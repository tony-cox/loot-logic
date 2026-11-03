--[[
The cache generation counters (technical findings 14 and 15, API counters).
Code that changes something calls Generations.Bump(name); Cache.lua reads the
counters to key its results. This file loads before Log.lua, so it calls
nothing below it.
]]

local _, ns = ...

local Generations = {}
ns.Generations = Generations

local counts = {
    asks = 0,
    gearHere = 0,
    gearOthers = 0,
    loadouts = 0,
    prices = 0,
    roster = 0,
    settings = 0,
}
local total = 0
local listeners = {}

local function Check(name)
    if not counts[name] then
        error("unknown generation: " .. tostring(name), 3)
    end
end

--- Adds 1 to the named counter and to the total, then calls each listener with
--- the name, in registration order. A listener catches its own errors.
-- @param name string one of the seven generation names; any other raises
function Generations.Bump(name)
    Check(name)
    counts[name] = counts[name] + 1
    total = total + 1
    for index = 1, #listeners do
        listeners[index](name)
    end
end

--- The value of the named counter.
-- @param name string one of the seven generation names; any other raises
-- @treturn number
function Generations.Get(name)
    Check(name)
    return counts[name]
end

--- The number of bumps so far, over all names.
-- @treturn number
function Generations.Total()
    return total
end

--- Registers a listener that gets (name) on each bump. There is no unregister.
-- @param fn function
function Generations.OnBump(fn)
    listeners[#listeners + 1] = fn
end
