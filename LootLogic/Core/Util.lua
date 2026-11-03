--[[
Small helpers the other files share: the money format, instance keys, the
secret-value guard, the pcall wrapper and the debounce (technical findings 14).
]]

local _, ns = ...

local Util = {}
ns.Util = Util

local L = ns.L

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

--- Writes an amount of copper as gold, silver and copper parts: "1g 2s",
--- "4g 10s", "35c". A part that is zero is left out, none is padded, and zero
--- is "0c" (technical findings 14, Locale table).
-- @param copper number a whole amount, not negative (the docs give no format
--   for a negative amount)
-- @treturn string
function Util.FormatMoney(copper)
    copper = math.floor(copper)
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local rest = copper % COPPER_PER_SILVER
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = string.format(L.moneyGold, gold)
    end
    if silver > 0 then
        parts[#parts + 1] = string.format(L.moneySilver, silver)
    end
    if rest > 0 then
        parts[#parts + 1] = string.format(L.moneyCopper, rest)
    end
    if #parts == 0 then
        return string.format(L.moneyCopper, 0)
    end
    return table.concat(parts, " ")
end

--- Reads the item ID and the suffix ID from an item link or item string. The
--- suffix is the seventh field of the item string, 0 when it is empty or absent
--- (technical findings 7.1). The colour part of the link is not read, so the
--- "|cnIQ4:...|Hitem:..." form and the classic hex form both work (from
--- memory; live check L52; fallback: fix the pattern).
-- @param link string
-- @treturn number|nil itemID, nil when the text holds no item
-- @treturn number|nil suffixID
function Util.ParseLink(link)
    local fields = string.match(link, "item:([%-%d:]*)")
    if not fields then
        return nil, nil
    end
    local itemID = tonumber(string.match(fields, "^(%d+)"))
    if not itemID then
        return nil, nil
    end
    local suffix = 0
    local index = 1
    for field in string.gmatch(fields .. ":", "([^:]*):") do
        if index == 7 then
            suffix = tonumber(field) or 0
            break
        end
        index = index + 1
    end
    return itemID, suffix
end

--- The instance key "itemID:suffixID" of a link (spec 6, Notes).
-- @param link string
-- @treturn string|nil nil when the text holds no item
function Util.InstanceKey(link)
    local itemID, suffix = Util.ParseLink(link)
    if not itemID then
        return nil
    end
    return string.format("%d:%d", itemID, suffix)
end

-- What a number placeholder of a format string matches: digits, points and
-- commas.
local NUMBER_PATTERN = "[%d%.,]+"

--- Reads a client format string (such as "Classes: %s" or "Improves hit
--- rating by %d.") as an anchored Lua pattern. A placeholder (%s, %d, %.1f,
--- %1$d) becomes a wildcard for a number, or, with `capture` true, a capture
--- of any text; "%%" is a literal percent sign and every other character
--- matches itself (technical findings 7.1, 14).
-- @param format string
-- @param capture boolean|nil true to capture the text of each placeholder
-- @treturn string
function Util.FormatPattern(format, capture)
    local wildcard = NUMBER_PATTERN
    if capture then
        wildcard = "(.+)"
    end
    local parts = { "^" }
    local position = 1
    while position <= #format do
        local char = string.sub(format, position, position)
        local spec = string.match(format, "^(%%[%d%$%.%-%+ #]*[sdif])", position)
        if char == "%" and string.sub(format, position + 1, position + 1) == "%" then
            parts[#parts + 1] = "%%"
            position = position + 2
        elseif spec then
            parts[#parts + 1] = wildcard
            position = position + #spec
        else
            if string.find(char, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
                char = "%" .. char
            end
            parts[#parts + 1] = char
            position = position + 1
        end
    end
    parts[#parts + 1] = "$"
    return table.concat(parts)
end

--- True when the client marks the value secret. issecretvalue exists on Forever
--- (source-read, technical findings 7.5; live check L25 tests secret values in
--- combat; fallback: defer classification to out of combat). False when the
--- function is missing.
-- @param value any
-- @treturn boolean
function Util.IsSecret(value)
    if not issecretvalue then
        return false
    end
    if issecretvalue(value) then
        return true
    end
    return false
end

local function PcallResult(ok, ...)
    if ok then
        return true, ...
    end
    local converted, text = pcall(tostring, (...))
    if converted then
        return false, text
    end
    return false, "(error object could not be converted to text)"
end

--- Calls fn under pcall. Returns true and what fn returned, or false and the
--- error as text.
-- @param fn function
-- @param ... any arguments for fn
-- @treturn boolean ok
-- @return what fn returned, or the error text
function Util.Pcall(fn, ...)
    return PcallResult(pcall(fn, ...))
end

--- A function that waits `seconds` after its last call, then calls fn with the
--- arguments of that last call. Each call restarts the wait.
-- C_Timer.NewTimer and its Cancel are from memory (live check L63; fallback:
-- C_Timer.After with a token the callback compares, used here when NewTimer is
-- missing).
-- @param seconds number
-- @param fn function
-- @treturn function
function Util.Debounce(seconds, fn)
    local args = {}
    local count = 0
    local timer
    local token = 0

    local function Run()
        timer = nil
        fn(unpack(args, 1, count))
    end

    local function Keep(...)
        for index = 1, math.max(count, select("#", ...)) do
            args[index] = nil
        end
        count = select("#", ...)
        for index = 1, count do
            args[index] = (select(index, ...))
        end
    end

    if C_Timer.NewTimer then
        return function(...)
            Keep(...)
            if timer then
                timer:Cancel()
            end
            timer = C_Timer.NewTimer(seconds, Run)
        end
    end
    return function(...)
        Keep(...)
        token = token + 1
        local mine = token
        C_Timer.After(seconds, function()
            if mine == token then
                Run()
            end
        end)
    end
end
