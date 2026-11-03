local _, ns, h = ...

local DB = ns.DB
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Prices = ns.Prices

-- The default settings: providerOrder { "ahdb", "auctionator" } and
-- maxPriceAgeDays 7.
local function Fresh()
    LootLogicDB = DB.NewDefaults()
end

-- Registers a fake provider. options: label, price (a table, or a function of
-- itemID and link), available (default true), hasData, honours, failWith.
local function Fake(id, options)
    options = options or {}
    local provider = {
        id = id,
        label = options.label or id,
        honoursLastScan = options.honours,
        updateCallback = nil,
        available = options.available ~= false,
        failWith = options.failWith,
        price = options.price,
    }
    function provider.IsAvailable()
        return provider.available
    end
    function provider.GetPrice(itemID, link)
        if provider.failWith then
            error(provider.failWith, 0)
        end
        if type(provider.price) == "function" then
            return provider.price(itemID, link)
        end
        return provider.price
    end
    if options.hasData ~= nil then
        function provider.HasData()
            return options.hasData
        end
    end
    function provider.OnUpdate(callback)
        provider.updateCallback = callback
    end
    Prices.Register(provider)
    return provider
end

local function Price(ageDays, extra)
    local price = { unit = 1000, ageDays = ageDays }
    for key, value in pairs(extra or {}) do
        price[key] = value
    end
    return price
end

return {
    -- Best
    ["Best with no provider gives noprovider"] = function()
        Fresh()
        local price, reason = Prices.Best(1, "item:1")
        h.Nil(price, "price")
        h.DeepEqual(reason, { code = "noprovider" }, "reason")
    end,

    ["Best with only unavailable providers gives noprovider"] = function()
        Fresh()
        Fake("auctionator", { available = false, price = Price(1) })
        local price, reason = Prices.Best(1, "item:1")
        h.Nil(price, "price")
        h.Equal(reason.code, "noprovider", "code")
    end,

    ["Best returns the one usable price with its source"] = function()
        Fresh()
        local table_ = Price(2)
        Fake("auctionator", { label = "Auctionator", price = table_ })
        local price, source = Prices.Best(1, "item:1")
        h.Equal(price, table_, "the table GetPrice returned")
        h.DeepEqual(source, { id = "auctionator", label = "Auctionator" }, "source")
    end,

    ["Best passes the item ID and the link to GetPrice"] = function()
        Fresh()
        local seen
        Fake("auctionator", {
            price = function(itemID, link)
                seen = { itemID, link }
                return Price(1)
            end,
        })
        Prices.Best(42, "item:42")
        h.DeepEqual(seen, { 42, "item:42" }, "arguments")
    end,

    ["the smaller age wins between two usable prices"] = function()
        Fresh()
        Fake("ahdb", { price = Price(3) })
        Fake("auctionator", { price = Price(1) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "source")
    end,

    ["equal ages go to providerOrder, whatever the registration order"] = function()
        Fresh()
        Fake("auctionator", { price = Price(2) })
        Fake("ahdb", { price = Price(2) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "ahdb", "ahdb is first in providerOrder")
    end,

    ["an id missing from providerOrder loses an equal age"] = function()
        Fresh()
        Fake("other", { price = Price(2) })
        Fake("auctionator", { price = Price(2) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "source")
    end,

    ["a price older than maxPriceAgeDays gives stale with the old price and provider"] = function()
        Fresh()
        local old = Price(9)
        Fake("auctionator", { price = old })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.price, old, "price")
        h.Equal(reason.provider, "auctionator", "provider")
    end,

    ["a price at exactly maxPriceAgeDays is usable"] = function()
        Fresh()
        Fake("auctionator", { price = Price(7) })
        local price = Prices.Best(1)
        h.True(price, "usable")
    end,

    ["a nil price gives neverseen"] = function()
        Fresh()
        -- hasData true, so noscan does not apply.
        Fake("auctionator", { price = nil, hasData = true })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.Equal(reason.code, "neverseen", "code")
        h.Nil(reason.price, "no price")
    end,

    ["a price with no age gives stale"] = function()
        Fresh()
        local old = { unit = 500 }
        Fake("auctionator", { price = old })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.price, old, "price")
        h.Equal(reason.provider, "auctionator", "provider")
    end,

    ["mixed failures give stale before notinscan before neverseen"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        LootLogicDB.settings.ah.providerOrder = { "a", "b", "c", "d" }
        -- With requireLastScan on, only honouring providers are asked.
        Fake("a", { honours = true, price = nil, hasData = true })
        Fake("b", { honours = true, price = Price(1, { inLastScan = false }), hasData = true })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "notinscan", "notinscan before neverseen")
        h.Equal(reason.provider, "b", "provider")
        Fake("c", { honours = true, price = Price(30, { inLastScan = true }), hasData = true })
        _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "stale before notinscan")
        h.Equal(reason.provider, "c", "provider")
    end,

    ["neverseen does not hide a later failure with a price"] = function()
        Fresh()
        Fake("ahdb", { price = nil, hasData = true })
        Fake("auctionator", { price = Price(20) })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.provider, "auctionator", "provider")
    end,

    ["two stale failures carry the smaller age"] = function()
        Fresh()
        Fake("ahdb", { price = Price(20) })
        local younger = Price(9)
        Fake("auctionator", { price = younger })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.price, younger, "price")
        h.Equal(reason.provider, "auctionator", "provider")
    end,

    ["a stale price with an age beats one with no age"] = function()
        Fresh()
        Fake("ahdb", { price = { unit = 1 } })
        Fake("auctionator", { price = Price(40) })
        local _, reason = Prices.Best(1)
        h.Equal(reason.provider, "auctionator", "provider")
    end,

    -- noscan
    ["no price this session and no HasData gives noscan"] = function()
        Fresh()
        Fake("auctionator", { price = nil })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.DeepEqual(reason, { code = "noscan" }, "reason")
    end,

    ["HasData false gives noscan"] = function()
        Fresh()
        Fake("ahdb", { price = nil, hasData = false })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "noscan", "code")
    end,

    ["HasData true gives neverseen"] = function()
        Fresh()
        Fake("ahdb", { price = nil, hasData = true })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "neverseen", "code")
    end,

    ["HasData of an unavailable provider is not asked"] = function()
        Fresh()
        Fake("ahdb", { available = false, price = nil, hasData = true })
        Fake("auctionator", { price = nil })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "noscan", "code")
    end,

    ["after any price in the session noscan no longer appears"] = function()
        Fresh()
        Fake("auctionator", {
            price = function(itemID)
                if itemID == 1 then
                    return Price(1)
                end
                return nil
            end,
        })
        h.Equal(select(2, Prices.Best(2)).code, "noscan", "before")
        h.True(Prices.Best(1), "a price")
        h.Equal(select(2, Prices.Best(2)).code, "neverseen", "after")
    end,

    ["a price with no age sets the session flag"] = function()
        Fresh()
        Fake("auctionator", {
            price = function(itemID)
                if itemID == 1 then
                    return { unit = 5 }
                end
                return nil
            end,
        })
        h.Equal(select(2, Prices.Best(1)).code, "stale", "the item")
        h.Equal(select(2, Prices.Best(2)).code, "neverseen", "another item")
    end,

    -- requireLastScan
    ["requireLastScan with an honouring provider ignores the others"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("ahdb", { honours = true, price = Price(1, { inLastScan = false }), hasData = true })
        local asked = false
        Fake("auctionator", {
            price = function()
                asked = true
                return Price(0)
            end,
        })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.Equal(reason.code, "notinscan", "code")
        h.Equal(reason.provider, "ahdb", "provider")
        h.Equal(asked, false, "the other provider was not asked")
        h.Equal(Prices.LastScanIgnored(), false, "not ignored")
    end,

    ["requireLastScan uses an honouring price that is in the last scan"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("ahdb", { honours = true, price = Price(1, { inLastScan = true }) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "ahdb", "source")
    end,

    ["requireLastScan with an honouring provider that is not available is ignored"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("ahdb", { honours = true, available = false })
        Fake("auctionator", { price = Price(1) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "source")
        h.Equal(Prices.LastScanIgnored(), true, "ignored")
    end,

    ["requireLastScan with only non-honouring providers is ignored"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("auctionator", { price = Price(1) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "the price is judged by age")
        h.Equal(Prices.LastScanIgnored(), true, "ignored")
    end,

    ["LastScanIgnored is false when the setting is off"] = function()
        Fresh()
        Fake("auctionator", { price = Price(1) })
        h.Equal(Prices.LastScanIgnored(), false, "off")
    end,

    ["LastScanIgnored is false with no provider available"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("auctionator", { available = false })
        h.Equal(Prices.LastScanIgnored(), false, "none available")
    end,

    -- Failure order with the winner first, and requireLastScan corners
    ["two stale failures: the smaller age wins when it comes first"] = function()
        Fresh()
        local younger = Price(9)
        Fake("ahdb", { price = younger })
        Fake("auctionator", { price = Price(20) })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.price, younger, "price")
        h.Equal(reason.provider, "ahdb", "provider")
    end,

    ["two stale failures of equal age go to the first in providerOrder"] = function()
        Fresh()
        local first = Price(9)
        Fake("auctionator", { price = Price(9) })
        Fake("ahdb", { price = first })
        local _, reason = Prices.Best(1)
        h.Equal(reason.provider, "ahdb", "provider")
        h.Equal(reason.price, first, "price")
    end,

    ["stale first beats a later neverseen"] = function()
        Fresh()
        Fake("ahdb", { price = Price(20) })
        Fake("auctionator", { price = nil, hasData = true })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.provider, "ahdb", "provider")
    end,

    ["a first stale beats a later notinscan"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        LootLogicDB.settings.ah.providerOrder = { "a", "b" }
        Fake("a", { honours = true, price = Price(30, { inLastScan = true }) })
        Fake("b", { honours = true, price = Price(1, { inLastScan = false }) })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "stale", "code")
        h.Equal(reason.provider, "a", "provider")
    end,

    ["a first notinscan beats a later neverseen"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        LootLogicDB.settings.ah.providerOrder = { "a", "b" }
        Fake("a", { honours = true, price = Price(1, { inLastScan = false }) })
        Fake("b", { honours = true, price = nil, hasData = true })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "notinscan", "code")
        h.Equal(reason.provider, "a", "provider")
    end,

    ["requireLastScan with an honouring provider that has no scans gives noscan"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("ahdb", { honours = true, price = nil, hasData = false })
        Fake("auctionator", { price = Price(0) })
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.DeepEqual(reason, { code = "noscan" }, "reason")
    end,

    ["inLastScan is not required while requireLastScan is off"] = function()
        Fresh()
        local outside = Price(1, { inLastScan = false })
        Fake("ahdb", { honours = true, price = outside })
        local price, source = Prices.Best(1)
        h.Equal(price, outside, "price")
        h.Equal(source.id, "ahdb", "source")
    end,

    -- NotifyChanged timing
    ["the first price of a session notifies after Best, not during it"] = function()
        Fresh()
        local heard = {}
        Prices.OnChanged(function(providerId)
            heard[#heard + 1] = providerId
        end)
        Fake("auctionator", { price = Price(1) })
        local before = Generations.Get("prices")
        Prices.Best(1)
        h.Equal(Generations.Get("prices"), before, "no bump during Best")
        h.DeepEqual(heard, {}, "no callback during Best")
        h.Stub.Advance(0)
        h.Equal(Generations.Get("prices"), before + 1, "one bump after")
        h.DeepEqual(heard, { "auctionator" }, "callback with the provider id")
    end,

    ["a second price does not notify again"] = function()
        Fresh()
        local calls = 0
        Prices.OnChanged(function()
            calls = calls + 1
        end)
        Fake("auctionator", { price = Price(1) })
        Prices.Best(1)
        h.Stub.Advance(0)
        Prices.Best(2)
        h.Stub.Advance(0)
        h.Equal(calls, 1, "callbacks")
        h.Equal(Generations.Get("prices"), 1, "bumps")
    end,

    ["NotifyChanged bumps first, then calls every callback in order"] = function()
        Fresh()
        local order = {}
        Prices.OnChanged(function(providerId)
            order[#order + 1] = { "first", providerId, Generations.Get("prices") }
        end)
        Prices.OnChanged(function(providerId)
            order[#order + 1] = { "second", providerId, Generations.Get("prices") }
        end)
        Prices.NotifyChanged("ahdb")
        h.DeepEqual(order, { { "first", "ahdb", 1 }, { "second", "ahdb", 1 } }, "calls")
    end,

    ["a price that fails no usable test still notifies once"] = function()
        Fresh()
        Fake("auctionator", { price = Price(30) })
        Prices.Best(1)
        h.Stub.Advance(0)
        h.Equal(Generations.Get("prices"), 1, "bumps")
    end,

    -- OnUpdate
    ["PLAYER_LOGIN calls OnUpdate of each available provider once"] = function()
        Fresh()
        local first = Fake("ahdb")
        local second = Fake("auctionator", { available = false })
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.True(first.updateCallback, "available provider hooked")
        h.Nil(second.updateCallback, "unavailable provider not hooked")
        local callback = first.updateCallback
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(first.updateCallback, callback, "not hooked twice")
    end,

    ["a later ADDON_LOADED hooks a provider that became available"] = function()
        Fresh()
        local late = Fake("auctionator", { available = false })
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Nil(late.updateCallback, "not yet")
        late.available = true
        h.Stub.FireEvent("ADDON_LOADED", "Auctionator")
        h.True(late.updateCallback, "hooked")
    end,

    ["ADDON_LOADED before PLAYER_LOGIN hooks nothing"] = function()
        Fresh()
        local provider = Fake("ahdb")
        h.Stub.FireEvent("ADDON_LOADED", "Auctionator")
        h.Nil(provider.updateCallback, "not before login")
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.True(provider.updateCallback, "hooked at login")
    end,

    ["the OnUpdate callback notifies with the provider id"] = function()
        Fresh()
        local heard = {}
        Prices.OnChanged(function(providerId)
            heard[#heard + 1] = providerId
        end)
        local provider = Fake("ahdb")
        h.Stub.FireEvent("PLAYER_LOGIN")
        provider.updateCallback()
        h.DeepEqual(heard, { "ahdb" }, "heard")
        h.Equal(Generations.Get("prices"), 1, "bump")
    end,

    -- Status
    ["Status lists the providers in providerOrder"] = function()
        Fresh()
        Fake("other", { label = "Other" })
        Fake("auctionator", { label = "Auctionator", available = false })
        Fake("ahdb", { label = "AHDB" })
        local status = Prices.Status()
        h.Equal(#status, 3, "entries")
        h.Equal(status[1].id, "ahdb", "first")
        h.Equal(status[2].id, "auctionator", "second")
        h.Equal(status[3].id, "other", "last")
        h.Equal(status[1].label, "AHDB", "label")
        h.Equal(status[1].available, true, "available")
        h.Equal(status[2].available, false, "unavailable")
        h.Equal(status[1].seen, false, "seen")
        h.Nil(status[1].newestAgeDays, "newest age")
        h.Nil(status[1].error, "error")
    end,

    ["Status shows seen and the smallest age after reads"] = function()
        Fresh()
        Fake("auctionator", {
            price = function(itemID)
                return Price(itemID)
            end,
        })
        Prices.Best(5)
        Prices.Best(3)
        Prices.Best(4)
        local entry = Prices.Status()[1]
        h.Equal(entry.seen, true, "seen")
        h.Equal(entry.newestAgeDays, 3, "newestAgeDays")
    end,

    ["Status newestAgeDays stays nil when every price had no age"] = function()
        Fresh()
        Fake("auctionator", { price = { unit = 1 } })
        Prices.Best(1)
        local entry = Prices.Status()[1]
        h.Equal(entry.seen, true, "seen")
        h.Nil(entry.newestAgeDays, "newestAgeDays")
    end,

    ["Status counts a stale price with an age"] = function()
        Fresh()
        Fake("auctionator", { price = Price(30) })
        Prices.Best(1)
        h.Equal(Prices.Status()[1].newestAgeDays, 30, "newestAgeDays")
    end,

    ["a failing provider sets its error, is logged and prints the line once"] = function()
        Fresh()
        Fake("ahdb", { label = "AHDB", failWith = "boom" })
        Fake("auctionator", { label = "Auctionator", price = Price(1) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "the other provider is still used")
        local status = Prices.Status()
        h.Equal(status[1].error, "boom", "error")
        h.Nil(status[2].error, "other provider")
        local errors = Log.Errors()
        h.Equal(#errors, 1, "entries")
        h.Equal(errors[1].area, "provider:ahdb", "area")
        h.Equal(errors[1].message, "boom", "message")
        local expected = L.chatPrefix
            .. " "
            .. string.format(L.providerFailedUsing, "AHDB", "boom", "Auctionator")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
        -- Again: more Errors counts, no second chat line.
        Prices.Best(2)
        h.Equal(#h.Stub.ChatLines(), 1, "still one chat line")
        h.Equal(errors[1].count, 2, "count")
    end,

    ["the provider error line says no prices when no other provider is available"] = function()
        Fresh()
        Fake("ahdb", { label = "AHDB", failWith = "boom" })
        Fake("auctionator", { label = "Auctionator", available = false })
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "noscan", "reason")
        local expected = L.chatPrefix .. " " .. string.format(L.providerFailedNone, "AHDB", "boom")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["the provider error line is once per session over all providers"] = function()
        Fresh()
        Fake("ahdb", { failWith = "one" })
        Fake("auctionator", { failWith = "two" })
        Prices.Best(1)
        h.Equal(#h.Stub.ChatLines(), 1, "one line")
        h.Equal(#Log.Errors(), 2, "two entries")
    end,

    ["the next good call clears the error"] = function()
        Fresh()
        local provider = Fake("auctionator", { failWith = "boom" })
        Prices.Best(1)
        h.Equal(Prices.Status()[1].error, "boom", "set")
        provider.failWith = nil
        provider.price = Price(1)
        Prices.Best(1)
        h.Nil(Prices.Status()[1].error, "cleared")
    end,

    ["an error in IsAvailable counts the provider unavailable and is recorded"] = function()
        Fresh()
        local provider = Fake("auctionator", { price = Price(1) })
        function provider.IsAvailable()
            error("no api", 0)
        end
        local price, reason = Prices.Best(1)
        h.Nil(price, "price")
        h.Equal(reason.code, "noprovider", "code")
        h.Equal(Log.Errors()[1].area, "provider:auctionator", "area")
        local entry = Prices.Status()[1]
        h.Equal(entry.available, false, "available")
        h.Equal(entry.error, "no api", "error")
        function provider.IsAvailable()
            return true
        end
        entry = Prices.Status()[1]
        h.Equal(entry.available, true, "available again")
        h.Nil(entry.error, "cleared by an IsAvailable that does not error")
    end,

    ["an error in HasData is recorded and counts as no data"] = function()
        Fresh()
        local provider = Fake("ahdb", { price = nil })
        function provider.HasData()
            error("bad", 0)
        end
        local _, reason = Prices.Best(1)
        h.Equal(reason.code, "noscan", "code")
        h.Equal(Log.Errors()[1].area, "provider:ahdb", "area")
        -- Status asks IsAvailable, which does not clear a HasData error.
        h.Equal(Prices.Status()[1].error, "bad", "error")
        function provider.HasData()
            return true
        end
        Prices.Best(2)
        h.Nil(Prices.Status()[1].error, "cleared by a HasData that does not error")
    end,

    ["an error in OnUpdate is recorded"] = function()
        Fresh()
        local provider = Fake("ahdb")
        function provider.OnUpdate()
            error("no listen", 0)
        end
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(Log.Errors()[1].area, "provider:ahdb", "area")
        h.Equal(Prices.Status()[1].error, "no listen", "error")
    end,

    -- Provider error line (D152)
    ["a failing honouring provider names no fallback it would not ask"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        Fake("ahdb", { label = "AHDB", honours = true, failWith = "boom" })
        Fake("auctionator", { label = "Auctionator", price = Price(1) })
        Prices.Best(1)
        local expected = L.chatPrefix .. " " .. string.format(L.providerFailedNone, "AHDB", "boom")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["the fallback is the first other provider in providerOrder"] = function()
        Fresh()
        LootLogicDB.settings.ah.providerOrder = { "ahdb", "b", "c" }
        Fake("c", { label = "C" })
        Fake("b", { label = "B" })
        Fake("ahdb", { label = "AHDB", failWith = "boom" })
        Prices.Best(1)
        local expected = L.chatPrefix
            .. " "
            .. string.format(L.providerFailedUsing, "AHDB", "boom", "B")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["an OnUpdate error is recorded and prints no line"] = function()
        Fresh()
        local provider = Fake("ahdb", { price = Price(1) })
        function provider.OnUpdate()
            error("no listen", 0)
        end
        h.Stub.FireEvent("PLAYER_LOGIN")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
        h.Equal(Log.Errors()[1].area, "provider:ahdb", "area")
        -- A good IsAvailable or GetPrice does not clear an OnUpdate error.
        Prices.Best(1)
        h.Equal(Prices.Status()[1].error, "no listen", "error stays")
        h.True(Prices.Best(1), "prices are still used")
    end,

    ["a HasData error is recorded and prints no line"] = function()
        Fresh()
        local provider = Fake("ahdb", { price = nil })
        function provider.HasData()
            error("bad", 0)
        end
        Prices.Best(1)
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    ["an IsAvailable error prints the line"] = function()
        Fresh()
        local provider = Fake("ahdb", { label = "AHDB" })
        function provider.IsAvailable()
            error("gone", 0)
        end
        Prices.Best(1)
        local expected = L.chatPrefix .. " " .. string.format(L.providerFailedNone, "AHDB", "gone")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["naming the fallback records an error in the other provider's IsAvailable"] = function()
        Fresh()
        Fake("ahdb", { label = "AHDB", failWith = "boom" })
        local other = Fake("auctionator", { label = "Auctionator" })
        -- Available when Best lists the providers, raising when the line asks.
        local calls = 0
        function other.IsAvailable()
            calls = calls + 1
            if calls > 1 then
                error("also", 0)
            end
            return true
        end
        Prices.Best(1)
        local errors = Log.Errors()
        h.Equal(errors[#errors].area, "provider:auctionator", "the other error is recorded")
        h.Equal(errors[#errors].message, "also", "message")
        local expected = L.chatPrefix .. " " .. string.format(L.providerFailedNone, "AHDB", "boom")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "one line")
    end,

    ["the fallback is named with requireLastScan off and an honouring failure"] = function()
        Fresh()
        Fake("ahdb", { label = "AHDB", honours = true, failWith = "boom" })
        Fake("auctionator", { label = "Auctionator", price = Price(1) })
        Prices.Best(1)
        local expected = L.chatPrefix
            .. " "
            .. string.format(L.providerFailedUsing, "AHDB", "boom", "Auctionator")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["an IsAvailable error of an honouring provider names the fallback"] = function()
        Fresh()
        LootLogicDB.settings.ah.requireLastScan = true
        local ahdb = Fake("ahdb", { label = "AHDB", honours = true })
        function ahdb.IsAvailable()
            error("gone", 0)
        end
        Fake("auctionator", { label = "Auctionator", price = Price(1) })
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "source")
        local expected = L.chatPrefix
            .. " "
            .. string.format(L.providerFailedUsing, "AHDB", "gone", "Auctionator")
        h.DeepEqual(h.Stub.ChatLines(), { expected }, "chat line")
    end,

    ["a provider calling Best from GetPrice does not disturb the outer call"] = function()
        Fresh()
        local auctionator = Fake("auctionator", { price = Price(1) })
        local ahdb = Fake("ahdb", { price = Price(5) })
        local nested = false
        function ahdb.GetPrice()
            if not nested then
                nested = true
                auctionator.available = false
                Prices.Best(999)
                auctionator.available = true
            end
            return Price(5)
        end
        local _, source = Prices.Best(1)
        h.Equal(source.id, "auctionator", "the outer call still asks every provider")
    end,

    ["a provider calling Best from IsAvailable does not disturb the outer call"] = function()
        Fresh()
        local asked = 0
        Fake("auctionator", {
            price = function()
                asked = asked + 1
                return Price(1)
            end,
        })
        local ahdb = Fake("ahdb", { price = Price(5) })
        local nested = false
        function ahdb.IsAvailable()
            if not nested then
                nested = true
                Prices.Best(2)
            end
            return true
        end
        Prices.Best(1)
        h.Equal(asked, 2, "one GetPrice per Best call")
    end,

    ["an error clears on the next call of the same function, not of another"] = function()
        Fresh()
        local provider = Fake("auctionator", { failWith = "boom" })
        Prices.Best(1)
        -- Best and Status call IsAvailable without error: the error stays.
        h.Equal(Prices.Status()[1].error, "boom", "stays after IsAvailable calls")
        provider.failWith = nil
        Prices.Best(1)
        h.Nil(Prices.Status()[1].error, "cleared by a GetPrice that does not error")
    end,

    ["a failing OnChanged callback is recorded and the next still runs"] = function()
        Fresh()
        local ran = false
        Prices.OnChanged(function()
            error("cb broke", 0)
        end)
        Prices.OnChanged(function()
            ran = true
        end)
        Prices.NotifyChanged("ahdb")
        h.Equal(ran, true, "next callback ran")
        h.Equal(Log.Errors()[1].area, "prices", "area")
        h.Equal(Log.Errors()[1].message, "cb broke", "message")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
    end,

    -- Register
    ["a duplicate id is ignored and recorded under prices"] = function()
        Fresh()
        local first = Fake("auctionator", { price = Price(1) })
        Fake("auctionator", { price = Price(0) })
        local errors = Log.Errors()
        h.Equal(#errors, 1, "entries")
        h.Equal(errors[1].area, "prices", "area")
        h.Equal(errors[1].message, string.format(L.providerDuplicate, "auctionator"), "message")
        h.Equal(#Prices.Status(), 1, "one provider")
        h.Equal(#h.Stub.ChatLines(), 0, "no chat line")
        local price = Prices.Best(1)
        h.Equal(price, first.price, "the first provider answers")
    end,
}
