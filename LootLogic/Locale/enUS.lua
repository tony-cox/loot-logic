--[[
English strings. Every player-facing text lives in ns.L; a missing key shows its
own name instead of raising an error (technical findings 14, Locale table).
]]

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

ns.L = L
