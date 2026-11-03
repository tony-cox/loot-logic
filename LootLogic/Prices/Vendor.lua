--[[
The vendor price (technical findings 11.2 and 14). Not a registered provider:
it adds GetVendorPrice to ns.Prices and defines no key.
]]

local _, ns = ...

local Prices = ns.Prices
local Util = ns.Util

--- The sell price, forced to 0 when the item has no value or AuctionDB's
--- SellablePrice says nobody buys it. SellablePrice is called only when
--- AuctionDB and the method exist, under pcall, because AHDB documents no API
--- and the method can change or fail (technical findings 11.1): an error leaves
--- sellPrice standing. SellablePrice is source-read (technical findings 11.1);
--- whether it returns nil for an item AHDB never saw is unverified, with no
--- live check yet.
-- @param itemID number
-- @param sellPrice number the sell price the caller already has
-- @param hasNoValue boolean
-- @treturn number
function Prices.GetVendorPrice(itemID, sellPrice, hasNoValue)
    if hasNoValue then
        return 0
    end
    if AuctionDB and AuctionDB.SellablePrice then
        local ok, sellable = Util.Pcall(AuctionDB.SellablePrice, AuctionDB, itemID)
        if ok and sellable == nil then
            return 0
        end
    end
    return sellPrice
end
