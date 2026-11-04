local _, ns, h = ...

local Classify = ns.Classify
local Generations = ns.Generations
local Roster = ns.Roster

local fixture = h.Fixture("scoring")

local HERE = "Zugar Soulsour-Region"
local BONESET = "Boneset Hallowine-Region"
local CHAM = "Chamoomile Rejuvenade-Region"

local AGI = "ITEM_MOD_AGILITY_SHORT"
local STA = "ITEM_MOD_STAMINA_SHORT"
local INT = "ITEM_MOD_INTELLECT_SHORT"

local nextID = 97000

-- The test weights: Bear weighs AGI 1 and STA 2; Cat (fixture) AGI 2;
-- Restoration (fixture) INT 2 and HEAL 1. A ring or a neck needs no
-- proficiency, so the cases use them. The item level fallback is off unless a
-- case turns it on, so an item without a weighted stat has score 0.
local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    for spec, weights in pairs(fixture.weights) do
        ns.WeightTables[spec] = weights
    end
    ns.WeightTables["DRUID:bear"] = { weights = { AGI = 1, STA = 2 }, percent = {} }
    h.Stub.SetPlayer({ level = 60 })
    h.Stub.SetKnownSpells({ 9077 })
    local here = LootLogicDB.characters[HERE]
    here.class = "DRUID"
    here.level = 60
    here.loadouts = {
        { name = "Bear", spec = "DRUID:bear", worn = true },
        { name = "Cat", spec = "DRUID:cat" },
    }
    here.gear = { slots = {} }
    here.bags = { gear = {} }
    local function Add(key, first, last)
        LootLogicDB.characters[key] = {
            first = first,
            last = last,
            class = "DRUID",
            level = 60,
            faction = here.faction,
            region = here.region,
            loadouts = { { name = "Cat", spec = "DRUID:cat", worn = true } },
            bags = { gear = {} },
        }
    end
    Add(BONESET, "Boneset", "Hallowine")
    Add(CHAM, "Chamoomile", "Rejuvenade")
    LootLogicDB.order = { BONESET, CHAM, HERE }
    LootLogicDB.settings.gear.itemLevelFallback = false
    LootLogicDB.settings.gear.lookAheadLevels = 5
    Generations.Bump("roster")
    return here
end

local function Define(fields)
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        name = "Item " .. nextID,
        link = "item:" .. nextID,
        quality = 2,
        itemLevel = 20,
        reqLevel = 1,
        sellPrice = 10,
        bindType = 0,
        equipLoc = "INVTYPE_FINGER",
        classID = 4,
        subclassID = 0,
        stats = {},
    }
    for key, value in pairs(fields or {}) do
        item[key] = value
    end
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

local function Ring(stat, value, fields)
    local item = { stats = { [stat] = value } }
    for key, extra in pairs(fields or {}) do
        item[key] = extra
    end
    return Define(item)
end

-- The next free slot of bag 0.
local nextSlot = 0

-- An item in a bag slot of here, and in the snapshot of the bags; returns the
-- item and its slot.
local function Carry(item, slotFields)
    nextSlot = nextSlot + 1
    local placed = { itemID = item.itemID, link = item.link, count = 1, quality = item.quality }
    for key, value in pairs(slotFields or {}) do
        placed[key] = value
    end
    h.Stub.SetBagSize(0, 40)
    h.Stub.SetBagItem(0, nextSlot, placed)
    local gear = LootLogicDB.characters[HERE].bags.gear
    gear[#gear + 1] = item.link
    Generations.Bump("gearHere")
    return item, nextSlot
end

-- Worn by here, in an equipment slot.
local function Wear(item, slot)
    LootLogicDB.characters[HERE].gear.slots[slot] = item.link
    Generations.Bump("gearHere")
end

-- Held in the bags of another character (a snapshot only).
local function Stow(key, item)
    local gear = LootLogicDB.characters[key].bags.gear
    gear[#gear + 1] = item.link
    Generations.Bump("gearOthers")
end

-- Two worn rings that nothing in these cases beats under Bear (score 100 each).
local function StrongRings()
    Wear(Ring(STA, 50), 11)
    Wear(Ring(STA, 50), 12)
end

local function Want(key, types, items)
    LootLogicDB.characters[key].asks = { types = types or {}, items = items or {} }
    Generations.Bump("asks")
end

local function Provider(price)
    ns.Prices.Register({
        id = "fake",
        label = "Fake",
        IsAvailable = function()
            return true
        end,
        GetPrice = function()
            return price
        end,
        OnUpdate = function() end,
    })
end

local function Expect(result, category, code, linkOnly, label)
    h.True(result ~= nil, label .. ": has a result")
    h.Equal(result.category, category, label .. ": category")
    h.Equal(result.reasonCode, code, label .. ": reason")
    h.Equal(result.linkOnly, linkOnly, label .. ": linkOnly")
end

local function SlotResult(slot)
    return Classify.BagSlot(0, slot)
end

-- Counts the slots a pass reads: Classify reads facts through
-- ItemFacts.FromSlot once per non-cached look at a slot.
local reads = 0

local function FromSlotCalls()
    return reads
end

local function CountReads()
    local original = ns.ItemFacts.FromSlot
    reads = 0
    ns.ItemFacts.FromSlot = function(...)
        reads = reads + 1
        return original(...)
    end
end

-- Fills bag 0 with count different cheap non-gear items, and starts counting
-- the slot reads.
local function FillBags(count)
    h.Stub.SetBagSize(0, count)
    for slot = 1, count do
        local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
        h.Stub.SetBagItem(0, slot, { itemID = item.itemID, link = item.link, count = 1 })
    end
    CountReads()
end

local function DebugText()
    return table.concat(LootLogicDB.debug.log or {}, "\n")
end

-- How many times the plain text occurs.
local function Count(text, part)
    local count = 0
    local from = 1
    while true do
        local found = string.find(text, part, from, true)
        if not found then
            return count
        end
        count = count + 1
        from = found + 1
    end
end

return {
    -- Step 3a
    ["ClassifyB: a ring for an empty slot is Equip with an infinite gain (3a)"] = function()
        Boot()
        local _, slot = Carry(Ring(AGI, 10))
        local result = SlotResult(slot)
        Expect(result, "equip", "equip", false, "empty slots")
        h.Equal(result.reasonData.gear.loadout, "Bear", "the worn loadout")
        h.Equal(result.reasonData.gear.gainPct, math.huge, "infinite gain")
        h.Equal(result.reasonData.gear.baseline, 0, "baseline 0")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEmptySlot, "Bear", ns.L.slotFinger),
            "text"
        )
    end,

    ["ClassifyB: empty-slot gear adds ilvl, training and effect suffixes"] = function()
        Boot()
        local item = Ring(AGI, 10)
        h.Stub.SetTooltipLines(item.link, { "Use: Restores health." })
        local _, slot = Carry(item)
        ns.Scoring.Compare = function(_, _, options)
            return {
                upgrade = true,
                baseline = 0,
                gainPct = math.huge,
                itemLevel = true,
                group = "finger",
                train = { 674 },
                loadout = options.loadout,
            }
        end
        local result = SlotResult(slot)
        Expect(result, "equip", "equip", false, "empty slot")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEmptySlot, "Bear", ns.L.slotFinger)
                .. ns.L.reasonIlvl
                .. string.format(ns.L.reasonTrain, ns.L.skillDualWield)
                .. ns.L.reasonEffect,
            "gear suffixes"
        )
    end,

    ["ClassifyB: pair baseline names both items and their locations"] = function()
        Boot()
        local main = Ring(AGI, 10, { name = "Blade" })
        local off = Ring(AGI, 5, { name = "Buckler" })
        local _, slot = Carry(Ring(AGI, 20))
        ns.Scoring.Compare = function(_, _, options)
            return {
                upgrade = true,
                baseline = 15,
                gainPct = 3.56,
                group = "twoHand",
                baselinePair = { { item = main, where = "worn" }, { item = off, where = "bags" } },
                loadout = options.loadout,
            }
        end
        local result = SlotResult(slot)
        local pair = string.format(
            ns.L.reasonPairLocated,
            string.format(ns.L.reasonItemLocation, "Blade", ns.L.reasonWhereWorn),
            string.format(ns.L.reasonItemLocation, "Buckler", ns.L.reasonWhereBags)
        )
        h.Equal(result.reasonText, string.format(ns.L.reasonEquip, "3.6", "Bear", pair), "pair")
    end,

    ["ClassifyB: judged hand is named only for a weapon compared in both hands"] = function()
        Boot()
        local baseline = Ring(AGI, 10, { name = "Old" })
        local _, slot = Carry(Ring(AGI, 20))
        local hand = "mainHand"
        ns.Scoring.Compare = function(_, _, options)
            return {
                upgrade = true,
                baseline = 10,
                baselineItem = baseline,
                baselineWhere = "bank",
                gainPct = 4,
                group = hand,
                judgedBoth = true,
                loadout = options.loadout,
            }
        end
        local prefix = string.format(
            ns.L.reasonEquip,
            "4",
            "Bear",
            string.format(ns.L.reasonItemLocation, "Old", ns.L.reasonWhereBank)
        )
        h.Equal(SlotResult(slot).reasonText, prefix .. ns.L.reasonMainHand, "main hand")
        hand = "offHand"
        Generations.Bump("gearHere")
        h.Equal(SlotResult(slot).reasonText, prefix .. ns.L.reasonOffHand, "off hand")
    end,

    ["ClassifyB: other character pair baseline omits locations"] = function()
        Boot()
        Roster.SetReceivesGear(CHAM, false)
        local main = Ring(AGI, 10, { name = "Blade" })
        local off = Ring(AGI, 5, { name = "Buckler" })
        local _, slot = Carry(Ring(AGI, 20))
        ns.Scoring.Compare = function(_, key, options)
            if key == HERE then
                return nil
            end
            return {
                upgrade = true,
                baseline = 15,
                gainPct = 4.04,
                group = "twoHand",
                baselinePair = { { item = main, where = "bank" }, { item = off, where = "inbox" } },
                loadout = options.loadout,
            }
        end
        ns.Scoring.InUse = function()
            return { inUse = false }
        end
        local result = SlotResult(slot)
        Expect(result, "char:" .. BONESET, "gearfor", false, "other pair")
        h.Equal(
            result.reasonText,
            string.format(
                ns.L.reasonGearfor,
                "4",
                "Cat",
                string.format(ns.L.reasonPair, "Blade", "Buckler")
            ),
            "pair and trailing zero"
        )
    end,

    ["ClassifyB: an empty second ring slot counts as 0 (3a)"] = function()
        Boot()
        Wear(Ring(AGI, 50), 11)
        local _, slot = Carry(Ring(AGI, 5))
        local result = SlotResult(slot)
        Expect(result, "equip", "equip", false, "second slot empty")
        h.Equal(result.reasonData.gear.baseline, 0, "weaker of the best two")
    end,

    ["ClassifyB: a ring that beats the weaker worn ring by the minimum is Equip (3a)"] = function()
        Boot()
        local baseline = Ring(AGI, 10)
        Wear(baseline, 11)
        Wear(Ring(AGI, 20), 12)
        local _, slot = Carry(Ring(AGI, 30))
        local result = SlotResult(slot)
        Expect(result, "equip", "equip", false, "upgrade")
        h.Equal(result.reasonData.gear.baseline, 10, "weaker of the best two")
        h.Equal(result.reasonData.gear.candidate, 30, "candidate score")
        h.Equal(result.reasonData.gear.gainPct, 200, "gain")
        h.Equal(result.reasonData.gear.assumed, false, "spec not assumed")
        h.Equal(
            result.reasonText,
            string.format(
                ns.L.reasonEquip,
                "200",
                "Bear",
                string.format(ns.L.reasonItemLocation, baseline.name, ns.L.reasonWhereWorn)
            ),
            "whole percentage and worn baseline"
        )
    end,

    ["ClassifyB: a candidate below the minimum upgrade stays in use (3a then 3c)"] = function()
        Boot()
        Wear(Ring(AGI, 10), 11)
        Wear(Ring(AGI, 20), 12)
        local _, slot = Carry(Ring(AGI, 10.05))
        local result = SlotResult(slot)
        Expect(result, "none", "inuse", false, "0.5% is under minUpgradePct 1")
        h.Equal(result.reasonData.loadout, "Bear", "names the loadout")
    end,

    ["ClassifyB: fractional gains round for display without changing ranking"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        Wear(Ring(STA, 1000), 11)
        Wear(Ring(STA, 1000), 12)
        local first = Ring(AGI, 100, { name = "First" })
        Stow(BONESET, first)
        Stow(BONESET, Ring(AGI, 100, { name = "First" }))
        Stow(CHAM, Ring(AGI, 100.04))
        Stow(CHAM, Ring(AGI, 100.04))
        local _, slot = Carry(Ring(AGI, 103.56))
        local result = SlotResult(slot)
        Expect(result, "char:" .. BONESET, "gearfor", false, "unrounded gain wins")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonGearfor, "3.6", "Cat", "First")
                .. string.format(ns.L.reasonRunner, "Chamoomile", "3.5"),
            "one decimal for winner and runner"
        )
    end,

    ["ClassifyB: an upgrade only for a stowed loadout is in use, not Equip (skips 3a)"] = function()
        local here = Boot()
        here.loadouts[2].assumed = true
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10))
        local result = SlotResult(slot)
        Expect(result, "none", "inuse", false, "Cat only")
        h.Equal(result.reasonData.loadout, "Cat", "the stowed loadout")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonInuse, "Cat" .. ns.L.reasonAssumed, ns.L.slotFinger),
            "assumed in-use text"
        )
    end,

    ["ClassifyB: in-use gear reports an unscored effect"] = function()
        Boot()
        StrongRings()
        local item = Ring(AGI, 10)
        h.Stub.SetTooltipLines(item.link, { "Use: Restores health." })
        local _, slot = Carry(item)
        local result = SlotResult(slot)
        Expect(result, "none", "inuse", false, "stowed loadout")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonInuse, "Cat", ns.L.slotFinger) .. ns.L.reasonEffect,
            "unscored effect suffix"
        )
    end,

    ["ClassifyB: in-use gear reports the training it needs"] = function()
        Boot()
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10))
        ns.Scoring.InUse = function()
            return {
                inUse = true,
                loadout = { name = "Cat" },
                train = { 674 },
            }
        end
        local result = SlotResult(slot)
        Expect(result, "none", "inuse", false, "stowed loadout")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonInuse, "Cat", ns.L.slotFinger)
                .. string.format(ns.L.reasonTrain, ns.L.skillDualWield),
            "train suffix"
        )
    end,

    ["ClassifyB: an item-level fallback look-ahead upgrade carries the ilvl marker"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.settings.gear.itemLevelFallback = true
        local item = Ring(STA, 0, { reqLevel = 22, stats = {} })
        local result = Classify.Link(item.link)
        Expect(result, "none", "equipat", true, "fallback look-ahead")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEquipat, 22) .. ns.L.reasonIlvl .. ns.L.reasonNotInBags,
            "ilvl after the level"
        )
    end,

    ["ClassifyB: a sale of gear with an unscored effect keeps the warning"] = function()
        Boot()
        local item = Ring(INT, 10)
        h.Stub.SetTooltipLines(item.link, { "Use: Restores health." })
        local _, slot = Carry(item, { bound = true })
        local result = SlotResult(slot)
        Expect(result, "vendor", "vendorbound", false, "bound and not wanted")
        h.Equal(result.reasonData.unscoredEffect, true, "carried into the data")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonVendorbound, ns.Util.FormatMoney(item.sellPrice))
                .. ns.L.reasonEffect,
            "effect suffix on a sale"
        )
    end,

    ["ClassifyB: a replaced piece reaches the other characters (3c then 3b)"] = function()
        Boot()
        StrongRings()
        local _, first = Carry(Ring(AGI, 20))
        local _, second = Carry(Ring(AGI, 15))
        local _, third = Carry(Ring(AGI, 5))
        Expect(SlotResult(first), "none", "inuse", false, "best Cat ring")
        Expect(SlotResult(second), "none", "inuse", false, "second best Cat ring")
        local result = SlotResult(third)
        Expect(result, "char:" .. BONESET, "gearfor", false, "no longer wins for any loadout")
        h.Equal(result.reasonData.better.item.link ~= nil, true, "names a better piece")
    end,

    ["ClassifyB: better-piece suffix names every location"] = function()
        Boot()
        StrongRings()
        local _, slot = Carry(Ring(AGI, 1), { bound = true })
        local where = "worn"
        ns.Scoring.InUse = function()
            return { better = { loadout = { name = "Cat" }, group = "finger", where = where } }
        end
        for _, entry in ipairs({
            { "worn", ns.L.reasonWhereWorn },
            { "bags", ns.L.reasonBetterBags },
            { "bank", ns.L.reasonBetterBank },
            { "inbox", ns.L.reasonBetterMail },
            { "inbound", ns.L.reasonBetterMail },
        }) do
            where = entry[1]
            Generations.Bump("gearHere")
            local result = SlotResult(slot)
            h.Equal(
                result.reasonText,
                string.format(ns.L.reasonVendorbound, ns.Util.FormatMoney(10))
                    .. string.format(ns.L.reasonBetter, "Cat", ns.L.slotFinger, entry[2]),
                where
            )
        end
    end,

    -- Look-ahead
    ["ClassifyB: a look-ahead upgrade stops at equipat when here wins (3a)"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        Want(CHAM, { ["4:*"] = {} })
        local _, slot = Carry(Ring(AGI, 30, { reqLevel = 22 }))
        local result = SlotResult(slot)
        Expect(result, "none", "equipat", false, "look-ahead")
        h.Equal(result.reasonData.atLevel, 22, "level")
        h.Equal(result.reasonData.gear.loadout, "Bear", "loadout")
        h.Equal(result.reasonText, string.format(ns.L.reasonEquipat, 22), "worn loadout omitted")
    end,

    ["ClassifyB: equipat names an assumed stowed loadout"] = function()
        local here = Boot()
        h.Stub.SetPlayer({ level = 20 })
        here.level = 20
        here.loadouts[2].assumed = true
        StrongRings()
        local _, slot = Carry(Ring(AGI, 30, { reqLevel = 22 }))
        local result = SlotResult(slot)
        Expect(result, "none", "equipat", false, "look-ahead")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEquipat, 22)
                .. string.format(ns.L.reasonLoadout, "Cat" .. ns.L.reasonAssumed),
            "assumed stowed loadout"
        )
    end,

    ["ClassifyB: with the priority off an owned future winner stays in use (3c)"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.settings.gear.hereWinsInLookAhead = false
        Generations.Bump("settings")
        local _, slot = Carry(Ring(AGI, 30, { reqLevel = 22 }))
        Expect(SlotResult(slot), "none", "inuse", false, "owned future winner")
    end,

    ["ClassifyB: a link-only look-ahead item goes to others, else equipat"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        local item = Ring(AGI, 30, { reqLevel = 22 })
        Expect(Classify.Link(item.link), "none", "equipat", true, "setting on")
        LootLogicDB.settings.gear.hereWinsInLookAhead = false
        Generations.Bump("settings")
        Expect(Classify.Link(item.link), "char:" .. BONESET, "gearfor", true, "setting off")
        Roster.SetReceivesGear(BONESET, false)
        Roster.SetReceivesGear(CHAM, false)
        Expect(Classify.Link(item.link), "none", "equipat", true, "nobody else wins")
    end,

    ["ClassifyB: future gear destination names its required level"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.characters[BONESET].level = 20
        Roster.SetReceivesGear(CHAM, false)
        LootLogicDB.settings.gear.hereWinsInLookAhead = false
        local item = Ring(AGI, 30, { reqLevel = 22 })
        local result = Classify.Link(item.link)
        Expect(result, "char:" .. BONESET, "gearfor", true, "future destination")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEmptySlot, "Cat", ns.L.slotFinger)
                .. string.format(ns.L.reasonAtLevel, 22)
                .. ns.L.reasonNotInBags,
            "required level text"
        )
    end,

    ["ClassifyB: owned progression winners stay in use, an inferior piece is routed"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.settings.gear.lookAheadLevels = 3
        LootLogicDB.settings.gear.hereWinsInLookAhead = false
        Generations.Bump("settings")
        local function Neck(value, level)
            return Ring(AGI, value, { equipLoc = "INVTYPE_NECK", reqLevel = level })
        end
        Wear(Neck(5, 10), 2)
        local _, level21 = Carry(Neck(10, 21))
        local _, level22 = Carry(Neck(15, 22))
        local _, level23 = Carry(Neck(20, 23))
        local _, inferior = Carry(Neck(12, 22))
        Expect(SlotResult(level21), "none", "inuse", false, "level 21 winner")
        h.Equal(
            SlotResult(level21).reasonText,
            string.format(ns.L.reasonInuse, "Bear", ns.L.slotNeck),
            "intermediate winner text"
        )
        Expect(SlotResult(level22), "none", "inuse", false, "level 22 winner")
        Expect(SlotResult(level23), "none", "inuse", false, "level 23 winner")
        Expect(
            SlotResult(inferior),
            "char:" .. BONESET,
            "gearfor",
            false,
            "inferior same-level piece"
        )
        -- A narrower window removes the winners beyond it.
        LootLogicDB.settings.gear.lookAheadLevels = 1
        Generations.Bump("settings")
        Expect(SlotResult(level21), "none", "inuse", false, "window keeps level 21")
        Expect(
            SlotResult(level22),
            "char:" .. BONESET,
            "gearfor",
            false,
            "level 22 left the window"
        )
        Expect(
            SlotResult(level23),
            "char:" .. BONESET,
            "gearfor",
            false,
            "level 23 left the window"
        )
        -- A level-up moves the window.
        LootLogicDB.settings.gear.lookAheadLevels = 3
        h.Stub.SetPlayer({ level = 22 })
        LootLogicDB.characters[HERE].level = 22
        Generations.Bump("gearHere")
        Generations.Bump("settings")
        Expect(SlotResult(level22), "equip", "equip", false, "now usable and better than level 21")
        Expect(
            SlotResult(level21),
            "char:" .. BONESET,
            "gearfor",
            false,
            "old winner after the level-up"
        )
    end,

    -- Step 3b
    ["ClassifyB: the larger gain wins and the runner-up is named (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local baseline = Ring(AGI, 5)
        Stow(BONESET, baseline)
        Stow(BONESET, Ring(AGI, 5, { name = baseline.name }))
        Stow(CHAM, Ring(AGI, 8))
        Stow(CHAM, Ring(AGI, 8))
        LootLogicDB.order = { CHAM, BONESET, HERE }
        Generations.Bump("roster")
        local _, slot = Carry(Ring(AGI, 10))
        local result = SlotResult(slot)
        Expect(result, "char:" .. BONESET, "gearfor", false, "100% beats 25%")
        h.Equal(result.reasonData.gear.gainPct, 100, "winner gain")
        h.Equal(#result.reasonData.runnerUps, 1, "one runner-up")
        h.Equal(result.reasonData.runnerUps[1].key, CHAM, "runner-up")
        h.Equal(result.reasonData.runnerUps[1].gainPct, 25, "runner-up gain")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonGearfor, "100", "Cat", baseline.name)
                .. string.format(ns.L.reasonRunner, "Chamoomile", "25"),
            "winner and runner text"
        )
    end,

    ["ClassifyB: equal gains fall to the character order, never the name (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10))
        Expect(SlotResult(slot), "char:" .. BONESET, "gearfor", false, "order Boneset first")
        LootLogicDB.order = { CHAM, BONESET, HERE }
        Generations.Bump("roster")
        Expect(SlotResult(slot), "char:" .. CHAM, "gearfor", false, "order Chamoomile first")
    end,

    ["ClassifyB: an empty slot beats any finite gain (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        Stow(BONESET, Ring(AGI, 1))
        Stow(BONESET, Ring(AGI, 1))
        local _, slot = Carry(Ring(AGI, 10))
        local result = SlotResult(slot)
        Expect(result, "char:" .. CHAM, "gearfor", false, "Chamoomile has empty slots")
        h.Equal(result.reasonData.gear.gainPct, math.huge, "infinite")
        h.Equal(result.reasonData.runnerUps[1].key, BONESET, "the finite gain is the runner-up")
    end,

    ["ClassifyB: empty gear destinations name the runner-up slot"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10))
        local result = SlotResult(slot)
        Expect(result, "char:" .. BONESET, "gearfor", false, "first empty destination")
        h.Equal(
            result.reasonText,
            string.format(ns.L.reasonEmptySlot, "Cat", ns.L.slotFinger)
                .. string.format(ns.L.reasonRunnerEmpty, "Chamoomile", ns.L.slotFinger),
            "empty winner and runner-up"
        )
    end,

    ["ClassifyB: a character with Receives gear off is skipped (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        Roster.SetReceivesGear(BONESET, false)
        local _, slot = Carry(Ring(AGI, 10))
        Expect(SlotResult(slot), "char:" .. CHAM, "gearfor", false, "Boneset skipped")
    end,

    ["ClassifyB: a character's gain is its best over its loadouts (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local boneset = LootLogicDB.characters[BONESET]
        boneset.loadouts = {
            { name = "Cat", spec = "DRUID:cat", worn = true },
            { name = "Restoration", spec = "DRUID:restoration", armor = "any" },
        }
        Roster.SetReceivesGear(CHAM, false)
        Stow(BONESET, Ring(AGI, 5, { stats = { [AGI] = 5, [INT] = 10 } }))
        Stow(BONESET, Ring(AGI, 5, { stats = { [AGI] = 5, [INT] = 10 } }))
        local candidate = Ring(AGI, 10, { stats = { [AGI] = 10, [INT] = 30 } })
        local _, slot = Carry(candidate)
        local result = SlotResult(slot)
        Expect(result, "char:" .. BONESET, "gearfor", false, "best loadout")
        h.Equal(result.reasonData.gear.loadout, "Restoration", "Restoration 200% over Cat 100%")
        h.Equal(result.reasonData.gear.gainPct, 200, "gain")
    end,

    ["ClassifyB: a unique item another character owns is not routed there (3b)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        Roster.SetReceivesGear(CHAM, false)
        local candidate = Ring(AGI, 10, { unique = true })
        Stow(BONESET, candidate)
        local _, slot = Carry(candidate)
        local result = SlotResult(slot)
        h.True(result.category ~= "char:" .. BONESET, "not routed: " .. result.category)
    end,

    ["ClassifyB: soulbound gear is never routed and is not an upgrade for here"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10), { bound = true })
        local result = SlotResult(slot)
        Expect(result, "vendor", "vendorbound", false, "bound gear goes to the vendor")
    end,

    ["ClassifyB: a soulbound upgrade for here is still Equip"] = function()
        Boot()
        local _, slot = Carry(Ring(AGI, 10), { bound = true })
        Expect(SlotResult(slot), "equip", "equip", false, "bound upgrade")
    end,

    ["ClassifyB: an imported-set member stays before the gear step (1c before 3a)"] = function()
        local here = Boot()
        local item, slot = Carry(Ring(AGI, 10))
        here.importedSets = {
            ["equipmentset:Cat"] = {
                source = "equipmentset",
                name = "Cat",
                items = { { id = item.itemID, suffix = 0 } },
            },
        }
        Generations.Bump("loadouts")
        Expect(SlotResult(slot), "none", "inset", false, "set member")
    end,

    ["ClassifyB: gear nobody can use reaches the wants and the sell rules (3d)"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        Want(CHAM, { ["4:*"] = {} })
        local plate = Define({ equipLoc = "INVTYPE_CHEST", subclassID = 4 })
        local _, slot = Carry(plate)
        Expect(SlotResult(slot), "char:" .. CHAM, "wanted", false, "wanted plate")
        LootLogicDB.characters[CHAM].asks = nil
        Generations.Bump("asks")
        Provider({ unit = 1, ageDays = 0 })
        Expect(SlotResult(slot), "vendor", "vendor", false, "sold")
    end,

    -- Step 3-0: nospec
    ["ClassifyB: a Mage with spec nil keeps its gear, nil and unsupported alike (3-0)"] = function()
        local here = Boot()
        here.class = "MAGE"
        here.loadouts = { { name = "Mage", worn = true } }
        Want(BONESET, { ["4:*"] = {} })
        local _, slot = Carry(Ring(AGI, 10))
        Expect(SlotResult(slot), "none", "nospec", false, "spec nil")
        h.Equal(
            SlotResult(slot).reasonText,
            string.format(ns.L.reasonNospec, UnitClass("player")),
            "nil text"
        )
        h.DeepEqual(here.loadouts, { { name = "Mage", worn = true } }, "saved loadout unchanged")
        here.loadouts = { { name = "Future", spec = "MAGE:future", worn = true } }
        Generations.Bump("loadouts")
        Expect(SlotResult(slot), "none", "nospec", false, "unsupported spec")
        h.Equal(
            SlotResult(slot).reasonText,
            string.format(ns.L.reasonNospec, UnitClass("player")),
            "unsupported text"
        )
        h.DeepEqual(
            here.loadouts,
            { { name = "Future", spec = "MAGE:future", worn = true } },
            "saved spec unchanged"
        )
    end,

    ["ClassifyB: one unscored loadout among scored ones still gives nospec (3-0)"] = function()
        local here = Boot()
        local _, slot = Carry(Ring(AGI, 10))
        Expect(SlotResult(slot), "equip", "equip", false, "all scored")
        here.loadouts[3] = { name = "Future", spec = "DRUID:future" }
        Generations.Bump("loadouts")
        Expect(SlotResult(slot), "none", "nospec", false, "unsupported next to scored")
        here.loadouts[3] = { name = "Unset" }
        Generations.Bump("loadouts")
        Expect(SlotResult(slot), "none", "nospec", false, "nil next to scored")
        h.Equal(#here.loadouts, 3, "loadouts kept")
        h.Equal(here.loadouts[3].spec, nil, "saved spec still nil")
        here.loadouts[3] = nil
        Generations.Bump("loadouts")
        Expect(SlotResult(slot), "equip", "equip", false, "scored again")
    end,

    ["ClassifyB: nospec leaves non-gear items alone (3-0 is for gear)"] = function()
        local here = Boot()
        here.loadouts = { { name = "Unset", worn = true } }
        Want(BONESET, { ["7:5"] = {} })
        local linen = Define({ equipLoc = false, classID = 7, subclassID = 5 })
        local _, slot = Carry(linen)
        Expect(SlotResult(slot), "char:" .. BONESET, "wanted", false, "a want still routes")
    end,

    ["ClassifyB: nospec for a bank piece too, and a bound piece"] = function()
        local here = Boot()
        here.loadouts = { { name = "Unset", worn = true } }
        local item = Ring(AGI, 10)
        h.Stub.SetBagSize(6, 4)
        h.Stub.SetBagItem(6, 1, { itemID = item.itemID, link = item.link, count = 1, bound = true })
        here.bank = { gear = { item.link } }
        h.Stub.OpenBank()
        Expect(Classify.BagSlot(6, 1), "none", "nospec", false, "bank piece")
    end,

    ["ClassifyB: a link-only item reaches a scored character, no spec here"] = function()
        local here = Boot()
        here.loadouts = { { name = "Future", spec = "DRUID:future", worn = true } }
        local item = Ring(AGI, 10)
        local result = Classify.Link(item.link)
        Expect(result, "char:" .. BONESET, "gearfor", true, "skips 3a, runs 3b")
        h.Equal(here.loadouts[1].spec, "DRUID:future", "saved spec unchanged")
    end,

    ["ClassifyB: a link-only item skips 3a when here mixes loadouts"] = function()
        local here = Boot()
        here.loadouts[3] = { name = "Unset" }
        Generations.Bump("loadouts")
        -- Here would Equip it with every loadout scored; 3a is skipped.
        local item = Ring(AGI, 10)
        Expect(Classify.Link(item.link), "char:" .. BONESET, "gearfor", true, "3a skipped")
    end,

    ["ClassifyB: a character with no scored loadout is never a destination (8.5)"] = function()
        local here = Boot()
        here.loadouts = { { name = "Unset", worn = true } }
        LootLogicDB.characters[BONESET].loadouts = { { name = "Cat" } }
        LootLogicDB.characters[CHAM].loadouts = {
            { name = "Future", spec = "DRUID:future", worn = true },
        }
        Generations.Bump("loadouts")
        local item = Ring(AGI, 10)
        Expect(Classify.Link(item.link), "none", "nobody", true, "nobody can use it")
        local _, slot = Carry(item)
        Expect(SlotResult(slot), "none", "nospec", false, "and in the bags")
    end,

    -- Link-only
    ["ClassifyB: link-only results use the allowed codes (7.5)"] = function()
        local here = Boot()
        StrongRings()
        local equip = Ring(AGI, 200)
        Expect(Classify.Link(equip.link), "equip", "equip", true, "equip")
        here.loadouts = { here.loadouts[1] }
        local gearfor = Ring(AGI, 10)
        Expect(Classify.Link(gearfor.link), "char:" .. BONESET, "gearfor", true, "gearfor")
        h.Equal(Classify.Link(gearfor.link) == Classify.Link(gearfor.link), true, "cached")
    end,

    ["ClassifyB: a link-only item with a want reads wanted or wantedhere, else nobody"] = function()
        Boot()
        Provider({ unit = 100000, ageDays = 0 })
        local linen = Define({ equipLoc = false, classID = 7, subclassID = 5, sellPrice = 50 })
        Expect(Classify.Link(linen.link), "none", "nobody", true, "never AH or Vendor")
        Want(BONESET, { ["7:5"] = {} })
        Expect(Classify.Link(linen.link), "char:" .. BONESET, "wanted", true, "wanted")
        Want(HERE, { ["7:5"] = {} })
        Expect(Classify.Link(linen.link), "none", "wantedhere", true, "wantedhere")
    end,

    ["ClassifyB: a grey link runs only the include rule"] = function()
        Boot()
        local grey = Define({ equipLoc = false, classID = 15, subclassID = 0, quality = 0 })
        Expect(Classify.Link(grey.link), "none", "nobody", true, "no include, not Vendor")
        Want(CHAM, nil, { [grey.itemID] = "include" })
        Expect(Classify.Link(grey.link), "char:" .. CHAM, "wanted", true, "include")
        Want(HERE, nil, { [grey.itemID] = "include" })
        Expect(Classify.Link(grey.link), "none", "wantedhere", true, "here includes")
    end,

    ["ClassifyB: a pending link has no result until it loads"] = function()
        Boot()
        local item = Ring(AGI, 10)
        h.Stub.SetItemPending(item.itemID, item)
        h.Nil(Classify.Link(item.link), "pending")
        h.Stub.LoadItem(item.itemID)
        h.Stub.Advance(1)
        h.True(Classify.Link(item.link) ~= nil, "loaded")
    end,

    ["ClassifyB: a mailbox attachment is an owned piece and reads inuse (7.5)"] = function()
        local here = Boot()
        StrongRings()
        local item = Ring(AGI, 10)
        here.inbox = { gear = { item.link } }
        Generations.Bump("gearHere")
        Expect(Classify.Link(item.link, "inbox"), "none", "inuse", true, "attachment")
        h.Equal(
            Classify.Link(item.link, "inbox").reasonText,
            string.format(ns.L.reasonInuse, "Cat", ns.L.slotFinger) .. ns.L.reasonNotInBags,
            "mail attachment text"
        )
        -- The same link with no bag slot is not owned: no 3c, so it goes on.
        Expect(Classify.Link(item.link), "char:" .. BONESET, "gearfor", true, "plain link")
    end,

    ["ClassifyB: a nospec attachment skips 3a and 3c, 3b runs"] = function()
        local here = Boot()
        StrongRings()
        local item = Ring(AGI, 10)
        here.inbox = { gear = { item.link } }
        Generations.Bump("gearHere")
        Expect(Classify.Link(item.link, "inbox"), "none", "inuse", true, "scored: 3c applies")
        here.loadouts = { { name = "Unset", worn = true } }
        Generations.Bump("loadouts")
        Expect(
            Classify.Link(item.link, "inbox"),
            "char:" .. BONESET,
            "gearfor",
            true,
            "nospec: no 3a or 3c, 3b runs"
        )
    end,

    ["ClassifyB: an attachment that beats the worn piece is Equip, grey keeps step 2"] = function()
        local here = Boot()
        local item = Ring(AGI, 10)
        here.inbox = { gear = { item.link } }
        Generations.Bump("gearHere")
        Expect(Classify.Link(item.link, "inbox"), "equip", "equip", true, "attachment upgrade")
        local grey = Define({ equipLoc = false, classID = 15, subclassID = 0, quality = 0 })
        Expect(Classify.Link(grey.link, "inbox"), "none", "nobody", true, "grey attachment")
    end,

    ["ClassifyB: inbound mail is an owned piece, one copy left out, 3c runs (7.5)"] = function()
        local here = Boot()
        StrongRings()
        local item = Ring(AGI, 10)
        here.inbound = { { sentAt = 1, from = HERE, link = item.link, count = 1 } }
        Generations.Bump("gearHere")
        local inbound = Classify.Link(item.link, "inbound")
        Expect(inbound, "none", "inuse", true, "better pieces are owned")
        h.True(Classify.Link(item.link, "inbound") == inbound, "cached")
        -- A mailbox attachment of the same link is another input.
        local inbox = Classify.Link(item.link, "inbox")
        h.True(inbox ~= inbound, "inbox and inbound are cached under different keys")
        h.True(Classify.Link(item.link, "inbox") == inbox, "inbox cached")
        h.True(Classify.Link(item.link, "inbound") == inbound, "inbound still cached")
    end,

    ["ClassifyB: inbound mail that beats the worn piece is Equip"] = function()
        local here = Boot()
        local item = Ring(AGI, 10)
        here.inbound = { { sentAt = 1, from = HERE, link = item.link, count = 1 } }
        Generations.Bump("gearHere")
        Expect(Classify.Link(item.link, "inbound"), "equip", "equip", true, "inbound upgrade")
    end,

    -- Pending owned pieces, cache
    ["ClassifyB: gear waits for a loading owned piece, then follows its load"] = function()
        local here = Boot()
        Wear(Ring(AGI, 30), 11)
        local owned = Define({ stats = { [AGI] = 40 } })
        h.Stub.SetItemPending(owned.itemID, owned)
        here.bags.gear[#here.bags.gear + 1] = owned.link
        Generations.Bump("gearHere")
        local _, slot = Carry(Ring(AGI, 10))
        h.Nil(SlotResult(slot), "pending while the owned piece loads")
        h.Nil(SlotResult(slot), "still pending, nothing cached")
        h.Stub.Advance(10)
        Expect(SlotResult(slot), "equip", "equip", false, "piece left out after 10 s")
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        Expect(SlotResult(slot), "char:" .. BONESET, "gearfor", false, "recomputed with the piece")
    end,

    ["ClassifyB: a gear result is cached until a generation it used moves"] = function()
        local here = Boot()
        here.loadouts = { here.loadouts[1] }
        StrongRings()
        local _, slot = Carry(Ring(AGI, 10))
        local first = SlotResult(slot)
        h.True(SlotResult(slot) == first, "cached")
        Generations.Bump("prices")
        h.True(SlotResult(slot) == first, "prices not used")
        Generations.Bump("gearOthers")
        local second = SlotResult(slot)
        h.True(second ~= first, "gearOthers used by 3b")
        Roster.SetReceivesGear(BONESET, false)
        Expect(SlotResult(slot), "char:" .. CHAM, "gearfor", false, "roster change")
        Generations.Bump("loadouts")
        h.True(SlotResult(slot) ~= second, "loadouts used")
    end,

    -- The full pass (technical findings 15)
    ["ClassifyB: the initial pass runs after the snapshot and writes a classify line"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(12)
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Equal(FromSlotCalls(), 0, "nothing at the event itself")
        h.Stub.Advance(ns.Snapshot.DEBOUNCE_SECONDS)
        h.Equal(FromSlotCalls(), 12, "every slot classified")
        local text = DebugText()
        local snapshot = string.find(text, "snapshot: gear", 1, true)
        local classify = string.find(text, "classify: bags: 12 items in ", 1, true)
        h.True(snapshot ~= nil and classify ~= nil and snapshot < classify, text)
        h.Equal(Count(text, "classify: bags"), 1, "one line per pass")
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", false, false)
        h.Stub.Advance(5)
        h.Equal(Count(DebugText(), "classify: bags"), 1, "not on a zone change")
    end,

    ["ClassifyB: two initial-login events give one pass after the last snapshot"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(12)
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Stub.Advance(ns.Snapshot.DEBOUNCE_SECONDS / 2)
        h.Stub.FireEvent("PLAYER_ENTERING_WORLD", true, false)
        h.Stub.Advance(ns.Snapshot.DEBOUNCE_SECONDS / 2)
        h.Equal(FromSlotCalls(), 0, "no pass before the last event settles")
        h.Stub.Advance(ns.Snapshot.DEBOUNCE_SECONDS)
        h.Equal(FromSlotCalls(), 12, "one pass over every slot")
        h.Equal(Count(DebugText(), "classify: bags"), 1, "one line")
    end,

    ["ClassifyB: a pass above the budget is spread over frames in batches of 25"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(80)
        -- Each profile reading costs 1 ms, so the first segment ends after
        -- about 11 slots.
        h.Stub.SetProfileStep(1)
        h.True(Classify.Pass("bags"), "started")
        local first = FromSlotCalls()
        h.True(first > 0 and first < 80, "first segment: " .. first)
        h.Equal(Count(DebugText(), "classify: bags"), 0, "not finished")
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), first + 25, "one batch of 25 per frame")
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), first + 50, "second batch")
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), 80, "the last batch holds the rest")
        h.True(
            string.find(DebugText(), "classify: bags: 80 items in ", 1, true) ~= nil,
            DebugText()
        )
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), 80, "nothing left to do")
    end,

    ["ClassifyB: a pass within the budget runs in one go"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(80)
        Classify.Pass("bags")
        h.Equal(FromSlotCalls(), 80, "all at once")
        h.Equal(Count(DebugText(), "classify: bags: 80 items"), 1, "one line")
    end,

    ["ClassifyB: a pass waits for the end of combat"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(30)
        h.Stub.SetCombat(true)
        h.Equal(Classify.Pass("bags"), false, "deferred in combat")
        h.Equal(FromSlotCalls(), 0, "nothing classified")
        h.Stub.SetCombat(false)
        h.Stub.FireEvent("PLAYER_REGEN_ENABLED")
        h.Equal(FromSlotCalls(), 30, "classified when combat ends")
        h.Equal(Count(DebugText(), "classify: bags: 30 items"), 1, "one line")
        h.Stub.FireEvent("PLAYER_REGEN_ENABLED")
        h.Equal(FromSlotCalls(), 30, "nothing deferred any more")
    end,

    ["ClassifyB: combat in the middle of a spread pass pauses it until combat ends"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(80)
        h.Stub.SetProfileStep(1)
        Classify.Pass("bags")
        local first = FromSlotCalls()
        h.Stub.SetCombat(true)
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), first, "the batch did not run in combat")
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), first, "and does not come back by itself")
        h.Stub.SetCombat(false)
        h.Stub.SetProfileStep(0)
        h.Stub.FireEvent("PLAYER_REGEN_ENABLED")
        h.Equal(Count(DebugText(), "classify: bags: 80 items"), 1, "finished after combat")
    end,

    ["ClassifyB: closing the bank in the middle of a spread bank pass stops it"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        h.Stub.SetBagSize(6, 80)
        for slot = 1, 80 do
            local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
            h.Stub.SetBagItem(6, slot, { itemID = item.itemID, link = item.link, count = 1 })
        end
        CountReads()
        h.Stub.SetProfileStep(1)
        h.Stub.OpenBank()
        local first = FromSlotCalls()
        h.True(first > 0 and first < 80, "the pass is spread over frames")
        h.Stub.CloseBank()
        h.Stub.Advance(0)
        h.Stub.Advance(0)
        h.Equal(FromSlotCalls(), first, "no slot is classified after the bank closed")
        h.Equal(Count(DebugText(), "classify: bank:"), 0, "the stopped pass writes no line")
    end,

    ["ClassifyB: the bank is classified only while it is open"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        CountReads()
        h.Stub.SetBagSize(6, 10)
        for slot = 1, 10 do
            local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
            h.Stub.SetBagItem(6, slot, { itemID = item.itemID, link = item.link, count = 1 })
        end
        h.Equal(Classify.Pass("bank"), false, "closed")
        h.Equal(FromSlotCalls(), 0, "nothing")
        h.Stub.OpenBank()
        h.Equal(FromSlotCalls(), 10, "classified at BANKFRAME_OPENED")
        h.Equal(Count(DebugText(), "classify: bank: 10 items"), 1, "bank line")
    end,

    ["ClassifyB: a pass runs again when item data loads"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
        h.Stub.SetItemPending(item.itemID, item)
        h.Stub.SetBagSize(0, 2)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 1 })
        Classify.Pass("bags")
        h.Equal(Count(DebugText(), "classify: bags: 0 items"), 1, "pending item not counted")
        h.Stub.LoadItem(item.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(Count(DebugText(), "classify: bags: 1 items"), 1, "classified after the load")
    end,

    -- A pending item in slot 1 of a bag-0 pass spread over frames. The item
    -- is read in the first segment, then loaded: its batch callback arrives
    -- while the pass is still under way.
    ["ClassifyB: a load during a spread pass does not restart it, and it reruns once"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        FillBags(80)
        local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
        h.Stub.SetItemPending(item.itemID, item)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 1 })
        h.Stub.SetProfileStep(1)
        h.True(Classify.Pass("bags"), "started")
        local first = FromSlotCalls()
        h.True(first > 0 and first < 80, "first segment: " .. first)
        h.Stub.LoadItem(item.itemID)
        -- The load batch (0.2 s) falls due after one pass batch (0 s).
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(FromSlotCalls(), first + 25, "the pass went on from where it was")
        h.Equal(Count(DebugText(), "classify: bags"), 0, "not finished, not restarted")
        h.Stub.SetProfileStep(0)
        h.Stub.Advance(0)
        h.Stub.Advance(0)
        h.Stub.Advance(0)
        h.Equal(Count(DebugText(), "classify: bags"), 2, "finished, then one rerun")
        h.Stub.Advance(1)
        h.Equal(Count(DebugText(), "classify: bags"), 2, "no further rerun")
    end,

    ["ClassifyB: closing the bank while its pass waits for combat drops the deferral"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        h.Stub.SetBagSize(6, 10)
        for slot = 1, 10 do
            local item = Define({ equipLoc = false, classID = 7, subclassID = 5 })
            h.Stub.SetBagItem(6, slot, { itemID = item.itemID, link = item.link, count = 1 })
        end
        CountReads()
        h.Stub.SetCombat(true)
        h.Stub.OpenBank()
        h.Equal(FromSlotCalls(), 0, "deferred in combat")
        h.Stub.CloseBank()
        -- A bank that reads as open again without a BANKFRAME_OPENED event:
        -- only a kept deferral could start a pass at the end of combat.
        local original = ns.Snapshot.IsBankOpen
        ns.Snapshot.IsBankOpen = function()
            return true
        end
        h.Stub.SetCombat(false)
        h.Stub.FireEvent("PLAYER_REGEN_ENABLED")
        ns.Snapshot.IsBankOpen = original
        h.Equal(FromSlotCalls(), 0, "no bank pass after the bank closed")
    end,
}
