--[[
The classification order of spec 7.2 (milestone M0, stages 12 and 13): the
guarded and cached frame, step 0 (pending), the hard stays of step 1, the grey
rule of step 2, the gear of step 3 (3-0 nospec, 3a, 3c, 3b, 3d; spec 8.3 to
8.6), the wants of step 4, the class dispositions of step 5 and the sell rules
of step 6, with the AH rule of spec 7.4. Also the link-only path (spec 7.5,
"Item with no bag slot"), which runs only steps 2 (the include rule), 3 and 4,
and the full pass over the bags or the bank (technical findings 15).

A result is { category, reasonCode, reasonText, linkOnly } (spec 12.4 and
technical findings 14, as D150 sets it for M0) plus reasonData, an internal
field that no doc lists yet. category is "none", "equip",
"char:<key>", "ah", "vendor" or "vendorah". reasonText is filled in by the
reason texts of stage 14, except for the error result, which carries its text
from the start. reasonData holds the values the text needs (an internal
table, so the texts and M1's detail lines read one source): the winner and
kind of a want, the set of an `inset` stay, the price of a Vendor/AH, AH or
Vendor result, the flags "refundable", "noVendorValue" and "unscoredEffect",
and for gear the `gear` entry (the fields of spec 12.4 `detail.gear` that M0
has), the `runnerUps` of a `gearfor`, the loadout and `train` list of an
`inuse` stay, `atLevel` for an item above the level, and `better` (a better
piece for a stowed loadout).

A result is cached by the key of the bag slot with the generations it used
(Cache.lua). An item whose facts are incomplete has no result and no cache
entry (step 0).
]]

local _, ns = ...

local Classify = {}
ns.Classify = Classify

local Asks = ns.Asks
local Cache = ns.Cache
local DB = ns.DB
local Events = ns.Events
local ItemClasses = ns.ItemClasses
local ItemFacts = ns.ItemFacts
local L = ns.L
local Loadouts = ns.Loadouts
local Log = ns.Log
local Prices = ns.Prices
local Proficiency = ns.Proficiency
local Roster = ns.Roster
local Scoring = ns.Scoring
local Sets = ns.Sets
local Slots = ns.Slots
local Snapshot = ns.Snapshot
local Util = ns.Util

--- The time a full pass may take before the rest is spread over frames, in
--- milliseconds (technical findings 15, Budget).
Classify.BUDGET_MS = 10

--- The slots classified per frame once a pass is spread over frames.
Classify.BATCH_SIZE = 25

-- Returned by a step for an item that cannot be classified yet: an owned piece
-- its comparison needs is still loading (spec 8.4). Nothing is cached.
local PENDING = {}

-- Every generation name, for a result whose steps are unknown (an error).
local ALL_GENERATIONS =
    { "asks", "gearHere", "gearOthers", "loadouts", "prices", "roster", "settings" }

-- Item classes of step 1a and the tool subclasses of step 1d (spec 7.2; the
-- numbers are live check L8).
local CLASS_QUEST = 12
local CLASS_KEY = 13
local CLASS_TOKEN = 18
local CLASS_WEAPON = 2
local SUBCLASS_TOOL = 14
local SUBCLASS_FISHING_POLE = 20

local function Result(category, code, data)
    return {
        category = category,
        reasonCode = code,
        linkOnly = false,
        reasonData = data or {},
    }
end

local BETTER_WHERE = {
    worn = "reasonWhereWorn",
    bags = "reasonBetterBags",
    bank = "reasonBetterBank",
    inbox = "reasonBetterMail",
    inbound = "reasonBetterMail",
}

local REASON_WHERE = {
    worn = "reasonWhereWorn",
    bags = "reasonWhereBags",
    bank = "reasonWhereBank",
    inbox = "reasonWhereMail",
    inbound = "reasonWhereMail",
}

local function GainText(gain)
    local text = string.format("%.1f", gain)
    return (string.gsub(text, "%.0$", ""))
end

local function BaselineName(item, where, located)
    local name = C_Item.GetItemInfo(item.link)
    if located then
        return string.format(L.reasonItemLocation, name, L[REASON_WHERE[where]])
    end
    return name
end

local function BaselineText(gear, located)
    if gear.baselinePair then
        local first, second = unpack(gear.baselinePair)
        local key = L.reasonPair
        if located then
            key = L.reasonPairLocated
        end
        return string.format(
            key,
            BaselineName(first.item, first.where, located),
            BaselineName(second.item, second.where, located)
        )
    end
    return BaselineName(gear.baselineItem, gear.baselineWhere, located)
end

local function PriceAge(days)
    if days == nil then
        return L.reasonAgeOver
    end
    return string.format(L.reasonAgeDays, days)
end

local function ProviderLabel(id)
    for _, provider in ipairs(Prices.Status()) do
        if provider.id == id then
            return provider.label
        end
    end
    return id
end

local function SkillName(spell)
    if spell == Proficiency.spells.dualWield then
        return L.skillDualWield
    end
    for kind, id in pairs(Proficiency.subclassSpell) do
        if spell == id then
            local class, subclass = string.match(kind, "^(%d+):(%d+)$")
            return C_Item.GetItemSubClassInfo(tonumber(class), tonumber(subclass))
        end
    end
end

local function ReasonText(result)
    local code, data = result.reasonCode, result.reasonData
    local key = "reason" .. string.upper(string.sub(code, 1, 1)) .. string.sub(code, 2)
    local text = L[key]
    if code == "wanted" or code == "wantedhere" then
        local name
        if data.kind == "item" then
            name = C_Item.GetItemInfo(data.itemID)
        elseif data.kind == "class" then
            name = Util.TypeName(data.class)
        else
            name = Util.TypeName(data.class, data.subclass)
        end
        text = string.format(text, name)
    elseif code == "inset" then
        text = string.format(text, data.set)
        if data.loadout then
            text = text .. string.format(L.reasonLoadout, data.loadout)
        end
    elseif code == "inuse" then
        local loadout = data.loadout
        if data.assumed then
            loadout = loadout .. L.reasonAssumed
        end
        text = string.format(text, loadout, Slots.Word(data.group))
    elseif code == "nospec" then
        text = string.format(text, UnitClass("player"))
    elseif code == "equipat" then
        text = string.format(text, data.atLevel)
        local worn = Loadouts.Worn(Roster.HereKey())
        if not worn or worn.name ~= data.gear.loadout then
            local loadout = data.gear.loadout
            if data.gear.assumed then
                loadout = loadout .. L.reasonAssumed
            end
            text = text .. string.format(L.reasonLoadout, loadout)
        end
        if data.gear.itemLevel then
            text = text .. L.reasonIlvl
        end
    elseif code == "stale" then
        text = string.format(
            text,
            PriceAge(data.price.ageDays),
            data.maxPriceAgeDays,
            Util.FormatMoney(data.price.unit),
            ProviderLabel(data.provider)
        )
    elseif code == "ah" then
        local price = data.price
        text = string.format(
            text,
            Util.FormatMoney(price.unit),
            Util.FormatMoney(price.gainPerUnit),
            price.cutPct,
            price.label,
            PriceAge(price.ageDays)
        )
    elseif code == "vendor" or code == "vendorbound" or code == "grey" then
        text = string.format(text, Util.FormatMoney(data.vendor))
    elseif code == "equip" or code == "gearfor" then
        local gear = data.gear
        local loadout = gear.loadout
        if gear.assumed then
            loadout = loadout .. L.reasonAssumed
        end
        if gear.baseline == 0 then
            text = string.format(L.reasonEmptySlot, loadout, Slots.Word(gear.group))
        else
            text = string.format(
                text,
                GainText(gear.gainPct),
                loadout,
                BaselineText(gear, code == "equip")
            )
        end
        if gear.itemLevel then
            text = text .. L.reasonIlvl
        end
        if gear.atLevel then
            text = text .. string.format(L.reasonAtLevel, gear.atLevel)
        end
        if code == "equip" and gear.judgedBoth then
            if gear.group == "offHand" then
                text = text .. L.reasonOffHand
            else
                text = text .. L.reasonMainHand
            end
        end
        for _, runner in ipairs(data.runnerUps or {}) do
            if runner.baseline == 0 then
                text = text
                    .. string.format(
                        L.reasonRunnerEmpty,
                        Roster.DisplayName(runner.key),
                        Slots.Word(runner.group)
                    )
            else
                text = text
                    .. string.format(
                        L.reasonRunner,
                        Roster.DisplayName(runner.key),
                        GainText(runner.gainPct)
                    )
            end
        end
    end
    if data.refundable then
        text = text .. L.reasonRefundable
    end
    if data.noVendorValue then
        text = text .. L.reasonNoVendorValue
    end
    local train = data.gear and data.gear.train or data.train
    if train and #train > 0 then
        local names = {}
        for _, spell in ipairs(train) do
            names[#names + 1] = SkillName(spell)
        end
        text = text .. string.format(L.reasonTrain, table.concat(names, ", "))
    end
    if data.unscoredEffect or (data.gear and data.gear.unscoredEffect) then
        text = text .. L.reasonEffect
    end
    if data.better then
        local better = data.better
        text = text
            .. string.format(
                L.reasonBetter,
                better.loadout.name,
                Slots.Word(better.group),
                L[BETTER_WHERE[better.where]]
            )
    end
    if result.linkOnly and code ~= "nobody" and code ~= "error" then
        text = text .. L.reasonNotInBags
    end
    return text
end

-- Records that the result used a generation.
local function Use(context, name)
    if not context.seen[name] then
        context.seen[name] = true
        context.used[#context.used + 1] = name
    end
end

-- Soulbound: bound to the character (spec 4). An account-bound item counts as
-- tradable, so it is not soulbound. This relies on the game reporting an item
-- in the loot trade window as bound (unverified; confirm live, L7).
local function IsSoulbound(facts)
    if facts.isAccountBound then
        return false
    end
    return facts.bound
end

-- Equippable armour or a weapon (spec 7.2 step 3): the slot type is one of
-- Data/Slots.lua and the item is neither cosmetic armour (4:5) nor a
-- profession tool (step 1d); Scoring.Group answers that.
local function IsGear(facts)
    return Scoring.Group(facts) ~= nil
end

local function IsTool(facts)
    if facts.classID == CLASS_WEAPON then
        if facts.subclassID == SUBCLASS_TOOL or facts.subclassID == SUBCLASS_FISHING_POLE then
            return true
        end
    end
    return ItemClasses.tools[facts.itemID] ~= nil
end

-- The facts Asks.Matches reads (spec 7.3).
local function WantFacts(facts)
    return {
        itemID = facts.itemID,
        class = facts.classID,
        subclass = facts.subclassID,
        quality = facts.quality,
        classRestriction = facts.classRestriction,
        knownHere = facts.knownHere,
    }
end

-- True when the character's wants include this item ID by name (step 2).
local function Includes(key, itemID)
    local entry = DB.Data().characters[key]
    if type(entry) ~= "table" or type(entry.asks) ~= "table" then
        return false
    end
    local items = entry.asks.items
    return type(items) == "table" and items[itemID] == "include"
end

-- A character that wants the item, as reason data: the key and which want
-- named it (spec 7.6, words in reasons).
local function WantData(context, key)
    local wantFacts = context.wantFacts
    return {
        winner = key,
        kind = Asks.MatchKind(key, wantFacts),
        itemID = wantFacts.itemID,
        class = wantFacts.class,
        subclass = wantFacts.subclass,
    }
end

-- The first eligible character in the global order for whom test(key) holds.
local function FirstEligible(context, test)
    Use(context, "roster")
    for _, key in ipairs(Roster.EligibleKeys()) do
        if test(key) then
            return key
        end
    end
    return nil
end

local function HereWants(context)
    Use(context, "asks")
    return Asks.Matches(Roster.HereKey(), context.wantFacts)
end

-- The name of here's loadout linked to the imported set, or nil.
local function LinkedLoadout(set)
    local entry = DB.Data().characters[Roster.HereKey()]
    if type(entry) ~= "table" or type(entry.loadouts) ~= "table" then
        return nil
    end
    for _, loadout in ipairs(entry.loadouts) do
        local link = loadout.link
        if type(link) == "table" and link.source == set.source and link.set == set.name then
            return loadout.name
        end
    end
    return nil
end

-- Step 1a to 1c: the stays that need no wants. Returns a result or nil.
local function HardStayA(context, facts)
    if
        facts.classID == CLASS_QUEST
        or facts.classID == CLASS_KEY
        or facts.classID == CLASS_TOKEN
    then
        return Result("none", "quest")
    end
    if facts.isQuest then
        return Result("none", "quest")
    end
    if ItemClasses.neverTouch[facts.itemID] then
        return Result("none", "nevertouch")
    end
    Use(context, "asks")
    if Sets.IsProtected(facts.itemID, facts.suffix) then
        return Result("none", "protected")
    end
    Use(context, "loadouts")
    local member, set = Sets.IsSetMember(facts.itemID, facts.suffix)
    if member then
        local data = { set = set.name, source = set.source, loadout = LinkedLoadout(set) }
        return Result("none", "inset", data)
    end
    return nil
end

-- Step 4: wants. here wins; otherwise the first eligible wanter if the item is
-- tradable. Returns a result or nil.
local function Wants(context, facts)
    Use(context, "asks")
    local wantFacts = context.wantFacts
    if Asks.Matches(Roster.HereKey(), wantFacts) then
        return Result("none", "wantedhere", WantData(context, Roster.HereKey()))
    end
    if IsSoulbound(facts) then
        return nil
    end
    local winner = FirstEligible(context, function(key)
        return Asks.Matches(key, wantFacts)
    end)
    if winner then
        return Result("char:" .. winner, "wanted", WantData(context, winner))
    end
    return nil
end

-- Step 5: the disposition for the item's class. A player override of the
-- class:subclass, then of the class, then the shipped class:subclass, then the
-- shipped class, then "stay" (spec 7.2 step 5). An override that is neither
-- "stay" nor "sell" is not a disposition and is skipped.
local function Disposition(context, facts)
    Use(context, "settings")
    local overrides = DB.Data().settings.classOverride
    local whole = tostring(facts.classID)
    local exact = whole .. ":" .. tostring(facts.subclassID)
    for _, key in ipairs({ exact, whole }) do
        local value = type(overrides) == "table" and overrides[key]
        if value == "stay" or value == "sell" then
            return value
        end
    end
    return ItemClasses.dispositions[exact] or ItemClasses.dispositions[whole] or "stay"
end

-- The AH rule of spec 7.4. Returns whether it passes and the price detail.
local function AHRule(settings, facts, price)
    local unit = price.unit
    local vendor = facts.vendorPrice
    -- unit * (1 - cut / 100), kept in whole numbers until the floor so a
    -- product just below an integer cannot lose a copper.
    local net = math.floor(unit * (100 - settings.ahCutPct) / 100)
    local gainPerUnit = net - vendor
    local gainTotal = gainPerUnit * facts.holding
    local passes = gainTotal >= settings.minGainCopper
        and gainPerUnit > 0
        and (vendor == 0 or gainPerUnit * 100 >= vendor * settings.minGainPct)
    return passes,
        {
            source = price.source,
            unit = unit,
            ageDays = price.ageDays,
            net = net,
            vendor = vendor,
            gainPerUnit = gainPerUnit,
            gainTotal = gainTotal,
            cutPct = settings.ahCutPct,
        }
end

-- Step 6: sell (spec 7.2 step 6).
local function Sell(context, facts)
    local vendor = facts.vendorPrice
    local data = { vendor = vendor }
    if IsSoulbound(facts) or facts.isAccountBound then
        if vendor > 0 then
            return Result("vendor", "vendorbound", data)
        end
        return Result("none", "novalue", data)
    end
    Use(context, "prices")
    Use(context, "settings")
    local settings = DB.Data().settings.ah
    local price, source, considered = Prices.Best(facts.itemID, facts.link)
    if not price then
        -- source is the reason here: { code, price, provider }.
        data.noVendorValue = vendor == 0
        if source.price then
            data.price = { unit = source.price.unit, ageDays = source.price.ageDays }
            data.provider = source.provider
            data.maxPriceAgeDays = settings.maxPriceAgeDays
        end
        return Result("vendorah", source.code, data)
    end
    context.relied = { price }
    if #considered > 1 then
        -- The winner is chosen by whole-day age, so any of them crossing a day
        -- boundary can change it.
        context.relied = considered
        context.byAge = true
    end
    local passes, detail = AHRule(settings, facts, {
        unit = price.unit,
        ageDays = price.ageDays,
        source = source.id,
    })
    detail.label = source.label
    data.price = detail
    if passes then
        return Result("ah", "ah", data)
    end
    if vendor > 0 then
        return Result("vendor", "vendor", data)
    end
    return Result("none", "belowthreshold", data)
end

-- True when a loadout of the character has no scoreable spec: spec = nil, or a
-- saved spec with no weight table in this build (spec 7.2 step 3-0, 8.5).
local function HasUnscoredLoadout(key)
    for _, loadout in ipairs(Loadouts.List(key)) do
        if not (loadout.spec and Loadouts.HasWeights(loadout.spec)) then
            return true
        end
    end
    return false
end

-- The options Scoring reads for one loadout. A mailbox attachment is an owned
-- piece: Scoring leaves one copy out of the baseline (spec 7.5).
local function CompareOptions(context, loadout, lookAhead)
    return {
        loadout = loadout,
        lookAhead = lookAhead,
        fromInbox = context.mail == "inbox",
        fromInbound = context.mail == "inbound",
    }
end

-- The gear fields of spec 12.4 `detail.gear` that M0 has, for the reason
-- texts of stage 14. bankAge is M1's.
local function GearData(key, comparison, facts)
    local loadout = comparison.loadout
    return {
        key = key,
        loadout = loadout.name,
        spec = loadout.spec,
        assumed = loadout.assumed == true,
        itemLevel = comparison.itemLevel,
        group = comparison.group,
        candidate = comparison.candidate,
        baseline = comparison.baseline,
        baselineItem = comparison.baselineItem,
        baselineWhere = comparison.baselineWhere,
        baselinePair = comparison.baselinePair,
        judgedBoth = comparison.judgedBoth,
        gainPct = comparison.gainPct,
        train = comparison.train,
        unscoredEffect = facts.unscoredEffect,
    }
end

-- The upgrade with the largest gain over the character's scored loadouts (the
-- worn loadout on a tie, then the first in the list; spec 8.5), or nil. With
-- lookAhead the item may be above the character's level. Returns PENDING while
-- an owned piece is loading.
local function BestUpgrade(context, key, facts, lookAhead)
    local best
    for _, loadout in ipairs(Scoring.Comparisons(key)) do
        local comparison = Scoring.Compare(facts, key, CompareOptions(context, loadout, lookAhead))
        if comparison and comparison.pending then
            return PENDING
        end
        if comparison and comparison.upgrade then
            if
                not best
                or comparison.gainPct > best.gainPct
                or (comparison.gainPct == best.gainPct and loadout.worn and not best.loadout.worn)
            then
                best = comparison
            end
        end
    end
    return best
end

-- Step 3a: here, under the worn loadout (Equip), then the look-ahead. Returns
-- a result, PENDING, or nil to go on (the look-ahead outcome, when it does not
-- stop here, is kept in context.equipat).
local function HereUpgrade(context, facts, hereKey)
    local worn = Loadouts.Worn(hereKey)
    if worn then
        local comparison = Scoring.Compare(facts, hereKey, CompareOptions(context, worn, false))
        if comparison and comparison.pending then
            return PENDING
        end
        if comparison and comparison.upgrade then
            local data = { gear = GearData(hereKey, comparison, facts) }
            return Result("equip", "equip", data)
        end
    end
    -- An item here can use now that is an upgrade only under another loadout
    -- is not a look-ahead item: it skips 3a (spec 7.2 step 3a).
    if facts.reqLevel <= UnitLevel("player") then
        return nil
    end
    local best = BestUpgrade(context, hereKey, facts, true)
    if best == PENDING then
        return PENDING
    end
    if not best then
        return nil
    end
    local data = { gear = GearData(hereKey, best, facts), atLevel = facts.reqLevel }
    local result = Result("none", "equipat", data)
    if DB.Data().settings.gear.hereWinsInLookAhead then
        return result
    end
    context.equipat = result
    return nil
end

-- Step 3c: "in use" for here, from the best owned pieces at every level of the
-- look-ahead window (spec 8.6). Independent of hereWinsInLookAhead. Returns a
-- result, PENDING, or nil.
local function InUse(context, facts, hereKey)
    local verdict = Scoring.InUse(facts, hereKey, CompareOptions(context))
    if verdict.pending then
        return PENDING
    end
    if verdict.inUse then
        local data = {
            loadout = verdict.loadout.name,
            assumed = verdict.loadout.assumed,
            group = Scoring.Group(facts),
            train = verdict.train,
        }
        return Result("none", "inuse", data)
    end
    context.better = verdict.better
    return nil
end

-- Step 3b: the eligible character with the largest gain, ties by the global
-- order. Returns a result, PENDING, or nil.
local function OtherUpgrade(context, facts)
    Use(context, "gearOthers")
    Use(context, "roster")
    local found = {}
    for order, key in ipairs(Roster.EligibleKeys()) do
        if Roster.ReceivesGear(key) then
            local best = BestUpgrade(context, key, facts, false)
            if best == PENDING then
                return PENDING
            end
            if best then
                found[#found + 1] = { key = key, comparison = best, order = order }
            end
        end
    end
    if #found == 0 then
        return nil
    end
    table.sort(found, function(a, b)
        if a.comparison.gainPct ~= b.comparison.gainPct then
            return a.comparison.gainPct > b.comparison.gainPct
        end
        return a.order < b.order
    end)
    local function Entry(index)
        local choice = found[index]
        local data = GearData(choice.key, choice.comparison, facts)
        local level = Roster.Entry(choice.key).level
        if type(level) == "number" and facts.reqLevel > level then
            data.atLevel = facts.reqLevel
        end
        return data
    end
    local data = { gear = Entry(1), runnerUps = {} }
    for index = 2, math.min(#found, 3) do
        data.runnerUps[#data.runnerUps + 1] = Entry(index)
    end
    return Result("char:" .. found[1].key, "gearfor", data)
end

-- Step 3 (spec 7.2). Returns a result, PENDING, or nil to go on to step 4.
-- 3-0: a here loadout with no scoreable spec keeps a bag or bank piece of gear
-- (nospec); for a link-only result 3a and 3c are skipped and 3b runs (D158).
-- Then 3a, 3c, 3b, and 3d (the caller goes on to step 4, except after a 3a
-- equipat). A link-only result has no 3c, unless it is a mailbox attachment.
local function Gear(context, facts)
    local hereKey = Roster.HereKey()
    Use(context, "loadouts")
    Use(context, "settings")
    local skipHere = false
    if HasUnscoredLoadout(hereKey) then
        if not context.linkOnly then
            return Result("none", "nospec")
        end
        skipHere = true
    end
    local result
    if not skipHere then
        Use(context, "gearHere")
        result = HereUpgrade(context, facts, hereKey)
        if result then
            return result
        end
        if not context.linkOnly or context.mail then
            result = InUse(context, facts, hereKey)
            if result then
                return result
            end
        end
    end
    if not IsSoulbound(facts) then
        result = OtherUpgrade(context, facts)
        if result then
            return result
        end
    end
    return context.equipat
end

-- Step 2's include rule for a grey item: here, then another eligible
-- character that includes the item ID and may be sent it. Returns a result or
-- nil.
local function GreyInclude(context, facts)
    local hereKey = Roster.HereKey()
    Use(context, "asks")
    if Includes(hereKey, facts.itemID) then
        return Result("none", "wantedhere", WantData(context, hereKey))
    end
    if not IsSoulbound(facts) then
        local winner = FirstEligible(context, function(key)
            return Includes(key, facts.itemID)
        end)
        if winner then
            return Result("char:" .. winner, "wanted", WantData(context, winner))
        end
    end
    return nil
end

-- The order of spec 7.2 for one set of facts. Returns a result.
local function Steps(context, facts)
    context.wantFacts = WantFacts(facts)
    local result = HardStayA(context, facts)
    if result then
        return result
    end
    -- Step 1d: a profession tool stays; a tradable one that an eligible
    -- character, or here, wants goes to step 4, which decides the result.
    -- Roster.EligibleKeys omits here, so here is tested first, as in step 4.
    if IsTool(facts) then
        if IsSoulbound(facts) then
            return Result("none", "tool")
        end
        Use(context, "asks")
        local wantFacts = context.wantFacts
        local wanted = HereWants(context)
            or FirstEligible(context, function(key)
                return Asks.Matches(key, wantFacts)
            end)
        if not wanted then
            return Result("none", "tool")
        end
        return Wants(context, facts) or Result("none", "tool")
    end
    -- Step 1e: soulbound, nothing to sell, not gear, and here does not want it.
    if IsSoulbound(facts) and facts.vendorPrice == 0 and not IsGear(facts) then
        if not HereWants(context) then
            return Result("none", "novalue")
        end
    end
    -- Step 2: grey items.
    if facts.quality == 0 then
        result = GreyInclude(context, facts)
        if result then
            return result
        end
        if facts.vendorPrice > 0 then
            return Result("vendor", "grey", { vendor = facts.vendorPrice })
        end
        return Result("none", "novalue")
    end
    -- Step 3: gear.
    if IsGear(facts) then
        result = Gear(context, facts)
        if result then
            return result
        end
    end
    result = Wants(context, facts)
    if result then
        return result
    end
    -- Step 5.
    if Disposition(context, facts) == "stay" then
        return Result("none", "classstay")
    end
    return Sell(context, facts)
end

-- The order for an item with no bag slot (spec 7.5): only step 2's include
-- rule for a grey item, then step 3 and step 4, with the item treated as
-- tradable. It is never AH, Vendor or Vendor/AH; when nobody wants it the
-- result is none with reason `nobody`.
local function LinkSteps(context, facts)
    context.wantFacts = WantFacts(facts)
    if facts.quality == 0 then
        return GreyInclude(context, facts) or Result("none", "nobody")
    end
    if IsGear(facts) then
        local result = Gear(context, facts)
        if result then
            return result
        end
    end
    return Wants(context, facts) or Result("none", "nobody")
end

-- Runs the steps of the context, and adds the flags of spec 7.6: "refundable"
-- ("Any bag item's reason adds "; refundable""), which stage 14 reads from the
-- reason data, "unscoredEffect" (any gear item, whatever the category), and the
-- better piece for a stowed loadout found by step 3c. The
-- cache key does not include the refund state, so a purchase that stops being
-- refundable is noticed when the key or a generation changes (live check L55).
local function Run(context, facts)
    local result = context.steps(context, facts)
    if result == PENDING then
        return result
    end
    if facts.refundable then
        result.reasonData.refundable = true
    end
    if facts.unscoredEffect then
        result.reasonData.unscoredEffect = true
    end
    if context.better then
        result.reasonData.better = context.better
    end
    if facts.linkOnly then
        result.linkOnly = true
    end
    result.reasonText = ReasonText(result)
    return result
end

local function ErrorResult(linkOnly)
    local errorResult = Result("none", "error")
    errorResult.reasonText = L.errorEngine
    errorResult.linkOnly = linkOnly == true
    return errorResult
end

-- Reads the facts of the slot and builds its cache key, under the engine
-- guard. Returns a table { pending = true } for an item with no result yet
-- (nothing is cached), { empty = true } for an empty slot, or { facts, key }.
local function Read(bag, slot, holdings)
    local facts = ItemFacts.FromSlot(bag, slot, holdings)
    if not facts then
        return { empty = true }
    end
    if facts.pending or facts.secret or facts.tooltipUnread then
        return { pending = true }
    end
    local key = Cache.SlotKey(bag, slot, facts.link, facts.bound, facts.holding)
    return { facts = facts, key = key }
end

-- The same for a link. mail is nil, "inbox" or "inbound". A mailbox copy has
-- its own cache key (technical findings 15); the inbound copy has
-- `I|link|inbound`.
local function ReadLink(link, mail)
    local facts = ItemFacts.FromLink(link)
    if not facts then
        return { empty = true }
    end
    if facts.pending or facts.secret or facts.tooltipUnread then
        return { pending = true }
    end
    local key = Cache.LinkKey(link)
    if mail == "inbox" then
        key = Cache.InboxKey(link)
    elseif mail == "inbound" then
        key = Cache.InboxKey(link) .. "|inbound"
    end
    return { facts = facts, key = key }
end

-- Runs the order under the engine guard, and turns a nil (an error) into the
-- error result. The error is recorded and the chat line printed once per
-- session by Log.Guard.
local function Guarded(context, facts)
    local result = Log.Guard("engine", Run, context, facts)
    if result then
        return result, false
    end
    return ErrorResult(facts.linkOnly), true
end

-- The result for the read facts, from the cache when fresh; nil while the
-- item is pending.
local function Resolve(read, steps, mail)
    local facts, key = read.facts, read.key
    local cached = Cache.Get(key)
    if cached then
        return cached
    end
    local context = {
        seen = {},
        used = {},
        steps = steps,
        mail = mail,
        linkOnly = facts.linkOnly or false,
    }
    local result, failed = Guarded(context, facts)
    if result == PENDING then
        return nil
    end
    local validUntil
    local used = context.used
    if failed then
        -- The steps that ran are not known, so any generation moving retries.
        used = ALL_GENERATIONS
    elseif context.relied then
        validUntil =
            Cache.ValidUntil(context.relied, DB.Data().settings.ah.maxPriceAgeDays, context.byAge)
    end
    Cache.Store(key, result, used, validUntil)
    return result
end

--- The result for the item in a bag slot, from the cache when it is fresh.
--- Returns nil when the slot is empty or the item is still pending: its data
--- is not loaded, a value is hidden in combat, a tooltip fact could not be
--- read, or an owned piece its comparison needs is still loading (spec 7.2
--- step 0 and 3; nothing is cached).
-- @param bag number
-- @param slot number
-- @param holdings table|nil from ItemFacts.Holdings(bag), shared by a pass
-- @treturn table|nil result
function Classify.BagSlot(bag, slot, holdings)
    local read = Log.Guard("engine", Read, bag, slot, holdings)
    if not read then
        -- The facts could not be read: the error result, with no key to cache.
        return ErrorResult(false)
    end
    if read.empty or read.pending then
        return nil
    end
    return Resolve(read, Steps, nil)
end

--- The result for an item with no bag slot (spec 7.5): who wants it and the
--- gear verdicts only, with linkOnly = true, never AH, Vendor or Vendor/AH.
--- The M1 API.ClassifyLink calls this. Returns nil while the item is pending
--- (as for a bag item) and for text that holds no item.
-- @param link string
-- @param mail string|nil "inbox" for a mailbox attachment, "inbound" for a
--   piece of inbound mail (an owned piece: one copy is left out and 3c runs),
--   else nil
-- @treturn table|nil result
function Classify.Link(link, mail)
    local read = Log.Guard("engine", ReadLink, link, mail)
    if not read then
        return ErrorResult(true)
    end
    if read.empty or read.pending then
        return nil
    end
    return Resolve(read, LinkSteps, mail)
end

-- The full pass (technical findings 15, Events and Budget). scope is "bags"
-- (bags 0 to 5) or "bank" (tabs 6 to 14, only while the bank is open).
-- runs[scope] is the pass under way, deferred[scope] is true while a pass
-- waits for the end of combat.
local runs = {}
local deferred = {}
-- dirty[scope] is true when item data loaded while a pass for the scope was
-- running; the pass runs once more when it finishes.
local dirty = {}

local function SlotList(range)
    local list = {}
    for bag = range.first, range.last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            list[#list + 1] = { bag, slot }
        end
    end
    return list
end

local function Finish(run)
    runs[run.scope] = nil
    Log.Debug("classify", string.format(L.classifyPass, run.scope, run.count, run.ms))
    if dirty[run.scope] then
        Classify.Pass(run.scope)
    end
end

local Continue

-- Milliseconds for the budget. API guess: debugprofilestop (live check L35);
-- GetTime() * 1000 is the fallback when the global is missing.
local function Clock()
    if debugprofilestop then
        return debugprofilestop()
    end
    return GetTime() * 1000
end

-- Classifies slots of the run. The first segment runs until the budget of
-- Classify.BUDGET_MS is spent; what is left goes in batches of
-- Classify.BATCH_SIZE, one per frame. The time reported is the time spent
-- classifying, not the frames waited between batches.
local function Advance(run, first)
    local started = Clock()
    local done = 0
    local list = run.list
    while run.index <= #list do
        local entry = list[run.index]
        run.index = run.index + 1
        if Classify.BagSlot(entry[1], entry[2], run.holdings) then
            run.count = run.count + 1
        end
        done = done + 1
        if first then
            if Clock() - started > Classify.BUDGET_MS then
                break
            end
        elseif done >= Classify.BATCH_SIZE then
            break
        end
    end
    run.ms = run.ms + (Clock() - started)
    if run.index > #list then
        Finish(run)
        return true
    end
    C_Timer.After(0, function()
        Continue(run)
    end)
    return true
end

-- One later batch. A pass that was replaced stops; combat defers the rest of
-- the pass, which starts again when combat ends (the finished slots are
-- cached, so the second pass is quick).
function Continue(run)
    if runs[run.scope] ~= run then
        return
    end
    if run.scope == "bank" and not Snapshot.IsBankOpen() then
        -- BANKFRAME_CLOSED: stop classifying bank slots (findings 15).
        runs.bank = nil
        return
    end
    if InCombatLockdown() then
        runs[run.scope] = nil
        deferred[run.scope] = true
        return
    end
    if not Log.Guard("engine", Advance, run, false) then
        -- A failed batch ends the run; the next Pass or OnLoaded restarts it.
        runs[run.scope] = nil
    end
end

--- Classifies every slot of the bags or of the bank: the initial classification
--- and the bank classification of technical findings 15. Nothing runs in
--- combat (spec 7.5, Combat): the pass is deferred until PLAYER_REGEN_ENABLED.
--- Writes the debug "classify" line when it finishes. Starting a pass for a
--- scope replaces one still under way.
-- @param scope string "bags" or "bank"
-- @treturn boolean true when the pass started, false when deferred or when
--   the bank is closed
function Classify.Pass(scope)
    local range = Slots.bags
    if scope == "bank" then
        if not Snapshot.IsBankOpen() then
            return false
        end
        range = Slots.bankTabs
    end
    runs[scope] = nil
    dirty[scope] = nil
    if InCombatLockdown() then
        deferred[scope] = true
        return false
    end
    deferred[scope] = nil
    local run = {
        scope = scope,
        list = SlotList(range),
        holdings = ItemFacts.Holdings(range.first),
        index = 1,
        count = 0,
        ms = 0,
    }
    runs[scope] = run
    Log.Guard("engine", Advance, run, true)
    return true
end

-- The events are from memory (technical findings 15; live checks L40, L28).
-- The snapshot of PLAYER_ENTERING_WORLD is debounced, so the initial
-- classification is debounced the same way: it restarts with each event and
-- its timer is made after the snapshot's, so it runs once, after the snapshot.
local passLater = Util.Debounce(Snapshot.DEBOUNCE_SECONDS, function()
    Log.Guard("engine", Classify.Pass, "bags")
end)

Events.Register("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        passLater()
    end
end)

Events.Register("BANKFRAME_OPENED", function()
    Classify.Pass("bank")
end)

Events.Register("PLAYER_REGEN_ENABLED", function()
    for _, scope in ipairs({ "bags", "bank" }) do
        if deferred[scope] then
            Classify.Pass(scope)
        end
    end
end)

-- Items with no result yet are classified again when their data has loaded
-- (spec 7.2 step 0).
-- A scope with a pass under way is marked dirty instead of restarted, so a
-- spread pass keeps its place; it runs once more when it finishes.
local function RefreshAfterLoad()
    for _, scope in ipairs({ "bags", "bank" }) do
        if runs[scope] then
            dirty[scope] = true
        else
            Classify.Pass(scope)
        end
    end
end

ItemFacts.OnLoaded(RefreshAfterLoad)
Scoring.OnOwnedStatsRecovered(function()
    Cache.Clear()
    RefreshAfterLoad()
end)

-- A pass deferred in combat does not outlive the bank window.
Events.Register("BANKFRAME_CLOSED", function()
    deferred.bank = nil
end)
