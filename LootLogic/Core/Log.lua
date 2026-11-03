--[[
The debug log writer, the "LootLogic:" chat line, the Errors list and the
per-item pcall guard (technical findings 14, Errors, and 15, Debug log).

This file loads before Core/DB.lua, so it reaches the saved data only through
the LootLogicDB global and creates nothing in it while debug counts as off.
]]

local _, ns = ...

local Log = {}
ns.Log = Log

local L = ns.L
local Init = ns.Init
local Util = ns.Util

local MAX_ERRORS = 20
-- Used only when debug.maxLog is not a number (DB.lua fills 300 by default).
local FALLBACK_MAX_LOG = 300

--- Every error this session, repeated ones included.
Log.errorCount = 0

local errors = {}
local debugLocked = false
local engineLinePrinted = false

--- Locks debug off (true) or lifts the lock (false). Core/DB.lua locks it when
--- the session becomes read-only, so nothing is written to the saved data, and
--- lifts it at the start of each load.
-- @param locked boolean
function Log.LockDebug(locked)
    debugLocked = locked
end

--- Prints one "LootLogic:" line to the chat frame with print, which writes to
--- the default chat frame (from memory; live check L63 covers the chat output).
-- @param text string
function Log.Chat(text)
    print(L.chatPrefix .. " " .. text)
end

--- The Errors list, oldest first: { time, area, message, count }. Not saved;
--- callers do not change it.
-- @treturn table
function Log.Errors()
    return errors
end

--- True when debug lines are written: Log.LockDebug has not locked it (a
--- read-only session), LootLogicDB has a debug table with
--- enabled true, and its saved schema is not newer than the code's (spec 6:
--- then the saved data stays unchanged for the session).
-- @treturn boolean
function Log.IsDebugOn()
    if debugLocked then
        return false
    end
    local db = LootLogicDB
    if type(db) ~= "table" or type(db.debug) ~= "table" then
        return false
    end
    if type(db.schema) == "number" and db.schema > Init.schemaVersion then
        return false
    end
    if db.debug.enabled then
        return true
    end
    return false
end

--- Writes the debug line "[hh:mm:ss] <area>: text": echoes it to chat with the
--- "LootLogic debug:" prefix and keeps it in debug.log, trimmed to the last
--- debug.maxLog lines. Does nothing, and creates nothing, while debug is off.
-- @param area string
-- @param text string
function Log.Debug(area, text)
    if not Log.IsDebugOn() then
        return
    end
    local line = string.format("[%s] %s: %s", date("%H:%M:%S", GetServerTime()), area, text)
    print(L.debugPrefix .. " " .. line)
    local saved = LootLogicDB.debug
    if type(saved.log) ~= "table" then
        saved.log = {}
    end
    local log = saved.log
    log[#log + 1] = line
    local maxLog = saved.maxLog
    if type(maxLog) ~= "number" then
        maxLog = FALLBACK_MAX_LOG
    end
    while #log > maxLog do
        table.remove(log, 1)
    end
end

--- Records an error in the Errors list (no chat line) and writes the debug line
--- "error: <area>: <message>".
-- @param area string "engine", "provider:<id>", "events", "prices" or "db"
-- @param message string
function Log.Error(area, message)
    message = tostring(message)
    Log.errorCount = Log.errorCount + 1
    local newest = errors[#errors]
    if newest and newest.area == area and newest.message == message then
        newest.count = newest.count + 1
    else
        errors[#errors + 1] = {
            time = GetServerTime(),
            area = area,
            message = message,
            count = 1,
        }
        if #errors > MAX_ERRORS then
            table.remove(errors, 1)
        end
    end
    Log.Debug("error", area .. ": " .. message)
end

local function GuardResult(area, ok, ...)
    if ok then
        return ...
    end
    Log.Error(area, (...))
    if area == "engine" and not engineLinePrinted then
        engineLinePrinted = true
        Log.Chat(L.errorEngine)
    end
    return nil
end

--- Runs fn(...) under pcall. Returns what fn returned; on an error records it
--- with Log.Error and returns nil. For the area "engine" it also prints the
--- engine error chat line, once per session.
-- @param area string
-- @param fn function
-- @param ... any arguments for fn
-- @return what fn returned, or nil after an error
function Log.Guard(area, fn, ...)
    return GuardResult(area, Util.Pcall(fn, ...))
end
