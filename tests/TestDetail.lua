local _, ns, h = ...

local API = ns.API
local L = ns.L

local HERE = "Local Test-Realm"
local OTHER = "Alt Test-Realm"
local nextID = 180000

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = DeepCopy(inner)
    end
    return copy
end

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
    return here
end

local function Item()
    nextID = nextID + 1
    local item = {
        itemID = nextID,
        name = "Detail Item",
        quality = 1,
        itemLevel = 1,
        reqLevel = 0,
        sellPrice = 0,
        bindType = 0,
        classID = 7,
        subclassID = 5,
        link = "item:" .. nextID,
    }
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

return {
    ["detail exposes ordered wants and shared lines without changing saved data"] = function()
        Boot()
        local item = Item()
        LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
        LootLogicDB.characters[HERE].asks = { types = {}, items = {} }
        LootLogicDB.characters[HERE].asks.items[item.itemID] = "include"
        local before = DeepCopy(LootLogicDB)
        local result = API.ClassifyLink(item.link)
        h.Equal(result.detail.wants.winner, HERE, "current character wins wants")
        h.Equal(result.detail.wants.others[1].key, OTHER, "other wanter")
        local lines = ns.Detail.Lines(result)
        h.Equal(lines[1], result.line, "category line first")
        h.True(string.find(lines[2], "Wants: you", 1, true) ~= nil, "wants explanation")
        h.DeepEqual(LootLogicDB, before, "full saved tree unchanged")
    end,
    ["detail is attached for exact bag facts"] = function()
        Boot()
        local item = Item()
        LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
        h.Stub.SetBagSize(0, 2)
        h.Stub.SetBagItem(0, 1, {
            itemID = item.itemID,
            link = item.link,
            count = 7,
            quality = item.quality,
        })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.wants.winner, OTHER, "bag wants")
        h.Equal(result.detail.gearPending, false, "non-gear detail is ready")
    end,
    ["detail lines keep wants before descending gear and reserve runners and price"] = function()
        Boot()
        local result = {
            line = "LootLogic: Equip (reason)",
            reasonData = { runnerUps = { { key = OTHER, gainPct = 5 } } },
            detail = {
                wants = { winner = HERE, others = {} },
                gearPending = true,
                gear = {},
                price = {
                    source = "Auctionator",
                    unit = 1000,
                    ageDays = 0,
                    net = 950,
                    vendor = 100,
                    gainPerUnit = 850,
                    gainTotal = 850,
                    minGainCopper = 100,
                    minGainPct = 10,
                },
            },
        }
        for index = 1, 10 do
            result.detail.gear[index] = {
                key = HERE,
                loadout = "Loadout " .. index,
                gainPct = 20 - index,
                upgrade = true,
                baselineItem = {},
                baselineWhere = {},
            }
        end
        local lines = ns.Detail.Lines(result)
        h.Equal(lines[1], result.line, "category first")
        h.True(string.find(lines[2], "Wants: you", 1, true) ~= nil, "wants second")
        h.True(string.find(lines[3], "Loadout 1", 1, true) ~= nil, "largest gain first")
        h.True(string.find(lines[4], "(and 8 more)", 1, true) ~= nil, "removed gear count")
        h.True(string.find(lines[5], "Runners-up:", 1, true) ~= nil, "runner line after gear")
        h.True(
            string.find(lines[6], "Additional gear comparisons", 1, true) ~= nil,
            "pending line reserved"
        )
        h.Equal(#lines, 8, "eight logical lines")
    end,
    ["price detail includes source, age, net and holding calculations"] = function()
        Boot()
        local item = Item()
        item.sellPrice = 100
        h.Stub.SetItem(item.itemID, item)
        ns.Prices.Register({
            id = "detailtest",
            label = "DetailTest",
            honoursLastScan = false,
            IsAvailable = function()
                return true
            end,
            GetPrice = function()
                return { unit = 1000, ageDays = 0 }
            end,
        })
        h.Stub.SetBagSize(0, 2)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 7, quality = 1 })
        local result = API.ClassifyBagSlot(0, 1)
        local price = result.detail.price
        h.Equal(price.source, "DetailTest", "selected provider")
        h.Equal(price.gainTotal, price.gainPerUnit * 7, "whole holding calculation")
        local lines = ns.Detail.Lines(result)
        h.True(
            string.find(
                lines[#lines - 1],
                "Price: DetailTest, 10s each (today), net 9s 50c",
                1,
                true
            ) ~= nil,
            "complete price line"
        )
        h.True(string.find(lines[#lines], "Gain:", 1, true) ~= nil, "threshold line")
    end,
    ["stale price detail preserves the rejected quote and marks it stale"] = function()
        Boot()
        local item = Item()
        item.sellPrice = 100
        h.Stub.SetItem(item.itemID, item)
        ns.Prices.Register({
            id = "staletest",
            label = "StaleTest",
            honoursLastScan = false,
            IsAvailable = function()
                return true
            end,
            GetPrice = function()
                return { unit = 1000 }
            end,
        })
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 1, quality = 1 })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.reasonCode, "stale", "classification keeps stale verdict")
        h.Equal(result.detail.price.stale, true, "detail marks rejected quote")
        local lines = ns.Detail.Lines(result)
        h.True(string.find(lines[#lines - 1], "staletest", 1, true) ~= nil, "provider is retained")
        h.True(string.find(lines[#lines - 1], "(stale)", 1, true) ~= nil, "stale marker")
    end,
    ["negative price gains use signed money formatting"] = function()
        Boot()
        local result = {
            line = "LootLogic: Vendor (below threshold)",
            reasonData = {},
            detail = {
                gear = {},
                gearPending = false,
                price = {
                    source = "StaleTest",
                    unit = 50,
                    ageDays = 22,
                    net = 47,
                    vendor = 100,
                    gainPerUnit = -53,
                    gainTotal = -106,
                    minGainCopper = 100,
                    minGainPct = 10,
                    stale = true,
                },
            },
        }
        local lines = ns.Detail.Lines(result)
        h.True(
            string.find(lines[3], "-53c each, -1s 6c for the holding", 1, true) ~= nil,
            "negative amounts are signed"
        )
    end,
    ["inbox baseline location is rendered as mail without a bank age"] = function()
        Boot()
        local result = {
            line = "LootLogic: Equip (reason)",
            reasonData = {},
            detail = {
                gearPending = false,
                wants = nil,
                price = nil,
                gear = {
                    {
                        key = HERE,
                        loadout = "Test",
                        gainPct = -2,
                        upgrade = false,
                        baselineItem = { "Mail item" },
                        baselineWhere = { "inbox" },
                    },
                },
            },
        }
        local line = ns.Detail.Lines(result)[2]
        h.True(string.find(line, "Mail item, mail", 1, true) ~= nil, "inbox location wording")
        h.True(string.find(line, "bank", 1, true) == nil, "mail baseline has no bank age")
    end,
    ["link-only BoP and quest-bound wants do not name another-character winners"] = function()
        for _, bindType in ipairs({ 1, 4 }) do
            Boot()
            local item = Item()
            item.bindType = bindType
            h.Stub.SetItem(item.itemID, item)
            LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
            local result = API.ClassifyLink(item.link)
            h.Equal(
                result.detail.wants.winner,
                L.detailWantNoWinner,
                "blocked bind type " .. bindType
            )
            h.Equal(
                result.detail.wants.others[1].why,
                L.detailWantBound,
                "bound explanation " .. bindType
            )
        end
    end,
    ["link-only account-bound items remain eligible want winners"] = function()
        Boot()
        local item = Item()
        item.bindType = 7
        h.Stub.SetItem(item.itemID, item)
        LootLogicDB.characters[OTHER].asks.items[item.itemID] = "include"
        local result = API.ClassifyLink(item.link)
        h.Equal(result.detail.wants.winner, OTHER, "account-bound is tradable for routing")
    end,
    ["gear detail exposes score values and the empty baseline"] = function()
        local here = Boot()
        local item = Item()
        item.classID = 4
        item.subclassID = 2
        item.equipLoc = "INVTYPE_CHEST"
        item.stats = { ITEM_MOD_STRENGTH_SHORT = 20 }
        h.Stub.SetItem(item.itemID, item)
        ns.WeightTables["WARRIOR:detail"] = { weights = { STR = 1 }, percent = {} }
        ns.WeightTables["WARRIOR:detail2"] = { weights = { STR = 2 }, percent = {} }
        ns.WeightTables["WARRIOR:detail-ilvl"] = { weights = {}, percent = {} }
        here.loadouts = {
            { name = "Test", spec = "WARRIOR:detail", worn = true, armor = "any", assumed = true },
            { name = "Duplicate", spec = "WARRIOR:detail", armor = "any" },
            { name = "Distinct", spec = "WARRIOR:detail2", armor = "any" },
            { name = "Item level", spec = "WARRIOR:detail-ilvl", armor = "any" },
        }
        h.Stub.SetKnownSpells({ 9077 })
        h.Stub.SetBagSize(0, 2)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 1, quality = 1 })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.reasonCode, "equip", "existing classifier chooses Equip")
        h.Equal(#result.detail.gear, 3, "duplicate spec and armour comparison is collapsed")
        h.Equal(result.detail.gear[1].candidate, 20, "candidate is the numeric score")
        h.Equal(result.detail.gear[1].baseline, 0, "empty baseline score")
        h.Equal(#result.detail.gear[1].baselineItem, 0, "empty baseline has no named item")
        h.Equal(result.detail.gear[1].assumed, true, "assumed spec flag")
        h.Equal(result.detail.gear[3].itemLevel, true, "item-level fallback flag")
        local lines = ns.Detail.Lines(result)
        h.True(string.find(lines[2], "(assumed)", 1, true) ~= nil, "assumed label rendered")
        h.True(string.find(lines[4], "(ilvl)", 1, true) ~= nil, "item-level label rendered")
    end,
    ["gearfor detail compares the recipient's loadouts"] = function()
        local here = Boot()
        local other = LootLogicDB.characters[OTHER]
        here.loadouts = { { name = "Unset" } }
        other.loadouts = { { name = "Priest", spec = "PRIEST:detail", worn = true, armor = "any" } }
        ns.WeightTables["PRIEST:detail"] = { weights = { INT = 1 }, percent = {} }
        local item = Item()
        item.classID = 4
        item.subclassID = 1
        item.equipLoc = "INVTYPE_CHEST"
        item.stats = { ITEM_MOD_INTELLECT_SHORT = 20 }
        h.Stub.SetItem(item.itemID, item)
        local result = API.ClassifyLink(item.link)
        h.Equal(result.reasonCode, "gearfor", "existing classifier routes to the scored recipient")
        h.Equal(result.category, "char:" .. OTHER, "recipient wins")
        h.Equal(#result.detail.gear, 1, "recipient comparisons are shown")
        h.Equal(result.detail.gear[1].key, OTHER, "detail is for the winner")
        h.Equal(result.detail.gear[1].loadout, "Priest", "recipient loadout is named")
    end,
    ["gear comparisons sort by full precision before display rounding"] = function()
        local here = Boot()
        ns.WeightTables["WARRIOR:tiny"] = { weights = { STR = 1, AGI = 100 }, percent = {} }
        ns.WeightTables["WARRIOR:precise"] = { weights = { STR = 1, AGI = 1 }, percent = {} }
        here.loadouts = {
            { name = "Tiny", spec = "WARRIOR:tiny", worn = true, armor = "any" },
            { name = "Precise", spec = "WARRIOR:precise", armor = "any" },
        }
        local owned = Item()
        owned.classID = 4
        owned.subclassID = 2
        owned.equipLoc = "INVTYPE_CHEST"
        owned.stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10 }
        h.Stub.SetItem(owned.itemID, owned)
        local candidate = Item()
        candidate.classID = 4
        candidate.subclassID = 2
        candidate.equipLoc = "INVTYPE_CHEST"
        candidate.stats = { ITEM_MOD_STRENGTH_SHORT = 10.004, ITEM_MOD_AGILITY_SHORT = 10 }
        h.Stub.SetItem(candidate.itemID, candidate)
        here.bags = { gear = { owned.link } }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, {
            itemID = candidate.itemID,
            link = candidate.link,
            count = 1,
            quality = 1,
        })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].loadout, "Precise", "larger full-precision gain sorts first")
        h.Equal(result.detail.gear[2].loadout, "Tiny", "small full-precision gain sorts second")
        h.True(
            result.detail.gear[1].gainPct > result.detail.gear[2].gainPct,
            "full-precision gains differ"
        )
        local lines = ns.Detail.Lines(result)
        h.True(
            string.find(lines[2], "Precise: 0%", 1, true) ~= nil,
            "precise is first despite rounded display"
        )
        h.True(string.find(lines[3], "Tiny: 0%", 1, true) ~= nil, "tiny gain is second")
    end,
    ["zero and negative loadout gains sort with zero first"] = function()
        local here = Boot()
        ns.WeightTables["WARRIOR:below"] = { weights = { STR = 1 }, percent = {} }
        ns.WeightTables["WARRIOR:equal"] = { weights = { AGI = 1 }, percent = {} }
        here.loadouts = {
            { name = "Below", spec = "WARRIOR:below", worn = true, armor = "any" },
            { name = "Equal", spec = "WARRIOR:equal", armor = "any" },
        }
        local owned = Item()
        owned.classID = 4
        owned.subclassID = 2
        owned.equipLoc = "INVTYPE_CHEST"
        owned.stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10 }
        h.Stub.SetItem(owned.itemID, owned)
        local candidate = Item()
        candidate.classID = 4
        candidate.subclassID = 2
        candidate.equipLoc = "INVTYPE_CHEST"
        candidate.stats = { ITEM_MOD_STRENGTH_SHORT = 9.9, ITEM_MOD_AGILITY_SHORT = 10 }
        h.Stub.SetItem(candidate.itemID, candidate)
        here.bags = { gear = { owned.link } }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, {
            itemID = candidate.itemID,
            link = candidate.link,
            count = 1,
            quality = 1,
        })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].loadout, "Equal", "zero gain sorts first")
        h.Equal(result.detail.gear[1].gainPct, 0, "equal score has zero gain")
        h.Equal(result.detail.gear[2].loadout, "Below", "loss sorts second")
        h.True(result.detail.gear[2].gainPct < 0, "weaker candidate keeps negative gain")
    end,
    ["weapon pair detail exposes both baseline pieces and locations"] = function()
        local here = Boot()
        here.class = "ROGUE"
        here.proficiency = { spells = { [674] = true } }
        ns.WeightTables["ROGUE:detail"] = {
            weights = { DPS_MH = 3, DPS_OH = 1 },
            percent = {},
        }
        here.loadouts = { { name = "Combat", spec = "ROGUE:detail", worn = true } }
        h.Stub.SetPlayer({ class = "ROGUE" })
        h.Stub.SetKnownSpells({ 674 })
        local function Weapon(id, name, equipLoc, dps)
            local weapon = {
                itemID = id,
                name = name,
                link = "item:" .. id,
                quality = 1,
                itemLevel = 20,
                reqLevel = 1,
                sellPrice = 0,
                bindType = 0,
                classID = 2,
                subclassID = 15,
                equipLoc = equipLoc,
                stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = dps },
            }
            h.Stub.SetItem(id, weapon)
            h.Stub.SetTooltipLines(weapon.link, {})
            return weapon
        end
        local main = Weapon(181101, "Main Blade", "INVTYPE_WEAPON", 10)
        local off = Weapon(181102, "Off Blade", "INVTYPE_WEAPON", 5)
        local candidate = Weapon(181103, "Great Blade", "INVTYPE_2HWEAPON", 12)
        here.bags = { gear = { main.link } }
        here.bank = { gear = { off.link }, updatedAt = GetServerTime() - 86400 }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, {
            itemID = candidate.itemID,
            link = candidate.link,
            count = 1,
            quality = 1,
        })
        local result = API.ClassifyBagSlot(0, 1)
        local gear = result.detail.gear[1]
        h.Equal(gear.candidate, 36, "candidate score")
        h.Equal(gear.baseline, 35, "pair baseline score")
        h.DeepEqual(gear.baselineItem, { "Main Blade", "Off Blade" }, "both baseline items")
        h.DeepEqual(gear.baselineWhere, { "bags", "bank" }, "both baseline locations")
        local lines = ns.Detail.Lines(result)
        h.True(
            string.find(lines[2], "Main Blade, bags and Off Blade, bank", 1, true) ~= nil,
            "pair rendered with both locations"
        )
        h.True(
            string.find(lines[2], "bank seen 1 d ago", 1, true) ~= nil,
            "second pair location carries bank age"
        )
    end,
    ["bank baseline age refreshes with time and reports a missing timestamp"] = function()
        local here = Boot()
        local candidate = Item()
        candidate.classID = 4
        candidate.subclassID = 2
        candidate.equipLoc = "INVTYPE_CHEST"
        candidate.stats = { ITEM_MOD_STRENGTH_SHORT = 20 }
        h.Stub.SetItem(candidate.itemID, candidate)
        local owned = Item()
        owned.classID = 4
        owned.subclassID = 2
        owned.equipLoc = "INVTYPE_CHEST"
        owned.stats = { ITEM_MOD_STRENGTH_SHORT = 10 }
        h.Stub.SetItem(owned.itemID, owned)
        ns.WeightTables["WARRIOR:detail"] = { weights = { STR = 1 }, percent = {} }
        here.loadouts = { { name = "Test", spec = "WARRIOR:detail", worn = true, armor = "any" } }
        here.bank = { gear = { owned.link }, updatedAt = GetServerTime() - 3 * 86400 }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, {
            itemID = candidate.itemID,
            link = candidate.link,
            count = 1,
            quality = 1,
        })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].bankAge, 3, "initial snapshot age")
        h.Stub.Advance(2 * 86400)
        result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].bankAge, 5, "cached verdict gets current bank age")
        here.bank.gear = {}
        ns.Generations.Bump("gearHere")
        result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].baseline, 0, "updated owned gear refreshes the baseline")
        here.loadouts = {
            { name = "Updated", spec = "WARRIOR:detail", worn = true, armor = "any" },
        }
        ns.Generations.Bump("loadouts")
        result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.detail.gear[1].loadout, "Updated", "cached result reads current loadouts")
        local noTimestamp = {
            line = result.line,
            reasonData = {},
            detail = {
                gearPending = false,
                gear = {
                    {
                        key = HERE,
                        loadout = "Test",
                        gainPct = 5,
                        upgrade = false,
                        baselineItem = { "Bank item" },
                        baselineWhere = { "bank" },
                        bankAge = nil,
                    },
                },
            },
        }
        h.True(
            string.find(ns.Detail.Lines(noTimestamp)[2], "bank not seen", 1, true) ~= nil,
            "missing timestamp wording"
        )
    end,
    ["detail performs no persistent write in a read-only schema session"] = function()
        LootLogicDB = h.Fixture("dbNewer")
        h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
        local item = Item()
        local before = DeepCopy(LootLogicDB)
        API.ClassifyLink(item.link)
        h.DeepEqual(LootLogicDB, before, "read-only saved data unchanged")
    end,
    ["detail performs no persistent write in an ordinary schema session"] = function()
        Boot()
        local item = Item()
        LootLogicDB.characters[HERE].asks = { types = {}, items = {} }
        LootLogicDB.characters[HERE].asks.items[item.itemID] = "include"
        local before = DeepCopy(LootLogicDB)
        API.ClassifyLink(item.link)
        h.DeepEqual(LootLogicDB, before, "ordinary saved data unchanged")
    end,
    ["on-demand price detail refreshes after a cached hard-stay verdict"] = function()
        Boot()
        local item = Item()
        item.classID = 12
        item.sellPrice = 100
        h.Stub.SetItem(item.itemID, item)
        local unit = 1000
        ns.Prices.Register({
            id = "freshdetail",
            label = "FreshDetail",
            honoursLastScan = false,
            IsAvailable = function()
                return true
            end,
            GetPrice = function()
                return { unit = unit, ageDays = 0 }
            end,
        })
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, { itemID = item.itemID, link = item.link, count = 1, quality = 1 })
        local result = API.ClassifyBagSlot(0, 1)
        local reason = result.reasonCode
        h.Equal(result.detail.price.unit, 1000, "initial quote")
        unit = 2000
        result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.reasonCode, reason, "hard-stay verdict remains unchanged")
        h.Equal(result.detail.price.unit, 2000, "on-demand price is refreshed")
    end,
    ["detail indicates additional gear comparisons are pending without hiding verdict"] = function()
        local here = Boot()
        local candidate = Item()
        candidate.classID = 4
        candidate.subclassID = 2
        candidate.equipLoc = "INVTYPE_CHEST"
        candidate.stats = { ITEM_MOD_STRENGTH_SHORT = 20 }
        h.Stub.SetItem(candidate.itemID, candidate)
        local owned = Item()
        owned.classID = 4
        owned.subclassID = 2
        owned.equipLoc = "INVTYPE_CHEST"
        owned.stats = { ITEM_MOD_STRENGTH_SHORT = 10 }
        h.Stub.SetItemPending(owned.itemID, owned)
        ns.WeightTables["WARRIOR:detail"] = { weights = { STR = 1 }, percent = {} }
        here.loadouts = { { name = "Test", spec = "WARRIOR:detail", worn = true, armor = "any" } }
        here.bags = { gear = { owned.link } }
        here.protect = { [tostring(candidate.itemID)] = true }
        h.Stub.SetBagSize(0, 1)
        h.Stub.SetBagItem(0, 1, {
            itemID = candidate.itemID,
            link = candidate.link,
            count = 1,
            quality = 1,
        })
        local result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.reasonCode, "protected", "existing protected verdict remains")
        h.Equal(result.detail.gearPending, true, "extra comparison pending")
        h.True(
            string.find(
                table.concat(ns.Detail.Lines(result), "\n"),
                "Additional gear comparisons are loading",
                1,
                true
            ) ~= nil,
            "loading is visible"
        )
        h.Stub.LoadItem(owned.itemID)
        h.Stub.Advance(ns.ItemFacts.BATCH_SECONDS)
        result = API.ClassifyBagSlot(0, 1)
        h.Equal(result.reasonCode, "protected", "verdict remains the same after recovery")
        h.Equal(result.detail.gearPending, false, "detail comparison recovers")
    end,
}
