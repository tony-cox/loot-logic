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
  FireEvent(event, ...)   fire an event on every frame registered for it
  ChatLines()             list of the chat lines printed so far
  ClearChat()             forget the captured chat lines

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

return Stub
