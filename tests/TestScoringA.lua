local _, ns, h = ...

local Scoring = ns.Scoring
local HERE = "Zugar Soulsour-Region"
local fixture = h.Fixture("scoring")
local nextID = 90000

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    for spec, weights in pairs(fixture.weights) do
        ns.WeightTables[spec] = weights
    end
    for key, entry in pairs(fixture.characters) do
        LootLogicDB.characters[key] = entry
    end
    local entry = LootLogicDB.characters[HERE]
    entry.class = "DRUID"
    entry.level = 60
    entry.loadouts = fixture.characters.druid.loadouts
    h.Stub.SetPlayer({ level = 60 })
    return entry
end

local function Item(fields)
    nextID = nextID + 1
    local item = { itemID = nextID, link = "item:" .. nextID,
        equipLoc = "INVTYPE_CHEST", classID = 4, subclassID = 2, reqLevel = 1,
        itemLevel = 20, stats = {} }
    for key, value in pairs(fields or {}) do
        item[key] = value
    end
    h.Stub.SetItem(item.itemID, item)
    if not item.noTooltip then
        h.Stub.SetTooltipLines(item.link, {})
    end
    return item
end

local function Options(loadout)
    return { loadout = loadout or fixture.characters.druid.loadouts[2] }
end

local function Compare(item, key, loadout)
    return Scoring.Compare(item, key or "druid", Options(loadout))
end

return {
    ["unreadable owned usability stays pending and retries without a generation bump"] = function()
        Boot()
        local owned = Item({ noTooltip = true,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        LootLogicDB.characters.druid.bags = { gear = { owned.link } }
        LootLogicDB.characters[HERE].bags = { gear = { owned.link } }
        for _, key in ipairs({ HERE, "druid" }) do
            local facts = ns.ItemFacts.FromLink(owned.link)
            h.Equal(facts.tooltipUnread, true, "unresolved tooltip")
            h.Nil(Scoring.CanUse(facts, key, Options()), "usability unresolved")
            local result = Compare(candidate, key)
            h.Equal(result.pending, true, "comparison pending")
            h.Nil(result.upgrade, "no upgrade verdict")
            h.Nil(result.baseline, "no invented baseline")
        end
        h.Stub.SetTooltipLines(owned.link, { "Classes: Mage" })
        for _, key in ipairs({ HERE, "druid" }) do
            local result = Compare(candidate, key)
            h.Nil(result.pending, "readable now")
            h.Equal(result.baseline, 0, "restricted owned item excluded")
            h.Equal(result.upgrade, true, "resolved comparison")
        end
    end,
    ["weighted sum and weapon DPS use the judged hand"] = function()
        Boot()
        local item = Item({ classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_AGILITY_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 3,
                ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } })
        h.Equal(Scoring.Score(item, "DRUID:cat", "mainHand"), 43, "main hand")
        h.Equal(Scoring.Score(item, "DRUID:cat", "offHand"), 23, "off hand")
        h.Equal(Scoring.Score(item, "DRUID:cat", "ranged"), 53, "ranged")
        item.equipLoc = "INVTYPE_2HWEAPON"
        h.Equal(Scoring.Score(item, "DRUID:cat"), 43, "two hand")
        h.Nil(Scoring.Score(item, nil), "no spec")
    end,
    ["percent keys convert once without changing source tables"] = function()
        Boot()
        local item = Item({ stats = { ITEM_MOD_HIT_RATING_SHORT = 10,
            ITEM_MOD_CRIT_RATING_SHORT = 14, ITEM_MOD_HASTE_RATING_SHORT = 10,
            ITEM_MOD_DODGE_RATING_SHORT = 12, ITEM_MOD_PARRY_RATING_SHORT = 15,
            ITEM_MOD_BLOCK_RATING_SHORT = 5 } })
        h.Equal(Scoring.Score(item, "PALADIN:holy"), 66, "converted score")
        h.Equal(Scoring.Score(item, "PALADIN:holy"), 66, "not converted twice")
        h.Equal(ns.WeightTables["PALADIN:holy"].weights.HIT, 10, "source unchanged")
        h.Equal(ns.WeightTables["WARLOCK:affliction"].weights.HIT, 0.9511, "computed weights")
        LootLogicDB.characters.paladin.level = 10
        h.Equal(Scoring.Score(item, "PALADIN:holy"), 66, "level invariant")
    end,
    ["required levels now and look ahead for here and another character"] = function()
        Boot()
        local item = Item({ reqLevel = 64 })
        h.Equal(Scoring.CanUse(item, HERE, Options()), false, "not usable now")
        local options = Options()
        options.lookAhead = true
        h.Equal(Scoring.CanUse(item, HERE, options), true, "here look ahead")
        h.Equal(Scoring.CanUse(item, "druid", Options()), true, "other look ahead")
        item.reqLevel = 66
        h.Equal(Scoring.CanUse(item, HERE, options), false, "here too far")
        h.Equal(Scoring.CanUse(item, "druid", Options()), false, "other too far")
    end,
    ["live answer only for here and trainable weapon overrides it"] = function()
        Boot()
        local item = Item({ classID = 2, subclassID = 4, equipLoc = "INVTYPE_WEAPONMAINHAND" })
        h.Stub.SetCanUseItem(item.itemID, false)
        local usable, train = Scoring.CanUse(item, HERE, Options())
        h.Equal(usable, true, "trainable mace")
        h.DeepEqual(train, { 198 }, "train mace")
        h.Stub.SetKnownSpells({ 198 })
        h.Equal(Scoring.CanUse(item, HERE, Options()), false, "live denial")
        local count = #h.Stub.CanUseItemCalls()
        h.Equal(Scoring.CanUse(item, "druid", Options()), true, "snapshot training")
        h.Equal(#h.Stub.CanUseItemCalls(), count, "no live call for other")
        item.subclassID = 7
        h.Equal(Scoring.CanUse(item, HERE, Options()), false, "druid cannot train sword")
        h.Equal(Scoring.CanUse(item, "druid", Options()), false, "other cannot train sword")
    end,
    ["armour training across forty uses current or required level"] = function()
        Boot()
        local entry = LootLogicDB.characters[HERE]
        entry.class = "PALADIN"
        entry.level = 38
        LootLogicDB.characters.paladin.level = 38
        LootLogicDB.characters.paladin.proficiency.spells = {}
        h.Stub.SetPlayer({ level = 38 })
        local item = Item({ subclassID = 4, reqLevel = 40 })
        local options = Options(fixture.characters.paladin.loadouts[1])
        options.lookAhead = true
        for _, key in ipairs({ HERE, "paladin" }) do
            local usable, train = Scoring.CanUse(item, key, options)
            h.Equal(usable, true, "plate at forty")
            h.DeepEqual(train, { 750 }, "train plate")
            item.reqLevel = 39
            h.Equal(Scoring.CanUse(item, key, options), false, "not yet trainable")
            item.reqLevel = 40
        end
    end,
    ["shield requires learning and relics require the matching class"] = function()
        Boot()
        local shield = Item({ subclassID = 6, equipLoc = "INVTYPE_SHIELD" })
        h.Equal(Scoring.CanUse(shield, HERE, Options()), false, "here unlearned shield")
        h.Equal(Scoring.CanUse(shield, "paladin", Options()), false, "other unlearned shield")
        h.Stub.SetKnownSpells({ 9116 })
        LootLogicDB.characters.paladin.proficiency.spells[9116] = true
        h.Equal(Scoring.CanUse(shield, HERE, Options()), true, "here learned shield")
        h.Equal(Scoring.CanUse(shield, "paladin", Options()), true, "other learned shield")
        for subclass, key in pairs({ [7] = "paladin", [8] = "druid", [9] = "shaman" }) do
            local relic = Item({ subclassID = subclass, equipLoc = "INVTYPE_RELIC" })
            h.Equal(Scoring.CanUse(relic, key, Options()), true, "matching relic")
            h.Equal(Scoring.CanUse(relic, "warlock", Options()), false, "wrong relic")
            h.Equal(Scoring.CanUse(relic, HERE, Options()), subclass == 8, "here relic")
        end
    end,
    ["dual wield training and no-proficiency weapon subclasses"] = function()
        Boot()
        LootLogicDB.characters[HERE].class = "ROGUE"
        LootLogicDB.characters.druid.class = "ROGUE"
        local item = Item({ classID = 2, subclassID = 9, equipLoc = "INVTYPE_WEAPONOFFHAND" })
        for _, key in ipairs({ HERE, "druid" }) do
            local usable, train = Scoring.CanUse(item, key, Options())
            h.Equal(usable, true, "train dual wield")
            h.DeepEqual(train, { 674 }, "dual wield flag only")
        end
        h.Stub.SetKnownSpells({ 674 })
        local _, train = Scoring.CanUse(item, HERE, Options())
        h.DeepEqual(train, {}, "learned dual wield")
        LootLogicDB.characters.druid.class = "DRUID"
        h.Equal(Scoring.CanUse(item, "druid", Options()), false, "no dual wield")
    end,
    ["class restrictions and ignored slot types"] = function()
        Boot()
        local item = Item({ classRestriction = { PALADIN = true } })
        h.Equal(Scoring.CanUse(item, HERE, Options()), false, "here class restriction")
        h.Equal(Scoring.CanUse(item, "druid", Options()), false, "other class restriction")
        for _, equipLoc in ipairs({ "INVTYPE_BODY", "INVTYPE_TABARD", "INVTYPE_AMMO",
            "INVTYPE_BAG", "INVTYPE_QUIVER" }) do
            h.Nil(Scoring.Group(Item({ equipLoc = equipLoc })), "ignored slot")
        end
        h.Nil(Scoring.Group(Item({ subclassID = 5 })), "cosmetic")
        h.Nil(Scoring.Group(Item({ itemID = 2901 })), "tool ID")
        h.Nil(Scoring.Group(Item({ classID = 2, subclassID = 14 })), "tool subclass")
        h.Nil(Scoring.Group(Item({ classID = 2, subclassID = 20 })), "fishing pole")
    end,
    ["global and per-loadout armour rules and worn baseline exception"] = function()
        Boot()
        local entry = LootLogicDB.characters.druid
        local leather = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 5 } })
        local cloth = Item({ subclassID = 1, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        entry.gear = { slots = { [5] = cloth.link } }
        entry.bags = { gear = { leather.link } }
        h.Nil(Compare(cloth), "lower armour is not a candidate")
        h.Equal(Compare(leather).baseline, 40, "worn lower armour baseline")
        entry.gear = nil
        entry.bags = { gear = { cloth.link } }
        ns.Generations.Bump("gearOthers")
        h.Equal(Compare(leather).baseline, 0, "unworn lower armour ignored")
        LootLogicDB.settings.gear.bestArmorOnly = false
        ns.Generations.Bump("settings")
        h.Equal(Compare(leather).baseline, 40, "global any")
        local best = { spec = "DRUID:cat", armor = "best" }
        h.Nil(Compare(cloth, "druid", best), "best override")
        LootLogicDB.settings.gear.bestArmorOnly = true
        ns.Generations.Bump("settings")
        local any = { spec = "DRUID:cat", armor = "any" }
        h.Equal(Compare(leather, "druid", any).baseline, 40, "any override")
    end,
    ["upgrade percentage boundary empty baseline and fallback disabled"] = function()
        Boot()
        h.Equal(Scoring.IsUpgrade(101, 100, 1), true, "at threshold")
        h.Equal(Scoring.IsUpgrade(102, 100, 1), true, "above threshold")
        h.Equal(Scoring.IsUpgrade(100.5, 100, 1), false, "below threshold")
        h.Equal(Scoring.IsUpgrade(100, 100, 0), false, "must improve")
        local upgrade, gain = Scoring.IsUpgrade(1, 0, 1000)
        h.Equal(upgrade, true, "positive empty")
        h.Equal(gain, math.huge, "infinite gain")
        h.Equal(Scoring.IsUpgrade(0, 0, 0), false, "zero empty")
        local item = Item()
        LootLogicDB.settings.gear.itemLevelFallback = false
        h.Equal(Compare(item).upgrade, false, "unweighted fallback off")
    end,
    ["fallback uses score baseline item level then highest level when all scores zero"] = function()
        Boot()
        local entry = LootLogicDB.characters.druid
        local best = Item({ itemLevel = 10, stats = { ITEM_MOD_AGILITY_SHORT = 50 } })
        local higher = Item({ itemLevel = 40 })
        local candidate = Item({ itemLevel = 20 })
        entry.bags = { gear = { best.link, higher.link } }
        local result = Compare(candidate)
        h.Equal(result.baseline, 10, "same score baseline piece")
        h.Equal(result.gainPct, 100, "item level percentage")
        h.Equal(result.itemLevel, true, "label item level")
        entry.bags.gear = { higher.link }
        ns.Generations.Bump("gearOthers")
        result = Compare(candidate)
        h.Equal(result.baseline, 40, "highest level among zero scores")
        h.Equal(result.upgrade, false, "not upgrade")
        entry.bags.gear = {}
        ns.Generations.Bump("gearOthers")
        result = Compare(candidate)
        h.Equal(result.baseline, 0, "empty item level")
        h.Equal(result.gainPct, math.huge, "empty infinite")
        h.Equal(result.upgrade, true, "empty upgrade")
    end,
    ["owned containers count but imported set membership alone does not"] = function()
        Boot()
        local entry = LootLogicDB.characters.druid
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        for _, where in ipairs({ "bags", "bank", "inbox", "inbound", "worn" }) do
            entry.bags, entry.bank, entry.inbox = nil, nil, nil
            entry.inbound, entry.gear = nil, nil
            local owned = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
            if where == "inbound" then
                entry.inbound = { { link = owned.link, count = 1 } }
            elseif where == "worn" then
                entry.gear = { slots = { [5] = owned.link } }
            else
                entry[where] = { gear = { owned.link } }
            end
            ns.Generations.Bump("gearOthers")
            local result = Compare(candidate)
            h.Equal(result.baseline, 40, "owned " .. where)
            h.Equal(result.baselineWhere, where, "location")
        end
        entry.gear = nil
        entry.importedSets = { test = { items = { { id = candidate.itemID, suffix = 0 } } } }
        ns.Generations.Bump("gearOthers")
        h.Equal(Compare(candidate).baseline, 0, "set alone not owned")
    end,
    ["loadouts collapse by effective armour rule preferring worn and nil is unscored"] = function()
        Boot()
        local entry = LootLogicDB.characters.druid
        entry.loadouts = {
            { name = "First", spec = "DRUID:cat" },
            { name = "Worn", spec = "DRUID:cat", armor = "best", worn = true },
            { name = "Any", spec = "DRUID:cat", armor = "any" },
            { name = "Unset" },
        }
        local comparisons = Scoring.Comparisons("druid")
        h.Equal(#comparisons, 2, "distinct rules")
        h.Equal(comparisons[1].name, "Worn", "worn preferred")
        h.Equal(#Scoring.Comparisons("mage"), 0, "mage unscored")
        local mage = fixture.characters.mage.loadouts[1]
        h.Nil(Compare(Item(), "mage", mage), "no comparison")
    end,
    ["own unworn instance excluded for here and cache generations refresh"] = function()
        local entry = Boot()
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local weaker = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 5 } })
        entry.bags = { gear = { candidate.link, weaker.link } }
        h.Equal(Compare(candidate, HERE).baseline, 10, "own copy excluded")
        local other = LootLogicDB.characters.druid
        other.bags = { gear = { candidate.link } }
        h.Equal(Compare(candidate).baseline, 20, "not excluded for other")
        entry.bags.gear = {}
        ns.Generations.Bump("gearHere")
        h.Equal(Compare(candidate, HERE).baseline, 0, "here generation")
        other.bags.gear = {}
        ns.Generations.Bump("gearOthers")
        h.Equal(Compare(candidate).baseline, 0, "other generation")
    end,
    ["every armour slot enforces best type and exempt slots allow cloth"] = function()
        Boot()
        local options = Options(fixture.characters.shaman.loadouts[1])
        LootLogicDB.characters[HERE].class = "SHAMAN"
        for _, equipLoc in ipairs({ "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST",
            "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST",
            "INVTYPE_LEGS", "INVTYPE_FEET" }) do
            local item = Item({ subclassID = 2, equipLoc = equipLoc, reqLevel = 35 })
            h.Equal(Scoring.CanUse(item, HERE, options), false, "here best armour")
            h.Equal(Scoring.CanUse(item, "shaman", options), false, "other best armour")
        end
        for _, equipLoc in ipairs({ "INVTYPE_CLOAK", "INVTYPE_NECK", "INVTYPE_FINGER",
            "INVTYPE_TRINKET", "INVTYPE_HOLDABLE" }) do
            local item = Item({ subclassID = 0, equipLoc = equipLoc })
            h.Equal(Scoring.CanUse(item, HERE, options), true, "here exempt")
            h.Equal(Scoring.CanUse(item, "shaman", options), true, "other exempt")
        end
    end,
    ["live proficiency overrides saved proficiency and absent API uses fallback"] = function()
        local entry = Boot()
        local item = Item({ classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPONMAINHAND" })
        entry.proficiency = { spells = { [201] = true } }
        h.Equal(Scoring.CanUse(item, HERE, Options()), false, "saved spell not live")
        h.Stub.SetKnownSpells({ 201 })
        h.Equal(Scoring.CanUse(item, HERE, Options()), true, "live learned spell")
        h.Stub.SetCanUseAPI(false)
        h.Equal(Scoring.CanUse(item, HERE, Options()), true, "L5 proficiency fallback")
        h.Stub.SetCanUseAPI(true)
    end,
    ["baseline cache avoids rescanning for a new candidate and loadouts invalidate it"] = function()
        Boot()
        local owned = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        LootLogicDB.characters.druid.bags = { gear = { owned.link } }
        local first = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local second = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 30 } })
        local original = ns.ItemFacts.FromLink
        local calls = 0
        ns.ItemFacts.FromLink = function(link)
            calls = calls + 1
            return original(link)
        end
        h.Equal(Compare(first).baseline, 20, "first baseline")
        h.Equal(calls, 1, "one owned read")
        h.Equal(Compare(second).baseline, 20, "second baseline")
        h.Equal(calls, 1, "no new scan")
        ns.Generations.Bump("loadouts")
        Compare(second)
        h.Equal(calls, 2, "loadouts invalidated")
        ns.ItemFacts.FromLink = original
    end,
    ["fallback threshold applies and cancellation of weighted stats is not fallback"] = function()
        Boot()
        local baseline = Item({ itemLevel = 100 })
        LootLogicDB.characters.druid.bags = { gear = { baseline.link } }
        LootLogicDB.settings.gear.minUpgradePct = 5
        h.Equal(Compare(Item({ itemLevel = 104 })).upgrade, false, "below fallback threshold")
        h.Equal(Compare(Item({ itemLevel = 105 })).upgrade, true, "at fallback threshold")
        ns.WeightTables["DRUID:cat"] = { weights = { STR = 1, AGI = -1 }, percent = {} }
        local item = Item({ itemLevel = 200,
            stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10 } })
        local result = Compare(item)
        h.Equal(result.itemLevel, false, "weighted zero is not unweighted")
        h.Equal(result.upgrade, false, "no zero-score upgrade")
        h.Nil(Compare({ pending = true }), "pending candidate")
    end,
}
