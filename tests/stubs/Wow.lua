--[[
The fake WoW client for the offline tests. run.py loads this chunk first in a
fresh Lua runtime; it defines the client globals the addon reads and returns the
control table that tests receive as h.Stub.

Setters of h.Stub (keep this list in step with the code below):
  Advance(seconds)        move the one manual clock forward, running due timers
  JumpClock(seconds)      move the manual clock forward without running timers
                          (a frame that stalled; the next Advance runs them)
  SetTimeOffset(seconds)  zone offset used by date() and time(dateTable)
                          (default 0, UTC)
  SetAddOnMetadata(addon, field, value)
                          value C_AddOns.GetAddOnMetadata returns for an addon
  SetPlayer(fields)       change the current character; fields (all optional):
                          first, last, realm, faction, factionName, class
                          (token), className, race (name), raceToken, raceID,
                          level, version, build
  SetUnknownEvents(names) event names RegisterEvent raises for (a name the
                          client does not know; API guess)
  MakeSecret()            a new token that issecretvalue reports as true
  FireEvent(event, ...)   fire an event on every frame registered for it
  Frames()                the frames CreateFrame has made so far (the live
                          list); a named frame is also a global
  SetPopupShown(index, shown)
                          show or hide StaticPopup1 to StaticPopup4
  PressEscape()           hide each shown frame named in UISpecialFrames
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
                          list; each entry is a string, the left text, or
                          { left = <text>, right = <text> }); no call, no
                          tooltip (nil)
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
                          one bag slot, item = { itemID, link, count, quality,
                          bound, hasNoValue, isQuest, refundSeconds }, or nil
                          to empty it; also the link GetContainerItemLink gives
  SetBagIndex(name, value)
                          change a member of Enum.BagIndex
  SetCombat(on)           whether InCombatLockdown reports combat (boolean;
                          default false)
  SetProfileStep(ms)      milliseconds added to debugprofilestop at every call
                          (default 0), so a test can make a pass take time
  AdvanceProfile(ms)      add milliseconds to debugprofilestop once
  OpenBank()              fire BANKFRAME_OPENED
  CloseBank()             fire BANKFRAME_CLOSED
  SetItemInstant(itemID, fields)
                          what C_Item.GetItemInfoInstant gives: equipLoc,
                          classID, subclassID
  SetKnownSpells(list)    the spell IDs IsPlayerSpell reports as known
  SetCanUseItem(itemID, answer)
                          script the live usability answer (boolean)
  SetCanUseAPI(enabled)   enable or remove the optional live usability API
                          (boolean)
  CanUseItemCalls()       item IDs passed to the live usability API
  SetItem(itemID, fields) an item the client knows: name, link, quality,
                          itemLevel, reqLevel, sellPrice, bindType, equipLoc,
                          classID, subclassID, stack, stats (a table of
                          ITEM_MOD_* keys to values), unique (boolean),
                          accountBound (what IsBoundToAccountUntilEquip gives);
                          also sets what GetItemInfoInstant gives
  SetItemPending(itemID, fields)
                          as SetItem, but GetItemInfo, GetItemStats and
                          GetDetailedItemLevelInfo give nil until LoadItem
  LoadItem(itemID)        the item's data arrives: fires GET_ITEM_INFO_RECEIVED
                          and ITEM_DATA_LOAD_RESULT with (itemID, true)
  ItemRequests(itemID)    how many times GetItemInfo was called for the item
                          while its data was missing
  SetUniquenessApi(on)    whether C_Item.GetItemUniquenessByID exists
  SetLoadOnRequest(itemID)
                          the next C_Item.GetItemInfo call for the item fires
                          ITEM_DATA_LOAD_RESULT (itemID, true) inside the call,
                          then returns as usual (nil while the item is pending;
                          L28, an event before the wait)
  SetString(name, value)  a client global string such as ITEM_UNIQUE (nil
                          removes it)
  SetNewTimer(on)         whether C_Timer.NewTimer exists (default true; L63)
  SetCancelStops(on)      whether a timer's Cancel stops it (default true; false
                          lets a cancelled timer still fire, L63)
  SetItemExists(itemID, answer)
                          what C_Item.DoesItemExistByID gives for an item
                          (default: true for an item the stub knows, else false)
  SetExistsApi(mode)      "on" (default), "off" (the call is missing) or "raise"
                          (the call raises an error; L58)
  SetAccountBoundApi(on)  whether C_Item.IsBoundToAccountUntilEquip exists (L24)
  SetUniquenessNothing(on)
                          GetItemUniquenessByID returns no value (L21)
  SetGlobal(name, value)  set or clear (nil) any global, such as EUI_Bags,
                          Auctionator, AuctionDB, ContainerFrame1,
                          GetNumTalentTabs
  MakeAuctionatorV1(prices, ages)
                          an Auctionator.API.v1 fake: price and age per item ID;
                          its calls are listed by AuctionatorCalls()
  FireAuctionatorUpdate() fire the callback registered by Auctionator
  MakeTooltip(name, info, owner) scripted tooltip for Stage 3 display tests
  FireTooltip(tooltip)      run TooltipDataProcessor callbacks for the tooltip
  SetAuctionator(v1)      install the Auctionator global with API.v1 = v1 (nil:
                          API has no v1)
  AuctionatorCalls()      list of { name, callerID, itemID } of the fake's calls
  SetLibStub(betterBags)  install LibStub with an AceAddon-3.0 fake; betterBags
                          is nil (no BetterBags) or { categories = <table>,
                          raises = <text> } (GetModule gives it or raises)
  SetBankApi(canUse)      install C_Bank.CanUseBank (giving canUse) and
                          Enum.BankType; nil removes both (L33)
  SetTalentTabs(tabs)     install GetNumTalentTabs and GetTalentTabInfo; tabs is
                          a list of lists of the values GetTalentTabInfo returns
                          for each tab (a list may set n to hold trailing nils);
                          nil removes both (L48)
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
local shiftDown = false

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

local cancelStops = true

function TimerHandle:Cancel()
    if cancelStops then
        handleTimers[self].cancelled = true
    end
end

function TimerHandle:IsCancelled()
    return handleTimers[self].cancelled
end

local function NewTimer(seconds, fn)
    local handle = setmetatable({}, TimerHandle)
    handleTimers[handle] = AddTimer(seconds, fn)
    return handle
end

C_Timer = {
    After = function(seconds, fn)
        AddTimer(seconds, fn)
    end,
    NewTimer = NewTimer,
}

--- Sets whether C_Timer.NewTimer exists (the client may lack it, L63).
-- @param on boolean
function Stub.SetNewTimer(on)
    if on then
        C_Timer.NewTimer = NewTimer
    else
        C_Timer.NewTimer = nil
    end
end

--- Sets whether a timer's Cancel stops it. False lets a cancelled timer fire,
--- the failure L63 reports.
-- @param on boolean
function Stub.SetCancelStops(on)
    cancelStops = on
end

C_AddOns = {
    GetAddOnMetadata = function(addon, field)
        return metadata[addon] and metadata[addon][field]
    end,
}

-- Event names RegisterEvent refuses (what a client may do with a name it does
-- not know; from memory, unverified).
local unknownEvents = {}

--- Makes RegisterEvent raise for the given event names from now on.
-- @param names table list of event names
function Stub.SetUnknownEvents(names)
    unknownEvents = {}
    for _, name in ipairs(names) do
        unknownEvents[name] = true
    end
end

-- Frames. An event frame needs RegisterEvent and SetScript("OnEvent", fn); the
-- Welcome dialog needs the rest of the methods below. Every method here is an
-- API guess checked in game (live check L43 for the dialog's calls). A client
-- method the code uses but the stub lacks fails the test with a nil call, so
-- the stub grows only with the code. A named frame also becomes a global, as
-- the client does (API guess).
local Methods = {}
Methods.__index = Methods

local function RunScript(frame, scriptName, ...)
    local fn = frame.scripts[scriptName]
    if fn then
        fn(frame, ...)
    end
end

-- A parent that hides runs OnHide on its children that are still shown, and
-- they keep their own shown state (API guess; L43).
local function ParentHidden(frame)
    if not frame.shown then
        return
    end
    RunScript(frame, "OnHide")
    for _, child in ipairs(frame.children) do
        ParentHidden(child)
    end
end

function Methods:RegisterEvent(event)
    if unknownEvents[event] then
        error("Frame:RegisterEvent(): Unknown event: " .. event)
    end
    self.events[event] = true
end

function Methods:UnregisterEvent(event)
    self.events[event] = nil
end

function Methods:IsEventRegistered(event)
    return self.events[event] or false
end

function Methods:SetScript(scriptName, fn)
    self.scripts[scriptName] = fn
end

function Methods:GetScript(scriptName)
    return self.scripts[scriptName]
end

function Methods:Show()
    if not self.shown then
        self.shown = true
        RunScript(self, "OnShow")
    end
end

function Methods:Hide()
    if self.shown then
        self.shown = false
        RunScript(self, "OnHide")
        for _, child in ipairs(self.children) do
            ParentHidden(child)
        end
    end
end

function Methods:IsShown()
    return self.shown
end

function Methods:GetParent()
    return self.parent
end

function Methods:Click()
    RunScript(self, "OnClick", "LeftButton", false)
end

function Methods:SetSize(width, height)
    self.width, self.height = width, height
end

function Methods:SetWidth(width)
    self.width = width
end

function Methods:SetPoint(...)
    table.insert(self.points, { ... })
end

function Methods:SetFrameStrata(strata)
    self.strata = strata
end

function Methods:GetFrameStrata()
    return self.strata
end

function Methods:SetMovable(on)
    self.movable = on
end

function Methods:IsMovable()
    return self.movable
end

function Methods:EnableMouse(on)
    self.mouse = on
end

function Methods:EnableKeyboard(on)
    self.keyboard = on
end

function Methods:IsKeyboardEnabled()
    return self.keyboard
end

function Methods:RegisterForDrag(...)
    self.dragButtons = { ... }
end

function Methods:StartMoving()
    self.moving = true
end

function Methods:StopMovingOrSizing()
    self.moving = false
end

function Methods:SetClampedToScreen(on)
    self.clamped = on
end

function Methods:SetBackdrop(backdrop)
    self.backdrop = backdrop
end

function Methods:SetUserPlaced(on)
    self.userPlaced = on
end

function Methods:SetText(text)
    self.text = text
end

function Methods:GetText()
    return self.text
end

function Methods:SetJustifyH(justify)
    self.justifyH = justify
end

function Methods:SetWordWrap(on)
    self.wordWrap = on
end

function Methods:CreateFontString(_, layer, font)
    local region = setmetatable({
        regionType = "FontString",
        layer = layer,
        font = font,
        parent = self,
        points = {},
        scripts = {},
        children = {},
    }, Methods)
    table.insert(self.regions, region)
    return region
end

function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        events = {},
        scripts = {},
        children = {},
        regions = {},
        points = {},
        shown = true,
        keyboard = false,
    }, Methods)
    if parent then
        table.insert(parent.children, frame)
    end
    if name then
        _G[name] = frame
    end
    frames[#frames + 1] = frame
    return frame
end

--- The frames created so far, the event frames included (the live list).
-- @treturn table list of frames
function Stub.Frames()
    return frames
end

UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}

-- The client's own dialogs, hidden until a test shows one (from memory; L43).
for index = 1, 4 do
    CreateFrame("Frame", "StaticPopup" .. index, UIParent):Hide()
end

--- Shows or hides one of the client's dialogs StaticPopup1 to StaticPopup4.
-- @param index number 1 to 4
-- @param shown boolean
function Stub.SetPopupShown(index, shown)
    local popup = _G["StaticPopup" .. index]
    if shown then
        popup:Show()
    else
        popup:Hide()
    end
end

--- Presses Escape: hides each shown frame named in UISpecialFrames, as the
--- client is assumed to do (API guess; L43).
function Stub.PressEscape()
    for _, name in ipairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end
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

--- Moves the manual clock forward without running any timer, as a client frame
-- that stalled would; a later Advance runs the timers that fell due.
-- @param seconds number
function Stub.JumpClock(seconds)
    elapsedMs = elapsedMs + ToMs(seconds)
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

--- Sets the aggregate Shift state used by Shift tooltip tests.
function Stub.SetShiftDown(value)
    shiftDown = value == true
end

function IsShiftKeyDown()
    return shiftDown
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
        return {
            itemID = item.itemID,
            hyperlink = item.link,
            stackCount = item.count or 1,
            quality = item.quality,
            isBound = item.bound,
            hasNoValue = item.hasNoValue,
        }
    end,
    -- The quest info table with isQuestItem and the purchase info table with
    -- refundSeconds are from memory (live checks L7 and L55).
    GetContainerItemQuestInfo = function(bag, slot)
        local item = bagItems[bag .. ":" .. slot]
        if not item then
            return nil
        end
        return { isQuestItem = item.isQuest or false, isActive = false }
    end,
    GetContainerItemPurchaseInfo = function(bag, slot)
        local item = bagItems[bag .. ":" .. slot]
        if not item or not item.refundSeconds then
            return nil
        end
        return { money = 0, itemCount = 0, refundSeconds = item.refundSeconds }
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
Enum = { BagIndex = bagIndex, TooltipDataType = { Item = 1 } }

GREEN_FONT_COLOR = { r = 0.1, g = 1, b = 0.1 }
GOLD_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
ORANGE_FONT_COLOR = { r = 1, g = 0.5, b = 0 }
BLUE_FONT_COLOR = { r = 0.25, g = 0.78, b = 0.92 }
YELLOW_FONT_COLOR = { r = 1, g = 0.95, b = 0.2 }
MAGENTA_FONT_COLOR = { r = 1, g = 0.1, b = 0.7 }
RED_FONT_COLOR = { r = 1, g = 0.125, b = 0.125 }
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PRIEST = { r = 1, g = 1, b = 1 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    DRUID = { r = 1, g = 0.49, b = 0.04 },
}

function GetCVarBool(name)
    return name == "colorblindMode" and false or false
end

local iconFiles = {
    ["Interface\\Icons\\INV_Sword_04"] = 135274,
    ["Interface\\Icons\\INV_Misc_Coin_01"] = 133784,
    ["Interface\\Icons\\INV_Misc_Coin_02"] = 133785,
    ["Interface\\Icons\\INV_Misc_QuestionMark"] = 134400,
}

function GetFileIDFromPath(path)
    return iconFiles[path]
end

function Stub.SetIconPath(path, fileID)
    iconFiles[path] = fileID
end

function Stub.SetBagIndex(name, value)
    bagIndex[name] = value
end

-- InCombatLockdown and debugprofilestop. The profile clock is a counter in
-- milliseconds that moves only when a test moves it (confidence: from memory;
-- debugprofilestop gives milliseconds as a number).
local inCombat = false
local profileMs = 0
local profileStep = 0

function InCombatLockdown()
    return inCombat
end

function debugprofilestop()
    profileMs = profileMs + profileStep
    return profileMs
end

--- Sets whether InCombatLockdown reports combat.
-- @param on boolean
function Stub.SetCombat(on)
    inCombat = on
end

--- Sets the milliseconds debugprofilestop adds at every call.
-- @param ms number
function Stub.SetProfileStep(ms)
    profileStep = ms
end

--- Adds milliseconds to the profile clock once.
-- @param ms number
function Stub.AdvanceProfile(ms)
    profileMs = profileMs + ms
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
-- C_Item.GetItemInfo gives nil while the item is pending or unknown (from
-- memory; live check L28), and its values come in the client's order: name,
-- link, quality, item level, required level, type, subtype, stack size,
-- equipLoc, icon, sell price, classID, subclassID, bindType.
local instants = {}
local itemFields = {}
local pendingItems = {}
local itemRequests = {}

local function ItemIDOfItem(item)
    if type(item) == "string" then
        return tonumber(string.match(item, "item:(%d+)"))
    end
    return item
end

--- Sets what GetItemInfoInstant gives for an item ID.
-- @param itemID number
-- @param fields table equipLoc (such as "INVTYPE_CHEST"), classID, subclassID
function Stub.SetItemInstant(itemID, fields)
    instants[itemID] = fields
end

--- Defines an item the client has loaded (see the list at the top).
-- @param itemID number
-- @param fields table
function Stub.SetItem(itemID, fields)
    itemFields[itemID] = fields
    pendingItems[itemID] = nil
    instants[itemID] = {
        equipLoc = fields.equipLoc,
        classID = fields.classID,
        subclassID = fields.subclassID,
    }
end

--- Defines an item whose data has not arrived yet.
-- @param itemID number
-- @param fields table
function Stub.SetItemPending(itemID, fields)
    Stub.SetItem(itemID, fields)
    pendingItems[itemID] = true
end

--- The data of a pending item arrives: both item-data events fire.
-- @param itemID number
function Stub.LoadItem(itemID)
    pendingItems[itemID] = nil
    Stub.FireEvent("GET_ITEM_INFO_RECEIVED", itemID, true)
    Stub.FireEvent("ITEM_DATA_LOAD_RESULT", itemID, true)
end

--- How many times GetItemInfo was called for the item while it was pending.
-- @param itemID number
-- @treturn number
function Stub.ItemRequests(itemID)
    return itemRequests[itemID] or 0
end

-- The fields of a loaded item, or nil (counting a request when asked) while it
-- is pending or unknown.
local function LoadedItem(item, countRequest)
    local itemID = ItemIDOfItem(item)
    local fields = itemFields[itemID]
    if fields and not pendingItems[itemID] then
        return fields, itemID
    end
    if countRequest then
        itemRequests[itemID] = (itemRequests[itemID] or 0) + 1
    end
    return nil, itemID
end

local loadOnRequest = {}

--- The next GetItemInfo call for the item fires ITEM_DATA_LOAD_RESULT (itemID,
--- true) inside the call, then returns as usual (nil while the item is
--- pending).
-- @param itemID number
function Stub.SetLoadOnRequest(itemID)
    loadOnRequest[itemID] = true
end

local uniquenessNothing = false

local function GetItemUniquenessByID(item)
    if uniquenessNothing then
        return
    end
    local fields = LoadedItem(item, false)
    return fields and fields.unique or false
end

--- Makes GetItemUniquenessByID return no value at all (live check L21).
-- @param on boolean
function Stub.SetUniquenessNothing(on)
    uniquenessNothing = on
end

-- C_Item.DoesItemExistByID answers at once, without the item being loaded
-- (from memory, technical findings 13; live check L58).
local existsAnswers = {}
local existsMode = "on"

local function DoesItemExistByID(itemID)
    if existsMode == "raise" then
        error("DoesItemExistByID failed", 0)
    end
    local answer = existsAnswers[itemID]
    if answer ~= nil then
        return answer
    end
    return itemFields[itemID] ~= nil
end

--- Scripts the answer of C_Item.DoesItemExistByID for one item.
-- @param itemID number
-- @param answer boolean
function Stub.SetItemExists(itemID, answer)
    existsAnswers[itemID] = answer
end

local itemClassNames = { [0] = "Consumable", [4] = "Armor", [7] = "Trade Goods" }
local itemSubclassNames = {
    [4] = { [1] = "Cloth" },
    [7] = { [5] = "Cloth", [7] = "Metal and Stone", [11] = "Other" },
}

function Stub.SetItemTypeNames(classes, subclasses)
    itemClassNames = classes
    itemSubclassNames = subclasses
end

C_Item = {
    GetItemClassInfo = function(class)
        return itemClassNames[class]
    end,
    GetItemSubClassInfo = function(class, subclass)
        local names = itemSubclassNames[class]
        return names and names[subclass]
    end,
    GetItemInfoInstant = function(item)
        local itemID = ItemIDOfItem(item)
        local fields = instants[itemID]
        if not fields then
            return nil
        end
        return itemID, nil, nil, fields.equipLoc or "", 134400, fields.classID, fields.subclassID
    end,
    GetItemInfo = function(item)
        local fields, itemID = LoadedItem(item, true)
        if loadOnRequest[itemID] then
            loadOnRequest[itemID] = nil
            Stub.FireEvent("ITEM_DATA_LOAD_RESULT", itemID, true)
        end
        if not fields then
            return nil
        end
        return fields.name or ("Item " .. itemID),
            fields.link or ("item:" .. itemID),
            fields.quality or 1,
            fields.itemLevel or 1,
            fields.reqLevel or 0,
            "Armor",
            "Cloth",
            fields.stack or 1,
            fields.equipLoc or "",
            134400,
            fields.sellPrice or 0,
            fields.classID,
            fields.subclassID,
            fields.bindType or 0
    end,
    GetItemStats = function(item)
        local fields = LoadedItem(item, false)
        if not fields then
            return nil
        end
        local copy = {}
        for key, value in pairs(fields.stats or {}) do
            copy[key] = value
        end
        return copy
    end,
    GetDetailedItemLevelInfo = function(item)
        local fields = LoadedItem(item, false)
        if not fields then
            return nil
        end
        return fields.itemLevel or 1, false, fields.itemLevel or 1
    end,
    -- The location argument and the bag-slot form are from memory (live check
    -- L24).
    IsBoundToAccountUntilEquip = function(location)
        local item = bagItems[location.bag .. ":" .. location.slot]
        local fields = item and itemFields[item.itemID]
        return fields and fields.accountBound or false
    end,
    GetItemUniquenessByID = GetItemUniquenessByID,
    DoesItemExistByID = DoesItemExistByID,
}

local isBoundToAccountUntilEquip = C_Item.IsBoundToAccountUntilEquip

--- Sets whether C_Item.IsBoundToAccountUntilEquip exists (live check L24).
-- @param on boolean
function Stub.SetAccountBoundApi(on)
    if on then
        C_Item.IsBoundToAccountUntilEquip = isBoundToAccountUntilEquip
    else
        C_Item.IsBoundToAccountUntilEquip = nil
    end
end

--- Chooses how C_Item.DoesItemExistByID behaves: "on", "off" (missing) or
--- "raise" (raises an error).
-- @param mode string
function Stub.SetExistsApi(mode)
    existsMode = mode
    if mode == "off" then
        C_Item.DoesItemExistByID = nil
    else
        C_Item.DoesItemExistByID = DoesItemExistByID
    end
end

--- Sets whether C_Item.GetItemUniquenessByID exists (it is optional, live
--- check L21).
-- @param on boolean
function Stub.SetUniquenessApi(on)
    if on then
        C_Item.GetItemUniquenessByID = GetItemUniquenessByID
    else
        C_Item.GetItemUniquenessByID = nil
    end
end

-- ItemLocation:CreateFromBagAndSlot(bag, slot) (source-read on Forever,
-- technical findings 5; the method call form is from memory).
ItemLocation = {
    CreateFromBagAndSlot = function(_, bag, slot)
        return { bag = bag, slot = slot }
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

-- The weapon speed format of the tooltip's "Speed 2.60" line. The wording is
-- the stub's own (from memory, Classic's); live check L22.
WEAPON_SPEED = "Speed %s"

-- Item tooltip strings. The names are source-read or from memory (live checks
-- L21, L51 and L56); the wording of the TOOLTIP_ITEM_STAT_* formats is the
-- stub's own invention, since the client's text is not known yet. The
-- ITEM_SPELL_TRIGGER_* and ITEM_SET_BONUS texts are the Classic ones, from
-- memory.
ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
ITEM_SPELL_TRIGGER_ONUSE = "Use:"
ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:"
ITEM_SET_BONUS = "Set: %s"
ITEM_CLASSES_ALLOWED = "Classes: %s"
ITEM_UNIQUE = "Unique"
ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped"
TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE = "Increases your critical strike chance by %s%%."
TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE = "Increases your hit chance by %s%%."
TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE = "Increases spell power by %d."
LOCALIZED_CLASS_NAMES_MALE = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_MALE

--- Sets or clears any global (a frame, another addon's table, a client
--- function) the test needs to appear or vanish.
-- @param name string
-- @param value any nil removes it
function Stub.SetGlobal(name, value)
    _G[name] = value
end

--- Sets a client global string; nil removes it.
-- @param name string
-- @param value string|nil
function Stub.SetString(name, value)
    _G[name] = value
end

-- Each line of the list is a string (the left text) or { left, right }.
function Stub.SetTooltipLines(link, lines)
    local built = {}
    for index, text in ipairs(lines) do
        -- A secret token is also a table: only a table with a left or right
        -- text is a two-sided line.
        if type(text) == "table" and (text.left or text.right) then
            built[index] = { leftText = text.left, rightText = text.right }
        else
            built[index] = { leftText = text }
        end
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

local tooltipPostCalls = {}

TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, callback)
        tooltipPostCalls[dataType] = tooltipPostCalls[dataType] or {}
        tooltipPostCalls[dataType][#tooltipPostCalls[dataType] + 1] = callback
    end,
}

function Stub.MakeTooltip(name, info, owner, itemLink)
    local tooltip = {
        name = name,
        info = info,
        owner = owner,
        itemLink = itemLink,
        lines = {},
        shown = false,
        scripts = {},
        HookScript = function(self, event, callback)
            self.scripts[event] = self.scripts[event] or {}
            table.insert(self.scripts[event], callback)
        end,
        Hide = function(self)
            self.shown = false
            for _, callback in ipairs(self.scripts.OnHide or {}) do
                callback(self)
            end
        end,
        GetName = function(self)
            return self.name
        end,
        GetOwner = function(self)
            return self.owner
        end,
        GetPrimaryTooltipInfo = function(self)
            return self.info
        end,
        GetItem = function(self)
            return self.itemName, self.itemLink
        end,
        AddLine = function(self, text, red, green, blue)
            self.lines[#self.lines + 1] = {
                text = text,
                color = { r = red, g = green, b = blue },
            }
        end,
        Show = function(self)
            self.shown = true
        end,
        IsShown = function(self)
            return self.shown
        end,
        ClearLines = function(self)
            self.lines = {}
            for _, callback in ipairs(self.scripts.OnTooltipCleared or {}) do
                callback(self)
            end
        end,
        SetBagItem = function(self, bag, slot)
            self.info = { getterName = "GetBagItem", getterArgs = { bag, slot } }
            local item = C_Container.GetContainerItemInfo(bag, slot)
            self.itemLink = item and item.hyperlink
            Stub.FireTooltip(self)
        end,
        SetInventoryItem = function(self, unit, slot)
            self.info = {
                getterName = "GetInventoryItem",
                getterArgs = { unit, slot },
                hyperlink = self.itemLink,
            }
            Stub.FireTooltip(self)
        end,
        SetInboxItem = function(self, mail, attachment)
            self.info = { getterName = "GetInboxItem", getterArgs = { mail, attachment } }
            self.itemLink = GetInboxItemLink(mail, attachment)
            Stub.FireTooltip(self)
        end,
        SetHyperlink = function(self, link)
            self.info = { getterName = "SetHyperlink", getterArgs = { link }, hyperlink = link }
            self.itemLink = link
            Stub.FireTooltip(self)
        end,
    }
    return tooltip
end

function Stub.FireTooltip(tooltip)
    for _, callback in ipairs(tooltipPostCalls[Enum.TooltipDataType.Item] or {}) do
        callback(tooltip)
    end
end

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

-- The optional current-character usability API (from memory; live check L5).
local canUseAnswers = {}
local canUseCalls = {}
C_PlayerInfo = {
    CanUseItem = function(itemID)
        canUseCalls[#canUseCalls + 1] = itemID
        return canUseAnswers[itemID] ~= false
    end,
}

--- Scripts the live usability answer for one item.
-- @param itemID number
-- @param answer boolean
function Stub.SetCanUseItem(itemID, answer)
    canUseAnswers[itemID] = answer
end

--- The item IDs passed to the live usability API.
-- @treturn table
function Stub.CanUseItemCalls()
    return canUseCalls
end

local canUseItem = C_PlayerInfo.CanUseItem

--- Enables or removes the optional live usability API (L5).
-- @param enabled boolean
function Stub.SetCanUseAPI(enabled)
    if enabled then
        C_PlayerInfo.CanUseItem = canUseItem
    else
        C_PlayerInfo.CanUseItem = nil
    end
end

-- The Auctionator fake of technical findings 11.1: Auctionator.API.v1 with
-- GetAuctionPriceByItemID(callerID, itemID) and GetAuctionAgeByItemID(callerID,
-- itemID). Source-read on the beta client; live check L9.
local auctionatorCalls = {}
local auctionatorUpdate

--- Builds an Auctionator.API.v1 fake that answers from the two tables and
--- records each call.
-- @param prices table item ID to copper
-- @param ages table item ID to age in days
-- @treturn table
function Stub.MakeAuctionatorV1(prices, ages)
    auctionatorCalls = {}
    auctionatorUpdate = nil
    return {
        GetAuctionPriceByItemID = function(callerID, itemID)
            auctionatorCalls[#auctionatorCalls + 1] =
                { name = "price", callerID = callerID, itemID = itemID }
            return prices[itemID]
        end,
        GetAuctionPriceByItemLink = function(callerID, link)
            auctionatorCalls[#auctionatorCalls + 1] =
                { name = "link", callerID = callerID, link = link }
            return prices[link]
        end,
        GetAuctionAgeByItemID = function(callerID, itemID)
            auctionatorCalls[#auctionatorCalls + 1] =
                { name = "age", callerID = callerID, itemID = itemID }
            return ages[itemID]
        end,
        RegisterForDBUpdate = function(callerID, callback)
            auctionatorCalls[#auctionatorCalls + 1] = { name = "update", callerID = callerID }
            auctionatorUpdate = callback
        end,
    }
end

--- Installs the Auctionator global with API.v1 = v1 (nil: no v1).
-- @param v1 table|nil
function Stub.SetAuctionator(v1)
    _G.Auctionator = { API = { v1 = v1 } }
end

--- The calls the Auctionator fake received.
-- @treturn table
function Stub.AuctionatorCalls()
    return auctionatorCalls
end

--- Fires the callback Auctionator registered for database updates.
function Stub.FireAuctionatorUpdate()
    if auctionatorUpdate then
        auctionatorUpdate()
    end
end

-- LibStub with an AceAddon-3.0 fake. LibStub(name, silent) gives the library or
-- nil with silent (from memory; live check L15).
function Stub.SetLibStub(betterBags)
    local addon
    if betterBags then
        addon = {
            GetModule = function(_, name)
                if betterBags.raises then
                    error(betterBags.raises, 0)
                end
                if name == "Categories" then
                    return betterBags.categories
                end
                return nil
            end,
        }
    end
    local ace = {
        GetAddon = function(_, name)
            if name == "BetterBags" then
                return addon
            end
            return nil
        end,
    }
    _G.LibStub = function(name)
        if name == "AceAddon-3.0" then
            return ace
        end
        return nil
    end
end

-- C_Bank.CanUseBank(Enum.BankType.Account) (from memory; live check L33).
function Stub.SetBankApi(canUse)
    if canUse == nil then
        _G.C_Bank = nil
        Enum.BankType = nil
        return
    end
    _G.C_Bank = {
        CanUseBank = function()
            return canUse
        end,
    }
    Enum.BankType = { Account = 2 }
end

-- GetNumTalentTabs and GetTalentTabInfo (from memory; live check L48). The
-- values GetTalentTabInfo returns for a tab are the test's choice.
function Stub.SetTalentTabs(tabs)
    if tabs == nil then
        _G.GetNumTalentTabs = nil
        _G.GetTalentTabInfo = nil
        return
    end
    _G.GetNumTalentTabs = function()
        return #tabs
    end
    _G.GetTalentTabInfo = function(index)
        return unpack(tabs[index], 1, tabs[index].n or #tabs[index])
    end
end

-- Slash commands: the client's table, which Globals.lua fills (not loaded
-- offline).
SlashCmdList = {}

return Stub
