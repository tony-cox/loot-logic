local _, ns, h = ...

local Classify = ns.Classify
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Prices = ns.Prices

local HERE = "Zugar Soulsour-Region"
local PRIEST = "Boneset Hallowine-Region"
local HUNTER = "Chamoomile Rejuvenade-Region"
local ENEMY = "Gorgrim Foeman-Region"

local nextID = 98000

-- A fresh database: the priest and the hunter registered ahead of the current
-- character (a warlock), in that order, both eligible; the enemy is of the
-- other faction.
local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    local here = LootLogicDB.characters[HERE]
    local function Add(key, first, last, class, faction)
        LootLogicDB.characters[key] = {
            first = first,
            last = last,
            class = class,
            faction = faction or here.faction,
            region = here.region,
            loadouts = {},
        }
    end
    Add(PRIEST, "Boneset", "Hallowine", "PRIEST")
    Add(HUNTER, "Chamoomile", "Rejuvenade", "HUNTER")
    Add(ENEMY, "Gorgrim", "Foeman", "WARRIOR", "Other")
    LootLogicDB.order = { PRIEST, HUNTER, ENEMY, HERE }
    return here
end

local function Want(key, types, items)
    LootLogicDB.characters[key].asks = { types = types or {}, items = items or {} }
end

-- Defines an item in the fake client: Linen Cloth like by default. Returns the
-- fields with the link.
local function Define(fields)
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        name = "Item " .. nextID,
        quality = 1,
        itemLevel = 5,
        reqLevel = 0,
        sellPrice = 13,
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

-- Puts one stack in a bag slot; slotFields override the slot fields (bound,
-- count, hasNoValue, isQuest).
local function Put(item, bag, slot, slotFields)
    local placed = { itemID = item.itemID, link = item.link, count = 1, quality = item.quality }
    for key, value in pairs(slotFields or {}) do
        placed[key] = value
    end
    h.Stub.SetBagSize(bag, 20)
    h.Stub.SetBagItem(bag, slot, placed)
end

-- Defines an item and puts it in bag 0, slot 1; returns the item.
local function Bag(fields, slotFields)
    local item = Define(fields)
    Put(item, 0, 1, slotFields)
    return item
end

local function Classified()
    return Classify.BagSlot(0, 1)
end

-- Registers a fake provider that serves the price table, or the function of
-- the item ID.
local function Provider(price, options)
    options = options or {}
    local provider = { id = "fake", label = "Fake" }
    function provider.IsAvailable()
        return true
    end
    function provider.GetPrice(itemID, link)
        if type(price) == "function" then
            return price(itemID, link)
        end
        return price
    end
    if options.hasData ~= nil then
        function provider.HasData()
            return options.hasData
        end
    end
    function provider.OnUpdate() end
    Prices.Register(provider)
    return provider
end

-- A provider whose price is below every vendor price used here, so a sellable
-- item gets Vendor.
local function LowPrice()
    Provider({ unit = 1, ageDays = 0 })
end

local function Settings()
    return LootLogicDB.settings.ah
end

local function Expect(result, category, code, label)
    h.True(result ~= nil, label .. ": has a result")
    h.Equal(result.category, category, label .. ": category")
    h.Equal(result.reasonCode, code, label .. ": reason")
    h.Equal(result.linkOnly, false, label .. ": linkOnly")
end

return {
    -- Step 0 and the frame
    ["Classify: an empty slot has no result"] = function()
        Boot()
        h.Nil(Classify.BagSlot(0, 3), "empty slot")
    end,

    ["Classify: a pending item has no result, and one once it has loaded"] = function()
        Boot()
        local item = Define({ itemID = 98500 })
        h.Stub.SetItemPending(item.itemID, item)
        Put(item, 0, 1)
        h.Nil(Classified(), "pending")
        h.Nil(Classified(), "still pending, no result cached")
        h.Stub.LoadItem(item.itemID)
        h.Stub.Advance(1)
        Expect(Classified(), "vendorah", "noprovider", "after the load")
    end,

    ["Classify: an item whose tooltip fact is unread has no result"] = function()
        Boot()
        local item = Define()
        -- A fresh link the fake client has no tooltip for.
        item.link = "item:" .. item.itemID .. ":0"
        h.Stub.SetItem(item.itemID, item)
        Put(item, 0, 1)
        h.Nil(Classified(), "unreadable tooltip")
    end,

    ["Classify: the result is cached until a generation it used moves"] = function()
        Boot()
        Bag({ classID = 0, subclassID = 0 })
        local first = Classified()
        Expect(first, "none", "classstay", "consumable")
        h.True(Classified() == first, "same table from the cache")
        Generations.Bump("prices")
        h.True(Classified() == first, "a generation the result did not use")
        Generations.Bump("settings")
        local again = Classified()
        h.True(again ~= first, "settings moved, recomputed")
        Expect(again, "none", "classstay", "recomputed")
    end,

    -- Step 1a
    ["Classify: quest class, quest info, keys and tokens stay (1a)"] = function()
        Boot()
        Bag({ classID = 12, subclassID = 0 })
        Expect(Classified(), "none", "quest", "class 12")
        Bag({ classID = 7, subclassID = 5 }, { isQuest = true })
        Expect(Classified(), "none", "quest", "quest info")
        Bag({ classID = 13, subclassID = 0 })
        Expect(Classified(), "none", "quest", "key")
        Bag({ classID = 18, subclassID = 0 })
        Expect(Classified(), "none", "quest", "WoW Token")
    end,

    ["Classify: the Hearthstone is on the never-touch list (1a)"] = function()
        Boot()
        Bag({ itemID = 6948, classID = 15, subclassID = 0, bindType = 1 })
        Expect(Classified(), "none", "nevertouch", "Hearthstone")
    end,

    -- Step 1b
    ["Classify: here's Protect list and the global list keep an item (1b)"] = function()
        Boot()
        LowPrice()
        local item = Bag()
        ns.Sets.ToggleProtect(HERE, item.itemID)
        Expect(Classified(), "none", "protected", "here's list")
        ns.Sets.ToggleProtect(HERE, item.itemID)
        Expect(Classified(), "vendor", "vendor", "removed again")
        ns.Sets.ToggleProtectGlobal(item.itemID)
        Expect(Classified(), "none", "protected", "global list")
    end,

    ["Classify: another character's Protect list does not apply (1b)"] = function()
        Boot()
        LowPrice()
        local item = Bag()
        LootLogicDB.characters[PRIEST].protect = { [tostring(item.itemID)] = true }
        Generations.Bump("asks")
        Expect(Classified(), "vendor", "vendor", "priest's list")
    end,

    -- Step 1c
    ["Classify: a member of an imported set stays and names the set (1c)"] = function()
        local here = Boot()
        local item = Bag()
        here.importedSets = {
            ["outfitter:Tank"] = {
                source = "outfitter",
                name = "Tank",
                items = { { id = item.itemID, suffix = 0 } },
            },
        }
        here.loadouts[1].link = { source = "outfitter", set = "Tank" }
        Generations.Bump("loadouts")
        local result = Classified()
        Expect(result, "none", "inset", "set member")
        h.Equal(result.reasonData.set, "Tank", "set name")
        h.Equal(result.reasonData.loadout, here.loadouts[1].name, "linked loadout")
    end,

    ["Classify: an imported-set member beats a want (1c before 4)"] = function()
        local here = Boot()
        local item = Bag()
        Want(HERE, { ["7:5"] = {} })
        here.importedSets = {
            ["equipmentset:Cat"] = {
                source = "equipmentset",
                name = "Cat",
                items = { { id = item.itemID, suffix = 0 } },
            },
        }
        Generations.Bump("loadouts")
        Expect(Classified(), "none", "inset", "set before wants")
    end,

    -- Step 1d
    ["Classify: a soulbound tool always stays (1d)"] = function()
        Boot()
        Want(PRIEST, { ["2:*"] = {} })
        Bag({ classID = 2, subclassID = 14 }, { bound = true })
        Expect(Classified(), "none", "tool", "soulbound 2/14")
    end,

    ["Classify: a tradable tool nobody wants stays, 2/14, 2/20 and the list (1d)"] = function()
        Boot()
        Bag({ classID = 2, subclassID = 14 })
        Expect(Classified(), "none", "tool", "2/14")
        Bag({ classID = 2, subclassID = 20 })
        Expect(Classified(), "none", "tool", "2/20")
        Bag({ itemID = 4471, classID = 7, subclassID = 11 })
        Expect(Classified(), "none", "tool", "Flint and Tinder")
    end,

    ["Classify: a tradable tool that an eligible character wants goes to step 4 (1d)"] = function()
        Boot()
        Want(HUNTER, { ["7:11"] = {} })
        Want(ENEMY, { ["7:11"] = {} })
        Bag({ itemID = 4471, classID = 7, subclassID = 11 })
        local result = Classified()
        Expect(result, "char:" .. HUNTER, "wanted", "tool wanted")
        h.Equal(result.reasonData.winner, HUNTER, "winner")
    end,

    ["Classify: a tool wanted only by an opposite-faction character stays (1d)"] = function()
        Boot()
        Want(ENEMY, { ["7:11"] = {} })
        Bag({ itemID = 4471, classID = 7, subclassID = 11 })
        Expect(Classified(), "none", "tool", "ineligible wanter")
    end,

    -- Step 1e
    ["Classify: a soulbound item with no vendor value stays (1e)"] = function()
        Boot()
        Bag({ sellPrice = 0, bindType = 1 }, { bound = true })
        Expect(Classified(), "none", "novalue", "soulbound, no value")
    end,

    ["Classify: 1e lets an item through when here wants it"] = function()
        Boot()
        Want(HERE, { ["7:5"] = {} })
        Bag({ sellPrice = 0 }, { bound = true })
        Expect(Classified(), "none", "wantedhere", "here wants")
    end,

    ["Classify: soulbound gear with no value passes 1e and step 3 leaves it to step 6"] = function()
        Boot()
        -- Plate that the warlock cannot wear: no step 3 verdict, so the later
        -- steps decide, and a soulbound piece with no value gets novalue.
        Bag({ sellPrice = 0, classID = 4, subclassID = 4, equipLoc = "INVTYPE_CHEST" }, {
            bound = true,
        })
        local result = Classified()
        Expect(result, "none", "novalue", "gear reaches step 6")
    end,

    ["Classify: an account-bound item with no vendor value is tradable, not 1e"] = function()
        Boot()
        Want(PRIEST, { ["7:5"] = {} })
        Bag({ sellPrice = 0, bindType = 7 }, { bound = true })
        Expect(Classified(), "char:" .. PRIEST, "wanted", "account-bound goes to a wanter")
    end,

    -- Step 2
    ["Classify: a grey item sells to the vendor (2)"] = function()
        Boot()
        Bag({ quality = 0, sellPrice = 7 })
        local result = Classified()
        Expect(result, "vendor", "grey", "grey")
        h.Equal(result.reasonData.vendor, 7, "price for the text")
    end,

    ["Classify: a grey item with no vendor value is none (2)"] = function()
        Boot()
        Bag({ quality = 0, sellPrice = 0 })
        Expect(Classified(), "none", "novalue", "worthless grey")
    end,

    ["Classify: a grey item here includes stays; another includes it goes there (2)"] = function()
        Boot()
        local item = Bag({ quality = 0, sellPrice = 7 })
        Want(HERE, {}, { [item.itemID] = "include" })
        Expect(Classified(), "none", "wantedhere", "here includes")
        Want(HERE)
        Want(HUNTER, {}, { [item.itemID] = "include" })
        Want(PRIEST, {}, { [item.itemID] = "include" })
        Generations.Bump("asks")
        local result = Classified()
        Expect(result, "char:" .. PRIEST, "wanted", "first in the order")
        h.Equal(result.reasonData.kind, "item", "an item include")
    end,

    ["Classify: a grey item needs the include; a type want does not move it (2)"] = function()
        Boot()
        Bag({ quality = 0, sellPrice = 7 })
        Want(PRIEST, { ["7:5"] = {} })
        Expect(Classified(), "vendor", "grey", "type want ignored for greys")
    end,

    ["Classify: a soulbound grey item is not routed to an include (2)"] = function()
        Boot()
        local item = Bag({ quality = 0, sellPrice = 7, bindType = 1 }, { bound = true })
        Want(PRIEST, {}, { [item.itemID] = "include" })
        Expect(Classified(), "vendor", "grey", "soulbound grey")
    end,

    ["Classify: an opposite-faction include does not take a grey item (2)"] = function()
        Boot()
        local item = Bag({ quality = 0, sellPrice = 7 })
        Want(ENEMY, {}, { [item.itemID] = "include" })
        Expect(Classified(), "vendor", "grey", "ineligible")
    end,

    -- Step 4: wants
    ["Classify: here's want keeps the item (4)"] = function()
        Boot()
        Want(HERE, { ["7:5"] = {} })
        Want(PRIEST, { ["7:5"] = {} })
        Bag()
        local result = Classified()
        Expect(result, "none", "wantedhere", "here first")
        h.Equal(result.reasonData.kind, "subclass", "the subclass want")
    end,

    ["Classify: the first eligible wanter in the global order gets it (4)"] = function()
        Boot()
        Want(HUNTER, { ["7:*"] = {} })
        Want(PRIEST, { ["7:5"] = {} })
        Bag()
        local result = Classified()
        Expect(result, "char:" .. PRIEST, "wanted", "priest first in the order")
        h.Equal(result.reasonData.kind, "subclass", "kind")
        LootLogicDB.order = { HUNTER, PRIEST, ENEMY, HERE }
        Generations.Bump("roster")
        result = Classified()
        Expect(result, "char:" .. HUNTER, "wanted", "after the order changed")
        h.Equal(result.reasonData.kind, "class", "whole-class want")
    end,

    ["Classify: a want names the item include before a type want (4)"] = function()
        Boot()
        local item = Bag()
        Want(PRIEST, { ["7:5"] = {} }, { [item.itemID] = "include" })
        h.Equal(Classified().reasonData.kind, "item", "include first")
    end,

    ["Classify: minimum quality, exclude and include decide a want (4)"] = function()
        Boot()
        LowPrice()
        local item = Bag({ quality = 1 })
        Want(PRIEST, { ["7:5"] = { minQuality = 2 } })
        Expect(Classified(), "vendor", "vendor", "below the minimum")
        Want(PRIEST, { ["7:5"] = { minQuality = 2 } }, { [item.itemID] = "include" })
        Generations.Bump("asks")
        Expect(Classified(), "char:" .. PRIEST, "wanted", "include ignores quality")
        Want(PRIEST, { ["7:5"] = {} }, { [item.itemID] = "exclude" })
        Generations.Bump("asks")
        Expect(Classified(), "vendor", "vendor", "excluded")
    end,

    ["Classify: a class restriction takes the item from a want (4)"] = function()
        Boot()
        local item = Define({ classID = 4, subclassID = 3 })
        h.Stub.SetTooltipLines(item.link, { "Classes: Hunter" })
        Put(item, 0, 1)
        Want(PRIEST, { ["4:*"] = {} })
        Want(HUNTER, { ["4:*"] = {} })
        Expect(Classified(), "char:" .. HUNTER, "wanted", "the hunter, not the priest")
    end,

    ["Classify: a soulbound item is not routed to a wanter (4)"] = function()
        Boot()
        Want(PRIEST, { ["7:5"] = {} })
        Bag({}, { bound = true })
        Expect(Classified(), "vendor", "vendorbound", "soulbound")
    end,

    ["Classify: a gear piece that step 3 leaves alone reaches the wants (3d)"] = function()
        Boot()
        Want(PRIEST, { ["4:*"] = {} })
        -- Plate: no loadout here or on the roster can use it.
        Bag({ classID = 4, subclassID = 4, equipLoc = "INVTYPE_CHEST" })
        Expect(Classified(), "char:" .. PRIEST, "wanted", "gear wanted")
    end,

    -- Step 5
    ["Classify: the shipped dispositions decide stay or sell (5)"] = function()
        Boot()
        LowPrice()
        Bag({ classID = 0, subclassID = 1 })
        Expect(Classified(), "none", "classstay", "consumable stays")
        Bag({ classID = 15, subclassID = 1 })
        Expect(Classified(), "none", "classstay", "15:1 stays (Soul Shards, by the class default)")
        Bag({ classID = 15, subclassID = 0 })
        Expect(Classified(), "vendor", "vendor", "15:0 sells")
        Bag({ classID = 8, subclassID = 0 })
        Expect(Classified(), "none", "classstay", "an unlisted class stays")
    end,

    ["Classify: overrides come before the shipped table, class:subclass first (5)"] = function()
        Boot()
        LowPrice()
        Bag({ classID = 0, subclassID = 1 })
        LootLogicDB.settings.classOverride = { ["0"] = "sell" }
        Generations.Bump("settings")
        Expect(Classified(), "vendor", "vendor", "class override sells")
        LootLogicDB.settings.classOverride = { ["0"] = "sell", ["0:1"] = "stay" }
        Generations.Bump("settings")
        Expect(Classified(), "none", "classstay", "class:subclass override wins")
        Bag({ classID = 15, subclassID = 1 })
        LootLogicDB.settings.classOverride = { ["15"] = "sell" }
        Generations.Bump("settings")
        Expect(
            Classified(),
            "vendor",
            "vendor",
            "a class override beats the shipped class:subclass"
        )
    end,

    ["Classify: a want beats the class disposition (4 before 5)"] = function()
        Boot()
        Want(PRIEST, { ["0:*"] = {} })
        Bag({ classID = 0, subclassID = 0 })
        Expect(Classified(), "char:" .. PRIEST, "wanted", "consumable wanted")
    end,

    -- Step 6
    ["Classify: a bound item sells to the vendor, or has no value (6)"] = function()
        Boot()
        Bag({ sellPrice = 9, bindType = 1 }, { bound = true })
        Expect(Classified(), "vendor", "vendorbound", "soulbound")
        Bag({ sellPrice = 9, bindType = 8 }, { bound = true })
        Expect(Classified(), "vendor", "vendorbound", "account-bound")
        Bag({ sellPrice = 0, bindType = 8 })
        Expect(Classified(), "none", "novalue", "account-bound, no value")
    end,

    ["Classify: an account-bound item never goes to the AH (6)"] = function()
        Boot()
        Provider({ unit = 100000, ageDays = 0 })
        Bag({ sellPrice = 10, bindType = 8 }, { bound = true })
        Expect(Classified(), "vendor", "vendorbound", "priced but account-bound")
    end,

    ["Classify: no price addon gives Vendor/AH, never Vendor (6)"] = function()
        Boot()
        Bag()
        local result = Classified()
        Expect(result, "vendorah", "noprovider", "no provider")
        h.Equal(result.reasonData.noVendorValue, false, "has a vendor value")
    end,

    ["Classify: Vendor/AH with no vendor value says so (6)"] = function()
        Boot()
        Bag({ sellPrice = 5 }, { hasNoValue = true })
        local result = Classified()
        Expect(result, "vendorah", "noprovider", "no price, no vendor value")
        h.Equal(result.reasonData.noVendorValue, true, "flag")
    end,

    ["Classify: no scan data gives noscan until a price is seen, then stale (6)"] = function()
        Boot()
        local price
        Provider(function()
            return price
        end, { hasData = false })
        Bag()
        Expect(Classified(), "vendorah", "noscan", "provider without data")
        price = { unit = 1000, ageDays = 9, timestamp = GetServerTime() - 9 * 86400 }
        Generations.Bump("prices")
        Expect(Classified(), "vendorah", "stale", "a price was seen: stale, not noscan")
    end,

    ["Classify: an old price gives Vendor/AH with the price for the text (6)"] = function()
        Boot()
        Provider({ unit = 1000, ageDays = 9 }, { hasData = true })
        Bag()
        local result = Classified()
        Expect(result, "vendorah", "stale", "stale")
        h.Equal(result.reasonData.price.unit, 1000, "was price")
        h.Equal(result.reasonData.price.ageDays, 9, "age")
        h.Equal(result.reasonData.maxPriceAgeDays, 7, "maximum")
        h.Equal(result.reasonData.provider, "fake", "provider id")
    end,

    ["Classify: an item the provider never saw gives Vendor/AH (6)"] = function()
        Boot()
        Provider(nil, { hasData = true })
        Bag()
        Expect(Classified(), "vendorah", "neverseen", "never seen")
    end,

    ["Classify: the AH rule passes and fails on each of its three tests (6)"] = function()
        Boot()
        -- Defaults: cut 5%, floor 100c, 10%.
        local price = { unit = 1000, ageDays = 0 }
        Provider(function()
            return price
        end)
        Bag({ sellPrice = 100 })
        local result = Classified()
        Expect(result, "ah", "ah", "net 950, gain 850")
        local detail = result.reasonData.price
        h.Equal(detail.net, 950, "net")
        h.Equal(detail.vendor, 100, "vendor")
        h.Equal(detail.gainPerUnit, 850, "gain per unit")
        h.Equal(detail.gainTotal, 850, "gain total")
        h.Equal(detail.unit, 1000, "unit")
        h.Equal(detail.ageDays, 0, "age")
        h.Equal(detail.source, "fake", "source")
        h.Equal(detail.label, "Fake", "label")

        -- Under the absolute floor: net 190, gain 90.
        price = { unit = 200, ageDays = 0 }
        Generations.Bump("prices")
        result = Classified()
        Expect(result, "vendor", "vendor", "net 190, vendor 100: gain 90 under 100")
        h.Equal(result.reasonData.price.gainTotal, 90, "gain total shown")

        -- Under the percentage floor: vendor 1500, unit 1700, net 1615, gain
        -- 115 clears the absolute floor.
        Bag({ sellPrice = 1500 })
        price = { unit = 1700, ageDays = 0 }
        Generations.Bump("prices")
        result = Classified()
        -- 11500 >= 15000 is false, so the 10% floor fails.
        Expect(result, "vendor", "vendor", "percentage floor fails")

        -- A gain of 0 or less never lists.
        price = { unit = 1500, ageDays = 0 }
        Generations.Bump("prices")
        Expect(Classified(), "vendor", "vendor", "net below vendor")
    end,

    ["Classify: the AH rule passes at exactly its floors (6)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 0
        settings.minGainCopper = 100
        settings.minGainPct = 10
        Provider({ unit = 1100, ageDays = 0 })
        Bag({ sellPrice = 1000 })
        Expect(Classified(), "ah", "ah", "gain 100 is 10% of 1000")
    end,

    ["Classify: the cut is applied first and floored (6)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 5
        settings.minGainCopper = 0
        settings.minGainPct = 0
        Provider({ unit = 119, ageDays = 0 })
        Bag({ sellPrice = 112 })
        local result = Classified()
        -- 119 * 95 / 100 = 113.05, floored to 113: gain 1.
        h.Equal(result.reasonData.price.net, 113, "net floored")
        Expect(result, "ah", "ah", "gain 1 clears a zero floor")
        settings.ahCutPct = 6
        Generations.Bump("settings")
        result = Classified()
        -- 119 * 94 / 100 = 111.86, floored to 111: below vendor 112.
        h.Equal(result.reasonData.price.net, 111, "net after a 6% cut")
        Expect(result, "vendor", "vendor", "the cut moves it to Vendor")
    end,

    ["Classify: nothing for a vendor-less item below the threshold (6)"] = function()
        Boot()
        Provider({ unit = 50, ageDays = 0 })
        Bag({ sellPrice = 0 }, { hasNoValue = true })
        Expect(Classified(), "none", "belowthreshold", "net 47 under 100, no vendor value")
        Settings().minGainCopper = 0
        Generations.Bump("settings")
        Expect(Classified(), "ah", "ah", "any gain lists with a zero floor")
    end,

    ["Classify: with vendor 0 only the absolute floor applies (6)"] = function()
        Boot()
        local settings = Settings()
        settings.minGainPct = 50
        Provider({ unit = 200, ageDays = 0 })
        Bag({ sellPrice = 0 }, { hasNoValue = true })
        Expect(Classified(), "ah", "ah", "net 190 clears 100 whatever the percentage")
    end,

    ["Classify: the holding multiplies the gain, 120 Linen at 1c clears 1s (6)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 0
        settings.minGainPct = 0
        Provider({ unit = 14, ageDays = 0 })
        -- Linen at vendor 13: a net gain of 1 copper each.
        local linen = Define({ sellPrice = 13 })
        Put(linen, 0, 1, { count = 60 })
        Put(linen, 1, 1, { count = 60 })
        Expect(Classify.BagSlot(0, 1), "ah", "ah", "bag 0")
        Expect(Classify.BagSlot(1, 1), "ah", "ah", "bag 1: both stacks share the holding")
        h.Equal(Classify.BagSlot(0, 1).reasonData.price.gainTotal, 120, "120 copper")
    end,

    ["Classify: one Linen at a 1c gain does not clear the 1s floor (6)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 0
        settings.minGainPct = 0
        Provider({ unit = 14, ageDays = 0 })
        Bag({ sellPrice = 13 })
        Expect(Classified(), "vendor", "vendor", "gain 1 under 100")
    end,

    ["Classify: the holding example holds with a vendor price of 0 (6)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 0
        Provider({ unit = 1, ageDays = 0 })
        local linen = Define({ sellPrice = 0 })
        Put(linen, 0, 1, { count = 120, hasNoValue = true })
        Expect(Classified(), "ah", "ah", "120 x 1c with no vendor value")
        Put(linen, 0, 1, { count = 1, hasNoValue = true })
        Expect(Classified(), "none", "belowthreshold", "one item")
    end,

    ["Classify: the bags and the bank count their own holding (7.5)"] = function()
        Boot()
        local settings = Settings()
        settings.ahCutPct = 0
        settings.minGainPct = 0
        Provider({ unit = 14, ageDays = 0 })
        local linen = Define({ sellPrice = 13 })
        Put(linen, 0, 1, { count = 120 })
        Put(linen, 6, 1, { count = 5 })
        Expect(Classify.BagSlot(0, 1), "ah", "ah", "bags: 120")
        Expect(Classify.BagSlot(6, 1), "vendor", "vendor", "bank: 5")
        h.Equal(Classify.BagSlot(6, 1).reasonData.price.gainTotal, 5, "bank holding")
    end,

    -- The cache and the clock
    ["Classify: a price change recomputes a step 6 result, not an earlier one (cache)"] = function()
        Boot()
        local price = { unit = 1000, ageDays = 0 }
        Provider(function()
            return price
        end)
        Bag({ sellPrice = 100 })
        local first = Classified()
        Expect(first, "ah", "ah", "priced")
        price = { unit = 100, ageDays = 0 }
        h.True(Classified() == first, "no notice yet, the cache stands")
        Generations.Bump("prices")
        Expect(Classified(), "vendor", "vendor", "after the notice")
        Bag({ classID = 12, subclassID = 0 })
        local quest = Classified()
        Generations.Bump("prices")
        h.True(Classified() == quest, "a hard stay did not use prices")
    end,

    ["Classify: a result that relied on a price expires when it turns stale (cache)"] = function()
        Boot()
        local timestamp = GetServerTime()
        Provider(function()
            local age = math.floor((GetServerTime() - timestamp) / 86400)
            return { unit = 1000, ageDays = age, timestamp = timestamp }
        end, { hasData = true })
        Bag({ sellPrice = 100 })
        local first = Classified()
        Expect(first, "ah", "ah", "fresh")
        h.Equal(Settings().maxPriceAgeDays, 7, "maximum age is the default")
        h.Stub.Advance(7 * 86400 + 3600)
        Expect(Classified(), "ah", "ah", "still usable on day 7")
        h.Stub.Advance(86400)
        local later = Classified()
        Expect(later, "vendorah", "stale", "day 8: stale, Vendor/AH")
    end,

    -- Errors
    ["Classify: an engine error gives the error result, which is cached (frame)"] = function()
        Boot()
        Bag()
        local dispositions = ns.ItemClasses.dispositions
        ns.ItemClasses.dispositions = nil
        local result = Classified()
        Expect(result, "none", "error", "error result")
        h.Equal(result.reasonText, L.errorEngine, "error text")
        h.Equal(Log.errorCount, 1, "one error recorded")
        h.Equal(Log.Errors()[1].area, "engine", "area")
        local chat = h.Stub.ChatLines()
        h.Equal(#chat, 1, "one chat line")
        h.True(Classified() == result, "cached, not retried")
        h.Equal(Log.errorCount, 1, "no second error")
        ns.ItemClasses.dispositions = dispositions
        Generations.Bump("settings")
        Expect(Classified(), "vendorah", "noprovider", "retried once a generation moved")
    end,

    ["Classify: the error line is printed once per session (frame)"] = function()
        Boot()
        ns.ItemClasses.dispositions = nil
        Bag()
        Classified()
        Bag()
        Put(Define(), 0, 2)
        Classify.BagSlot(0, 2)
        h.Equal(#h.Stub.ChatLines(), 1, "one line for two errors")
        h.Equal(Log.errorCount, 2, "both recorded")
    end,

    -- The reason data of other results
    ["Classify: the class stay, tool and protect results carry no reason text yet"] = function()
        Boot()
        Bag({ classID = 0, subclassID = 0 })
        local result = Classified()
        h.Nil(result.reasonText, "stage 14 writes the text")
        h.DeepEqual(result.reasonData, {}, "no fill-ins")
    end,

    ["Classify: the quest stay comes before Protect and wants (1a before 1b)"] = function()
        Boot()
        local item = Bag({ classID = 12, subclassID = 0 })
        ns.Sets.ToggleProtect(HERE, item.itemID)
        Want(HERE, { ["12:*"] = {} })
        Expect(Classified(), "none", "quest", "quest first")
    end,

    ["Classify: a refundable purchase sets the reason data flag (7.6)"] = function()
        Boot()
        Bag({ classID = 0, subclassID = 0 }, { refundSeconds = 3000 })
        local result = Classified()
        Expect(result, "none", "classstay", "refundable, classified normally")
        h.Equal(result.reasonData.refundable, true, "flag")
        Bag({ classID = 0, subclassID = 0 })
        h.Nil(Classified().reasonData.refundable, "not a purchase")
    end,

    ["Classify: a classification error from the facts read gives the error result"] = function()
        Boot()
        Bag()
        local FromSlot = ns.ItemFacts.FromSlot
        ns.ItemFacts.FromSlot = function()
            error("tooltip API failed")
        end
        local result = Classified()
        ns.ItemFacts.FromSlot = FromSlot
        Expect(result, "none", "error", "facts read raised")
        h.Equal(result.reasonText, L.errorEngine, "error text")
        h.Equal(Log.errorCount, 1, "one error recorded")
        h.Equal(Log.Errors()[1].area, "engine", "area")
        h.Nil(Classify.BagSlot(0, 9), "an empty slot is still nil")
    end,

    -- Cases the plan names
    ["Classify: a tradable tool that only here wants is wanted here (1d)"] = function()
        Boot()
        Want(HERE, { ["7:11"] = {} })
        Bag({ itemID = 4471, classID = 7, subclassID = 11 })
        Expect(Classified(), "none", "wantedhere", "here wants the tool")
    end,

    ["Classify: a tool that here and another character want is wanted here (1d)"] = function()
        Boot()
        Want(HERE, { ["7:11"] = {} })
        Want(HUNTER, { ["7:11"] = {} })
        Bag({ itemID = 4471, classID = 7, subclassID = 11 })
        Expect(Classified(), "none", "wantedhere", "here first")
    end,

    ["Classify: a soulbound tool that here wants still stays (1d)"] = function()
        Boot()
        Want(HERE, { ["7:11"] = {} })
        Bag({ itemID = 4471, classID = 7, subclassID = 11 }, { bound = true })
        Expect(Classified(), "none", "tool", "soulbound tool")
    end,

    ["Classify: a soulbound item that here wants is wanted here, not routed (4)"] = function()
        Boot()
        Want(HERE, { ["7:5"] = {} })
        Want(PRIEST, { ["7:5"] = {} })
        Bag({}, { bound = true })
        Expect(Classified(), "none", "wantedhere", "soulbound, here wants")
    end,

    ["Classify: a container stays under the shipped class default (5, 7.5)"] = function()
        Boot()
        LowPrice()
        Bag({ classID = 1, subclassID = 0 })
        Expect(Classified(), "none", "classstay", "bag stays")
    end,

    ["Classify: requireLastScan gives notinscan for a price outside the last scan (6)"] = function()
        Boot()
        Settings().requireLastScan = true
        local provider = Provider({ unit = 1000, ageDays = 0, inLastScan = false }, {
            hasData = true,
        })
        provider.honoursLastScan = true
        Bag({ sellPrice = 100 })
        Expect(Classified(), "vendorah", "notinscan", "not in the last scan")
    end,

    ["Classify: an item include is exempt from a class restriction (4)"] = function()
        Boot()
        local item = Define({ classID = 4, subclassID = 3 })
        h.Stub.SetTooltipLines(item.link, { "Classes: Hunter" })
        Put(item, 0, 1)
        Want(PRIEST, {}, { [item.itemID] = "include" })
        Expect(Classified(), "char:" .. PRIEST, "wanted", "the priest, by include")
    end,

    ["Classify: an item AHDB marks unsellable has vendor price 0 (6)"] = function()
        Boot()
        AuctionDB = {
            SellablePrice = function()
                return nil
            end,
        }
        Provider({ unit = 50, ageDays = 0 })
        Bag({ sellPrice = 500 })
        local result = Classified()
        AuctionDB = nil
        Expect(result, "none", "belowthreshold", "vendor forced to 0")
        h.Equal(result.reasonData.vendor, 0, "vendor price")
    end,
}
