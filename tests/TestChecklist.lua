local _, ns, h = ...

local L = ns.L
local Stub = h.Stub
local Checklist = ns.Checklist

local HERE = "Local Test-Realm"
local DAY = 86400

-- Boots a Warlock called Local Test with a fresh database.
local function Boot(class, className)
    Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = class or "WARLOCK",
        className = className or "Warlock",
        level = 60,
    })
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
    Stub.ClearChat()
end

local CLASS_NAMES = {
    WARLOCK = "Warlock",
    MAGE = "Mage",
    PRIEST = "Priest",
    PALADIN = "Paladin",
}

-- Adds an alt of the same faction and region, last seen when the current
-- character was unless `fields` says otherwise. A class with no assumed spec
-- gets a loadout named after the class and no spec.
local function AddAlt(first, last, class, fields)
    local key = first .. " " .. last .. "-Realm"
    local entry = {
        first = first,
        last = last,
        class = class,
        faction = "Alliance",
        region = "Realm",
        lastSeen = ns.DB.Data().characters[HERE].lastSeen,
        asks = { types = {}, items = {} },
        protect = {},
        loadouts = {},
    }
    for name, value in pairs(fields or {}) do
        entry[name] = value
    end
    if #entry.loadouts == 0 then
        local spec = ns.Loadouts.AssumedSpec(class)
        entry.loadouts = {
            spec and { name = ns.Specs[spec].label, spec = spec, worn = true, assumed = true }
                or { name = CLASS_NAMES[class], worn = true, assumed = true },
        }
    end
    ns.DB.Data().characters[key] = entry
    table.insert(ns.DB.Data().order, key)
    return key, entry
end

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

local function Generations()
    local names = { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }
    local snapshot = { total = ns.Generations.Total() }
    for _, name in ipairs(names) do
        snapshot[name] = ns.Generations.Get(name)
    end
    return snapshot
end

local function RowsOf(line)
    local rows = {}
    for _, row in ipairs(Checklist.Rows()) do
        if row.line == line then
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function Only(line)
    local rows = RowsOf(line)
    h.Equal(#rows, 1, "one row on line " .. line)
    return rows[1]
end

-- Makes Auctionator available; Prices.Best makes a price seen (never through
-- the checklist).
local function Auctionator(prices, ages)
    Stub.SetAuctionator(Stub.MakeAuctionatorV1(prices or {}, ages or {}))
end

local function StatusTexts(adapters)
    local texts = {}
    for _, row in ipairs(Checklist.StatusRows(adapters or { L.statusTooltip })) do
        texts[#texts + 1] = row.text
    end
    return texts
end

return {
    ["Checklist: line 1 names the current character and is done"] = function()
        Boot()
        local row = Only(1)
        h.Equal(row.text, string.format(L.checkHere, "Local"), "text")
        h.Equal(row.tag, "done", "tag")
        h.True(row.done, "done")
        h.Equal(Checklist.Format(row), L.tagDone .. " " .. row.text, "chat form")
    end,

    ["Checklist: line 2 counts every roster character, singular and plural"] = function()
        Boot()
        local row = Only(2)
        h.Equal(row.text, L.checkRosterOne, "singular")
        h.Equal(row.tag, "info", "not done tag")
        h.Equal(row.done, false, "not done")
        h.True(row.counted, "counted")
        AddAlt("Alt", "Test", "PRIEST")
        row = Only(2)
        h.Equal(row.text, string.format(L.checkRoster, 2), "plural")
        h.Equal(row.tag, "done", "done tag")
        h.True(row.done, "done at two")
        -- An other-faction alt counts too (D216): not only eligible characters.
        AddAlt("Horde", "Test", "PRIEST", { faction = "Horde" })
        h.Equal(Only(2).text, string.format(L.checkRoster, 3), "every roster character")
    end,

    ["Checklist: line 2 counts here and an ineligible alt, and is done at two"] = function()
        Boot()
        AddAlt("Horde", "Test", "PRIEST", { faction = "Horde" })
        local row = Only(2)
        h.Equal(row.text, string.format(L.checkRoster, 2), "counts the other faction")
        h.True(row.done, "done although only one character is eligible")
    end,

    ["Checklist: line 3 tips the current character with no character option"] = function()
        Boot()
        local row = Only(3)
        local command = string.format(L.checkSpecKeepCommand, "Affliction", "Affliction", "")
        h.Equal(row.text, string.format(L.checkSpecAssumed, "Local", "Affliction", command), "text")
        h.Equal(row.tag, "TIP", "tag")
        h.Equal(row.done, false, "not done")
    end,

    ["Checklist: line 3 names an alt in the keep command"] = function()
        Boot()
        AddAlt("Alt", "Test", "WARLOCK")
        local rows = RowsOf(3)
        h.Equal(#rows, 2, "one row per loadout")
        local option = string.format(L.checkSpecCharacterOption, "Alt")
        local command = string.format(L.checkSpecKeepCommand, "Affliction", "Affliction", option)
        h.Equal(
            rows[2].text,
            string.format(L.checkSpecAssumed, "Alt", "Affliction", command),
            "alt text"
        )
    end,

    ["Checklist: line 3 quotes a display name with a space"] = function()
        Boot()
        AddAlt("Boneset", "Hale", "WARLOCK")
        AddAlt("Boneset", "Ivy", "WARLOCK")
        local rows = RowsOf(3)
        h.Equal(#rows, 3, "three loadouts")
        local option = string.format(L.checkSpecCharacterOption, '"Boneset H"')
        local command = string.format(L.checkSpecKeepCommand, "Affliction", "Affliction", option)
        h.Equal(
            rows[2].text,
            string.format(L.checkSpecAssumed, "Boneset H", "Affliction", command),
            "spaced name quoted"
        )
    end,

    ["Checklist: line 3 quotes a loadout name with a space"] = function()
        Boot()
        ns.DB.Data().characters[HERE].loadouts[1].name = "Fire set"
        local command = string.format(L.checkSpecKeepCommand, '"Fire set"', "Affliction", "")
        h.Equal(
            Only(3).text,
            string.format(L.checkSpecAssumed, "Local", "Affliction", command),
            "text"
        )
    end,

    ["Checklist: line 3 has no tip once the spec is picked"] = function()
        Boot()
        ns.DB.Data().characters[HERE].loadouts[1].assumed = nil
        local row = Only(3)
        h.Equal(row.text, L.checkSpecDone, "done text")
        h.Equal(row.tag, "done", "tag")
        h.True(row.done, "done")
    end,

    ["Checklist: line 3 shows no gear advice for a class with no table"] = function()
        Boot("MAGE", "Mage")
        local rows = RowsOf(3)
        h.Equal(#rows, 1, "the info entry only, no separate done row")
        h.Equal(rows[1].text, string.format(L.checkSpecNoAdvice, "Mage"), "text")
        h.Equal(rows[1].tag, "info", "tag")
        h.True(rows[1].done, "counts as done")
        h.Nil(string.find(rows[1].text, "/ll loadout", 1, true), "no keep command")
    end,

    ["Checklist: line 3 names the spec when its saved spec has no table"] = function()
        Boot()
        local loadout = ns.DB.Data().characters[HERE].loadouts[1]
        loadout.name = "Destro"
        loadout.spec = "WARLOCK:destruction"
        local rows = RowsOf(3)
        h.Equal(#rows, 1, "one entry")
        h.Equal(
            rows[1].text,
            string.format(L.checkSpecNoTable, "Destro", ns.Specs["WARLOCK:destruction"].label),
            "text"
        )
        h.Equal(rows[1].tag, "info", "tag")
        h.True(rows[1].done, "done")
        h.Nil(string.find(rows[1].text, "/ll loadout", 1, true), "no keep command")
    end,

    ["Checklist: line 3 falls back to the spec key for a spec not in the catalogue"] = function()
        Boot()
        local loadout = ns.DB.Data().characters[HERE].loadouts[1]
        loadout.spec = "WARLOCK:nonesuch"
        h.Equal(Only(3).text, string.format(L.checkSpecNoTable, "Affliction", "WARLOCK:nonesuch"))
    end,

    ["Checklist: line 3 follows roster order, not key order"] = function()
        Boot()
        local mage = AddAlt("Mage", "Alt", "MAGE")
        local pal = AddAlt("Pal", "Alt", "PALADIN")
        ns.Roster.SetOrder({ pal, HERE, mage })
        local rows = RowsOf(3)
        h.Equal(#rows, 3, "rows")
        h.Equal(rows[1].tag, "TIP", "paladin first")
        h.True(string.find(rows[1].text, "^Pal is using an assumed spec %(Protection%)"), "pal")
        h.Equal(rows[2].tag, "TIP", "here second")
        h.True(string.find(rows[2].text, "^Local is using"), "here")
        h.Equal(rows[3].text, string.format(L.checkSpecNoAdvice, "Mage"), "mage last")
    end,

    ["Checklist: line 4 covers eligible destinations only"] = function()
        Boot()
        h.Equal(Only(4).text, L.checkWantsDone, "nobody to cover")
        AddAlt("Jujuniper", "Test", "PRIEST")
        AddAlt("Other", "Test", "PRIEST", { faction = "Horde" })
        local rows = RowsOf(4)
        h.Equal(#rows, 1, "the other faction is not covered, here is not covered")
        h.Equal(rows[1].text, string.format(L.checkWantsNothing, "Jujuniper"), "text")
        h.Equal(rows[1].tag, "info", "info only")
        h.Equal(rows[1].done, false, "not done")
    end,

    ["Checklist: line 4 is done for a type want or an item include"] = function()
        Boot()
        local _, typed = AddAlt("Typed", "Test", "PRIEST")
        typed.asks.types["7:5"] = true
        local _, included = AddAlt("Included", "Test", "PRIEST")
        included.asks.items[2589] = "include"
        local row = Only(4)
        h.Equal(row.text, L.checkWantsDone, "text")
        h.Equal(row.tag, "done", "tag")
        h.True(row.done, "done")
    end,

    ["Checklist: line 4 treats an exclude alone as no want"] = function()
        Boot()
        local _, entry = AddAlt("Excl", "Test", "PRIEST")
        entry.asks.items[2589] = "exclude"
        entry.asks.types["7:5"] = false
        local row = Only(4)
        h.Equal(row.text, string.format(L.checkWantsNothing, "Excl"), "text")
        h.Equal(row.done, false, "not done")
    end,

    ["Checklist: line 4 counts a character with gear off and no want as done"] = function()
        Boot()
        AddAlt("Bankalt", "Test", "PRIEST", { receivesGear = false })
        local rows = RowsOf(4)
        h.Equal(#rows, 1, "the info entry only, no separate done row")
        h.Equal(rows[1].text, string.format(L.checkWantsNoGear, "Bankalt"), "text")
        h.Equal(rows[1].tag, "info", "tag")
        h.True(rows[1].done, "done")
    end,

    ["Checklist: line 4 follows roster order, not key order"] = function()
        Boot()
        local first = AddAlt("Aaa", "Test", "PRIEST")
        local second = AddAlt("Zzz", "Test", "PRIEST")
        ns.Roster.SetOrder({ second, HERE, first })
        local rows = RowsOf(4)
        h.Equal(#rows, 2, "two entries")
        h.Equal(rows[1].text, string.format(L.checkWantsNothing, "Zzz"), "Zzz first")
        h.Equal(rows[2].text, string.format(L.checkWantsNothing, "Aaa"), "Aaa second")
    end,

    ["Checklist: line 4 ignores ui.ack"] = function()
        Boot()
        AddAlt("Quiet", "Test", "PRIEST")
        ns.DB.Data().ui.ack = { gearOnly = { ["Quiet Test-Realm"] = true } }
        h.Equal(Only(4).done, false, "still not done")
    end,

    ["Checklist: line 5 without Auctionator is the no-price tip"] = function()
        Boot()
        local row = Only(5)
        h.Equal(row.text, L.checkPriceNone, "text")
        h.Equal(row.tag, "TIP", "tag")
        h.Equal(row.done, false, "not done")
    end,

    ["Checklist: line 5 found but not seen"] = function()
        Boot()
        Auctionator()
        h.Equal(Only(5).text, string.format(L.checkPriceUnseen, "Auctionator"), "text")
    end,

    ["Checklist: line 5 seen with no age"] = function()
        Boot()
        Auctionator({ [100] = 50 })
        ns.Prices.Best(100)
        local row = Only(5)
        h.Equal(row.text, string.format(L.checkPriceOver, "Auctionator"), "text")
        h.Equal(row.done, false, "not done")
    end,

    ["Checklist: line 5 seen older than the maximum"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 9 })
        ns.Prices.Best(100)
        local row = Only(5)
        h.Equal(row.text, string.format(L.checkPriceStale, 9), "text")
        h.Equal(row.tag, "TIP", "tag")
        h.Equal(row.done, false, "not done")
    end,

    ["Checklist: line 5 is done at exactly the maximum age"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 7 })
        ns.Prices.Best(100)
        local row = Only(5)
        h.Equal(row.text, string.format(L.checkPriceAge, "Auctionator", 7), "text")
        h.Equal(row.tag, "done", "tag")
        h.True(row.done, "done")
    end,

    ["Checklist: line 5 reads today at age 0"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 0 })
        ns.Prices.Best(100)
        h.Equal(Only(5).text, string.format(L.checkPriceToday, "Auctionator"), "text")
    end,

    ["Checklist: building the rows makes no Auctionator call and no Best call"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 2 })
        ns.Prices.Best(100)
        local calls = #Stub.AuctionatorCalls()
        local original = ns.Prices.Best
        ns.Prices.Best = function()
            error("Prices.Best must not be called")
        end
        Checklist.Rows()
        Checklist.StatusRows({ L.statusTooltip })
        ns.Prices.Best = original
        h.Equal(#Stub.AuctionatorCalls(), calls, "no Auctionator call")
    end,

    ["Checklist: line 6 is the same every time"] = function()
        Boot()
        local first = Only(6)
        h.Equal(first.text, L.checkBags, "text")
        h.Equal(first.tag, "info", "tag")
        AddAlt("Alt", "Test", "PRIEST")
        Auctionator({ [100] = 50 }, { [100] = 0 })
        h.DeepEqual(Only(6), first, "unchanged")
    end,

    ["Checklist: line 7 follows the bank snapshot and is never counted"] = function()
        Boot()
        local row = Only(7)
        h.Equal(row.text, L.checkBankUnseen, "not seen")
        h.Equal(row.tag, "info", "tag")
        h.Equal(row.done, false, "not done")
        h.Equal(row.counted, false, "not counted")
        Stub.OpenBank()
        row = Only(7)
        h.Equal(row.text, L.checkBankSeen, "seen")
        h.Equal(row.tag, "done", "done tag")
        h.True(row.done, "done")
        h.Equal(row.counted, false, "still not counted")
        Stub.CloseBank()
    end,

    ["Checklist: the rows come in line order"] = function()
        Boot()
        AddAlt("Alt", "Test", "WARLOCK")
        local previous = 0
        for _, row in ipairs(Checklist.Rows()) do
            h.True(row.line >= previous, "line " .. row.line .. " after " .. previous)
            previous = row.line
        end
        h.Equal(previous, 7, "ends with line 7")
    end,

    ["Checklist: a read-only session builds the rows and changes nothing"] = function()
        Boot()
        local database = h.Fixture("dbNewer")
        database.characters = {
            [HERE] = {
                first = "Local",
                last = "Test",
                class = "WARLOCK",
                faction = "Alliance",
                region = "Realm",
                lastSeen = 1,
                asks = { types = {}, items = {} },
                protect = {},
                loadouts = { { name = "Affliction", spec = "WARLOCK:affliction", worn = true } },
            },
        }
        database.order = { HERE }
        LootLogicDB = database
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.True(ns.DB.IsReadOnly(), "read-only")
        local before = Copy(LootLogicDB)
        local generations = Generations()
        h.Equal(#Checklist.Rows(), 7, "seven rows")
        Checklist.StatusRows({ L.statusTooltip })
        h.DeepEqual(LootLogicDB, before, "saved data unchanged")
        h.DeepEqual(Generations(), generations, "generations unchanged")
    end,

    ["Checklist: building rows leaves saved data and generations unchanged"] = function()
        Boot()
        AddAlt("Alt", "Test", "PRIEST")
        Auctionator({ [100] = 50 }, { [100] = 2 })
        ns.Prices.Best(100)
        ns.Log.Error("engine", "boom")
        local before = Copy(LootLogicDB)
        local generations = Generations()
        Checklist.Rows()
        Checklist.StatusRows({ L.statusTooltip })
        h.DeepEqual(LootLogicDB, before, "saved data unchanged")
        h.DeepEqual(Generations(), generations, "generations unchanged")
    end,

    ["Checklist: status prices with no provider"] = function()
        Boot()
        h.Equal(StatusTexts()[1], L.statusPriceNone, "none")
    end,

    ["Checklist: status prices found, seen with an age and seen with no age"] = function()
        Boot()
        Auctionator({ [100] = 50, [101] = 50 }, { [100] = 3 })
        h.Equal(StatusTexts()[1], string.format(L.statusPriceUnseen, "Auctionator"), "unseen")
        ns.Prices.Best(101)
        h.Equal(StatusTexts()[1], string.format(L.statusPriceOver, "Auctionator"), "no age")
        ns.Prices.Best(100)
        h.Equal(StatusTexts()[1], string.format(L.statusPriceFound, "Auctionator", 3), "age")
    end,

    ["Checklist: status notes the ignored latest-scan setting"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 0 })
        ns.DB.Data().settings.ah.requireLastScan = true
        local texts = StatusTexts()
        h.Equal(texts[1], string.format(L.statusPriceUnseen, "Auctionator"), "provider row")
        h.Equal(texts[2], L.statusPriceLastScan, "note")
    end,

    ["Checklist: status shows an erroring provider until it works"] = function()
        Boot()
        Auctionator({}, {})
        _G.Auctionator.API.v1.GetAuctionPriceByItemID = function()
            error("LastPrice missing", 0)
        end
        ns.Prices.Best(100)
        h.Equal(
            StatusTexts()[1],
            string.format(L.statusPriceError, "Auctionator", "LastPrice missing"),
            "error row"
        )
        _G.Auctionator.API.v1.GetAuctionPriceByItemID = function()
            return 5
        end
        ns.Prices.Best(100)
        h.Nil(string.find(StatusTexts()[1], "error", 1, true), "cleared after a good call")
    end,

    ["Checklist: an OnUpdate error is in the Errors list only"] = function()
        Boot()
        Auctionator({ [100] = 50 }, { [100] = 3 })
        _G.Auctionator.API.v1.RegisterForDBUpdate = function()
            error("no DB update", 0)
        end
        Stub.FireEvent("ADDON_LOADED", "Auctionator")
        ns.Prices.Best(100)
        local texts = StatusTexts()
        h.Equal(texts[1], string.format(L.statusPriceFound, "Auctionator", 3), "reads normally")
        h.True(ns.Log.errorCount > 0, "recorded in the Errors list")
    end,

    ["Checklist: status supplies the adapter rows after the prices"] = function()
        Boot()
        local rows = Checklist.StatusRows({ L.statusTooltip })
        h.Equal(rows[1].area, "prices", "prices first")
        h.Equal(rows[2].area, "adapters", "adapters second")
        h.Equal(rows[2].text, L.statusTooltip, "tooltip row")
        h.Equal(rows[3].area, "roster", "roster third")
        h.Equal(rows[4].area, "errors", "errors last")
    end,

    ["Checklist: status roster is sorted by age with old marked"] = function()
        Boot()
        local now = GetServerTime()
        local function Seen(days)
            return now - days * DAY - 100
        end
        AddAlt("Zugar", "Test", "PRIEST", { lastSeen = Seen(9) })
        AddAlt("Jujuniper", "Test", "PRIEST", { lastSeen = Seen(1) })
        AddAlt("Fresh", "Test", "PRIEST", { lastSeen = now - 3600 })
        AddAlt("Thirteen", "Test", "PRIEST", { lastSeen = Seen(13) })
        AddAlt("Otherguy", "Test", "PRIEST", { lastSeen = Seen(14) })
        AddAlt("Ancient", "Test", "PRIEST", { lastSeen = Seen(15) })
        local function Days(name, days)
            return string.format(L.statusRosterDays, name, days)
        end
        local expected = table.concat({
            string.format(L.statusRosterNow, "Local"),
            string.format(L.statusRosterToday, "Fresh"),
            Days("Jujuniper", 1),
            Days("Zugar", 9),
            Days("Thirteen", 13),
            Days("Otherguy", 14) .. L.statusRosterOld,
            Days("Ancient", 15) .. L.statusRosterOld,
        }, ", ")
        h.Equal(StatusTexts()[3], string.format(L.statusRoster, expected), "roster row")
    end,

    ["Checklist: status roster puts the newest first within the same day"] = function()
        Boot()
        local now = GetServerTime()
        AddAlt("Older", "Test", "PRIEST", { lastSeen = now - 7200 })
        AddAlt("Newer", "Test", "PRIEST", { lastSeen = now - 60 })
        local expected = table.concat({
            string.format(L.statusRosterNow, "Local"),
            string.format(L.statusRosterToday, "Newer"),
            string.format(L.statusRosterToday, "Older"),
        }, ", ")
        h.Equal(StatusTexts()[3], string.format(L.statusRoster, expected), "newest first")
    end,

    ["Checklist: status roster handles a missing lastSeen"] = function()
        Boot()
        local _, entry = AddAlt("Odd", "Test", "PRIEST")
        entry.lastSeen = nil
        local expected = string.format(L.statusRosterNow, "Local")
            .. ", "
            .. string.format(L.statusRosterUnknown, "Odd")
        h.Equal(StatusTexts()[3], string.format(L.statusRoster, expected), "last")
    end,

    ["Checklist: status errors none, three, seven and a repeat"] = function()
        Boot()
        h.Equal(StatusTexts()[4], L.statusErrorsNone, "none")
        for index = 1, 3 do
            ns.Log.Error("events", "failure " .. index)
        end
        local texts = StatusTexts()
        h.Equal(texts[4], string.format(L.statusErrors, 3), "count")
        h.Equal(#texts, 7, "count line then three entries")
        h.True(string.find(texts[5], "^  %d%d:%d%d:%d%d events: failure 3$"), texts[5])
        h.True(string.find(texts[7], "failure 1$", 1), texts[7])
        for index = 4, 7 do
            ns.Log.Error("events", "failure " .. index)
        end
        texts = StatusTexts()
        h.Equal(texts[4], string.format(L.statusErrors, 7), "seven")
        h.Equal(#texts, 9, "count line then five entries")
        h.True(string.find(texts[5], "failure 7$"), "newest first")
        h.True(string.find(texts[9], "failure 3$"), "fifth newest last")
        ns.Log.Error("events", "failure 7")
        texts = StatusTexts()
        h.Equal(texts[4], string.format(L.statusErrors, 8), "repeat counts")
        h.True(string.find(texts[5], "failure 7 %(x2%)$"), texts[5])
    end,
}
