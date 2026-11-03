local _, ns, h = ...

local Cache = ns.Cache
local Generations = ns.Generations
local Prices = ns.Prices

local DAY = 86400
-- The stub clock starts at 2024-01-01 00:00:00 UTC.
local START = 1704067200

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
    LootLogicDB.debug.enabled = true
end

local function LastLine()
    local log = LootLogicDB.debug.log
    return log[#log]
end

-- The validUntil of an Auctionator-style price (an age, no timestamp) at the
-- time the case set.
local function DayTurn()
    return Cache.ValidUntil({ { ageDays = 1 } }, 7)
end

return {
    ["Cache: the keys are exactly the forms of technical findings 15"] = function()
        h.Equal(Cache.SlotKey(0, 3, "item:1", true, 5), "0:3|item:1|1|5", "bound bag item")
        h.Equal(Cache.SlotKey(5, 12, "item:1", false, 120), "5:12|item:1|0|120", "unbound")
        h.Equal(Cache.LinkKey("item:1"), "L|item:1", "link only")
        h.Equal(Cache.InboxKey("item:1"), "I|item:1", "inbox attachment")
    end,

    ["Cache: an entry is reused until one of its generations moves, and only then"] = function()
        local result = { category = "none" }
        local key = Cache.LinkKey("item:1")
        Cache.Store(key, result, { "asks", "gearHere" })
        h.True(Cache.Get(key) == result, "fresh")
        Generations.Bump("settings")
        Generations.Bump("prices")
        Generations.Bump("roster")
        h.True(Cache.Get(key) == result, "generations it did not use moved")
        Generations.Bump("gearHere")
        h.Nil(Cache.Get(key), "a used generation moved")
        h.Nil(Cache.Get(key), "and it stays gone")
    end,

    ["Cache: a bump before the store does not make the entry stale"] = function()
        Generations.Bump("asks")
        local key = Cache.LinkKey("item:2")
        local result = {}
        Cache.Store(key, result, { "asks" })
        h.True(Cache.Get(key) == result, "stored at the current value")
        Generations.Bump("asks")
        h.Nil(Cache.Get(key), "stale after the next bump")
    end,

    ["Cache: changing the used list after the store does not change the entry"] = function()
        local used = { "asks" }
        local key = Cache.LinkKey("item:6")
        local result = {}
        Cache.Store(key, result, used)
        used[1] = "roster"
        Generations.Bump("roster")
        h.True(Cache.Get(key) == result, "the entry kept its own list")
        Generations.Bump("asks")
        h.Nil(Cache.Get(key), "stale by asks")
    end,

    ["Cache: a missing key has no result"] = function()
        h.Nil(Cache.Get("0:1|item:9|0|1"), "never stored")
    end,

    ["Cache: each key holds its own entry"] = function()
        local first = {}
        local second = {}
        Cache.Store(Cache.SlotKey(0, 1, "item:1", false, 1), first, {})
        Cache.Store(Cache.SlotKey(0, 2, "item:1", false, 1), second, {})
        h.True(Cache.Get(Cache.SlotKey(0, 1, "item:1", false, 1)) == first, "slot 1")
        h.True(Cache.Get(Cache.SlotKey(0, 2, "item:1", false, 1)) == second, "slot 2")
        h.Nil(Cache.Get(Cache.SlotKey(0, 1, "item:1", true, 1)), "bound state differs")
        h.Nil(Cache.Get(Cache.SlotKey(0, 1, "item:1", false, 2)), "holding differs")
    end,

    ["Cache: validUntil of a timestamped price is its age passing maxPriceAgeDays"] = function()
        -- Written 2 days and 100 s ago: its age is 2 whole days until it is 8
        -- days old, which is the first moment it is above 7.
        local written = START - 2 * DAY - 100
        h.Equal(
            Cache.ValidUntil({ { timestamp = written, ageDays = 2 } }, 7),
            written + 8 * DAY,
            "valid until the age reaches 8 days"
        )
        h.Equal(
            Cache.ValidUntil({ { timestamp = START, ageDays = 0 } }, 0),
            START + DAY,
            "maxPriceAgeDays 0: only the first day"
        )
    end,

    ["Cache: validUntil is the earliest of the prices relied on"] = function()
        local old = { timestamp = START - 5 * DAY, ageDays = 5 }
        local new = { timestamp = START - DAY, ageDays = 1 }
        h.Equal(Cache.ValidUntil({ new, old }, 7), START + 3 * DAY, "the older price decides")
        h.Equal(Cache.ValidUntil({ old, new }, 7), START + 3 * DAY, "in either order")
    end,

    ["Cache: a price with no age and no timestamp gives no validUntil"] = function()
        h.Nil(Cache.ValidUntil({ {} }, 7), "never usable")
        h.Nil(Cache.ValidUntil({}, 7), "no prices")
    end,

    ["Cache: an entry is stale once now reaches validUntil, not before"] = function()
        local key = Cache.LinkKey("item:3")
        local result = {}
        local expires = START + 3 * DAY
        Cache.Store(key, result, { "prices" }, expires)
        h.Stub.Advance(3 * DAY - 1)
        h.True(Cache.Get(key) == result, "one second before")
        h.Stub.Advance(1)
        h.Nil(Cache.Get(key), "at validUntil")
    end,

    ["Cache: an entry with no validUntil does not age"] = function()
        local key = Cache.LinkKey("item:4")
        local result = {}
        Cache.Store(key, result, { "asks" })
        h.Stub.Advance(400 * DAY)
        h.True(Cache.Get(key) == result, "still fresh")
    end,

    ["Cache: a price with no timestamp is rechecked at 01:00 from 00:00"] = function()
        h.Equal(DayTurn(), START + 3600, "at 00:00 the next time is 01:00")
        h.Stub.Advance(30 * 60 + 15)
        h.Equal(DayTurn(), START + 3600, "at 00:30:15 it is still 01:00")
    end,

    ["Cache: a price with no timestamp is rechecked at the next 00:00 from 01:00 on"] = function()
        h.Stub.Advance(3600)
        h.Equal(DayTurn(), START + DAY, "at 01:00:00 the next time is midnight")
        h.Stub.Advance(11 * 3600)
        h.Equal(DayTurn(), START + DAY, "at 12:00 it is midnight")
        h.Stub.Advance(11 * 3600 + 30 * 60)
        h.Equal(DayTurn(), START + DAY, "at 23:30 it is midnight, in 30 minutes")
    end,

    ["Cache: the day turn follows the local clock, not UTC"] = function()
        -- 18:00 UTC is 23:30 at +5:30, so the turn is in 30 minutes.
        h.Stub.SetTimeOffset(5 * 3600 + 30 * 60)
        h.Stub.Advance(18 * 3600)
        h.Equal(DayTurn(), START + 18 * 3600 + 30 * 60, "local midnight")
        -- 19:00 UTC is 00:30 local: the next time is 01:00 local.
        h.Stub.Advance(3600)
        h.Equal(DayTurn(), START + 19 * 3600 + 30 * 60, "local 01:00")
    end,

    ["Cache: an entry relying on a price with no timestamp goes stale at the turn"] = function()
        h.Stub.Advance(12 * 3600)
        local key = Cache.LinkKey("item:5")
        local result = {}
        Cache.Store(key, result, { "prices" }, DayTurn())
        h.Stub.Advance(12 * 3600 - 1)
        h.True(Cache.Get(key) == result, "before midnight")
        h.Stub.Advance(1)
        h.Nil(Cache.Get(key), "at midnight")
    end,

    ["Cache: a price notice counts the entries it made stale and logs one prices line"] = function()
        Boot()
        local onlyPrices = Cache.LinkKey("item:10")
        local onlyAsks = Cache.LinkKey("item:11")
        local both = Cache.LinkKey("item:12")
        local staleAlready = Cache.LinkKey("item:13")
        Cache.Store(onlyPrices, {}, { "prices" })
        Cache.Store(onlyAsks, {}, { "asks" })
        Cache.Store(both, {}, { "prices", "asks" })
        Cache.Store(staleAlready, {}, { "prices", "loadouts" })
        Generations.Bump("loadouts")
        Prices.NotifyChanged("auctionator")
        h.True(
            string.find(
                LastLine(),
                "prices: auctionator: new data, 2 cached results made stale",
                1,
                true
            ),
            "line: " .. tostring(LastLine())
        )
        h.Nil(Cache.Get(onlyPrices), "stale")
        h.Nil(Cache.Get(both), "stale")
        h.True(Cache.Get(onlyAsks) ~= nil, "did not use prices")
        h.Nil(Cache.Get(staleAlready), "was already stale")
    end,

    ["Cache: a second notice does not count entries it found stale already"] = function()
        Boot()
        Cache.Store(Cache.LinkKey("item:20"), {}, { "prices" })
        Prices.NotifyChanged("ahdb")
        Prices.NotifyChanged("ahdb")
        h.True(
            string.find(LastLine(), "prices: ahdb: new data, 0 cached results made stale", 1, true),
            "line: " .. tostring(LastLine())
        )
    end,

    ["Cache: Clear forgets every entry"] = function()
        local key = Cache.LinkKey("item:30")
        Cache.Store(key, {}, {})
        Cache.Clear()
        h.Nil(Cache.Get(key), "gone")
    end,
}
