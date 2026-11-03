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

-- Chat prefixes (technical findings 15, Debug log; docs/ux.md 6).
L.chatPrefix = "LootLogic:"
L.debugPrefix = "LootLogic debug:"

-- The engine error chat line, without the prefix (docs/ux.md 6).
L.errorEngine = "error on an item, see /ll status."

-- Money parts (technical findings 14, Locale table).
L.moneyGold = "%dg"
L.moneySilver = "%ds"
L.moneyCopper = "%dc"
