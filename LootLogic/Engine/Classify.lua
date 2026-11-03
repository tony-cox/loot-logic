--[[
The classification order of spec 7.2, first part (milestone M0, stage 12):
the guarded and cached frame, step 0 (pending), the hard stays of step 1, the
grey rule of step 2, the wants of step 4, the class dispositions of step 5 and
the sell rules of step 6, with the AH rule of spec 7.4. Step 3 (gear) is not
here yet: a gear item passes from step 2 to step 4 as if step 3 had matched
nothing, and stage 13 inserts step 3 at the marked place.

A result is { category, reasonCode, reasonText, linkOnly } (spec 12.4 and
technical findings 14, as D150 sets it for M0) plus reasonData, an internal
field that no doc lists yet. category is "none",
"char:<key>", "ah", "vendor" or "vendorah". reasonText is filled in by the
reason texts of stage 14, except for the error result, which carries its text
from the start. reasonData holds the values the text needs (an internal
table, so the texts and M1's detail lines read one source): the winner and
kind of a want, the set of an `inset` stay, the price of a Vendor/AH, AH or
Vendor result, and the flags "refundable" and "noVendorValue".

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
local ItemClasses = ns.ItemClasses
local ItemFacts = ns.ItemFacts
local L = ns.L
local Log = ns.Log
local Prices = ns.Prices
local Roster = ns.Roster
local Sets = ns.Sets
local Slots = ns.Slots

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
-- Data/Slots.lua and the item is not cosmetic armour (4:5). A profession tool
-- is taken out before this is asked (step 1d).
local function IsGear(facts)
    if not Slots.invTypeGroup[facts.equipLoc] then
        return false
    end
    return not (facts.classID == 4 and facts.subclassID == 5)
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
        if facts.vendorPrice > 0 then
            return Result("vendor", "grey", { vendor = facts.vendorPrice })
        end
        return Result("none", "novalue")
    end
    -- Step 3 (gear) goes here in stage 13.
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

-- The order of spec 7.2, and the refundable flag of spec 7.6 ("Any bag item's
-- reason adds "; refundable""), which stage 14 reads from the reason data. The
-- cache key does not include the refund state, so a purchase that stops being
-- refundable is noticed when the key or a generation changes (live check L55).
local function Run(context, facts)
    local result = Steps(context, facts)
    if facts.refundable then
        result.reasonData.refundable = true
    end
    return result
end

local function ErrorResult()
    local errorResult = Result("none", "error")
    errorResult.reasonText = L.errorEngine
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

-- Runs the order under the engine guard, and turns a nil (an error) into the
-- error result. The error is recorded and the chat line printed once per
-- session by Log.Guard.
local function Guarded(context, facts)
    local result = Log.Guard("engine", Run, context, facts)
    if result then
        return result, false
    end
    return ErrorResult(), true
end

--- The result for the item in a bag slot, from the cache when it is fresh.
--- Returns nil when the slot is empty or the item is still pending: its data
--- is not loaded, a value is hidden in combat, or a tooltip fact could not be
--- read (spec 7.2 step 0; nothing is cached).
-- @param bag number
-- @param slot number
-- @param holdings table|nil from ItemFacts.Holdings(bag), shared by a pass
-- @treturn table|nil result
function Classify.BagSlot(bag, slot, holdings)
    local read = Log.Guard("engine", Read, bag, slot, holdings)
    if not read then
        -- The facts could not be read: the error result, with no key to cache.
        return ErrorResult()
    end
    if read.empty or read.pending then
        return nil
    end
    local facts, key = read.facts, read.key
    local cached = Cache.Get(key)
    if cached then
        return cached
    end
    local context = { seen = {}, used = {} }
    local result, failed = Guarded(context, facts)
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
