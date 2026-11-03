--[[
The fake WoW client for the offline tests. run.py loads this chunk first in a
fresh Lua runtime; it defines the client globals the addon reads and returns the
control table that tests receive as h.Stub.

Setters of h.Stub (keep this list in step with the code below):
  Advance(seconds)        move the one manual clock forward, running due timers
  SetTimeOffset(seconds)  zone offset used by date() and time(dateTable)
                          (default 0, UTC)
  SetAddOnMetadata(addon, field, value)
                          value C_AddOns.GetAddOnMetadata returns for an addon
  SetPlayer(fields)       change the current character; fields (all optional):
                          first, last, realm, faction, factionName, class
                          (token), className, race (name), raceToken, raceID,
                          level, version, build
  MakeSecret()            a new token that issecretvalue reports as true
  FireEvent(event, ...)   fire an event on every frame registered for it
  ChatLines()             list of the chat lines printed so far
  ClearChat()             forget the captured chat lines
  SetEquipmentSets(list)  the Equipment Manager sets of the current character;
                          each { id, name, items = { [slot] = itemID },
                          places = { [slot] = { where = "worn" | "bag" |
                          "bank", slot, bag } or a plain number }, noLocations =
                          true makes GetItemLocations give nil }
  SetWornLink(slot, link) the link GetInventoryItemLink("player", slot) gives
  SetBagLink(bag, slot, link)
                          the link C_Container.GetContainerItemLink gives
  SetTooltipLines(link, lines)
                          the lines C_TooltipInfo.GetHyperlink(link) gives (a
                          list of strings); no call, no tooltip (nil)
  SetItemSpellKnown(text)
                          the global ITEM_SPELL_KNOWN (nil removes it)
  TooltipCalls()          how many times C_TooltipInfo.GetHyperlink was called
  SetOutfitter(settings)  install the Outfitter global with Settings = settings
  RemoveOutfitter()       remove the Outfitter global
  SetOutfitterGlobal(characters)
                          gOutfitter_GlobalSettings.Characters = characters
  FireOutfitterEvent(event, ...)
                          call the functions registered with
                          Outfitter:RegisterOutfitEvent for the event
  OutfitterHandlerCount(event)
                          how many functions are registered for the event
  SetBagSize(bag, size)   the number of slots C_Container.GetContainerNumSlots
                          gives (0 when unset, as for a tab not bought)
  SetBagItem(bag, slot, item)
                          one bag slot, item = { itemID, link, count }, or nil
                          to empty it; also the link GetContainerItemLink gives
  SetBagIndex(name, value)
                          change a member of Enum.BagIndex
  OpenBank()              fire BANKFRAME_OPENED
  CloseBank()             fire BANKFRAME_CLOSED
  SetItemInstant(itemID, fields)
                          what C_Item.GetItemInfoInstant gives: equipLoc,
                          classID, subclassID
  SetKnownSpells(list)    the spell IDs IsPlayerSpell reports as known
  SetInbox(mails)         the inbox, a list of { items = { { link, count } } }
  SetSendMailItems(items) the attachments of the mail being written, a list of
                          { link, count }

Time: every "now" comes from the manual clock, never the machine clock. date()
formats in UTC (plus the offset) so expected times do not depend on the
machine's zone. The calls C_Timer.NewTimer with Cancel, GetServerTime, date and
GetTime are from memory (live check L63). If NewTimer is missing on the client,
the code keeps one C_Timer.After per timer with a token and the stub drops it.
]]

local Stub = {}

-- 2024-01-01 00:00:00 UTC, so midnight cases start at a round number.
local START_TIME = 1704067200
local SESSION_BASE = 1000

-- The clock counts whole milliseconds since the start, so fractional advances
-- do not drift at epoch size.
local elapsedMs = 0
local offset = 0
local timerSeq = 0
local timers = {}
local frames = {}
local chatLines = {}
local metadata = { LootLogic = { Version = "0.0.0-test" } }

local function Floor(value)
    return math.floor(value)
end

-- Days since 1970-01-01 for a civil date (proleptic Gregorian, UTC).
local function DaysFromCivil(year, month, day)
    if month <= 2 then
        year = year - 1
    end
    local era = Floor(year / 400)
    local yearOfEra = year - era * 400
    local shifted = month + 9
    if month > 2 then
        shifted = month - 3
    end
    local dayOfYear = Floor((153 * shifted + 2) / 5) + day - 1
    local dayOfEra = yearOfEra * 365 + Floor(yearOfEra / 4) - Floor(yearOfEra / 100) + dayOfYear
    return era * 146097 + dayOfEra - 719468
end

local function ToMs(seconds)
    return Floor(seconds * 1000 + 0.5)
end

function GetServerTime()
    return START_TIME + Floor(elapsedMs / 1000)
end

function GetTime()
    return SESSION_BASE + elapsedMs / 1000
end

-- The client's time(): the manual clock with no argument; with a date table,
-- the epoch of that table read in the stub's zone (the UTC offset), so that
-- time(date("*t", x)) equals x. Confidence: from memory.
function time(dateTable)
    if not dateTable then
        return GetServerTime()
    end
    -- Out-of-range months carry into the year, as os.time normalises them.
    local monthIndex = dateTable.month - 1
    local year = dateTable.year + Floor(monthIndex / 12)
    local days = DaysFromCivil(year, monthIndex % 12 + 1, dateTable.day)
    local seconds = (dateTable.hour or 12) * 3600 + (dateTable.min or 0) * 60
    return days * 86400 + seconds + (dateTable.sec or 0) - offset
end

-- A format that starts with "!" asks for UTC and ignores the offset, as Lua's
-- os.date does (from memory).
function date(format, stamp)
    format = format or "%c"
    stamp = stamp or GetServerTime()
    if string.sub(format, 1, 1) == "!" then
        return os.date(format, stamp)
    end
    return os.date("!" .. format, stamp + offset)
end

local function RunsBefore(first, second)
    if first.dueMs ~= second.dueMs then
        return first.dueMs < second.dueMs
    end
    return first.seq < second.seq
end

local running = false

local function RunDueTimers(targetMs)
    running = true
    while true do
        local nextIndex
        for index, timer in ipairs(timers) do
            if timer.dueMs <= targetMs and not timer.deferred then
                if not nextIndex or RunsBefore(timer, timers[nextIndex]) then
                    nextIndex = index
                end
            end
        end
        if not nextIndex then
            running = false
            return
        end
        local timer = table.remove(timers, nextIndex)
        if timer.dueMs > elapsedMs then
            elapsedMs = timer.dueMs
        end
        if not timer.cancelled then
            timer.fn()
        end
    end
end

-- A zero-delay timer created while timers run waits for the next Advance, as a
-- callback scheduled with C_Timer.After(0) runs on a later frame (from memory,
-- not covered by a live check).
local function AddTimer(seconds, fn)
    timerSeq = timerSeq + 1
    local timer = {
        dueMs = elapsedMs + ToMs(seconds),
        seq = timerSeq,
        fn = fn,
        cancelled = false,
        deferred = running and ToMs(seconds) == 0,
    }
    timers[#timers + 1] = timer
    return timer
end

-- The handle's methods take self, as the client's do (from memory, live check
-- L63).
local TimerHandle = {}
TimerHandle.__index = TimerHandle

-- The timer record of each handle, out of reach of other files.
local handleTimers = {}

function TimerHandle:Cancel()
    handleTimers[self].cancelled = true
end

function TimerHandle:IsCancelled()
    return handleTimers[self].cancelled
end

C_Timer = {
    After = function(seconds, fn)
        AddTimer(seconds, fn)
    end,
    NewTimer = function(seconds, fn)
        local handle = setmetatable({}, TimerHandle)
        handleTimers[handle] = AddTimer(seconds, fn)
        return handle
    end,
}

C_AddOns = {
    GetAddOnMetadata = function(addon, field)
        return metadata[addon] and metadata[addon][field]
    end,
}

-- A frame that can take events and an OnEvent script, which is all the addon
-- needs of one. Confidence: from memory; the names RegisterEvent and
-- SetScript("OnEvent", fn) are an API guess, checked in game.
function CreateFrame(frameType, name)
    local frame = { frameType = frameType, name = name, events = {}, scripts = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:IsEventRegistered(event)
        return self.events[event] or false
    end
    function frame:SetScript(scriptName, fn)
        self.scripts[scriptName] = fn
    end
    function frame:GetScript(scriptName)
        return self.scripts[scriptName]
    end
    frames[#frames + 1] = frame
    return frame
end

local function CharacterClass(set)
    return "[" .. string.gsub(set, "[%^%]%-%%]", "%%%0") .. "]"
end

-- The client's string helpers (not part of Lua 5.1). Confidence: from memory;
-- strsplit treats each character of the delimiter as a separator.
function strsplit(delimiter, text, pieces)
    local result = {}
    local position = 1
    local separator = CharacterClass(delimiter)
    while not pieces or #result < pieces - 1 do
        local first, last = string.find(text, separator, position)
        if not first then
            break
        end
        result[#result + 1] = string.sub(text, position, first - 1)
        position = last + 1
    end
    result[#result + 1] = string.sub(text, position)
    return unpack(result)
end

function strtrim(text, chars)
    local pattern = CharacterClass(chars or " \t\r\n")
    local first = 1
    local last = #text
    while first <= last and string.find(string.sub(text, first, first), pattern) do
        first = first + 1
    end
    while last >= first and string.find(string.sub(text, last, last), pattern) do
        last = last - 1
    end
    return string.sub(text, first, last)
end

function wipe(target)
    for key in pairs(target) do
        target[key] = nil
    end
    return target
end

-- Chat output is captured; LootLogic's chat printer (Core/Log.lua) uses one of
-- these two. Confidence: from memory (API guess), checked in game.
local function AddChatLine(text)
    chatLines[#chatLines + 1] = text
end

function print(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring((select(index, ...)))
    end
    AddChatLine(table.concat(parts, " "))
end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, text)
        AddChatLine(text)
    end,
}

-- The current character. UnitName returns the first and the last name
-- (confirmed by the team in beta play, live check L2) and GetRealmName the
-- region (unverified, L3). UnitFactionGroup (English faction, then the local
-- name), UnitClass (class name, then token), UnitRace (race name, token, then
-- numeric ID), UnitLevel and GetBuildInfo (version, then build number) are from
-- memory, with no live check yet.
local player = {
    first = "Zugar",
    last = "Soulsour",
    realm = "Region",
    faction = "Horde",
    factionName = "Horde (local)",
    class = "WARLOCK",
    className = "Warlock",
    race = "Orc",
    raceToken = "Orc",
    raceID = 2,
    level = 60,
    version = "1.60.1",
    build = "12345",
}

function UnitName(unit)
    if unit ~= "player" then
        return nil
    end
    return player.first, player.last
end

function GetRealmName()
    return player.realm
end

function UnitFactionGroup(unit)
    if unit ~= "player" then
        return nil
    end
    return player.faction, player.factionName
end

function UnitClass(unit)
    if unit ~= "player" then
        return nil
    end
    return player.className, player.class
end

function UnitRace(unit)
    if unit ~= "player" then
        return nil
    end
    return player.race, player.raceToken, player.raceID
end

function UnitLevel(unit)
    if unit ~= "player" then
        return nil
    end
    return player.level
end

function GetBuildInfo()
    return player.version, player.build, "Jan 1 2026", 16001
end

--- Changes the current character. A field not in the table keeps its value; a
--- field set to false is removed (a missing last name, for example).
-- @param fields table first, last, realm, faction, factionName, class,
-- className, race, raceToken, raceID, level, version, build
function Stub.SetPlayer(fields)
    for name, value in pairs(fields) do
        if value == false then
            player[name] = nil
        else
            player[name] = value
        end
    end
end

--- Moves the manual clock forward and runs the timers that fall due.
-- @param seconds number
function Stub.Advance(seconds)
    for _, timer in ipairs(timers) do
        timer.deferred = false
    end
    local targetMs = elapsedMs + ToMs(seconds)
    RunDueTimers(targetMs)
    elapsedMs = targetMs
end

--- Sets the zone offset used by date() and time(dateTable).
-- @param seconds number offset from UTC in seconds
function Stub.SetTimeOffset(seconds)
    offset = seconds
end

--- Sets a TOC field that C_AddOns.GetAddOnMetadata returns.
-- @param addon string
-- @param field string
-- @param value string
function Stub.SetAddOnMetadata(addon, field, value)
    metadata[addon] = metadata[addon] or {}
    metadata[addon][field] = value
end

-- Secret values. The client's issecretvalue is a global function (source-read,
-- technical findings 7.5; live check L25); the stub marks opaque tokens.
local secrets = {}

function issecretvalue(value)
    return secrets[value] or false
end

--- Returns a new opaque token that issecretvalue reports as true.
-- @treturn table
function Stub.MakeSecret()
    local token = {}
    secrets[token] = true
    return token
end

--- Fires an event on every frame registered for it.
-- @param event string
-- @param ... any the event arguments
function Stub.FireEvent(event, ...)
    for _, frame in ipairs(frames) do
        local handler = frame.scripts.OnEvent
        if frame.events[event] and handler then
            handler(frame, event, ...)
        end
    end
end

--- The chat lines printed so far (the live list).
-- @treturn table list of strings
function Stub.ChatLines()
    return chatLines
end

--- Forgets the captured chat lines, keeping the same list.
function Stub.ClearChat()
    wipe(chatLines)
end

-- The Equipment Manager. C_EquipmentSet.GetEquipmentSetIDs, GetEquipmentSetInfo
-- (the name first), GetItemIDs and GetItemLocations are unverified (technical
-- findings 9.1; live check L1). A place table of a set is turned into an opaque
-- location number that EquipmentManager_UnpackLocation reads back; the real
-- values are bit flags (from memory).
local equipmentSets = {}
local places = {}
local placeSeq = 1000
local wornLinks = {}
local bagLinks = {}

function Stub.SetEquipmentSets(list)
    equipmentSets = {}
    places = {}
    for _, set in ipairs(list) do
        local locations = {}
        for slot, place in pairs(set.places or {}) do
            if type(place) == "table" then
                placeSeq = placeSeq + 1
                places[placeSeq] = place
                locations[slot] = placeSeq
            else
                locations[slot] = place
            end
        end
        equipmentSets[#equipmentSets + 1] = {
            id = set.id,
            name = set.name,
            items = set.items or {},
            locations = locations,
            noLocations = set.noLocations,
        }
    end
end

local function FindSet(setID)
    for _, set in ipairs(equipmentSets) do
        if set.id == setID then
            return set
        end
    end
    return nil
end

C_EquipmentSet = {
    GetEquipmentSetIDs = function()
        local ids = {}
        for _, set in ipairs(equipmentSets) do
            ids[#ids + 1] = set.id
        end
        return ids
    end,
    GetEquipmentSetInfo = function(setID)
        local set = FindSet(setID)
        return set.name, 134400, setID
    end,
    GetItemIDs = function(setID)
        return FindSet(setID).items
    end,
    GetItemLocations = function(setID)
        local set = FindSet(setID)
        if set.noLocations then
            return nil
        end
        return set.locations
    end,
}

-- Returns player, bank, bags, voidStorage, slot, bag (from memory; live check
-- L1).
function EquipmentManager_UnpackLocation(location)
    local place = places[location]
    if not place then
        return false, false, false, false
    end
    if place.where == "worn" then
        return true, false, false, false, place.slot
    elseif place.where == "bag" then
        return true, false, true, false, place.slot, place.bag
    end
    return true, true, true, false, place.slot, place.bag
end

function Stub.SetWornLink(slot, link)
    wornLinks[slot] = link
end

function GetInventoryItemLink(unit, slot)
    if unit ~= "player" then
        return nil
    end
    return wornLinks[slot]
end

function Stub.SetBagLink(bag, slot, link)
    bagLinks[bag .. ":" .. slot] = link
end

-- Bag contents. GetContainerNumSlots and GetContainerItemInfo (a table with
-- itemID, hyperlink and stackCount) are from memory (live checks L7 and L14).
local bagSizes = {}
local bagItems = {}

function Stub.SetBagSize(bag, size)
    bagSizes[bag] = size
end

--- Sets or clears (item nil) one bag slot; also the link GetContainerItemLink
--- gives.
-- @param bag number
-- @param slot number
-- @param item table|nil { itemID, link, count }
function Stub.SetBagItem(bag, slot, item)
    bagItems[bag .. ":" .. slot] = item
    bagLinks[bag .. ":" .. slot] = item and item.link
end

C_Container = {
    GetContainerItemLink = function(bag, slot)
        return bagLinks[bag .. ":" .. slot]
    end,
    GetContainerNumSlots = function(bag)
        return bagSizes[bag] or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local item = bagItems[bag .. ":" .. slot]
        if not item then
            return nil
        end
        return { itemID = item.itemID, hyperlink = item.link, stackCount = item.count or 1 }
    end,
}

-- Enum.BagIndex: no Bank member, bank tabs 6 to 14 (technical findings 5;
-- live check L14).
local bagIndex = {
    Backpack = 0,
    Bag_1 = 1,
    Bag_2 = 2,
    Bag_3 = 3,
    Bag_4 = 4,
    ReagentBag = 5,
}
for tab = 1, 9 do
    bagIndex["CharacterBankTab_" .. tab] = 5 + tab
end
Enum = { BagIndex = bagIndex }

function Stub.SetBagIndex(name, value)
    bagIndex[name] = value
end

--- Fires BANKFRAME_OPENED.
function Stub.OpenBank()
    Stub.FireEvent("BANKFRAME_OPENED")
end

--- Fires BANKFRAME_CLOSED.
function Stub.CloseBank()
    Stub.FireEvent("BANKFRAME_CLOSED")
end

-- C_Item.GetItemInfoInstant returns the item ID, type, subtype, equipLoc,
-- icon, classID and subclassID; it accepts a link (from memory, technical
-- findings 7.1; live check L8). An item with no fields set is unknown (nil).
local instants = {}

--- Sets what GetItemInfoInstant gives for an item ID.
-- @param itemID number
-- @param fields table equipLoc (such as "INVTYPE_CHEST"), classID, subclassID
function Stub.SetItemInstant(itemID, fields)
    instants[itemID] = fields
end

C_Item = {
    GetItemInfoInstant = function(item)
        local itemID = item
        if type(item) == "string" then
            itemID = tonumber(string.match(item, "item:(%d+)"))
        end
        local fields = instants[itemID]
        if not fields then
            return nil
        end
        return itemID, nil, nil, fields.equipLoc or "", 134400, fields.classID, fields.subclassID
    end,
}

-- IsPlayerSpell is from memory (live check L6).
local knownSpells = {}

--- Sets the spell IDs IsPlayerSpell reports as known.
-- @param list table list of spell IDs
function Stub.SetKnownSpells(list)
    knownSpells = {}
    for _, spellID in ipairs(list) do
        knownSpells[spellID] = true
    end
end

function IsPlayerSpell(spellID)
    return knownSpells[spellID] or false
end

-- Mail. GetInboxNumItems (the mail count, then the total), GetInboxItem (name,
-- itemID, texture, count, quality, canUse), GetInboxItemLink,
-- GetSendMailItem (name, itemID, texture, count, quality), GetSendMailItemLink,
-- SendMail (recipient, subject, body) and the two attachment limits are from
-- memory (live checks L13 and L49).
ATTACHMENTS_MAX_SEND = 12
ATTACHMENTS_MAX_RECEIVE = 16

local inbox = {}
local sendItems = {}

local function ItemIDOf(link)
    return tonumber(string.match(link, "item:(%d+)"))
end

--- Sets the inbox: a list of mails, each { items = { { link, count }, ... } }.
-- @param mails table
function Stub.SetInbox(mails)
    inbox = mails
end

--- Sets the attachments of the mail being written: a list of { link, count }.
-- @param items table
function Stub.SetSendMailItems(items)
    sendItems = items
end

function GetInboxNumItems()
    return #inbox, #inbox
end

function GetInboxItem(mail, attachment)
    local item = inbox[mail] and inbox[mail].items[attachment]
    if not item then
        return nil
    end
    return "Item", ItemIDOf(item.link), 134400, item.count or 1, 1, true
end

function GetInboxItemLink(mail, attachment)
    local item = inbox[mail] and inbox[mail].items[attachment]
    return item and item.link
end

function GetSendMailItem(index)
    local item = sendItems[index]
    if not item then
        return nil
    end
    return "Item", ItemIDOf(item.link), 134400, item.count or 1, 1
end

function GetSendMailItemLink(index)
    local item = sendItems[index]
    return item and item.link
end

-- The client sends the mail; the stub does nothing, so a test fires
-- MAIL_SEND_SUCCESS or MAIL_FAILED itself.
function SendMail() end

-- hooksecurefunc(name, hook) and hooksecurefunc(table, name, hook): the hook
-- runs after the original with the same arguments (from memory; live check
-- L13).
function hooksecurefunc(first, second, third)
    local target = _G
    local name = first
    local hook = second
    if type(first) == "table" then
        target = first
        name = second
        hook = third
    end
    local original = target[name]
    target[name] = function(...)
        local results = { original(...) }
        hook(...)
        return unpack(results)
    end
end

-- Scripted tooltips. C_TooltipInfo.GetHyperlink(link).lines, each with
-- leftText, is source-read on Forever for the call (technical findings 7.1);
-- the field name is from memory.
local tooltips = {}
local tooltipCalls = 0

ITEM_SPELL_KNOWN = "Already known"

function Stub.SetTooltipLines(link, lines)
    local built = {}
    for index, text in ipairs(lines) do
        built[index] = { leftText = text }
    end
    tooltips[link] = { lines = built }
end

function Stub.SetItemSpellKnown(text)
    ITEM_SPELL_KNOWN = text
end

function Stub.TooltipCalls()
    return tooltipCalls
end

C_TooltipInfo = {
    GetHyperlink = function(link)
        tooltipCalls = tooltipCalls + 1
        return tooltips[link]
    end,
}

-- Outfitter Forever: Outfitter.Settings.Outfits and
-- Outfitter:RegisterOutfitEvent are source-read;
-- gOutfitter_GlobalSettings.Characters["First-Realm"] is source-read
-- (technical findings 9.1; live check L29).
local outfitterHandlers = {}

function Stub.SetOutfitter(settings)
    outfitterHandlers = {}
    Outfitter = {
        Settings = settings,
        RegisterOutfitEvent = function(_, event, fn)
            outfitterHandlers[event] = outfitterHandlers[event] or {}
            table.insert(outfitterHandlers[event], fn)
        end,
    }
end

function Stub.RemoveOutfitter()
    Outfitter = nil
    outfitterHandlers = {}
end

function Stub.SetOutfitterGlobal(characters)
    gOutfitter_GlobalSettings = { Characters = characters }
end

function Stub.FireOutfitterEvent(event, ...)
    for _, fn in ipairs(outfitterHandlers[event] or {}) do
        fn(...)
    end
end

function Stub.OutfitterHandlerCount(event)
    return #(outfitterHandlers[event] or {})
end

return Stub
