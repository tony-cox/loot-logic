--[[
The facts of an item, read from a bag slot or from a link (spec 7.1; technical
findings 7.1 and 7.5). The facts of an item whose data the game has not loaded
yet are incomplete and marked pending (spec 7.2, step 0): the item is requested
once per session, and retried when the game says its data arrived, in batches.
Every value read from the game passes the secret-value guard (live check L25;
fallback: defer classification to out of combat): a secret value makes the
facts pending and marks them secret, so the caller can defer instead of
waiting for item data.

A fact read from the tooltip (class restriction, unique, knownHere,
unscoredEffect) can be unreadable while the item data is loaded: no tooltip
yet, or a "Classes:" line whose names resolve to no class token. Then
facts.tooltipUnread is true, that fact is nil, and nothing is cached, so the
next FromSlot or FromLink call reads it again. tooltipUnread is not pending
(no item-data event will come for it): Classify (stage 12) treats it as
pending, and so as no result yet, because a nil class restriction otherwise
means the item names no class.

A facts table has these fields: itemID, link, suffix, stack, quality, bound,
isAccountBound, classID, subclassID, equipLoc, bindType, reqLevel, isQuest,
hasNoValue, classRestriction (a set of class tokens, or nil), unique,
vendorPrice, itemLevel, knownHere (class 9 only), unscoredEffect (gear only),
holding, refundable, pending, secret and tooltipUnread; a slot's facts also
carry bag and slot, and a link's carry linkOnly = true. A pending table holds
only the fields read before the data was missing.
]]

local _, ns = ...

local ItemFacts = {}
ns.ItemFacts = ItemFacts

local Events = ns.Events
local L = ns.L
local Log = ns.Log
local Prices = ns.Prices
local Recipes = ns.Recipes
local Slots = ns.Slots
local Stats = ns.Stats
local Util = ns.Util

--- How long the item-data events are collected before the pending items are
--- read again, in seconds, counted from the first event of a batch. An
--- internal value with no live check: long enough to gather a burst of events
--- into one pass, short enough not to be noticed.
ItemFacts.BATCH_SECONDS = 0.2

-- The bind types of an item bound to the account: to the WoW account, to the
-- Battle.net account, and to the Battle.net account until equipped (the
-- members ToWoWAccount, ToBnetAccount and ToBnetAccountUntilEquipped of
-- Enum.ItemBind). From memory, unverified for Forever (live check L24;
-- fallback: treat every bound item as bound to the character).
local ACCOUNT_BIND_TYPES = { [7] = true, [8] = true, [9] = true }

-- itemID -> link, for each item requested and not yet seen loaded.
local waiting = {}
-- itemID -> time of the first request; never cleared, so the 10 s owned-data
-- deadline in Scoring is fixed from the first request in the session.
local requestedAt = {}
-- itemID -> true, for the items whose data event arrived in the current batch.
local arrived = {}
local scheduled = false
local callbacks = {}
-- itemID -> the class tokens the tooltip's "Classes:" line allows (false when
-- it names none), and itemID -> whether the item is unique. Filled once the
-- tooltip can be read.
local classCache = {}
local uniqueCache = {}
-- Class name (male and female forms) -> class token, built on first use.
local classTokens
local classesPattern

local function Clean(facts, value)
    if Util.IsSecret(value) then
        facts.secret = true
        facts.pending = true
        return nil
    end
    return value
end

-- Equippable armour or a weapon: its equipLoc is a slot type of Data/Slots.lua
-- and it is not cosmetic armour (4:5), as in Model/Snapshot.lua.
local function IsGear(facts)
    if not Slots.invTypeGroup[facts.equipLoc] then
        return false
    end
    return not (facts.classID == 4 and facts.subclassID == 5)
end

local function TooltipLines(link)
    local data = C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then
        return nil
    end
    return data.lines
end

local function ClassTokens()
    if classTokens then
        return classTokens
    end
    classTokens = {}
    local male = LOCALIZED_CLASS_NAMES_MALE or {}
    local female = LOCALIZED_CLASS_NAMES_FEMALE or {}
    for _, names in ipairs({ male, female }) do
        for token, name in pairs(names) do
            classTokens[name] = token
        end
    end
    return classTokens
end

-- The class tokens of the tooltip's "Classes: A, B" line, or nil when the item
-- names none. The second result is false when a Classes line matched but no
-- name resolved to a token, or a line was secret and no Classes line was
-- found, so the restriction is unknown, not absent. The
-- format string ITEM_CLASSES_ALLOWED and the two global tables
-- LOCALIZED_CLASS_NAMES_MALE and _FEMALE that turn the localized names into
-- tokens are from memory: live check L51 prints all three (fallback: a pattern
-- from a captured tooltip).
local function ReadClassRestriction(lines)
    if type(ITEM_CLASSES_ALLOWED) ~= "string" then
        return nil, true
    end
    classesPattern = classesPattern or Util.FormatPattern(ITEM_CLASSES_ALLOWED, true)
    local secretSeen = false
    for _, line in ipairs(lines) do
        local text = line.leftText
        if Util.IsSecret(text) then
            secretSeen = true
        elseif type(text) == "string" then
            local list = string.match(text, classesPattern)
            if list then
                local set
                for name in string.gmatch(list, "[^,]+") do
                    local token = ClassTokens()[strtrim(name)]
                    if token then
                        set = set or {}
                        set[token] = true
                    end
                end
                return set, set ~= nil
            end
        end
    end
    -- A secret line may have been the Classes line: unknown, not absent.
    return nil, not secretSeen
end

-- The set of class tokens (nil for none) of an item, remembered once its
-- tooltip can be read. The second result is false, and nothing is remembered,
-- when it cannot be read yet.
local function ClassRestriction(itemID, link)
    local cached = classCache[itemID]
    if cached ~= nil then
        return cached or nil, true
    end
    local lines = TooltipLines(link)
    if not lines then
        return nil, false
    end
    local set, readable = ReadClassRestriction(lines)
    if not readable then
        return nil, false
    end
    classCache[itemID] = set or false
    return set, true
end

-- True when a Unique line is found, nil when none is found but a line was
-- secret (it may have been the Unique line), otherwise false.
local function HasUniqueLine(lines)
    local secretSeen = false
    for _, line in ipairs(lines) do
        local text = line.leftText
        if Util.IsSecret(text) then
            secretSeen = true
        elseif text == ITEM_UNIQUE or text == ITEM_UNIQUE_EQUIPPABLE then
            return true
        end
    end
    if secretSeen then
        return nil
    end
    return false
end

-- Whether the item is unique: C_Item.GetItemUniquenessByID when it exists
-- (its first result true for a unique item; from memory), otherwise the
-- tooltip lines ITEM_UNIQUE and ITEM_UNIQUE_EQUIPPABLE (live check L21;
-- fallback: the tooltip lines). Nil and not remembered when neither can say.
local function IsUnique(itemID, link)
    local cached = uniqueCache[itemID]
    if cached ~= nil then
        return cached
    end
    local unique
    if C_Item.GetItemUniquenessByID then
        -- A wrong argument raises (from memory, live check L21).
        local ok, result = Util.Pcall(C_Item.GetItemUniquenessByID, itemID)
        if ok and not Util.IsSecret(result) then
            unique = result and true or false
        end
    end
    if unique == nil then
        local lines = TooltipLines(link)
        if not lines then
            return nil
        end
        unique = HasUniqueLine(lines)
        if unique == nil then
            return nil
        end
    end
    uniqueCache[itemID] = unique
    return unique
end

-- Whether the item is bound to the account rather than the character: an
-- account bind type, or, for a bag slot, C_Item.IsBoundToAccountUntilEquip
-- with an ItemLocation (the argument is from memory, unverified, under pcall;
-- live check L24; fallback: treat every bound item as bound to the character).
local function IsAccountBound(facts)
    if ACCOUNT_BIND_TYPES[facts.bindType] then
        return true
    end
    if facts.bag and C_Item.IsBoundToAccountUntilEquip and ItemLocation then
        local location = ItemLocation:CreateFromBagAndSlot(facts.bag, facts.slot)
        -- A wrong argument raises (from memory, live check L24).
        local ok, result = Util.Pcall(C_Item.IsBoundToAccountUntilEquip, location)
        if ok and Clean(facts, result) then
            return true
        end
    end
    return false
end

-- Reads the facts that depend only on the item: instant data, the item info
-- (pending until it loads) and the tooltip facts. The first read of an item the
-- game has not loaded requests it once; until its data event is handled the
-- item stays pending without a second request. C_Item.GetItemInfoInstant
-- returns the item ID, type, subtype, equipLoc, icon, classID and subclassID;
-- C_Item.GetItemInfo returns reqLevel as its fifth value, sellPrice as its
-- eleventh and bindType as its fourteenth (technical findings 7.1; from
-- memory, live checks L7 and L8).
local function FillItem(facts, link)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    facts.equipLoc = Clean(facts, equipLoc)
    facts.classID = Clean(facts, classID)
    facts.subclassID = Clean(facts, subclassID)
    if facts.secret then
        return
    end
    local itemID = facts.itemID
    if waiting[itemID] then
        facts.pending = true
        return
    end
    local name, _, quality, _, reqLevel, _, _, _, _, _, sellPrice, _, _, bindType =
        C_Item.GetItemInfo(link)
    if name == nil then
        waiting[itemID] = link
        requestedAt[itemID] = requestedAt[itemID] or GetTime()
        facts.pending = true
        return
    end
    if facts.quality == nil then
        facts.quality = Clean(facts, quality)
    end
    facts.reqLevel = Clean(facts, reqLevel)
    facts.bindType = Clean(facts, bindType)
    sellPrice = Clean(facts, sellPrice)
    -- Clean may have found a secret value.
    if facts.secret then
        return
    end
    facts.vendorPrice = Prices.GetVendorPrice(itemID, sellPrice or 0, facts.hasNoValue)
    -- The item level of the link (source-read, technical findings 7.1).
    facts.itemLevel = Clean(facts, (C_Item.GetDetailedItemLevelInfo(link)))
    facts.isAccountBound = IsAccountBound(facts)
    local readable
    facts.classRestriction, readable = ClassRestriction(itemID, link)
    facts.tooltipUnread = not readable
    facts.unique = IsUnique(itemID, link)
    if facts.unique == nil then
        facts.tooltipUnread = true
    end
    if facts.classID == 9 then
        facts.knownHere = Recipes.KnownHere(link)
        if facts.knownHere == nil then
            facts.tooltipUnread = true
        end
    end
    facts.unscoredEffect = false
    if IsGear(facts) then
        facts.unscoredEffect = Stats.HasUnscoredEffect(link)
        if facts.unscoredEffect == nil then
            facts.tooltipUnread = true
        end
    end
end

-- Whether the game says the purchase of the slot's item is refundable: the
-- purchase info has a refund time above 0. The call, its table result and the
-- refundSeconds field are from memory (live check L55; fallback: drop the
-- "refundable" suffix).
local function IsRefundable(bag, slot)
    local info = C_Container.GetContainerItemPurchaseInfo(bag, slot, false)
    if type(info) ~= "table" then
        return false
    end
    local seconds = info.refundSeconds
    if Util.IsSecret(seconds) then
        return false
    end
    return type(seconds) == "number" and seconds > 0
end

-- Whether the slot's item is a quest item: GetContainerItemQuestInfo gives a
-- table with isQuestItem (from memory, live check L7).
local function IsQuestItem(facts, bag, slot)
    local info = C_Container.GetContainerItemQuestInfo(bag, slot)
    if type(info) ~= "table" then
        return false
    end
    -- A secret value is deferred: Clean marks the facts secret and pending.
    return Clean(facts, info.isQuestItem) and true or false
end

--- The count of each item ID over the container that holds `bag`: bags 0 to 5,
--- or bank tabs 6 to 14 (technical findings 7.1, holding). A secret count is
--- left out. Build it once per container for a whole pass and give it to
--- FromSlot.
-- @param bag number
-- @treturn table itemID -> total stackCount
function ItemFacts.Holdings(bag)
    local range = Slots.bags
    if bag >= Slots.bankTabs.first and bag <= Slots.bankTabs.last then
        range = Slots.bankTabs
    end
    local totals = {}
    for container = range.first, range.last do
        local size = C_Container.GetContainerNumSlots(container) or 0
        for slot = 1, size do
            local info = C_Container.GetContainerItemInfo(container, slot)
            if info and info.itemID and not Util.IsSecret(info.itemID) then
                local count = info.stackCount or 1
                if not Util.IsSecret(count) then
                    totals[info.itemID] = (totals[info.itemID] or 0) + count
                end
            end
        end
    end
    return totals
end

--- The facts of the item in a bag slot, or nil for an empty slot. The field
--- names of C_Container.GetContainerItemInfo (itemID, hyperlink, stackCount,
--- quality, isBound, hasNoValue) are live check L7.
-- @param bag number
-- @param slot number
-- @param holdings table|nil from ItemFacts.Holdings(bag); built here when nil
-- @treturn table|nil facts
function ItemFacts.FromSlot(bag, slot, holdings)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        return nil
    end
    local facts = {
        bag = bag,
        slot = slot,
        pending = false,
        secret = false,
        tooltipUnread = false,
    }
    facts.itemID = Clean(facts, info.itemID)
    facts.link = Clean(facts, info.hyperlink)
    facts.stack = Clean(facts, info.stackCount) or 1
    facts.quality = Clean(facts, info.quality)
    facts.bound = Clean(facts, info.isBound) or false
    facts.hasNoValue = Clean(facts, info.hasNoValue) or false
    if facts.secret or not facts.itemID or not facts.link then
        facts.pending = true
        return facts
    end
    local _, suffix = Util.ParseLink(facts.link)
    facts.suffix = suffix or 0
    facts.isQuest = IsQuestItem(facts, bag, slot)
    facts.refundable = IsRefundable(bag, slot)
    holdings = holdings or ItemFacts.Holdings(bag)
    facts.holding = holdings[facts.itemID] or facts.stack
    FillItem(facts, facts.link)
    return facts
end

--- The facts of an item known only by its link (a link-only result, a mailbox
--- attachment: spec 7.5). It has no bound state, stack count or holding, so it
--- counts as unbound, a stack of 1, and not a quest item or a refundable
--- purchase.
-- @param link string
-- @treturn table|nil facts, nil when the text holds no item
function ItemFacts.FromLink(link)
    local itemID, suffix = Util.ParseLink(link)
    if not itemID then
        return nil
    end
    local facts = {
        itemID = itemID,
        link = link,
        suffix = suffix,
        stack = 1,
        bound = false,
        isQuest = false,
        hasNoValue = false,
        holding = 1,
        refundable = false,
        linkOnly = true,
        pending = false,
        secret = false,
        tooltipUnread = false,
    }
    FillItem(facts, link)
    return facts
end

--- Registers a function called as callback(itemIDs) after a batch of pending
--- items loaded, with the sorted list of their IDs, so a caller can classify
--- them again. It runs under Log.Guard("events", ...). There is no unregister.
-- @param callback function
function ItemFacts.OnLoaded(callback)
    callbacks[#callbacks + 1] = callback
end

--- Time of the first item-data request in this session, if any.
-- @param itemID number
-- @treturn number|nil
function ItemFacts.RequestedAt(itemID)
    return requestedAt[itemID]
end

-- Reads the items whose event arrived. One debug line says how many loaded.
local function Flush()
    scheduled = false
    local loaded = {}
    for itemID in pairs(arrived) do
        arrived[itemID] = nil
        local link = waiting[itemID]
        if link and C_Item.GetItemInfo(link) ~= nil then
            waiting[itemID] = nil
            loaded[#loaded + 1] = itemID
        end
    end
    if #loaded == 0 then
        return
    end
    table.sort(loaded)
    if #loaded == 1 then
        Log.Debug("event", L.itemsLoadedOne)
    else
        Log.Debug("event", string.format(L.itemsLoadedMany, #loaded))
    end
    for index = 1, #callbacks do
        Log.Guard("events", callbacks[index], loaded)
    end
end

-- GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT both carry (itemID,
-- success). Events.lua does not log them one by one: the batch line above
-- stands for them. An item LootLogic did not request is ignored. An item the
-- game reports as not loadable (success false) is also ignored, a stated
-- choice: it stays pending and is not requested again this session (one request
-- per item), and M0 has no retry for it. Both events and their arguments are
-- from memory (live check L28; fallback: Item:ContinueOnItemLoad only).
local function OnItemData(_, itemID, success)
    if success == false or Util.IsSecret(itemID) or not waiting[itemID] then
        return
    end
    arrived[itemID] = true
    if not scheduled then
        scheduled = true
        C_Timer.After(ItemFacts.BATCH_SECONDS, Flush)
    end
end

Events.Register("GET_ITEM_INFO_RECEIVED", OnItemData)
Events.Register("ITEM_DATA_LOAD_RESULT", OnItemData)
