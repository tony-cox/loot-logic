--[[
Command parsing for /ll and /lootlogic (technical findings 14). This stage
handles "probe" and "debug"; the help list and the other commands of spec 13
arrive with later stages.
]]

local addonName, ns = ...

local Slash = {}
ns.Slash = Slash

local L = ns.L
local Log = ns.Log
local DB = ns.DB
local Events = ns.Events
local Util = ns.Util
local Probe = ns.Probe

local debugEventsRegistered = false

local function NoOp() end

-- Registers the events that only the debug log reads, so Events.lua writes
-- their "event" lines (technical findings 15, Debug log). Each registration
-- runs under pcall: PLAYERBANKSLOTS_CHANGED may not exist on Forever (from
-- memory; live check L40 notes whether it fires), and an unknown name may
-- raise (API guess). MERCHANT_SHOW and AUCTION_HOUSE_SHOW are from memory
-- (live check L38) and are skipped when ui.autoOpenContents is on, as the
-- findings say. A second call does nothing: Events has no unregister, and the
-- registrations are harmless while debug is off, because the event line is
-- written only while it is on.
local function RegisterDebugEvents()
    if debugEventsRegistered then
        return
    end
    debugEventsRegistered = true
    local names = { "PLAYERBANKSLOTS_CHANGED" }
    if not DB.Data().ui.autoOpenContents then
        names[#names + 1] = "MERCHANT_SHOW"
        names[#names + 1] = "AUCTION_HOUSE_SHOW"
    end
    for _, name in ipairs(names) do
        local ok, message = Util.Pcall(Events.Register, name, NoOp)
        if not ok then
            Log.Error("events", name .. ": " .. message)
        end
    end
end

-- /ll debug on|off (spec 13). rest is what follows the word "debug".
local function RunDebug(rest)
    local argument = string.match(rest, "^(%S+)$")
    argument = argument and string.lower(argument)
    if argument ~= "on" and argument ~= "off" then
        Log.Chat(L.debugUsage)
        return
    end
    if DB.IsReadOnly() then
        Log.Chat(L.debugReadOnly)
        return
    end
    local saved = DB.Data().debug
    local wanted = argument == "on"
    local already = saved.enabled == wanted
    saved.enabled = wanted
    if wanted then
        RegisterDebugEvents()
    end
    if already then
        Log.Chat(wanted and L.debugAlreadyOn or L.debugAlreadyOff)
    elseif wanted then
        Log.Chat(string.format(L.debugOn, tostring(saved.maxLog)))
    else
        Log.Chat(L.debugOff)
    end
end

--- Runs the command typed after /ll. The command word is case-insensitive;
--- words after "probe" are ignored (spec 13, errors rule 2). "debug" takes on
--- or off. Anything else prints one placeholder line for now.
-- @param message string the typed text after the slash command
function Slash.Run(message)
    local word, rest = string.match(strtrim(message), "^(%S+)%s*(.*)$")
    word = word and string.lower(word)
    if word == "probe" then
        Probe.Run()
        return
    end
    if word == "debug" then
        RunDebug(rest)
        return
    end
    Log.Chat(L.slashPlaceholder)
end

-- Debug saved on from an earlier session registers the debug-only events
-- (RegisterDebugEvents) at load. DB.lua's
-- handler for the same event is registered first, so the saved data is
-- loaded by now.
Events.Register("ADDON_LOADED", function(_, name)
    if name == addonName and Log.IsDebugOn() then
        RegisterDebugEvents()
    end
end)
