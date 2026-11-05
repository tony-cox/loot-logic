--[[
The Auctionator public API v1 price provider (spec 11.2, technical findings
11.1 and 11.2). It reads only Auctionator's documented API.
]]

local _, ns = ...

local Prices = ns.Prices

local CALLER_ID = "LootLogic"

local function API()
    local auctionator = Auctionator
    return auctionator and auctionator.API and auctionator.API.v1
end

local function IsAvailable()
    local api = API()
    return api ~= nil
        and (api.GetAuctionPriceByItemID ~= nil or api.GetAuctionPriceByItemLink ~= nil)
end

local function GetPrice(itemID, link)
    local api = API()
    if not api then
        return nil
    end

    local unit
    if itemID and api.GetAuctionPriceByItemID then
        unit = api.GetAuctionPriceByItemID(CALLER_ID, itemID)
    elseif link and api.GetAuctionPriceByItemLink then
        unit = api.GetAuctionPriceByItemLink(CALLER_ID, link)
    end
    if unit == nil then
        return nil
    end

    local ageDays
    if itemID and api.GetAuctionAgeByItemID then
        ageDays = api.GetAuctionAgeByItemID(CALLER_ID, itemID)
    end
    return { unit = unit, ageDays = ageDays }
end

local function OnUpdate(callback)
    local api = API()
    if api and api.RegisterForDBUpdate then
        api.RegisterForDBUpdate(CALLER_ID, callback)
    end
end

Prices.Register({
    id = "auctionator",
    label = "Auctionator",
    honoursLastScan = false,
    IsAvailable = IsAvailable,
    GetPrice = GetPrice,
    OnUpdate = OnUpdate,
})
