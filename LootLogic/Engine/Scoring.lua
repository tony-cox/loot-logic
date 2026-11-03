--[[
Scores, usability and single-slot comparisons (spec 8.1 to 8.5 and 8.7).
Weapon pairs, two-slot baselines and in-use protection are built separately.
]]

local _, ns = ...

local Scoring = {}
ns.Scoring = Scoring

local DB = ns.DB
local Generations = ns.Generations
local ItemClasses = ns.ItemClasses
local ItemFacts = ns.ItemFacts
local Proficiency = ns.Proficiency
local Roster = ns.Roster
local Slots = ns.Slots
local Stats = ns.Stats
local WeightTables = ns.WeightTables

-- Level-60 conversions, source-read in the sim, unverified in game (L20).
-- Until L20, the same values apply at every character level (spec 8.2).
local RATING_PER_PERCENT = { HIT = 10, CRIT = 14, HASTE = 10, DODGE = 12, PARRY = 15, BLOCK = 5 }
local ARMOR_SPELLS = { 9078, 9077, 8737, 750 }
local RELIC_CLASSES = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }
local normalized = {}
local baselines = {}

local function Weights(spec)
    local source = WeightTables[spec]
    local entry = normalized[spec]
    if entry and entry.source == source then
        return entry.weights
    end
    local weights = {}
    for key, value in pairs(source.weights) do
        weights[key] = value
    end
    for _, key in ipairs(source.percent) do
        weights[key] = weights[key] / RATING_PER_PERCENT[key]
    end
    normalized[spec] = { source = source, weights = weights }
    return weights
end

--- The weighted score and whether any nonzero-weight stat is present.
-- @param item table item facts with a link and equipLoc
-- @param spec string|nil spec id; nil is not scored
-- @param hand string|nil slot group when judging a weapon
-- @treturn number|nil score; nil for no spec or unloaded stats
-- @treturn boolean|nil whether item level must not replace the score
function Scoring.Score(item, spec, hand)
    if not spec then
        return nil
    end
    local stats = Stats.Get(item.link)
    if not stats then
        return nil
    end
    local weights = Weights(spec)
    local score = 0
    local weighted = false
    for key, value in pairs(stats) do
        if key == "DPS" then
            local group = hand or Slots.invTypeGroup[item.equipLoc]
            key = "DPS_MH"
            if group == "offHand" then
                key = "DPS_OH"
            elseif group == "ranged" then
                key = "DPS_RANGED"
            end
        end
        local weight = weights[key] or 0
        if weight ~= 0 and value ~= 0 then
            weighted = true
        end
        score = score + weight * value
    end
    return score, weighted
end

--- The loadout's effective best-armour rule.
-- @param loadout table saved loadout
-- @treturn boolean
function Scoring.BestArmorOnly(loadout)
    if loadout.armor then
        return loadout.armor == "best"
    end
    return DB.Data().settings.gear.bestArmorOnly
end

local function Knows(key, spell)
    if Roster.IsHere(key) then
        return IsPlayerSpell(spell)
    end
    local proficiency = Roster.Entry(key).proficiency
    return proficiency and proficiency.spells[spell] or false
end

local function BestArmor(key, level)
    local class = Proficiency.classes[Roster.Entry(key).class]
    for rank = 4, 1, -1 do
        local trainingLevel = class.armor["4:" .. rank]
        if Knows(key, ARMOR_SPELLS[rank]) or (trainingLevel and trainingLevel <= level) then
            return rank
        end
    end
    return 0
end

local function IsArmorGroup(group)
    for _, armorGroup in ipairs(Slots.armorGroups) do
        if group == armorGroup then
            return true
        end
    end
    return false
end

--- The scoring slot group, or nil for ignored gear and profession tools.
-- @param item table item facts
-- @treturn string|nil
function Scoring.Group(item)
    if ItemClasses.tools[item.itemID] then
        return nil
    end
    if item.classID == 2 and (item.subclassID == 14 or item.subclassID == 20) then
        return nil
    end
    if item.classID == 4 and item.subclassID == 5 then
        return nil
    end
    return Slots.invTypeGroup[item.equipLoc]
end

--- Whether gear is usable, and the proficiency spell IDs to train first.
--- The optional live answer is from memory, unverified (L5); when absent,
--- proficiency is the fallback. Trainable types override a negative answer.
-- @param item table item facts
-- @param key string character key
-- @param options table loadout, lookAhead, hand and worn (baseline only)
-- @treturn boolean|nil nil while the item's usability facts are unreadable
-- @treturn table list of training spell IDs
function Scoring.CanUse(item, key, options)
    if item.pending or item.tooltipUnread then
        return nil, {}
    end
    local entry = Roster.Entry(key)
    local group = Scoring.Group(item)
    local train = {}
    if not group or (item.classRestriction and not item.classRestriction[entry.class]) then
        return false, train
    end
    local level = entry.level
    if Roster.IsHere(key) then
        level = UnitLevel("player")
    end
    local limit = level
    if options.lookAhead or not Roster.IsHere(key) then
        limit = limit + DB.Data().settings.gear.lookAheadLevels
    end
    if item.reqLevel > limit then
        return false, train
    end
    local judgedLevel = math.max(level, item.reqLevel)
    local class = Proficiency.classes[entry.class]
    local typeKey = item.classID .. ":" .. item.subclassID
    local spell = Proficiency.subclassSpell[typeKey]
    if spell and not Knows(key, spell) then
        local types = class.weapons
        if item.classID == 4 then
            types = class.armor
        end
        local trainingLevel = types[typeKey]
        local cannotTrain = not trainingLevel or trainingLevel > judgedLevel
        if spell == Proficiency.spells.shield or cannotTrain then
            return false, train
        end
        train[#train + 1] = spell
    end
    if item.classID == 4 and RELIC_CLASSES[item.subclassID] then
        if entry.class ~= RELIC_CLASSES[item.subclassID] then
            return false, train
        end
    end
    local hand = options.hand or group
    if item.classID == 2 and hand == "offHand" and not Knows(key, 674) then
        if not class.dualWield or class.dualWield > judgedLevel then
            return false, train
        end
        train[#train + 1] = 674
    end
    if IsArmorGroup(group) and Scoring.BestArmorOnly(options.loadout) then
        if item.subclassID < BestArmor(key, judgedLevel) and not options.worn then
            return false, train
        end
    end
    if Roster.IsHere(key) and C_PlayerInfo and C_PlayerInfo.CanUseItem and #train == 0 then
        if not C_PlayerInfo.CanUseItem(item.itemID) then
            return false, train
        end
    end
    return true, train
end

--- Distinct scored loadouts by spec and effective armour rule, worn preferred.
-- @param key string character key
-- @treturn table list of saved loadouts
function Scoring.Comparisons(key)
    local result = {}
    local seen = {}
    for _, loadout in ipairs(Roster.Entry(key).loadouts) do
        if loadout.spec then
            local id = loadout.spec .. ":" .. tostring(Scoring.BestArmorOnly(loadout))
            local index = seen[id]
            if not index then
                result[#result + 1] = loadout
                seen[id] = #result
            elseif loadout.worn then
                result[index] = loadout
            end
        end
    end
    return result
end

local function AddOwned(pieces, link, where, worn)
    pieces[#pieces + 1] = { link = link, where = where, worn = worn }
end

local function Owned(entry)
    local pieces = {}
    for _, link in pairs((entry.gear or {}).slots or {}) do
        AddOwned(pieces, link, "worn", true)
    end
    for _, where in ipairs({ "bags", "bank", "inbox" }) do
        for _, link in ipairs((entry[where] or {}).gear or {}) do
            AddOwned(pieces, link, where, false)
        end
    end
    for _, item in ipairs(entry.inbound or {}) do
        AddOwned(pieces, item.link, "inbound", false)
    end
    return pieces
end

local function Stamp(key)
    local gear = "gearOthers"
    if Roster.IsHere(key) then
        gear = "gearHere"
    end
    return table.concat({
        Generations.Get(gear), Generations.Get("loadouts"), Generations.Get("settings"),
    }, ":")
end

local function KeepBest(list, piece, field)
    if #list == 0 or piece[field] > list[1][field] then
        list[2] = list[1]
        list[1] = piece
    elseif #list == 1 or piece[field] > list[2][field] then
        list[2] = piece
    end
end

local function SelectPiece(list, excludeLink)
    local piece = list[1]
    if piece and not piece.worn and piece.item.link == excludeLink then
        return list[2]
    end
    return piece
end

local function BuildBaseline(key, loadout, group)
    local result = { scores = {}, levels = {} }
    for _, piece in ipairs(Owned(Roster.Entry(key))) do
        local item = ItemFacts.FromLink(piece.link)
        if not item.pending and Scoring.Group(item) == group then
            if item.tooltipUnread then
                return nil
            end
            local usable = Scoring.CanUse(item, key, { loadout = loadout, worn = piece.worn })
            if usable then
                local score = Scoring.Score(item, loadout.spec, group)
                if score then
                    piece.item = item
                    piece.score = score
                    piece.itemLevel = item.itemLevel
                    if score > 0 then
                        KeepBest(result.scores, piece, "score")
                    end
                    KeepBest(result.levels, piece, "itemLevel")
                end
            end
        end
    end
    return result
end

--- Best owned single-slot baseline by score, plus the highest item level.
--- Exclusion identifies the candidate's unworn link for here. Duplicate copy
--- and pair selection are the next scoring stage's separate rules.
-- @param key string character key
-- @param loadout table scored loadout
-- @param options table group and optional excludeLink
-- @treturn table score, item, where, itemLevel, highestItem, highestWhere;
--   pending = true when an owned piece's usability is unreadable
function Scoring.Baseline(key, loadout, options)
    local cacheKey = table.concat({ key, loadout.spec,
        tostring(Scoring.BestArmorOnly(loadout)), options.group }, "|")
    local stamp = Stamp(key)
    local cached = baselines[cacheKey]
    if not cached or cached.stamp ~= stamp then
        local result = BuildBaseline(key, loadout, options.group)
        if not result then
            baselines[cacheKey] = nil
            return { pending = true }
        end
        cached = { stamp = stamp, result = result }
        baselines[cacheKey] = cached
    end
    local result = { score = 0, itemLevel = 0 }
    local excludeLink
    if Roster.IsHere(key) then
        excludeLink = options.excludeLink
    end
    local best = SelectPiece(cached.result.scores, excludeLink)
    if best then
        result.score = best.score
        result.item = best.item
        result.where = best.where
    end
    local highest = SelectPiece(cached.result.levels, excludeLink)
    if highest then
        result.itemLevel = highest.itemLevel
        result.highestItem = highest.item
        result.highestWhere = highest.where
    end
    return result
end

--- Upgrade verdict and percentage gain; an empty baseline gives infinite gain.
-- @param candidate number score or fallback item level
-- @param baseline number score or fallback item level
-- @param minimum number minimum percentage gain
-- @treturn boolean
-- @treturn number
function Scoring.IsUpgrade(candidate, baseline, minimum)
    if baseline == 0 then
        return candidate > 0, math.huge
    end
    local gain = (candidate - baseline) / baseline * 100
    return candidate > baseline and gain >= minimum, gain
end

--- Compare a usable single-slot candidate under one loadout.
-- @param item table candidate facts
-- @param key string character key
-- @param options table loadout and lookAhead
-- @treturn table|nil comparison, nil when unusable, unscored or not loaded;
--   pending = true when an owned piece's usability is unreadable
function Scoring.Compare(item, key, options)
    local loadout = options.loadout
    if item.pending or item.tooltipUnread or not loadout.spec then
        return nil
    end
    local usable, train = Scoring.CanUse(item, key, options)
    if not usable then
        return nil
    end
    local group = Scoring.Group(item)
    local candidate, weighted = Scoring.Score(item, loadout.spec, group)
    if not candidate then
        return nil
    end
    local excludeLink
    if Roster.IsHere(key) and not item.linkOnly then
        excludeLink = item.link
    end
    local baseline = Scoring.Baseline(key, loadout, { group = group, excludeLink = excludeLink })
    if baseline.pending then
        return baseline
    end
    local value = baseline.score
    local baselineItem = baseline.item
    local baselineWhere = baseline.where
    local itemLevel = false
    local settings = DB.Data().settings.gear
    if not weighted and settings.itemLevelFallback then
        itemLevel = true
        candidate = item.itemLevel
        if not baselineItem then
            baselineItem = baseline.highestItem
            baselineWhere = baseline.highestWhere
        end
        value = 0
        if baselineItem then
            value = baselineItem.itemLevel
        end
    end
    local upgrade, gainPct = Scoring.IsUpgrade(candidate, value, settings.minUpgradePct)
    return { upgrade = upgrade, gainPct = gainPct, candidate = candidate, baseline = value,
        baselineItem = baselineItem, baselineWhere = baselineWhere, itemLevel = itemLevel,
        loadout = loadout, group = group, train = train }
end
