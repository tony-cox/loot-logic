local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local PREFIX = L.chatPrefix .. " "

local function Load()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.ClearChat()
end

local function HasLine(text)
    for _, line in ipairs(Stub.ChatLines()) do
        if line == PREFIX .. text then
            return true
        end
    end
    return false
end

local function HasL2Line()
    for _, line in ipairs(Stub.ChatLines()) do
        if string.find(line, "^" .. PREFIX .. "L2 PASS ") then
            return true
        end
    end
    return false
end

local function RunsSaved()
    return LootLogicDB.debug.probe
end

local function ExpectProbe(message)
    Load()
    ns.Slash.Run(message)
    Stub.Advance(11)
    h.True(HasL2Line(), "the L2 line for '" .. message .. "'")
    h.True(HasLine(L.probeDone), "probe done for '" .. message .. "'")
end

local function ExpectPlaceholder(message)
    Load()
    ns.Slash.Run(message)
    local word = string.match(message, "(%S+)") or ""
    local expected = word == "probes" and string.format(L.slashUnknownSuggested, word, "probe")
        or string.format(L.slashUnknown, word)
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. expected }, "chat for '" .. message .. "'")
    h.Nil(RunsSaved(), "nothing saved for '" .. message .. "'")
    h.Equal(#Stub.ChatLines(), 1, "nothing run for '" .. message .. "'")
end

local function LogCount(text)
    local count = 0
    for _, line in ipairs(LootLogicDB.debug.log or {}) do
        if string.find(line, "] " .. text, 1, true) then
            count = count + 1
        end
    end
    return count
end

local function DebugOnLine()
    return string.format(L.debugOn, "300")
end

local function ExpectOnWith(message)
    Load()
    ns.Slash.Run(message)
    h.Equal(LootLogicDB.debug.enabled, true, "enabled for '" .. message .. "'")
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. DebugOnLine() }, "chat for '" .. message .. "'")
end

local function ExpectUsage(message)
    Load()
    LootLogicDB.debug.enabled = true
    ns.Slash.Run(message)
    h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugUsage }, "chat for '" .. message .. "'")
    h.Equal(LootLogicDB.debug.enabled, true, "unchanged for '" .. message .. "'")
end

local function WhyBoot()
    Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = "WARRIOR",
        level = 60,
    })
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.FireEvent("PLAYER_LOGIN")
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = Copy(inner) end
    return result
end

local function GenerationSnapshot()
    local names = { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }
    local snapshot = { total = ns.Generations.Total() }
    for _, name in ipairs(names) do snapshot[name] = ns.Generations.Get(name) end
    return snapshot
end

local function ReadOnlyFixture()
    local database = h.Fixture("dbNewer")
    database.characters = {
        ["Local Test-Realm"] = {
            first = "Local",
            last = "Test",
            class = "WARLOCK",
            faction = "Alliance",
            region = "Realm",
            receivesGear = true,
            asks = { types = {}, items = {} },
            protect = {},
            loadouts = {
                { name = "Affliction", spec = "WARLOCK:affliction", worn = true },
                { name = "Tank", spec = "WARLOCK:demonology" },
            },
        },
        ["Alt Test-Realm"] = {
            first = "Alt",
            last = "Test",
            class = "PRIEST",
            faction = "Alliance",
            region = "Realm",
            asks = { types = {}, items = {} },
            protect = {},
            loadouts = {},
        },
    }
    database.order = { "Local Test-Realm", "Alt Test-Realm" }
    return database
end

local function WhyItem(itemID, suffix)
    local link = "item:" .. itemID
    if suffix then
        link = link .. ":0:0:0:0:0:" .. suffix
    end
    local item = {
        itemID = itemID,
        name = "Why Item",
        link = link,
        quality = 1,
        itemLevel = 1,
        reqLevel = 0,
        sellPrice = 100,
        bindType = 0,
        classID = 7,
        subclassID = 5,
    }
    Stub.SetItem(itemID, item)
    Stub.SetTooltipLines(link, {})
    return link
end

return {
    ["Slash: probe runs the probe"] = function()
        ExpectProbe("probe")
    end,

    ["Slash: PROBE runs the probe (case-insensitive)"] = function()
        ExpectProbe("PROBE")
    end,

    ["Slash: a padded Probe runs the probe"] = function()
        ExpectProbe("  Probe  ")
    end,

    ["Slash: words after probe are ignored"] = function()
        ExpectProbe("probe extra words")
    end,

    ["Slash: bare /ll and help print the M1 help list"] = function()
        h.Equal(
            L.helpMultiPC,
            "LootLogic data is local to this computer. Log in on each character here to add it; "
                .. "its data is as fresh as its last login here. Characters played only on another "
                .. "computer are unseen here.",
            "help explains computer-local roster data and freshness"
        )
        for _, command in ipairs({ "", "help" }) do
            Load()
            ns.Slash.Run(command)
            h.Equal(Stub.ChatLines()[1], PREFIX .. L.helpHeader, "help header")
            h.Equal(Stub.ChatLines()[#Stub.ChatLines()], PREFIX .. L.helpMultiPC, "help footer")
            h.Equal(#Stub.ChatLines(), 14, "help line count")
        end
    end,

    ["Slash: want accepts a numeric type and gear uses the roster setter"] = function()
        WhyBoot()
        ns.Slash.Run("want 7:5")
        h.True(LootLogicDB.characters["Local Test-Realm"].asks.types["7:5"] ~= nil, "type saved")
        ns.Slash.Run("gear Local off")
        h.Equal(LootLogicDB.characters["Local Test-Realm"].receivesGear, false, "gear off")
    end,

    ["Slash: current-character listings and trailing character targets"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        local alt = {
            first = "Alt",
            last = "Test",
            class = "WARLOCK",
            faction = here.faction,
            region = here.region,
            receivesGear = true,
            asks = { types = {}, items = {} },
            loadouts = {
                {
                    name = "Affliction",
                    spec = "WARLOCK:affliction",
                    worn = true,
                    assumed = true,
                },
            },
        }
        LootLogicDB.characters["Alt Test-Realm"] = alt
        LootLogicDB.order = { "Local Test-Realm", "Alt Test-Realm" }
        local before = Copy(LootLogicDB)
        local generation = ns.Generations.Total()
        ns.Slash.Run("loadout")
        h.True(HasLine(string.format(L.loadoutListHeader, "Local")), "defaults to here")
        local showsGlobalArmor = false
        for _, line in ipairs(Stub.ChatLines()) do
            if string.find(line, string.format(
                L.loadoutListDefaultArmor,
                L.loadoutListBestOnly
            ), 1, true) then
                showsGlobalArmor = true
            end
        end
        h.True(showsGlobalArmor, "shows global armor behavior")
        Stub.ClearChat()
        ns.Slash.Run("loadout --character Alt")
        h.True(HasLine(string.format(L.loadoutListHeader, "Alt")), "targeted loadout list")
        h.True(HasLine(string.format(
            L.loadoutListKeep,
            "Affliction",
            "Affliction",
            string.format(L.loadoutListCharacterOption, "Alt")
        )), "assumed spec command includes target")
        Stub.ClearChat()
        ns.Slash.Run("loadout --all")
        h.True(HasLine(string.format(L.loadoutListHeader, "Local")), "all list has here")
        h.True(HasLine(string.format(L.loadoutListHeader, "Alt")), "all list has alt")
        h.True(HasLine(string.format(
            L.loadoutListKeep,
            "Affliction",
            "Affliction",
            string.format(L.loadoutListCharacterOption, "Alt")
        )), "all list keep command targets assumed alt")
        Stub.ClearChat()
        ns.Slash.Run('loadout "Affliction" Affliction --character "Alt"')
        h.Equal(alt.loadouts[1].assumed, false, "trailing character option edits selected entry")
        h.True(LootLogicDB.characters["Local Test-Realm"].loadouts[1].assumed,
            "current character remains unchanged")
        Stub.ClearChat()
        ns.Slash.Run("want --character Alt")
        h.True(HasLine(string.format(L.wantListHeader, "Alt")), "targeted wants list")
        Stub.ClearChat()
        ns.Slash.Run("want --all")
        h.True(HasLine(string.format(L.wantListHeader, "Local")), "all wants has here")
        h.True(HasLine(string.format(L.wantListHeader, "Alt")), "all wants has alt")
        h.Equal(ns.Generations.Total(), generation + 1, "only explicit edit changes generation")
        h.True(before.characters["Local Test-Realm"].loadouts[1].assumed,
            "listing did not mutate saved loadouts")
    end,

    ["Slash: wants listing shows type quality and item include or exclude"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        WhyItem(199090)
        entry.asks = {
            types = { ["7:5"] = {}, ["4:1"] = { minQuality = 3 } },
            items = { [199090] = "include", [199091] = "exclude" },
        }
        ns.Slash.Run("want")
        h.True(HasLine(string.format(L.wantListHeader, "Local")), "current wants header")
        h.True(HasLine(string.format(L.wantListType, "Trade Goods: Cloth", L.wantListAnyQuality)),
            "any quality shown")
        h.True(HasLine(string.format(L.wantListType, "Armor: Cloth", "3")),
            "minimum quality shown")
        h.True(HasLine(string.format(L.wantListInclude, 199090, " [Why Item]")),
            "item include with loaded name")
        h.True(HasLine(string.format(L.wantListExclude, 199091, "")),
            "item exclude without loaded name")
    end,

    ["Slash: invalid all-character option combinations print usage without changes"] = function()
        WhyBoot()
        local before = Copy(LootLogicDB)
        local generation = ns.Generations.Total()
        for _, command in ipairs({
            "want 7:5 --all",
            "want --all --character Alt",
            "want --character Alt extra",
            "want --character Alt --character Local",
            "loadout Affliction Affliction --all",
            "loadout --all --character Alt",
            "loadout --character Alt extra",
        }) do
            Stub.ClearChat()
            ns.Slash.Run(command)
            local expected = string.sub(command, 1, 4) == "want" and L.wantUsage
                or string.format(L.loadoutUsage, L.helpLoadoutExample)
            h.Equal(Stub.ChatLines()[1], PREFIX .. expected, "usage for " .. command)
            h.DeepEqual(LootLogicDB, before, "no changes for " .. command)
            h.Equal(ns.Generations.Total(), generation, "no generation bump for " .. command)
        end
    end,

    ["Slash: type want on, off and clear replies match each mutation"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        ns.Slash.Run("want 7:5 on")
        h.True(entry.asks.types["7:5"] ~= nil, "type on")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantTypeChanged, "Local", "Trade Goods: Cloth"),
            "on reply"
        )
        Stub.ClearChat()
        ns.Slash.Run("want 7:5 off")
        h.Nil(entry.asks.types["7:5"], "type off clears")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantTypeRemoved, "Local", "Trade Goods: Cloth"),
            "off reply"
        )
        Stub.ClearChat()
        ns.Slash.Run("want 7:5 clear")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantTypeAbsent, "Local", "Trade Goods: Cloth"),
            "clear reply"
        )
    end,

    ["Slash: repeating a type want reports unchanged and preserves its quality"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = { ["7:5"] = { minQuality = 3 } }, items = {} }
        local before = ns.Generations.Get("asks")
        ns.Slash.Run("want 7:5 on")
        h.Equal(entry.asks.types["7:5"].minQuality, 3, "quality preserved")
        h.Equal(ns.Generations.Get("asks"), before, "unchanged call did not bump")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantTypeUnchanged, "Local", "Trade Goods: Cloth"),
            "unchanged reply"
        )
    end,

    ["Slash: item want on, off and clear replies match each mutation"] = function()
        WhyBoot()
        WhyItem(199092)
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        ns.Slash.Run("want 199092 on")
        h.Equal(entry.asks.items[199092], "include", "item on")
        h.True(
            string.find(Stub.ChatLines()[1], "now wants item 199092", 1, true) ~= nil,
            "on reply"
        )
        Stub.ClearChat()
        ns.Slash.Run("want 199092 off")
        h.Equal(entry.asks.items[199092], "exclude", "item off")
        h.True(
            string.find(Stub.ChatLines()[1], "excludes item 199092", 1, true) ~= nil,
            "off reply"
        )
        Stub.ClearChat()
        ns.Slash.Run("want 199092 clear")
        h.Nil(entry.asks.items[199092], "item cleared")
        h.True(
            string.find(Stub.ChatLines()[1], "removed from Local's wants", 1, true) ~= nil,
            "clear reply"
        )
    end,

    ["Slash: invalid signed item ID is rejected, unavailable validator accepts it"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        Stub.SetItemExists(-1, false)
        ns.Slash.Run("want -1")
        h.Nil(entry.asks.items[-1], "false validation no mutation")
        h.Equal(Stub.ChatLines()[1], PREFIX .. string.format(L.itemNotExist, -1), "signed ID error")
        Stub.SetExistsApi("off")
        Stub.ClearChat()
        ns.Slash.Run("want -1")
        h.Equal(entry.asks.items[-1], "include", "missing validator fallback")
        entry.asks.items[-2] = nil
        Stub.SetExistsApi("raise")
        Stub.ClearChat()
        ns.Slash.Run("want -2")
        h.Equal(entry.asks.items[-2], "include", "raising validator fallback")
    end,

    ["Slash: unknown item class and subclass errors list the ordered catalogue"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        ns.Slash.Run("want Armr: Cloth")
        h.True(
            string.find(Stub.ChatLines()[1], "Classes: Consumable, Armor, Trade Goods", 1, true)
                ~= nil,
            "all classes"
        )
        Stub.ClearChat()
        ns.Slash.Run("want Armor: Clth")
        h.True(
            string.find(Stub.ChatLines()[1], "Armor subclasses: Cloth", 1, true) ~= nil,
            "subclasses"
        )
        h.Nil(entry.asks.types["4:1"], "errors leave wants unchanged")
    end,

    ["Slash: unavailable item type API fails safely without mutation"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        local original = C_Item.GetItemClassInfo
        _G.C_Item.GetItemClassInfo = nil
        ns.Slash.Run("want Armor")
        _G.C_Item.GetItemClassInfo = original
        h.DeepEqual(entry.asks.types, {}, "no mutation")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.typeCatalogueUnavailable, "safe failure")
    end,

    ["Slash: item type enumeration errors fail safely without mutation"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        local original = C_Item.GetItemClassInfo
        _G.C_Item.GetItemClassInfo = function() error("enumeration failed") end
        ns.Slash.Run("want Armor")
        _G.C_Item.GetItemClassInfo = original
        h.DeepEqual(entry.asks.types, {}, "no mutation")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.typeCatalogueUnavailable, "safe failure")
    end,

    ["Slash: missing or raising subclass APIs leave the full DB unchanged"] = function()
        for _, failure in ipairs({ "missing", "raising" }) do
            WhyBoot()
            local original = C_Item.GetItemSubClassInfo
            if failure == "missing" then
                _G.C_Item.GetItemSubClassInfo = nil
            else
                _G.C_Item.GetItemSubClassInfo = function()
                    error("subclass enumeration failed")
                end
            end
            local before = Copy(LootLogicDB)
            local generations = GenerationSnapshot()
            ns.Slash.Run("want Armor: Cloth")
            _G.C_Item.GetItemSubClassInfo = original
            h.DeepEqual(LootLogicDB, before, failure .. " subclass API leaves DB unchanged")
            h.DeepEqual(
                GenerationSnapshot(),
                generations,
                failure .. " subclass API leaves generations unchanged"
            )
            h.Equal(
                Stub.ChatLines()[1],
                PREFIX .. L.typeCatalogueUnavailable,
                failure .. " subclass API reply"
            )
        end
    end,

    ["Slash: type reply uses its validated label without repeating client API lookups"] = function()
        WhyBoot()
        local originalClass = C_Item.GetItemClassInfo
        local originalSubclass = C_Item.GetItemSubClassInfo
        local expectedSubclasses = 0
        for class = 0, 20 do
            if originalClass(class) then
                for subclass = 0, 20 do
                    originalSubclass(class, subclass)
                    expectedSubclasses = expectedSubclasses + 1
                end
            end
        end
        local classCalls, subclassCalls = 0, 0
        _G.C_Item.GetItemClassInfo = function(class)
            classCalls = classCalls + 1
            if classCalls > 21 then error("repeated class lookup failed") end
            return originalClass(class)
        end
        _G.C_Item.GetItemSubClassInfo = function(class, subclass)
            subclassCalls = subclassCalls + 1
            if subclassCalls > expectedSubclasses then error("repeated subclass lookup failed") end
            return originalSubclass(class, subclass)
        end
        local entry = LootLogicDB.characters["Local Test-Realm"]
        local generation = ns.Generations.Get("asks")
        ns.Slash.Run("want Armor: Cloth")
        _G.C_Item.GetItemClassInfo = originalClass
        _G.C_Item.GetItemSubClassInfo = originalSubclass
        h.Equal(classCalls, 21, "catalogue looked up each class once")
        h.Equal(subclassCalls, expectedSubclasses, "catalogue looked up subclasses once")
        h.True(entry.asks.types["4:1"] ~= nil, "validated type was saved")
        h.Equal(ns.Generations.Get("asks"), generation + 1, "one want generation bump")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantTypeChanged, "Local", "Armor: Cloth"),
            "reply uses the validated catalogue label"
        )
    end,

    ["Slash: exact class beats a same-named subclass and holes stay numeric"] = function()
        WhyBoot()
        Stub.SetItemTypeNames(
            { [0] = "Trade Goods", [4] = "Armor" },
            { [0] = { [0] = "Potion" }, [4] = { [1] = "Trade Goods", [3] = "Plate" } }
        )
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = {}, items = {} }
        ns.Slash.Run("want Trade Goods")
        h.True(entry.asks.types["0:*"] ~= nil, "class selected")
        h.Nil(entry.asks.types["4:1"], "same-named subclass not selected")
        ns.Slash.Run("want 4:3")
        h.True(entry.asks.types["4:3"] ~= nil, "named subclass after hole selected")
        Stub.ClearChat()
        ns.Slash.Run("want 4:2")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.itemTypeMissing, "4:2"),
            "hole rejected"
        )
    end,

    ["Slash: item wants for ineligible characters explain faction and region"] = function()
        WhyBoot()
        WhyItem(199093)
        local alt = {
            first = "Alt",
            last = "Test",
            class = "PRIEST",
            faction = "Horde",
            region = "Realm",
            loadouts = {},
            asks = { types = {}, items = {} },
        }
        LootLogicDB.characters["Alt Test-Realm"] = alt
        LootLogicDB.order = { "Local Test-Realm", "Alt Test-Realm" }
        ns.Slash.Run("want 199093 on --character Alt")
        h.Equal(alt.asks.items[199093], "include", "ineligible include saved")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantIneligible, "Alt", L.ineligibleFaction),
            "faction reply"
        )
        alt.faction = "Alliance"
        alt.region = "Other"
        Stub.ClearChat()
        ns.Slash.Run("want 199093 clear --character Alt")
        h.Nil(alt.asks.items[199093], "ineligible clear saved")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.wantIneligible, "Alt", L.ineligibleRegion),
            "region reply"
        )
    end,

    ["Slash: malformed protect quotes and extra refresh arguments do not mutate"] = function()
        WhyBoot()
        local link = WhyItem(199094)
        local tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "SetHyperlink", getterArgs = { link }, hyperlink = link },
            nil,
            link
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        local before = ns.Generations.Total()
        ns.Slash.Run('protect "')
        h.Equal(ns.Generations.Total(), before, "malformed quote does not mutate")
        h.Nil(LootLogicDB.characters["Local Test-Realm"].protect, "hovered item not protected")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.protectUsage, "protect usage")
        Stub.ClearChat()
        ns.Slash.Run('protect ""')
        h.Equal(ns.Generations.Total(), before, "empty quoted item does not mutate")
        h.Nil(LootLogicDB.characters["Local Test-Realm"].protect, "empty item not protected")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.protectUsage, "empty item usage")
        Stub.ClearChat()
        ns.Slash.Run('protect global ""')
        h.Equal(ns.Generations.Total(), before, "empty global item does not mutate")
        h.Nil(LootLogicDB.protectGlobal["199094"], "empty global item not protected")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.protectUsage, "empty global item usage")
        for _, message in ipairs({ "protect 199094 extra", "protect global 199094 extra" }) do
            Stub.ClearChat()
            ns.Slash.Run(message)
            h.Equal(Stub.ChatLines()[1], PREFIX .. L.protectUsage, "invalid explicit input usage")
            h.Equal(ns.Generations.Total(), before, "invalid explicit input does not mutate")
        end
        Stub.SetGlobal("GameTooltip", nil)
        Stub.ClearChat()
        ns.Slash.Run("protect 199094 extra")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.protectUsage, "invalid input without hover usage")
        h.Equal(ns.Generations.Total(), before, "invalid input without hover does not mutate")
        Stub.ClearChat()
        ns.Slash.Run("refresh extra")
        h.Equal(ns.Generations.Total(), before, "extra arg does not refresh")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.refreshUsage, "refresh usage")
    end,

    ["Slash: want missing value and empty loadout name print usage without mutation"] = function()
        WhyBoot()
        local before = Copy(LootLogicDB)
        local generation = ns.Generations.Total()
        for _, message in ipairs({
            'want on',
            'want on',
            'want off',
            'want clear',
            'want " "',
        }) do
            Stub.ClearChat()
            ns.Slash.Run(message)
            h.Equal(Stub.ChatLines()[1], PREFIX .. L.wantUsage, "missing want value usage")
            h.DeepEqual(LootLogicDB, before, "missing want value leaves DB unchanged")
            h.Equal(
                ns.Generations.Total(),
                generation,
                "missing want value leaves generations unchanged"
            )
        end
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.class = "WARLOCK"
        before = Copy(LootLogicDB)
        Stub.ClearChat()
        ns.Slash.Run('loadout "" Affliction')
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.loadoutUsage, L.helpLoadoutExample),
            "empty loadout name usage"
        )
        h.DeepEqual(LootLogicDB, before, "empty loadout name leaves DB unchanged")
        h.Equal(
            ns.Generations.Total(),
            generation,
            "empty loadout name leaves generations unchanged"
        )
    end,

    ["Slash: near matches cover short types, specs and loadouts with tie handling"] = function()
        WhyBoot()
        ns.Slash.Run("want Armor: Cltoh")
        h.True(string.find(Stub.ChatLines()[1], "Did you mean Cloth?", 1, true) ~= nil,
            "short subclass typo suggestion")
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.class = "WARLOCK"
        entry.loadouts = { { name = "Affliction", spec = "WARLOCK:affliction" } }
        Stub.ClearChat()
        ns.Slash.Run("loadout Tank afflicton")
        h.True(string.find(Stub.ChatLines()[1], "Did you mean Affliction?", 1, true) ~= nil,
            "loadout spec typo suggestion")
        Stub.ClearChat()
        ns.Slash.Run("loadout Afflictio remove")
        h.True(string.find(Stub.ChatLines()[1], "Did you mean Affliction?", 1, true) ~= nil,
            "loadout name typo suggestion")
        entry.loadouts = {
            { name = "Cat", spec = "WARLOCK:affliction" },
            { name = "Bat", spec = "WARLOCK:affliction" },
        }
        Stub.ClearChat()
        ns.Slash.Run("loadout Hat remove")
        h.True(string.find(Stub.ChatLines()[1], "Loadouts: Bat, Cat", 1, true) ~= nil,
            "choices remain when near-match tie")
        h.True(string.find(Stub.ChatLines()[1], "Did you mean", 1, true) == nil,
            "no suggestion on tie")
    end,

    ["Slash: picking an assumed spec reports the picked suffix only once"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.class = "WARLOCK"
        entry.loadouts = {
            { name = "Affliction", spec = "WARLOCK:affliction", worn = true, assumed = true },
        }
        ns.Slash.Run("loadout Affliction Affliction")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(
                L.loadoutChanged,
                "Local",
                "Affliction",
                "Affliction",
                L.loadoutPickedSuffix
            ),
            "assumed spec acceptance reply"
        )
        h.Equal(entry.loadouts[1].assumed, false, "assumed flag cleared")
        Stub.ClearChat()
        ns.Slash.Run("loadout Affliction Affliction")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.loadoutUnchanged, "Local", "Affliction", "Affliction"),
            "picked spec unchanged reply"
        )
    end,

    ["Slash: read-only commands preserve the full DB and generations"] = function()
        local calls = 0
        local wrapped = {}
        local methods = {
            { ns.Asks, "SetType" },
            { ns.Asks, "SetItem" },
            { ns.Roster, "SetOrder" },
            { ns.Roster, "SetReceivesGear" },
            { ns.Loadouts, "Set" },
            { ns.Loadouts, "SetArmor" },
            { ns.Loadouts, "Remove" },
            { ns.Sets, "ToggleProtect" },
            { ns.Sets, "ToggleProtectGlobal" },
        }
        for _, method in ipairs(methods) do
            local target, name = method[1], method[2]
            local original = target[name]
            wrapped[#wrapped + 1] = { target = target, name = name, original = original }
            target[name] = function(...)
                calls = calls + 1
                return original(...)
            end
        end
        for _, command in ipairs({
            "want 7:5",
            "want 199097",
            "gear Local off",
            "order Alt Local",
            "loadout Tank Affliction",
            "loadout Tank armor best",
            "loadout Tank remove",
            "protect 199097",
            "protect global 199098",
            "refresh",
            "reset",
        }) do
            WhyBoot()
            LootLogicDB = ReadOnlyFixture()
            Stub.FireEvent("ADDON_LOADED", "LootLogic")
            Stub.ClearChat()
            WhyItem(199097)
            WhyItem(199098)
            local before = Copy(LootLogicDB)
            local generations = GenerationSnapshot()
            calls = 0
            ns.Slash.Run(command)
            h.DeepEqual(LootLogicDB, before, "read-only DB for " .. command)
            h.DeepEqual(GenerationSnapshot(), generations, "read-only generations for " .. command)
            h.Equal(calls, 0, "read-only model calls for " .. command)
            h.Equal(
                Stub.ChatLines()[1],
                PREFIX .. L.debugReadOnly,
                "read-only refusal for " .. command
            )
        end
        for _, method in ipairs(wrapped) do
            method.target[method.name] = method.original
        end
    end,

    ["Slash: settings reset preserves other saved data and first-run state"] = function()
        for _, firstRunDone in ipairs({ true, false }) do
            WhyBoot()
            LootLogicDB.ui.firstRunDone = firstRunDone
            LootLogicDB.debug.enabled = false
            LootLogicDB.protectGlobal = { ["199098"] = true }
            LootLogicDB.order = { "Local Test-Realm" }
            local roster = Copy(LootLogicDB.characters)
            local debug = Copy(LootLogicDB.debug)
            local protectGlobal = Copy(LootLogicDB.protectGlobal)
            local order = Copy(LootLogicDB.order)
            ns.Slash.Run("reset")
            ns.Slash.Run("reset confirm")
            h.DeepEqual(LootLogicDB.characters, roster, "roster preserved")
            h.DeepEqual(LootLogicDB.debug, debug, "debug preserved")
            h.DeepEqual(LootLogicDB.protectGlobal, protectGlobal, "global protection preserved")
            h.DeepEqual(LootLogicDB.order, order, "order preserved")
            h.Equal(LootLogicDB.ui.firstRunDone, firstRunDone, "firstRunDone preserved")
        end
    end,

    ["Slash: help, perf and refresh reject trailing arguments"] = function()
        Load()
        ns.Slash.Run("help extra")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.helpUsage }, "help usage")
        Stub.ClearChat()
        ns.Slash.Run("perf extra")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.perfUsage }, "perf usage")
    end,

    ["Slash: read-only reset preview and confirm preserve saved data"] = function()
        local before = h.Fixture("dbNewer")
        LootLogicDB = h.Fixture("dbNewer")
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        ns.Slash.Run("reset")
        ns.Slash.Run("reset confirm")
        h.DeepEqual(LootLogicDB, before, "read-only data unchanged")
    end,

    ["Slash: protect toggles the current character item key"] = function()
        WhyBoot()
        WhyItem(199088)
        ns.Slash.Run("protect 199088")
        h.Equal(LootLogicDB.characters["Local Test-Realm"].protect["199088"], true, "protected")
    end,

    ["Slash: protect refuses a roll toggle when every roll is protected"] = function()
        WhyBoot()
        WhyItem(199089, -12)
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.protect = { ["199089"] = true }
        ns.Slash.Run("protect 199089:-12")
        h.Equal(entry.protect["199089"], true, "all rolls preserved")
        h.Nil(entry.protect["199089:-12"], "roll not added")
    end,

    ["Slash: protect global zero suffix and hovered context use the right keys"] = function()
        WhyBoot()
        local link = WhyItem(199096, -3)
        ns.Slash.Run("protect global 199096:0")
        h.Equal(LootLogicDB.protectGlobal["199096"], true, "zero suffix uses plain global key")
        local tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "GetBagItem", getterArgs = { 0, 1 } },
            nil,
            link
        )
        Stub.SetBagSize(0, 1)
        Stub.SetBagItem(0, 1, { itemID = 199096, link = link, count = 1, quality = 1 })
        Stub.SetGlobal("GameTooltip", tooltip)
        ns.Slash.Run("protect")
        h.Equal(
            LootLogicDB.characters["Local Test-Realm"].protect["199096:-3"],
            true,
            "hovered roll protected locally"
        )
    end,

    ["Slash: quoted loadout names parse, and worn removal is refused"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.class = "WARLOCK"
        ns.Slash.Run('loadout "Tank set" Affliction worn')
        h.Equal(entry.loadouts[#entry.loadouts].name, "Tank set", "quoted name")
        h.Equal(entry.loadouts[#entry.loadouts].worn, true, "worn flag")
        ns.Slash.Run('loadout "Tank set" remove')
        h.Equal(entry.loadouts[#entry.loadouts].name, "Tank set", "worn loadout kept")
        h.Equal(
            Stub.ChatLines()[#Stub.ChatLines()],
            PREFIX .. string.format(L.loadoutWornNamed, "Local", "Tank set"),
            "worn refusal reply"
        )
    end,

    ["Slash: setting an assumed spec clears assumed and armor default restores nil"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.class = "WARLOCK"
        entry.loadouts = {
            { name = "Affliction", spec = "WARLOCK:affliction", worn = true, assumed = true },
            { name = "Other", spec = "WARLOCK:affliction" },
        }
        ns.Slash.Run("loadout Affliction affliction")
        h.Equal(entry.loadouts[1].assumed, false, "picked spec clears assumed")
        entry.loadouts[2].armor = "best"
        ns.Slash.Run("loadout Other armor default")
        h.Nil(entry.loadouts[2].armor, "default armor follows settings")
    end,

    ["Slash: invalid or missing loadout armor rule gives armor usage without changes"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.loadouts = { { name = "Resto", spec = "DRUID:restoration", worn = true, armor = "best" } }
        for _, command in ipairs({ "loadout Resto armor all", "loadout Resto armor" }) do
            Stub.ClearChat()
            ns.Slash.Run(command)
            h.Equal(entry.loadouts[1].armor, "best", "invalid rule leaves armor unchanged")
            h.Equal(
                Stub.ChatLines()[1],
                PREFIX .. "/ll loadout <loadout> armor best|any|default [--character <name>]. "
                    .. "Example: /ll loadout Resto armor any",
                "armor usage lists valid choices"
            )
        end
    end,

    ["Slash: unknown loadout names include available choices"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.loadouts = {
            { name = "Affliction", spec = "WARLOCK:affliction", worn = true },
            { name = "Demonology", spec = "WARLOCK:demonology" },
        }
        entry.class = "WARLOCK"
        ns.Slash.Run("loadout Missing remove")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.noLoadoutNamed, "Local", "Missing", "Affliction, Demonology"),
            "missing loadout choices"
        )
    end,

    ["Slash: loadout argument and spec errors differ"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.displayName = "Local Hero"
        entry.class = "WARLOCK"
        ns.Slash.Run('loadout "Local Hero"')
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.loadoutUsage, L.helpLoadoutExample),
            "missing argument usage"
        )
        Stub.ClearChat()
        ns.Slash.Run('loadout "Local Hero" Tank Wrong')
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.loadoutSpecs, "Wrong", "Warlock", "Affliction"),
            "spec choices"
        )
        entry.class = "MAGE"
        Stub.ClearChat()
        ns.Slash.Run('loadout "Local Hero" Tank Fire')
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.loadoutNoSpecs, "Mage"),
            "unsupported class"
        )
    end,

    ["Slash: name parsing uses longest prefixes and display-name precedence"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        local alt = {
            first = "Alt",
            last = "Test",
            displayName = "Local Test",
            class = "PRIEST",
            faction = here.faction,
            region = here.region,
            asks = { types = {}, items = {} },
            loadouts = {},
        }
        LootLogicDB.characters["Alt Test-Realm"] = alt
        LootLogicDB.order = { "Local Test-Realm", "Alt Test-Realm" }
        ns.Slash.Run('want 7:5 --character "Alt Test"')
        h.True(
            alt.asks.types["7:5"] ~= nil,
            "full name consumes its longest matching prefix"
        )
        ns.Slash.Run('want 7:5 off --character "Local Test"')
        h.Nil(alt.asks.types["7:5"], "display name beats another character full name")
        Stub.ClearChat()
        ns.Slash.Run("want 7:5 --character LocalHero")
        h.True(
            string.find(Stub.ChatLines()[1], "does not know LocalHero", 1, true) ~= nil,
            "word boundary"
        )
    end,

    ["Slash: ambiguous shared first name lists display names"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        for _, surname in ipairs({ "H", "W" }) do
            local key = "Boneset " .. surname .. "-Realm"
            LootLogicDB.characters[key] = {
                first = "Boneset",
                last = surname,
                class = "PRIEST",
                faction = here.faction,
                region = here.region,
                loadouts = {},
                asks = { types = {}, items = {} },
            }
            LootLogicDB.order[#LootLogicDB.order + 1] = key
        end
        h.Equal(ns.Roster.Entry("Boneset H-Realm").first, "Boneset", "registered first name")
        h.True(ns.Roster.Keys()[2] ~= nil, "the second roster key is present")
        ns.Slash.Run("gear Boneset off")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. string.format(L.ambiguousCharacter, "Boneset", "Boneset H or Boneset W"),
            "ambiguous first name"
        )
    end,

    ["Slash: an invalid late order name leaves priority order unchanged"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        LootLogicDB.characters["Alt Test-Realm"] = {
            first = "Alt",
            last = "Test",
            class = "PRIEST",
            faction = here.faction,
            region = here.region,
            asks = { types = {}, items = {} },
            loadouts = {},
        }
        LootLogicDB.order = { "Alt Test-Realm", "Local Test-Realm" }
        ns.Slash.Run("order Local Alt Missing")
        h.DeepEqual(LootLogicDB.order, { "Alt Test-Realm", "Local Test-Realm" }, "order unchanged")
    end,

    ["Slash: order accepts a partial list and ignores repeated names"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        for _, first in ipairs({ "Alt", "Third" }) do
            local key = first .. " Test-Realm"
            LootLogicDB.characters[key] = {
                first = first,
                last = "Test",
                class = "PRIEST",
                faction = here.faction,
                region = here.region,
                loadouts = {},
                asks = { types = {}, items = {} },
            }
        end
        LootLogicDB.order = { "Alt Test-Realm", "Third Test-Realm", "Local Test-Realm" }
        ns.Slash.Run("order Local Alt Local")
        h.DeepEqual(
            LootLogicDB.order,
            { "Local Test-Realm", "Alt Test-Realm", "Third Test-Realm" },
            "partial reordered list and duplicate"
        )
    end,

    ["Slash: reset preview leaves saved state unchanged until confirmation"] = function()
        WhyBoot()
        LootLogicDB.settings.staleDays = 3
        ns.Slash.Run("reset")
        h.Equal(LootLogicDB.settings.staleDays, 3, "preview did not reset")
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.settings.staleDays, 14, "confirmed reset")
    end,

    ["Slash: quoted reserved reset names and preview replacement"] = function()
        WhyBoot()
        local here = LootLogicDB.characters["Local Test-Realm"]
        local namedAll = {
            first = "Alt",
            last = "All",
            displayName = "all",
            class = "PRIEST",
            faction = here.faction,
            region = here.region,
            asks = { types = { ["7:5"] = {} }, items = {} },
            loadouts = {},
        }
        LootLogicDB.characters["Alt All-Realm"] = namedAll
        LootLogicDB.order[#LootLogicDB.order + 1] = "Alt All-Realm"
        ns.Slash.Run('reset "all"')
        ns.Slash.Run("reset")
        ns.Slash.Run("reset confirm")
        h.True(
            LootLogicDB.characters["Alt All-Realm"] ~= nil,
            "later settings preview replaced character target"
        )
        h.True(namedAll.asks.types["7:5"] ~= nil, "replacement did not reset character")
        ns.Slash.Run('reset "all"')
        ns.Slash.Run("reset confirm")
        h.DeepEqual(
            namedAll.asks,
            { types = {}, items = {} },
            "quoted reserved name selected character"
        )
    end,

    ["Slash: reset confirm without a pending preview changes nothing"] = function()
        WhyBoot()
        local staleDays = LootLogicDB.settings.staleDays
        local generation = ns.Generations.Total()
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.settings.staleDays, staleDays, "no pending reset did not mutate")
        h.Equal(ns.Generations.Total(), generation, "no generation bump")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.resetNothing, "no pending reply")
    end,

    ["Slash: an invalid reset command preserves the pending preview"] = function()
        WhyBoot()
        LootLogicDB.settings.staleDays = 3
        ns.Slash.Run("reset")
        ns.Slash.Run("reset Unknown")
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.settings.staleDays, 14, "pending preview applied")
    end,

    ["Slash: reset confirmation remains valid at exactly 30 seconds"] = function()
        WhyBoot()
        LootLogicDB.settings.staleDays = 3
        ns.Slash.Run("reset")
        Stub.Advance(30)
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.settings.staleDays, 14, "boundary confirmation applied")
    end,

    ["Slash: expired reset confirmation does nothing"] = function()
        WhyBoot()
        LootLogicDB.settings.staleDays = 3
        ns.Slash.Run("reset")
        Stub.Advance(30.1)
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.settings.staleDays, 3, "expired target preserved")
    end,

    ["Slash: character reset preserves identity and snapshots"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.displayName = "Local Hero"
        entry.importedSets = { marker = true }
        entry.gear = { marker = true }
        entry.bags = { marker = true }
        entry.bank = { marker = true }
        entry.inbox = { marker = true }
        entry.inbound = { marker = true }
        entry.proficiency = { marker = true }
        entry.receivesGear = false
        local asksGeneration = ns.Generations.Get("asks")
        local loadoutGeneration = ns.Generations.Get("loadouts")
        local rosterGeneration = ns.Generations.Get("roster")
        ns.Slash.Run('reset "Local Hero"')
        ns.Slash.Run("reset confirm")
        h.Equal(entry.displayName, "Local Hero", "display name")
        h.Equal(entry.importedSets.marker, true, "imported equipment")
        h.Equal(entry.gear.marker, true, "gear snapshot")
        h.Equal(entry.bags.marker, true, "bag snapshot")
        h.Equal(entry.bank.marker, true, "bank snapshot")
        h.Equal(entry.inbox.marker, true, "inbox snapshot")
        h.Equal(entry.inbound.marker, true, "inbound mail")
        h.Equal(entry.proficiency.marker, true, "proficiency snapshot")
        h.Equal(entry.receivesGear, nil, "receives gear restored to default")
        h.DeepEqual(entry.asks, { types = {}, items = {} }, "wants cleared")
        h.Equal(ns.Generations.Get("asks"), asksGeneration + 1, "asks generation")
        h.Equal(ns.Generations.Get("loadouts"), loadoutGeneration + 1, "loadouts generation")
        h.Equal(ns.Generations.Get("roster"), rosterGeneration + 1, "roster generation")
    end,

    ["Slash: ambiguous type words do not mutate wants"] = function()
        WhyBoot()
        LootLogicDB.characters["Local Test-Realm"].asks = { types = {}, items = {} }
        ns.Slash.Run("want cloth")
        h.Nil(LootLogicDB.characters["Local Test-Realm"].asks.types["4:1"], "armor cloth untouched")
        h.Nil(LootLogicDB.characters["Local Test-Realm"].asks.types["7:5"], "trade cloth untouched")
        h.True(
            string.find(Stub.ChatLines()[1], "Armor: Cloth (4:1)", 1, true) ~= nil,
            "first choice"
        )
        h.True(
            string.find(Stub.ChatLines()[1], "Trade Goods: Cloth (7:5)", 1, true) ~= nil,
            "second choice"
        )
    end,

    ["Slash: a one-edit type match is suggested without mutating wants"] = function()
        WhyBoot()
        LootLogicDB.characters["Local Test-Realm"].asks = { types = {}, items = {} }
        ns.Slash.Run("want Armor: Clth")
        h.Nil(LootLogicDB.characters["Local Test-Realm"].asks.types["4:1"], "no type set")
        h.True(
            string.find(Stub.ChatLines()[1], "Did you mean Cloth?", 1, true) ~= nil,
            "suggestion"
        )
    end,

    ["Slash: colored item links with spaces stay one item argument"] = function()
        WhyBoot()
        WhyItem(199090)
        local colored = "|cnIQ4:|Hitem:199090:0:0:0:0:0:0|h[Why Item]|h|r"
        ns.Slash.Run("want " .. colored)
        h.Equal(
            LootLogicDB.characters["Local Test-Realm"].asks.items[199090],
            "include",
            "linked item included"
        )
    end,

    ["Slash: perf reads a completed classifier pass"] = function()
        WhyBoot()
        ns.Classify.Pass("bags")
        ns.Slash.Run("perf")
        h.True(
            string.find(Stub.ChatLines()[1], "Last classification: bags,", 1, true) ~= nil,
            "pass output"
        )
    end,

    ["Slash: perf reports count and time without starting a pass"] = function()
        WhyBoot()
        Stub.SetBagSize(0, 50)
        Stub.SetProfileStep(2)
        ns.Classify.Pass("bags")
        h.Nil(ns.Classify.LastPass(), "first pass still batched")
        Stub.SetProfileStep(0)
        ns.Slash.Run("perf")
        h.Nil(ns.Classify.LastPass(), "perf did not start a pass")
        for _ = 1, 5 do
            if ns.Classify.LastPass() then break end
            Stub.Advance(0.1)
        end
        local pass = ns.Classify.LastPass()
        h.Equal(pass.scope, "bags", "scope")
        h.Equal(pass.count, 0, "item count")
        h.True(pass.ms > 0, "classification time measured")
        Stub.ClearChat()
        ns.Slash.Run("perf")
        h.True(
            string.find(Stub.ChatLines()[1], "Last classification: bags, 0 items in", 1, true)
                ~= nil,
            "perf includes count"
        )
        h.True(string.find(Stub.ChatLines()[1], "ms.", 1, true) ~= nil, "perf includes time")
    end,

    ["Slash: perf does not report a deferred pass before combat ends"] = function()
        WhyBoot()
        Stub.SetCombat(true)
        ns.Classify.Pass("bags")
        h.Nil(ns.Classify.LastPass(), "deferred pass not completed")
        ns.Slash.Run("perf")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.perfNone, "no completed-pass reply")
        Stub.SetCombat(false)
        Stub.FireEvent("PLAYER_REGEN_ENABLED")
        h.Equal(ns.Classify.LastPass().scope, "bags", "deferred pass completed")
    end,

    ["Slash: reset all preserves firstRunDone and restores the current character"] = function()
        WhyBoot()
        LootLogicDB.ui.firstRunDone = true
        ns.Slash.Run("reset all")
        ns.Slash.Run("reset confirm")
        h.Equal(LootLogicDB.ui.firstRunDone, true, "welcome state")
        h.True(LootLogicDB.characters["Local Test-Realm"] ~= nil, "current character restored")
        h.True(LootLogicDB.characters["Local Test-Realm"].loadouts[1].worn, "default loadout worn")
    end,

    ["Slash: reset all uses the localized name for an unsupported class"] = function()
        WhyBoot()
        Stub.SetPlayer({ class = "MAGE", className = "Mage" })
        ns.Slash.Run("reset all")
        ns.Slash.Run("reset confirm")
        local entry = LootLogicDB.characters["Local Test-Realm"]
        h.Equal(entry.class, "MAGE", "current class refreshed")
        h.Equal(entry.loadouts[1].name, "Mage", "localized default loadout")
    end,

    ["Slash: reset all restores current live data before classification"] = function()
        local function LiveLink(itemID)
            return string.format("item:%d:0:0:0:0:0:0", itemID)
        end
        local hereKey = "Local Test-Realm"
        local otherKey = "Other Test-Realm"
        local wornID, bagID, bankID, inboxID = 199110, 199111, 199112, 199113
        local equipID, outfitID = 199114, 199115
        local allItems = { wornID, bagID, bankID, inboxID }

        for _, bankOpen in ipairs({ false, true }) do
            WhyBoot()
            local entry = LootLogicDB.characters[hereKey]
            LootLogicDB.characters[otherKey] = {
                first = "Other",
                last = "Test",
                region = "Realm",
                faction = "Alliance",
                class = "PRIEST",
                importedSets = { ["equipmentset:stale"] = { items = {} } },
            }
            LootLogicDB.order[#LootLogicDB.order + 1] = otherKey
            entry.gear = { updatedAt = 1, slots = { [1] = "stale" } }
            entry.proficiency = { updatedAt = 1, spells = { [1] = true } }
            entry.bags = { updatedAt = 1, gear = { "stale" }, ids = { [1] = 1 } }
            entry.bank = { updatedAt = 1, gear = { "stale" }, ids = { [1] = 1 } }
            entry.inbox = { updatedAt = 1, gear = { "stale" }, ids = { [1] = 1 } }
            entry.inbound = { { id = 1, count = 1 } }
            entry.importedSets = {
                ["equipmentset:stale"] = { source = "equipmentset", name = "stale", items = {} },
                ["outfitter:stale"] = { source = "outfitter", name = "stale", items = {} },
            }

            local itemInstant = {
                equipLoc = "INVTYPE_CHEST",
                classID = 4,
                subclassID = 1,
            }
            for _, itemID in ipairs(allItems) do
                Stub.SetItemInstant(itemID, itemInstant)
            end
            Stub.SetWornLink(1, LiveLink(wornID))
            Stub.SetKnownSpells({ 9077 })
            Stub.SetBagSize(0, 1)
            Stub.SetBagItem(0, 1, {
                itemID = bagID,
                link = LiveLink(bagID),
                count = 2,
            })
            Stub.SetBagSize(6, 1)
            Stub.SetBagItem(6, 1, {
                itemID = bankID,
                link = LiveLink(bankID),
                count = 1,
            })
            Stub.SetInbox({
                { items = { { link = LiveLink(inboxID), count = 3 } } },
            })
            Stub.SetEquipmentSets({
                { id = 1, name = "Live Equipment", items = { [1] = equipID }, places = {} },
            })
            Stub.SetOutfitter({
                Outfits = {
                    Complete = {
                        {
                            Name = "Live Outfit",
                            Items = { Head = { Code = outfitID } },
                        },
                    },
                },
            })
            if bankOpen then Stub.OpenBank() end

            local lifecycle = {}
            local registered = false
            local classified = false
            local function Wrap(target, method, name, before, after)
                local original = target[method]
                target[method] = function(...)
                    lifecycle[#lifecycle + 1] = name
                    if before then before(...) end
                    local result = original(...)
                    if after then after(...) end
                    return result
                end
                return function() target[method] = original end
            end
            local restore = {}
            restore[#restore + 1] = Wrap(ns.Roster, "RegisterNow", "register", nil, function()
                registered = true
            end)
            local function CheckRegistered()
                h.True(registered, "capture follows current-character registration")
                local current = LootLogicDB.characters[hereKey]
                h.True(current ~= nil, "current roster entry exists before capture")
                h.Equal(#current.loadouts, 1, "default loadout exists before capture")
                h.Equal(current.loadouts[1].worn, true, "default loadout is worn before capture")
            end
            for _, method in ipairs({
                { ns.Snapshot, "TakeAll", "snapshot all" },
                { ns.Sets, "RefreshEquipmentSets", "refresh equipment sets" },
                { ns.Sets, "RefreshOutfitter", "refresh outfitter" },
            }) do
                restore[#restore + 1] = Wrap(
                    method[1],
                    method[2],
                    method[3],
                    CheckRegistered
                )
            end
            if bankOpen then
                restore[#restore + 1] = Wrap(
                    ns.Snapshot,
                    "TakeBank",
                    "snapshot bank",
                    CheckRegistered
                )
            end
            local originalClassify = ns.Classify.Pass
            ns.Classify.Pass = function(scope)
                lifecycle[#lifecycle + 1] = "classify " .. scope
                local current = LootLogicDB.characters[hereKey]
                if scope == "bags" then
                    h.Equal(
                        current.gear.slots[1],
                        LiveLink(wornID),
                        "gear captured before classification"
                    )
                    h.Equal(current.bags.ids[bagID], 2, "bags captured before classification")
                    h.Nil(current.inbox, "closed inbox remains uncaptured")
                    h.Equal(current.bank ~= nil, bankOpen, "bank follows current availability")
                    h.True(
                        current.importedSets["equipmentset:Live Equipment"],
                        "equipment set restored"
                    )
                    h.True(
                        current.importedSets["outfitter:Live Outfit"],
                        "Outfitter set restored"
                    )
                    h.Nil(current.importedSets["equipmentset:stale"], "stale equipment set deleted")
                    h.Nil(current.importedSets["outfitter:stale"], "stale Outfitter set deleted")
                    h.Nil(current.inbound, "old inbound mail is not restored")
                    h.Nil(LootLogicDB.characters[otherKey], "other roster entry stays deleted")
                    h.DeepEqual(
                        LootLogicDB.order,
                        { hereKey },
                        "only current character is registered"
                    )
                else
                    h.True(classified, "bank classification follows bag classification")
                end
                local result = originalClassify(scope)
                if scope == "bags" then classified = true end
                return result
            end
            restore[#restore + 1] = function() ns.Classify.Pass = originalClassify end
            restore[#restore + 1] = Wrap(ns.Tooltip, "RefreshShown", "refresh tooltip", function()
                h.True(classified, "tooltip refresh follows classification")
            end)

            local getInboxNumItems = GetInboxNumItems
            local getInboxItemLink = GetInboxItemLink
            _G.GetInboxNumItems = function()
                error("inbox APIs must not be read before MAIL_SHOW")
            end
            _G.GetInboxItemLink = function()
                error("inbox APIs must not be read before MAIL_SHOW")
            end
            ns.Slash.Run("reset all")
            ns.Slash.Run("reset confirm")
            _G.GetInboxNumItems = getInboxNumItems
            _G.GetInboxItemLink = getInboxItemLink
            for index = #restore, 1, -1 do restore[index]() end

            local expected = {
                "register",
                "snapshot all",
            }
            if bankOpen then expected[#expected + 1] = "snapshot bank" end
            expected[#expected + 1] = "refresh equipment sets"
            expected[#expected + 1] = "refresh outfitter"
            expected[#expected + 1] = "classify bags"
            if bankOpen then expected[#expected + 1] = "classify bank" end
            expected[#expected + 1] = "refresh tooltip"
            h.DeepEqual(lifecycle, expected, "reset lifecycle order")
            local current = LootLogicDB.characters[hereKey]
            h.Equal(current.gear.slots[1], LiveLink(wornID), "current gear restored")
            h.Equal(current.proficiency.spells[9077], true, "current proficiency restored")
            h.Equal(current.bags.ids[bagID], 2, "current bags restored")
            h.Nil(current.inbox, "closed inbox snapshot remains deleted")
            h.Equal(current.bank ~= nil, bankOpen, "closed bank snapshot is not restored")
            if bankOpen then h.Equal(current.bank.ids[bankID], 1, "open bank restored") end
            h.True(
                current.importedSets["equipmentset:Live Equipment"],
                "live Equipment Manager set"
            )
            h.True(current.importedSets["outfitter:Live Outfit"], "live Outfitter set")
            h.Nil(current.inbound, "deleted inbound data stays deleted")
            h.DeepEqual(
                LootLogicDB.order,
                { hereKey },
                "reset roster contains current character only"
            )
            Stub.FireEvent("MAIL_SHOW")
            h.Equal(current.inbox.ids[inboxID], 3, "mail event captures inbox after reset")
            if bankOpen then Stub.CloseBank() end
        end
    end,

    ["Slash: reset known character with extra arguments preserves the pending reset"] = function()
        WhyBoot()
        local entry = LootLogicDB.characters["Local Test-Realm"]
        entry.asks = { types = { ["7:5"] = { minQuality = 2 } }, items = {} }
        ns.Slash.Run("reset Local")
        Stub.ClearChat()
        ns.Slash.Run("reset Local extra")
        h.Equal(Stub.ChatLines()[1], PREFIX .. L.resetUsage, "extra arguments show reset usage")
        h.True(
            entry.asks.types["7:5"] ~= nil,
            "invalid command leaves saved preview target untouched"
        )
        Stub.ClearChat()
        ns.Slash.Run("reset confirm")
        h.Nil(entry.asks.types["7:5"], "original pending character reset still applies")
        h.Equal(
            Stub.ChatLines()[1],
            PREFIX .. L.resetDone,
            "confirmation completes the original preview"
        )
    end,

    ["Slash: reset all isolates capture failures and still invalidates and classifies"] = function()
        WhyBoot()
        local hereKey = "Local Test-Realm"
        local bankID, outfitID = 199118, 199119
        Stub.SetItemInstant(bankID, {
            equipLoc = "INVTYPE_CHEST",
            classID = 4,
            subclassID = 1,
        })
        Stub.SetBagSize(6, 1)
        Stub.SetBagItem(6, 1, {
            itemID = bankID,
            link = "item:" .. bankID,
            count = 1,
        })
        Stub.SetEquipmentSets({
            { id = 1, name = "Failed Equipment", items = { [1] = outfitID }, places = {} },
        })
        Stub.SetOutfitter({
            Outfits = {
                Complete = {
                    { Name = "Surviving Outfit", Items = { Head = { Code = outfitID } } },
                },
            },
        })
        Stub.OpenBank()

        local originalTakeAll = ns.Snapshot.TakeAll
        local originalTakeBank = ns.Snapshot.TakeBank
        local originalRefreshEquipmentSets = ns.Sets.RefreshEquipmentSets
        local originalRefreshOutfitter = ns.Sets.RefreshOutfitter
        local originalClassify = ns.Classify.Pass
        local originalRefreshTooltip = ns.Tooltip.RefreshShown
        local scopes = {}
        local outfitterCalls, tooltipCalls = 0, 0
        ns.Snapshot.TakeAll = function()
            error("injected full snapshot failure")
        end
        ns.Snapshot.TakeBank = function(...)
            return originalTakeBank(...)
        end
        ns.Sets.RefreshEquipmentSets = function()
            error("injected equipment set failure")
        end
        ns.Sets.RefreshOutfitter = function(...)
            outfitterCalls = outfitterCalls + 1
            return originalRefreshOutfitter(...)
        end
        ns.Classify.Pass = function(scope)
            scopes[#scopes + 1] = scope
            return originalClassify(scope)
        end
        ns.Tooltip.RefreshShown = function(...)
            tooltipCalls = tooltipCalls + 1
            return originalRefreshTooltip(...)
        end

        local errorsBefore = #ns.Log.Errors()
        local gearBefore = ns.Generations.Get("gearHere")
        local gearOthersBefore = ns.Generations.Get("gearOthers")
        local settingsBefore = ns.Generations.Get("settings")
        ns.Slash.Run("reset all")
        ns.Slash.Run("reset confirm")

        ns.Snapshot.TakeAll = originalTakeAll
        ns.Snapshot.TakeBank = originalTakeBank
        ns.Sets.RefreshEquipmentSets = originalRefreshEquipmentSets
        ns.Sets.RefreshOutfitter = originalRefreshOutfitter
        ns.Classify.Pass = originalClassify
        ns.Tooltip.RefreshShown = originalRefreshTooltip

        local entry = LootLogicDB.characters[hereKey]
        h.Nil(entry.gear, "failed full snapshot remains absent")
        h.Nil(entry.bags, "failed full snapshot does not restore stale bags")
        h.Equal(entry.bank.ids[bankID], 1, "independent bank snapshot still runs")
        h.True(
            entry.importedSets["outfitter:Surviving Outfit"],
            "Outfitter refresh follows equipment import failure"
        )
        h.Nil(
            entry.importedSets["equipmentset:Failed Equipment"],
            "failed equipment import is absent"
        )
        h.Equal(outfitterCalls, 1, "Outfitter refresh still runs")
        h.DeepEqual(scopes, { "bags", "bank" }, "classification still runs for both scopes")
        h.Equal(tooltipCalls, 1, "tooltip refresh still runs")
        h.Equal(ns.Generations.Get("gearHere"), gearBefore + 2, "bank and reset invalidate gear")
        h.Equal(
            ns.Generations.Get("gearOthers"),
            gearOthersBefore + 1,
            "reset invalidates other gear"
        )
        h.Equal(
            ns.Generations.Get("settings"),
            settingsBefore + 1,
            "reset invalidates settings"
        )
        local errors = ns.Log.Errors()
        h.Equal(#errors, errorsBefore + 2, "both injected failures are recorded")
        h.Equal(errors[#errors - 1].area, "events", "snapshot failure area")
        h.Equal(errors[#errors].area, "events", "set refresh failure area")
        h.Equal(Stub.ChatLines()[#Stub.ChatLines()], PREFIX .. L.resetDone, "reset completes")
        Stub.CloseBank()
    end,

    ["Slash: an unknown word prints the placeholder and runs nothing"] = function()
        ExpectPlaceholder("foo")
    end,

    ["Slash: a word that only starts with probe is not the probe command"] = function()
        ExpectPlaceholder("probes")
    end,

    ["Slash: one adjacent transposition suggests a command"] = function()
        Load()
        ns.Slash.Run("debgu")
        h.DeepEqual(
            Stub.ChatLines(),
            { PREFIX .. string.format(L.slashUnknownSuggested, "debgu", "debug") },
            "suggestion"
        )
    end,

    ["Slash: an unknown word during a probe prints the placeholder"] = function()
        Load()
        ns.Slash.Run("probe")
        Stub.ClearChat()
        ns.Slash.Run("foo")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. string.format(L.slashUnknown, "foo") }, "chat")
        Stub.Advance(11)
    end,

    ["Slash: debug on sets debug.enabled and prints the on line"] = function()
        ExpectOnWith("debug on")
    end,

    ["Slash: DEBUG ON and a padded debug  on work (case-insensitive)"] = function()
        ExpectOnWith("DEBUG ON")
        ExpectOnWith(" debug  on ")
    end,

    ["Slash: debug off clears debug.enabled, prints the off line, keeps the log"] = function()
        Load()
        LootLogicDB.debug.enabled = true
        LootLogicDB.debug.log = { "[00:00:00] old: line" }
        ns.Slash.Run("debug off")
        h.Equal(LootLogicDB.debug.enabled, false, "enabled")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugOff }, "chat")
        h.DeepEqual(LootLogicDB.debug.log, { "[00:00:00] old: line" }, "log kept")
    end,

    ["Slash: debug on while on prints the already-on line and registers once"] = function()
        Load()
        local original = ns.Events.Register
        local merchantRegistrations = 0
        ns.Events.Register = function(event, handler)
            if event == "MERCHANT_SHOW" then
                merchantRegistrations = merchantRegistrations + 1
            end
            return original(event, handler)
        end
        ns.Slash.Run("debug on")
        ns.Slash.Run("debug on")
        ns.Events.Register = original
        h.DeepEqual(
            Stub.ChatLines(),
            { PREFIX .. DebugOnLine(), PREFIX .. L.debugAlreadyOn },
            "chat"
        )
        h.Equal(LootLogicDB.debug.enabled, true, "still on")
        h.Equal(merchantRegistrations, 1, "registered once")
    end,

    ["Slash: debug on after a hand-set enabled prints already-on and registers"] = function()
        Load()
        LootLogicDB.debug.enabled = true
        ns.Slash.Run("debug on")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugAlreadyOn }, "chat")
        Stub.FireEvent("MERCHANT_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant logged")
    end,

    ["Slash: debug on reports a changed maxLog"] = function()
        Load()
        LootLogicDB.debug.maxLog = 50
        ns.Slash.Run("debug on")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. string.format(L.debugOn, "50") }, "chat")
    end,

    ["Slash: debug off while off prints the already-off line and changes nothing"] = function()
        Load()
        ns.Slash.Run("debug off")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugAlreadyOff }, "chat")
        h.Equal(LootLogicDB.debug.enabled, false, "still off")
    end,

    ["Slash: debug on then off then off prints off and then the already-off line"] = function()
        Load()
        ns.Slash.Run("debug on")
        Stub.ClearChat()
        ns.Slash.Run("debug off")
        ns.Slash.Run("debug off")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugOff, PREFIX .. L.debugAlreadyOff }, "chat")
    end,

    ["Slash: a bare debug prints the usage and changes nothing"] = function()
        ExpectUsage("debug")
    end,

    ["Slash: a bad debug word prints the usage and changes nothing"] = function()
        ExpectUsage("debug maybe")
    end,

    ["Slash: extra words after debug on print the usage and change nothing"] = function()
        ExpectUsage("debug on now")
    end,

    ["Slash: a read-only session refuses debug on and off and stays unchanged"] = function()
        for _, word in ipairs({ "on", "off" }) do
            LootLogicDB = h.Fixture("dbNewer")
            Stub.FireEvent("ADDON_LOADED", "LootLogic")
            Stub.ClearChat()
            ns.Slash.Run("debug " .. word)
            h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.debugReadOnly }, "chat for " .. word)
            h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "saved data for " .. word)
            Stub.FireEvent("MERCHANT_SHOW")
            h.DeepEqual(LootLogicDB, h.Fixture("dbNewer"), "no event line for " .. word)
        end
    end,

    ["Slash: events are logged after debug on and not after debug off"] = function()
        Load()
        ns.Slash.Run("debug on")
        Stub.ClearChat()
        Stub.FireEvent("BANKFRAME_OPENED")
        h.Equal(LogCount("event: BANKFRAME_OPENED"), 1, "log line")
        local entry
        for _, line in ipairs(LootLogicDB.debug.log) do
            if string.find(line, "] event: BANKFRAME_OPENED", 1, true) then
                entry = line
            end
        end
        h.True(entry, "the event line is in the log")
        local echoed = false
        for _, line in ipairs(Stub.ChatLines()) do
            if line == L.debugPrefix .. " " .. entry then
                echoed = true
            end
        end
        h.True(echoed, "the event line is echoed to chat")
        ns.Slash.Run("debug off")
        local before = #LootLogicDB.debug.log
        Stub.FireEvent("BANKFRAME_CLOSED")
        h.Equal(#LootLogicDB.debug.log, before, "no line after off")
    end,

    ["Slash: debug on stays on, events registered, when ADDON_LOADED runs again"] = function()
        Load()
        ns.Slash.Run("debug on")
        -- A reload keeps the saved table and loads the addon again; the
        -- registered handlers stand in for the fresh session's.
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        h.Equal(LootLogicDB.debug.enabled, true, "still on")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 4)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 4"), 1, "bank slots")
    end,

    ["Slash: saved debug on registers the debug-only events at ADDON_LOADED"] = function()
        LootLogicDB = nil
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        LootLogicDB.debug.enabled = true
        -- ADDON_LOADED for another addon registers nothing.
        Stub.FireEvent("ADDON_LOADED", "SomethingElse")
        Stub.FireEvent("MERCHANT_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "not registered yet")
        Stub.FireEvent("ADDON_LOADED", "LootLogic")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 1)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 1, "auction house")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 1"), 1, "bank slots")
    end,

    ["Slash: saved debug off registers nothing at ADDON_LOADED"] = function()
        Load()
        -- Turned on directly, not through the command, so only a registration
        -- made at load could write the lines.
        LootLogicDB.debug.enabled = true
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 1)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "merchant")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED"), 0, "bank slots")
    end,

    ["Slash: autoOpenContents on skips MERCHANT_SHOW and AUCTION_HOUSE_SHOW"] = function()
        Load()
        LootLogicDB.ui.autoOpenContents = true
        ns.Slash.Run("debug on")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        Stub.FireEvent("PLAYERBANKSLOTS_CHANGED", 2)
        h.Equal(LogCount("event: MERCHANT_SHOW"), 0, "merchant skipped")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 0, "auction house skipped")
        h.Equal(LogCount("event: PLAYERBANKSLOTS_CHANGED: 2"), 1, "bank slots logged")
    end,

    ["Slash: an event the client refuses is an Errors entry and the others register"] = function()
        Load()
        Stub.SetUnknownEvents({ "PLAYERBANKSLOTS_CHANGED" })
        ns.Slash.Run("debug on")
        local errors = ns.Log.Errors()
        h.Equal(#errors, 1, "one error")
        h.Equal(errors[1].area, "events", "area")
        h.True(string.find(errors[1].message, "PLAYERBANKSLOTS_CHANGED", 1, true), "names it")
        Stub.FireEvent("MERCHANT_SHOW")
        Stub.FireEvent("AUCTION_HOUSE_SHOW")
        h.Equal(LogCount("event: MERCHANT_SHOW"), 1, "merchant")
        h.Equal(LogCount("event: AUCTION_HOUSE_SHOW"), 1, "auction house")
        h.Equal(LogCount("error: events: PLAYERBANKSLOTS_CHANGED"), 1, "error line")
    end,

    ["Slash: why prints shared lines for an explicit link and a bare item ID"] = function()
        WhyBoot()
        WhyItem(199001)
        local hyperlink = "|cffa335ee|Hitem:199001:0:0:0:0:0:0|h[Why Item]|h|r"
        Stub.SetTooltipLines(hyperlink, {})
        ns.Slash.Run("why " .. hyperlink)
        h.Equal(#Stub.ChatLines(), 1, "link line count")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "explicit link result"
        )
        Stub.ClearChat()
        ns.Slash.Run("why 199001")
        h.Equal(#Stub.ChatLines(), 1, "ID line count")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "constructed link result"
        )
        WhyItem(199006)
        local uncolored = "|Hitem:199006:0:0:0:0:0:0|h[Why Item]|h"
        Stub.SetTooltipLines(uncolored, {})
        Stub.ClearChat()
        ns.Slash.Run("why " .. uncolored)
        h.Equal(#Stub.ChatLines(), 1, "uncolored hyperlink accepted")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "uncolored link result"
        )
    end,

    ["Slash: why matches a bag item and preserves suffix identity"] = function()
        WhyBoot()
        local link = WhyItem(199002, -17)
        LootLogicDB.characters["Local Test-Realm"].asks = {
            types = {},
            items = { [199002] = "include" },
        }
        Stub.SetBagSize(0, 2)
        Stub.SetBagItem(0, 1, { itemID = 199002, link = link, count = 1, quality = 1 })
        ns.Slash.Run("why 199002:-17")
        h.Equal(#Stub.ChatLines(), 2, "category and wants explanation")
        h.True(
            string.find(Stub.ChatLines()[1], "wanted by you", 1, true) ~= nil,
            "exact matching bag result"
        )
    end,

    ["Slash: why rejects extra text and reports missing IDs and hover"] = function()
        WhyBoot()
        WhyItem(199003)
        WhyItem(199005)
        local link = "|cffa335ee|Hitem:199003:0:0:0:0:0:0|h[Why Item]|h|r"
        local secondLink = "|Hitem:199005:0:0:0:0:0:0|h[Why Item]|h"
        Stub.SetTooltipLines(link, {})
        Stub.SetTooltipLines(secondLink, {})
        for _, argument in ipairs({
            "199003 extra",
            "prefix " .. link,
            link .. " extra",
            link .. " " .. link,
            link .. " " .. secondLink,
        }) do
            Stub.ClearChat()
            ns.Slash.Run("why " .. argument)
            h.DeepEqual(
                Stub.ChatLines(),
                { PREFIX .. L.detailUsage },
                "rejected argument: " .. argument
            )
        end
        Stub.SetItemExists(199004, false)
        Stub.ClearChat()
        ns.Slash.Run("why 199004")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.detailNotFound }, "missing item")
        Stub.ClearChat()
        ns.Slash.Run("why")
        h.DeepEqual(Stub.ChatLines(), { PREFIX .. L.detailNoHover }, "no hovered item")
    end,
    ["Slash: why uses hovered bag, link and inbox contexts"] = function()
        WhyBoot()
        local bagItem = WhyItem(199010)
        LootLogicDB.characters["Local Test-Realm"].asks = {
            types = {},
            items = { [199010] = "include" },
        }
        Stub.SetBagSize(0, 1)
        Stub.SetBagItem(0, 1, { itemID = 199010, link = bagItem, count = 1, quality = 1 })
        local tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "GetBagItem", getterArgs = { 0, 1 } },
            nil,
            bagItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "wanted by you", 1, true) ~= nil,
            "hovered bag item"
        )
        local linkItem = WhyItem(199011)
        Stub.ClearChat()
        tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "SetHyperlink", getterArgs = { linkItem }, hyperlink = linkItem },
            nil,
            linkItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "hovered link"
        )
        h.Stub.SetInbox({ { items = { { link = linkItem, count = 1 } } } })
        Stub.ClearChat()
        tooltip = Stub.MakeTooltip(
            "GameTooltip",
            { getterName = "GetInboxItem", getterArgs = { 1, 1 } },
            nil,
            linkItem
        )
        Stub.SetGlobal("GameTooltip", tooltip)
        local original = ns.API.ClassifyLink
        local inboxSeen = false
        ns.API.ClassifyLink = function(link, fromInbox)
            inboxSeen = inboxSeen or fromInbox == true
            return original(link, fromInbox)
        end
        ns.Slash.Run("why")
        ns.API.ClassifyLink = original
        h.True(inboxSeen, "hovered inbox retains inbox origin")
    end,
    ["Slash: why accepts token colors and falls back from malformed hover links"] = function()
        WhyBoot()
        local item = WhyItem(199099)
        local link = "|cnIQ4:|Hitem:199099:0:0:0:0:0:0|h[Why Item]|h|r"
        Stub.SetTooltipLines(link, {})
        ns.Slash.Run("why " .. link)
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "token link accepted"
        )
        Stub.ClearChat()
        Stub.SetGlobal(
            "GameTooltip",
            Stub.MakeTooltip("GameTooltip", { hyperlink = "bad" }, nil, item)
        )
        ns.Slash.Run("why")
        h.True(
            string.find(Stub.ChatLines()[1], "nobody wants this", 1, true) ~= nil,
            "valid GetItem fallback"
        )
    end,
    ["Slash: why preserves pending matching-bag results without link fallback"] = function()
        WhyBoot()
        local link = WhyItem(199012)
        Stub.SetBagSize(0, 1)
        Stub.SetBagItem(0, 1, { itemID = 199012, link = link, count = 1, quality = 1 })
        Stub.SetItemPending(199012, { itemID = 199012, name = "Why Item", link = link })
        local original = ns.API.ClassifyLink
        local linkCalls = 0
        ns.API.ClassifyLink = function(...)
            linkCalls = linkCalls + 1
            return original(...)
        end
        ns.Slash.Run("why 199012")
        ns.API.ClassifyLink = original
        h.Equal(#Stub.ChatLines(), 0, "pending bag has no classification")
        h.Equal(linkCalls, 0, "no link-only fallback")
    end,
    ["Slash: zero suffix selects the first stack and ID lookup failures are tolerated"] = function()
        WhyBoot()
        local link = WhyItem(199013, -17)
        local zeroLink = "item:199013:0:0:0:0:0:0"
        Stub.SetTooltipLines(zeroLink, {})
        local here = LootLogicDB.characters["Local Test-Realm"]
        here.asks = { types = {}, items = {} }
        LootLogicDB.characters["Alt Test-Realm"] = {
            first = "Alt",
            last = "Test",
            class = "PRIEST",
            level = 60,
            faction = here.faction,
            region = here.region,
            loadouts = {},
            asks = { types = {}, items = { [199013] = "include" } },
        }
        LootLogicDB.order = { "Alt Test-Realm", "Local Test-Realm" }
        Stub.SetBagSize(0, 2)
        Stub.SetBagItem(0, 1, {
            itemID = 199013,
            link = zeroLink,
            count = 1,
            quality = 1,
            bound = true,
        })
        Stub.SetBagItem(0, 2, { itemID = 199013, link = link, count = 1, quality = 1 })
        ns.Slash.Run("why 199013:0")
        h.True(
            string.find(Stub.ChatLines()[1], "Alt", 1, true) == nil,
            "zero suffix uses bound first stack"
        )
        Stub.ClearChat()
        ns.Slash.Run("why 199013:-17")
        h.True(
            string.find(Stub.ChatLines()[1], "Alt", 1, true) ~= nil,
            "negative suffix uses its matching stack"
        )
        WhyItem(199014)
        WhyItem(199015)
        Stub.SetExistsApi("off")
        Stub.ClearChat()
        ns.Slash.Run("why 199014")
        h.Equal(#Stub.ChatLines(), 1, "missing lookup API does not block a loaded item")
        Stub.SetExistsApi("raise")
        Stub.ClearChat()
        ns.Slash.Run("why 199015")
        h.Equal(#Stub.ChatLines(), 1, "failing lookup API does not block a loaded item")
    end,
}
