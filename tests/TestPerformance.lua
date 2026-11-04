local _, ns, h = ...

-- The performance smoke test of technical findings 17.1: 4 characters x 140
-- slots in plain Lua 5.1, a loose proxy for the client, unverified until live
-- check L35. Warm passes (baselines built) are held to under 50 ms. The cold
-- first pass has no per-pass target (it is batched across frames under the
-- 10 ms budget; about 250 ms here is acceptable). The cached pass is held only
-- to the same loose 50 ms: the documented figure of about 1 ms per 100 slots
-- is not reliable to assert in plain Lua, so the cached cases assert that no
-- scoring happens instead. Only the classification is timed; the fixture is
-- built before the clock starts.

local Classify = ns.Classify
local Generations = ns.Generations

local fixture = h.Fixture("scoring")

local HERE = "Zugar Soulsour-Region"
local BONESET = "Boneset Hallowine-Region"
local CHAM = "Chamoomile Rejuvenade-Region"
local WARLOCK = "Wormwood Hexbane-Region"

local TARGET_SECONDS = 0.050
local SLOTS = 140
local BAGS = 5
local PER_BAG = SLOTS / BAGS

-- Leather slots a druid wears, then neck, ring and trinket (4:0, no
-- proficiency needed).
local GROUPS = {
    { "INVTYPE_HEAD", 2 },
    { "INVTYPE_SHOULDER", 2 },
    { "INVTYPE_CHEST", 2 },
    { "INVTYPE_WRIST", 2 },
    { "INVTYPE_HAND", 2 },
    { "INVTYPE_WAIST", 2 },
    { "INVTYPE_LEGS", 2 },
    { "INVTYPE_FEET", 2 },
    { "INVTYPE_NECK", 0 },
    { "INVTYPE_FINGER", 0 },
    { "INVTYPE_TRINKET", 0 },
}

local LEVELS = { 50, 60, 61, 62, 64 }
local nextID = 99000

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
        classID = 4,
        stats = {},
    }
    for key, value in pairs(fields) do
        item[key] = value
    end
    h.Stub.SetItem(item.itemID, item)
    h.Stub.SetTooltipLines(item.link, {})
    return item
end

-- 4 characters: here (Bear and Cat) and three others, one with two loadouts
-- and one with three, each owning pieces in every slot. 140 bag items in the
-- 11 groups with required levels 45 to 65 around here's level 60 (so the
-- progression window of 5 matters), many sharing a level.
local function Build()
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
    here.proficiency = { spells = { [9077] = true } }
    here.loadouts = {
        { name = "Bear", spec = "DRUID:bear", worn = true },
        { name = "Cat", spec = "DRUID:cat" },
    }
    here.gear = { slots = {} }
    here.bags = { gear = {} }
    local function Add(key, first, last, loadouts)
        LootLogicDB.characters[key] = {
            first = first,
            last = last,
            class = "DRUID",
            level = 60,
            faction = here.faction,
            region = here.region,
            proficiency = { spells = { [9077] = true } },
            loadouts = loadouts,
            bags = { gear = {} },
        }
    end
    Add(BONESET, "Boneset", "Hallowine", { { name = "Cat", spec = "DRUID:cat", worn = true } })
    Add(CHAM, "Chamoomile", "Rejuvenade", {
        { name = "Cat", spec = "DRUID:cat", worn = true },
        { name = "Bear", spec = "DRUID:bear" },
    })
    Add(WARLOCK, "Wormwood", "Hexbane", {
        { name = "Cat", spec = "DRUID:cat", worn = true },
        { name = "Bear", spec = "DRUID:bear" },
        { name = "Restoration", spec = "DRUID:restoration", armor = "any" },
    })
    LootLogicDB.order = { BONESET, CHAM, WARLOCK, HERE }
    LootLogicDB.settings.gear.itemLevelFallback = false
    LootLogicDB.settings.gear.lookAheadLevels = 5
    Generations.Bump("roster")
    -- Owned pieces: every other character owns one piece per group (two for
    -- rings and trinkets); here wears a piece per group and carries the 140.
    for _, group in ipairs(GROUPS) do
        local equipLoc, subclass = group[1], group[2]
        for _, key in ipairs({ BONESET, CHAM, WARLOCK }) do
            local gear = LootLogicDB.characters[key].bags.gear
            for copy = 1, 2 do
                local owned = Define({
                    equipLoc = equipLoc,
                    subclassID = subclass,
                    reqLevel = 40,
                    stats = { ITEM_MOD_AGILITY_SHORT = 10 + copy, ITEM_MOD_STAMINA_SHORT = 5 },
                })
                gear[#gear + 1] = owned.link
            end
        end
    end
    for slot = 1, BAGS do
        h.Stub.SetBagSize(slot - 1, PER_BAG)
    end
    local placed = 0
    for index = 0, SLOTS - 1 do
        local group = GROUPS[(index % #GROUPS) + 1]
        local item = Define({
            equipLoc = group[1],
            subclassID = group[2],
            reqLevel = LEVELS[(index % #LEVELS) + 1],
            stats = {
                ITEM_MOD_AGILITY_SHORT = 5 + (index % 17),
                ITEM_MOD_STAMINA_SHORT = (index * 3) % 11,
                ITEM_MOD_INTELLECT_SHORT = index % 7,
            },
        })
        local bag = math.floor(index / PER_BAG)
        h.Stub.SetBagItem(bag, (index % PER_BAG) + 1, {
            itemID = item.itemID,
            link = item.link,
            count = 1,
            quality = 2,
        })
        local gear = here.bags.gear
        gear[#gear + 1] = item.link
        placed = placed + 1
    end
    Generations.Bump("gearHere")
    Generations.Bump("gearOthers")
    return placed
end

-- The result of every slot, in order.
local function Results()
    local results = {}
    for bag = 0, BAGS - 1 do
        for slot = 1, PER_BAG do
            results[#results + 1] = Classify.BagSlot(bag, slot)
        end
    end
    return results
end

-- Seconds of CPU time spent in fn (plain Lua 5.1 os.clock).
local function Timed(fn)
    local started = os.clock()
    fn()
    return os.clock() - started
end

-- Counts the calls of Scoring.Compare, which every uncached gear verdict makes.
local function CountCompares()
    local calls = { count = 0 }
    local original = ns.Scoring.Compare
    ns.Scoring.Compare = function(...)
        calls.count = calls.count + 1
        return original(...)
    end
    return calls
end

-- Counts the baselines built: Scoring.BuildBaseline is local, so this counts
-- the Scoring.Score calls for owned pieces (required level 40 in this fixture),
-- which only a baseline build makes.
local function CountBaselineScores()
    local calls = { count = 0 }
    local original = ns.Scoring.Score
    ns.Scoring.Score = function(item, ...)
        if item.reqLevel == 40 then
            calls.count = calls.count + 1
        end
        return original(item, ...)
    end
    return calls
end

local function Verdicts(results)
    local list = {}
    for index, result in ipairs(results) do
        list[index] = result.category .. "/" .. result.reasonCode
    end
    return list
end

return {
    -- The cold first pass of a session builds every baseline from the owned
    -- pieces and has no per-pass target (technical findings 17.1: batched
    -- across frames; about 250 ms in this proxy is acceptable). The warm
    -- target of 50 ms is held for the work that follows, with the baselines
    -- built.
    ["Performance: 4 x 140 slots recompute in under 50 ms over built baselines"] = function()
        h.Equal(Build(), SLOTS, "fixture size")
        Classify.Pass("bags")
        local first = Results()
        h.Equal(#first, SLOTS, "every slot has a result")
        local seen = {}
        for _, result in ipairs(first) do
            seen[result.reasonCode] = true
        end
        h.True(seen.equip, "an Equip verdict was made")
        h.True(seen.equipat, "a look-ahead verdict was made")
        h.True(seen.gearfor, "a gearfor verdict was made")
        ns.Cache.Clear()
        local seconds = Timed(function()
            Classify.Pass("bags")
        end)
        h.True(seconds < TARGET_SECONDS, string.format("recompute took %.1f ms", seconds * 1000))
        h.DeepEqual(Verdicts(Results()), Verdicts(first), "the same verdicts")
    end,

    ["Performance: a second pass reads the cache; a cleared cache reuses baselines"] = function()
        Build()
        Classify.Pass("bags")
        local first = Results()
        local calls = CountCompares()
        local seconds = Timed(function()
            Classify.Pass("bags")
        end)
        h.Equal(calls.count, 0, "cached results are not scored again")
        -- Loose bound only; the cached figure (about 1 ms per 100 slots) is
        -- not asserted because plain Lua timing is not reliable at that scale.
        h.True(seconds < TARGET_SECONDS, string.format("cached pass took %.1f ms", seconds * 1000))
        local second = Results()
        for index = 1, SLOTS do
            h.True(first[index] == second[index], "same result table at slot " .. index)
        end
        local built = CountBaselineScores()
        ns.Cache.Clear()
        seconds = Timed(function()
            Classify.Pass("bags")
        end)
        h.True(calls.count > 0, "a cleared result cache scores again")
        h.Equal(built.count, 0, "no baseline is built again over unchanged owned data")
        h.True(seconds < TARGET_SECONDS, string.format("rebuilt pass took %.1f ms", seconds * 1000))
        h.DeepEqual(Verdicts(Results()), Verdicts(first), "the same verdicts")
    end,

    ["Performance: a level-up, the window and owned data invalidate the results"] = function()
        Build()
        Classify.Pass("bags")
        local before = Results()
        local verdicts = Verdicts(before)
        -- Owned data of another character: only results that reached step 3b
        -- used it.
        Generations.Bump("gearOthers")
        local after = Results()
        local recomputed, kept = 0, 0
        for index = 1, SLOTS do
            if after[index] == before[index] then
                kept = kept + 1
            else
                recomputed = recomputed + 1
            end
        end
        h.True(recomputed > 0, "results that used gearOthers are recomputed")
        h.True(kept > 0, "results decided before 3b are kept")
        h.DeepEqual(Verdicts(after), verdicts, "no data changed, same verdicts")
        -- The window: a window of 0 leaves nothing above here's level.
        LootLogicDB.settings.gear.lookAheadLevels = 0
        Generations.Bump("settings")
        local narrow = Results()
        for index = 1, SLOTS do
            h.True(narrow[index] ~= after[index], "settings used by every gear result")
        end
        local changed = 0
        for index, text in ipairs(Verdicts(narrow)) do
            if text ~= verdicts[index] then
                changed = changed + 1
            end
        end
        h.True(changed > 0, "a narrower window changes verdicts")
        -- A level-up moves the evaluated levels.
        LootLogicDB.settings.gear.lookAheadLevels = 5
        Generations.Bump("settings")
        local wide = Results()
        h.DeepEqual(Verdicts(wide), verdicts, "the window back, the verdicts back")
        h.Stub.SetPlayer({ level = 64 })
        LootLogicDB.characters[HERE].level = 64
        Generations.Bump("gearHere")
        local leveled = Results()
        local moved = 0
        for index, text in ipairs(Verdicts(leveled)) do
            if text ~= verdicts[index] then
                moved = moved + 1
            end
        end
        h.True(moved > 0, "a level-up changes verdicts")
    end,

    ["Performance: items sharing a required level and slot share their baselines"] = function()
        Build()
        local compares = CountCompares()
        local built = CountBaselineScores()
        Classify.Pass("bags")
        h.True(compares.count > 0, "scored")
        local first = built.count
        h.True(first > 0, "the first pass built baselines")
        -- Far fewer than one build per item: 140 items share baselines by
        -- required level, group and spec.
        local owned = 3 * 11 * 2
        local loadouts = 2 + 1 + 2 + 3
        local levels = #LEVELS * 2
        h.True(
            first <= owned * loadouts * levels,
            "baselines are shared, not built per item (" .. first .. " owned scores)"
        )
        -- A second cold result cache over unchanged owned data builds none.
        ns.Cache.Clear()
        Classify.Pass("bags")
        h.Equal(built.count, first, "no baseline is built again")
    end,
}
