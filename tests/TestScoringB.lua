local _, ns, h = ...

local fixture = h.Fixture("scoring")
local nextID = 96000

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    h.Stub.FireEvent("PLAYER_LOGIN")
    for spec, weights in pairs(fixture.weights) do
        ns.WeightTables[spec] = weights
    end
    LootLogicDB.characters.druid = fixture.characters.druid
    return fixture.characters.druid
end

local function Item(fields)
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        link = "item:" .. nextID,
        equipLoc = "INVTYPE_FINGER",
        classID = 4,
        subclassID = 0,
        reqLevel = 1,
        itemLevel = 20,
        stats = {},
    }
    for key, value in pairs(fields or {}) do
        item[key] = value
    end
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

return {
    ["trinket baseline uses its weaker owned slot"] = function()
        local entry = Boot()
        local first =
            Item({ equipLoc = "INVTYPE_TRINKET", stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local second =
            Item({ equipLoc = "INVTYPE_TRINKET", stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local candidate =
            Item({ equipLoc = "INVTYPE_TRINKET", stats = { ITEM_MOD_AGILITY_SHORT = 15 } })
        entry.bags = { gear = { first.link, second.link } }
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.baseline, 20, "weaker trinket")
        h.Equal(result.upgrade, true, "beats weaker trinket")
    end,
    ["one-hand candidate uses the better gain without reusing the main hand"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        local main = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONOFFHAND",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
        })
        local candidate = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6 },
        })
        entry.bags = { gear = { main.link, off.link } }
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.group, "offHand", "better gain is off hand")
        h.Equal(result.baseline, 5, "pair off hand, not the main hand")
        h.Equal(result.candidate, 6, "off-hand weight")
        h.Equal(result.upgrade, true, "off-hand upgrade")
    end,
    ["weapon fallback uses the higher item level of the winning pair"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        local main = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONMAINHAND",
            itemLevel = 20,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONOFFHAND",
            itemLevel = 50,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local candidate =
            Item({ classID = 2, subclassID = 15, equipLoc = "INVTYPE_2HWEAPON", itemLevel = 40 })
        entry.bags = { gear = { main.link, off.link } }
        LootLogicDB.settings.gear.itemLevelFallback = true
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.itemLevel, true, "fallback")
        h.Equal(result.baseline, 50, "higher item level of pair")
        h.Equal(result.upgrade, false, "candidate is lower")
    end,
    ["ring fallback uses the zero-scoring member of a positive-score pair"] = function()
        local entry = Boot()
        local positive = Item({ itemLevel = 10, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local zero = Item({ itemLevel = 50 })
        local candidate = Item({ itemLevel = 40 })
        entry.bags = { gear = { positive.link, zero.link } }
        LootLogicDB.settings.gear.itemLevelFallback = true
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.itemLevel, true, "fallback")
        h.Equal(result.baseline, 50, "zero-scoring ring is the weaker score member")
        h.Equal(result.upgrade, false, "item level is lower")
    end,
    ["mail copies rank after bag copies and exclude one attachment"] = function()
        local entry = Boot()
        local here = "Zugar Soulsour-Region"
        local character = LootLogicDB.characters[here]
        character.class = "DRUID"
        character.loadouts = { entry.loadouts[2] }
        local item = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        character.bags = { gear = { item.link } }
        character.inbox = { gear = { item.link } }
        local attachment = ns.ItemFacts.FromLink(item.link)
        local options = { loadout = entry.loadouts[2], fromInbox = true }
        h.Equal(
            ns.Scoring.Compare(attachment, here, options).baseline,
            20,
            "bag copy remains owned"
        )
        h.Equal(ns.Scoring.InUse(attachment, here, options).inUse, false, "bag copy wins")
    end,
    ["better-piece data covers rings and weapon sets"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        entry.loadouts = { entry.loadouts[2] }
        LootLogicDB.settings.gear.lookAheadLevels = 0
        local first = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 30 } })
        local second = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local old = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local weapon = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
        })
        local oldWeapon = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        entry.bags = { gear = { first.link, second.link, old.link, weapon.link, oldWeapon.link } }
        local ringResult = ns.Scoring.InUse(old, "druid")
        h.Equal(ringResult.better.item.link, second.link, "second ring is the one replacement")
        local weaponResult = ns.Scoring.InUse(oldWeapon, "druid")
        h.Equal(weaponResult.better.item.link, weapon.link, "winning weapon")
    end,
    ["a unique ring with a worn twin compares against that twin"] = function()
        local entry = Boot()
        local here = "Zugar Soulsour-Region"
        local character = LootLogicDB.characters[here]
        character.class = "DRUID"
        character.loadouts = { entry.loadouts[2] }
        local twin = Item({ unique = true, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local weak = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 2 } })
        character.gear = { slots = { [11] = twin.link, [12] = weak.link } }
        character.bags = { gear = { twin.link } }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, { itemID = twin.itemID, link = twin.link, count = 1 })
        local candidate = ns.ItemFacts.FromSlot(0, 1)
        local result = ns.Scoring.Compare(candidate, here, { loadout = entry.loadouts[2] })
        h.Equal(result.baseline, 40, "worn twin is baseline")
        h.Equal(result.upgrade, false, "duplicate does not replace weaker other ring")
    end,
    ["a piece loses protection only after every scored loadout replaces it"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2], entry.loadouts[3] }
        LootLogicDB.settings.gear.lookAheadLevels = 0
        local old = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_INTELLECT_SHORT = 20 },
        })
        local cat = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local healer = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_INTELLECT_SHORT = 30 },
        })
        entry.bags = { gear = { old.link, cat.link } }
        h.Equal(ns.Scoring.InUse(old, "druid").inUse, true, "restoration still wins")
        entry.bags.gear[3] = healer.link
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(old, "druid").inUse, false, "both replaced it")
    end,
    ["a stowed loadout reports the single better owned piece"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local best = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local older = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { best.link, older.link } }
        local result = ns.Scoring.InUse(older, "druid")
        h.Equal(result.inUse, false, "older piece is not protected")
        h.Equal(result.better.item.link, best.link, "better piece")
        h.Equal(result.better.where, "bags", "better location")
        h.Equal(result.better.loadout.name, "Cat", "loadout")
    end,
    ["weapon set protection follows the winning set at each level"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        entry.loadouts = { entry.loadouts[2] }
        LootLogicDB.settings.gear.lookAheadLevels = 1
        local main = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONMAINHAND",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONOFFHAND",
            reqLevel = 61,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local two = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
        })
        entry.bags = { gear = { main.link, off.link, two.link } }
        h.Equal(ns.Scoring.InUse(two, "druid").inUse, true, "two-hander wins now")
        h.Equal(ns.Scoring.InUse(main, "druid").inUse, true, "main wins later")
        h.Equal(ns.Scoring.InUse(off, "druid").inUse, true, "off wins later")
        entry.level = 61
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(two, "druid").inUse, false, "two-hander loses at every level")
    end,
    ["weapon partner is filtered at the candidate evaluated level"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        local main = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONMAINHAND",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONOFFHAND",
            reqLevel = 62,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
        })
        local early = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
        })
        local later = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            reqLevel = 62,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
        })
        entry.bags = { gear = { main.link, off.link } }
        local options = { loadout = entry.loadouts[2] }
        h.Equal(ns.Scoring.Compare(early, "druid", options).baseline, 30, "later partner excluded")
        h.Equal(ns.Scoring.Compare(later, "druid", options).baseline, 35, "later partner included")
    end,
    ["late owned loads invalidate only affected character generations"] = function()
        local entry = Boot()
        local here = "Zugar Soulsour-Region"
        LootLogicDB.characters[here].class = "DRUID"
        LootLogicDB.characters[here].loadouts = { entry.loadouts[2] }
        local owned = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local candidate = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        h.Stub.SetItemPending(owned.itemID, owned)
        entry.bags = { gear = { owned.link } }
        local options = { loadout = entry.loadouts[2] }
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).pending, true, "other pending")
        h.Stub.Advance(10)
        local hereGeneration = ns.Generations.Get("gearHere")
        local otherGeneration = ns.Generations.Get("gearOthers")
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(ns.Generations.Get("gearHere"), hereGeneration, "here unaffected")
        h.Equal(ns.Generations.Get("gearOthers"), otherGeneration + 1, "other invalidated")
    end,
    ["protection reuses each level selection for repeated candidates"] = function()
        local entry = Boot()
        entry.level = 20
        entry.loadouts = { entry.loadouts[2] }
        LootLogicDB.settings.gear.lookAheadLevels = 3
        local best = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local loser = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { best.link, loser.link } }
        local original, calls = ns.ItemFacts.FromLink, 0
        ns.ItemFacts.FromLink = function(link)
            calls = calls + 1
            return original(link)
        end
        h.Equal(ns.Scoring.InUse(loser, "druid").inUse, false, "loser")
        h.Equal(calls, 8, "two owned pieces at four levels")
        h.Equal(ns.Scoring.InUse(loser, "druid").inUse, false, "repeat")
        h.Equal(calls, 8, "no repeated owned reads")
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(loser, "druid").inUse, false, "after change")
        h.Equal(calls, 16, "each level refreshed")
        ns.ItemFacts.FromLink = original
    end,
    ["armour protection follows each loadout rule across level forty"] = function()
        local entry = Boot()
        entry.class = "SHAMAN"
        entry.level = 39
        entry.proficiency.spells = {}
        entry.loadouts = { { name = "Best", spec = "DRUID:cat", armor = "best" } }
        LootLogicDB.settings.gear.lookAheadLevels = 1
        local leather = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local mail = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 3,
            reqLevel = 40,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { leather.link, mail.link } }
        h.Equal(ns.Scoring.InUse(leather, "druid").inUse, true, "leather wins at 39")
        h.Equal(ns.Scoring.InUse(mail, "druid").inUse, true, "mail wins at 40")
        entry.level = 40
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(leather, "druid").inUse, false, "best armour excludes leather")
        entry.loadouts[2] = { name = "Any", spec = "DRUID:cat", armor = "any" }
        ns.Generations.Bump("loadouts")
        h.Equal(ns.Scoring.InUse(leather, "druid").inUse, true, "any armour retains leather")
    end,
    ["owned deadline starts at an earlier item facts request"] = function()
        local entry = Boot()
        local owned = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local candidate = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        h.Stub.SetItemPending(owned.itemID, owned)
        h.Equal(ns.ItemFacts.FromLink(owned.link).pending, true, "first request")
        h.Stub.Advance(9)
        entry.bags = { gear = { owned.link } }
        local options = { loadout = entry.loadouts[2] }
        h.Equal(
            ns.Scoring.Compare(candidate, "druid", options).pending,
            true,
            "still within first deadline"
        )
        h.Stub.Advance(1)
        h.Equal(
            ns.Scoring.Compare(candidate, "druid", options).baseline,
            0,
            "first deadline is shared"
        )
    end,
    ["unique rings never occupy both baseline slots"] = function()
        local entry = Boot()
        local unique = Item({ unique = true, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local other = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 8 } })
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        entry.bags = { gear = { unique.link, unique.link, other.link } }
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.baseline, 16, "different second ring")
        h.Equal(result.upgrade, true, "candidate beats it")
        local duplicate = ns.ItemFacts.FromLink(unique.link)
        h.Nil(
            ns.Scoring.Compare(duplicate, "druid", { loadout = entry.loadouts[2] }),
            "other already owns unique"
        )
    end,
    ["positive ties use item level only when enabled and zero never protects"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local a = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            itemLevel = 10,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        local b = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            itemLevel = 20,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        local zero = Item({ equipLoc = "INVTYPE_HEAD", subclassID = 2, itemLevel = 100 })
        entry.bags = { gear = { a.link, b.link, zero.link } }
        LootLogicDB.settings.gear.itemLevelFallback = false
        ns.Generations.Bump("settings")
        h.Equal(ns.Scoring.InUse(a, "druid").inUse, true, "first tie")
        h.Equal(ns.Scoring.InUse(b, "druid").inUse, true, "second tie")
        h.Equal(ns.Scoring.InUse(zero, "druid").inUse, false, "zero score")
        LootLogicDB.settings.gear.itemLevelFallback = true
        ns.Generations.Bump("settings")
        h.Equal(ns.Scoring.InUse(a, "druid").inUse, false, "lower item level loses")
        h.Equal(ns.Scoring.InUse(b, "druid").inUse, true, "higher item level wins")
    end,
    ["owned load before deadline retries without a late-load generation bump"] = function()
        local entry = Boot()
        local owned = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local candidate = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        h.Stub.SetItemPending(owned.itemID, owned)
        entry.bags = { gear = { owned.link } }
        local options = { loadout = entry.loadouts[2] }
        local generation = ns.Generations.Get("gearOthers")
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).pending, true, "pending")
        h.Stub.Advance(2)
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(ns.Generations.Get("gearOthers"), generation, "no late bump")
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).baseline, 40, "resolved")
        h.Stub.Advance(10)
        h.Equal(ns.Generations.Get("gearOthers"), generation, "cancelled deadline")
    end,
    ["identical bag copies protect and compare by slot order"] = function()
        local entry = Boot()
        local here = "Zugar Soulsour-Region"
        LootLogicDB.characters[here].class = "DRUID"
        LootLogicDB.characters[here].loadouts = { entry.loadouts[2] }
        local item = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        LootLogicDB.characters[here].bags = { gear = { item.link, item.link } }
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 2, { itemID = item.itemID, link = item.link, count = 1 })
        h.Stub.SetBagItem(0, 4, { itemID = item.itemID, link = item.link, count = 1 })
        local first = ns.ItemFacts.FromSlot(0, 2)
        local second = ns.ItemFacts.FromSlot(0, 4)
        local options = { loadout = entry.loadouts[2] }
        h.Equal(ns.Scoring.Compare(first, here, options).baseline, 0, "first excludes duplicates")
        h.Equal(ns.Scoring.Compare(second, here, options).baseline, 20, "second sees first")
        h.Equal(ns.Scoring.InUse(first, here).inUse, true, "first protected")
        h.Equal(ns.Scoring.InUse(second, here).inUse, false, "second not protected")
    end,
    ["protection keeps the winning progression across levels"] = function()
        local entry = Boot()
        entry.level = 20
        entry.loadouts = { entry.loadouts[2] }
        LootLogicDB.settings.gear.lookAheadLevels = 3
        local one = Item({
            reqLevel = 21,
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        local two = Item({
            reqLevel = 22,
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 15 },
        })
        local loser = Item({
            reqLevel = 22,
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 12 },
        })
        local three = Item({
            reqLevel = 23,
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        entry.bags = { gear = { one.link, two.link, loser.link, three.link } }
        h.Equal(ns.Scoring.InUse(one, "druid").inUse, true, "level 21 winner")
        h.Equal(ns.Scoring.InUse(two, "druid").inUse, true, "level 22 winner")
        h.Equal(ns.Scoring.InUse(three, "druid").inUse, true, "level 23 winner")
        h.Equal(ns.Scoring.InUse(loser, "druid").inUse, false, "inferior")
        LootLogicDB.settings.gear.hereWinsInLookAhead = false
        ns.Generations.Bump("settings")
        h.Equal(
            ns.Scoring.InUse(two, "druid").inUse,
            true,
            "priority setting does not disable protection"
        )
        LootLogicDB.settings.gear.lookAheadLevels = 1
        ns.Generations.Bump("settings")
        h.Equal(ns.Scoring.InUse(one, "druid").inUse, true, "window retains level 21")
        h.Equal(ns.Scoring.InUse(two, "druid").inUse, false, "window excludes level 22")
        entry.level = 22
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(one, "druid").inUse, false, "old winner loses after level up")
        h.Equal(ns.Scoring.InUse(two, "druid").inUse, true, "new current winner")
        LootLogicDB.settings.gear.lookAheadLevels = 0
        ns.Generations.Bump("settings")
        h.Equal(ns.Scoring.InUse(three, "druid").inUse, false, "zero-width window")
    end,
    ["unsupported and unset specs supply no protection while a supported one does"] = function()
        local entry = Boot()
        local item = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { item.link } }
        entry.loadouts =
            { { name = "Future", spec = "DRUID:future", worn = true }, { name = "Unset" } }
        local result = ns.Scoring.InUse(item, "druid")
        h.Equal(result.inUse, false, "no scored loadout")
        h.Nil(result.loadout, "no loadout named")
        entry.loadouts[3] = { name = "Cat", spec = "DRUID:cat" }
        ns.Generations.Bump("loadouts")
        result = ns.Scoring.InUse(item, "druid")
        h.Equal(result.inUse, true, "supported loadout protects")
        h.Equal(result.loadout, entry.loadouts[3], "names the supported loadout")
        h.Equal(entry.loadouts[1].spec, "DRUID:future", "saved spec unchanged")
    end,
    ["protection keeps the best two rings and never two copies of a unique ring"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local unique = Item({ unique = true, stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local second = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 8 } })
        local third = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 6 } })
        entry.bags = { gear = { unique.link, unique.link, second.link, third.link } }
        h.Equal(ns.Scoring.InUse(unique, "druid").inUse, true, "unique ring")
        h.Equal(ns.Scoring.InUse(second, "druid").inUse, true, "second slot is a different ring")
        h.Equal(ns.Scoring.InUse(third, "druid").inUse, false, "third ring loses")
    end,
    ["protection waits ten seconds for a loading owned piece"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local owned = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local other = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        h.Stub.SetItemPending(owned.itemID, owned)
        entry.bags = { gear = { owned.link, other.link } }
        h.Equal(ns.Scoring.InUse(other, "druid").pending, true, "pending")
        h.Stub.Advance(9)
        h.Equal(ns.Scoring.InUse(other, "druid").pending, true, "still pending")
        h.Stub.Advance(1)
        h.Equal(ns.Scoring.InUse(other, "druid").inUse, true, "omitted piece cannot block")
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        h.Equal(ns.Scoring.InUse(other, "druid").inUse, false, "late arrival recomputed")
    end,
    ["mixed armour rules protect leather under any and not under best at level forty"] = function()
        local entry = Boot()
        entry.class = "SHAMAN"
        entry.level = 40
        entry.proficiency.spells = {}
        LootLogicDB.settings.gear.lookAheadLevels = 0
        entry.loadouts = {
            { name = "Best", spec = "DRUID:cat", armor = "best" },
            { name = "Any", spec = "DRUID:bear", armor = "any" },
        }
        local leather = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        entry.bags = { gear = { leather.link } }
        local result = ns.Scoring.InUse(leather, "druid")
        h.Equal(result.inUse, true, "kept by the any-armour loadout")
        h.Equal(result.loadout, entry.loadouts[2], "names that loadout")
    end,
    ["a loaded owned piece with unreadable stats is left out after ten seconds"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local broken = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local candidate = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { broken.link } }
        local original = ns.Stats.Get
        ns.Stats.Get = function(link)
            if link == broken.link then
                return nil
            end
            return original(link)
        end
        local options = { loadout = entry.loadouts[1] }
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).pending, true, "waits")
        h.Stub.Advance(10)
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).baseline, 0, "left out")
        h.Equal(ns.Scoring.InUse(candidate, "druid").pending, nil, "protection resolves")
        ns.Stats.Get = original
    end,
    ["protection recomputes after a level-up with a primed cache"] = function()
        local entry = Boot()
        entry.level = 20
        entry.loadouts = { entry.loadouts[2] }
        LootLogicDB.settings.gear.lookAheadLevels = 1
        local low = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        local high = Item({
            reqLevel = 22,
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        entry.bags = { gear = { low.link, high.link } }
        h.Equal(ns.Scoring.InUse(low, "druid").inUse, true, "low wins at 20 and 21")
        h.Equal(ns.Scoring.InUse(high, "druid").inUse, false, "high is outside the window")
        entry.level = 22
        ns.Generations.Bump("gearOthers")
        h.Equal(ns.Scoring.InUse(low, "druid").inUse, false, "low loses once 22 is current")
        h.Equal(ns.Scoring.InUse(high, "druid").inUse, true, "high enters the window")
    end,
    ["weapon baseline compares a two-hander with two distinct one-hand pieces"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        local main = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
        })
        local candidate = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_2HWEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
        })
        entry.bags = { gear = { main.link, off.link } }
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = entry.loadouts[2] })
        h.Equal(result.baseline, 35, "main plus different off hand")
        h.Equal(result.upgrade, true, "two hand beats pair")
    end,
    ["ring baseline is the weaker of two and an empty slot is zero"] = function()
        local entry = Boot()
        local first = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local second = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 15 } })
        local options = { loadout = entry.loadouts[2] }
        entry.bags = { gear = { first.link } }
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).baseline, 0, "empty slot")
        entry.bags.gear[2] = second.link
        ns.Generations.Bump("gearOthers")
        local result = ns.Scoring.Compare(candidate, "druid", options)
        h.Equal(result.baseline, 20, "weaker ring")
        h.Equal(result.upgrade, true, "beats weaker ring")
    end,
    ["a negative second ring or trinket never lowers the baseline below zero"] = function()
        local entry = Boot()
        ns.WeightTables["DRUID:harm"] = { weights = { AGI = 2, STR = -1 }, percent = {} }
        local loadout = { name = "Harm", spec = "DRUID:harm" }
        entry.loadouts = { loadout }
        local good = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local harmful = Item({ stats = { ITEM_MOD_STRENGTH_SHORT = 5 } })
        local candidate = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        entry.bags = { gear = { good.link, harmful.link } }
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = loadout })
        h.Equal(result.baseline, 0, "harmful piece counts as an empty slot")
        h.Equal(result.upgrade, true, "positive candidate is an upgrade")
        h.Equal(result.gainPct, math.huge, "empty slot gain")
    end,
    ["surplus identical rings are not protected beyond the free slots"] = function()
        local entry = Boot()
        local here = "Zugar Soulsour-Region"
        LootLogicDB.characters[here].class = "DRUID"
        LootLogicDB.characters[here].loadouts = { entry.loadouts[2] }
        local best = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 20 } })
        local twin = Item({ stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
        LootLogicDB.characters[here].bags = { gear = { best.link, twin.link, twin.link } }
        h.Stub.SetBagSize(0, 6)
        h.Stub.SetBagItem(0, 1, { itemID = best.itemID, link = best.link, count = 1 })
        h.Stub.SetBagItem(0, 2, { itemID = twin.itemID, link = twin.link, count = 1 })
        h.Stub.SetBagItem(0, 4, { itemID = twin.itemID, link = twin.link, count = 1 })
        local first = ns.ItemFacts.FromSlot(0, 2)
        local second = ns.ItemFacts.FromSlot(0, 4)
        h.Equal(ns.Scoring.InUse(first, here).inUse, true, "first twin fills the second ring slot")
        h.Equal(ns.Scoring.InUse(second, here).inUse, false, "surplus twin is not protected")
    end,
    ["the worn loadout is named when it is among several winners"] = function()
        local entry = Boot()
        entry.loadouts = {
            { name = "Cat", spec = "DRUID:cat" },
            { name = "Restoration", spec = "DRUID:restoration", armor = "any", worn = true },
        }
        local chest = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_INTELLECT_SHORT = 10 },
        })
        entry.bags = { gear = { chest.link } }
        local result = ns.Scoring.InUse(chest, "druid")
        h.Equal(result.inUse, true, "wins")
        h.Equal(result.loadout.spec, "DRUID:restoration", "worn loadout named over the first")
    end,
    ["a unique one-hand weapon is not an upgrade next to its own twin"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        local here = "Zugar Soulsour-Region"
        LootLogicDB.characters[here].class = "ROGUE"
        LootLogicDB.characters[here].proficiency = { spells = { [674] = true, [9077] = true } }
        LootLogicDB.characters[here].loadouts = { entry.loadouts[2] }
        local twin = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            unique = true,
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        local off = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPONOFFHAND",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
        })
        LootLogicDB.characters[here].gear = { slots = { [16] = twin.link } }
        LootLogicDB.characters[here].bags = { gear = { off.link, twin.link } }
        h.Stub.SetBagSize(0, 4)
        h.Stub.SetBagItem(0, 1, { itemID = off.itemID, link = off.link, count = 1 })
        h.Stub.SetBagItem(0, 2, { itemID = twin.itemID, link = twin.link, count = 1 })
        local copy = ns.ItemFacts.FromSlot(0, 2)
        local result = ns.Scoring.Compare(copy, here, { loadout = entry.loadouts[2] })
        h.Equal(result.upgrade, false, "second copy cannot join the worn twin")
    end,
    ["a piece whose stats become readable after the leave-out is scored again"] = function()
        local entry = Boot()
        entry.loadouts = { entry.loadouts[2] }
        local late = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 20 },
        })
        local candidate = Item({
            equipLoc = "INVTYPE_CHEST",
            subclassID = 2,
            stats = { ITEM_MOD_AGILITY_SHORT = 10 },
        })
        entry.bags = { gear = { late.link } }
        local original = ns.Stats.Get
        local readable = false
        ns.Stats.Get = function(link)
            if link == late.link and not readable then
                return nil
            end
            return original(link)
        end
        local options = { loadout = entry.loadouts[1] }
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).pending, true, "waits")
        h.Stub.Advance(10)
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).baseline, 0, "left out")
        h.Equal(ns.Scoring.InUse(late, "druid").inUse, false, "not protected while unreadable")
        readable = true
        h.Equal(ns.Scoring.Compare(candidate, "druid", options).baseline, 40, "baseline recovers")
        h.Equal(ns.Scoring.InUse(late, "druid").inUse, true, "protection recovers")
        ns.Stats.Get = original
    end,
    ["a one-hand upgrade in one hand beats a non-upgrade in the other hand"] = function()
        local entry = Boot()
        entry.class = "ROGUE"
        entry.proficiency.spells[674] = true
        ns.WeightTables["DRUID:mhonly"] = { weights = { DPS_MH = 3 }, percent = {} }
        local loadout = { name = "MH only", spec = "DRUID:mhonly" }
        entry.loadouts = { loadout }
        local owned = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 },
        })
        local candidate = Item({
            classID = 2,
            subclassID = 15,
            equipLoc = "INVTYPE_WEAPON",
            stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 },
        })
        entry.bags = { gear = { owned.link } }
        LootLogicDB.settings.gear.itemLevelFallback = false
        local result = ns.Scoring.Compare(candidate, "druid", { loadout = loadout })
        h.Equal(result.upgrade, true, "the main-hand upgrade is kept")
        h.Equal(result.group, "mainHand", "main hand, not the zero-score off hand")
    end,
}
