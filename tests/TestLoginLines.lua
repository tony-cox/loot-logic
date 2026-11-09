local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local HERE = "Local Test-Realm"
local PREFIX = L.chatPrefix .. " "

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, inner in pairs(value) do
        result[key] = Copy(inner)
    end
    return result
end

local function GenerationSnapshot()
    local names = { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }
    local snapshot = { total = ns.Generations.Total() }
    for _, name in ipairs(names) do
        snapshot[name] = ns.Generations.Get(name)
    end
    return snapshot
end

local function Lines()
    local copy = {}
    for index, line in ipairs(Stub.ChatLines()) do
        copy[index] = line
    end
    return copy
end

local function SavedEntry(class)
    return {
        first = "Local",
        last = "Test",
        class = class,
        level = 60,
        faction = "Alliance",
        region = "Realm",
        lastSeen = 1,
        asks = { types = {}, items = {} },
        protect = {},
        loadouts = {},
    }
end

-- Boots the current character. `saved` (optional) names what the database holds
-- before ADDON_LOADED: here (the character is already registered), alt (another
-- character), firstRunDone (boolean).
local function Boot(class, className, saved)
    Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = class,
        className = className,
        level = 60,
    })
    LootLogicDB = nil
    if saved then
        LootLogicDB = { schema = ns.Init.schemaVersion, characters = {}, order = {}, ui = {} }
        if saved.alt then
            LootLogicDB.characters["Alt Test-Realm"] = SavedEntry("PRIEST")
            table.insert(LootLogicDB.order, "Alt Test-Realm")
        end
        if saved.here then
            LootLogicDB.characters[HERE] = SavedEntry(class)
            table.insert(LootLogicDB.order, HERE)
        end
        if saved.firstRunDone ~= nil then
            LootLogicDB.ui.firstRunDone = saved.firstRunDone
        end
    end
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
    Stub.ClearChat()
end

local function Added(className, label)
    local name = ns.Roster.DisplayName(HERE)
    if label then
        return PREFIX .. string.format(L.loginAdded, name, className, 60, "Alliance", label)
    end
    return PREFIX .. string.format(L.loginAddedNoTable, name, className, 60, "Alliance", className)
end

local FIRST_RUN = PREFIX .. L.loginFirstRun
local NO_PRICE = PREFIX .. L.loginNoPrice

local function Installed()
    Stub.SetAuctionator(Stub.MakeAuctionatorV1({}, {}))
end

return {
    ["LoginLines: nothing before 5 seconds, then the three lines in order"] = function()
        Boot("WARLOCK", "Warlock")
        Stub.Advance(4.9)
        h.DeepEqual(Lines(), {}, "nothing yet")
        Stub.Advance(0.1)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE }, "three lines")
        Stub.Advance(60)
        h.Equal(#Stub.ChatLines(), 3, "printed once")
    end,

    ["LoginLines: a class with no weight table gets the no-table line"] = function()
        for _, pair in ipairs({ { "WARRIOR", "Warrior" }, { "MAGE", "Mage" } }) do
            Boot(pair[1], pair[2])
            Stub.Advance(5)
            h.DeepEqual(Lines(), { Added(pair[2]), FIRST_RUN, NO_PRICE }, pair[2] .. " lines")
        end
    end,

    ["LoginLines: a later character with the flag set gets only the added line"] = function()
        Boot("WARLOCK", "Warlock", { alt = true, firstRunDone = true })
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction") }, "added only")
    end,

    ["LoginLines: a later character with the flag false gets all three"] = function()
        Boot("WARLOCK", "Warlock", { alt = true, firstRunDone = false })
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE }, "three")
    end,

    ["LoginLines: a returning character with the flag set prints nothing"] = function()
        Boot("WARLOCK", "Warlock", { here = true, firstRunDone = true })
        Stub.Advance(5)
        h.DeepEqual(Lines(), {}, "no lines")
    end,

    ["LoginLines: a returning character with the flag false gets two lines"] = function()
        Boot("WARLOCK", "Warlock", { here = true, firstRunDone = false })
        Stub.Advance(5)
        h.DeepEqual(Lines(), { FIRST_RUN, NO_PRICE }, "two lines")
    end,

    ["LoginLines: Auctionator installed before login drops the no-price line"] = function()
        Installed()
        Boot("WARLOCK", "Warlock")
        local before = #Stub.AuctionatorCalls()
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN }, "no no-price line")
        h.Equal(#Stub.AuctionatorCalls(), before, "the print asks Auctionator for nothing")
    end,

    ["LoginLines: Auctionator installed before the print drops the no-price line"] = function()
        Boot("WARLOCK", "Warlock")
        Stub.Advance(3)
        Installed()
        Stub.Advance(2)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN }, "decided at print")
    end,

    ["LoginLines: Auctionator installed after the print leaves the line printed"] = function()
        Boot("WARLOCK", "Warlock")
        Stub.Advance(5)
        Installed()
        h.DeepEqual(
            Lines(),
            { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE },
            "printed before the install"
        )
    end,

    ["LoginLines: the flag set between login and the print drops both lines"] = function()
        Boot("WARLOCK", "Warlock")
        Stub.Advance(2)
        LootLogicDB.ui.firstRunDone = true
        Stub.Advance(3)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction") }, "added only")
    end,

    ["LoginLines: requireLastScan with Auctionator alone prints no last-scan line"] = function()
        Installed()
        Boot("WARLOCK", "Warlock")
        LootLogicDB.settings.requireLastScan = true
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN }, "no M2 line")
    end,

    ["LoginLines: a provider that raises prints its error line before the group"] = function()
        Boot("WARLOCK", "Warlock")
        _G.Auctionator = setmetatable({}, {
            __index = function()
                error("boom")
            end,
        })
        Stub.Advance(5)
        local lines = Lines()
        h.Equal(#lines, 4, "error line and three lines")
        local pattern = string.gsub(PREFIX .. L.providerFailedNone, "%p", "%%%0")
        pattern = "^" .. string.gsub(pattern, "%%%%s", "(.-)") .. "$"
        local label, message = string.match(lines[1], pattern)
        h.Equal(label, "Auctionator", "error line first, from L.providerFailedNone")
        h.True(string.find(message or "", "boom", 1, true), "carries the message")
        h.DeepEqual(
            { lines[2], lines[3], lines[4] },
            { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE },
            "the group follows in order"
        )
    end,

    ["LoginLines: the lines print in combat while the dialog is held back"] = function()
        Stub.SetCombat(true)
        Boot("WARLOCK", "Warlock")
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE }, "three lines")
        h.Nil(LootLogicWelcome, "no dialog yet")
    end,

    ["LoginLines: the lines print while a client dialog is shown"] = function()
        Stub.SetPopupShown(1, true)
        Boot("WARLOCK", "Warlock")
        Stub.Advance(5)
        h.DeepEqual(Lines(), { Added("Warlock", "Affliction"), FIRST_RUN, NO_PRICE }, "three lines")
        h.Nil(LootLogicWelcome, "no dialog yet")
    end,

    ["LoginLines: a read-only session prints first-run and no-price from the copy"] = function()
        Stub.SetPlayer({
            first = "Local",
            last = "Test",
            realm = "Realm",
            faction = "Alliance",
            class = "WARLOCK",
            className = "Warlock",
            level = 60,
        })
        local database = h.Fixture("dbNewer")
        database.characters = { [HERE] = SavedEntry("WARLOCK") }
        database.order = { HERE }
        LootLogicDB = database
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.True(ns.DB.IsReadOnly(), "read-only")
        Stub.FireEvent("PLAYER_LOGIN")
        Stub.ClearChat()
        local before = Copy(LootLogicDB)
        Stub.Advance(5)
        h.DeepEqual(Lines(), { FIRST_RUN, NO_PRICE }, "no added line, the two others")
        h.DeepEqual(LootLogicDB, before, "saved data unchanged")
    end,

    ["LoginLines: printing writes nothing and bumps no generation"] = function()
        Boot("WARLOCK", "Warlock")
        local saved = Copy(LootLogicDB)
        local generations = GenerationSnapshot()
        Stub.Advance(10)
        h.Equal(#Stub.ChatLines(), 3, "lines printed")
        h.DeepEqual(LootLogicDB, saved, "saved data unchanged")
        h.DeepEqual(GenerationSnapshot(), generations, "generations unchanged")
    end,
}
