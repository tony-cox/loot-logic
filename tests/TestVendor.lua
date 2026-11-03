local _, ns, h = ...

local Prices = ns.Prices

return {
    ["hasNoValue gives 0"] = function()
        h.Equal(Prices.GetVendorPrice(1, 500, true), 0, "price")
    end,

    ["no AuctionDB leaves the sell price"] = function()
        AuctionDB = nil
        h.Equal(Prices.GetVendorPrice(1, 500, false), 500, "price")
    end,

    ["an AuctionDB without SellablePrice leaves the sell price"] = function()
        AuctionDB = {}
        h.Equal(Prices.GetVendorPrice(1, 500, false), 500, "price")
    end,

    ["SellablePrice returning nil gives 0"] = function()
        local asked
        AuctionDB = {
            SellablePrice = function(_, itemID)
                asked = itemID
                return nil
            end,
        }
        h.Equal(Prices.GetVendorPrice(77, 500, false), 0, "price")
        h.Equal(asked, 77, "item ID")
    end,

    ["SellablePrice returning a value leaves the sell price"] = function()
        AuctionDB = {
            SellablePrice = function()
                return 123
            end,
        }
        h.Equal(Prices.GetVendorPrice(1, 500, false), 500, "price")
    end,

    ["SellablePrice raising leaves the sell price"] = function()
        AuctionDB = {
            SellablePrice = function()
                error("boom", 0)
            end,
        }
        h.Equal(Prices.GetVendorPrice(1, 500, false), 500, "price")
    end,

    ["hasNoValue does not call SellablePrice"] = function()
        local called = false
        AuctionDB = {
            SellablePrice = function()
                called = true
            end,
        }
        Prices.GetVendorPrice(1, 500, true)
        h.Equal(called, false, "called")
    end,
}
