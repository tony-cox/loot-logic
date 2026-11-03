--[[
Protect lists and imported gear sets (spec 6, 9.2 and 13; technical findings 9.1
and 15). The Protect lists are toggled by key: a plain item ID protects every
roll, an instance key "itemID:suffixID" one roll. The imported sets are a
read-only copy of the membership of the Equipment Manager and Outfitter Forever
sets: nothing here writes to Outfitter or to the game. A read-only session
writes nothing and refuses (spec 6, Notes: Migrations). Typed text and links
are parsed in M1; the functions here take numbers.
]]

local _, ns = ...

local Sets = {}
ns.Sets = Sets

local DB = ns.DB
local Events = ns.Events
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Roster = ns.Roster
local Util = ns.Util

-- The Outfitter events that count as a change of the outfits. OUTFITTER_INIT is
-- in the list because Outfitter's settings may not exist at our login (an
-- API guess; no live check covers it yet). WEAR_OUTFIT and UNWEAR_OUTFIT
-- change nothing in the sets, so they are left out.
local OUTFITTER_EVENTS = {
    "OUTFITTER_INIT",
    "ADD_OUTFIT",
    "DELETE_OUTFIT",
    "EDIT_OUTFIT",
    "DID_RENAME_OUTFIT",
}

local outfitterHooked = false

-- The saved entry of an editable character, or nil and the reason for a
-- refusal. Creates nothing.
local function Editable(key)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local entry = DB.Data().characters[key]
    if not entry then
        return nil, "unknown"
    end
    return entry
end

-- The key a plain item ID is stored under, and the key of an instance. Both
-- are strings, as in spec 6.
local function PlainKey(itemID)
    return string.format("%d", itemID)
end

-- A suffix of nil or 0 gives the plain key (spec 13, Protect keys).
local function ProtectKey(itemID, suffix)
    if not suffix or suffix == 0 then
        return PlainKey(itemID)
    end
    return string.format("%d:%d", itemID, suffix)
end

-- Toggles the key on a list. Returns "added" or "removed", or nil and
-- "everyroll" when only the plain ID is stored and the toggle names one roll.
local function Toggle(list, itemID, suffix)
    local exact = ProtectKey(itemID, suffix)
    if list[exact] then
        list[exact] = nil
        return "removed"
    end
    local plain = PlainKey(itemID)
    if exact ~= plain and list[plain] then
        return nil, "everyroll"
    end
    list[exact] = true
    return "added"
end

-- True when the list holds the plain ID or the instance key.
local function Listed(list, itemID, suffix)
    if type(list) ~= "table" then
        return false
    end
    if list[PlainKey(itemID)] or list[ProtectKey(itemID, suffix)] then
        return true
    end
    return false
end

-- The keys of a table sorted, so that reads are in a fixed order. Keys are
-- numbers or strings, never mixed in one table here.
local function SortedKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- True when the saved set has the same name and members, in order, as the new
-- one.
local function SameSet(saved, fresh)
    if type(saved) ~= "table" or saved.name ~= fresh.name or type(saved.items) ~= "table" then
        return false
    end
    if #saved.items ~= #fresh.items then
        return false
    end
    for index, item in ipairs(fresh.items) do
        local member = saved.items[index]
        if type(member) ~= "table" or member.id ~= item.id or member.suffix ~= item.suffix then
            return false
        end
    end
    return true
end

-- Replaces the sets of one source on an entry with the new ones. sets is a
-- list of { name, items }. A repeated name adds its items to the first set
-- (safe: more members only protect more). Nothing is written when the sets are
-- the ones already saved. Returns the number of sets and of items, and whether
-- anything was written.
local function Replace(entry, source, sets, now)
    local prefix = source .. ":"
    local fresh = {}
    local setCount = 0
    local itemCount = 0
    for _, set in ipairs(sets) do
        local key = prefix .. set.name
        local target = fresh[key]
        if not target then
            target = { source = source, name = set.name, updatedAt = now, items = {} }
            fresh[key] = target
            setCount = setCount + 1
        end
        for _, item in ipairs(set.items) do
            target.items[#target.items + 1] = { id = item.id, suffix = item.suffix }
            itemCount = itemCount + 1
        end
    end
    local saved = entry.importedSets
    local changed = type(saved) ~= "table" and setCount > 0
    if type(saved) == "table" then
        for key, set in pairs(saved) do
            if
                string.sub(key, 1, #prefix) == prefix
                and not (fresh[key] and SameSet(set, fresh[key]))
            then
                changed = true
            end
        end
        for key in pairs(fresh) do
            if not saved[key] then
                changed = true
            end
        end
    end
    if not changed then
        return setCount, itemCount, false
    end
    if type(saved) ~= "table" then
        saved = {}
        entry.importedSets = saved
    end
    for key in pairs(saved) do
        if string.sub(key, 1, #prefix) == prefix then
            saved[key] = nil
        end
    end
    for key, set in pairs(fresh) do
        saved[key] = set
    end
    return setCount, itemCount, true
end

-- The current character's saved entry, or nil. Nothing is written in a
-- read-only session.
local function HereEntry()
    if DB.IsReadOnly() then
        return nil
    end
    local key = Roster.HereKey()
    local entry = key and DB.Data().characters[key]
    if type(entry) ~= "table" then
        return nil
    end
    return entry, key
end

-- The suffix of an Equipment Manager member, read from the link at the
-- member's location while the item is worn or in the bags; 0 for a location
-- in the bank, an unset one or a link of another item (unverified; live check
-- L1). EquipmentManager_UnpackLocation, GetInventoryItemLink and
-- C_Container.GetContainerItemLink are from memory (API guess), as is the
-- meaning of the values: player, bank and bags are true for the places, and
-- slot and bag say where.
local function SuffixAt(itemID, location)
    if type(location) ~= "number" or location <= 0 then
        return 0
    end
    if type(EquipmentManager_UnpackLocation) ~= "function" then
        return 0
    end
    local player, bank, bags, _, slot, bag = EquipmentManager_UnpackLocation(location)
    if not player or bank or type(slot) ~= "number" then
        return 0
    end
    -- A different return shape would move slot and bag; read nothing then.
    if bags and type(bag) ~= "number" then
        return 0
    end
    local link
    if bags then
        link = C_Container.GetContainerItemLink(bag, slot)
    else
        link = GetInventoryItemLink("player", slot)
    end
    if not link then
        return 0
    end
    local linkID, suffix = Util.ParseLink(link)
    if linkID ~= itemID then
        return 0
    end
    return suffix
end

-- The sets of the Equipment Manager: a list of { name, items }. All four
-- C_EquipmentSet calls are unverified (technical findings 9.1; live check L1):
-- GetEquipmentSetIDs gives a list of IDs, GetEquipmentSetInfo the name first,
-- GetItemIDs and GetItemLocations tables by slot.
local function ReadEquipmentSets()
    local sets = {}
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        local locations = C_EquipmentSet.GetItemLocations(setID) or {}
        local items = {}
        for _, slot in ipairs(SortedKeys(itemIDs)) do
            local itemID = itemIDs[slot]
            if type(itemID) == "number" and itemID > 0 then
                items[#items + 1] = { id = itemID, suffix = SuffixAt(itemID, locations[slot]) }
            end
        end
        sets[#sets + 1] = { name = name, items = items }
    end
    return sets
end

-- The sets of an Outfitter outfit table, Outfits[categoryID] = { outfit, ... }
-- (source-read for the category lists and for Code and SubCode; the outfit's
-- Name and Items fields are from memory; live check L29).
-- Items are keyed by slot name.
local function ReadOutfits(outfits)
    local sets = {}
    if type(outfits) ~= "table" then
        return sets
    end
    for _, category in ipairs(SortedKeys(outfits)) do
        local list = outfits[category]
        if type(list) == "table" then
            for _, outfit in ipairs(list) do
                if type(outfit) == "table" and type(outfit.Name) == "string" then
                    local items = {}
                    local slots = outfit.Items
                    if type(slots) == "table" then
                        for _, slotName in ipairs(SortedKeys(slots)) do
                            local item = slots[slotName]
                            if
                                type(item) == "table"
                                and type(item.Code) == "number"
                                and item.Code > 0
                            then
                                local suffix = item.SubCode
                                if type(suffix) ~= "number" then
                                    suffix = 0
                                end
                                items[#items + 1] = { id = item.Code, suffix = suffix }
                            end
                        end
                    end
                    sets[#sets + 1] = { name = outfit.Name, items = items }
                end
            end
        end
    end
    return sets
end

-- How many registered characters have each first name.
local function FirstNameCounts(characters)
    local counts = {}
    for _, entry in pairs(characters) do
        if type(entry) == "table" and type(entry.first) == "string" then
            counts[entry.first] = (counts[entry.first] or 0) + 1
        end
    end
    return counts
end

-- Registers for Outfitter's own events, once. Outfitter:RegisterOutfitEvent
-- and the event names are source-read (technical findings 9.1). The
-- callbacks run outside our event frame, so each is guarded here.
local function HookOutfitter()
    if outfitterHooked then
        return
    end
    if type(Outfitter) ~= "table" or type(Outfitter.RegisterOutfitEvent) ~= "function" then
        return
    end
    outfitterHooked = true
    for _, event in ipairs(OUTFITTER_EVENTS) do
        Outfitter:RegisterOutfitEvent(event, function(...)
            Events.LogEvent(event, ...)
            Log.Guard("events", Sets.RefreshOutfitter)
        end)
    end
end

--- Toggles protection of an item on the character's list. A suffix of nil or 0
--- stores the plain item ID (every roll); a toggle removes the exact key it
--- would store. If only the plain item ID is stored and the toggle names one
--- roll, nothing changes and the caller gets "everyroll" (M1 words the reply,
--- spec 13). Bumps asks on a change.
-- @param key string character key
-- @param itemID number
-- @param suffix number|nil suffix ID of the roll, nil or 0 for none
-- @treturn string|nil "added" or "removed"; nil after a refusal
-- @treturn string|nil "readonly", "unknown" or "everyroll"
function Sets.ToggleProtect(key, itemID, suffix)
    local entry, reason = Editable(key)
    if not entry then
        return nil, reason
    end
    if type(entry.protect) ~= "table" then
        entry.protect = {}
    end
    local result, refusal = Toggle(entry.protect, itemID, suffix)
    if not result then
        return nil, refusal
    end
    Generations.Bump("asks")
    return result
end

--- As Sets.ToggleProtect, on the global list (spec 6, protectGlobal).
-- @param itemID number
-- @param suffix number|nil
-- @treturn string|nil "added" or "removed"; nil after a refusal
-- @treturn string|nil "readonly" or "everyroll"
function Sets.ToggleProtectGlobal(itemID, suffix)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local data = DB.Data()
    if type(data.protectGlobal) ~= "table" then
        data.protectGlobal = {}
    end
    local result, refusal = Toggle(data.protectGlobal, itemID, suffix)
    if not result then
        return nil, refusal
    end
    Generations.Bump("asks")
    return result
end

--- Step 1b: the item's plain ID or its instance key is on the current
--- character's Protect list or on the global one.
-- @param itemID number
-- @param suffix number|nil suffix ID of the item, nil or 0 for none
-- @treturn boolean
function Sets.IsProtected(itemID, suffix)
    local data = DB.Data()
    if Listed(data.protectGlobal, itemID, suffix) then
        return true
    end
    local entry = data.characters[Roster.HereKey()]
    return type(entry) == "table" and Listed(entry.protect, itemID, suffix)
end

--- Step 1c: the item is a member of one of the current character's imported
--- sets. A member stored with suffix 0 (a roll that was not known at import)
--- matches every roll of its item ID; any other member matches its own roll
--- only (spec 6, Notes: Item keys).
-- @param itemID number
-- @param suffix number|nil suffix ID of the item, nil or 0 for none
-- @treturn boolean
-- @treturn table|nil the first set that holds the item ({ source, name, ... }),
--   for the reason text (spec 7.6, `inset`)
function Sets.IsSetMember(itemID, suffix)
    local entry = DB.Data().characters[Roster.HereKey()]
    if type(entry) ~= "table" or type(entry.importedSets) ~= "table" then
        return false
    end
    suffix = suffix or 0
    for _, set in pairs(entry.importedSets) do
        if type(set) == "table" and type(set.items) == "table" then
            for _, member in ipairs(set.items) do
                if member.id == itemID and (member.suffix == 0 or member.suffix == suffix) then
                    return true, set
                end
            end
        end
    end
    return false
end

--- Copies the membership of the current character's Equipment Manager sets
--- into importedSets, replacing the earlier copy. Reads the game and writes
--- only the saved data. Bumps loadouts when a set changed and writes the debug
--- snapshot line. With keepWhenEmpty, an empty list from the game changes
--- nothing: at login the Equipment Manager may not have its sets yet (an API
--- guess; live check L1), so the saved sets stay until the game reports a
--- change or gives sets.
-- @param keepWhenEmpty boolean|nil
function Sets.RefreshEquipmentSets(keepWhenEmpty)
    local entry = HereEntry()
    if not entry then
        return
    end
    -- Read before writing, so a failing call leaves the saved data as it was.
    local sets = ReadEquipmentSets()
    if keepWhenEmpty and #sets == 0 then
        return
    end
    local setCount, itemCount, changed = Replace(entry, "equipmentset", sets, GetServerTime())
    if changed then
        Generations.Bump("loadouts")
    end
    Log.Debug("snapshot", string.format(L.snapshotSetsEquipment, setCount, itemCount))
end

--- Copies the membership of Outfitter Forever's outfits into importedSets,
--- replacing the earlier copy: the current character's from the live
--- Outfitter.Settings, the others' from the account-wide copy in
--- gOutfitter_GlobalSettings, matched by first name plus region and skipped
--- when the first name is shared (spec 9.2; technical findings 9.1). A
--- character with no copy keeps what it had. When the Outfitter global is
--- missing (the addon was removed or is off), the current character's Outfitter
--- sets are cleared. Reads Outfitter and never writes to it. Bumps loadouts
--- once when any set changed and writes the debug snapshot line; does nothing
--- when Outfitter has no data yet.
function Sets.RefreshOutfitter()
    local entry, hereKey = HereEntry()
    if not entry then
        return
    end
    local data = DB.Data()
    local found = {}
    -- Source-read (Outfitter Forever 1.9.1): the global Outfitter table with
    -- Settings.Outfits for this character. No table at all means the addon is
    -- gone, so its sets are dropped; a table without Settings is not loaded
    -- yet and changes nothing.
    if type(Outfitter) ~= "table" then
        found[hereKey] = {}
    elseif type(Outfitter.Settings) == "table" then
        found[hereKey] = ReadOutfits(Outfitter.Settings.Outfits)
    end
    -- Source-read: gOutfitter_GlobalSettings.Characters["FirstName-Realm"] with
    -- an Outfits table (live check L29; fallback: the current character only).
    local copies = type(gOutfitter_GlobalSettings) == "table"
        and gOutfitter_GlobalSettings.Characters
    if type(copies) == "table" then
        local counts = FirstNameCounts(data.characters)
        for _, key in ipairs(data.order) do
            local other = data.characters[key]
            if
                key ~= hereKey
                and type(other) == "table"
                and type(other.first) == "string"
                and counts[other.first] == 1
            then
                local copy = copies[other.first .. "-" .. tostring(other.region)]
                if type(copy) == "table" then
                    found[key] = ReadOutfits(copy.Outfits)
                end
            end
        end
    end
    if next(found) == nil then
        return
    end
    local now = GetServerTime()
    local setTotal = 0
    local itemTotal = 0
    local anyChanged = false
    for _, key in ipairs(SortedKeys(found)) do
        local setCount, itemCount, changed =
            Replace(data.characters[key], "outfitter", found[key], now)
        setTotal = setTotal + setCount
        itemTotal = itemTotal + itemCount
        anyChanged = anyChanged or changed
    end
    if anyChanged then
        Generations.Bump("loadouts")
    end
    Log.Debug("snapshot", string.format(L.snapshotSetsOutfitter, setTotal, itemTotal))
end

-- After the roster entry (Roster.lua loads first, so its handler runs first).
Events.Register("PLAYER_LOGIN", function()
    Sets.RefreshEquipmentSets(true)
end)

Events.Register("PLAYER_LOGIN", function()
    HookOutfitter()
    Sets.RefreshOutfitter()
end)

-- EQUIPMENT_SETS_CHANGED is from memory (consistent with EUI and Baganator
-- use; live check L1).
Events.Register("EQUIPMENT_SETS_CHANGED", function()
    Sets.RefreshEquipmentSets()
end)

-- An addon that loaded before us fires no ADDON_LOADED we see; the login
-- handler above covers it.
Events.Register("ADDON_LOADED", function(_, addon)
    if addon == "OutfitterForever" then
        HookOutfitter()
        Sets.RefreshOutfitter()
    end
end)
