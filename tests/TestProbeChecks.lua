local _, ns, h = ...

local L = ns.L
local Stub = h.Stub

local PREFIX = L.chatPrefix .. " "

local function Load()
    LootLogicDB = nil
    Stub.FireEvent("ADDON_LOADED", "LootLogic")
    Stub.ClearChat()
end

-- Runs the probe to its end and returns the status and value of one check.
local function Check(id)
    ns.Probe.Run()
    Stub.Advance(11)
    local pattern = "^" .. PREFIX .. "L" .. id .. " (%u+) (.*)$"
    for _, line in ipairs(Stub.ChatLines()) do
        local status, value = string.match(line, pattern)
        if status then
            return status, value
        end
    end
    return nil, nil
end

local function Expect(id, expectedStatus)
    local status, value = Check(id)
    h.Equal(status, expectedStatus, "L" .. id .. " status (" .. tostring(value) .. ")")
    return value
end

local function Has(value, text)
    h.True(string.find(value, text, 1, true), "'" .. value .. "' holds '" .. text .. "'")
end

local function Nothing() end

local function LoadStepItems()
    Stub.SetItem(263307, { stats = { ITEM_MOD_SPELL_POWER_SHORT = 10 } })
    Stub.SetItem(286745, { stats = { ITEM_MOD_HEALING_POWER_SHORT = 10 } })
    Stub.SetItem(2907, { stats = { ITEM_MOD_EXPERTISE_RATING_SHORT = 10 } })
    Stub.SetItem(6463, { stats = { ITEM_MOD_SPELL_PENETRATION_SHORT = 10 } })
end

local function PendStepItems()
    for _, itemID in ipairs({ 263307, 286745, 2907, 6463 }) do
        Stub.SetItemPending(itemID, {})
    end
end

local function SetTypeNames()
    local classes = { [0] = "Consumable", [2] = "Weapon", [7] = "Trade Goods" }
    local subclasses = { [2] = {}, [7] = {} }
    for subclass = 13, 20 do
        subclasses[2][subclass] = "Weapon " .. subclass
    end
    for _, subclass in ipairs({ 0, 1, 2, 5, 6, 7, 8, 9, 10, 11, 12 }) do
        subclasses[7][subclass] = "Goods " .. subclass
    end
    Stub.SetItemTypeNames(classes, subclasses)
    return classes, subclasses
end

local function ReadyForL8()
    Stub.SetItemInstant(2589, { classID = 7, subclassID = 5 })
    local _, subclasses = SetTypeNames()
    subclasses[2][9] = "Staves"
    subclasses[2][17] = "Polearms"
    Stub.SetItemTypeNames({ [2] = "Weapon", [7] = "Trade Goods" }, subclasses)
end

local function LoadedAuctionDB(last)
    return {
        PlayerHouse = function()
            return "Horde"
        end,
        LastPrice = function()
            return last
        end,
    }
end

local function BetterBagsCategories()
    return {
        RegisterCategoryFunction = Nothing,
        ReprocessAllItems = Nothing,
    }
end

return {
    ["Checks: L4 is SKIP with an empty slot 5 and every fixed item pending"] = function()
        Load()
        PendStepItems()
        local value = Expect(4, "SKIP")
        Has(value, string.format(L.probeSlotEmpty, 5))
        Has(value, L.probeNotLoaded)
    end,

    ["Checks: L4 passes with the keys once the fixed items are loaded"] = function()
        Load()
        LoadStepItems()
        local value = Expect(4, "PASS")
        Has(value, "ITEM_MOD_SPELL_POWER_SHORT")
        Has(value, "ITEM_MOD_HEALING_POWER_SHORT")
        Has(value, "ITEM_MOD_EXPERTISE_RATING_SHORT")
        Has(value, "ITEM_MOD_SPELL_PENETRATION_SHORT")
    end,

    ["Checks: L4 passes when one fixed item loaded and the others are pending"] = function()
        Load()
        PendStepItems()
        Stub.SetItem(2907, { stats = { ITEM_MOD_EXPERTISE_RATING_SHORT = 10 } })
        local value = Expect(4, "PASS")
        Has(value, "SKIP")
        Has(value, "ITEM_MOD_EXPERTISE_RATING_SHORT")
    end,

    ["Checks: L4 passes on a slot 5 item with a rating key"] = function()
        Load()
        Stub.SetItem(555, { stats = { ITEM_MOD_CRIT_RATING_SHORT = 5 } })
        Stub.SetWornLink(5, "item:555")
        PendStepItems()
        local value = Expect(4, "PASS")
        Has(value, "ITEM_MOD_CRIT_RATING_SHORT")
    end,

    ["Checks: L4 is SKIP when the slot 5 item has no rating key"] = function()
        Load()
        Stub.SetItem(555, { stats = { ITEM_MOD_STAMINA_SHORT = 5 } })
        Stub.SetWornLink(5, "item:555")
        PendStepItems()
        local value = Expect(4, "SKIP")
        Has(value, "ITEM_MOD_STAMINA_SHORT")
    end,

    ["Checks: L4 fails when one step fails and another passes"] = function()
        Load()
        -- Item 555 is unknown, so GetItemStats gives nil for the slot 5 link.
        Stub.SetWornLink(5, "item:555")
        LoadStepItems()
        Expect(4, "FAIL")
    end,

    ["Checks: L5 passes on a boolean answer"] = function()
        Load()
        Expect(5, "PASS")
    end,

    ["Checks: L5 fails when the call is missing"] = function()
        Load()
        Stub.SetCanUseAPI(false)
        local value = Expect(5, "FAIL")
        h.Equal(value, L.probeCallMissing, "value")
    end,

    ["Checks: L5 fails on an answer that is not a boolean"] = function()
        Load()
        Stub.SetGlobal("C_PlayerInfo", {
            CanUseItem = function()
                return "yes"
            end,
        })
        Expect(5, "FAIL")
    end,

    ["Checks: L6 passes when Cloth is known"] = function()
        Load()
        Stub.SetKnownSpells({ 9078, 750 })
        local value = Expect(6, "PASS")
        Has(value, "9078=true")
        Has(value, "9077=false")
    end,

    ["Checks: L6 fails when a return is not a boolean"] = function()
        Load()
        Stub.SetGlobal("IsPlayerSpell", function(spellID)
            if spellID == 9077 then
                return nil
            end
            return true
        end)
        local value = Expect(6, "FAIL")
        Has(value, "9077=nil")
    end,

    ["Checks: L6 fails when Cloth is unknown"] = function()
        Load()
        Stub.SetKnownSpells({ 750 })
        Expect(6, "FAIL")
    end,

    ["Checks: L7 is SKIP on an empty bag 0 slot 1"] = function()
        Load()
        Expect(7, "SKIP")
    end,

    ["Checks: L7 passes with every field"] = function()
        Load()
        Stub.SetBagItem(0, 1, {
            itemID = 2589,
            link = "item:2589",
            count = 1,
            quality = 1,
            bound = false,
            hasNoValue = false,
        })
        local value = Expect(7, "PASS")
        Has(value, "isQuestItem=false")
    end,

    ["Checks: L7 fails naming the missing field"] = function()
        Load()
        Stub.SetBagItem(0, 1, {
            itemID = 2589,
            link = "item:2589",
            count = 1,
            quality = 1,
            hasNoValue = false,
        })
        local value = Expect(7, "FAIL")
        Has(value, "isBound")
    end,

    ["Checks: L7 fails naming isQuestItem when the quest info lacks it"] = function()
        Load()
        Stub.SetBagItem(0, 1, {
            itemID = 2589,
            link = "item:2589",
            count = 1,
            quality = 1,
            bound = false,
            hasNoValue = false,
        })
        Stub.SetGlobal(
            "C_Container",
            setmetatable({
                GetContainerItemQuestInfo = function()
                    return { isActive = false }
                end,
            }, { __index = C_Container })
        )
        local value = Expect(7, "FAIL")
        Has(value, "isQuestItem")
    end,

    ["Checks: L8 passes with the head slot and the subclass names"] = function()
        Load()
        ReadyForL8()
        Stub.SetWornLink(1, "item:1")
        Stub.SetItemInstant(1, { equipLoc = "INVTYPE_HEAD" })
        local value = Expect(8, "PASS")
        Has(value, "2:9 Staves")
        Has(value, "2:17 Polearms")
    end,

    ["Checks: L8 notes that the head part did not run with slot 1 empty"] = function()
        Load()
        ReadyForL8()
        local value = Expect(8, "PASS")
        Has(value, L.probeHeadNotRun)
    end,

    ["Checks: L8 fails on another head slot type"] = function()
        Load()
        ReadyForL8()
        Stub.SetWornLink(1, "item:1")
        Stub.SetItemInstant(1, { equipLoc = "INVTYPE_CHEST" })
        Expect(8, "FAIL")
    end,

    ["Checks: L8 fails when item 2589 is not class 7 subclass 5"] = function()
        Load()
        ReadyForL8()
        Stub.SetItemInstant(2589, { classID = 4, subclassID = 1 })
        Expect(8, "FAIL")
    end,

    ["Checks: L8 fails naming a subclass with no name"] = function()
        Load()
        ReadyForL8()
        local _, subclasses = SetTypeNames()
        subclasses[7][6] = nil
        Stub.SetItemTypeNames({ [7] = "Trade Goods" }, subclasses)
        local value = Expect(8, "FAIL")
        Has(value, "7:6")
    end,

    ["Checks: L9 is SKIP with neither provider"] = function()
        Load()
        local value = Expect(9, "SKIP")
        Has(value, string.format(L.probeHalf, L.probeAuctionator, L.probeSkip, L.probeAbsent))
        Has(value, string.format(L.probeHalf, L.probeAHDB, L.probeSkip, L.probeAbsent))
    end,

    ["Checks: L9 Auctionator passes on a number price and an integer age"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({ [2589] = 120 }, { [2589] = 1 }))
        local value = Expect(9, "PASS")
        Has(value, string.format(L.probeHalf, L.probeAuctionator, L.probePass, "120, 1"))
        local calls = Stub.AuctionatorCalls()
        h.Equal(#calls, 2, "two calls")
        h.Equal(calls[1].callerID, "LootLogic", "price caller ID")
        h.Equal(calls[2].callerID, "LootLogic", "age caller ID")
        h.Equal(calls[1].itemID, 2589, "item")
    end,

    ["Checks: L9 Auctionator with no price is SKIP"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({}, {}))
        local value = Expect(9, "SKIP")
        Has(value, L.probeNoPrice)
    end,

    ["Checks: L9 Auctionator with a price and no age is SKIP"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({ [2589] = 120 }, {}))
        local value = Expect(9, "SKIP")
        Has(value, L.probeNoAge)
    end,

    ["Checks: L9 Auctionator fails on a price of another type"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({ [2589] = "cheap" }, { [2589] = 1 }))
        Expect(9, "FAIL")
    end,

    ["Checks: L9 Auctionator fails on an age that is not whole"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({ [2589] = 120 }, { [2589] = 1.5 }))
        Expect(9, "FAIL")
    end,

    ["Checks: L9 Auctionator fails without API.v1"] = function()
        Load()
        Stub.SetAuctionator(nil)
        local value = Expect(9, "FAIL")
        Has(value, L.probeApiMissing)
    end,

    ["Checks: L9 Auctionator fails when a function is missing"] = function()
        Load()
        Stub.SetAuctionator({ GetAuctionPriceByItemID = Nothing })
        Expect(9, "FAIL")
    end,

    ["Checks: L9 an error inside Auctionator is FAIL with its text, the run goes on"] = function()
        Load()
        Stub.SetAuctionator({
            GetAuctionPriceByItemID = function()
                error("auctionator boom", 0)
            end,
            GetAuctionAgeByItemID = Nothing,
        })
        local value = Expect(9, "FAIL")
        Has(value, "auctionator boom")
        local pattern = "^" .. PREFIX .. "L10 (%u+) "
        local l10
        for _, line in ipairs(Stub.ChatLines()) do
            l10 = l10 or string.match(line, pattern)
        end
        h.True(l10 ~= nil, "L10 still printed")
    end,

    ["Checks: L9 AHDB passes on a table with ts and min and prints the house"] = function()
        Load()
        Stub.SetGlobal("AuctionDB", LoadedAuctionDB({ ts = 1, min = 2, median = 3, qty = 4 }))
        local value = Expect(9, "PASS")
        Has(value, string.format(L.probeHalf, L.probeAHDB, L.probePass, "1, 2"))
        Has(value, string.format(L.probeHouse, "Horde"))
    end,

    ["Checks: L9 AHDB with no last price is SKIP"] = function()
        Load()
        Stub.SetGlobal("AuctionDB", LoadedAuctionDB(nil))
        local value = Expect(9, "SKIP")
        Has(value, L.probeNoLastPrice)
    end,

    ["Checks: L9 AHDB fails without LastPrice"] = function()
        Load()
        Stub.SetGlobal("AuctionDB", {})
        local value = Expect(9, "FAIL")
        Has(value, L.probeLastPriceMissing)
    end,

    ["Checks: L9 AHDB fails on a value of another shape"] = function()
        Load()
        Stub.SetGlobal("AuctionDB", LoadedAuctionDB({ ts = 1 }))
        Expect(9, "FAIL")
    end,

    ["Checks: L9 is FAIL when one provider fails and the other passes"] = function()
        Load()
        Stub.SetAuctionator(nil)
        Stub.SetGlobal("AuctionDB", LoadedAuctionDB({ ts = 1, min = 2 }))
        local value = Expect(9, "FAIL")
        Has(value, string.format(L.probeHalf, L.probeAHDB, L.probePass, "1, 2"))
    end,

    ["Checks: L9 is PASS when one provider passes and the other is SKIP"] = function()
        Load()
        Stub.SetAuctionator(Stub.MakeAuctionatorV1({ [2589] = 120 }, { [2589] = 1 }))
        Expect(9, "PASS")
    end,

    ["Checks: L10 passes with both frames and their functions"] = function()
        Load()
        Stub.SetGlobal("ContainerFrameCombinedBags", { UpdateItems = Nothing })
        Stub.SetGlobal("ContainerFrame1", { UpdateItems = Nothing })
        Expect(10, "PASS")
    end,

    ["Checks: L10 fails naming the missing frames and asks to retry"] = function()
        Load()
        local value = Expect(10, "FAIL")
        Has(value, "ContainerFrameCombinedBags")
        Has(value, "ContainerFrame1")
        Has(value, "bags open")
    end,

    ["Checks: L10 fails naming a missing UpdateItems"] = function()
        Load()
        Stub.SetGlobal("ContainerFrameCombinedBags", { UpdateItems = Nothing })
        Stub.SetGlobal("ContainerFrame1", {})
        local value = Expect(10, "FAIL")
        Has(value, "ContainerFrame1.UpdateItems")
    end,

    ["Checks: L15 is SKIP without LibStub"] = function()
        Load()
        Expect(15, "SKIP")
    end,

    ["Checks: L15 is SKIP when BetterBags is not there"] = function()
        Load()
        Stub.SetLibStub(nil)
        Expect(15, "SKIP")
    end,

    ["Checks: L15 passes with the two functions"] = function()
        Load()
        Stub.SetLibStub({ categories = BetterBagsCategories() })
        Expect(15, "PASS")
    end,

    ["Checks: L15 fails when a function is missing"] = function()
        Load()
        Stub.SetLibStub({ categories = { RegisterCategoryFunction = Nothing } })
        Expect(15, "FAIL")
    end,

    ["Checks: L15 fails with the error from GetModule"] = function()
        Load()
        Stub.SetLibStub({ raises = "no such module" })
        local value = Expect(15, "FAIL")
        Has(value, "no such module")
    end,

    ["Checks: L19 is SKIP without EUI_Bags"] = function()
        Load()
        Expect(19, "SKIP")
    end,

    ["Checks: L19 passes with the overlay function"] = function()
        Load()
        Stub.SetGlobal("EUI_Bags", { RegisterItemOverlayIcon = Nothing })
        Expect(19, "PASS")
    end,

    ["Checks: L19 fails when the field is not a function"] = function()
        Load()
        Stub.SetGlobal("EUI_Bags", { RegisterItemOverlayIcon = 5 })
        Expect(19, "FAIL")
    end,

    ["Checks: L21 is SKIP while item 20429 is not loaded"] = function()
        Load()
        Stub.SetItemPending(20429, { unique = true })
        local value = Expect(21, "SKIP")
        Has(value, L.probeNotLoaded)
    end,

    ["Checks: L21 passes with the values printed"] = function()
        Load()
        Stub.SetItem(20429, { unique = true })
        local value = Expect(21, "PASS")
        h.Equal(value, "true", "value")
    end,

    ["Checks: L21 fails when the call is missing"] = function()
        Load()
        Stub.SetItem(20429, { unique = true })
        Stub.SetUniquenessApi(false)
        local value = Expect(21, "FAIL")
        h.Equal(value, L.probeUniquenessMissing, "value")
    end,

    ["Checks: L21 is FAIL, not SKIP, when the call is missing and 20429 is pending"] = function()
        Load()
        Stub.SetItemPending(20429, { unique = true })
        Stub.SetUniquenessApi(false)
        local value = Expect(21, "FAIL")
        h.Equal(value, L.probeUniquenessMissing, "value")
    end,

    ["Checks: L21 fails with returned nothing when every return is nil"] = function()
        Load()
        Stub.SetItem(20429, { unique = true })
        Stub.SetUniquenessNothing(true)
        local value = Expect(21, "FAIL")
        h.Equal(value, L.probeReturnedNothing, "value")
    end,

    ["Checks: L22 is SKIP with slot 16 empty"] = function()
        Load()
        Expect(22, "SKIP")
    end,

    ["Checks: L22 passes on a right-hand speed text"] = function()
        Load()
        Stub.SetWornLink(16, "item:100")
        Stub.SetTooltipLines("item:100", { "Sword", { left = "One-Hand", right = "Speed 2.60" } })
        local value = Expect(22, "PASS")
        h.Equal(value, "Speed 2.60", "value")
    end,

    ["Checks: L22 passes on a left-hand speed text"] = function()
        Load()
        Stub.SetWornLink(16, "item:100")
        Stub.SetTooltipLines("item:100", { "Speed 1.80" })
        Expect(22, "PASS")
    end,

    ["Checks: L22 fails when no line matches"] = function()
        Load()
        Stub.SetWornLink(16, "item:100")
        Stub.SetTooltipLines("item:100", { "Sword", "Binds when equipped" })
        Expect(22, "FAIL")
    end,

    ["Checks: L22 fails without WEAPON_SPEED"] = function()
        Load()
        Stub.SetWornLink(16, "item:100")
        Stub.SetTooltipLines("item:100", { "Speed 2.60" })
        Stub.SetString("WEAPON_SPEED", nil)
        Expect(22, "FAIL")
    end,

    ["Checks: L22 fails when the tooltip gives nothing"] = function()
        Load()
        Stub.SetWornLink(16, "item:100")
        Expect(22, "FAIL")
    end,

    ["Checks: L24 passes when the function exists"] = function()
        Load()
        Expect(24, "PASS")
    end,

    ["Checks: L24 fails when the function is missing"] = function()
        Load()
        Stub.SetAccountBoundApi(false)
        Expect(24, "FAIL")
    end,

    ["Checks: L31 is SKIP while 2880 is pending"] = function()
        Load()
        Stub.SetItem(2589, { stack = 20 })
        Stub.SetItemPending(2880, { stack = 10 })
        Expect(31, "SKIP")
        h.True(Stub.ItemRequests(2880) >= 1, "2880 was requested")
    end,

    ["Checks: L31 passes on stack sizes 20 and 10"] = function()
        Load()
        Stub.SetItem(2589, { stack = 20 })
        Stub.SetItem(2880, { stack = 10 })
        Expect(31, "PASS")
    end,

    ["Checks: L31 fails on another stack size"] = function()
        Load()
        Stub.SetItem(2589, { stack = 5 })
        Stub.SetItem(2880, { stack = 10 })
        Expect(31, "FAIL")
    end,

    ["Checks: L33 is SKIP with the bank closed"] = function()
        Load()
        Stub.SetBankApi(false)
        Expect(33, "SKIP")
    end,

    ["Checks: L33 passes on false with the bank open"] = function()
        Load()
        Stub.SetBankApi(false)
        Stub.OpenBank()
        Expect(33, "PASS")
    end,

    ["Checks: L33 passes on nil when the API is missing"] = function()
        Load()
        Stub.OpenBank()
        local value = Expect(33, "PASS")
        Has(value, "nil")
    end,

    ["Checks: L33 fails on true with the bank open"] = function()
        Load()
        Stub.SetBankApi(true)
        Stub.OpenBank()
        Expect(33, "FAIL")
    end,

    ["Checks: L33 is SKIP again after the bank closes"] = function()
        Load()
        Stub.SetBankApi(true)
        Stub.OpenBank()
        Stub.CloseBank()
        Expect(33, "SKIP")
    end,

    ["Checks: L48 passes for a druid: Feral Combat matches Bear and Cat"] = function()
        Load()
        Stub.SetPlayer({ class = "DRUID", className = "Druid" })
        Stub.SetTalentTabs({
            { "Balance", 136096, "desc" },
            { "Feral Combat", 132115 },
            { "Restoration", 136041 },
        })
        local value = Expect(48, "PASS")
        Has(value, string.format(L.probeClass, "DRUID"))
        Has(value, "Feral Combat, 132115")
        Has(value, "Balance, 136096, desc")
    end,

    ["Checks: L48 prints every return, a nil in the middle and at the end included"] = function()
        Load()
        Stub.SetPlayer({ class = "DRUID", className = "Druid" })
        Stub.SetTalentTabs({ { "Balance", nil, 7, nil, n = 4 } })
        local value = Expect(48, "PASS")
        Has(value, "Balance, nil, 7, nil")
    end,

    ["Checks: L48 matches on a string return other than the first"] = function()
        Load()
        Stub.SetPlayer({ class = "DRUID", className = "Druid" })
        Stub.SetTalentTabs({ { "Tab one", "Balance" } })
        Expect(48, "PASS")
    end,

    ["Checks: L48 fails on a tree name only another class has"] = function()
        Load()
        Stub.SetPlayer({ class = "WARLOCK", className = "Warlock" })
        Stub.SetTalentTabs({ { "Affliction" }, { "Balance" } })
        local value = Expect(48, "FAIL")
        Has(value, L.probeNoMatch)
    end,

    ["Checks: L48 is SKIP without GetNumTalentTabs"] = function()
        Load()
        Expect(48, "SKIP")
    end,

    ["Checks: L48 is SKIP with no tabs"] = function()
        Load()
        Stub.SetTalentTabs({})
        Expect(48, "SKIP")
    end,

    ["Checks: L52 is SKIP with neither a slot 5 link nor a bag link"] = function()
        Load()
        Expect(52, "SKIP")
    end,

    ["Checks: L52 passes on the colour token and the classic forms"] = function()
        Load()
        Stub.SetWornLink(5, "|cnIQ4:|Hitem:12345::::::::60:|h[Robe]|h|r")
        Stub.SetBagSize(0, 16)
        Stub.SetBagLink(0, 3, "|cff9d9d9d|Hitem:2589::::::::1:|h[Linen Cloth]|h|r")
        local value = Expect(52, "PASS")
        Has(value, "||cnIQ4:||Hitem:12345")
        Has(value, "||cff9d9d9d||Hitem:2589")
    end,

    ["Checks: L52 reads the lowest bag and slot first"] = function()
        Load()
        Stub.SetBagSize(0, 16)
        Stub.SetBagSize(1, 16)
        Stub.SetBagLink(1, 1, "|cff9d9d9d|Hitem:111::::::::1:|h[One]|h|r")
        Stub.SetBagLink(0, 5, "|cff9d9d9d|Hitem:222::::::::1:|h[Two]|h|r")
        Stub.SetBagLink(0, 9, "|cff9d9d9d|Hitem:333::::::::1:|h[Three]|h|r")
        local value = Expect(52, "PASS")
        Has(value, "Hitem:222")
        h.Nil(string.find(value, "Hitem:111", 1, true), "not the bag 1 link")
    end,

    ["Checks: L52 goes on when bag 5 reports no slot count"] = function()
        Load()
        Stub.SetWornLink(5, "|cnIQ4:|Hitem:12345::::::::60:|h[Robe]|h|r")
        Stub.SetBagSize(0, 16)
        local original = C_Container
        Stub.SetGlobal(
            "C_Container",
            setmetatable({
                GetContainerNumSlots = function(bag)
                    if bag == 5 then
                        return nil
                    end
                    return original.GetContainerNumSlots(bag)
                end,
            }, { __index = C_Container })
        )
        local value = Expect(52, "PASS")
        Has(value, "Hitem:12345")
    end,

    ["Checks: L52 fails on a link with neither colour form"] = function()
        Load()
        Stub.SetWornLink(5, "|Hitem:12345::::::::60:|h[Robe]|h|r")
        Expect(52, "FAIL")
    end,

    ["Checks: L52 fails on a link with no item ID"] = function()
        Load()
        Stub.SetWornLink(5, "|cnIQ4:|Hitem:|h[Robe]|h|r")
        Expect(52, "FAIL")
    end,

    ["Checks: L61 prints every name in numeric order across a gap and saves the pairs"] = function()
        Load()
        SetTypeNames()
        local key = tostring(GetServerTime())
        local status = Expect(61, "PASS")
        h.Equal(status, string.format(L.probeNamesFound, 22), "names found")
        local lines = Stub.ChatLines()
        local start
        for index, line in ipairs(lines) do
            if string.find(line, "^" .. PREFIX .. "L61 ") then
                start = index
            end
        end
        h.Equal(lines[start + 1], PREFIX .. "0 Consumable", "first name")
        h.Equal(lines[start + 2], PREFIX .. "2 Weapon", "class 2 before its subclasses")
        h.Equal(lines[start + 3], PREFIX .. "2:13 Weapon 13", "subclass of 2")
        h.Equal(lines[start + 11], PREFIX .. "7 Trade Goods", "class 7")
        h.Equal(lines[start + 12], PREFIX .. "7:0 Goods 0", "first subclass of 7")
        h.Equal(lines[start + 15], PREFIX .. "7:5 Goods 5", "7:5 after the gap at 7:3 and 7:4")
        local names = ns.DB.Data().debug.probe[key].results.L61.names
        h.DeepEqual(names[1], { id = "0", name = "Consumable" }, "pair 1")
        h.DeepEqual(names[2], { id = "2", name = "Weapon" }, "class pair")
        h.DeepEqual(names[3], { id = "2:13", name = "Weapon 13" }, "subclass pair")
        h.DeepEqual(names[#names], { id = "7:12", name = "Goods 12" }, "last pair")
        h.Equal(#names, 22, "count")
    end,

    ["Checks: L61 fails listing the missing range"] = function()
        Load()
        local value = Expect(61, "FAIL")
        Has(value, "7:0")
        Has(value, "2:13")
        h.Nil(string.find(value, "7:3", 1, true), "7:3 is not required")
    end,

    ["Checks: L61 fails naming one missing subclass while later ones still count"] = function()
        Load()
        local _, subclasses = SetTypeNames()
        subclasses[7][7] = nil
        Stub.SetItemTypeNames({ [2] = "Weapon", [7] = "Trade Goods" }, subclasses)
        local value = Expect(61, "FAIL")
        h.Equal(value, string.format(L.probeNamesMissing, "7:7"), "only 7:7 missing")
    end,
}
