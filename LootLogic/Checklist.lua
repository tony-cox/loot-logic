--[[
The setup checklist lines and the M1 status block as data (docs/ux.md 2.2 and
3.5; technical findings 14). Slash.lua prints them in M1; the window shows them
from M2. Everything is computed on each call from the saved data and the price
registry's status. Nothing is stored, no generation is bumped, and the price
choice (Prices.Best) is never called, because it marks a provider seen and may
schedule the price notice.
]]

local _, ns = ...

local Checklist = {}
ns.Checklist = Checklist

local DB = ns.DB
local L = ns.L
local Log = ns.Log
local Roster = ns.Roster
local Loadouts = ns.Loadouts
local Specs = ns.Specs
local Prices = ns.Prices

local SECONDS_PER_DAY = 86400
-- The most recent errors the status block lists.
local SHOWN_ERRORS = 5

local TAGS = {
    done = "tagDone",
    TIP = "tagTip",
    info = "tagInfo",
    NEED = "tagNeed",
}

-- A checklist row: { line, tag, text, done, counted }.
local function Row(fields)
    return fields
end

-- A name with a space is quoted so the typed command reads it as one word
-- (spec 13, command grammar).
local function Quoted(name)
    if string.find(name, "%s") then
        return '"' .. name .. '"'
    end
    return name
end

local function HereName()
    local key = Roster.HereKey()
    local name = key and (Roster.DisplayName(key) or key)
    return name or UnitName("player")
end

-- Line 2: every roster character, here included (docs/ux.md 2.2).
local function RosterRow()
    local count = #Roster.Keys()
    local text = string.format(L.checkRoster, count)
    if count == 1 then
        text = L.checkRosterOne
    end
    local done = count >= 2
    local tag = "info"
    if done then
        tag = "done"
    end
    return Row({ line = 2, tag = tag, text = text, done = done, counted = true })
end

-- Line 3: one entry per loadout that needs a word, in roster order. A loadout
-- with no spec table in this build gets the no-advice text, never a keep
-- command (docs/ux.md 2.2).
local function SpecRows()
    local rows = {}
    local names = Roster.DisplayNames()
    local hereKey = Roster.HereKey()
    for _, key in ipairs(Roster.Keys()) do
        for _, loadout in ipairs(Loadouts.List(key)) do
            local spec = Specs[loadout.spec]
            if not loadout.spec then
                rows[#rows + 1] = Row({
                    line = 3,
                    tag = "info",
                    text = string.format(L.checkSpecNoAdvice, loadout.name),
                    done = true,
                    counted = true,
                })
            elseif not (spec and Loadouts.HasWeights(loadout.spec)) then
                rows[#rows + 1] = Row({
                    line = 3,
                    tag = "info",
                    text = string.format(
                        L.checkSpecNoTable,
                        loadout.name,
                        spec and spec.label or loadout.spec
                    ),
                    done = true,
                    counted = true,
                })
            elseif loadout.assumed then
                local option = ""
                if key ~= hereKey then
                    option = string.format(L.checkSpecCharacterOption, Quoted(names[key]))
                end
                local command =
                    string.format(L.checkSpecKeepCommand, Quoted(loadout.name), spec.label, option)
                rows[#rows + 1] = Row({
                    line = 3,
                    tag = "TIP",
                    text = string.format(L.checkSpecAssumed, names[key], spec.label, command),
                    done = false,
                    counted = true,
                })
            end
        end
    end
    if #rows == 0 then
        rows[1] =
            Row({ line = 3, tag = "done", text = L.checkSpecDone, done = true, counted = true })
    end
    return rows
end

-- True for a character with a type want or an item include. An exclude alone
-- is not a want (docs/ux.md 2.2).
local function HasWant(entry)
    local asks = entry.asks
    if not asks then
        return false
    end
    for _, flag in pairs(asks.types or {}) do
        if flag then
            return true
        end
    end
    for _, mode in pairs(asks.items or {}) do
        if mode == "include" then
            return true
        end
    end
    return false
end

-- Line 4: eligible destination characters only (D218), one entry each for a
-- character with no want, in roster order.
local function WantRows()
    local rows = {}
    local names = Roster.DisplayNames()
    for _, key in ipairs(Roster.EligibleKeys()) do
        if not HasWant(Roster.Entry(key)) then
            if Roster.ReceivesGear(key) then
                rows[#rows + 1] = Row({
                    line = 4,
                    tag = "info",
                    text = string.format(L.checkWantsNothing, names[key]),
                    done = false,
                    counted = true,
                })
            else
                rows[#rows + 1] = Row({
                    line = 4,
                    tag = "info",
                    text = string.format(L.checkWantsNoGear, names[key]),
                    done = true,
                    counted = true,
                })
            end
        end
    end
    if #rows == 0 then
        rows[1] =
            Row({ line = 4, tag = "done", text = L.checkWantsDone, done = true, counted = true })
    end
    return rows
end

-- Line 5, from the registry's status only. Done when an available provider's
-- newest price is at most maxPriceAgeDays old (technical findings 11.2).
local function PriceRow()
    local maxAge = DB.Data().settings.ah.maxPriceAgeDays
    local first
    for _, status in ipairs(Prices.Status()) do
        if status.available then
            first = first or status
            if status.newestAgeDays and status.newestAgeDays <= maxAge then
                local text
                if status.newestAgeDays == 0 then
                    text = string.format(L.checkPriceToday, status.label)
                else
                    text = string.format(L.checkPriceAge, status.label, status.newestAgeDays)
                end
                return Row({ line = 5, tag = "done", text = text, done = true, counted = true })
            end
        end
    end
    local text
    if not first then
        text = L.checkPriceNone
    elseif not first.seen then
        text = string.format(L.checkPriceUnseen, first.label)
    elseif not first.newestAgeDays then
        text = string.format(L.checkPriceOver, first.label)
    else
        text = string.format(L.checkPriceStale, first.newestAgeDays)
    end
    return Row({ line = 5, tag = "TIP", text = text, done = false, counted = true })
end

local function BankRow()
    local entry = Roster.Entry(Roster.HereKey())
    if entry and entry.bank and entry.bank.updatedAt then
        return Row({ line = 7, tag = "done", text = L.checkBankSeen, done = true, counted = false })
    end
    return Row({ line = 7, tag = "info", text = L.checkBankUnseen, done = false, counted = false })
end

--- The seven checklist lines as rows, in line order. Lines 3 and 4 give one
--- row per affected character. No count and no "Setup complete" collapse in M1
--- (D213).
-- @treturn table list of { line, tag, text, done, counted }; tag is "done",
--   "TIP", "info" or "NEED"; counted is false for line 7, which is advice
function Checklist.Rows()
    local rows = {}
    local function Add(more)
        for _, row in ipairs(more) do
            rows[#rows + 1] = row
        end
    end
    Add({
        Row({
            line = 1,
            tag = "done",
            text = string.format(L.checkHere, HereName()),
            done = true,
            counted = true,
        }),
    })
    Add({ RosterRow() })
    Add(SpecRows())
    Add(WantRows())
    Add({ PriceRow() })
    Add({ Row({ line = 6, tag = "info", text = L.checkBags, done = false, counted = true }) })
    Add({ BankRow() })
    return rows
end

--- The chat form of a row: "[TIP] text".
-- @param row table a row of Checklist.Rows
-- @treturn string
function Checklist.Format(row)
    return L[TAGS[row.tag]] .. " " .. row.text
end

local function PriceStatusRows()
    local rows = {}
    for _, status in ipairs(Prices.Status()) do
        local text
        -- Only a lookup error (IsAvailable or GetPrice) skips the provider's
        -- prices; an OnUpdate error is in the Errors list only (D219).
        local lookupError = status.error
            and (status.errorMethod == "IsAvailable" or status.errorMethod == "GetPrice")
        if lookupError then
            text = string.format(L.statusPriceError, status.label, status.error)
        elseif status.available then
            if not status.seen then
                text = string.format(L.statusPriceUnseen, status.label)
            elseif not status.newestAgeDays then
                text = string.format(L.statusPriceOver, status.label)
            else
                text = string.format(L.statusPriceFound, status.label, status.newestAgeDays)
            end
        end
        if text then
            rows[#rows + 1] = { area = "prices", text = text }
        end
    end
    if #rows == 0 then
        rows[1] = { area = "prices", text = L.statusPriceNone }
    end
    if Prices.LastScanIgnored() then
        rows[#rows + 1] = { area = "prices", text = L.statusPriceLastScan }
    end
    return rows
end

-- One text per roster character, sorted by age: the current character first
-- ("now"), then the others from the most recently seen, by elapsed seconds so
-- two characters seen on the same day keep newest first (D220). One with
-- no lastSeen comes last, in roster order.
local function RosterStatusRow()
    local names = Roster.DisplayNames()
    local hereKey = Roster.HereKey()
    local staleDays = DB.Data().settings.staleDays
    local now = GetServerTime()
    local items = {}
    for index, key in ipairs(Roster.Keys()) do
        local entry = Roster.Entry(key)
        local elapsed
        if key == hereKey then
            elapsed = -math.huge
        elseif entry and type(entry.lastSeen) == "number" then
            elapsed = math.max(0, now - entry.lastSeen)
        else
            elapsed = math.huge
        end
        items[#items + 1] = { key = key, elapsed = elapsed, index = index }
    end
    table.sort(items, function(first, second)
        if first.elapsed ~= second.elapsed then
            return first.elapsed < second.elapsed
        end
        return first.index < second.index
    end)
    local texts = {}
    for _, item in ipairs(items) do
        local name = names[item.key] or item.key
        local text
        local days
        if item.elapsed >= 0 and item.elapsed < math.huge then
            days = math.floor(item.elapsed / SECONDS_PER_DAY)
        end
        if item.elapsed == -math.huge then
            text = string.format(L.statusRosterNow, name)
        elseif not days then
            text = string.format(L.statusRosterUnknown, name)
        elseif days == 0 then
            text = string.format(L.statusRosterToday, name)
        else
            text = string.format(L.statusRosterDays, name, days)
        end
        if days and days >= staleDays then
            text = text .. L.statusRosterOld
        end
        texts[#texts + 1] = text
    end
    return { area = "roster", text = string.format(L.statusRoster, table.concat(texts, ", ")) }
end

-- The error count line, then the newest SHOWN_ERRORS entries, newest first
-- (D221).
local function ErrorStatusRows()
    local rows = {}
    if Log.errorCount == 0 then
        rows[1] = { area = "errors", text = L.statusErrorsNone }
        return rows
    end
    rows[1] = { area = "errors", text = string.format(L.statusErrors, Log.errorCount) }
    local errors = Log.Errors()
    for index = #errors, math.max(1, #errors - SHOWN_ERRORS + 1), -1 do
        local item = errors[index]
        local text =
            string.format(L.statusErrorLine, date("%H:%M:%S", item.time), item.area, item.message)
        if item.count > 1 then
            text = text .. string.format(L.statusErrorRepeat, item.count)
        end
        rows[#rows + 1] = { area = "errors", text = text }
    end
    return rows
end

--- The M1 status block as rows, in spec 13's order: the price providers, the
--- adapter rows, the roster's snapshot ages, then the errors.
--- Display/Tooltip.lua loads after this file and exposes no hook state, so the
--- caller supplies the adapter rows (D214). Reads Prices.Status and
--- Prices.LastScanIgnored only.
-- @param adapterTexts table list of strings for the adapter rows
-- @treturn table list of { area, text }
function Checklist.StatusRows(adapterTexts)
    local rows = PriceStatusRows()
    for _, text in ipairs(adapterTexts) do
        rows[#rows + 1] = { area = "adapters", text = text }
    end
    rows[#rows + 1] = RosterStatusRow()
    for _, row in ipairs(ErrorStatusRows()) do
        rows[#rows + 1] = row
    end
    return rows
end
