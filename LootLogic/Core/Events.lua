--[[
One event frame. Events.Register(event, handler) adds a handler; the handlers
of one event run in registration order (technical findings 14, Events).
]]

local _, ns = ...

local Events = {}
ns.Events = Events

local Log = ns.Log
local Util = ns.Util

-- Their one batch line comes from the item-data handler (findings 14).
local NOT_LOGGED = {
    GET_ITEM_INFO_RECEIVED = true,
    ITEM_DATA_LOAD_RESULT = true,
}

local handlers = {}
local frame = CreateFrame("Frame")

local function Describe(value)
    if Util.IsSecret(value) then
        return "<secret>"
    end
    if type(value) == "table" then
        return "<table>"
    end
    return tostring(value)
end

local function LogEvent(event, ...)
    if NOT_LOGGED[event] or not Log.IsDebugOn() then
        return
    end
    local text = event
    local count = select("#", ...)
    if count > 0 then
        local parts = {}
        for index = 1, count do
            parts[index] = Describe((select(index, ...)))
        end
        text = text .. ": " .. table.concat(parts, ", ")
    end
    Log.Debug("event", text)
end

local function Dispatch(_, event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    LogEvent(event, ...)
    -- The length is read once, so a handler added while this runs waits for the
    -- next dispatch.
    for index = 1, #list do
        local ok, message = Util.Pcall(list[index], event, ...)
        if not ok then
            Log.Error("events", event .. ": " .. message)
        end
    end
end

--- Adds a handler for a game event; handler(event, ...) gets the event name and
--- its arguments. Works at load time and later; there is no unregister.
-- @param event string
-- @param handler function
function Events.Register(event, handler)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        frame:RegisterEvent(event)
    end
    list[#list + 1] = handler
end

frame:SetScript("OnEvent", Dispatch)
