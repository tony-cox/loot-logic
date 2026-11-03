local _, ns, h = ...

local DB = ns.DB
local Generations = ns.Generations
local Sets = ns.Sets

local HERE = "Zugar Soulsour-Region"

-- A fresh database with the current character registered.
local function Login()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
end

-- Adds a second character that is not here.
local function AddOther()
    local key = "Boneset Hallowine-Region"
    LootLogicDB.characters[key] = { first = "Boneset", last = "Hallowine", class = "PRIEST" }
    LootLogicDB.order[#LootLogicDB.order + 1] = key
    return key
end

return {
    ["Protect: a plain item ID is added and removed, bumping asks each time"] = function()
        Login()
        h.Equal(Sets.ToggleProtect(HERE, 2589), "added", "first toggle")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, { ["2589"] = true }, "list")
        h.Equal(Generations.Get("asks"), 1, "asks after add")
        h.Equal(Sets.ToggleProtect(HERE, 2589), "removed", "second toggle")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, {}, "list after removal")
        h.Equal(Generations.Get("asks"), 2, "asks after removal")
    end,

    ["Protect: a link with no suffix and itemID:0 store the plain item ID"] = function()
        Login()
        h.Equal(Sets.ToggleProtect(HERE, 2589, 0), "added", "suffix 0")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, { ["2589"] = true }, "list")
        h.Equal(Sets.ToggleProtect(HERE, 2589, nil), "removed", "no suffix removes the same key")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, {}, "list after removal")
    end,

    ["Protect: a roll stores the instance key and its toggle removes it"] = function()
        Login()
        h.Equal(Sets.ToggleProtect(HERE, 12345, -17), "added", "add")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, { ["12345:-17"] = true }, "list")
        h.Equal(Sets.ToggleProtect(HERE, 12345, -17), "removed", "remove")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, {}, "list after removal")
    end,

    ["Protect: a roll toggle with only the plain ID stored changes nothing"] = function()
        Login()
        Sets.ToggleProtect(HERE, 12345)
        local before = Generations.Get("asks")
        local result, reason = Sets.ToggleProtect(HERE, 12345, -17)
        h.Nil(result, "result")
        h.Equal(reason, "everyroll", "reason")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, { ["12345"] = true }, "list")
        h.Equal(Generations.Get("asks"), before, "asks not bumped")
    end,

    ["Protect: a toggle removes the exact key it would store"] = function()
        Login()
        LootLogicDB.characters[HERE].protect = { ["12345"] = true, ["12345:-17"] = true }
        h.Equal(Sets.ToggleProtect(HERE, 12345, -17), "removed", "roll removed")
        h.DeepEqual(LootLogicDB.characters[HERE].protect, { ["12345"] = true }, "plain kept")
        LootLogicDB.characters[HERE].protect = { ["12345:-17"] = true }
        h.Equal(Sets.ToggleProtect(HERE, 12345), "added", "plain added beside a roll")
        h.DeepEqual(
            LootLogicDB.characters[HERE].protect,
            { ["12345"] = true, ["12345:-17"] = true },
            "both stored"
        )
    end,

    ["Protect: the global list follows the same rules"] = function()
        Login()
        h.Equal(Sets.ToggleProtectGlobal(6948), "added", "plain")
        h.Equal(Sets.ToggleProtectGlobal(6948, 0), "removed", "plain again")
        h.Equal(Sets.ToggleProtectGlobal(12345, -17), "added", "roll")
        h.DeepEqual(LootLogicDB.protectGlobal, { ["12345:-17"] = true }, "list")
        h.Equal(Sets.ToggleProtectGlobal(12345, -17), "removed", "roll removed")
        Sets.ToggleProtectGlobal(12345)
        local before = Generations.Get("asks")
        local result, reason = Sets.ToggleProtectGlobal(12345, -17)
        h.Nil(result, "refused result")
        h.Equal(reason, "everyroll", "refused reason")
        h.DeepEqual(LootLogicDB.protectGlobal, { ["12345"] = true }, "unchanged")
        h.Equal(Generations.Get("asks"), before, "asks not bumped")
        -- The character's list is separate.
        h.Nil(LootLogicDB.characters[HERE].protect, "here's list untouched")
    end,

    ["Protect: an unknown character is refused"] = function()
        Login()
        local result, reason = Sets.ToggleProtect("Nobody Here-Region", 2589)
        h.Nil(result, "result")
        h.Equal(reason, "unknown", "reason")
        h.Equal(Generations.Get("asks"), 0, "asks")
    end,

    ["Protect: a read-only session refuses and writes nothing"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        local _, reason = Sets.ToggleProtect(HERE, 2589)
        h.Equal(reason, "readonly", "character list")
        _, reason = Sets.ToggleProtectGlobal(2589)
        h.Equal(reason, "readonly", "global list")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.Equal(Generations.Get("asks"), 0, "asks")
    end,

    ["Protect: the query finds the plain ID, the roll and the global list"] = function()
        Login()
        h.Equal(Sets.IsProtected(2589, 0), false, "nothing protected")
        Sets.ToggleProtect(HERE, 2589)
        h.Equal(Sets.IsProtected(2589, 0), true, "plain ID")
        h.Equal(Sets.IsProtected(2589, -17), true, "plain ID covers every roll")
        Sets.ToggleProtect(HERE, 12345, -17)
        h.Equal(Sets.IsProtected(12345, -17), true, "the roll")
        h.Equal(Sets.IsProtected(12345, -3), false, "another roll")
        h.Equal(Sets.IsProtected(12345), false, "no suffix is not the roll")
        Sets.ToggleProtectGlobal(6948)
        h.Equal(Sets.IsProtected(6948), true, "global list")
    end,

    ["Protect: another character's list does not protect here"] = function()
        Login()
        local other = AddOther()
        Sets.ToggleProtect(other, 2589)
        h.Equal(Sets.IsProtected(2589), false, "not here's")
    end,
}
