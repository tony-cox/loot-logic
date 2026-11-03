local _, ns, h = ...

local Asks = ns.Asks
local DB = ns.DB
local Generations = ns.Generations
local Roster = ns.Roster

local HERE = "Zugar Soulsour-Region"
local PRIEST = "Boneset Hallowine-Region"
local HUNTER = "Chamoomile Rejuvenade-Region"

-- A fresh database: Boneset the priest and Chamoomile the hunter registered
-- first in that order, then the current character, a warlock.
local function Login()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    LootLogicDB.characters[PRIEST] = { first = "Boneset", last = "Hallowine", class = "PRIEST" }
    LootLogicDB.characters[HUNTER] = {
        first = "Chamoomile",
        last = "Rejuvenade",
        class = "HUNTER",
    }
    LootLogicDB.order = { PRIEST, HUNTER }
    h.Stub.FireEvent("PLAYER_LOGIN")
end

local function Want(key, types, items)
    LootLogicDB.characters[key].asks = { types = types or {}, items = items or {} }
end

-- Linen Cloth (trade goods, cloth) unless fields say otherwise.
local function Facts(fields)
    local facts = { itemID = 2589, class = 7, subclass = 5, quality = 1 }
    for name, value in pairs(fields or {}) do
        facts[name] = value
    end
    return facts
end

return {
    ["Asks: a type flag matches its type and no other"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = {} })
        h.Equal(Asks.Matches(PRIEST, Facts()), true, "the type")
        h.Equal(Asks.Matches(PRIEST, Facts({ subclass = 8 })), false, "another subclass")
        h.Equal(Asks.Matches(PRIEST, Facts({ class = 4 })), false, "another class")
    end,

    ["Asks: MatchKind names the include, then the subclass flag, then the class flag"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = {}, ["7:*"] = {} }, { [2589] = "include" })
        h.Equal(Asks.MatchKind(PRIEST, Facts()), "item", "include")
        Want(PRIEST, { ["7:5"] = {}, ["7:*"] = {} })
        h.Equal(Asks.MatchKind(PRIEST, Facts()), "subclass", "subclass")
        Want(PRIEST, { ["7:*"] = {} })
        h.Equal(Asks.MatchKind(PRIEST, Facts()), "class", "class")
        Want(PRIEST, { ["7:5"] = { minQuality = 3 }, ["7:*"] = { minQuality = 1 } })
        h.Equal(Asks.MatchKind(PRIEST, Facts()), "class", "the subclass minimum is not met")
        Want(PRIEST, { ["4:*"] = {} })
        h.Nil(Asks.MatchKind(PRIEST, Facts()), "no flag")
    end,

    ["Asks: a class:* flag matches the whole class"] = function()
        Login()
        Want(PRIEST, { ["4:*"] = {} })
        h.Equal(Asks.Matches(PRIEST, Facts({ class = 4, subclass = 1 })), true, "cloth armour")
        h.Equal(Asks.Matches(PRIEST, Facts({ class = 4, subclass = 4 })), true, "plate armour")
        h.Equal(Asks.Matches(PRIEST, Facts()), false, "another class")
    end,

    ["Asks: a character with no wants never matches"] = function()
        Login()
        h.Equal(Asks.Matches(PRIEST, Facts()), false, "no asks table")
        Want(PRIEST)
        h.Equal(Asks.Matches(PRIEST, Facts()), false, "empty asks")
        h.Equal(Asks.Matches("Nobody Here-Region", Facts()), false, "unknown character")
    end,

    ["Asks: the minimum quality of a flag is a lower bound"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = { minQuality = 2 } })
        h.Equal(Asks.Matches(PRIEST, Facts({ quality = 1 })), false, "below")
        h.Equal(Asks.Matches(PRIEST, Facts({ quality = 2 })), true, "equal")
        h.Equal(Asks.Matches(PRIEST, Facts({ quality = 4 })), true, "above")
    end,

    ["Asks: with two flags and two minimums either one matches"] = function()
        Login()
        Want(PRIEST, { ["4:1"] = { minQuality = 3 }, ["4:*"] = { minQuality = 1 } })
        h.Equal(
            Asks.Matches(PRIEST, Facts({ class = 4, subclass = 1, quality = 2 })),
            true,
            "whole"
        )
        h.Equal(
            Asks.Matches(PRIEST, Facts({ class = 4, subclass = 1, quality = 0 })),
            false,
            "none"
        )
        Want(PRIEST, { ["4:1"] = { minQuality = 1 }, ["4:*"] = { minQuality = 3 } })
        h.Equal(
            Asks.Matches(PRIEST, Facts({ class = 4, subclass = 1, quality = 2 })),
            true,
            "exact"
        )
        h.Equal(
            Asks.Matches(PRIEST, Facts({ class = 4, subclass = 2, quality = 2 })),
            false,
            "other"
        )
    end,

    ["Asks: an item exclude beats a type that is on"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = {} }, { [2589] = "exclude" })
        h.Equal(Asks.Matches(PRIEST, Facts()), false, "excluded")
        h.Equal(Asks.Matches(PRIEST, Facts({ itemID = 2592 })), true, "another item of the type")
    end,

    ["Asks: an item include beats a type that is off, whatever the quality"] = function()
        Login()
        Want(PRIEST, {}, { [2589] = "include" })
        h.Equal(Asks.Matches(PRIEST, Facts({ quality = 0 })), true, "included")
        h.Equal(Asks.Matches(PRIEST, Facts({ itemID = 2592 })), false, "another item")
        Want(PRIEST, { ["7:5"] = { minQuality = 3 } }, { [2589] = "include" })
        h.Equal(Asks.Matches(PRIEST, Facts({ quality = 1 })), true, "below the type's minimum")
    end,

    ["Asks: a class restriction that leaves the character out is no match"] = function()
        Login()
        Want(PRIEST, { ["9:*"] = {} })
        Want(HUNTER, { ["9:*"] = {} })
        local book = Facts({ class = 9, subclass = 0, classRestriction = { HUNTER = true } })
        h.Equal(Asks.Matches(PRIEST, book), false, "priest")
        h.Equal(Asks.Matches(HUNTER, book), true, "hunter")
        local open = Facts({ class = 9, subclass = 0, classRestriction = {} })
        h.Equal(Asks.Matches(PRIEST, open), true, "an item that names no class")
    end,

    ["Asks: an item include beats the class restriction and a known recipe"] = function()
        Login()
        Want(HERE, { ["9:*"] = {} }, { [3334] = "include" })
        local book = Facts({
            itemID = 3334,
            class = 9,
            subclass = 0,
            classRestriction = { HUNTER = true },
            knownHere = true,
        })
        h.Equal(Asks.Matches(HERE, book), true, "include wins")
        Want(HERE, { ["9:*"] = {} })
        h.Equal(Asks.Matches(HERE, book), false, "without the include")
    end,

    ["Asks: a recipe that the current character knows is no match for it only"] = function()
        Login()
        Want(HERE, { ["9:*"] = {} })
        Want(PRIEST, { ["9:*"] = {} })
        local recipe = Facts({ class = 9, subclass = 8, knownHere = true })
        h.Equal(Asks.Matches(HERE, recipe), false, "known here")
        h.Equal(Asks.Matches(PRIEST, recipe), true, "another character")
        recipe.knownHere = false
        h.Equal(Asks.Matches(HERE, recipe), true, "not known")
        recipe = Facts({ knownHere = true })
        Want(HERE, { ["7:5"] = {} })
        h.Equal(Asks.Matches(HERE, recipe), true, "knownHere is for class 9 only")
    end,

    ["Asks: wanters come in the global order, here and ineligible ones included"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = {} })
        Want(HUNTER, { ["7:5"] = {} })
        Want(HERE, { ["7:5"] = {} })
        h.DeepEqual(Asks.Wanters(Facts()), { PRIEST, HUNTER, HERE }, "default order")
        Roster.SetOrder({ HERE, HUNTER })
        h.DeepEqual(Asks.Wanters(Facts()), { HERE, HUNTER, PRIEST }, "after reorder")
        LootLogicDB.characters[HUNTER].faction = "Alliance"
        h.DeepEqual(Asks.Wanters(Facts()), { HERE, HUNTER, PRIEST }, "faction not considered")
        Want(HUNTER, { ["7:5"] = {} }, { [2589] = "exclude" })
        h.DeepEqual(Asks.Wanters(Facts()), { HERE, PRIEST }, "exclude removes one")
    end,

    ["Asks: a type flag is turned on and off, bumping asks once per change"] = function()
        Login()
        h.Equal(Asks.SetType(PRIEST, "7:5", "on"), "changed", "on")
        h.DeepEqual(LootLogicDB.characters[PRIEST].asks.types, { ["7:5"] = {} }, "types")
        h.Equal(Generations.Get("asks"), 1, "asks after on")
        h.Equal(Asks.SetType(PRIEST, "7:5", "on"), "unchanged", "on again")
        h.Equal(Generations.Get("asks"), 1, "asks after on again")
        h.Equal(Asks.SetType(PRIEST, "7:5", "off"), "changed", "off clears")
        h.DeepEqual(LootLogicDB.characters[PRIEST].asks.types, {}, "types after off")
        h.Equal(Generations.Get("asks"), 2, "asks after off")
        h.Equal(Asks.SetType(PRIEST, "7:5", "off"), "unchanged", "off again")
        h.Equal(Asks.SetType(PRIEST, "7:5", "clear"), "unchanged", "clear when absent")
        h.Equal(Generations.Get("asks"), 2, "asks after nothing")
    end,

    ["Asks: a class flag and clear"] = function()
        Login()
        h.Equal(Asks.SetType(PRIEST, "4:*", "on"), "changed", "on")
        h.True(LootLogicDB.characters[PRIEST].asks.types["4:*"], "flag")
        h.Equal(Asks.SetType(PRIEST, "4:*", "clear"), "changed", "clear")
        h.Nil(LootLogicDB.characters[PRIEST].asks.types["4:*"], "flag cleared")
    end,

    ["Asks: turning a flag on keeps the minimum quality it has"] = function()
        Login()
        Want(PRIEST, { ["7:5"] = { minQuality = 2 } })
        h.Equal(Asks.SetType(PRIEST, "7:5", "on"), "unchanged", "on")
        h.DeepEqual(LootLogicDB.characters[PRIEST].asks.types["7:5"], { minQuality = 2 }, "flag")
    end,

    ["Asks: an item is included, excluded and cleared"] = function()
        Login()
        h.Equal(Asks.SetItem(PRIEST, 2589, "include"), "changed", "include")
        h.Equal(LootLogicDB.characters[PRIEST].asks.items[2589], "include", "stored")
        h.Equal(Asks.SetItem(PRIEST, 2589, "include"), "unchanged", "include again")
        h.Equal(Asks.SetItem(PRIEST, 2589, "exclude"), "changed", "exclude")
        h.Equal(LootLogicDB.characters[PRIEST].asks.items[2589], "exclude", "stored")
        h.Equal(Generations.Get("asks"), 2, "asks")
        h.Equal(Asks.SetItem(PRIEST, 2589, "clear"), "changed", "clear")
        h.Nil(LootLogicDB.characters[PRIEST].asks.items[2589], "cleared")
        h.Equal(Asks.SetItem(PRIEST, 2589, "clear"), "unchanged", "clear again")
        h.Equal(Generations.Get("asks"), 3, "asks")
    end,

    ["Asks: edits of an unknown character are refused"] = function()
        Login()
        local result, reason = Asks.SetType("Nobody Here-Region", "7:5", "on")
        h.Nil(result, "type result")
        h.Equal(reason, "unknown", "type reason")
        result, reason = Asks.SetItem("Nobody Here-Region", 2589, "include")
        h.Nil(result, "item result")
        h.Equal(reason, "unknown", "item reason")
        h.Equal(Generations.Get("asks"), 0, "asks")
    end,

    ["Asks: a read-only session refuses every edit and writes nothing"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        local _, reason = Asks.SetType(HERE, "7:5", "on")
        h.Equal(reason, "readonly", "type")
        _, reason = Asks.SetItem(HERE, 2589, "include")
        h.Equal(reason, "readonly", "item")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.Equal(Generations.Get("asks"), 0, "asks")
    end,
}
