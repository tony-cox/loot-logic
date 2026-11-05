--[[
The /ll probe checks: the automatic live-client checks of technical findings
18, the list of the manual ones, and the saved record of each run. A check only
reports; a failure is reviewed by the team before any fallback is built.
The subject of each check is unverified until the live client (2026-11-05) and
is reported by that check. The other calls (UnitClass, GetBuildInfo,
C_Timer.After and the item and bag link reads) are from memory (API guess) and
are exercised by the /ll probe run itself (docs/TESTING.md, M1 step 1).
]]

local _, ns = ...

local Probe = {}
ns.Probe = Probe

local DB = ns.DB
local Events = ns.Events
local Init = ns.Init
local L = ns.L
local Log = ns.Log
local Snapshot = ns.Snapshot
local Specs = ns.Specs
local Util = ns.Util

local PASS = "PASS"
local FAIL = "FAIL"
local SKIP = "SKIP"

local STATUS_TEXT = {
    [PASS] = L.probePass,
    [FAIL] = L.probeFail,
    [SKIP] = L.probeSkip,
}

-- The L4 and L21 items of technical findings 18 are from the data dump of build
-- 1.60.1.70532: source-read, not yet seen on the live client. 2589 and 2880 are
-- the items the Exact tests of L5, L8, L9 and L31 name.
local LINEN_CLOTH = 2589
local WEAK_FLUX = 2880
local STEP_ITEMS = {
    { itemID = 263307, label = L.probeSpellPower },
    { itemID = 286745, label = L.probeHealing },
    { itemID = 2907, label = L.probeExpertise },
    { itemID = 6463, label = L.probeSpellPiercing },
}
local UNIQUE_RING = 20429

-- L58 and L28 (technical findings 18, the candidate list). The candidate IDs
-- are the Classic ones or another session's read of the beta data. -1 is the
-- live-confirmed "does not exist" half of L58; 99999999 returns true here.
local CANDIDATES = { 19019, 17182, 13262, 18608, 17204 }
local MISSING_ITEM = -1
local ITEM_WAIT_SECONDS = 10
local CANCEL_WAIT_SECONDS = 1.5

local PROFICIENCY_SPELLS = { 9078, 9077, 8737, 750, 9116, 674, 198, 199, 227, 1180 }
local CLOTH_SPELL = 9078
local CONTAINER_FIELDS = { "isBound", "hasNoValue", "stackCount", "quality", "hyperlink" }
local SUBCLASS_RANGES = { { 0, 2 }, { 5, 12 } }
local REQUIRED_TYPES = {
    { 7, 0, 2 },
    { 7, 5, 12 },
    { 2, 13, 20 },
}
local TYPE_LIMIT = 20
local FERAL_TREE = "Feral Combat"
local LINK_FORMS = {
    "^|cnIQ%d[^|]*|Hitem:",
    "^|cff%x%x%x%x%x%x|Hitem:",
}
-- The saved key or build when GetServerTime or GetBuildInfo gives no usable
-- value.
local UNKNOWN = "unknown"

-- The manual checks (Probe column "manual") in number order, with L5 standing
-- for its above-level part, and the ones spec 19 gives M1.
local MANUAL_IDS = {
    1,
    3,
    5,
    11,
    12,
    13,
    14,
    16,
    17,
    18,
    20,
    23,
    25,
    26,
    27,
    29,
    30,
    32,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    49,
    50,
    51,
    53,
    54,
    55,
    56,
    57,
    59,
    60,
}
local M1_MANUAL = {
    [1] = true,
    [3] = true,
    [5] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [20] = true,
    [23] = true,
    [25] = true,
    [26] = true,
    [27] = true,
    [32] = true,
    [40] = true,
    [43] = true,
    [46] = true,
    [49] = true,
    [51] = true,
    [53] = true,
    [55] = true,
    [56] = true,
    [57] = true,
    [59] = true,
    [60] = true,
}

-- True from the start of a run until "probe done" prints.
local active = false
-- The L28 mark: the item whose ITEM_DATA_LOAD_RESULT the probe waits for.
local awaited

-- A value as the debug event line writes it (technical findings 14, Events).
local function Describe(value)
    if Util.IsSecret(value) then
        return "<secret>"
    end
    if type(value) == "table" then
        return "<table>"
    end
    return tostring(value)
end

local function Show(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = Describe((select(index, ...)))
    end
    return table.concat(parts, ", ")
end

-- True when at least one value is not nil, then the values as text.
local function Report(...)
    for index = 1, select("#", ...) do
        if select(index, ...) ~= nil then
            return true, Show(...)
        end
    end
    return false, Show(...)
end

local function Filled(value)
    return type(value) == "string" and value ~= ""
end

local function SortedKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

local function Overall(statuses)
    local passed = false
    for _, status in ipairs(statuses) do
        if status == FAIL then
            return FAIL
        end
        if status == PASS then
            passed = true
        end
    end
    if passed then
        return PASS
    end
    return SKIP
end

local function Joined(texts)
    return table.concat(texts, "; ")
end

-- The link of the item when its data has loaded; nil until then. The call also
-- requests the item (from memory; live check L28).
local function LoadedLink(itemID)
    local _, link = C_Item.GetItemInfo(itemID)
    return link
end

local function CheckL2()
    local first, last = UnitName("player")
    if Filled(first) and Filled(last) then
        return PASS, Show(first, last)
    end
    return FAIL, Show(first, last)
end

local function StatsOf(link)
    local stats = C_Item.GetItemStats(link)
    if type(stats) ~= "table" then
        return nil, string.format(L.probeNotTable, Describe(stats))
    end
    return stats, SortedKeys(stats)
end

local function HasRatingKey(stats)
    for key in pairs(stats) do
        if string.find(tostring(key), "_RATING", 1, true) then
            return true
        end
    end
    return false
end

local function CheckL4()
    local statuses = {}
    local texts = {}
    local function Add(label, status, text)
        statuses[#statuses + 1] = status
        texts[#texts + 1] = string.format(L.probeStep, label, STATUS_TEXT[status], text)
    end

    local slotLabel = string.format(L.probeSlotStep, 5)
    local worn = GetInventoryItemLink("player", 5)
    if not worn then
        Add(slotLabel, SKIP, string.format(L.probeSlotEmpty, 5))
    else
        local stats, keys = StatsOf(worn)
        if not stats then
            Add(slotLabel, FAIL, keys)
        elseif not HasRatingKey(stats) then
            Add(slotLabel, SKIP, string.format(L.probeNoRatingKey, keys))
        else
            Add(slotLabel, PASS, keys)
        end
    end

    for _, step in ipairs(STEP_ITEMS) do
        local label = string.format(L.probeItemStep, step.label, step.itemID)
        local link = LoadedLink(step.itemID)
        if not link then
            Add(label, SKIP, L.probeNotLoaded)
        else
            local stats, keys = StatsOf(link)
            if stats then
                Add(label, PASS, keys)
            else
                Add(label, FAIL, keys)
            end
        end
    end
    return Overall(statuses), Joined(texts)
end

local function CheckL5()
    if not (C_PlayerInfo and C_PlayerInfo.CanUseItem) then
        return FAIL, L.probeCallMissing
    end
    local answer = C_PlayerInfo.CanUseItem(LINEN_CLOTH)
    if type(answer) == "boolean" then
        return PASS, tostring(answer)
    end
    return FAIL, Describe(answer)
end

local function CheckL6()
    local texts = {}
    local allBooleans = true
    local cloth
    for _, spellID in ipairs(PROFICIENCY_SPELLS) do
        local known = IsPlayerSpell(spellID)
        if type(known) ~= "boolean" then
            allBooleans = false
        end
        if spellID == CLOTH_SPELL then
            cloth = known
        end
        texts[#texts + 1] = spellID .. "=" .. Describe(known)
    end
    local value = table.concat(texts, " ")
    if allBooleans and cloth == true then
        return PASS, value
    end
    return FAIL, value
end

local function CheckL7()
    local info = C_Container.GetContainerItemInfo(0, 1)
    if not info then
        return SKIP, string.format(L.probeBagEmpty, 0, 1)
    end
    local quest = C_Container.GetContainerItemQuestInfo(0, 1)
    local missing = {}
    local texts = {}
    for _, field in ipairs(CONTAINER_FIELDS) do
        if info[field] == nil then
            missing[#missing + 1] = field
        end
        texts[#texts + 1] = field .. "=" .. Describe(info[field])
    end
    local questItem
    if quest then
        questItem = quest.isQuestItem
    end
    if questItem == nil then
        missing[#missing + 1] = "isQuestItem"
    end
    texts[#texts + 1] = "isQuestItem=" .. Describe(questItem)
    if #missing > 0 then
        return FAIL, string.format(L.probeMissingFields, table.concat(missing, ", "))
    end
    return PASS, table.concat(texts, " ")
end

local function CheckL8()
    local parts = {}
    local problems = 0
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(LINEN_CLOTH)
    parts[#parts + 1] = string.format(L.probeClassItem, Describe(class), Describe(subclass))
    if class ~= 7 or subclass ~= 5 then
        problems = problems + 1
    end

    local head = GetInventoryItemLink("player", 1)
    if head then
        local slotType = select(4, C_Item.GetItemInfoInstant(head))
        parts[#parts + 1] = string.format(L.probeHeadSlot, Describe(slotType))
        if slotType ~= "INVTYPE_HEAD" then
            problems = problems + 1
        end
    else
        parts[#parts + 1] = L.probeHeadNotRun
    end

    local absent = {}
    for _, range in ipairs(SUBCLASS_RANGES) do
        for subclassID = range[1], range[2] do
            if not C_Item.GetItemSubClassInfo(7, subclassID) then
                absent[#absent + 1] = "7:" .. subclassID
            end
        end
    end
    if #absent > 0 then
        problems = problems + 1
        parts[#parts + 1] = string.format(L.probeNamesMissing, table.concat(absent, ", "))
    end

    -- Printed, not tested (technical findings 18).
    for _, subclassID in ipairs({ 9, 17 }) do
        local name = C_Item.GetItemSubClassInfo(2, subclassID)
        parts[#parts + 1] = string.format(L.probeName, "2:" .. subclassID, Describe(name))
    end

    local status = PASS
    if problems > 0 then
        status = FAIL
    end
    return status, Joined(parts)
end

-- The two halves of L9 run the providers' own calls (technical findings 11.1,
-- 11.2), not Prices.Status(). Each half runs under pcall: another addon's call
-- can raise.
local function AuctionatorHalf()
    if not Auctionator then
        return SKIP, L.probeAbsent
    end
    local api = Auctionator.API and Auctionator.API.v1
    if
        type(api) ~= "table"
        or type(api.GetAuctionPriceByItemID) ~= "function"
        or type(api.GetAuctionAgeByItemID) ~= "function"
    then
        return FAIL, L.probeApiMissing
    end
    local price = api.GetAuctionPriceByItemID("LootLogic", LINEN_CLOTH)
    if price == nil then
        return SKIP, L.probeNoPrice
    end
    local age = api.GetAuctionAgeByItemID("LootLogic", LINEN_CLOTH)
    if age == nil then
        return SKIP, L.probeNoAge
    end
    local value = Show(price, age)
    if type(price) == "number" and type(age) == "number" and age == math.floor(age) then
        return PASS, value
    end
    return FAIL, string.format(L.probeWrongType, value)
end

local function AHDBHalf()
    if not AuctionDB then
        return SKIP, L.probeAbsent
    end
    local house = L.probeAliasAbsent
    if type(AuctionDB.PlayerHouse) == "function" then
        house = Describe(AuctionDB:PlayerHouse())
    end
    local houseText = string.format(L.probeHouse, house)
    if type(AuctionDB.LastPrice) ~= "function" then
        return FAIL, Joined({ L.probeLastPriceMissing, houseText })
    end
    local last = AuctionDB:LastPrice(LINEN_CLOTH, UnitFactionGroup("player"))
    if last == nil then
        return SKIP, Joined({ L.probeNoLastPrice, houseText })
    end
    if type(last) == "table" and type(last.ts) == "number" and type(last.min) == "number" then
        return PASS, Joined({ Show(last.ts, last.min), houseText })
    end
    return FAIL, Joined({ string.format(L.probeWrongShape, Describe(last)), houseText })
end

local function RunHalf(half)
    local ok, status, value = Util.Pcall(half)
    if not ok then
        return FAIL, status
    end
    return status, value
end

local function CheckL9()
    local auctionatorStatus, auctionatorValue = RunHalf(AuctionatorHalf)
    local ahdbStatus, ahdbValue = RunHalf(AHDBHalf)
    local value = Joined({
        string.format(
            L.probeHalf,
            L.probeAuctionator,
            STATUS_TEXT[auctionatorStatus],
            auctionatorValue
        ),
        string.format(L.probeHalf, L.probeAHDB, STATUS_TEXT[ahdbStatus], ahdbValue),
    })
    return Overall({ auctionatorStatus, ahdbStatus }), value
end

local function CheckL10()
    local missing = {}
    if not ContainerFrameCombinedBags then
        missing[#missing + 1] = "ContainerFrameCombinedBags"
    elseif not ContainerFrameCombinedBags.UpdateItems then
        missing[#missing + 1] = "ContainerFrameCombinedBags.UpdateItems"
    end
    if not ContainerFrame1 then
        missing[#missing + 1] = "ContainerFrame1"
    elseif not ContainerFrame1.UpdateItems then
        missing[#missing + 1] = "ContainerFrame1.UpdateItems"
    end
    if #missing > 0 then
        return FAIL, string.format(L.probeMissingRetry, table.concat(missing, ", "))
    end
    return PASS, L.probeFramesFound
end

local function CheckL15()
    if not LibStub then
        return SKIP, L.probeNoBetterBags
    end
    local ace = LibStub("AceAddon-3.0", true)
    local addon = ace and ace:GetAddon("BetterBags", true)
    if not addon then
        return SKIP, L.probeNoBetterBags
    end
    -- GetModule raises an error when the module does not exist (from memory);
    -- Util.Pcall in the runner reports that as FAIL with its text.
    local categories = addon:GetModule("Categories")
    local register = categories and categories.RegisterCategoryFunction
    local reprocess = categories and categories.ReprocessAllItems
    local value = Show(type(register), type(reprocess))
    if type(register) == "function" and type(reprocess) == "function" then
        return PASS, value
    end
    return FAIL, value
end

local function CheckL19()
    if not EUI_Bags then
        return SKIP, L.probeAbsent
    end
    local register = EUI_Bags.RegisterItemOverlayIcon
    if type(register) == "function" then
        return PASS, type(register)
    end
    return FAIL, string.format(L.probeNotFunction, Describe(register))
end

local function CheckL21()
    if not C_Item.GetItemUniquenessByID then
        return FAIL, L.probeUniquenessMissing
    end
    if not LoadedLink(UNIQUE_RING) then
        return SKIP, L.probeNotLoaded
    end
    local anyValue, text = Report(C_Item.GetItemUniquenessByID(UNIQUE_RING))
    if anyValue then
        return PASS, text
    end
    return FAIL, L.probeReturnedNothing
end

local function CheckL22()
    local link = GetInventoryItemLink("player", 16)
    if not link then
        return SKIP, string.format(L.probeSlotEmpty, 16)
    end
    local tooltip = C_TooltipInfo.GetHyperlink(link)
    if not WEAPON_SPEED or not tooltip or not tooltip.lines then
        return FAIL, L.probeNoWeaponSpeed
    end
    local pattern = Util.FormatPattern(WEAPON_SPEED)
    for _, line in ipairs(tooltip.lines) do
        for _, text in ipairs({ line.leftText or "", line.rightText or "" }) do
            if type(text) == "string" and string.find(text, pattern) then
                return PASS, text
            end
        end
    end
    return FAIL, L.probeNoSpeedLine
end

local function CheckL24()
    local call = C_Item.IsBoundToAccountUntilEquip
    if type(call) == "function" then
        return PASS, type(call)
    end
    return FAIL, string.format(L.probeNotFunction, Describe(call))
end

local function CheckL31()
    -- Both calls run, so both items are requested.
    local _, _, _, _, _, _, _, linen = C_Item.GetItemInfo(LINEN_CLOTH)
    local _, _, _, _, _, _, _, flux = C_Item.GetItemInfo(WEAK_FLUX)
    if linen == nil or flux == nil then
        return SKIP, L.probeNotLoaded
    end
    local value = string.format(L.probeStacks, Describe(linen), Describe(flux))
    if linen == 20 and flux == 10 then
        return PASS, value
    end
    return FAIL, value
end

local function CheckL33()
    if not Snapshot.IsBankOpen() then
        return SKIP, L.probeBankClosed
    end
    local answer
    if C_Bank and C_Bank.CanUseBank and Enum.BankType then
        answer = C_Bank.CanUseBank(Enum.BankType.Account)
    end
    local value = string.format(L.probeBankValue, Describe(answer))
    if answer == true then
        return FAIL, value
    end
    return PASS, value
end

-- Whether any return is a label, and every return as text (a nil among them
-- still counts as a position, technical findings 18, L48).
local function MatchReturns(labels, ...)
    local matched = false
    for position = 1, select("#", ...) do
        local value = select(position, ...)
        if type(value) == "string" and labels[value] then
            matched = true
        end
    end
    return matched, Show(...)
end

local function CheckL48()
    if not GetNumTalentTabs then
        return SKIP, L.probeNoTabs
    end
    local count = GetNumTalentTabs()
    if not count or count == 0 then
        return SKIP, L.probeNoTabs
    end
    -- UnitClass is from memory (API guess), no live check beyond the probe run.
    local classToken = select(2, UnitClass("player"))
    local labels = {}
    for _, spec in pairs(Specs) do
        if spec.class == classToken then
            labels[spec.label] = true
        end
    end
    -- Feral Combat is the one tree that two specs share (Bear and Cat,
    -- technical findings 14.1 and 18, L48).
    if labels.Bear and labels.Cat then
        labels[FERAL_TREE] = true
    end
    local parts = { string.format(L.probeClass, Describe(classToken)) }
    local allMatch = true
    for index = 1, count do
        local matched, shown = MatchReturns(labels, GetTalentTabInfo(index))
        local verdict = L.probeMatch
        if not matched then
            allMatch = false
            verdict = L.probeNoMatch
        end
        parts[#parts + 1] = string.format(L.probeTab, index, shown, verdict)
    end
    local status = PASS
    if not allMatch then
        status = FAIL
    end
    return status, Joined(parts)
end

local function LinkPart(label, link)
    local formOk = false
    for _, pattern in ipairs(LINK_FORMS) do
        if string.find(link, pattern) then
            formOk = true
        end
    end
    local readable = formOk and Util.ParseLink(link) ~= nil
    local verdict = L.probeLinkBad
    if readable then
        verdict = L.probeLinkOk
    end
    local raw = string.gsub(link, "|", "||")
    return readable, string.format(L.probeLinkPart, label, verdict, raw)
end

local function FirstBagLink()
    for bag = 0, 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                return link, string.format(L.probeLinkBag, bag, slot)
            end
        end
    end
    return nil
end

local function CheckL52()
    local worn = GetInventoryItemLink("player", 5)
    local bagLink, bagLabel = FirstBagLink()
    if not worn and not bagLink then
        return SKIP, L.probeNoLinks
    end
    local texts = {}
    local allReadable = true
    if worn then
        local readable, text = LinkPart(string.format(L.probeLinkSlot, 5), worn)
        allReadable = allReadable and readable
        texts[#texts + 1] = text
    end
    if bagLink then
        local readable, text = LinkPart(bagLabel, bagLink)
        allReadable = allReadable and readable
        texts[#texts + 1] = text
    end
    local status = PASS
    if not allReadable then
        status = FAIL
    end
    return status, Joined(texts)
end

local function CheckL61()
    local names = {}
    local lines = {}
    local found = {}
    local function Note(id, name)
        found[id] = true
        names[#names + 1] = { id = id, name = name }
        lines[#lines + 1] = string.format(L.probeName, id, name)
    end
    for classID = 0, TYPE_LIMIT do
        local className = C_Item.GetItemClassInfo(classID)
        if className then
            Note(tostring(classID), className)
        end
        for subclassID = 0, TYPE_LIMIT do
            local subclassName = C_Item.GetItemSubClassInfo(classID, subclassID)
            if subclassName then
                Note(classID .. ":" .. subclassID, subclassName)
            end
        end
    end
    local missing = {}
    for _, range in ipairs(REQUIRED_TYPES) do
        for subclassID = range[2], range[3] do
            local id = range[1] .. ":" .. subclassID
            if not found[id] then
                missing[#missing + 1] = id
            end
        end
    end
    local extra = { lines = lines, names = names }
    if #missing > 0 then
        return FAIL, string.format(L.probeNamesMissing, table.concat(missing, ", ")), extra
    end
    return PASS, string.format(L.probeNamesFound, #names), extra
end

local function CheckL62()
    -- table.unpack and bit are read with rawget: the linter's Lua 5.1 standard
    -- does not list them.
    local unpackInTable = rawget(table, "unpack")
    local bitLibrary = rawget(_G, "bit")
    local value = Show(
        _VERSION,
        unpackInTable ~= nil,
        unpack ~= nil,
        setfenv ~= nil,
        math.pow ~= nil,
        bitLibrary ~= nil
    )
    if _VERSION == "Lua 5.1" and unpackInTable == nil then
        return PASS, value
    end
    return FAIL, value
end

local function FinishIfDone(run)
    if run.finished or not run.listDone or run.waiting > 0 then
        return
    end
    run.finished = true
    active = false
    Log.Chat(L.probeDone)
end

local function PrintResult(run, id, status, value, extra)
    Log.Chat(string.format(L.probeLine, id, STATUS_TEXT[status], value))
    local result = { status = status, value = value }
    if extra then
        for _, line in ipairs(extra.lines) do
            Log.Chat(line)
        end
        result.names = extra.names
    end
    run.results["L" .. id] = result
end

-- The lines of L28 and L63 print after the manual list, each when it is ready.
local function Late(run, id, status, value)
    if not run.pending[id] then
        return
    end
    run.pending[id] = nil
    run.waiting = run.waiting - 1
    if run.listDone then
        PrintResult(run, id, status, value)
        FinishIfDone(run)
    else
        run.queue[#run.queue + 1] = { id = id, status = status, value = value }
    end
end

local function FinishItemWait(mark, status, value)
    if mark.resolved then
        return
    end
    mark.resolved = true
    if awaited == mark then
        awaited = nil
    end
    Late(mark.run, 28, status, value)
end

local function ItemLoadedValue(mark)
    return string.format(
        L.probeLoaded,
        mark.itemID,
        mark.receivedAt - mark.requestedAt,
        Describe(mark.success)
    )
end

-- ITEM_DATA_LOAD_RESULT arrives as (itemID, success) (API guess, as
-- ItemFacts.lua assumes; live check L28). It counts only for the marked item.
-- An event that arrives before the wait opens is kept (technical findings 18).
local function OnItemData(_, itemID, success)
    local mark = awaited
    if not mark or mark.itemID ~= itemID or mark.receivedAt then
        return
    end
    local now = GetTime()
    if now - mark.requestedAt > ITEM_WAIT_SECONDS then
        -- Past the 10 seconds: the timeout path, whichever callback runs first
        -- (technical findings 18, the late lines; D121).
        if mark.waiting then
            FinishItemWait(mark, FAIL, L.probeNoEvent)
        end
        return
    end
    mark.receivedAt = now
    mark.success = success
    if mark.waiting then
        FinishItemWait(mark, PASS, ItemLoadedValue(mark))
    end
end

-- The wait is one C_Timer.After that checks whether the line already printed,
-- so it needs no Cancel (technical findings 17.1, clock rule).
local function OpenItemWait(run, mark)
    mark.run = run
    mark.waiting = true
    run.open[28] = true
    if mark.receivedAt then
        FinishItemWait(mark, PASS, ItemLoadedValue(mark))
        return
    end
    local delay = ITEM_WAIT_SECONDS - (GetTime() - mark.requestedAt)
    if delay < 0 then
        delay = 0
    end
    -- C_Timer.After: from memory (API guess), no live check of its own; if it
    -- fails, this check's line is FAIL with the error (docs/TESTING.md, M1
    -- step 1).
    C_Timer.After(delay, function()
        FinishItemWait(mark, FAIL, L.probeNoEvent)
    end)
end

-- Tries each candidate once: the L58 calls, with the L28 mark set before the
-- request. Returns the chosen ID with its three answers, or nil, and the list
-- of what each candidate returned.
local function SearchCandidates()
    local tried = {}
    for _, itemID in ipairs(CANDIDATES) do
        awaited = { itemID = itemID, requestedAt = GetTime() }
        local exists = C_Item.DoesItemExistByID(itemID)
        local absent = C_Item.DoesItemExistByID(MISSING_ITEM)
        local info = C_Item.GetItemInfo(itemID)
        tried[#tried + 1] = string.format(
            L.probeCandidate,
            itemID,
            Describe(exists),
            Describe(absent),
            Describe(info)
        )
        if exists == true and info == nil then
            return itemID, exists, absent, info, tried
        end
        awaited = nil
    end
    return nil, nil, nil, nil, tried
end

local function CheckL58(run)
    if not C_Item.DoesItemExistByID then
        Late(run, 28, SKIP, L.probeNoCandidateApi)
        return FAIL, L.probeCallMissing
    end
    local ok, itemID, exists, absent, info, tried = Util.Pcall(SearchCandidates)
    if not ok then
        awaited = nil
        Late(run, 28, SKIP, L.probeCandidateError)
        return FAIL, itemID
    end
    if not itemID then
        Late(run, 28, SKIP, L.probeNoCandidate)
        return SKIP, Joined(tried)
    end
    local waitOk, waitError = Util.Pcall(OpenItemWait, run, awaited)
    if not waitOk then
        -- The L58 answers stand; only the L28 wait failed to open.
        awaited.resolved = true
        awaited = nil
        Late(run, 28, FAIL, waitError)
    end
    local value =
        string.format(L.probeChosen, itemID, Describe(exists), Describe(absent), Describe(info))
    if absent == false then
        return PASS, value
    end
    return FAIL, value
end

local function Part(failures, name, test)
    local ok, result = Util.Pcall(test)
    if not ok then
        failures[#failures + 1] = string.format(L.probePartError, name, result)
    elseif not result then
        failures[#failures + 1] = name
    end
end

-- L63 (technical findings 18): the parts that answer at once, then a wait of
-- about 1.5 s for the cancelled timer. The line prints late.
local function CheckL63(run)
    run.open[63] = true
    local failures = {}
    local fired = false
    local timer
    local seen = {}
    Part(failures, "C_Timer.NewTimer", function()
        timer = C_Timer.NewTimer(1, function()
            fired = true
        end)
        return type(timer) == "table"
    end)
    if type(timer) == "table" then
        Part(failures, "Cancel", function()
            if type(timer.Cancel) ~= "function" then
                return false
            end
            timer:Cancel()
            return true
        end)
    end
    Part(failures, "GetServerTime", function()
        seen.serverTime = GetServerTime()
        return type(seen.serverTime) == "number"
    end)
    Part(failures, "date", function()
        seen.clock = date("%H:%M:%S", GetServerTime())
        return type(seen.clock) == "string" and string.find(seen.clock, "^%d%d:%d%d:%d%d$") ~= nil
    end)
    Part(failures, "GetTime", function()
        seen.now = GetTime()
        return type(seen.now) == "number"
    end)
    Part(failures, "GetAddOnMetadata", function()
        seen.version = Init.Version()
        return type(seen.version) == "string"
    end)
    -- C_Timer.After: from memory (API guess), no live check of its own; if it
    -- fails, this check's line is FAIL with the error (docs/TESTING.md, M1
    -- step 1).
    C_Timer.After(CANCEL_WAIT_SECONDS, function()
        if fired then
            failures[#failures + 1] = L.probeTimerFired
        end
        if #failures > 0 then
            Late(run, 63, FAIL, string.format(L.probeFailedParts, table.concat(failures, ", ")))
        else
            Late(run, 63, PASS, Show(seen.serverTime, seen.clock, seen.now, seen.version))
        end
    end)
end

-- The automatic checks in L-number order. L28 has no entry: it is decided by
-- L58, which finds the candidate. L63 is late: it prints through Late.
local CHECKS = {
    { id = 2, fn = CheckL2 },
    { id = 4, fn = CheckL4 },
    { id = 5, fn = CheckL5 },
    { id = 6, fn = CheckL6 },
    { id = 7, fn = CheckL7 },
    { id = 8, fn = CheckL8 },
    { id = 9, fn = CheckL9 },
    { id = 10, fn = CheckL10 },
    { id = 15, fn = CheckL15 },
    { id = 19, fn = CheckL19 },
    { id = 21, fn = CheckL21 },
    { id = 22, fn = CheckL22 },
    { id = 24, fn = CheckL24 },
    { id = 31, fn = CheckL31 },
    { id = 33, fn = CheckL33 },
    { id = 48, fn = CheckL48 },
    { id = 52, fn = CheckL52 },
    { id = 58, fn = CheckL58 },
    { id = 61, fn = CheckL61 },
    { id = 62, fn = CheckL62 },
    { id = 63, fn = CheckL63, late = true },
}

local function Execute(run, check)
    local ok, status, value, extra = Util.Pcall(check.fn, run)
    if check.late then
        if not ok then
            Late(run, check.id, FAIL, status)
        end
        return
    end
    if not ok then
        PrintResult(run, check.id, FAIL, status)
        return
    end
    PrintResult(run, check.id, status, value, extra)
end

-- The key is the server time as text, with -2, -3 and so on appended when that
-- key is already saved (spec 6, Probe runs). A GetServerTime or GetBuildInfo
-- that is missing, raises or gives no usable value is recorded as "unknown"
-- with one chat line, and the run goes on (technical findings 18, Output).
-- Returns the run: { results, pending, open, queue, listDone, waiting,
-- finished }; results is the results table of the run's record in
-- debug.probe.
local function NewRun()
    local data = DB.Data()
    if type(data.debug.probe) ~= "table" then
        data.debug.probe = {}
    end
    local runs = data.debug.probe
    local timeOk, serverTime = Util.Pcall(GetServerTime)
    local base = UNKNOWN
    if timeOk and type(serverTime) == "number" then
        base = tostring(serverTime)
    else
        Log.Chat(L.probeNoServerTime)
    end
    local key = base
    local number = 1
    while runs[key] do
        number = number + 1
        key = base .. "-" .. number
    end
    -- GetBuildInfo: from memory (API guess), no live check beyond the probe run
    -- (docs/TESTING.md, M1 step 1).
    local buildOk, version, build = Util.Pcall(GetBuildInfo)
    local buildText = UNKNOWN
    if buildOk and Filled(version) and Filled(build) then
        buildText = version .. "." .. build
    else
        Log.Chat(L.probeNoBuild)
    end
    local results = {}
    runs[key] = { build = buildText, results = results }
    return {
        results = results,
        pending = { [28] = true, [63] = true },
        open = {},
        queue = {},
        waiting = 2,
        listDone = false,
        finished = false,
    }
end

local function PrintManualList()
    for _, id in ipairs(MANUAL_IDS) do
        local format = L.probeManualLine
        if M1_MANUAL[id] then
            format = L.probeManualLineM1
        end
        Log.Chat(string.format(format, id, L["probeAssumptionL" .. id]))
    end
end

--- Runs the automatic checks, prints one line each, then the manual list, then
--- the late lines of L28 and L63 and "probe done". Refused while a run is
--- still waiting. Each run is kept as a new entry of debug.probe (spec 6).
function Probe.Run()
    if active then
        Log.Chat(L.probeBusy)
        return
    end
    local run = NewRun()
    active = true
    for _, check in ipairs(CHECKS) do
        Execute(run, check)
    end
    -- A check that failed before it opened its wait must not hold "probe done".
    if not run.open[28] then
        Late(run, 28, SKIP, L.probeNotRun)
    end
    if not run.open[63] then
        Late(run, 63, FAIL, L.probeNotRun)
    end
    PrintManualList()
    run.listDone = true
    for _, late in ipairs(run.queue) do
        PrintResult(run, late.id, late.status, late.value)
    end
    run.queue = {}
    FinishIfDone(run)
end

Events.Register("ITEM_DATA_LOAD_RESULT", OnItemData)
