--[[
The roster: character keys, the entry of the current character, eligibility,
the priority order, the Receives gear switch and display names (spec 4, 6 and
13; technical findings 6 and 15). Saved data is read through DB.Data(); a
read-only session writes nothing (spec 6, Notes: Migrations).
]]

local _, ns = ...

local Roster = {}
ns.Roster = Roster

local DB = ns.DB
local Events = ns.Events
local Generations = ns.Generations
local Init = ns.Init

local addedThisSession = {}

-- The current character's key, region and faction, kept from login: the
-- logout handler cannot rely on the client still answering UnitName then
-- (API guess; live check L32 checks gear only).
local hereKey
local hereRegion
local hereFaction

local function JoinName(first, last)
    if not last or last == "" then
        return first
    end
    return first .. " " .. last
end

-- The first name, the last name and the key of the current character, read
-- from the client. Confirmed (team, beta play, 2026-10-31): UnitName returns
-- two names (live check L2).
local function ReadHere()
    local first, last = UnitName("player")
    if not first or not last then
        return nil
    end
    -- Unverified: GetRealmName returns the region on Forever (live check L3;
    -- fallback: rework eligibility).
    return first, last, first .. " " .. last .. "-" .. GetRealmName()
end

-- True for a saved entry that has a first name, the minimum the roster needs.
local function IsUsable(entry)
    return type(entry) == "table" and type(entry.first) == "string"
end

local function Surname(entry)
    if type(entry.last) == "string" then
        return entry.last
    end
    return ""
end

local function SortedKeys(characters)
    local keys = {}
    for key in pairs(characters) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- A surname as a list of whole characters (UTF-8 sequences) and the same list
-- folded to lower case. string.lower folds ASCII letters only (from memory),
-- so an accented capital differs from its lower case form.
local function SplitSurname(surname)
    local chars = {}
    local lowered = {}
    for character in string.gmatch(surname, "[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = character
        lowered[#lowered + 1] = string.lower(character)
    end
    return { chars = chars, lowered = lowered }
end

local function IsStartOf(short, long)
    if #short.lowered >= #long.lowered then
        return false
    end
    for position = 1, #short.lowered do
        if short.lowered[position] ~= long.lowered[position] then
            return false
        end
    end
    return true
end

-- The letter of a surname that tells it apart from every other surname of its
-- group: the character at the first position where it differs from all of
-- them, ignoring case (a position past the end of a shorter surname counts as
-- different). Returns the letter as written, "" when the surname is the start
-- of another (the first name alone is used), or nil when there is no such
-- letter.
local function SurnameLetter(own, others)
    for position = 1, #own.chars do
        local differs = true
        for _, other in ipairs(others) do
            if other.lowered[position] == own.lowered[position] then
                differs = false
                break
            end
        end
        if differs then
            return own.chars[position]
        end
    end
    for _, other in ipairs(others) do
        if IsStartOf(own, other) then
            return ""
        end
    end
    return nil
end

-- The automatic names of one group of characters sharing a first name, as a
-- map from key to name. Every key gets its full name when the letters do not
-- give each its own name.
local function GroupNames(group, characters)
    local split = {}
    for _, key in ipairs(group) do
        split[key] = SplitSurname(Surname(characters[key]))
    end
    local names = {}
    local seen = {}
    local complete = true
    for _, key in ipairs(group) do
        local others = {}
        for _, otherKey in ipairs(group) do
            if otherKey ~= key then
                others[#others + 1] = split[otherKey]
            end
        end
        local letter = SurnameLetter(split[key], others)
        if not letter then
            complete = false
            break
        end
        names[key] = JoinName(characters[key].first, letter)
        if seen[names[key]] then
            complete = false
            break
        end
        seen[names[key]] = true
    end
    if complete then
        return names
    end
    for _, key in ipairs(group) do
        names[key] = JoinName(characters[key].first, Surname(characters[key]))
    end
    return names
end

local function Override(entry)
    if type(entry.displayName) == "string" and entry.displayName ~= "" then
        return entry.displayName
    end
    return nil
end

-- Creates or refreshes the current character's entry at PLAYER_LOGIN.
local function Register()
    local first, last, key = ReadHere()
    if not key then
        return
    end
    hereKey = key
    hereRegion = GetRealmName()
    hereFaction = UnitFactionGroup("player")
    if DB.IsReadOnly() then
        return
    end
    -- Every client value is read before anything is written, so a failing
    -- call leaves the saved data as it was.
    -- All below: from memory (API guess), no live check yet. UnitClass gives
    -- the class name then the token, UnitRace the race name, token and
    -- numeric ID, GetBuildInfo the version then the build number.
    local class = select(2, UnitClass("player"))
    local race = select(2, UnitRace("player"))
    local level = UnitLevel("player")
    local version, build = GetBuildInfo()
    local buildText
    if type(version) == "string" and type(build) == "string" then
        buildText = version .. "." .. build
    end
    local lootLogicVersion = Init.Version()
    local data = DB.Data()
    local entry = data.characters[key]
    local isNew = type(entry) ~= "table"
    local listed = false
    for _, listedKey in ipairs(data.order) do
        if listedKey == key then
            listed = true
            break
        end
    end
    if not listed then
        data.order[#data.order + 1] = key
    end
    if isNew then
        entry = {}
        data.characters[key] = entry
        addedThisSession[key] = true
    end
    entry.first = first
    entry.last = last
    entry.region = hereRegion
    entry.faction = hereFaction
    entry.class = class
    -- Unverified: the race token (such as "NightElf") is the second value of
    -- UnitRace; live check L3.
    entry.race = race
    entry.level = level
    entry.lastSeen = GetServerTime()
    entry.build = buildText
    entry.lootLogicVersion = lootLogicVersion
    if isNew or not listed then
        Generations.Bump("roster")
    end
end

--- The key of the current character: the one kept at login, else read from
--- the client; nil when the game gives no name.
-- @treturn string|nil
function Roster.HereKey()
    if hereKey then
        return hereKey
    end
    local _, _, key = ReadHere()
    return key
end

--- True when the key is the current character's.
-- @param key string
-- @treturn boolean
function Roster.IsHere(key)
    return key == Roster.HereKey()
end

--- The saved entry of a character, or nil.
-- @param key string
-- @treturn table|nil
function Roster.Entry(key)
    return DB.Data().characters[key]
end

--- The keys of the registered characters in the priority order, as a new list.
-- @treturn table list of strings
function Roster.Keys()
    local keys = {}
    for index, key in ipairs(DB.Data().order) do
        keys[index] = key
    end
    return keys
end

--- True when the character was added to the roster at this session's login.
--- Used by M1's "added" chat line (docs/ux.md 2.1).
-- @param key string
-- @treturn boolean
function Roster.WasAddedThisSession(key)
    return addedThisSession[key] or false
end

--- True for a registered character with the same faction and the same region
--- as the current one, other than the current one (spec 4).
-- Source-read (Forever Ledger's mail rule), unverified here: UnitFactionGroup
-- and GetRealmName give the faction and the region (live check L3; fallback:
-- rework eligibility). The ruleset cannot be read (L53, accepted limit).
-- @param key string
-- @treturn boolean
function Roster.IsEligible(key)
    local entry = DB.Data().characters[key]
    if not entry or key == Roster.HereKey() then
        return false
    end
    local region = hereRegion or GetRealmName()
    local faction = hereFaction or UnitFactionGroup("player")
    return entry.faction == faction and entry.region == region
end

--- The eligible characters, in the priority order.
-- @treturn table list of keys
function Roster.EligibleKeys()
    local keys = {}
    for _, key in ipairs(DB.Data().order) do
        if Roster.IsEligible(key) then
            keys[#keys + 1] = key
        end
    end
    return keys
end

--- Sets the priority order: the listed keys first, in that order, and the rest
--- after them in their old order (spec 13, /ll order). A repeated key counts
--- once. A key that is not in the order refuses the whole change. Bumps roster
--- when the order changes.
-- @param keys table list of character keys
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Roster.SetOrder(keys)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local data = DB.Data()
    local known = {}
    for _, key in ipairs(data.order) do
        known[key] = true
    end
    for _, key in ipairs(keys) do
        if not known[key] then
            return nil, "unknown"
        end
    end
    local result = {}
    local placed = {}
    for _, key in ipairs(keys) do
        if not placed[key] then
            placed[key] = true
            result[#result + 1] = key
        end
    end
    for _, key in ipairs(data.order) do
        if not placed[key] then
            placed[key] = true
            result[#result + 1] = key
        end
    end
    local changed = #result ~= #data.order
    for index, key in ipairs(result) do
        if data.order[index] ~= key then
            changed = true
        end
    end
    if not changed then
        return "unchanged"
    end
    -- The saved table is changed in place, so a reader holding it sees the new
    -- order.
    for index = #data.order, 1, -1 do
        data.order[index] = nil
    end
    for index, key in ipairs(result) do
        data.order[index] = key
    end
    Generations.Bump("roster")
    return "changed"
end

--- Whether gear upgrades may be routed to the character (spec 6: nil counts as
--- true).
-- @param key string
-- @treturn boolean
function Roster.ReceivesGear(key)
    local entry = DB.Data().characters[key]
    if not entry then
        return false
    end
    return entry.receivesGear ~= false
end

--- Sets the Receives gear switch (spec 13, /ll gear). On is stored as nil,
--- off as false. Bumps roster when the switch changes.
-- @param key string
-- @param receives boolean
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Roster.SetReceivesGear(key, receives)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local entry = DB.Data().characters[key]
    if not entry then
        return nil, "unknown"
    end
    if (entry.receivesGear ~= false) == receives then
        return "unchanged"
    end
    if receives then
        entry.receivesGear = nil
    else
        entry.receivesGear = false
    end
    Generations.Bump("roster")
    return "changed"
end

--- The full name "First Last" of a character (the first name alone when it has
--- no last name).
-- @param key string
-- @treturn string|nil nil for an unknown key
function Roster.FullName(key)
    local entry = DB.Data().characters[key]
    if not IsUsable(entry) then
        return nil
    end
    return JoinName(entry.first, Surname(entry))
end

--- The display name of every registered character, as a map from key to name
--- (spec 6, Display name). Computed on each call, never stored. Eligibility
--- plays no part, so a name does not change when it does. An entry without a
--- first name (damaged saved data) is named by its key.
-- @treturn table map from key to display name
function Roster.DisplayNames()
    local characters = DB.Data().characters
    local keys = SortedKeys(characters)
    local groups = {}
    local names = {}
    local overrides = {}
    local overrideSet = {}
    for _, key in ipairs(keys) do
        local entry = characters[key]
        if IsUsable(entry) then
            groups[entry.first] = groups[entry.first] or {}
            table.insert(groups[entry.first], key)
            overrides[key] = Override(entry)
            if overrides[key] then
                overrideSet[overrides[key]] = true
            end
        else
            names[key] = key
        end
    end
    for _, key in ipairs(keys) do
        if overrides[key] then
            names[key] = overrides[key]
        elseif not names[key] then
            local group = groups[characters[key].first]
            if #group == 1 then
                names[key] = characters[key].first
            else
                for groupKey, name in pairs(GroupNames(group, characters)) do
                    if not overrides[groupKey] then
                        names[groupKey] = name
                    end
                end
            end
        end
    end
    -- An automatic name never equals another character's override.
    local used = {}
    for _, key in ipairs(keys) do
        used[names[key]] = true
    end
    for _, key in ipairs(keys) do
        if IsUsable(characters[key]) and not overrides[key] and overrideSet[names[key]] then
            local full = Roster.FullName(key)
            local name = full
            local number = 2
            while overrideSet[name] or used[name] do
                name = full .. " " .. number
                number = number + 1
            end
            used[name] = true
            names[key] = name
        end
    end
    return names
end

--- The display name of one character.
-- @param key string
-- @treturn string|nil nil for an unknown key
function Roster.DisplayName(key)
    return Roster.DisplayNames()[key]
end

-- The first Model handler of PLAYER_LOGIN (Loadouts.lua loads after this file,
-- and both load before Prices.lua, whose handler may need the entry).
Events.Register("PLAYER_LOGIN", Register)

-- Only lastSeen is written here: the client has already cleared other data
-- (confirmed in beta data; live check L32).
Events.Register("PLAYER_LOGOUT", function()
    if DB.IsReadOnly() then
        return
    end
    local entry = DB.Data().characters[Roster.HereKey()]
    if entry then
        entry.lastSeen = GetServerTime()
    end
end)
