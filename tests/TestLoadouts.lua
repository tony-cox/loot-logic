local _, ns, h = ...

local DB = ns.DB
local Generations = ns.Generations
local Loadouts = ns.Loadouts

local HERE = "Zugar Soulsour-Region"

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
end

-- Logs in as a character of the class and returns its loadouts.
local function LoginAs(class, className)
    h.Stub.SetPlayer({ class = class, className = className })
    Boot()
    h.Stub.FireEvent("PLAYER_LOGIN")
    return LootLogicDB.characters[HERE].loadouts
end

-- A logged-in Warlock with an Affliction loadout picked by the player, and the
-- loadouts counter read after that.
local function PickedWarlock()
    LoginAs("WARLOCK", "Warlock")
    LootLogicDB.characters[HERE].loadouts = {
        { name = "Affliction", spec = "WARLOCK:affliction", worn = true, assumed = false },
    }
    return Generations.Get("loadouts")
end

return {
    ["Loadouts: a new Druid gets a worn assumed Bear loadout"] = function()
        h.DeepEqual(LoginAs("DRUID", "Druid"), {
            { name = "Bear", spec = "DRUID:bear", worn = true, assumed = true },
        }, "loadouts")
    end,

    ["Loadouts: a new Paladin gets a worn assumed Protection loadout"] = function()
        h.DeepEqual(LoginAs("PALADIN", "Paladin"), {
            { name = "Protection", spec = "PALADIN:protection", worn = true, assumed = true },
        }, "loadouts")
    end,

    ["Loadouts: a new Shaman gets a worn assumed Enhancement loadout"] = function()
        h.DeepEqual(LoginAs("SHAMAN", "Shaman"), {
            { name = "Enhancement", spec = "SHAMAN:enhancement", worn = true, assumed = true },
        }, "loadouts")
    end,

    ["Loadouts: a new Warlock gets a worn assumed Affliction loadout"] = function()
        h.DeepEqual(LoginAs("WARLOCK", "Warlock"), {
            { name = "Affliction", spec = "WARLOCK:affliction", worn = true, assumed = true },
        }, "loadouts")
    end,

    ["Loadouts: a new Mage gets a worn assumed loadout named Mage with no spec"] = function()
        local loadouts = LoginAs("MAGE", "Mage")
        h.DeepEqual(loadouts, { { name = "Mage", worn = true, assumed = true } }, "loadouts")
        h.Nil(loadouts[1].spec, "spec")
    end,

    ["Loadouts: the name of a spec-less loadout is the client's class name"] = function()
        local loadouts = LoginAs("ROGUE", "Schurke")
        h.Equal(loadouts[1].name, "Schurke", "name")
    end,

    ["Loadouts: only the four M1 specs are assumed"] = function()
        h.Equal(Loadouts.AssumedSpec("DRUID"), "DRUID:bear", "Druid")
        h.Equal(Loadouts.AssumedSpec("PALADIN"), "PALADIN:protection", "Paladin")
        h.Equal(Loadouts.AssumedSpec("SHAMAN"), "SHAMAN:enhancement", "Shaman")
        h.Equal(Loadouts.AssumedSpec("WARLOCK"), "WARLOCK:affliction", "Warlock")
        for _, class in ipairs({ "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "MAGE" }) do
            h.Nil(Loadouts.AssumedSpec(class), class)
        end
    end,

    ["Loadouts: login creates the loadout once and bumps loadouts once"] = function()
        LoginAs("DRUID", "Druid")
        h.Equal(Generations.Get("loadouts"), 1, "after first login")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(Generations.Get("loadouts"), 1, "after second login")
        h.Equal(#LootLogicDB.characters[HERE].loadouts, 1, "loadouts")
    end,

    ["Loadouts: login keeps the loadouts a character already has"] = function()
        Boot()
        local saved = { { name = "Cat", spec = "DRUID:cat", worn = true, assumed = false } }
        LootLogicDB.characters[HERE] = { first = "Zugar", last = "Soulsour", loadouts = saved }
        LootLogicDB.order[1] = HERE
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(LootLogicDB.characters[HERE].loadouts, saved, "same list")
        h.Equal(#saved, 1, "count")
        h.Equal(Generations.Get("loadouts"), 0, "loadouts bumps")
    end,

    ["Loadouts: login gives an empty list its default loadout"] = function()
        h.Stub.SetPlayer({ class = "WARLOCK", className = "Warlock" })
        Boot()
        LootLogicDB.characters[HERE] = { first = "Zugar", last = "Soulsour", loadouts = {} }
        LootLogicDB.order[1] = HERE
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(LootLogicDB.characters[HERE].loadouts[1].name, "Affliction", "name")
    end,

    ["Loadouts: a read-only session creates no loadout and refuses every edit"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        local _, reason = Loadouts.Set(HERE, "Affliction", "WARLOCK:affliction")
        h.Equal(reason, "readonly", "set")
        _, reason = Loadouts.SetWorn(HERE, "Affliction")
        h.Equal(reason, "readonly", "worn")
        _, reason = Loadouts.Remove(HERE, "Affliction")
        h.Equal(reason, "readonly", "remove")
        _, reason = Loadouts.SetArmor(HERE, "Affliction", "any")
        h.Equal(reason, "readonly", "armor")
        h.Equal(Generations.Get("loadouts"), 0, "loadouts bumps")
    end,

    ["Loadouts: setting a new name adds a picked loadout that is not worn"] = function()
        local before = PickedWarlock()
        local result = Loadouts.Set(HERE, "Second", "WARLOCK:affliction")
        h.Equal(result, "added", "result")
        local added = Loadouts.List(HERE)[2]
        h.DeepEqual(added, { name = "Second", spec = "WARLOCK:affliction", assumed = false }, "new")
        h.Nil(added.worn, "worn")
        h.Equal(Generations.Get("loadouts") - before, 1, "loadouts bumps")
    end,

    ["Loadouts: setting the spec of an assumed loadout clears the flag"] = function()
        LoginAs("WARLOCK", "Warlock")
        local before = Generations.Get("loadouts")
        local result = Loadouts.Set(HERE, "Affliction", "WARLOCK:affliction")
        h.Equal(result, "changed", "result")
        h.Equal(Loadouts.List(HERE)[1].assumed, false, "assumed")
        h.Equal(Loadouts.List(HERE)[1].spec, "WARLOCK:affliction", "spec")
        h.Equal(Generations.Get("loadouts") - before, 1, "loadouts bumps")
    end,

    ["Loadouts: a picked spec set again is no change and bumps nothing"] = function()
        local before = PickedWarlock()
        h.Equal(Loadouts.Set(HERE, "Affliction", "WARLOCK:affliction"), "unchanged", "result")
        h.Equal(Generations.Get("loadouts"), before, "loadouts bumps")
    end,

    ["Loadouts: loadout names are case-insensitive and unique per character"] = function()
        PickedWarlock()
        h.Equal(Loadouts.Set(HERE, "AFFLICTION", "WARLOCK:affliction"), "unchanged", "same")
        h.Equal(#Loadouts.List(HERE), 1, "count")
        h.Equal(Loadouts.Find(HERE, "aFFLICTION"), Loadouts.List(HERE)[1], "find")
        h.Nil(Loadouts.Find(HERE, "Other"), "other")
    end,

    ["Loadouts: setting a different spec on a name changes it"] = function()
        LoginAs("DRUID", "Druid")
        LootLogicDB.characters[HERE].loadouts[1].assumed = false
        h.Equal(Loadouts.Set(HERE, "Bear", "DRUID:bear"), "unchanged", "same spec")
        LootLogicDB.characters[HERE].class = "WARLOCK"
        h.Equal(Loadouts.Set(HERE, "Bear", "WARLOCK:affliction"), "changed", "other spec")
        h.Equal(Loadouts.List(HERE)[1].spec, "WARLOCK:affliction", "spec")
    end,

    ["Loadouts: worn on an existing loadout makes it worn, one change"] = function()
        local before = PickedWarlock()
        Loadouts.Set(HERE, "Second", "WARLOCK:affliction")
        h.Equal(Loadouts.Set(HERE, "Second", "WARLOCK:affliction", true), "changed", "result")
        h.Equal(Loadouts.Worn(HERE).name, "Second", "worn")
        h.Nil(Loadouts.List(HERE)[1].worn, "old worn")
        h.Equal(Generations.Get("loadouts") - before, 2, "loadouts bumps")
    end,

    ["Loadouts: worn with a new loadout clears the flag on the others"] = function()
        local before = PickedWarlock()
        h.Equal(Loadouts.Set(HERE, "Second", "WARLOCK:affliction", true), "added", "result")
        local worn = 0
        for _, loadout in ipairs(Loadouts.List(HERE)) do
            if loadout.worn then
                worn = worn + 1
            end
        end
        h.Equal(worn, 1, "worn count")
        h.Equal(Loadouts.Worn(HERE).name, "Second", "worn")
        h.Equal(Generations.Get("loadouts") - before, 1, "loadouts bumps")
    end,

    ["Loadouts: a loadout added to a list with none worn becomes the worn one"] = function()
        PickedWarlock()
        LootLogicDB.characters[HERE].loadouts = {}
        h.Equal(Loadouts.Set(HERE, "First", "WARLOCK:affliction"), "added", "result")
        h.Equal(Loadouts.Worn(HERE).name, "First", "worn")
    end,

    ["Loadouts: a refused edit creates no loadouts list"] = function()
        Boot()
        LootLogicDB.characters[HERE] = { first = "Zugar", last = "Soulsour", class = "WARLOCK" }
        local _, reason = Loadouts.SetWorn(HERE, "Foo")
        h.Equal(reason, "noloadout", "worn")
        _, reason = Loadouts.Remove(HERE, "Foo")
        h.Equal(reason, "noloadout", "remove")
        _, reason = Loadouts.SetArmor(HERE, "Foo", "any")
        h.Equal(reason, "noloadout", "armor")
        h.Nil(LootLogicDB.characters[HERE].loadouts, "list")
    end,

    ["Loadouts: a loadout without a name is skipped by a lookup"] = function()
        PickedWarlock()
        table.insert(LootLogicDB.characters[HERE].loadouts, 1, { spec = "WARLOCK:affliction" })
        h.Equal(Loadouts.Find(HERE, "Affliction").name, "Affliction", "found")
        h.Nil(Loadouts.Find(HERE, "Foo"), "missing")
    end,

    ["Loadouts: a spec without a weight table is refused"] = function()
        local before = PickedWarlock()
        LootLogicDB.characters[HERE].class = "DRUID"
        local result, reason = Loadouts.Set(HERE, "Cat", "DRUID:cat")
        h.Nil(result, "result")
        h.Equal(reason, "noweights", "reason")
        h.Equal(#Loadouts.List(HERE), 1, "count")
        h.Equal(Generations.Get("loadouts"), before, "loadouts bumps")
        h.Equal(Loadouts.HasWeights("DRUID:bear"), true, "bear")
        h.Equal(Loadouts.HasWeights("DRUID:cat"), false, "cat")
    end,

    ["Loadouts: a spec of another class is refused"] = function()
        local before = PickedWarlock()
        local result, reason = Loadouts.Set(HERE, "Tank", "PALADIN:protection")
        h.Nil(result, "result")
        h.Equal(reason, "wrongclass", "reason")
        h.Equal(Generations.Get("loadouts"), before, "loadouts bumps")
    end,

    ["Loadouts: an edit for an unknown character is refused"] = function()
        Boot()
        local _, reason = Loadouts.Set("Nobody Known-Region", "A", "WARLOCK:affliction")
        h.Equal(reason, "unknown", "set")
        _, reason = Loadouts.SetWorn("Nobody Known-Region", "A")
        h.Equal(reason, "unknown", "worn")
        _, reason = Loadouts.Remove("Nobody Known-Region", "A")
        h.Equal(reason, "unknown", "remove")
        _, reason = Loadouts.SetArmor("Nobody Known-Region", "A", "any")
        h.Equal(reason, "unknown", "armor")
        h.DeepEqual(Loadouts.List("Nobody Known-Region"), {}, "list")
        h.Nil(Loadouts.Worn("Nobody Known-Region"), "worn loadout")
    end,

    ["Loadouts: making another loadout worn clears the others, one bump"] = function()
        local before = PickedWarlock()
        Loadouts.Set(HERE, "Second", "WARLOCK:affliction")
        h.Equal(Loadouts.SetWorn(HERE, "second"), "changed", "result")
        h.Equal(Loadouts.Worn(HERE).name, "Second", "worn")
        h.Nil(Loadouts.List(HERE)[1].worn, "old worn")
        h.Equal(Loadouts.SetWorn(HERE, "Second"), "unchanged", "again")
        h.Equal(Generations.Get("loadouts") - before, 2, "loadouts bumps")
    end,

    ["Loadouts: making an unknown loadout worn is refused"] = function()
        local before = PickedWarlock()
        local result, reason = Loadouts.SetWorn(HERE, "Foo")
        h.Nil(result, "result")
        h.Equal(reason, "noloadout", "reason")
        h.Equal(Generations.Get("loadouts"), before, "loadouts bumps")
    end,

    ["Loadouts: a loadout that is not worn can be removed, once"] = function()
        local before = PickedWarlock()
        Loadouts.Set(HERE, "Second", "WARLOCK:affliction")
        h.Equal(Loadouts.Remove(HERE, "SECOND"), "removed", "result")
        h.Equal(#Loadouts.List(HERE), 1, "count")
        local result, reason = Loadouts.Remove(HERE, "Second")
        h.Nil(result, "again")
        h.Equal(reason, "noloadout", "reason")
        h.Equal(Generations.Get("loadouts") - before, 2, "loadouts bumps")
    end,

    ["Loadouts: the worn loadout is never removed"] = function()
        local before = PickedWarlock()
        local result, reason = Loadouts.Remove(HERE, "Affliction")
        h.Nil(result, "result")
        h.Equal(reason, "worn", "reason")
        h.Equal(#Loadouts.List(HERE), 1, "count")
        h.Equal(Generations.Get("loadouts"), before, "loadouts bumps")
    end,

    ["Loadouts: the armour rule is best, any or nil"] = function()
        local before = PickedWarlock()
        h.Nil(Loadouts.List(HERE)[1].armor, "start")
        h.Equal(Loadouts.SetArmor(HERE, "Affliction", "any"), "changed", "any")
        h.Equal(Loadouts.List(HERE)[1].armor, "any", "stored any")
        h.Equal(Loadouts.SetArmor(HERE, "affliction", "any"), "unchanged", "any again")
        h.Equal(Loadouts.SetArmor(HERE, "Affliction", "best"), "changed", "best")
        h.Equal(Loadouts.List(HERE)[1].armor, "best", "stored best")
        h.Equal(Loadouts.SetArmor(HERE, "Affliction", nil), "changed", "default")
        h.Nil(Loadouts.List(HERE)[1].armor, "stored default")
        h.Equal(Loadouts.SetArmor(HERE, "Affliction", nil), "unchanged", "default again")
        h.Equal(Generations.Get("loadouts") - before, 3, "loadouts bumps")
    end,

    ["Loadouts: the armour rule of an unknown loadout is refused"] = function()
        PickedWarlock()
        local result, reason = Loadouts.SetArmor(HERE, "Foo", "any")
        h.Nil(result, "result")
        h.Equal(reason, "noloadout", "reason")
    end,
}
