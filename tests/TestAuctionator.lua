local _, ns, h = ...

local Generations = ns.Generations
local Log = ns.Log
local Prices = ns.Prices

local function Ready(prices, ages)
    LootLogicDB = ns.DB.NewDefaults()
    h.Stub.SetAuctionator(h.Stub.MakeAuctionatorV1(prices or {}, ages or {}))
end

return {
    ["unavailable when the public API is absent"] = function()
        LootLogicDB = ns.DB.NewDefaults()
        h.Stub.SetAuctionator(nil)

        local price, reason = Prices.Best(100)

        h.Nil(price, "price")
        h.Equal(reason.code, "noprovider", "reason")
    end,

    ["an unloaded database or missing item price returns no price"] = function()
        Ready()

        local price, reason = Prices.Best(101)

        h.Nil(price, "price")
        h.Equal(reason.code, "noscan", "reason")
        h.Equal(#Log.Errors(), 0, "no API error")
    end,

    ["a price with no age remains a seen but stale price"] = function()
        Ready({ [102] = 125 })

        local price, reason = Prices.Best(102)

        h.Nil(price, "usable price")
        h.Equal(reason.code, "stale", "reason")
        h.Equal(reason.price.unit, 125, "unit")
        h.Nil(reason.price.ageDays, "age")
        h.True(Prices.Status()[1].seen, "seen")
        h.Nil(Prices.Status()[1].newestAgeDays, "newest age")
    end,

    ["item ID price and whole day age use the required caller ID"] = function()
        Ready({ [103] = 456 }, { [103] = 3 })

        local price, source = Prices.Best(103, "item:103")
        local calls = h.Stub.AuctionatorCalls()

        h.Equal(price.unit, 456, "unit")
        h.Equal(price.ageDays, 3, "age days")
        h.Equal(source.id, "auctionator", "source")
        h.Equal(calls[1].name, "price", "price call")
        h.Equal(calls[1].callerID, "LootLogic", "price caller ID")
        h.Equal(calls[1].itemID, 103, "price item ID")
        h.Equal(calls[2].name, "age", "age call")
        h.Equal(calls[2].callerID, "LootLogic", "age caller ID")
    end,

    ["link price lookup is used when no item ID is available"] = function()
        local link = "|Hitem:104:0:0:0|h[Test]|h"
        Ready({ [link] = 789 })

        local price, reason = Prices.Best(nil, link)
        local calls = h.Stub.AuctionatorCalls()

        h.Nil(price, "usable price")
        h.Equal(reason.code, "stale", "unknown age is stale")
        h.Equal(reason.price.unit, 789, "link price")
        h.Equal(calls[1].name, "link", "link call")
        h.Equal(calls[1].callerID, "LootLogic", "link caller ID")
        h.Equal(calls[1].link, link, "link")
    end,

    ["a failing public call is contained by the prices registry"] = function()
        LootLogicDB = ns.DB.NewDefaults()
        local api = h.Stub.MakeAuctionatorV1({}, {})
        api.GetAuctionPriceByItemID = function()
            error("price failed", 0)
        end
        h.Stub.SetAuctionator(api)

        local price = Prices.Best(105)

        h.Nil(price, "price")
        h.Equal(Prices.Status()[1].error, "price failed", "provider error")
        h.Equal(Log.Errors()[1].area, "provider:auctionator", "error area")
    end,

    ["database updates bump the price generation"] = function()
        Ready()
        local before = Generations.Get("prices")
        h.Stub.FireEvent("PLAYER_LOGIN")
        local calls = h.Stub.AuctionatorCalls()

        h.Equal(calls[1].name, "update", "update registration")
        h.Equal(calls[1].callerID, "LootLogic", "update caller ID")
        h.Stub.FireAuctionatorUpdate()
        h.Equal(Generations.Get("prices"), before + 1, "generation")
    end,
}
