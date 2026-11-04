--[[
The result caches (technical findings 15, Caches and generations). An entry
stores the generations it used and is stale when any of them moved. An entry
that reached step 6 also stores validUntil, and is stale once the clock reaches
it. The timer that would refresh such entries when validUntil passes is not
built here: it arrives in M2 with its first consumer, the adapters.
]]

local _, ns = ...

local Cache = {}
ns.Cache = Cache

local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Prices = ns.Prices

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

-- Key -> { result, names, values, validUntil, counted }. names and values are
-- parallel lists of the generations the result used and their values then.
local entries = {}

--- The key of a bag item: "bag:slot|link|bound|holding" (so two identical
--- copies can have different results; holding only matters for step 6).
-- @param bag number
-- @param slot number
-- @param link string
-- @param bound boolean
-- @param holding number
-- @treturn string
function Cache.SlotKey(bag, slot, link, bound, holding)
    local boundText = "0"
    if bound then
        boundText = "1"
    end
    return string.format("%d:%d|%s|%s|%d", bag, slot, link, boundText, holding)
end

--- The key of a link-only result: "L|link".
-- @param link string
-- @treturn string
function Cache.LinkKey(link)
    return "L|" .. link
end

-- The key of a mailbox attachment: "I|link"; Classify adds "|inbound" for an
-- inbound copy.
-- @param link string
-- @treturn string
function Cache.InboxKey(link)
    return "I|" .. link
end

--- Stores a result with the generations it used.
-- @param key string from SlotKey, LinkKey or InboxKey
-- @param result table
-- @param used table list of generation names the result used
-- @param validUntil number|nil epoch time from Cache.ValidUntil, for a result
--   that reached step 6
function Cache.Store(key, result, used, validUntil)
    local values = {}
    for index, name in ipairs(used) do
        values[index] = Generations.Get(name)
    end
    entries[key] = {
        result = result,
        names = { unpack(used) },
        values = values,
        validUntil = validUntil,
        counted = false,
    }
end

-- True when a generation the entry used moved, other than the one named in
-- `except` (nil to count every generation), or the clock reached validUntil.
local function IsStale(entry, except)
    local names = entry.names
    local values = entry.values
    for index = 1, #names do
        local name = names[index]
        if name ~= except and Generations.Get(name) ~= values[index] then
            return true
        end
    end
    if entry.validUntil and GetServerTime() >= entry.validUntil then
        return true
    end
    return false
end

--- The stored result, or nil when there is none or it is stale (a stale entry
--- is dropped).
-- @param key string
-- @return table|nil
function Cache.Get(key)
    local entry = entries[key]
    if not entry then
        return nil
    end
    if IsStale(entry) then
        entries[key] = nil
        return nil
    end
    return entry.result
end

--- Forgets every entry.
function Cache.Clear()
    wipe(entries)
end

-- The next 00:00 or 01:00 on the computer's local clock, whichever comes
-- first after now. date("*t", ...) in local time is from memory (live check
-- L63). A day with a clock change is an hour out, which the hourly recheck
-- around the turn absorbs (technical findings 15, Auctionator's day turn).
local function NextDayTurn(now)
    local parts = date("*t", now)
    local intoHour = parts.min * 60 + parts.sec
    if parts.hour == 0 then
        return now + SECONDS_PER_HOUR - intoHour
    end
    return now + SECONDS_PER_DAY - (parts.hour * SECONDS_PER_HOUR + intoHour)
end

-- The time one price stops being usable, or nil for a price that was never
-- usable (no age). A price with a timestamp is too old once its age in whole
-- days, rounded down, passes maxPriceAgeDays (spec 4). Auctionator's price has
-- no timestamp, so it is checked when its day turns.
-- With byAge, a timestamped price is instead due when its whole-day age next
-- changes, because Prices.Best ranks providers by that age.
local function PriceExpiry(price, maxPriceAgeDays, byAge)
    if price.timestamp then
        if byAge then
            return price.timestamp + (price.ageDays + 1) * SECONDS_PER_DAY
        end
        return price.timestamp + (maxPriceAgeDays + 1) * SECONDS_PER_DAY
    end
    if price.ageDays then
        return NextDayTurn(GetServerTime())
    end
    return nil
end

--- The earliest time any of the prices a result relied on stops being usable
--- (the entry's validUntil), or nil when none of them can.
-- @param prices table list of provider prices ({ timestamp, ageDays, ... })
-- @param maxPriceAgeDays number
-- @param byAge boolean|nil expire at the next whole-day age change, for prices
--   that competed to be the best
-- @treturn number|nil epoch time
function Cache.ValidUntil(prices, maxPriceAgeDays, byAge)
    local earliest
    for _, price in ipairs(prices) do
        local expiry = PriceExpiry(price, maxPriceAgeDays, byAge)
        if expiry and (not earliest or expiry < earliest) then
            earliest = expiry
        end
    end
    return earliest
end

-- A price notice has bumped the generation: count the entries it made stale,
-- those that used the price generation and were fresh before it, and write the
-- debug "prices" line.
local function OnPricesChanged(providerId)
    local count = 0
    local current = Generations.Get("prices")
    for _, entry in pairs(entries) do
        if not entry.counted and not IsStale(entry, "prices") then
            for index, name in ipairs(entry.names) do
                if name == "prices" and entry.values[index] ~= current then
                    entry.counted = true
                    count = count + 1
                    break
                end
            end
        end
    end
    Log.Debug("prices", string.format(L.pricesStale, providerId, count))
end

Prices.OnChanged(OnPricesChanged)
