--[[
Scores, usability, owned-piece comparisons and protection (spec 8.1 to 8.7).
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
local weaponPools = {}
local weaponSets = setmetatable({}, { __mode = "k" })
local protections = {}
local waitingOwned = {}
local occurrences = {}

-- The item-data event and timer are unverified in game (L28 and L63).
-- ItemFacts requests each item once; this deadline is shared by all levels.
local function AwaitOwned(item, key)
    local waiting = waitingOwned[item.itemID]
    if not waiting then
        waiting =
            { deadline = (ItemFacts.RequestedAt(item.itemID) or GetTime()) + 10, characters = {} }
        waitingOwned[item.itemID] = waiting
        C_Timer.After(math.max(0, waiting.deadline - GetTime()), function()
            if waitingOwned[item.itemID] == waiting then
                for generation in pairs(waiting.characters) do
                    Generations.Bump(generation)
                end
            end
        end)
    end
    local generation = Roster.IsHere(key) and "gearHere" or "gearOthers"
    waiting.characters[generation] = true
    return GetTime() < waiting.deadline
end

-- Owned pieces left out for unreadable stats (L4) are remembered by link, so a
-- cached result is rebuilt once any of them becomes readable.
local function Recovered(links)
    for _, link in ipairs(links) do
        if Stats.Get(link) then
            return true
        end
    end
    return false
end

ItemFacts.OnLoaded(function(ids)
    local bump = {}
    for _, id in ipairs(ids) do
        local waiting = waitingOwned[id]
        if waiting then
            if GetTime() >= waiting.deadline then
                for generation in pairs(waiting.characters) do
                    bump[generation] = true
                end
            end
            waitingOwned[id] = nil
        end
    end
    for generation in pairs(bump) do
        Generations.Bump(generation)
    end
end)

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
-- @param spec string|nil spec id; nil or unavailable weights are not scored
-- @param hand string|nil slot group when judging a weapon
-- @treturn number|nil score; nil for unavailable spec weights or unloaded stats
-- @treturn boolean|nil whether item level must not replace the score
function Scoring.Score(item, spec, hand)
    if not spec or not WeightTables[spec] then
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

local function CharacterLevel(key)
    if Roster.IsHere(key) then
        return UnitLevel("player")
    end
    return Roster.Entry(key).level
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
-- @param options table loadout, lookAhead, hand and worn (baseline only);
--   evaluatedLevel filters owned pieces at that level rather than a window
-- @treturn boolean|nil nil while the item's usability facts are unreadable
-- @treturn table list of training spell IDs
function Scoring.CanUse(item, key, options)
    if item.pending then
        return nil, {}
    end
    local entry = Roster.Entry(key)
    local group = Scoring.Group(item)
    local train = {}
    if not group or (item.classRestriction and not item.classRestriction[entry.class]) then
        return false, train
    end
    local level = CharacterLevel(key)
    local limit = level
    if options.evaluatedLevel then
        limit = options.evaluatedLevel
    elseif options.lookAhead or not Roster.IsHere(key) then
        limit = limit + DB.Data().settings.gear.lookAheadLevels
    end
    if item.reqLevel > limit then
        return false, train
    end
    if item.tooltipUnread then
        return nil, train
    end
    local judgedLevel = math.max(level, item.reqLevel)
    if options.evaluatedLevel then
        judgedLevel = options.evaluatedLevel
    end
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
    local hasLiveAnswer = C_PlayerInfo and C_PlayerInfo.CanUseItem
    if Roster.IsHere(key) and item.reqLevel <= level and hasLiveAnswer and #train == 0 then
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
        if loadout.spec and WeightTables[loadout.spec] then
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
    local slots = (entry.gear or {}).slots or {}
    for slot = 1, 19 do
        if slots[slot] then
            AddOwned(pieces, slots[slot], "worn", true)
        end
    end
    for _, where in ipairs({ "bags", "bank", "inbox" }) do
        for _, link in ipairs((entry[where] or {}).gear or {}) do
            AddOwned(pieces, link, where, false)
        end
    end
    for _, item in ipairs(entry.inbound or {}) do
        AddOwned(pieces, item.link, "inbound", false)
    end
    local counts = {}
    for _, piece in ipairs(pieces) do
        local id = piece.where .. "|" .. piece.link
        counts[id] = (counts[id] or 0) + 1
        piece.occurrence = counts[id]
    end
    return pieces
end

-- Snapshot links preserve container scan order. Map a live candidate's slot
-- to its occurrence among equal links in that snapshot (L7 and L14).
local function CandidateIdentity(item, options)
    if not item then
        return nil
    end
    local where = options and options.fromInbound and "inbound"
        or options and options.fromInbox and "inbox"
        or "bags"
    local occurrence = 1
    if item.bag and item.slot then
        local first = Slots.bags.first
        if item.bag >= Slots.bankTabs.first then
            where, first = "bank", Slots.bankTabs.first
        end
        local cacheKey = table.concat({ item.bag, item.slot, item.link }, "|")
        local cached = occurrences[cacheKey]
        local stamp = Generations.Get("gearHere")
        if cached and cached.stamp == stamp then
            return { link = item.link, where = where, occurrence = cached.occurrence }
        end
        occurrence = 0
        for bag = first, item.bag do
            local last = C_Container.GetContainerNumSlots(bag) or 0
            if bag == item.bag then
                last = item.slot
            end
            for slot = 1, last do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if
                    info
                    and not ns.Util.IsSecret(info.hyperlink)
                    and info.hyperlink == item.link
                then
                    occurrence = occurrence + 1
                end
            end
        end
        occurrence = math.max(1, occurrence)
        occurrences[cacheKey] = { stamp = stamp, occurrence = occurrence }
    end
    return { link = item.link, where = where, occurrence = occurrence }
end

local function IsCandidate(piece, identity)
    return identity
        and not piece.worn
        and piece.link == identity.link
        and piece.where == identity.where
        and piece.occurrence == identity.occurrence
end

local function Stamp(key)
    local gear = "gearOthers"
    if Roster.IsHere(key) then
        gear = "gearHere"
    end
    return table.concat({
        Generations.Get(gear),
        Generations.Get("loadouts"),
        Generations.Get("settings"),
    }, ":")
end

local function KeepBest(list, piece, field)
    list[#list + 1] = piece
    table.sort(list, function(a, b)
        if a[field] ~= b[field] then
            return a[field] > b[field]
        end
        if
            field == "score"
            and DB.Data().settings.gear.itemLevelFallback
            and a.itemLevel ~= b.itemLevel
        then
            return a.itemLevel > b.itemLevel
        end
        return a.order < b.order
    end)
end

local function SelectPiece(list, excludeLink, count, identity, first)
    local selected = {}
    local excluded = false
    for _, piece in ipairs(list) do
        if
            identity
            and (
                (first and not piece.worn and piece.link == identity.link)
                or IsCandidate(piece, identity)
            )
        then
            excluded = true
        elseif
            not identity
            and not excluded
            and not piece.worn
            and piece.item.link == excludeLink
        then
            excluded = true
        else
            local selectedFirst = selected[1]
            if
                not selectedFirst
                or not (piece.item.unique and piece.item.itemID == selectedFirst.item.itemID)
            then
                selected[#selected + 1] = piece
                if #selected == count then
                    return piece
                end
            end
        end
    end
    return nil
end

local function BuildBaseline(key, loadout, group, evaluatedLevel)
    local result = { scores = {}, levels = {}, first = {}, unreadable = {} }
    local pending = false
    for order, piece in ipairs(Owned(Roster.Entry(key))) do
        piece.order = order
        if not piece.worn and not result.first[piece.link] then
            result.first[piece.link] = piece
        end
        local item = ItemFacts.FromLink(piece.link)
        if item.pending and (not item.equipLoc or Scoring.Group(item) == group) then
            if item.secret or AwaitOwned(item, key) then
                pending = true
            end
        end
        if not item.pending and Scoring.Group(item) == group then
            local usable = Scoring.CanUse(item, key, {
                loadout = loadout,
                worn = piece.worn,
                evaluatedLevel = evaluatedLevel,
            })
            if usable == nil then
                pending = true
            end
            if usable then
                local score = Scoring.Score(item, loadout.spec, group)
                if score then
                    piece.item = item
                    piece.score = score
                    piece.itemLevel = item.itemLevel
                    KeepBest(result.scores, piece, "score")
                    KeepBest(result.levels, piece, "itemLevel")
                else
                    -- Loaded but unreadable stats (L4): left out after 10 s.
                    if AwaitOwned(item, key) then
                        pending = true
                    end
                    if not Stats.Get(item.link) then
                        result.unreadable[#result.unreadable + 1] = item.link
                    end
                end
            end
        end
    end
    if pending then
        return nil
    end
    return result
end

--- Best owned baseline by score, plus the highest item level. Rings and
--- trinkets use the weaker of two; weapons use WeaponBaseline instead.
-- @param key string character key
-- @param loadout table scored loadout
-- @param options table group, optional excludeLink and evaluatedLevel;
--   evaluatedLevel defaults to current level for direct baseline callers
-- @treturn table score, item, where, itemLevel, highestItem, highestWhere;
--   pending = true while an owned piece's usability is unreadable or its
--     item data is still loading (within 10 s of its first request)
function Scoring.Baseline(key, loadout, options)
    local evaluatedLevel = options.evaluatedLevel or CharacterLevel(key)
    local cacheKey = table.concat({
        key,
        loadout.spec,
        tostring(Scoring.BestArmorOnly(loadout)),
        options.group,
        evaluatedLevel,
    }, "|")
    local stamp = Stamp(key)
    local cached = baselines[cacheKey]
    if not cached or cached.stamp ~= stamp or Recovered(cached.result.unreadable) then
        local result = BuildBaseline(key, loadout, options.group, evaluatedLevel)
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
    local identity = options.identity
    if excludeLink and not identity then
        identity = CandidateIdentity({ link = excludeLink })
    end
    local first = identity and IsCandidate(cached.result.first[identity.link] or {}, identity)
    local count = Slots.slotCount[options.group] or 1
    local best = SelectPiece(cached.result.scores, excludeLink, count, identity, first)
    local top = SelectPiece(cached.result.scores, excludeLink, 1, identity, first)
    local highest = SelectPiece(cached.result.levels, excludeLink, count, identity, first)
    if
        Roster.IsHere(key)
        and options.candidate
        and options.candidate.unique
        and options.group == "finger"
    then
        for _, piece in ipairs(cached.result.levels) do
            if piece.worn and piece.item.itemID == options.candidate.itemID then
                best = piece.score > 0 and piece or nil
                highest = piece
                break
            end
        end
    end
    if best and (best.score > 0 or (count == 2 and top and (top.score > 0 or best.score < 0))) then
        result.score = math.max(0, best.score)
        result.item = best.item
        result.where = best.where
    end
    if highest then
        result.itemLevel = highest.itemLevel
        result.highestItem = highest.item
        result.highestWhere = highest.where
    end
    return result
end

local function WeaponPool(key, loadout, level)
    local cacheKey =
        table.concat({ key, loadout.spec, tostring(Scoring.BestArmorOnly(loadout)), level }, "|")
    local stamp = Stamp(key)
    local cached = weaponPools[cacheKey]
    if cached and cached.stamp == stamp and not Recovered(cached.unreadable) then
        return cached.pieces, cached.unreadable
    end
    local pieces = {}
    local unreadable = {}
    local pending = false
    for order, piece in ipairs(Owned(Roster.Entry(key))) do
        piece.order = order
        local item = ItemFacts.FromLink(piece.link)
        local group = Scoring.Group(item)
        local weapon = group == "mainHand" or group == "offHand" or group == "twoHand"
        if item.pending and (weapon or not item.equipLoc) then
            pending = item.secret or AwaitOwned(item, key) or pending
        elseif weapon then
            piece.item = item
            piece.itemLevel = item.itemLevel
            for _, hand in ipairs({ "mainHand", "offHand", "twoHand" }) do
                if
                    group == hand or (hand == "offHand" and Slots.alsoGroup[item.equipLoc] == hand)
                then
                    local usable = Scoring.CanUse(item, key, {
                        loadout = loadout,
                        worn = piece.worn,
                        evaluatedLevel = level,
                        hand = hand,
                    })
                    if usable == nil then
                        pending = true
                    elseif usable then
                        piece[hand] = Scoring.Score(item, loadout.spec, hand)
                        if piece[hand] == nil then
                            if AwaitOwned(item, key) then
                                pending = true
                            end
                            if not Stats.Get(item.link) then
                                unreadable[#unreadable + 1] = item.link
                            end
                        end
                    end
                end
            end
            pieces[#pieces + 1] = piece
        end
    end
    if pending then
        return nil
    end
    weaponPools[cacheKey] = { stamp = stamp, pieces = pieces, unreadable = unreadable }
    return pieces, unreadable
end

local function WeaponSets(pieces)
    if weaponSets[pieces] then
        return weaponSets[pieces]
    end
    local result =
        { pair = {}, two = {}, highest = { mainHand = {}, offHand = {}, twoHand = {} }, first = {} }
    local function Add(list, main, off, score, level)
        if score > 0 then
            list[#list + 1] =
                { main = main, off = off, score = score, level = level, order = #list + 1 }
        end
    end
    for _, piece in ipairs(pieces) do
        if not piece.worn and not result.first[piece.link] then
            result.first[piece.link] = piece
        end
        for _, hand in ipairs({ "mainHand", "offHand", "twoHand" }) do
            if piece[hand] ~= nil then
                result.highest[hand][#result.highest[hand] + 1] = piece
            end
        end
        if piece.twoHand then
            Add(result.two, piece, nil, piece.twoHand, piece.itemLevel)
        end
        if piece.mainHand then
            Add(result.pair, piece, nil, piece.mainHand, piece.itemLevel)
            for _, off in ipairs(pieces) do
                if
                    off ~= piece
                    and off.offHand
                    and not (piece.item.unique and piece.item.itemID == off.item.itemID)
                then
                    Add(
                        result.pair,
                        piece,
                        off,
                        piece.mainHand + off.offHand,
                        math.max(piece.itemLevel, off.itemLevel)
                    )
                end
            end
        end
        if piece.offHand then
            Add(result.pair, nil, piece, piece.offHand, piece.itemLevel)
        end
    end
    local fallback = DB.Data().settings.gear.itemLevelFallback
    for _, list in ipairs({ result.pair, result.two }) do
        table.sort(list, function(a, b)
            if a.score ~= b.score then
                return a.score > b.score
            end
            if fallback and a.level ~= b.level then
                return a.level > b.level
            end
            return a.order < b.order
        end)
    end
    for _, list in pairs(result.highest) do
        table.sort(list, function(a, b)
            if a.itemLevel ~= b.itemLevel then
                return a.itemLevel > b.itemLevel
            end
            return a.order < b.order
        end)
    end
    weaponSets[pieces] = result
    return result
end

local function WeaponBaseline(key, loadout, level, excludeLink, identity)
    local pieces = WeaponPool(key, loadout, level)
    if not pieces then
        return { pending = true }
    end
    local sets = WeaponSets(pieces)
    if excludeLink and not identity then
        identity = CandidateIdentity({ link = excludeLink })
    end
    local first = identity and IsCandidate(sets.first[identity.link] or {}, identity)
    local function Allowed(piece)
        return not piece
            or not identity
            or not (
                (first and not piece.worn and piece.link == identity.link)
                or IsCandidate(piece, identity)
            )
    end
    local best = {
        mainScore = 0,
        offScore = 0,
        pairScore = 0,
        twoScore = 0,
        pairLevel = 0,
        twoLevel = 0,
        highest = {},
    }
    for hand, list in pairs(sets.highest) do
        for _, piece in ipairs(list) do
            if Allowed(piece) then
                best.highest[hand] = piece
                break
            end
        end
    end
    for _, set in ipairs(sets.two) do
        if Allowed(set.main) then
            best.twoScore, best.twoLevel, best.two = set.score, set.level, set.main
            break
        end
    end
    for _, set in ipairs(sets.pair) do
        if Allowed(set.main) and Allowed(set.off) then
            best.main, best.off, best.pairScore, best.pairLevel =
                set.main, set.off, set.score, set.level
            best.mainScore = set.main and set.main.mainHand or 0
            best.offScore = set.off and set.off.offHand or 0
            break
        end
    end
    return best
end

-- Whether a is strictly ahead of b: a higher score, or an equal score with a
-- higher item level while itemLevelFallback is on (spec 8.4).
local function Ahead(a, b)
    if a.score ~= b.score then
        return a.score > b.score
    end
    return DB.Data().settings.gear.itemLevelFallback and a.itemLevel > b.itemLevel
end

-- Slots left for identical copies of a piece: those not held by strictly
-- better chosen pieces, and one at most for a unique item.
local function CopySlots(chosen, piece, count)
    local slots = count
    for _, other in ipairs(chosen) do
        if Ahead(other, piece) then
            slots = slots - 1
        end
    end
    if piece.item.unique then
        slots = math.min(slots, 1)
    end
    return slots
end

local function ProtectionAt(key, loadout, group, level)
    local cacheKey = table.concat(
        { key, loadout.spec, tostring(Scoring.BestArmorOnly(loadout)), group, level },
        "|"
    )
    local stamp = Stamp(key)
    local cached = protections[cacheKey]
    if cached and cached.stamp == stamp and not Recovered(cached.unreadable) then
        return cached.winners, cached.near
    end
    local unreadable
    local winners = {}
    local near = {}
    if group == "mainHand" or group == "offHand" or group == "twoHand" then
        local pieces, missing = WeaponPool(key, loadout, level)
        if not pieces then
            return nil
        end
        unreadable = missing
        local best = 0
        local bestLevel = 0
        local sets = {}
        local function AddSet(a, b, score, firstHand)
            if score <= 0 then
                return
            end
            for _, piece in ipairs(pieces) do
                if piece ~= a and piece ~= b then
                    if
                        a
                        and piece.link == a.link
                        and piece.order < a.order
                        and piece[firstHand]
                    then
                        return
                    end
                    if b and piece.link == b.link and piece.order < b.order and piece.offHand then
                        return
                    end
                end
            end
            local itemLevel = math.max(a and a.itemLevel or 0, b and b.itemLevel or 0)
            if
                score > best
                or (
                    score == best
                    and DB.Data().settings.gear.itemLevelFallback
                    and itemLevel > bestLevel
                )
            then
                best, bestLevel, sets = score, itemLevel, {}
            end
            if
                score == best
                and (not DB.Data().settings.gear.itemLevelFallback or itemLevel == bestLevel)
            then
                sets[#sets + 1] = { a, b }
            end
        end
        for _, main in ipairs(pieces) do
            if main.twoHand then
                AddSet(main, nil, main.twoHand, "twoHand")
            end
            if main.mainHand then
                AddSet(main, nil, main.mainHand, "mainHand")
                for _, off in ipairs(pieces) do
                    if
                        off ~= main
                        and off.offHand
                        and not (main.item.unique and main.item.itemID == off.item.itemID)
                    then
                        if main.mainHand > 0 and off.offHand > 0 then
                            AddSet(main, off, main.mainHand + off.offHand, "mainHand")
                        end
                    end
                end
            end
            if main.offHand then
                AddSet(main, nil, main.offHand, "offHand")
            end
        end
        for _, set in ipairs(sets) do
            for _, piece in ipairs(set) do
                winners[piece] = true
            end
        end
        if not loadout.worn then
            local choices = WeaponSets(pieces)
            local function WinsWithout(target, removed)
                local highest, highestLevel, targetWins = 0, 0, false
                for _, list in ipairs({ choices.two, choices.pair }) do
                    for _, choice in ipairs(list) do
                        if choice.main ~= removed and choice.off ~= removed then
                            local includes = (
                                choice.main == target
                                and (target.twoHand or target.mainHand or 0) > 0
                            )
                                or (choice.off == target and target.offHand > 0)
                            local levelTie = not DB.Data().settings.gear.itemLevelFallback
                                or choice.level == highestLevel
                            if
                                choice.score > highest
                                or (
                                    choice.score == highest
                                    and DB.Data().settings.gear.itemLevelFallback
                                    and choice.level > highestLevel
                                )
                            then
                                highest, highestLevel, targetWins =
                                    choice.score, choice.level, includes
                            elseif choice.score == highest and levelTie and includes then
                                targetWins = true
                            end
                        end
                    end
                end
                return targetWins
            end
            for _, piece in ipairs(pieces) do
                if not winners[piece] then
                    local identical = false
                    for winner in pairs(winners) do
                        if winner.link == piece.link then
                            identical = true
                        end
                    end
                    if not identical then
                        for better in pairs(winners) do
                            if WinsWithout(piece, better) then
                                near[piece] = better
                                break
                            end
                        end
                    end
                end
            end
        end
    else
        local result = Scoring.Baseline(key, loadout, { group = group, evaluatedLevel = level })
        if result.pending then
            return nil
        end
        local list = baselines[cacheKey].result.scores
        unreadable = baselines[cacheKey].result.unreadable
        local count = Slots.slotCount[group] or 1
        local chosen = {}
        local threshold
        for _, piece in ipairs(list) do
            local usable =
                Scoring.CanUse(piece.item, key, { loadout = loadout, evaluatedLevel = level })
            if usable and piece.score > 0 then
                local duplicateUnique = false
                for _, earlier in ipairs(chosen) do
                    if piece.item.unique and earlier.item.itemID == piece.item.itemID then
                        duplicateUnique = true
                    end
                end
                if not duplicateUnique then
                    if #chosen < count then
                        chosen[#chosen + 1] = piece
                        winners[piece] = true
                        threshold = piece
                    elseif
                        piece.score == threshold.score
                        and (
                            not DB.Data().settings.gear.itemLevelFallback
                            or piece.itemLevel == threshold.itemLevel
                        )
                    then
                        local copies = 0
                        for selected in pairs(winners) do
                            if selected.link == piece.link then
                                copies = copies + 1
                            end
                        end
                        if copies < CopySlots(chosen, piece, count) then
                            winners[piece] = true
                        end
                    end
                end
            end
        end
        if not loadout.worn then
            local function IncludedWithout(target, removed)
                local selected, cutoff, copies = {}, nil, {}
                for _, piece in ipairs(list) do
                    if
                        piece ~= removed
                        and piece.score > 0
                        and Scoring.CanUse(
                            piece.item,
                            key,
                            { loadout = loadout, evaluatedLevel = level }
                        )
                    then
                        local duplicateUnique = false
                        for _, earlier in ipairs(selected) do
                            if piece.item.unique and earlier.item.itemID == piece.item.itemID then
                                duplicateUnique = true
                            end
                        end
                        local tied = cutoff
                            and piece.score == cutoff.score
                            and (
                                not DB.Data().settings.gear.itemLevelFallback
                                or piece.itemLevel == cutoff.itemLevel
                            )
                        if not duplicateUnique and (#selected < count or tied) then
                            copies[piece.link] = (copies[piece.link] or 0) + 1
                            if copies[piece.link] <= CopySlots(selected, piece, count) then
                                if piece == target then
                                    return true
                                end
                                if #selected < count then
                                    selected[#selected + 1] = piece
                                    cutoff = piece
                                end
                            end
                        end
                    end
                end
                return false
            end
            for _, piece in ipairs(list) do
                if not winners[piece] and piece.score > 0 then
                    for better in pairs(winners) do
                        local betterScore = better.score > piece.score
                            or (
                                DB.Data().settings.gear.itemLevelFallback
                                and better.score == piece.score
                                and better.itemLevel > piece.itemLevel
                            )
                        if
                            better.link ~= piece.link
                            and betterScore
                            and IncludedWithout(piece, better)
                        then
                            local prior = near[piece]
                            if
                                not prior
                                or better.score < prior.score
                                or (better.score == prior.score and better.order < prior.order)
                            then
                                near[piece] = better
                            end
                        end
                    end
                end
            end
        end
    end
    protections[cacheKey] =
        { stamp = stamp, winners = winners, near = near, unreadable = unreadable }
    return winners, near
end

--- Protection at any level in here's look-ahead window under scored loadouts.
-- @param item table candidate facts
-- @param key string character key
-- @param options table|nil fromInbox or fromInbound identifies a mail copy
-- @treturn table pending or inUse, loadout and optional better-piece data
function Scoring.InUse(item, key, options)
    local group = Scoring.Group(item)
    local start = CharacterLevel(key)
    local identity = CandidateIdentity(item, options)
    local better
    local winningLoadout
    for _, loadout in ipairs(Scoring.Comparisons(key)) do
        for level = start, start + DB.Data().settings.gear.lookAheadLevels do
            local winners, near = ProtectionAt(key, loadout, group, level)
            if not winners then
                return { pending = true }
            end
            for piece in pairs(winners) do
                if IsCandidate(piece, identity) then
                    if not winningLoadout or (loadout.worn and not winningLoadout.worn) then
                        winningLoadout = loadout
                    end
                end
            end
            if not better then
                for piece, superior in pairs(near) do
                    if IsCandidate(piece, identity) then
                        better = {
                            loadout = loadout,
                            group = group,
                            item = superior.item,
                            where = superior.where,
                        }
                        break
                    end
                end
            end
        end
    end
    return { inUse = winningLoadout ~= nil, loadout = winningLoadout, better = better }
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
    -- Allow floating-point rounding at the inclusive percentage boundary.
    local tolerance = 1e-12 * math.max(1, math.abs(minimum))
    return candidate > baseline and gain + tolerance >= minimum, gain
end

local function CompareWeapon(item, options, hand, pool, train)
    local candidate, weighted = Scoring.Score(item, options.loadout.spec, hand)
    if candidate == nil then
        return nil
    end
    local baseline, reference
    local partner = 0
    if hand == "twoHand" then
        if
            pool.twoScore > pool.pairScore
            or (
                pool.twoScore == pool.pairScore
                and (
                    not DB.Data().settings.gear.itemLevelFallback
                    or pool.twoLevel >= pool.pairLevel
                )
            )
        then
            baseline, reference = pool.twoScore, pool.two
        else
            baseline = pool.pairScore
            reference = pool.main or pool.off
            if pool.main and pool.off and pool.off.itemLevel > pool.main.itemLevel then
                reference = pool.off
            end
        end
    elseif pool.twoScore > pool.pairScore then
        baseline, reference = pool.twoScore, pool.two
        if hand == "mainHand" then
            partner = pool.offScore
        else
            partner = pool.mainScore
        end
    elseif hand == "mainHand" then
        baseline, reference = pool.mainScore, pool.main
    else
        baseline, reference = pool.offScore, pool.off
    end
    local settings = DB.Data().settings.gear
    local itemLevel = not weighted and settings.itemLevelFallback
    if itemLevel then
        if not reference then
            reference = pool.highest[hand]
            if hand == "twoHand" then
                for _, other in ipairs({ "mainHand", "offHand" }) do
                    local piece = pool.highest[other]
                    if piece and (not reference or piece.itemLevel > reference.itemLevel) then
                        reference = piece
                    end
                end
            end
        end
        candidate = item.itemLevel
        baseline = reference and reference.itemLevel or 0
        partner = 0
    end
    local upgrade, gainPct =
        Scoring.IsUpgrade(candidate + partner, baseline, settings.minUpgradePct)
    -- A unique item cannot join its own twin, which stays as the other hand.
    local retained = pool.off
    if hand == "offHand" then
        retained = pool.main
    end
    if hand ~= "twoHand" and item.unique and retained and retained.item.itemID == item.itemID then
        upgrade, gainPct = false, 0
    end
    return {
        upgrade = upgrade,
        gainPct = gainPct,
        candidate = candidate + partner,
        baseline = baseline,
        baselineItem = reference and reference.item,
        baselineWhere = reference and reference.where,
        itemLevel = itemLevel and true or false,
        loadout = options.loadout,
        group = hand,
        train = train,
    }
end

--- Compare a usable candidate under one loadout.
-- @param item table candidate facts
-- @param key string character key
-- @param options table loadout, lookAhead, optional fromInbox or fromInbound
-- @treturn table|nil comparison, nil when unusable, unscored or not loaded;
--   pending = true while an owned piece's usability is unreadable or its
--     item data is still loading (within 10 s of its first request)
function Scoring.Compare(item, key, options)
    local loadout = options.loadout
    local spec = loadout.spec
    if item.pending or item.tooltipUnread or not spec or not WeightTables[spec] then
        return nil
    end
    local usable, train = Scoring.CanUse(item, key, options)
    if not usable then
        return nil
    end
    local group = Scoring.Group(item)
    local evaluatedLevel = math.max(CharacterLevel(key), item.reqLevel)
    if item.unique and not Roster.IsHere(key) then
        for _, piece in ipairs(Owned(Roster.Entry(key))) do
            local ownedID = ns.Util.ParseLink(piece.link)
            if ownedID == item.itemID then
                return nil
            end
        end
    end
    if group == "mainHand" or group == "offHand" or group == "twoHand" then
        local excludeLink
        if
            Roster.IsHere(key) and (not item.linkOnly or options.fromInbox or options.fromInbound)
        then
            excludeLink = item.link
        end
        local pool = WeaponBaseline(
            key,
            loadout,
            evaluatedLevel,
            excludeLink,
            excludeLink and CandidateIdentity(item, options)
        )
        if pool.pending then
            return pool
        end
        local result = CompareWeapon(item, options, group, pool, train)
        if Slots.alsoGroup[item.equipLoc] == "offHand" then
            local usableOff, trainOff = Scoring.CanUse(item, key, {
                loadout = loadout,
                lookAhead = options.lookAhead,
                hand = "offHand",
            })
            if usableOff then
                local off = CompareWeapon(item, options, "offHand", pool, trainOff)
                -- A hand that is an upgrade beats one that is not, whatever
                -- the gains: an empty baseline gives even a zero score an
                -- infinite gain.
                if
                    off
                    and (
                        not result
                        or (off.upgrade and not result.upgrade)
                        or (off.upgrade == result.upgrade and off.gainPct > result.gainPct)
                    )
                then
                    result = off
                end
            end
        end
        return result
    end
    local candidate, weighted = Scoring.Score(item, loadout.spec, group)
    if not candidate then
        return nil
    end
    local excludeLink
    if Roster.IsHere(key) and (not item.linkOnly or options.fromInbox or options.fromInbound) then
        excludeLink = item.link
    end
    local baseline = Scoring.Baseline(key, loadout, {
        group = group,
        excludeLink = excludeLink,
        identity = excludeLink and CandidateIdentity(item, options),
        candidate = item,
        evaluatedLevel = evaluatedLevel,
    })
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
    return {
        upgrade = upgrade,
        gainPct = gainPct,
        candidate = candidate,
        baseline = value,
        baselineItem = baselineItem,
        baselineWhere = baselineWhere,
        itemLevel = itemLevel,
        loadout = loadout,
        group = group,
        train = train,
    }
end
