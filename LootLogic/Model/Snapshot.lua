--[[
The snapshots of the current character: gear, proficiency, bags, bank and inbox,
and the mail the character sends to its own roster (spec 6; technical findings
5, 6 and 15). Each capture reads the client, replaces its part of the saved
entry and bumps gearHere once per event. A read-only session takes no snapshot
and writes nothing (spec 6, Notes: Migrations). Nothing is captured at
PLAYER_LOGOUT beyond the counts of the debug line: the client has already
cleared the data by then (confirmed in beta data; live check L32).
]]

local _, ns = ...

local Snapshot = {}
ns.Snapshot = Snapshot

local DB = ns.DB
local Events = ns.Events
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Proficiency = ns.Proficiency
local Roster = ns.Roster
local Slots = ns.Slots
local Util = ns.Util

--- How long the full snapshot at PLAYER_ENTERING_WORLD waits after the last
--- event, in seconds. An internal value with no live check: the wait only lets
--- the client settle at login.
Snapshot.DEBOUNCE_SECONDS = 1

-- An inbound entry older than this is dropped (technical findings 15: the
-- 30-day mail lifetime).
local MAIL_LIFETIME = 30 * 24 * 60 * 60

-- Used only when the client's attachment limits are missing. From memory
-- (Classic and retail values; live check L49).
local DEFAULT_SEND_LIMIT = 12
local DEFAULT_RECEIVE_LIMIT = 16

local GEAR_SLOT_FIRST = 1
local GEAR_SLOT_LAST = 19
local BANK_TAB_COUNT = 9

local bankOpen = false
-- The equippable bag items of the last bags snapshot of this session, as one
-- text, so a move between slots counts as a change (technical findings 15).
local bagsSignature = ""
local pendingMail

--- True from BANKFRAME_OPENED to BANKFRAME_CLOSED. A reload starts closed
--- (technical findings 15; live check L40).
-- @treturn boolean
function Snapshot.IsBankOpen()
    return bankOpen
end

-- True for equippable armour or a weapon: its equipLoc is one of the slot
-- types of Data/Slots.lua, which leaves out shirts, tabards, ammo, bags and
-- quivers, and it is not cosmetic armour (4:5). Profession tools are left to
-- the engine (spec 7.2, step 1d). C_Item.GetItemInfoInstant returns the item
-- ID, type, subtype, equipLoc, icon, classID and subclassID, and accepts a link
-- (from memory; technical findings 7.1 names the fields; live check L8).
local function IsEquippable(link)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if not Slots.invTypeGroup[equipLoc] then
        return false
    end
    return not (classID == 4 and subclassID == 5)
end

-- Reads the slots of the given containers. Returns the equippable links, the
-- item counts by ID, the signature text and the number of item IDs. The
-- fields itemID, hyperlink and stackCount of GetContainerItemInfo are live
-- check L7; GetContainerNumSlots is from memory (L14: a tab that is not bought
-- reports no slots and is skipped). A slot with a secret value is left out
-- (live check L25).
local function ScanContainers(bags)
    local gear = {}
    local ids = {}
    local parts = {}
    local idCount = 0
    for _, bag in ipairs(bags) do
        local size = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, size do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            local link = info and info.hyperlink
            local stack = 1
            if info and info.stackCount then
                stack = info.stackCount
            end
            if itemID and not Util.IsSecret(itemID) and not Util.IsSecret(stack) then
                if not ids[itemID] then
                    idCount = idCount + 1
                end
                ids[itemID] = (ids[itemID] or 0) + stack
                if link and not Util.IsSecret(link) and IsEquippable(link) then
                    gear[#gear + 1] = link
                    parts[#parts + 1] = bag .. ":" .. slot .. ":" .. link
                end
            end
        end
    end
    return gear, ids, table.concat(parts, "|"), idCount
end

local function BagIDs()
    local bags = {}
    for bag = Slots.bags.first, Slots.bags.last do
        bags[#bags + 1] = bag
    end
    return bags
end

-- The bank tab IDs from Enum.BagIndex.CharacterBankTab_1 to _9, never from
-- BANK_CONTAINER (technical findings 5; live check L14; fallback: re-derive
-- the IDs from Enum.BagIndex).
local function BankTabIDs()
    local tabs = {}
    for tab = 1, BANK_TAB_COUNT do
        local bag = Enum.BagIndex["CharacterBankTab_" .. tab]
        if bag then
            tabs[#tabs + 1] = bag
        end
    end
    return tabs
end

local function CaptureGear(entry)
    local slots = {}
    local count = 0
    -- GetInventoryItemLink("player", slot) is source-read on Forever
    -- (technical findings 5). That slots 1 to 19 are the equipment slots is
    -- from memory, and no live check covers the range (L52 covers the link
    -- format).
    for slot = GEAR_SLOT_FIRST, GEAR_SLOT_LAST do
        local link = GetInventoryItemLink("player", slot)
        if link and not Util.IsSecret(link) then
            slots[slot] = link
            count = count + 1
        end
    end
    entry.gear = { updatedAt = GetServerTime(), slots = slots }
    Log.Debug("snapshot", string.format(L.snapshotGear, count))
    return true
end

local function CaptureProficiency(entry)
    local spells = {}
    local count = 0
    -- IsPlayerSpell is from memory (live check L6; fallback: IsSpellKnown,
    -- C_SpellBook.IsSpellKnown or tooltip red lines).
    for _, spellID in pairs(Proficiency.spells) do
        if IsPlayerSpell(spellID) then
            spells[spellID] = true
            count = count + 1
        end
    end
    entry.proficiency = { updatedAt = GetServerTime(), spells = spells }
    Log.Debug("snapshot", string.format(L.snapshotProficiency, count))
    return true
end

-- Bumps only when an equippable item entered, left or moved.
local function CaptureBags(entry)
    local gear, ids, signature, idCount = ScanContainers(BagIDs())
    entry.bags = { updatedAt = GetServerTime(), gear = gear, ids = ids }
    Log.Debug("snapshot", string.format(L.snapshotBags, #gear, idCount))
    local changed = signature ~= bagsSignature
    bagsSignature = signature
    return changed
end

local function CaptureBank(entry)
    local gear, ids, _, idCount = ScanContainers(BankTabIDs())
    entry.bank = { updatedAt = GetServerTime(), gear = gear, ids = ids }
    Log.Debug("snapshot", string.format(L.snapshotBank, #gear, idCount))
    return true
end

-- Reads the inbox: the links and counts of every attachment. The three calls
-- and the attachment limit are from memory (live check L49; fallback: walk
-- the inbox on MAIL_SHOW only). GetInboxNumItems returns the number of mails
-- first; GetInboxItem returns the name, itemID, texture and count.
local function ReadInbox()
    local attachments = {}
    local mails = GetInboxNumItems() or 0
    local limit = ATTACHMENTS_MAX_RECEIVE or DEFAULT_RECEIVE_LIMIT
    for mail = 1, mails do
        for attachment = 1, limit do
            local link = GetInboxItemLink(mail, attachment)
            if link and not Util.IsSecret(link) then
                local itemID = Util.ParseLink(link)
                local _, _, _, count = GetInboxItem(mail, attachment)
                if itemID and not Util.IsSecret(count) then
                    attachments[#attachments + 1] = {
                        id = itemID,
                        link = link,
                        count = count or 1,
                    }
                end
            end
        end
    end
    return attachments
end

-- Drops each inbound entry of here that an attachment in the inbox matches
-- (item and count, one attachment per entry) or that is older than the mail
-- lifetime. An entry still in transit stays, so its item keeps counting as
-- owned (technical findings 15).
local function ClearInbound(entry, attachments)
    local inbound = entry.inbound
    if type(inbound) ~= "table" then
        return
    end
    local now = GetServerTime()
    local used = {}
    local kept = {}
    for _, item in ipairs(inbound) do
        local matched
        if type(item) == "table" then
            for position, attachment in ipairs(attachments) do
                if
                    not used[position]
                    and attachment.id == item.id
                    and attachment.count == item.count
                then
                    matched = position
                    break
                end
            end
        end
        local expired = type(item) == "table"
            and type(item.sentAt) == "number"
            and now - item.sentAt > MAIL_LIFETIME
        if matched then
            used[matched] = true
            Log.Debug(
                "mail",
                string.format(L.mailClearedSeen, tostring(item.id), tostring(item.count))
            )
        elseif expired then
            Log.Debug(
                "mail",
                string.format(L.mailClearedOld, tostring(item.id), tostring(item.count))
            )
        else
            kept[#kept + 1] = item
        end
    end
    entry.inbound = kept
end

local function CaptureInbox(entry)
    local attachments = ReadInbox()
    local gear = {}
    local ids = {}
    local idCount = 0
    for _, attachment in ipairs(attachments) do
        if not ids[attachment.id] then
            idCount = idCount + 1
        end
        ids[attachment.id] = (ids[attachment.id] or 0) + attachment.count
        if IsEquippable(attachment.link) then
            gear[#gear + 1] = attachment.link
        end
    end
    entry.inbox = { updatedAt = GetServerTime(), gear = gear, ids = ids }
    Log.Debug("snapshot", string.format(L.snapshotInbox, #gear, idCount))
    ClearInbound(entry, attachments)
    return true
end

-- Runs the captures on the current character's entry, then bumps gearHere
-- once when any asked for it. Returns "taken", or nil and "readonly" or
-- "unknown" (no entry for the current character yet).
local function Run(captures)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    -- No saved data yet: the event came before ADDON_LOADED filled it.
    local data = DB.Data()
    local key = Roster.HereKey()
    local characters = type(data) == "table" and data.characters
    local entry = key and type(characters) == "table" and characters[key]
    if type(entry) ~= "table" then
        return nil, "unknown"
    end
    local bump = false
    for _, capture in ipairs(captures) do
        if capture(entry) then
            bump = true
        end
    end
    if bump then
        Generations.Bump("gearHere")
    end
    return "taken"
end

--- Snapshots the equipped gear and the proficiency spells; bumps gearHere.
-- @treturn string|nil "taken"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Snapshot.TakeGear()
    return Run({ CaptureGear, CaptureProficiency })
end

--- Snapshots bags 0 to 5; bumps gearHere when an equippable item entered, left
--- or moved.
-- @treturn string|nil "taken"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Snapshot.TakeBags()
    return Run({ CaptureBags })
end

--- Snapshots the bank tabs; bumps gearHere. Only while the bank is open.
-- @treturn string|nil "taken"; nil after a refusal
-- @treturn string|nil "readonly", "unknown" or "closed" after a refusal
function Snapshot.TakeBank()
    if not bankOpen then
        return nil, "closed"
    end
    return Run({ CaptureBank })
end

--- Snapshots the inbox and clears the inbound entries of here it explains;
--- bumps gearHere.
-- @treturn string|nil "taken"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Snapshot.TakeInbox()
    return Run({ CaptureInbox })
end

--- The full snapshot of login: gear, proficiency and bags, with one bump.
-- @treturn string|nil "taken"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown" after a refusal
function Snapshot.TakeAll()
    return Run({ CaptureGear, CaptureProficiency, CaptureBags })
end

-- The key of the roster character whose full name equals the typed recipient,
-- ignoring case, among those in the current character's region (technical
-- findings 6, Mail recipient to roster). Nil when none does.
local function FindRecipient(recipient, hereEntry)
    local wanted = string.lower(strtrim(recipient))
    local characters = DB.Data().characters
    for _, key in ipairs(Roster.Keys()) do
        local entry = characters[key]
        local name = Roster.FullName(key)
        if
            type(entry) == "table"
            and name
            and entry.region == hereEntry.region
            and string.lower(name) == wanted
        then
            return key
        end
    end
    return nil
end

-- Remembers the recipient and the attachments of the mail being sent. The
-- attachment calls are from memory (live check L13; fallback: track through
-- the send frame); the limit is live check L49.
local function CaptureSend(recipient)
    pendingMail = nil
    if DB.IsReadOnly() or type(recipient) ~= "string" then
        return
    end
    local items = {}
    local texts = {}
    local limit = ATTACHMENTS_MAX_SEND or DEFAULT_SEND_LIMIT
    for index = 1, limit do
        local link = GetSendMailItemLink(index)
        if link and not Util.IsSecret(link) then
            local itemID = Util.ParseLink(link)
            local _, _, _, count = GetSendMailItem(index)
            if itemID and not Util.IsSecret(count) then
                count = count or 1
                items[#items + 1] = { id = itemID, link = link, count = count }
                texts[#texts + 1] = string.format("%s x%d", link, count)
            end
        end
    end
    pendingMail = { recipient = recipient, items = items }
    if #texts == 0 then
        texts[1] = L.mailNoAttachments
    end
    Log.Debug("mail", string.format(L.mailCaptured, recipient, table.concat(texts, ", ")))
end

local function OnSendSuccess()
    local mail = pendingMail
    pendingMail = nil
    if not mail or DB.IsReadOnly() then
        return
    end
    local hereKey = Roster.HereKey()
    local hereEntry = hereKey and DB.Data().characters[hereKey]
    if type(hereEntry) ~= "table" then
        return
    end
    local targetKey = FindRecipient(mail.recipient, hereEntry)
    if not targetKey then
        Log.Debug("mail", string.format(L.mailSentStranger, mail.recipient))
        return
    end
    local target = DB.Data().characters[targetKey]
    if type(target.inbound) ~= "table" then
        target.inbound = {}
    end
    local now = GetServerTime()
    for _, item in ipairs(mail.items) do
        target.inbound[#target.inbound + 1] = {
            sentAt = now,
            from = hereKey,
            id = item.id,
            link = item.link,
            count = item.count,
        }
        Log.Debug("mail", string.format(L.mailInboundAdded, targetKey, item.link, item.count))
    end
    if #mail.items > 0 then
        Generations.Bump("gearOthers")
    end
end

local takeAllLater = Util.Debounce(Snapshot.DEBOUNCE_SECONDS, Snapshot.TakeAll)

-- The events below are from memory (technical findings 15, events table);
-- live checks L40 (bank) and L49 (mail). The first two arguments of
-- PLAYER_ENTERING_WORLD say initial login and reload (from memory,
-- unverified; live check L40; fallback: a snapshot on every
-- PLAYER_ENTERING_WORLD).
Events.Register("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        takeAllLater()
    end
end)

Events.Register("PLAYER_EQUIPMENT_CHANGED", Snapshot.TakeGear)
Events.Register("SPELLS_CHANGED", Snapshot.TakeGear)

-- The new level comes from the event's first argument: UnitLevel may still
-- return the old one during the event (from memory).
Events.Register("PLAYER_LEVEL_UP", function(_, level)
    Run({
        function(entry)
            if type(level) == "number" then
                entry.level = level
            end
            return false
        end,
        CaptureGear,
        CaptureProficiency,
    })
end)

Events.Register("BAG_UPDATE_DELAYED", function()
    if bankOpen then
        Run({ CaptureBags, CaptureBank })
    else
        Run({ CaptureBags })
    end
end)

Events.Register("BANKFRAME_OPENED", function()
    bankOpen = true
    Snapshot.TakeBank()
end)

-- Never snapshots at close: the snapshot taken while open stays.
Events.Register("BANKFRAME_CLOSED", function()
    bankOpen = false
end)

Events.Register("MAIL_SHOW", Snapshot.TakeInbox)
Events.Register("MAIL_INBOX_UPDATE", Snapshot.TakeInbox)

-- The hook receives the recipient first, the arguments of the global function
-- (API guess; live check L13; fallback: track through the send frame).
Events.Register("PLAYER_LOGIN", function()
    hooksecurefunc("SendMail", function(recipient)
        Log.Guard("events", CaptureSend, recipient)
    end)
end)

Events.Register("MAIL_SEND_SUCCESS", OnSendSuccess)

Events.Register("MAIL_FAILED", function()
    if pendingMail then
        pendingMail = nil
        Log.Debug("mail", L.mailFailed)
    end
end)

-- Counts are read for the debug line only and never stored (live check L32:
-- the client has cleared the data by now, so the counts may be zero).
Events.Register("PLAYER_LOGOUT", function()
    if not Log.IsDebugOn() then
        return
    end
    local worn = 0
    for slot = GEAR_SLOT_FIRST, GEAR_SLOT_LAST do
        if GetInventoryItemLink("player", slot) then
            worn = worn + 1
        end
    end
    local filled = 0
    for _, bag in ipairs(BagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            if C_Container.GetContainerItemInfo(bag, slot) then
                filled = filled + 1
            end
        end
    end
    Log.Debug("logout", string.format(L.logoutCounts, worn, filled))
end)
