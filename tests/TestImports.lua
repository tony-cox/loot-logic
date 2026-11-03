local _, ns, h = ...

local DB = ns.DB
local Generations = ns.Generations
local Sets = ns.Sets

local HERE = "Zugar Soulsour-Region"

local function Link(itemID, suffix)
    return string.format("|cffffffff|Hitem:%d:0:0:0:0:0:%d:0:60|h[Item]|h|r", itemID, suffix)
end

-- A fresh database; the current character logs in.
local function Login()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    return LootLogicDB.characters[HERE]
end

-- A fresh database with a second character already registered, then the login.
local function LoginWithOther(first, last)
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    local key = first .. " " .. last .. "-Region"
    LootLogicDB.characters[key] = { first = first, last = last, region = "Region" }
    LootLogicDB.order[1] = key
    h.Stub.FireEvent("PLAYER_LOGIN")
    return key
end

local function Outfit(name, items)
    return { Name = name, Items = items }
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = DeepCopy(inner)
    end
    return copy
end

-- One Equipment Manager set with a worn item that rolled a suffix, a bagged
-- item without one, a banked item and an item with no known place.
local function ScriptCatSet()
    h.Stub.SetWornLink(1, Link(100, -17))
    h.Stub.SetBagLink(2, 5, Link(200, 0))
    h.Stub.SetEquipmentSets({
        {
            id = 1,
            name = "Cat",
            items = { [1] = 100, [16] = 200, [17] = 300, [18] = 400, [19] = 0 },
            places = {
                [1] = { where = "worn", slot = 1 },
                [16] = { where = "bag", bag = 2, slot = 5 },
                [17] = { where = "bank", bag = 7, slot = 3 },
                [18] = -1,
            },
        },
    })
end

return {
    ["Equipment Manager: a set is imported with the suffix of a worn or bagged link"] = function()
        ScriptCatSet()
        local here = Login()
        h.DeepEqual(here.importedSets, {
            ["equipmentset:Cat"] = {
                source = "equipmentset",
                name = "Cat",
                updatedAt = GetServerTime(),
                items = {
                    { id = 100, suffix = -17 },
                    { id = 200, suffix = 0 },
                    { id = 300, suffix = 0 },
                    { id = 400, suffix = 0 },
                },
            },
        }, "importedSets")
    end,

    ["Equipment Manager: a link of another item at the location gives suffix 0"] = function()
        h.Stub.SetWornLink(1, Link(999, -17))
        h.Stub.SetEquipmentSets({
            {
                id = 1,
                name = "Cat",
                items = { [1] = 100 },
                places = { [1] = { where = "worn", slot = 1 } },
            },
        })
        local here = Login()
        h.DeepEqual(
            here.importedSets["equipmentset:Cat"].items,
            { { id = 100, suffix = 0 } },
            "items"
        )
    end,

    ["Equipment Manager: a refresh bumps loadouts once and replaces the sets"] = function()
        ScriptCatSet()
        local here = Login()
        local before = Generations.Get("loadouts")
        h.Stub.SetEquipmentSets({
            { id = 2, name = "Bear", items = { [1] = 500 }, places = {} },
        })
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        h.Equal(Generations.Get("loadouts") - before, 1, "loadouts bumps")
        h.Nil(here.importedSets["equipmentset:Cat"], "old set gone")
        h.DeepEqual(
            here.importedSets["equipmentset:Bear"].items,
            { { id = 500, suffix = 0 } },
            "new set"
        )
    end,

    ["Equipment Manager: login imports once and bumps loadouts once for it"] = function()
        ScriptCatSet()
        LootLogicDB = nil
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Stub.FireEvent("PLAYER_LOGIN")
        -- One bump for the new character's default loadout, one for the import.
        h.Equal(Generations.Get("loadouts"), 2, "loadouts")
    end,

    ["Equipment Manager: the debug snapshot line counts sets and items"] = function()
        ScriptCatSet()
        Login()
        LootLogicDB.debug.enabled = true
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        local log = LootLogicDB.debug.log
        h.True(
            string.find(
                log[#log],
                "snapshot: imported sets, Equipment Manager: sets 1, items 4",
                1,
                true
            ),
            "last line: " .. tostring(log[#log])
        )
    end,

    ["Equipment Manager: no sets writes nothing and bumps nothing"] = function()
        local here = Login()
        h.Nil(here.importedSets, "importedSets")
        -- The default loadout only.
        h.Equal(Generations.Get("loadouts"), 1, "loadouts")
    end,

    ["Equipment Manager: a refresh that finds the same sets changes nothing"] = function()
        ScriptCatSet()
        local here = Login()
        local before = DeepCopy(here.importedSets)
        local bumps = Generations.Get("loadouts")
        h.Stub.Advance(60)
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        h.DeepEqual(here.importedSets, before, "importedSets")
        h.Equal(Generations.Get("loadouts"), bumps, "loadouts")
    end,

    ["Imported sets: a member is found by its roll, and suffix 0 matches every roll"] = function()
        ScriptCatSet()
        Login()
        h.Equal(Sets.IsSetMember(100, -17), true, "the rolled member")
        h.Equal(Sets.IsSetMember(100, -3), false, "another roll of it")
        h.Equal(Sets.IsSetMember(100), false, "no suffix is not the roll")
        h.Equal(Sets.IsSetMember(200, 0), true, "suffix 0 member, suffix 0")
        h.Equal(Sets.IsSetMember(200, -5), true, "suffix 0 member, any roll")
        h.Equal(Sets.IsSetMember(777, 0), false, "not a member")
    end,

    ["Imported sets: a member of an Outfitter set is found too"] = function()
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100, SubCode = 0 } }) } },
        })
        Login()
        h.Equal(Sets.IsSetMember(100, -9), true, "member")
        h.Equal(Sets.IsSetMember(101, 0), false, "non-member")
    end,

    ["Imported sets: only the current character's sets count for membership"] = function()
        local other = LoginWithOther("Boneset", "Hallowine")
        LootLogicDB.characters[other].importedSets = {
            ["outfitter:Tank"] = {
                source = "outfitter",
                name = "Tank",
                items = { { id = 100, suffix = 0 } },
            },
        }
        h.Equal(Sets.IsSetMember(100, 0), false, "another character's member")
    end,

    ["Outfitter: the current character's outfits are imported from Outfitter.Settings"] = function()
        h.Stub.SetOutfitter({
            Outfits = {
                Complete = {
                    Outfit("Tank", {
                        Weapon = { Code = 200, SubCode = -17, UniqueID = 5 },
                        Head = { Code = 100, SubCode = 0 },
                        Back = { Code = 0 },
                    }),
                },
                Accessory = { Outfit("Rings", { Finger0 = { Code = 300 } }) },
            },
        })
        local here = Login()
        h.DeepEqual(here.importedSets, {
            ["outfitter:Tank"] = {
                source = "outfitter",
                name = "Tank",
                updatedAt = GetServerTime(),
                items = { { id = 100, suffix = 0 }, { id = 200, suffix = -17 } },
            },
            ["outfitter:Rings"] = {
                source = "outfitter",
                name = "Rings",
                updatedAt = GetServerTime(),
                items = { { id = 300, suffix = 0 } },
            },
        }, "importedSets")
    end,

    ["Outfitter: a refresh bumps loadouts once and writes one snapshot line"] = function()
        local settings = {
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        }
        h.Stub.SetOutfitter(settings)
        Login()
        LootLogicDB.debug.enabled = true
        local before = Generations.Get("loadouts")
        settings.Outfits.Complete[1].Items.Head.Code = 101
        h.Stub.FireOutfitterEvent("ADD_OUTFIT")
        h.Equal(Generations.Get("loadouts") - before, 1, "loadouts bumps")
        local log = LootLogicDB.debug.log
        h.Equal(#log, 2, "event line and snapshot line")
        h.True(string.find(log[1], "event: ADD_OUTFIT", 1, true), "event line: " .. log[1])
        h.True(
            string.find(log[2], "snapshot: imported sets, Outfitter: sets 1, items 1", 1, true),
            "snapshot line: " .. log[2]
        )
    end,

    ["Outfitter: a refresh that finds the same outfits bumps nothing"] = function()
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        })
        Login()
        local before = Generations.Get("loadouts")
        h.Stub.FireOutfitterEvent("EDIT_OUTFIT")
        h.Equal(Generations.Get("loadouts"), before, "loadouts")
    end,

    ["Outfitter: a removed Outfitter clears the Outfitter sets at login only of here"] = function()
        ScriptCatSet()
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        })
        local here = Login()
        h.True(here.importedSets["outfitter:Tank"], "imported")
        h.Stub.RemoveOutfitter()
        local before = Generations.Get("loadouts")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Nil(here.importedSets["outfitter:Tank"], "cleared")
        h.True(here.importedSets["equipmentset:Cat"], "Equipment Manager set kept")
        h.Equal(Generations.Get("loadouts") - before, 1, "one bump")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(Generations.Get("loadouts") - before, 1, "no bump when nothing is left")
    end,

    ["Equipment Manager: an empty list at login keeps the saved sets"] = function()
        ScriptCatSet()
        local here = Login()
        local before = Generations.Get("loadouts")
        h.Stub.SetEquipmentSets({})
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.True(here.importedSets["equipmentset:Cat"], "kept at login")
        h.Equal(Generations.Get("loadouts"), before, "no bump")
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        h.Nil(here.importedSets["equipmentset:Cat"], "replaced on the change event")
    end,

    ["Equipment Manager: a non-empty list at login replaces the saved sets"] = function()
        ScriptCatSet()
        local here = Login()
        h.Stub.SetEquipmentSets({ { id = 2, name = "Bear", items = { [1] = 500 }, places = {} } })
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Nil(here.importedSets["equipmentset:Cat"], "old set")
        h.True(here.importedSets["equipmentset:Bear"], "new set")
    end,

    ["Outfitter: outfits with one name in two categories are merged into one set"] = function()
        h.Stub.SetOutfitter({
            Outfits = {
                Complete = { Outfit("Tank", { Head = { Code = 100 } }) },
                Accessory = { Outfit("Tank", { Finger0 = { Code = 300, SubCode = -2 } }) },
            },
        })
        local here = Login()
        local count = 0
        for _ in pairs(here.importedSets) do
            count = count + 1
        end
        h.Equal(count, 1, "one set")
        h.DeepEqual(
            here.importedSets["outfitter:Tank"].items,
            { { id = 300, suffix = -2 }, { id = 100, suffix = 0 } },
            "members of both"
        )
    end,

    ["Outfitter: a failing refresh in an Outfitter callback is recorded, not raised"] = function()
        local settings = {}
        h.Stub.SetOutfitter(settings)
        Login()
        setmetatable(settings, {
            __index = function()
                error("boom")
            end,
        })
        local before = #ns.Log.Errors()
        h.Stub.FireOutfitterEvent("EDIT_OUTFIT")
        local errors = ns.Log.Errors()
        h.Equal(#errors, before + 1, "one more error")
        h.Equal(errors[#errors].area, "events", "area")
    end,

    ["Outfitter: its event line carries the event's arguments"] = function()
        h.Stub.SetOutfitter({ Outfits = {} })
        Login()
        LootLogicDB.debug.enabled = true
        h.Stub.FireOutfitterEvent("ADD_OUTFIT", "Tank", { 1 })
        h.True(
            string.find(LootLogicDB.debug.log[1], "event: ADD_OUTFIT: Tank, <table>", 1, true),
            "line"
        )
    end,

    ["Outfitter: the five events refresh and the others are not registered"] = function()
        h.Stub.SetOutfitter({ Outfits = { Complete = {} } })
        Login()
        for _, event in ipairs({
            "OUTFITTER_INIT",
            "ADD_OUTFIT",
            "DELETE_OUTFIT",
            "EDIT_OUTFIT",
            "DID_RENAME_OUTFIT",
        }) do
            h.Equal(h.Stub.OutfitterHandlerCount(event), 1, event .. " registered")
        end
        h.Equal(h.Stub.OutfitterHandlerCount("WEAR_OUTFIT"), 0, "WEAR_OUTFIT")
        h.Equal(h.Stub.OutfitterHandlerCount("UNWEAR_OUTFIT"), 0, "UNWEAR_OUTFIT")
    end,

    ["Outfitter: delete and rename events re-read the outfits"] = function()
        local settings = {
            Outfits = {
                Complete = {
                    Outfit("Tank", { Head = { Code = 100 } }),
                    Outfit("Cat", { Head = { Code = 101 } }),
                },
            },
        }
        h.Stub.SetOutfitter(settings)
        local here = Login()
        settings.Outfits.Complete = { Outfit("Cat", { Head = { Code = 101 } }) }
        h.Stub.FireOutfitterEvent("DELETE_OUTFIT")
        h.Nil(here.importedSets["outfitter:Tank"], "deleted")
        settings.Outfits.Complete[1].Name = "Kitty"
        h.Stub.FireOutfitterEvent("DID_RENAME_OUTFIT")
        h.Nil(here.importedSets["outfitter:Cat"], "old name")
        h.Equal(here.importedSets["outfitter:Kitty"].items[1].id, 101, "new name")
    end,

    ["Outfitter: its sets and the Equipment Manager's are refreshed separately"] = function()
        ScriptCatSet()
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        })
        local here = Login()
        h.True(here.importedSets["equipmentset:Cat"], "Equipment Manager set")
        h.True(here.importedSets["outfitter:Tank"], "Outfitter set")
        h.Stub.SetEquipmentSets({})
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        h.Nil(here.importedSets["equipmentset:Cat"], "Equipment Manager set gone")
        h.True(here.importedSets["outfitter:Tank"], "Outfitter set kept")
    end,

    ["Outfitter: an Outfitter that loads after login is read on its ADDON_LOADED"] = function()
        local here = Login()
        h.Nil(here.importedSets, "nothing at login")
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        })
        h.Stub.FireEvent("ADDON_LOADED", "SomethingElse")
        h.Nil(here.importedSets, "another addon")
        h.Stub.FireEvent("ADDON_LOADED", "OutfitterForever")
        h.True(here.importedSets["outfitter:Tank"], "imported")
        h.Equal(h.Stub.OutfitterHandlerCount("ADD_OUTFIT"), 1, "registered once")
        h.Stub.FireEvent("ADDON_LOADED", "OutfitterForever")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(h.Stub.OutfitterHandlerCount("ADD_OUTFIT"), 1, "still registered once")
    end,

    ["Outfitter: without Outfitter nothing is written and nothing is bumped"] = function()
        local here = Login()
        h.Nil(here.importedSets, "importedSets")
        -- The default loadout only.
        h.Equal(Generations.Get("loadouts"), 1, "loadouts")
    end,

    ["Outfitter: other characters are matched by first name plus region"] = function()
        h.Stub.SetOutfitterGlobal({
            ["Boneset-Region"] = {
                Name = "Boneset",
                Outfits = {
                    Complete = { Outfit("Healer", { Head = { Code = 600, SubCode = -4 } }) },
                },
            },
            ["Boneset-Elsewhere"] = {
                Outfits = { Complete = { Outfit("Wrong", { Head = { Code = 1 } }) } },
            },
        })
        local other = LoginWithOther("Boneset", "Hallowine")
        h.DeepEqual(LootLogicDB.characters[other].importedSets, {
            ["outfitter:Healer"] = {
                source = "outfitter",
                name = "Healer",
                updatedAt = GetServerTime(),
                items = { { id = 600, suffix = -4 } },
            },
        }, "importedSets")
    end,

    ["Outfitter: a character whose first name is shared is skipped"] = function()
        h.Stub.SetOutfitterGlobal({
            ["Boneset-Region"] = {
                Outfits = { Complete = { Outfit("Healer", { Head = { Code = 600 } }) } },
            },
        })
        LootLogicDB = nil
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        local first = "Boneset Hallowine-Region"
        local second = "Boneset Wine-Region"
        LootLogicDB.characters[first] = { first = "Boneset", last = "Hallowine", region = "Region" }
        LootLogicDB.characters[second] = { first = "Boneset", last = "Wine", region = "Region" }
        LootLogicDB.order = { first, second }
        h.Stub.SetOutfitter({ Outfits = { Complete = {} } })
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Nil(LootLogicDB.characters[first].importedSets, "first sharer")
        h.Nil(LootLogicDB.characters[second].importedSets, "second sharer")
    end,

    ["Outfitter: a character with no copy keeps its sets"] = function()
        h.Stub.SetOutfitterGlobal({
            ["Boneset-Region"] = {
                Outfits = { Complete = { Outfit("Healer", { Head = { Code = 600 } }) } },
            },
        })
        local other = LoginWithOther("Boneset", "Hallowine")
        h.True(LootLogicDB.characters[other].importedSets["outfitter:Healer"], "imported")
        h.Stub.SetOutfitterGlobal({})
        h.Stub.SetOutfitter({ Outfits = { Complete = {} } })
        h.Stub.FireEvent("ADDON_LOADED", "OutfitterForever")
        h.True(LootLogicDB.characters[other].importedSets["outfitter:Healer"], "kept")
    end,

    ["Outfitter: another character's copy is not used for here"] = function()
        h.Stub.SetOutfitterGlobal({
            ["Zugar-Region"] = {
                Outfits = { Complete = { Outfit("Stale", { Head = { Code = 600 } }) } },
            },
        })
        local here = Login()
        h.Nil(here.importedSets, "importedSets")
    end,

    ["Imports never write to Outfitter or to the Equipment Manager's data"] = function()
        ScriptCatSet()
        local settings = {
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100, SubCode = -3 } }) } },
        }
        h.Stub.SetOutfitter(settings)
        local characters = {
            ["Boneset-Region"] = {
                Outfits = { Complete = { Outfit("Healer", { Head = { Code = 600 } }) } },
            },
        }
        h.Stub.SetOutfitterGlobal(characters)
        local settingsBefore = DeepCopy(settings)
        local charactersBefore = DeepCopy(characters)
        LoginWithOther("Boneset", "Hallowine")
        h.Stub.FireOutfitterEvent("EDIT_OUTFIT")
        h.DeepEqual(settings, settingsBefore, "Outfitter.Settings")
        h.DeepEqual(characters, charactersBefore, "global copy")
    end,

    ["Imports: a read-only session writes nothing and bumps nothing"] = function()
        ScriptCatSet()
        h.Stub.SetOutfitter({
            Outfits = { Complete = { Outfit("Tank", { Head = { Code = 100 } }) } },
        })
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Stub.FireEvent("EQUIPMENT_SETS_CHANGED")
        h.Stub.FireOutfitterEvent("ADD_OUTFIT")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.Equal(Generations.Get("loadouts"), 0, "loadouts")
    end,
}
