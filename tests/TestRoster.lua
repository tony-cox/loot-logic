local _, ns, h = ...

local DB = ns.DB
local Generations = ns.Generations
local Roster = ns.Roster

local HERE = "Zugar Soulsour-Region"

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
end

local function Login()
    h.Stub.FireEvent("PLAYER_LOGIN")
end

-- Adds a saved character as an earlier session would have left it.
local function AddCharacter(first, last, faction, region)
    local key = first .. " " .. last .. "-" .. region
    LootLogicDB.characters[key] = {
        first = first,
        last = last,
        region = region,
        faction = faction,
        class = "DRUID",
    }
    LootLogicDB.order[#LootLogicDB.order + 1] = key
    return key
end

return {
    ["Roster: the key joins two names and the region"] = function()
        Boot()
        h.Equal(Roster.HereKey(), HERE, "key")
    end,

    ["Roster: an empty realm name with no saved region to map to registers nothing"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = "CampRealm" })
        Boot()
        Login()
        h.Nil(Roster.HereKey(), "key")
        h.DeepEqual(LootLogicDB.order, {}, "order")
    end,

    ["Roster: the normalised realm maps back to the saved region"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = "CampRealm1" })
        Boot()
        local other = AddCharacter("Aa", "One", "Horde", "Camp Realm 1")
        local saved = AddCharacter("Zugar", "Soulsour", "Horde", "Camp Realm 1")
        Login()
        h.Equal(Roster.HereKey(), saved, "key keeps the saved region")
        h.DeepEqual(LootLogicDB.order, { other, saved }, "no second entry")
        h.DeepEqual(Roster.EligibleKeys(), { other }, "others stay eligible")
    end,

    ["Roster: with no realm name at all the saved region of the same names is used"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        local other = AddCharacter("Aa", "One", "Horde", "Camp Realm 1")
        local saved = AddCharacter("Zugar", "Soulsour", "Horde", "Camp Realm 1")
        Login()
        h.Equal(Roster.HereKey(), saved, "key keeps the saved region")
        h.DeepEqual(Roster.EligibleKeys(), { other }, "others stay eligible")
    end,

    ["Roster: no realm name at login registers at PLAYER_ENTERING_WORLD"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        Login()
        h.Nil(Roster.HereKey(), "key at login")
        h.DeepEqual(LootLogicDB.order, {}, "nothing registered")
        h.Stub.SetPlayer({ realm = "Region" })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Equal(Roster.HereKey(), HERE, "key after entering the world")
        h.DeepEqual(LootLogicDB.order, { HERE }, "registered once")
    end,

    ["Roster: the late registration at PLAYER_ENTERING_WORLD adds a default loadout"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        Login()
        h.Stub.SetPlayer({ realm = "Region" })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Equal(#LootLogicDB.characters[HERE].loadouts, 1, "default loadout")
    end,

    ["Roster: a second PLAYER_ENTERING_WORLD registers nothing more"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        Login()
        h.Stub.SetPlayer({ realm = "Region" })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Stub.SetPlayer({ realm = "Other" })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Equal(Roster.HereKey(), HERE, "key")
        h.DeepEqual(LootLogicDB.order, { HERE }, "order")
    end,

    ["Roster: the retry while the region is still empty registers nothing"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        Login()
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Nil(Roster.HereKey(), "key")
    end,

    ["Roster: an unmatched normalised realm uses the saved region of the same names"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = "Unmatched" })
        Boot()
        local saved = AddCharacter("Zugar", "Soulsour", "Horde", "Camp Realm 1")
        Login()
        h.Equal(Roster.HereKey(), saved, "key")
    end,

    ["Roster: the same names in two regions register nothing without a realm"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        AddCharacter("Zugar", "Soulsour", "Horde", "Camp Realm 1")
        AddCharacter("Zugar", "Soulsour", "Horde", "Camp Realm 2")
        Login()
        h.Nil(Roster.HereKey(), "key")
    end,

    ["Roster: RegisterNow keeps the region from login when the realm name is empty"] = function()
        Boot()
        Login()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        LootLogicDB.characters[HERE].region = nil
        Roster.RegisterNow()
        h.Equal(LootLogicDB.characters[HERE].region, "Region", "region")
    end,

    ["Roster: a late registration runs the handlers added with OnLateRegister once"] = function()
        h.Stub.SetPlayer({ realm = "", normalizedRealm = false })
        Boot()
        local calls = 0
        Roster.OnLateRegister(function()
            calls = calls + 1
        end)
        Login()
        h.Equal(calls, 0, "none at login")
        h.Stub.SetPlayer({ realm = "Region" })
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD")
        h.Equal(calls, 1, "once")
    end,

    ["Roster: the key is nil when the game gives no name"] = function()
        h.Stub.SetPlayer({ first = false, last = false })
        Boot()
        h.Nil(Roster.HereKey(), "key")
        Login()
        h.DeepEqual(LootLogicDB.order, {}, "order")
    end,

    ["Roster: login writes the entry of spec 6"] = function()
        h.Stub.SetPlayer({
            race = "Night Elf",
            raceToken = "NightElf",
            raceID = 4,
            class = "DRUID",
            className = "Druid",
            level = 23,
            faction = "Alliance",
            factionName = "Allianz",
        })
        h.Stub.SetAddOnMetadata("LootLogic", "Version", "1.0.0")
        Boot()
        Login()
        h.DeepEqual(LootLogicDB.characters[HERE], {
            first = "Zugar",
            last = "Soulsour",
            region = "Region",
            faction = "Alliance",
            class = "DRUID",
            race = "NightElf",
            level = 23,
            lastSeen = 1704067200,
            build = "1.60.1.12345",
            lootLogicVersion = "1.0.0",
            loadouts = LootLogicDB.characters[HERE].loadouts,
        }, "entry")
    end,

    ["Roster: login registers once, appends to order once, bumps roster once"] = function()
        Boot()
        AddCharacter("Boneset", "Hallowine", "Horde", "Region")
        local before = Generations.Get("roster")
        Login()
        Login()
        h.DeepEqual(LootLogicDB.order, { "Boneset Hallowine-Region", HERE }, "order")
        h.Equal(Generations.Get("roster") - before, 1, "roster bumps")
        h.True(Roster.WasAddedThisSession(HERE), "added this session")
    end,

    ["Roster: a known character is refreshed, not added, and keeps its other fields"] = function()
        Boot()
        LootLogicDB.characters[HERE] = {
            first = "Zugar",
            last = "Soulsour",
            level = 10,
            receivesGear = false,
            displayName = "Zug",
        }
        LootLogicDB.order[1] = HERE
        local before = Generations.Get("roster")
        h.Stub.Advance(60)
        Login()
        local entry = LootLogicDB.characters[HERE]
        h.Equal(entry.level, 60, "level refreshed")
        h.Equal(entry.lastSeen, 1704067260, "lastSeen refreshed")
        h.Equal(entry.receivesGear, false, "receivesGear kept")
        h.Equal(entry.displayName, "Zug", "displayName kept")
        h.Equal(#LootLogicDB.order, 1, "order unchanged")
        h.Equal(Generations.Get("roster"), before, "roster not bumped")
        h.Equal(Roster.WasAddedThisSession(HERE), false, "not added this session")
    end,

    ["Roster: a known character missing from the order is appended"] = function()
        Boot()
        LootLogicDB.characters[HERE] = { first = "Zugar", last = "Soulsour" }
        local before = Generations.Get("roster")
        Login()
        h.DeepEqual(LootLogicDB.order, { HERE }, "order")
        h.Equal(Generations.Get("roster") - before, 1, "roster bumps")
    end,

    ["Roster: lastSeen is written at login and at logout from the clock"] = function()
        Boot()
        Login()
        h.Equal(LootLogicDB.characters[HERE].lastSeen, 1704067200, "login")
        h.Stub.Advance(3600)
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.Equal(LootLogicDB.characters[HERE].lastSeen, 1704070800, "logout")
    end,

    ["Roster: logout writes lastSeen and nothing else"] = function()
        Boot()
        Login()
        local entry = LootLogicDB.characters[HERE]
        entry.level = 5
        entry.faction = "Neutral"
        h.Stub.Advance(10)
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.Equal(entry.level, 5, "level")
        h.Equal(entry.faction, "Neutral", "faction")
        h.Equal(entry.lastSeen, 1704067210, "lastSeen")
        h.Equal(Generations.Get("roster"), 1, "roster bumps")
    end,

    ["Roster: logout of an unregistered character creates nothing"] = function()
        Boot()
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.DeepEqual(LootLogicDB.characters, {}, "characters")
    end,

    ["Roster: a read-only session writes nothing"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Equal(DB.IsReadOnly(), true, "read-only")
        Login()
        h.Stub.Advance(5)
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data")
        h.Equal(Generations.Get("roster"), 0, "roster bumps")
        h.Equal(Roster.WasAddedThisSession(HERE), false, "added this session")
    end,

    ["Roster: a read-only session refuses order and switch changes"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        local result, reason = Roster.SetOrder({ "A" })
        h.Nil(result, "order result")
        h.Equal(reason, "readonly", "order reason")
        result, reason = Roster.SetReceivesGear("A", false)
        h.Nil(result, "gear result")
        h.Equal(reason, "readonly", "gear reason")
        h.Equal(Generations.Get("roster"), 0, "roster bumps")
    end,

    ["Roster: eligibility needs the same faction and region and not here"] = function()
        Boot()
        Login()
        local same = AddCharacter("Boneset", "Hallowine", "Horde", "Region")
        local otherFaction = AddCharacter("Chamoomile", "Rejuvenade", "Alliance", "Region")
        local otherRegion = AddCharacter("Tana", "Tan", "Horde", "Elsewhere")
        h.Equal(Roster.IsEligible(same), true, "same faction and region")
        h.Equal(Roster.IsEligible(otherFaction), false, "other faction")
        h.Equal(Roster.IsEligible(otherRegion), false, "other region")
        h.Equal(Roster.IsEligible(HERE), false, "here")
        h.Equal(Roster.IsEligible("Nobody Known-Region"), false, "unregistered")
        h.DeepEqual(Roster.EligibleKeys(), { same }, "eligible keys")
        h.Equal(Roster.IsHere(HERE), true, "is here")
        h.Equal(Roster.IsHere(same), false, "is not here")
    end,

    ["Roster: eligible keys follow the priority order"] = function()
        Boot()
        Login()
        local first = AddCharacter("Boneset", "Hallowine", "Horde", "Region")
        local second = AddCharacter("Chamoomile", "Rejuvenade", "Horde", "Region")
        Roster.SetOrder({ second, first })
        h.DeepEqual(Roster.EligibleKeys(), { second, first }, "eligible keys")
    end,

    ["Roster: reorder puts the listed keys first and keeps the rest in order"] = function()
        Boot()
        local a = AddCharacter("Aa", "One", "Horde", "Region")
        local b = AddCharacter("Bb", "Two", "Horde", "Region")
        local c = AddCharacter("Cc", "Three", "Horde", "Region")
        local d = AddCharacter("Dd", "Four", "Horde", "Region")
        local before = Generations.Get("roster")
        h.Equal(Roster.SetOrder({ c, a }), "changed", "result")
        h.DeepEqual(Roster.Keys(), { c, a, b, d }, "order")
        h.DeepEqual(LootLogicDB.order, { c, a, b, d }, "saved order")
        h.Equal(Generations.Get("roster") - before, 1, "roster bumps")
    end,

    ["Roster: reorder counts a repeated key once"] = function()
        Boot()
        local a = AddCharacter("Aa", "One", "Horde", "Region")
        local b = AddCharacter("Bb", "Two", "Horde", "Region")
        Roster.SetOrder({ b, b })
        h.DeepEqual(Roster.Keys(), { b, a }, "order")
    end,

    ["Roster: reorder with an unknown key is refused and changes nothing"] = function()
        Boot()
        local a = AddCharacter("Aa", "One", "Horde", "Region")
        local b = AddCharacter("Bb", "Two", "Horde", "Region")
        local before = Generations.Get("roster")
        local result, reason = Roster.SetOrder({ b, "Nobody" })
        h.Nil(result, "result")
        h.Equal(reason, "unknown", "reason")
        h.DeepEqual(Roster.Keys(), { a, b }, "order")
        h.Equal(Generations.Get("roster"), before, "roster bumps")
    end,

    ["Roster: reorder to the same order changes nothing and bumps nothing"] = function()
        Boot()
        local a = AddCharacter("Aa", "One", "Horde", "Region")
        local b = AddCharacter("Bb", "Two", "Horde", "Region")
        local before = Generations.Get("roster")
        h.Equal(Roster.SetOrder({ a }), "unchanged", "partial prefix")
        h.Equal(Roster.SetOrder({ a, b }), "unchanged", "full list")
        h.Equal(Roster.SetOrder({}), "unchanged", "empty list")
        h.Equal(Generations.Get("roster"), before, "roster bumps")
    end,

    ["Roster: receivesGear nil counts as true, false as false"] = function()
        Boot()
        local key = AddCharacter("Aa", "One", "Horde", "Region")
        h.Nil(LootLogicDB.characters[key].receivesGear, "stored")
        h.Equal(Roster.ReceivesGear(key), true, "nil")
        LootLogicDB.characters[key].receivesGear = false
        h.Equal(Roster.ReceivesGear(key), false, "false")
        h.Equal(Roster.ReceivesGear("Nobody Known-Region"), false, "unknown character")
    end,

    ["Roster: the switch is stored as false for off and nil for on, one bump each"] = function()
        Boot()
        local key = AddCharacter("Aa", "One", "Horde", "Region")
        local before = Generations.Get("roster")
        h.Equal(Roster.SetReceivesGear(key, false), "changed", "off")
        h.Equal(LootLogicDB.characters[key].receivesGear, false, "stored off")
        h.Equal(Roster.SetReceivesGear(key, false), "unchanged", "off again")
        h.Equal(Roster.SetReceivesGear(key, true), "changed", "on")
        h.Nil(LootLogicDB.characters[key].receivesGear, "stored on")
        h.Equal(Roster.SetReceivesGear(key, true), "unchanged", "on again")
        h.Equal(Generations.Get("roster") - before, 2, "roster bumps")
    end,

    ["Roster: the switch of an unknown character is refused"] = function()
        Boot()
        local result, reason = Roster.SetReceivesGear("Nobody Known-Region", false)
        h.Nil(result, "result")
        h.Equal(reason, "unknown", "reason")
        h.Equal(Generations.Get("roster"), 0, "roster bumps")
    end,

    ["Roster: the full name joins first and last"] = function()
        Boot()
        local key = AddCharacter("Aa", "One", "Horde", "Region")
        h.Equal(Roster.FullName(key), "Aa One", "full name")
        h.Nil(Roster.FullName("Nobody Known-Region"), "unknown")
    end,

    ["Roster: a client value that fails leaves the entry in the order"] = function()
        h.Stub.SetPlayer({ version = false })
        Boot()
        Login()
        h.DeepEqual(LootLogicDB.order, { HERE }, "order")
        h.Nil(LootLogicDB.characters[HERE].build, "build")
        h.Equal(LootLogicDB.characters[HERE].first, "Zugar", "first")
    end,

    ["Roster: logout writes lastSeen after the client forgot the name"] = function()
        Boot()
        Login()
        h.Stub.SetPlayer({ first = false, last = false, realm = false })
        h.Stub.Advance(30)
        h.Stub.FireEvent("PLAYER_LOGOUT")
        h.Equal(LootLogicDB.characters[HERE].lastSeen, 1704067230, "lastSeen")
    end,

    ["Roster: the roster entry and loadout exist before a provider's OnUpdate runs"] = function()
        Boot()
        local seen
        ns.Prices.Register({
            id = "fake",
            label = "Fake",
            IsAvailable = function()
                return true
            end,
            GetPrice = function() end,
            OnUpdate = function()
                local entry = LootLogicDB.characters[HERE]
                seen = { entry = entry ~= nil, loadouts = entry ~= nil and entry.loadouts ~= nil }
            end,
        })
        Login()
        h.DeepEqual(seen, { entry = true, loadouts = true }, "state at OnUpdate")
    end,
}
