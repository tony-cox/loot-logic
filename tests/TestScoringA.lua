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
    local item = {
        itemID = nextID,
        link = "item:" .. nextID,
        equipLoc = "INVTYPE_CHEST",
        classID = 4,
        subclassID = 2,
        reqLevel = 1,
        itemLevel = 20,
        stats = {},
    }
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
    ["owned item data waits once across levels and refreshes on late arrival"] = function()
        Boot()
        local owned = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        h.Stub.SetItemPending(owned.itemID, owned)
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        LootLogicDB.characters.druid.bags = { gear = { owned.link } }
        h.Equal(Compare(candidate).pending, true, "initially pending")
        h.Stub.Advance(9)
        h.Equal(Compare(candidate).pending, true, "still pending")
        h.Stub.Advance(1)
        h.Equal(Compare(candidate).baseline, 0, "omitted after deadline")
        local generation = ns.Generations.Get("gearOthers")
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(ns.Generations.Get("gearOthers"), generation + 1, "late load invalidates")
        h.Equal(Compare(candidate).baseline, 40, "loaded piece included")
    end,
    ["unavailable saved specs stay unchanged and supply no score or comparison"] = function()
        Boot()
        local entry = LootLogicDB.characters.druid
        local missing = "DRUID:future"
        entry.loadouts = { { name = "Future", spec = missing, worn = true } }
        local calls = 0
        local original = ns.Stats.Get
        ns.Stats.Get = function(link)
            calls = calls + 1
            return original(link)
        end
        h.Nil(Scoring.Score({}, missing), "missing table has no score")
        h.Nil(Compare({}, "druid", entry.loadouts[1]), "no advice")
        h.Equal(calls, 0, "unsupported spec never reads stats")
        h.Equal(#Scoring.Comparisons("druid"), 0, "unsupported-only character")
        entry.loadouts[2] = { name = "Cat", spec = "DRUID:cat" }
        entry.loadouts[3] = { name = "Unset" }
        local comparisons = Scoring.Comparisons("druid")
        h.Equal(#comparisons, 1, "mixed loadouts exclude unsupported and nil")
        h.Equal(comparisons[1], entry.loadouts[2], "supported comparison")
        h.DeepEqual(entry.loadouts, {
            { name = "Future", spec = missing, worn = true },
            { name = "Cat", spec = "DRUID:cat" },
            { name = "Unset" },
        }, "saved choices unchanged")
        ns.Stats.Get = original
    end,
    ["above-level live denial is bypassed but a current-level denial still applies"] = function()
        Boot()
        h.Stub.SetKnownSpells({ 9077 })
        local item = Item({ reqLevel = 63 })
        local options = Options()
        options.lookAhead = true
        h.Stub.SetCanUseItem(item.itemID, false)
        local calls = #h.Stub.CanUseItemCalls()
        h.Equal(Scoring.CanUse(item, HERE, options), true, "future usable")
        h.Equal(#h.Stub.CanUseItemCalls(), calls, "future never calls live API")
        options.evaluatedLevel = 63
        h.Equal(Scoring.CanUse(item, HERE, options), true, "owned future evaluation")
        h.Equal(#h.Stub.CanUseItemCalls(), calls, "evaluation is not real level")
        item.reqLevel = 60
        h.Equal(Scoring.CanUse(item, HERE, options), false, "current denial")
        h.Equal(#h.Stub.CanUseItemCalls(), calls + 1, "current calls API")
        h.Stub.SetKnownSpells({})
        local usable, train = Scoring.CanUse(item, HERE, options)
        h.Equal(usable, true, "trainable overrides current denial")
        h.DeepEqual(train, { 9077 }, "train leather")
        h.Equal(#h.Stub.CanUseItemCalls(), calls + 1, "training bypasses API")
    end,
    ["single-slot progression uses candidate level for here and another character"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        h.Stub.SetKnownSpells({ 9077 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.characters.druid.level = 20
        local now = Item({ reqLevel = 10, stats = { ITEM_MOD_AGILITY_SHORT = 5 } })
        local level21 = Item({ reqLevel = 21, stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local level22 = Item({ reqLevel = 22, stats = { ITEM_MOD_AGILITY_SHORT = 15 } })
        local level23 = Item({ reqLevel = 23, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local options = Options()
        options.lookAhead = true
        local earlier = Item({ reqLevel = 15, stats = { ITEM_MOD_AGILITY_SHORT = 6 } })
        local inferior22 = Item({ reqLevel = 22, stats = { ITEM_MOD_AGILITY_SHORT = 12.5 } })
        local inferior23 = Item({ reqLevel = 23, stats = { ITEM_MOD_AGILITY_SHORT = 14 } })
        for _, key in ipairs({ HERE, "druid" }) do
            local entry = LootLogicDB.characters[key]
            entry.bags = { gear = { now.link, level22.link, level23.link } }
            ns.Generations.Bump("gearHere")
            ns.Generations.Bump("gearOthers")
            local current = Scoring.Compare(earlier, key, options)
            h.Equal(current.baseline, 10, "below-current candidate uses current level")
            h.Equal(current.upgrade, true, "future pieces do not suppress usable-now upgrade")
            local intermediate = Scoring.Compare(level21, key, options)
            h.Equal(intermediate.baseline, 10, "level21 baseline")
            h.Equal(intermediate.upgrade, true, "later winners do not suppress level21")
            entry.bags.gear = { now.link, level21.link, level23.link }
            ns.Generations.Bump("gearHere")
            ns.Generations.Bump("gearOthers")
            local nextUpgrade = Scoring.Compare(level22, key, options)
            h.Equal(nextUpgrade.baseline, 20, "level22 baseline")
            h.Equal(nextUpgrade.upgrade, true, "later winner does not suppress level22")
            entry.bags.gear = { now.link, level21.link, level22.link, level23.link }
            ns.Generations.Bump("gearHere")
            ns.Generations.Bump("gearOthers")
            h.Equal(Scoring.Compare(inferior22, key, options).baseline, 30, "same-level winner")
            h.Equal(Scoring.Compare(inferior22, key, options).upgrade, false, "inferior level22")
            h.Equal(Scoring.Compare(inferior23, key, options).baseline, 40, "later winner")
            h.Equal(Scoring.Compare(inferior23, key, options).upgrade, false, "inferior level23")
        end
    end,
    ["level-specific baselines cache separately and reuse the earlier evaluation"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters.druid.level = 20
        local earlier = Item({ reqLevel = 21, stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local later = Item({ reqLevel = 23, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        LootLogicDB.characters.druid.bags = { gear = { earlier.link, later.link } }
        local original = ns.ItemFacts.FromLink
        local calls = 0
        ns.ItemFacts.FromLink = function(link)
            calls = calls + 1
            return original(link)
        end
        local loadout = fixture.characters.druid.loadouts[2]
        local options = { group = "chest", evaluatedLevel = 21 }
        h.Equal(Scoring.Baseline("druid", loadout, options).score, 20, "early level")
        h.Equal(calls, 2, "early scan")
        options.evaluatedLevel = 23
        h.Equal(Scoring.Baseline("druid", loadout, options).score, 40, "later level")
        h.Equal(calls, 4, "separate later scan")
        options.evaluatedLevel = 21
        h.Equal(Scoring.Baseline("druid", loadout, options).score, 20, "early cache retained")
        h.Equal(calls, 4, "early cache reused")
        ns.Generations.Bump("settings")
        Scoring.Baseline("druid", loadout, options)
        h.Equal(calls, 6, "settings refresh level-specific entry")
        ns.ItemFacts.FromLink = original
    end,
    ["unreadable later-level usability does not block an earlier baseline"] = function()
        Boot()
        LootLogicDB.characters.druid.level = 20
        local now = Item({ reqLevel = 20, stats = { ITEM_MOD_AGILITY_SHORT = 5 } })
        local later = Item({
            reqLevel = 23,
            noTooltip = true,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        LootLogicDB.characters.druid.bags = { gear = { now.link, later.link } }
        local loadout = fixture.characters.druid.loadouts[2]
        local baseline =
            Scoring.Baseline("druid", loadout, { group = "chest", evaluatedLevel = 21 })
        h.Nil(baseline.pending, "later piece cannot affect earlier usability")
        h.Equal(baseline.score, 10, "known earlier baseline")
        h.Equal(
            Scoring.Baseline("druid", loadout, { group = "chest", evaluatedLevel = 23 }).pending,
            true,
            "later usability needed at its level"
        )
    end,
    ["item-level fallback excludes owned pieces above the evaluated level"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 20 })
        LootLogicDB.characters[HERE].level = 20
        LootLogicDB.characters.druid.level = 20
        local now = Item({ reqLevel = 10, itemLevel = 10 })
        local same = Item({ reqLevel = 22, itemLevel = 30 })
        local later = Item({ reqLevel = 23, itemLevel = 80 })
        local candidate = Item({ reqLevel = 21, itemLevel = 20 })
        local options = Options()
        options.lookAhead = true
        for _, key in ipairs({ HERE, "druid" }) do
            LootLogicDB.characters[key].bags = { gear = { now.link, same.link, later.link } }
            local result = Scoring.Compare(candidate, key, options)
            h.Equal(result.itemLevel, true, "fallback used")
            h.Equal(result.baseline, 10, "fallback filters future pieces")
            h.Equal(result.upgrade, true, "intermediate fallback upgrade")
            candidate.reqLevel = 22
            result = Scoring.Compare(candidate, key, options)
            h.Equal(result.baseline, 30, "same-level fallback alternative")
            h.Equal(result.upgrade, false, "same-level stronger item suppresses")
            candidate.reqLevel = 21
        end
    end,
    ["owned armour and training use the later evaluation for every baseline piece"] = function()
        Boot()
        h.Stub.SetPlayer({ level = 38 })
        h.Stub.SetKnownSpells({ 8737 })
        local mail = Item({
            subclassID = 3,
            reqLevel = 30,
            stats = { ITEM_MOD_STRENGTH_SHORT = 100 },
        })
        local plate = Item({
            subclassID = 4,
            reqLevel = 39,
            stats = { ITEM_MOD_STRENGTH_SHORT = 5 },
        })
        local loadout = { spec = "DRUID:cat", armor = "best" }
        for _, key in ipairs({ HERE, "paladin" }) do
            local entry = LootLogicDB.characters[key]
            entry.class = "PALADIN"
            entry.level = 38
            entry.proficiency = { spells = { [8737] = true } }
            entry.bags = { gear = { mail.link, plate.link } }
            local options = { group = "chest", evaluatedLevel = 39 }
            h.Equal(Scoring.Baseline(key, loadout, options).score, 100, "mail at39")
            options.evaluatedLevel = 40
            h.Equal(Scoring.Baseline(key, loadout, options).score, 5, "plate trained at40")
            local usable, train =
                Scoring.CanUse(plate, key, { loadout = loadout, evaluatedLevel = 40 })
            h.Equal(usable, true, "owned plate trainable at later evaluation")
            h.DeepEqual(train, { 750 }, "train plate")
            entry.gear = { slots = { [5] = mail.link } }
            ns.Generations.Bump("gearHere")
            ns.Generations.Bump("gearOthers")
            h.Equal(Scoring.Baseline(key, loadout, options).score, 100, "worn mail exception")
        end
    end,
    ["look-ahead required level raises the best wearable armour type"] = function()
        Boot()
        LootLogicDB.characters[HERE].class = "PALADIN"
        LootLogicDB.characters[HERE].level = 38
        LootLogicDB.characters.paladin.level = 38
        LootLogicDB.characters.paladin.proficiency.spells = { [8737] = true }
        h.Stub.SetPlayer({ level = 38 })
        h.Stub.SetKnownSpells({ 8737 })
        local item = Item({ subclassID = 3, reqLevel = 40 })
        local options = Options(fixture.characters.paladin.loadouts[1])
        options.lookAhead = true
        for _, key in ipairs({ HERE, "paladin" }) do
            h.Equal(Scoring.CanUse(item, key, options), false, "plate is best at required level")
            options.loadout = { spec = "PALADIN:protection", armor = "any" }
            h.Equal(Scoring.CanUse(item, key, options), true, "any armour allows future mail")
            options.loadout = fixture.characters.paladin.loadouts[1]
        end
    end,
    ["explicit off-hand judgment requires dual wield for a general one-hand weapon"] = function()
        Boot()
        local item = Item({ classID = 2, subclassID = 9, equipLoc = "INVTYPE_WEAPON" })
        local options = Options()
        for _, key in ipairs({ HERE, "druid" }) do
            h.Equal(Scoring.CanUse(item, key, options), true, "main hand needs no dual wield")
            options.hand = "offHand"
            h.Equal(Scoring.CanUse(item, key, options), false, "off hand needs dual wield")
            options.hand = nil
        end
        LootLogicDB.characters.druid.class = "ROGUE"
        options.hand = "offHand"
        local usable, train = Scoring.CanUse(item, "druid", options)
        h.Equal(usable, true, "trainable dual wield")
        h.DeepEqual(train, { 674 }, "explicit hand training flag")
    end,
    ["link-only comparison keeps the matching owned instance in the baseline"] = function()
        local entry = Boot()
        local item = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        entry.bags = { gear = { item.link } }
        h.Equal(Compare(item, HERE).baseline, 0, "slot candidate excluded")
        item.linkOnly = true
        local result = Compare(item, HERE)
        h.Equal(result.baseline, 20, "link-only candidate retains owned instance")
        h.Equal(result.upgrade, false, "same item is not an upgrade")
    end,
    ["configured look-ahead window changes eligibility for here and another character"] = function()
        Boot()
        local item = Item({ reqLevel = 63 })
        local options = Options()
        options.lookAhead = true
        for _, row in ipairs({
            { levels = 0, usable = false },
            { levels = 2, usable = false },
            { levels = 3, usable = true },
            { levels = 8, usable = true },
        }) do
            LootLogicDB.settings.gear.lookAheadLevels = row.levels
            h.Equal(Scoring.CanUse(item, HERE, options), row.usable, "here configured window")
            h.Equal(Scoring.CanUse(item, "druid", options), row.usable, "other configured window")
        end
        options.lookAhead = nil
        h.Equal(Scoring.CanUse(item, HERE, options), false, "here now ignores window")
    end,
    ["unreadable owned usability stays pending and retries without a generation bump"] = function()
        Boot()
        local owned = Item({ noTooltip = true, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
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
        local item = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = {
                ITEM_MOD_AGILITY_SHORT = 5,
                ITEM_MOD_STRENGTH_SHORT = 3,
                ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10,
            },
        })
        h.Equal(Scoring.Score(item, "DRUID:cat", "mainHand"), 43, "main hand")
        h.Equal(Scoring.Score(item, "DRUID:cat", "offHand"), 23, "off hand")
        h.Equal(Scoring.Score(item, "DRUID:cat", "ranged"), 53, "ranged")
        item.equipLoc = "INVTYPE_2HWEAPON"
        h.Equal(Scoring.Score(item, "DRUID:cat"), 43, "two hand")
        h.Nil(Scoring.Score(item, nil), "no spec")
    end,
    ["percent keys convert once without changing source tables"] = function()
        Boot()
        local item = Item({
            stats = {
                ITEM_MOD_HIT_RATING_SHORT = 10,
                ITEM_MOD_CRIT_RATING_SHORT = 14,
                ITEM_MOD_HASTE_RATING_SHORT = 10,
                ITEM_MOD_DODGE_RATING_SHORT = 12,
                ITEM_MOD_PARRY_RATING_SHORT = 15,
                ITEM_MOD_BLOCK_RATING_SHORT = 5,
            },
        })
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
        for _, equipLoc in ipairs({
            "INVTYPE_BODY",
            "INVTYPE_TABARD",
            "INVTYPE_AMMO",
            "INVTYPE_BAG",
            "INVTYPE_QUIVER",
        }) do
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
        h.Equal(Scoring.IsUpgrade(6.6, 6, 10), true, "fractional threshold")
        h.Equal(Scoring.IsUpgrade(6.599, 6, 10), false, "below fractional threshold")
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
        for _, equipLoc in ipairs({
            "INVTYPE_HEAD",
            "INVTYPE_SHOULDER",
            "INVTYPE_CHEST",
            "INVTYPE_ROBE",
            "INVTYPE_WRIST",
            "INVTYPE_HAND",
            "INVTYPE_WAIST",
            "INVTYPE_LEGS",
            "INVTYPE_FEET",
        }) do
            local item = Item({ subclassID = 2, equipLoc = equipLoc, reqLevel = 35 })
            h.Equal(Scoring.CanUse(item, HERE, options), false, "here best armour")
            h.Equal(Scoring.CanUse(item, "shaman", options), false, "other best armour")
        end
        for _, equipLoc in ipairs({
            "INVTYPE_CLOAK",
            "INVTYPE_NECK",
            "INVTYPE_FINGER",
            "INVTYPE_TRINKET",
            "INVTYPE_HOLDABLE",
        }) do
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
        local item = Item({
            itemLevel = 200,
            stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10 },
        })
        local result = Compare(item)
        h.Equal(result.itemLevel, false, "weighted zero is not unweighted")
        h.Equal(result.upgrade, false, "no zero-score upgrade")
        h.Nil(Compare({ pending = true }), "pending candidate")
    end,
}
