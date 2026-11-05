local _, ns, h = ...

local API = ns.API
local Generations = ns.Generations

local HERE = "Local Test-Realm"
local OTHER = "Alt Test-Realm"
local nextID = 104000

local function Boot()
    LootLogicDB = nil
    h.Stub.SetPlayer({
        first = "Local",
        last = "Test",
        realm = "Realm",
        faction = "Alliance",
        class = "WARRIOR",
        level = 60,
    })
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    local here = LootLogicDB.characters[HERE]
    LootLogicDB.characters[OTHER] = {
        first = "Alt",
        last = "Test",
        class = "PRIEST",
        level = 60,
        faction = here.faction,
        region = here.region,
        loadouts = {},
        asks = { types = {}, items = {} },
    }
    LootLogicDB.order = { OTHER, HERE }
    LootLogicDB.settings.display.palette = "default"
    return here
end

local function Define(fields)
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        name = "Test Item",
        quality = 1,
        itemLevel = 1,
        reqLevel = 0,
        sellPrice = 0,
        bindType = 0,
        classID = 7,
        subclassID = 5,
    }
    for key, value in pairs(fields or {}) do
        item[key] = value
    end
    item.link = "item:" .. item.itemID
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

local function Put(item)
    h.Stub.SetBagSize(0, 10)
    h.Stub.SetBagItem(0, 1, {
        itemID = item.itemID,
        link = item.link,
        count = 1,
        quality = item.quality,
    })
end

local function Include(item)
    LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
end

return {
    ["bag and link results use the same verdict with the link-only flag"] = function()
        Boot()
        local item = Define()
        Put(item)
        Include(item)

        local bag = API.ClassifyBagSlot(0, 1)
        local link = API.ClassifyLink(item.link)

        h.Equal(bag.category, "char:" .. OTHER, "bag category")
        h.Equal(link.category, bag.category, "link category")
        h.Equal(bag.linkOnly, false, "bag result")
        h.Equal(link.linkOnly, true, "link-only result")
        h.Equal(link.reasonCode, bag.reasonCode, "reason")
    end,

    ["pending item data returns nil from both API paths"] = function()
        Boot()
        local item = Define()
        Put(item)
        h.Stub.SetItemPending(item.itemID, item)

        h.Nil(API.ClassifyBagSlot(0, 1), "pending bag item")
        h.Nil(API.ClassifyLink(item.link), "pending link item")
    end,

    ["results have the public category line and palette fields"] = function()
        Boot()
        local item = Define()
        Include(item)
        h.Stub.SetIconPath("Interface\\Icons\\ClassIcon_PRIEST", 900001)
        local result = API.ClassifyLink(item.link)

        h.Equal(result.label, "Alt", "label")
        h.DeepEqual(result.color, RAID_CLASS_COLORS.PRIEST, "class color")
        h.Equal(result.short, "A", "short")
        h.Equal(result.icon, 900001, "class icon")
        h.Equal(result.line, "LootLogic: Alt (wants Test Item; not in your bags)", "line")

        local rows = API.GetActiveCategories()
        h.Equal(rows[1].id, "char:" .. OTHER, "first category")
        h.Equal(rows[1].icon, 900001, "active category icon")
        h.Equal(rows[2].id, "ah", "AH category")
        h.Equal(rows[5].id, "equip", "Equip category")
        h.Equal(rows[6].id, "none", "No category is last")
        h.Equal(rows[6].label, "No category", "No category label")
        h.DeepEqual(rows[6].color, NORMAL_FONT_COLOR, "No category default color")
        h.Equal(type(rows[6].icon), "number", "No category FileID")
    end,

    ["character short names distinguish colliding display names"] = function()
        Boot()
        local item = Define()
        local characters = LootLogicDB.characters
        characters[OTHER].first = "Zo"
        characters[OTHER].last = "One"
        characters[OTHER].asks.items[item.itemID] = "include"
        characters["Zu Test-Realm"] = {
            first = "Zu",
            last = "Two",
            class = "PRIEST",
            level = 60,
            faction = characters[OTHER].faction,
            region = characters[OTHER].region,
            loadouts = {},
            asks = { types = {}, items = {} },
        }
        LootLogicDB.order = { OTHER, "Zu Test-Realm", HERE }
        Generations.Bump("asks")
        local zo = API.ClassifyLink(item.link)
        h.Equal(zo.label, "Zo", "first display name")
        h.Equal(zo.short, "Zo", "first short name")
        characters[OTHER].asks.items[item.itemID] = nil
        characters["Zu Test-Realm"].asks.items[item.itemID] = "include"
        Generations.Bump("asks")
        local zu = API.ClassifyLink(item.link)
        h.Equal(zu.label, "Zu", "second display name")
        h.Equal(zu.short, "Zu", "second short name")

        characters[OTHER].first = "Ann"
        characters[OTHER].last = "One"
        characters["Zu Test-Realm"].asks.items[item.itemID] = nil
        characters[OTHER].asks.items[item.itemID] = "include"
        characters["Zu Test-Realm"].first = "Abe"
        characters["Aby Test-Realm"] = {
            first = "Aby",
            last = "Three",
            class = "PRIEST",
            level = 60,
            faction = characters[OTHER].faction,
            region = characters[OTHER].region,
            loadouts = {},
            asks = { types = {}, items = {} },
        }
        LootLogicDB.order = { OTHER, "Zu Test-Realm", "Aby Test-Realm", HERE }
        Generations.Bump("asks")
        h.Equal(API.ClassifyLink(item.link).short, "An", "Ann short name")
        characters[OTHER].asks.items[item.itemID] = nil
        characters["Zu Test-Realm"].asks.items[item.itemID] = "include"
        Generations.Bump("asks")
        h.Equal(API.ClassifyLink(item.link).short, "Ae", "Abe short name")
        characters["Zu Test-Realm"].asks.items[item.itemID] = nil
        characters["Aby Test-Realm"].asks.items[item.itemID] = "include"
        Generations.Bump("asks")
        h.Equal(API.ClassifyLink(item.link).short, "Ay", "Aby short name")
    end,

    ["callbacks coalesce bumps and isolate callback errors"] = function()
        Boot()
        h.Stub.Advance(0)
        local calls = {}
        API.RegisterCallback("CHANGED", function(generation, name)
            calls[#calls + 1] = { generation = generation, name = name }
        end)
        API.RegisterCallback("CHANGED", function()
            error("callback failed", 0)
        end)
        API.RegisterCallback("CHANGED", function(generation, name)
            calls[#calls + 1] = { generation = generation, name = name }
        end)
        local before = API.GetGeneration()

        Generations.Bump("asks")
        Generations.Bump("roster")
        h.Equal(#calls, 0, "deferred until the frame ends")
        h.Stub.Advance(0)

        h.Equal(API.GetGeneration(), before + 2, "generation")
        h.Equal(#calls, 2, "both callbacks ran")
        h.DeepEqual(calls[1], { generation = before + 2, name = "asks" }, "first callback")
        h.DeepEqual(calls[2], calls[1], "second callback")
        h.Equal(ns.Log.Errors()[1].message, "callback failed", "callback error")
    end,
}
