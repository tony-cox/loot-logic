--[[
The price provider registry and the choice of the best price (spec 11.2,
technical findings 11.2 and 14, Registering).

Every call into a provider runs under pcall, because a provider reads another
addon, whose API can be missing, changed or failing (technical findings 11.1).
An error is recorded in the Errors
list under the area "provider:<id>" and kept in the provider's Status entry. An
error in IsAvailable or GetPrice also prints the provider error chat line, once
per session in total.
]]

local _, ns = ...

local Prices = {}
ns.Prices = Prices

local DB = ns.DB
local Events = ns.Events
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Util = ns.Util

-- The order of the failure codes, most informative first (spec 7.6).
local FAILURE_RANK = { stale = 1, notinscan = 2, neverseen = 3 }

-- Providers in registration order, and the state of each by id.
local providers = {}
local states = {}
local callbacks = {}

-- True once any provider has returned a price this session; lasts until
-- /reload.
local sessionPriced = false
local errorLinePrinted = false
local loggedIn = false

-- Lists reused by Best, LastScanIgnored, HookProviders and Status, so a bag
-- scan does not build the provider lists for each item. A call made while one
-- of them runs (a provider calling back into Prices) gets fresh tables.
local orderedList = {}
local availableList = {}
local placedSet = {}
local depth = 0

local function EnterLists()
    depth = depth + 1
    if depth == 1 then
        return orderedList, availableList
    end
    return {}, {}
end

local function LeaveLists()
    depth = depth - 1
end

local function Settings()
    return DB.Data().settings.ah
end

local function ProviderLabel(provider)
    return provider.label or provider.id
end

--- Fills `into` with the registered providers in providerOrder; an id missing
--- from it goes last, in registration order.
local function Ordered(into)
    wipe(into)
    if #providers == 0 then
        return into
    end
    wipe(placedSet)
    for _, id in ipairs(Settings().providerOrder) do
        local state = states[id]
        if state and not placedSet[id] then
            placedSet[id] = true
            into[#into + 1] = state.provider
        end
    end
    for _, provider in ipairs(providers) do
        if not placedSet[provider.id] then
            into[#into + 1] = provider
        end
    end
    return into
end

local PrintErrorLine

--- Calls provider[method](...) under pcall. On an error records it and returns
--- false; otherwise clears an error the same method left earlier and returns
--- true and the first result. (Clearing per method keeps a good IsAvailable
--- from hiding a failing GetPrice; technical findings 14.)
local function Call(provider, method, ...)
    local ok, first = Util.Pcall(provider[method], ...)
    local state = states[provider.id]
    if not ok then
        state.error = first
        state.errorMethod = method
        Log.Error("provider:" .. provider.id, first)
        -- Only an error that skips the provider's prices prints the line.
        if method == "IsAvailable" or method == "GetPrice" then
            PrintErrorLine(provider, method, first)
        end
        return false
    end
    if state.errorMethod == method then
        state.error = nil
        state.errorMethod = nil
    end
    return true, first
end

local function IsAvailable(provider)
    local ok, available = Call(provider, "IsAvailable")
    if ok and available then
        return true
    end
    return false
end

--- Prints the provider error chat line, once per session in total. It names
--- the first other provider that Best would ask now (in providerOrder; while
--- requireLastScan is on and an honouring provider is available, only an
--- honouring one), or says no prices until it works.
function PrintErrorLine(failed, method, message)
    if errorLinePrinted then
        return
    end
    -- Set first: asking the others may raise and come back here.
    errorLinePrinted = true
    local order = Ordered({})
    local available = {}
    local honouring = false
    for _, provider in ipairs(order) do
        local isAvailable
        if provider == failed then
            -- Its GetPrice raised, so it is available; its IsAvailable raised,
            -- so it is not.
            isAvailable = method == "GetPrice"
        else
            isAvailable = IsAvailable(provider)
        end
        available[provider] = isAvailable
        if isAvailable and provider.honoursLastScan then
            honouring = true
        end
    end
    honouring = honouring and Settings().requireLastScan
    local other
    for _, provider in ipairs(order) do
        if
            provider ~= failed
            and available[provider]
            and (not honouring or provider.honoursLastScan)
        then
            other = provider
            break
        end
    end
    local label = ProviderLabel(failed)
    if other then
        Log.Chat(string.format(L.providerFailedUsing, label, message, ProviderLabel(other)))
    else
        Log.Chat(string.format(L.providerFailedNone, label, message))
    end
end

--- Fills `available` with the available providers in providerOrder, using
--- `ordered` as the scratch list.
local function AvailableProviders(ordered, available)
    Ordered(ordered)
    wipe(available)
    for _, provider in ipairs(ordered) do
        if IsAvailable(provider) then
            available[#available + 1] = provider
        end
    end
    return available
end

local function NoteSeen(provider, price)
    local state = states[provider.id]
    state.seen = true
    local age = price.ageDays
    if age and (state.newestAgeDays == nil or age < state.newestAgeDays) then
        state.newestAgeDays = age
    end
    if not sessionPriced then
        sessionPriced = true
        -- Just after the current Best returns, so a classification in progress
        -- is not interrupted. C_Timer.After(0) running after the current call
        -- returns is from memory, not covered by a live check.
        C_Timer.After(0, function()
            Prices.NotifyChanged(provider.id)
        end)
    end
end

--- True when requireLastScan is on and some listed provider honours it.
local function HonouringOnly(available)
    if not Settings().requireLastScan then
        return false
    end
    for _, provider in ipairs(available) do
        if provider.honoursLastScan then
            return true
        end
    end
    return false
end

--- True when an available provider says it holds data.
local function AnyHasData(available)
    for _, provider in ipairs(available) do
        if provider.HasData then
            local ok, has = Call(provider, "HasData")
            if ok and has then
                return true
            end
        end
    end
    return false
end

--- A price with no age counts as the oldest.
local function Age(price)
    return price.ageDays or math.huge
end

--- Whether a failure with this code and price beats the one kept: a more
--- informative code first, then the smaller age; on a tie the earlier stays.
local function BeatsFailure(code, price, failure)
    if not failure then
        return true
    end
    if FAILURE_RANK[code] ~= FAILURE_RANK[failure.code] then
        return FAILURE_RANK[code] < FAILURE_RANK[failure.code]
    end
    if not price then
        return false
    end
    return not failure.price or Age(price) < Age(failure.price)
end

--- Calls OnUpdate once for each provider not hooked yet that is available.
local function HookProviders()
    local ordered = EnterLists()
    for _, provider in ipairs(Ordered(ordered)) do
        local state = states[provider.id]
        if not state.hooked and IsAvailable(provider) then
            state.hooked = true
            Call(provider, "OnUpdate", function()
                Prices.NotifyChanged(provider.id)
            end)
        end
    end
    LeaveLists()
end

--- Adds a provider (the table of spec 11.2). A second provider with a
--- registered id is ignored and recorded under the area "prices".
-- @param provider table { id, label, honoursLastScan, IsAvailable, GetPrice,
--   HasData, OnUpdate }
function Prices.Register(provider)
    if states[provider.id] then
        Log.Error("prices", string.format(L.providerDuplicate, provider.id))
        return
    end
    providers[#providers + 1] = provider
    states[provider.id] = {
        provider = provider,
        seen = false,
        hooked = false,
    }
end

--- Registers a callback that gets (providerId) when prices changed.
-- @param callback function
function Prices.OnChanged(callback)
    callbacks[#callbacks + 1] = callback
end

--- Bumps the price generation, then calls each OnChanged callback with the
--- provider id. Each runs under Log.Guard("prices", ...), so a failing
--- callback is recorded and the next still runs.
-- @param providerId string
function Prices.NotifyChanged(providerId)
    Generations.Bump("prices")
    for index = 1, #callbacks do
        Log.Guard("prices", callbacks[index], providerId)
    end
end

--- Prices.Best over the list of available providers.
local function Choose(itemID, link, available)
    if #available == 0 then
        return nil, { code = "noprovider" }
    end
    local maxAge = Settings().maxPriceAgeDays
    local honouringOnly = HonouringOnly(available)
    local best, bestProvider, failure
    local considered = {}
    for _, provider in ipairs(available) do
        if not honouringOnly or provider.honoursLastScan then
            local ok, price = Call(provider, "GetPrice", itemID, link)
            if ok and price then
                NoteSeen(provider, price)
                local code
                if not price.ageDays or price.ageDays > maxAge then
                    code = "stale"
                elseif honouringOnly and not price.inLastScan then
                    code = "notinscan"
                end
                if not code then
                    considered[#considered + 1] = price
                    -- The list is in providerOrder, so a strict comparison
                    -- leaves the tie to the earlier provider.
                    if not best or price.ageDays < best.ageDays then
                        best = price
                        bestProvider = provider
                    end
                elseif BeatsFailure(code, price, failure) then
                    failure = { code = code, price = price, provider = provider.id }
                end
            elseif ok and BeatsFailure("neverseen", nil, failure) then
                failure = { code = "neverseen" }
            end
        end
    end
    if best then
        local source = { id = bestProvider.id, label = ProviderLabel(bestProvider) }
        return best, source, considered
    end
    if not sessionPriced and not AnyHasData(available) then
        return nil, { code = "noscan" }
    end
    return nil, failure or { code = "neverseen" }
end

--- The best usable price of the available providers.
-- @param itemID number
-- @param link string|nil
-- @return table|nil price, the table GetPrice returned
-- @return table source { id, label }; or, when the price is nil, the reason
--   { code, price, provider } with code stale, notinscan, neverseen, noscan or
--   noprovider
-- @return table|nil considered usable prices that competed, when a price won
function Prices.Best(itemID, link)
    local ordered, available = EnterLists()
    local usable = AvailableProviders(ordered, available)
    local price, extra, considered = Choose(itemID, link, usable)
    LeaveLists()
    return price, extra, considered
end

--- True when requireLastScan is on, a provider is available and none of the
--- available providers honours it.
-- @treturn boolean
function Prices.LastScanIgnored()
    if not Settings().requireLastScan then
        return false
    end
    local ordered, available = EnterLists()
    AvailableProviders(ordered, available)
    local ignored = #available > 0 and not HonouringOnly(available)
    LeaveLists()
    return ignored
end

--- One entry per registered provider in providerOrder.
-- @treturn table list of { id, label, available, seen, newestAgeDays, error }
function Prices.Status()
    local list = {}
    local ordered = EnterLists()
    for _, provider in ipairs(Ordered(ordered)) do
        local state = states[provider.id]
        list[#list + 1] = {
            id = provider.id,
            label = ProviderLabel(provider),
            available = IsAvailable(provider),
            seen = state.seen,
            newestAgeDays = state.newestAgeDays,
            error = state.error,
        }
    end
    LeaveLists()
    return list
end

Events.Register("PLAYER_LOGIN", function()
    loggedIn = true
    HookProviders()
end)

-- A provider whose addon loads after login becomes available then (technical
-- findings 14, Registering). The provider table carries no addon name, so
-- IsAvailable is asked again.
Events.Register("ADDON_LOADED", function()
    if loggedIn then
        HookProviders()
    end
end)
