--[[
Derived explanation data and the shared logical lines for Shift and /ll why
(spec 12.4 and 13; technical findings 14).
]]

local _, ns = ...

local Detail = {}
ns.Detail = Detail

local Asks = ns.Asks
local DB = ns.DB
local ItemFacts = ns.ItemFacts
local IsSoulbound = ns.Classify.IsSoulbound
local L = ns.L
local Prices = ns.Prices
local Roster = ns.Roster
local Scoring = ns.Scoring
local Util = ns.Util

local function Facts(context)
    if context.bag ~= nil then
        return ItemFacts.FromSlot(context.bag, context.slot, ItemFacts.Holdings(context.bag))
    end
    return ItemFacts.FromLink(context.link)
end

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

local function ItemName(item)
    if not item then
        return nil
    end
    if item.name then
        return item.name
    end
    if item.link then
        local name = C_Item.GetItemInfo(item.link)
        return name or item.link
    end
    return nil
end

local function Baseline(comparison, key)
    local items, locations = {}, {}
    if comparison.baselinePair then
        for index, piece in ipairs(comparison.baselinePair) do
            items[index] = ItemName(piece.item) or piece.name
            locations[index] = piece.where
        end
    elseif comparison.baselineItem then
        items[1] = ItemName(comparison.baselineItem)
        locations[1] = comparison.baselineWhere
    end
    local bankAge
    local bank = Roster.Entry(key).bank
    if bank and bank.updatedAt then
        bankAge = math.max(0, math.floor((GetServerTime() - bank.updatedAt) / 86400))
    end
    return items, locations, bankAge
end

local function Gear(result, facts, context)
    local key = result.reasonCode == "gearfor" and string.match(result.category, "^char:(.+)$")
        or Roster.HereKey()
    if not key or not Scoring.Group(facts) then
        return {}, false
    end
    local entries, pending = {}, false
    for order, loadout in ipairs(Scoring.Comparisons(key)) do
        local options = {
            loadout = loadout,
            fromInbox = context.fromInbox == true,
            fromInbound = context.fromInbound == true,
            lookAhead = key == Roster.HereKey() and result.reasonCode == "equipat",
        }
        local comparison = Scoring.Compare(facts, key, options)
        if comparison and comparison.pending then
            pending = true
        elseif comparison then
            local baselineItem, baselineWhere, bankAge = Baseline(comparison, key)
            entries[#entries + 1] = {
                key = key,
                order = order,
                loadout = loadout.name,
                spec = loadout.spec,
                assumed = loadout.assumed == true,
                itemLevel = comparison.itemLevel == true,
                candidate = comparison.candidate,
                itemScore = comparison.itemScore,
                candidateLevel = facts.itemLevel,
                baseline = comparison.baseline,
                baselineItem = baselineItem,
                baselineWhere = baselineWhere,
                bankAge = bankAge,
                gainPct = comparison.gainPct,
                upgrade = comparison.upgrade,
            }
        end
    end
    table.sort(entries, function(a, b)
        if a.gainPct ~= b.gainPct then
            return a.gainPct > b.gainPct
        end
        return a.order < b.order
    end)
    return entries, pending
end

local function Price(facts, result)
    local reasonData = result.reasonData or {}
    local existing = reasonData.price
    local price, source
    local stale = result.reasonCode == "stale"
    if existing then
        price = existing
        source = { label = existing.label or existing.source or reasonData.provider }
    else
        price, source = Prices.Best(facts.itemID, facts.link)
        if not price and source and source.code == "stale" then
            price = source.price
            stale = true
        end
    end
    if not price then
        return nil
    end
    local settings = DB.Data().settings.ah
    local vendor = facts.vendorPrice or 0
    local net = math.floor(price.unit * (100 - settings.ahCutPct) / 100)
    local gainPerUnit = net - vendor
    return {
        source = source.label or source.id or source.provider or L.detailUnknownSource,
        unit = price.unit,
        ageDays = price.ageDays,
        net = net,
        vendor = vendor,
        gainPerUnit = gainPerUnit,
        gainTotal = gainPerUnit * (facts.holding or 1),
        minGainCopper = settings.minGainCopper,
        minGainPct = settings.minGainPct,
        stale = stale,
    }
end

function Detail.Attach(result, context)
    local facts = Facts(context)
    if not facts or facts.pending or facts.secret or facts.tooltipUnread then
        result.detail = nil
        return result
    end
    local wantFacts = WantFacts(facts)
    local wanters = Asks.Wanters(wantFacts)
    local wants
    if #wanters > 0 then
        local winner = result.reasonCode == "wantedhere" and Roster.HereKey()
            or result.reasonCode == "wanted" and string.match(result.category, "^char:(.+)$")
            or result.reasonData and result.reasonData.winner
        if not winner and Asks.Matches(Roster.HereKey(), wantFacts) then
            winner = Roster.HereKey()
        end
        local tradable = not IsSoulbound(facts)
        if not winner and tradable then
            for _, key in ipairs(Roster.EligibleKeys()) do
                if Asks.Matches(key, wantFacts) then
                    winner = key
                    break
                end
            end
        end
        if not winner then
            winner = L.detailWantNoWinner
        end
        wants = { winner = winner, others = {} }
        for _, key in ipairs(wanters) do
            if key ~= winner then
                local kind = Asks.MatchKind(key, wantFacts)
                local why = key ~= Roster.HereKey()
                        and not Roster.IsEligible(key)
                        and L.detailWantIneligible
                    or not tradable and L.detailWantBound
                    or kind == "item" and L.detailWantItem
                    or kind and Util.TypeName(facts.classID, facts.subclassID)
                    or L.detailWantRule
                wants.others[#wants.others + 1] = { key = key, why = why }
            end
        end
    end
    local gear, gearPending = Gear(result, facts, context)
    result.detail = {
        wants = wants,
        gear = gear,
        gearPending = gearPending,
        price = Price(facts, result),
    }
    return result
end

local function Name(key)
    return key == Roster.HereKey() and L.detailYou or Roster.DisplayName(key) or key
end

local function Percent(value)
    if value == math.huge then
        return L.detailInfinite
    end
    local rounded = math.floor(value * 10 + 0.5) / 10
    if rounded == math.floor(rounded) then
        return tostring(math.floor(rounded))
    end
    return tostring(rounded)
end

-- A computed score to two decimals, without trailing zeros.
local function Score(value)
    local text = string.format("%.2f", value)
    return (string.gsub(string.gsub(text, "(%.%d-)0+$", "%1"), "%.$", ""))
end

local function SignedMoney(value)
    if value < 0 then
        return "-" .. Util.FormatMoney(-value)
    end
    return Util.FormatMoney(value)
end

local function GearLine(entry)
    local baseline
    if #(entry.baselineItem or {}) == 0 then
        baseline = L.detailEmpty
    else
        local pieces = {}
        for index, name in ipairs(entry.baselineItem) do
            local where = entry.baselineWhere and entry.baselineWhere[index]
            local location = where == "worn" and L.reasonWhereWorn
                or where == "bags" and L.reasonWhereBags
                or where == "bank" and L.reasonWhereBank
                or where == "inbox" and L.reasonWhereMail
            pieces[#pieces + 1] = location and (name .. ", " .. location) or name
        end
        baseline = table.concat(pieces, L.detailAnd)
    end
    local text = string.format(
        L.detailGear,
        Name(entry.key),
        entry.loadout,
        Percent(entry.gainPct),
        entry.upgrade and L.detailOver or L.detailVs,
        baseline
    )
    if entry.assumed then
        text = text .. L.reasonAssumed
    end
    if entry.itemLevel then
        text = text .. L.reasonIlvl
    elseif entry.itemScore then
        local score = Score(entry.itemScore)
        if score == "0" or score == "-0" then
            text = text .. string.format(L.detailScoreZero, entry.candidateLevel or "?")
        else
            text = text .. string.format(L.detailScore, score)
        end
    end
    local hasBankBaseline = false
    for _, where in ipairs(entry.baselineWhere or {}) do
        if where == "bank" then
            hasBankBaseline = true
            break
        end
    end
    if hasBankBaseline then
        text = text
            .. (
                entry.bankAge and string.format(L.detailBankSeen, entry.bankAge)
                or L.detailBankNotSeen
            )
    end
    return text
end

function Detail.Lines(result)
    if not result then
        return {}
    end
    local lines, gearLines = { result.line }, {}
    local detail = result.detail or {}
    if detail.wants then
        local text = L.detailWants .. Name(detail.wants.winner)
        for _, other in ipairs(detail.wants.others) do
            text = text .. ", " .. Name(other.key) .. " (" .. other.why .. ")"
        end
        lines[#lines + 1] = text
    end
    for _, entry in ipairs(detail.gear or {}) do
        gearLines[#gearLines + 1] = GearLine(entry)
    end
    local runners = result.reasonData and result.reasonData.runnerUps or {}
    local otherLines = {}
    if #runners > 0 then
        local names = {}
        for index = 1, math.min(2, #runners) do
            names[#names + 1] = Name(runners[index].key)
                .. " +"
                .. Percent(runners[index].gainPct)
                .. "%"
        end
        otherLines[#otherLines + 1] = L.detailRunners .. table.concat(names, ", ")
    end
    if detail.gearPending then
        otherLines[#otherLines + 1] = L.detailLoading
    end
    local price = detail.price
    if price then
        local stale = price.stale and L.detailStale or ""
        local age
        if price.ageDays == nil then
            age = L.reasonAgeOver
        elseif price.ageDays == 0 then
            age = L.reasonAgeToday
        else
            age = string.format(L.reasonAgeDays, price.ageDays)
        end
        otherLines[#otherLines + 1] = string.format(
            L.detailPrice,
            price.source,
            Util.FormatMoney(price.unit),
            age,
            Util.FormatMoney(price.net),
            stale
        )
        otherLines[#otherLines + 1] = string.format(
            L.detailGain,
            SignedMoney(price.gainPerUnit),
            SignedMoney(price.gainTotal),
            Util.FormatMoney(price.minGainCopper),
            price.minGainPct
        )
    end
    local reserved = #lines + #otherLines
    local keep = math.max(0, 8 - reserved)
    if #gearLines > keep then
        local removed = #gearLines - keep
        while #gearLines > keep do
            table.remove(gearLines)
        end
        if #gearLines > 0 then
            gearLines[#gearLines] = gearLines[#gearLines] .. string.format(L.detailMore, removed)
        end
    end
    for _, line in ipairs(gearLines) do
        lines[#lines + 1] = line
    end
    for _, line in ipairs(otherLines) do
        lines[#lines + 1] = line
    end
    return lines
end

return Detail
