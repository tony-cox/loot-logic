--[[
The stats of an item link and whether it has an effect that is not scored
(spec 8.1; technical findings 7.1, 8.1 and 14.1). Both are read once per link
and kept for the session in memory only: no stat is saved (spec 6).
]]

local _, ns = ...

local Stats = {}
ns.Stats = Stats

local ItemMods = ns.ItemMods
local L = ns.L
local Log = ns.Log
local Util = ns.Util

local STAT_FORMAT_PREFIX = "^TOOLTIP_ITEM_STAT_"

-- Link -> { stats, effect }. stats is filled by Stats.Get, effect (true or
-- false) by Stats.HasUnscoredEffect, each when first read.
local cache = {}
local loggedKeys = {}
-- The TOOLTIP_ITEM_STAT_* formats as patterns, built on first use.
local statPatterns

local function NoteUnknownKey(key)
    if loggedKeys[key] or not Log.IsDebugOn() then
        return
    end
    loggedKeys[key] = true
    Log.Debug("stats", string.format(L.statsUnknownKey, tostring(key)))
end

--- The canonical stats of a link, as { [canonicalKey] = value }, for example
--- { CRIT = 20, STA = 12 } (the keys are those of Data/ItemMods.lua; the
--- weapon's damage per second is "DPS", scored by hand in Scoring). Returns an
--- empty table for an item with no stats and nil while the game gives none
--- (item data not loaded) or a value is secret; nil is not remembered. A key
--- the map does not know is ignored and written once per key and session to
--- the debug log. C_Item.GetItemStats exists on Forever (source-read); that it
--- returns nil for an item not loaded yet, and the key names, are from memory
--- (live check L4; fallback: tooltip parsing).
-- @param link string
-- @treturn table|nil
function Stats.Get(link)
    local entry = cache[link]
    if entry and entry.stats then
        return entry.stats
    end
    local raw = C_Item.GetItemStats(link)
    if raw == nil or Util.IsSecret(raw) then
        return nil
    end
    local stats = {}
    for key, value in pairs(raw) do
        if Util.IsSecret(key) or Util.IsSecret(value) then
            return nil
        end
        local canonical = ItemMods[key]
        if canonical then
            stats[canonical] = (stats[canonical] or 0) + value
        else
            NoteUnknownKey(key)
        end
    end
    if not entry then
        entry = {}
        cache[link] = entry
    end
    entry.stats = stats
    return stats
end

-- The client formats as anchored patterns, each number a wildcard.
local function StatPatterns()
    if statPatterns then
        return statPatterns
    end
    statPatterns = {}
    for name, format in pairs(_G) do
        if type(name) == "string" and string.find(name, STAT_FORMAT_PREFIX) then
            if type(format) == "string" then
                statPatterns[#statPatterns + 1] = Util.FormatPattern(format)
            end
        end
    end
    return statPatterns
end

local function StartsWith(text, prefix)
    return type(prefix) == "string" and string.sub(text, 1, #prefix) == prefix
end

-- True when the text, without a leading "Equip:", is one of the stat formats.
-- Whether the formats include the "Equip:" prefix is not known, so the whole
-- line is tried too (live check L56).
local function IsStatLine(text, prefix)
    local rest = string.match(string.sub(text, #prefix + 1), "^%s*(.-)%s*$")
    for _, pattern in ipairs(StatPatterns()) do
        if string.find(rest, pattern) or string.find(text, pattern) then
            return true
        end
    end
    return false
end

-- True when the line is an effect that is not scored. A set bonus line ("Set:
-- ...") starts with none of the three prefixes, so it never counts. With no
-- stat format strings to compare against, an "Equip:" line cannot be told from
-- a stat and is not counted (live check L56; fallback: only "Use:" and "Chance
-- on hit:" lines count, and when those prefixes are missing too the suffix is
-- dropped).
local function IsEffectLine(text)
    if
        StartsWith(text, ITEM_SPELL_TRIGGER_ONUSE) or StartsWith(text, ITEM_SPELL_TRIGGER_ONPROC)
    then
        return true
    end
    if StartsWith(text, ITEM_SPELL_TRIGGER_ONEQUIP) and #StatPatterns() > 0 then
        return not IsStatLine(text, ITEM_SPELL_TRIGGER_ONEQUIP)
    end
    return false
end

--- Whether the item has an effect that is not one of its stats: a line of its
--- tooltip that starts with "Use:" or "Chance on hit:", or with "Equip:" and
--- matches none of the stat formats (technical findings 7.1). Returns nil, and
--- remembers nothing, while the game gives no tooltip or a line is secret.
--- C_TooltipInfo.GetHyperlink(link).lines is source-read on Forever; the
--- leftText field, "Use:" and "Chance on hit:" (the ITEM_SPELL_TRIGGER_* global
--- strings) are from memory (live check L56).
-- @param link string
-- @treturn boolean|nil
function Stats.HasUnscoredEffect(link)
    local entry = cache[link]
    if entry and entry.effect ~= nil then
        return entry.effect
    end
    local data = C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then
        return nil
    end
    local effect = false
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if Util.IsSecret(text) then
            return nil
        end
        if type(text) == "string" and IsEffectLine(text) then
            effect = true
            break
        end
    end
    if not entry then
        entry = {}
        cache[link] = entry
    end
    entry.effect = effect
    return effect
end
