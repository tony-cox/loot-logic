local _, ns, h = ...

local ItemFacts = ns.ItemFacts

local items = h.Fixture("items")

local function Link(itemID, suffix)
    return string.format("|cffffffff|Hitem:%d:0:0:0:0:0:%d:0:60|h[Test]|h|r", itemID, suffix or 0)
end

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    LootLogicDB.debug.enabled = true
end

-- Defines a fixture item in the fake client and puts one stack of it in a bag
-- slot; options override the slot fields.
local function Place(name, bag, slot, options)
    local fixture = items[name]
    h.Stub.SetItem(fixture.itemID, fixture)
    local item = { itemID = fixture.itemID, link = Link(fixture.itemID), count = 1, quality = 1 }
    for key, value in pairs(options or {}) do
        item[key] = value
    end
    h.Stub.SetBagSize(bag, math.max(slot, 4))
    h.Stub.SetBagItem(bag, slot, item)
    return item
end

local function CountLines(text)
    local count = 0
    for _, line in ipairs(LootLogicDB.debug.log) do
        if string.find(line, text, 1, true) then
            count = count + 1
        end
    end
    return count
end

return {
    ["Facts: the first item-data request time is kept by later requests"] = function()
        Boot()
        local itemID = 97101
        h.Equal(ItemFacts.RequestedAt(itemID), nil, "not requested")
        h.Stub.SetItemPending(itemID, { itemID = itemID, link = "item:" .. itemID })
        local first = GetTime()
        ItemFacts.FromLink("item:" .. itemID)
        h.Equal(ItemFacts.RequestedAt(itemID), first, "first request time")
        h.Stub.Advance(5)
        ItemFacts.FromLink("item:" .. itemID)
        h.Equal(ItemFacts.RequestedAt(itemID), first, "later request does not move it")
    end,
    ["Facts: every fact of a gear piece in a bag slot"] = function()
        local item = Place("robe", 0, 1, { quality = 3, bound = false })
        h.Stub.SetTooltipLines(item.link, { "Test Robe", "Binds when equipped" })
        local facts = ItemFacts.FromSlot(0, 1)
        h.DeepEqual(facts, {
            bag = 0,
            slot = 1,
            itemID = 14138,
            link = item.link,
            suffix = 0,
            stack = 1,
            quality = 3,
            bound = false,
            isAccountBound = false,
            classID = 4,
            subclassID = 1,
            equipLoc = "INVTYPE_ROBE",
            bindType = 2,
            reqLevel = 55,
            isQuest = false,
            hasNoValue = false,
            unique = false,
            vendorPrice = 4000,
            itemLevel = 66,
            unscoredEffect = false,
            holding = 1,
            refundable = false,
            pending = false,
            secret = false,
            tooltipUnread = false,
        }, "the facts of the robe")
    end,

    ["Facts: an empty slot has no facts"] = function()
        h.Stub.SetBagSize(0, 4)
        h.Nil(ItemFacts.FromSlot(0, 2), "empty")
    end,

    ["Facts: the bound state and the stack come from the slot"] = function()
        Place("helm", 0, 1, { bound = true, count = 3, quality = 4 })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.bound, true, "bound")
        h.Equal(facts.stack, 3, "stack")
        h.Equal(facts.quality, 4, "quality")
        h.Equal(facts.bindType, 1, "bind on pickup")
    end,

    ["Facts: hasNoValue forces the vendor price to 0"] = function()
        Place("linen", 0, 1, { hasNoValue = true })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.hasNoValue, true, "no value")
        h.Equal(facts.vendorPrice, 0, "forced to 0")
        Place("linen", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 2).vendorPrice, 13, "the sell price otherwise")
    end,

    ["Facts: a quest item is read from the slot's quest info"] = function()
        Place("quest", 0, 1, { isQuest = true })
        Place("linen", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 1).isQuest, true, "quest item")
        h.Equal(ItemFacts.FromSlot(0, 2).isQuest, false, "ordinary item")
    end,

    ["Facts: a purchase with refund time left is refundable"] = function()
        Place("helm", 0, 1, { refundSeconds = 3000 })
        Place("helm", 0, 2, { refundSeconds = 0 })
        Place("helm", 0, 3)
        h.Equal(ItemFacts.FromSlot(0, 1).refundable, true, "time left")
        h.Equal(ItemFacts.FromSlot(0, 2).refundable, false, "no time left")
        h.Equal(ItemFacts.FromSlot(0, 3).refundable, false, "not a purchase")
    end,

    ["Facts: the suffix is the seventh field of the link"] = function()
        Place("robe", 0, 1, { link = Link(14138, -5) })
        Place("robe", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 1).suffix, -5, "random suffix")
        h.Equal(ItemFacts.FromSlot(0, 2).suffix, 0, "no suffix")
    end,

    ["Facts: an account bind type or the until-equip call makes it account bound"] = function()
        Place("warbound", 0, 1, { bound = true })
        h.Equal(ItemFacts.FromSlot(0, 1).isAccountBound, true, "bind type 8")
        local fixture = items.robe
        h.Stub.SetItem(fixture.itemID, {
            name = "Robe",
            equipLoc = "INVTYPE_ROBE",
            classID = 4,
            subclassID = 1,
            bindType = 2,
            accountBound = true,
        })
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 2, { itemID = fixture.itemID, link = Link(fixture.itemID) })
        h.Equal(ItemFacts.FromSlot(0, 2).isAccountBound, true, "until-equip call")
        Place("helm", 0, 3, { bound = true })
        h.Equal(ItemFacts.FromSlot(0, 3).isAccountBound, false, "bound to the character")
    end,

    ["Facts: the class restriction is the set of classes of the Classes line"] = function()
        local item = Place("helm", 0, 1)
        h.Stub.SetTooltipLines(item.link, { "Test Helm", "Classes: Warrior, Paladin" })
        h.DeepEqual(
            ItemFacts.FromSlot(0, 1).classRestriction,
            { WARRIOR = true, PALADIN = true },
            "two classes"
        )
        local ring = Place("ring", 0, 2)
        h.Stub.SetTooltipLines(ring.link, { "Test Ring", "Requires Level 58" })
        h.Nil(ItemFacts.FromSlot(0, 2).classRestriction, "names no class")
        local single = Place("robe", 0, 3)
        h.Stub.SetTooltipLines(single.link, { "Classes: Mage" })
        h.DeepEqual(ItemFacts.FromSlot(0, 3).classRestriction, { MAGE = true }, "one class")
    end,

    ["Facts: an unreadable tooltip is tooltipUnread, not pending, and is re-read"] = function()
        local item = Place("helm", 0, 1)
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.tooltipUnread, true, "no tooltip yet")
        h.Equal(facts.pending, false, "not pending")
        h.Nil(facts.classRestriction, "unknown")
        h.Nil(facts.unscoredEffect, "unknown")
        h.Stub.SetTooltipLines(item.link, { "Classes: Warrior" })
        local again = ItemFacts.FromSlot(0, 1)
        h.Equal(again.tooltipUnread, false, "read now")
        h.DeepEqual(again.classRestriction, { WARRIOR = true }, "restriction")
        h.Equal(again.unscoredEffect, false, "effect")
    end,

    ["Facts: a Classes line that resolves no class is unread and not remembered"] = function()
        local item = Place("ring", 0, 1)
        h.Stub.SetTooltipLines(item.link, { "Classes: Nonesuch" })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.tooltipUnread, true, "unread")
        h.Nil(facts.classRestriction, "unknown")
        h.Stub.SetTooltipLines(item.link, { "Classes: Mage" })
        local again = ItemFacts.FromSlot(0, 1)
        h.Equal(again.tooltipUnread, false, "read once it resolves")
        h.DeepEqual(again.classRestriction, { MAGE = true }, "restriction")
    end,

    ["Facts: an unread tooltip on a recipe or a link is flagged too"] = function()
        Place("recipe", 0, 1)
        h.Equal(ItemFacts.FromSlot(0, 1).tooltipUnread, true, "recipe")
        h.Stub.SetItem(items.helm.itemID, items.helm)
        h.Equal(ItemFacts.FromLink(Link(items.helm.itemID)).tooltipUnread, true, "link")
    end,

    ["Facts: a facts table starts with tooltipUnread false for an empty tooltip"] = function()
        local item = Place("linen", 0, 1)
        h.Stub.SetTooltipLines(item.link, { "Linen Cloth" })
        h.Equal(ItemFacts.FromSlot(0, 1).tooltipUnread, false, "readable")
    end,

    ["Facts: the tooltip is read once per item for the class line and the effect"] = function()
        local item = Place("helm", 0, 1)
        h.Stub.SetTooltipLines(item.link, { "Classes: Warrior", "Use: Heals you." })
        local first = ItemFacts.FromSlot(0, 1)
        local calls = h.Stub.TooltipCalls()
        local second = ItemFacts.FromSlot(0, 1)
        h.Equal(h.Stub.TooltipCalls(), calls, "no further tooltip reads")
        h.DeepEqual(second.classRestriction, first.classRestriction, "same restriction")
        h.Equal(second.unscoredEffect, true, "same effect")
    end,

    ["Facts: a secret tooltip line leaves the class restriction unread"] = function()
        local item = Place("helm", 0, 1)
        h.Stub.SetTooltipLines(item.link, { "Test Helm", h.Stub.MakeSecret() })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.tooltipUnread, true, "unread")
        h.Nil(facts.classRestriction, "unknown")
        h.Stub.SetTooltipLines(item.link, { "Test Helm", "Classes: Warrior" })
        local again = ItemFacts.FromSlot(0, 1)
        h.Equal(again.tooltipUnread, false, "read once readable")
        h.DeepEqual(again.classRestriction, { WARRIOR = true }, "restriction")
    end,

    ["Facts: a secret tooltip line leaves unique unknown and not remembered"] = function()
        h.Stub.SetUniquenessApi(false)
        local ring = Place("ring", 0, 1)
        h.Stub.SetTooltipLines(ring.link, { "Test Ring", h.Stub.MakeSecret() })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Nil(facts.unique, "unknown")
        h.Equal(facts.tooltipUnread, true, "unread")
        h.Stub.SetTooltipLines(ring.link, { "Test Ring", "Unique-Equipped" })
        h.Equal(ItemFacts.FromSlot(0, 1).unique, true, "unique once readable")
    end,

    ["Facts: a secret quest flag makes the facts pending and secret"] = function()
        Place("quest", 0, 1, { isQuest = h.Stub.MakeSecret() })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.secret, true, "secret")
        h.Equal(facts.pending, true, "pending")
        h.Equal(facts.isQuest, false, "not reported as a quest item")
    end,

    ["Facts: a secret account-bound result makes the facts pending and secret"] = function()
        local item = Place("robe", 0, 1)
        local fields = {}
        for key, value in pairs(items.robe) do
            fields[key] = value
        end
        fields.accountBound = h.Stub.MakeSecret()
        h.Stub.SetItem(item.itemID, fields)
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.secret, true, "secret")
        h.Equal(facts.pending, true, "pending")
    end,

    ["Facts: unique comes from the uniqueness call"] = function()
        Place("thunderfury", 0, 1)
        Place("dagger", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 1).unique, true, "unique")
        h.Equal(ItemFacts.FromSlot(0, 2).unique, false, "not unique")
    end,

    ["Facts: without the uniqueness call, the Unique tooltip lines say it"] = function()
        h.Stub.SetUniquenessApi(false)
        local ring = Place("ring", 0, 1)
        h.Stub.SetTooltipLines(ring.link, { "Test Ring", "Unique-Equipped" })
        local plain = Place("robe", 0, 2)
        h.Stub.SetTooltipLines(plain.link, { "Test Robe" })
        local both = Place("thunderfury", 0, 3)
        h.Stub.SetTooltipLines(both.link, { "Unique" })
        h.Equal(ItemFacts.FromSlot(0, 1).unique, true, "Unique-Equipped")
        h.Equal(ItemFacts.FromSlot(0, 2).unique, false, "no line")
        h.Equal(ItemFacts.FromSlot(0, 3).unique, true, "Unique")
    end,

    ["Facts: knownHere is read for recipes and books only"] = function()
        local recipe = Place("recipe", 0, 1)
        h.Stub.SetTooltipLines(recipe.link, { "Pattern: Red Linen Bag", "Already known" })
        Place("linen", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 1).knownHere, true, "known recipe")
        h.Nil(ItemFacts.FromSlot(0, 2).knownHere, "not a recipe")
        local other = Place("recipe", 0, 3, { itemID = 2599, link = Link(2599) })
        h.Stub.SetItem(2599, items.recipe)
        h.Stub.SetTooltipLines(other.link, { "Requires Tailoring" })
        h.Equal(ItemFacts.FromSlot(0, 3).knownHere, false, "unknown recipe")
    end,

    ["Facts: unscoredEffect is read for gear only"] = function()
        local weapon = Place("dagger", 0, 1)
        h.Stub.SetTooltipLines(weapon.link, { "Chance on hit: Burns." })
        local plain = Place("robe", 0, 2)
        h.Stub.SetTooltipLines(plain.link, { "Test Robe" })
        local cosmetic = Place("cosmetic", 0, 3)
        h.Stub.SetTooltipLines(cosmetic.link, { "Use: Wear it." })
        local linen = Place("linen", 0, 4)
        h.Stub.SetTooltipLines(linen.link, { "Use: Tailoring." })
        h.Equal(ItemFacts.FromSlot(0, 1).unscoredEffect, true, "weapon with an effect")
        h.Equal(ItemFacts.FromSlot(0, 2).unscoredEffect, false, "robe with none")
        h.Equal(ItemFacts.FromSlot(0, 3).unscoredEffect, false, "cosmetic armour is not gear")
        h.Equal(ItemFacts.FromSlot(0, 4).unscoredEffect, false, "a material is not gear")
    end,

    ["Facts: holding sums the stacks of the container being classified"] = function()
        Place("linen", 0, 1, { count = 20 })
        Place("linen", 1, 2, { count = 15 })
        Place("linen", 5, 1, { count = 7 })
        Place("linen", 6, 1, { count = 40 })
        Place("linen", 14, 2, { count = 9 })
        Place("dagger", 0, 2)
        h.Equal(ItemFacts.FromSlot(0, 1).holding, 42, "bags 0 to 5")
        h.Equal(ItemFacts.FromSlot(1, 2).holding, 42, "same container, another bag")
        h.Equal(ItemFacts.FromSlot(6, 1).holding, 49, "bank tabs 6 to 14")
        h.Equal(ItemFacts.FromSlot(14, 2).holding, 49, "last bank tab")
        h.Equal(ItemFacts.FromSlot(0, 2).holding, 1, "another item")
    end,

    ["Facts: holdings built once serve every slot of the pass"] = function()
        Place("linen", 0, 1, { count = 20 })
        Place("linen", 1, 2, { count = 15 })
        local holdings = ItemFacts.Holdings(0)
        h.DeepEqual(holdings, { [2589] = 35 }, "totals by item ID")
        h.Equal(ItemFacts.FromSlot(0, 1, holdings).holding, 35, "slot 1")
        h.Equal(ItemFacts.FromSlot(1, 2, holdings).holding, 35, "slot 2")
    end,

    ["Facts: a secret stack count is left out of the holding"] = function()
        Place("linen", 0, 1, { count = 20 })
        Place("linen", 1, 2, { count = h.Stub.MakeSecret() })
        h.DeepEqual(ItemFacts.Holdings(0), { [2589] = 20 }, "secret count skipped")
    end,

    ["Facts: a secret value makes the facts pending and secret, with no request"] = function()
        local item = Place("linen", 0, 1, { count = h.Stub.MakeSecret() })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.secret, true, "secret")
        h.Equal(facts.pending, true, "pending")
        h.Equal(h.Stub.ItemRequests(item.itemID), 0, "no item request")
    end,

    ["Facts: a secret value in the item info makes the facts pending and secret"] = function()
        h.Stub.SetItem(2589, {
            classID = 7,
            subclassID = 5,
            sellPrice = h.Stub.MakeSecret(),
        })
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, { itemID = 2589, link = Link(2589) })
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.secret, true, "secret")
        h.Equal(facts.pending, true, "pending")
        h.Nil(facts.vendorPrice, "no price from a secret value")
    end,

    ["Facts: a pending item is requested once and completes after the load event"] = function()
        Boot()
        local fixture = items.robe
        h.Stub.SetItemPending(fixture.itemID, fixture)
        local item = { itemID = fixture.itemID, link = Link(fixture.itemID), quality = 3 }
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, item)
        local facts = ItemFacts.FromSlot(0, 1)
        h.Equal(facts.pending, true, "pending")
        h.Equal(facts.itemID, 14138, "the slot fields are there")
        h.Equal(facts.quality, 3, "quality from the slot")
        h.Equal(facts.equipLoc, "INVTYPE_ROBE", "instant data is there")
        h.Nil(facts.reqLevel, "no item info yet")
        h.Nil(facts.vendorPrice, "no price yet")
        h.Equal(h.Stub.ItemRequests(fixture.itemID), 1, "requested once")
        h.Equal(ItemFacts.FromSlot(0, 1).pending, true, "still pending")
        h.Equal(h.Stub.ItemRequests(fixture.itemID), 1, "not requested again")

        h.Stub.LoadItem(fixture.itemID)
        h.Equal(ItemFacts.FromSlot(0, 1).pending, true, "the batch window is still open")
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        local loaded = ItemFacts.FromSlot(0, 1)
        h.Equal(loaded.pending, false, "complete")
        h.Equal(loaded.reqLevel, 55, "item info read")
        h.Equal(loaded.vendorPrice, 4000, "price read")
        h.Equal(h.Stub.ItemRequests(fixture.itemID), 1, "still one request")
    end,

    ["Facts: the item-data events give one batch line, not one line per event"] = function()
        Boot()
        local ids = {}
        h.Stub.SetBagSize(0, 20)
        for index = 1, 12 do
            local itemID = 30000 + index
            ids[index] = itemID
            h.Stub.SetItemPending(itemID, { name = "Item", classID = 7, subclassID = 0 })
            h.Stub.SetBagItem(0, index, { itemID = itemID, link = Link(itemID) })
            ItemFacts.FromSlot(0, index)
        end
        local reported
        local calls = 0
        ItemFacts.OnLoaded(function(list)
            calls = calls + 1
            reported = list
        end)
        for index = 12, 1, -1 do
            h.Stub.LoadItem(ids[index])
        end
        h.Equal(calls, 0, "nothing before the window ends")
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        h.Equal(CountLines("event: 12 items loaded"), 1, "one batch line")
        h.Equal(CountLines("GET_ITEM_INFO_RECEIVED"), 0, "no per-event line")
        h.Equal(CountLines("ITEM_DATA_LOAD_RESULT"), 0, "no per-event line")
        h.Equal(calls, 1, "one callback for the batch")
        h.DeepEqual(reported, ids, "the sorted IDs of the batch")
        for index = 1, 12 do
            h.Equal(ItemFacts.FromSlot(0, index).pending, false, "item " .. index .. " complete")
        end
    end,

    ["Facts: one item loading gives the singular line"] = function()
        Boot()
        h.Stub.SetItemPending(31000, { name = "Item" })
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, { itemID = 31000, link = Link(31000) })
        ItemFacts.FromSlot(0, 1)
        h.Stub.LoadItem(31000)
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        h.Equal(CountLines("event: 1 item loaded"), 1, "singular line")
    end,

    ["Facts: events in separate windows give separate batches"] = function()
        Boot()
        h.Stub.SetBagSize(0, 4)
        for index = 1, 2 do
            h.Stub.SetItemPending(32000 + index, { name = "Item" })
            h.Stub.SetBagItem(0, index, { itemID = 32000 + index, link = Link(32000 + index) })
            ItemFacts.FromSlot(0, index)
        end
        h.Stub.LoadItem(32001)
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        h.Stub.LoadItem(32002)
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        h.Equal(CountLines("event: 1 item loaded"), 2, "two lines")
    end,

    ["Facts: an item-data event for an item nobody requested does nothing"] = function()
        Boot()
        local calls = 0
        ItemFacts.OnLoaded(function()
            calls = calls + 1
        end)
        h.Stub.LoadItem(99999)
        h.Stub.Advance(10)
        h.Equal(calls, 0, "no callback")
        h.Equal(CountLines("loaded"), 0, "no line")
    end,

    ["Facts: an event reporting a failed load leaves the item pending"] = function()
        Boot()
        h.Stub.SetItemPending(33000, { name = "Item" })
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, { itemID = 33000, link = Link(33000) })
        ItemFacts.FromSlot(0, 1)
        h.Stub.FireEvent("ITEM_DATA_LOAD_RESULT", 33000, false)
        h.Stub.Advance(10)
        h.Equal(ItemFacts.FromSlot(0, 1).pending, true, "still pending")
        h.Equal(CountLines("loaded"), 0, "no line")
    end,

    ["Facts: two slots of one pending item make one request"] = function()
        h.Stub.SetItemPending(34000, { name = "Item" })
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, { itemID = 34000, link = Link(34000) })
        h.Stub.SetBagItem(0, 2, { itemID = 34000, link = Link(34000) })
        ItemFacts.FromSlot(0, 1)
        ItemFacts.FromSlot(0, 2)
        h.Equal(h.Stub.ItemRequests(34000), 1, "one request")
    end,

    ["Facts: a link has no bound state, stack count or holding"] = function()
        local fixture = items.helm
        h.Stub.SetItem(fixture.itemID, fixture)
        local link = Link(fixture.itemID)
        h.Stub.SetTooltipLines(link, { "Test Helm", "Classes: Warrior" })
        local facts = ItemFacts.FromLink(link)
        h.DeepEqual(facts, {
            itemID = 16680,
            link = link,
            suffix = 0,
            stack = 1,
            quality = 4,
            bound = false,
            isAccountBound = false,
            classID = 4,
            subclassID = 4,
            equipLoc = "INVTYPE_HEAD",
            bindType = 1,
            reqLevel = 60,
            isQuest = false,
            hasNoValue = false,
            classRestriction = { WARRIOR = true },
            unique = false,
            vendorPrice = 9000,
            itemLevel = 76,
            unscoredEffect = false,
            holding = 1,
            refundable = false,
            linkOnly = true,
            pending = false,
            secret = false,
            tooltipUnread = false,
        }, "the facts of the helm")
    end,

    ["Facts: a link with a random suffix gives its suffix"] = function()
        h.Stub.SetItem(14138, items.robe)
        h.Equal(ItemFacts.FromLink(Link(14138, -7)).suffix, -7, "suffix")
    end,

    ["Facts: text that holds no item has no facts"] = function()
        h.Nil(ItemFacts.FromLink("not a link"), "no item")
    end,

    ["Facts: a link to an unloaded item is pending and completes after the load event"] = function()
        Boot()
        local fixture = items.robe
        h.Stub.SetItemPending(fixture.itemID, fixture)
        local link = Link(fixture.itemID)
        h.Equal(ItemFacts.FromLink(link).pending, true, "pending")
        h.Equal(ItemFacts.FromLink(link).pending, true, "still pending")
        h.Equal(h.Stub.ItemRequests(fixture.itemID), 1, "requested once")
        h.Stub.LoadItem(fixture.itemID)
        h.Stub.Advance(ItemFacts.BATCH_SECONDS)
        local facts = ItemFacts.FromLink(link)
        h.Equal(facts.pending, false, "complete")
        h.Equal(facts.quality, 3, "quality from the item info")
    end,
}
