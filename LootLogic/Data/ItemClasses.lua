--[[
Default dispositions per item class and subclass, the profession tool item IDs
and the never-touch item IDs (technical findings 14.1; spec 7.2).
]]

local _, ns = ...

local ItemClasses = {}
ns.ItemClasses = ItemClasses

-- Keys are always text: "<class>" or "<class>:<subclass>". Source: the game
-- data dump (source-read; L8 checks the class and subclass numbers).
ItemClasses.dispositions = {
    ["0"] = "stay",
    ["1"] = "stay",
    ["2"] = "sell",
    ["4"] = "sell",
    ["5"] = "stay",
    ["6"] = "stay",
    ["7"] = "sell",
    ["9"] = "sell",
    ["11"] = "stay",
    ["12"] = "stay",
    ["13"] = "stay",
    ["18"] = "stay",
    ["15:0"] = "sell",
    ["15:1"] = "stay",
    ["15:2"] = "stay",
    ["15:3"] = "stay",
    ["15:4"] = "stay",
    ["15:5"] = "stay",
}

-- [itemID] = profession. The item IDs are from memory of Classic, unverified
-- for Forever: no live check covers them, so check each one in game (an item
-- link for each ID) when the client is available. Fishing poles are 2/20 and
-- profession tools 2/14, but Flint and Tinder (7/11) and the runed rods
-- (7/12) share their subclass with other goods, so only this list tells them
-- apart.
ItemClasses.tools = {
    -- Mining Pick.
    [2901] = "Mining",
    -- Skinning Knife.
    [7005] = "Skinning",
    -- Blacksmith Hammer.
    [5956] = "Blacksmithing",
    -- Arclight Spanner.
    [6219] = "Engineering",
    -- Runed Copper Rod.
    [6218] = "Enchanting",
    -- Fishing Pole.
    [6256] = "Fishing",
    -- Flint and Tinder.
    [4471] = "Cooking",
    -- Runed rods above Runed Copper Rod: Silver, Golden, Truesilver, Arcanite.
    [6339] = "Enchanting",
    [11130] = "Enchanting",
    [11145] = "Enchanting",
    [16207] = "Enchanting",
}

-- Hearthstone (source-read, game data dump).
ItemClasses.neverTouch = { [6948] = true }
