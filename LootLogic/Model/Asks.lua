--[[
Wants (the saved table keeps the name asks): want matching (spec 7.3) and the
edits of a character's type flags and item entries (spec 6 and 13). Matching
takes the item's facts as an argument and looks up nothing in the game. A
read-only session writes nothing and refuses (spec 6, Notes: Migrations).
Names of characters come from Roster.lua; typed text is parsed in M1.
]]

local _, ns = ...

local Asks = {}
ns.Asks = Asks

local DB = ns.DB
local Generations = ns.Generations
local Roster = ns.Roster

-- The item class of recipes (spec 7.3 step 5, spec 10).
local CLASS_RECIPE = 9

-- True when the type flag is set and the quality reaches its minimum (a flag
-- with no minimum matches any quality).
local function FlagMatches(flag, quality)
    if not flag then
        return false
    end
    local minimum
    if type(flag) == "table" then
        minimum = flag.minQuality
    end
    return not minimum or quality >= minimum
end

-- Step 3 of spec 7.3: the exact type or the whole class; with two flags it is
-- a match if either matches.
local function TypeMatches(types, facts)
    local exact = string.format("%d:%d", facts.class, facts.subclass)
    local whole = string.format("%d:*", facts.class)
    return FlagMatches(types[exact], facts.quality) or FlagMatches(types[whole], facts.quality)
end

-- The asks table of an editable character, created with its two tables when
-- missing, or nil and the reason for a refusal.
local function Editable(key)
    if DB.IsReadOnly() then
        return nil, "readonly"
    end
    local entry = DB.Data().characters[key]
    if not entry then
        return nil, "unknown"
    end
    if type(entry.asks) ~= "table" then
        entry.asks = {}
    end
    if type(entry.asks.types) ~= "table" then
        entry.asks.types = {}
    end
    if type(entry.asks.items) ~= "table" then
        entry.asks.items = {}
    end
    return entry.asks
end

--- Whether the character's wants match an item, in the order of spec 7.3: an
--- item exclude, an item include (whatever the quality), a type flag or whole
--- class flag with its minimum quality, the class restriction, and a recipe the
--- current character already knows. A character with no wants never matches.
-- @param key string character key
-- @param facts table item facts: itemID, class, subclass, quality, and when
-- they apply classRestriction (a set of class tokens, nil or empty when the
-- item names no class) and knownHere (true for a class 9 item the current
-- character already knows)
-- @treturn boolean
function Asks.Matches(key, facts)
    local entry = DB.Data().characters[key]
    if type(entry) ~= "table" or type(entry.asks) ~= "table" then
        return false
    end
    local asks = entry.asks
    local setting
    if type(asks.items) == "table" then
        setting = asks.items[facts.itemID]
    end
    if setting == "exclude" then
        return false
    end
    if setting == "include" then
        return true
    end
    if type(asks.types) ~= "table" or not TypeMatches(asks.types, facts) then
        return false
    end
    local restriction = facts.classRestriction
    if restriction and next(restriction) ~= nil and not restriction[entry.class] then
        return false
    end
    -- LootLogic knows what the current character has learned only (spec 10).
    if facts.class == CLASS_RECIPE and facts.knownHere and Roster.IsHere(key) then
        return false
    end
    return true
end

--- Which want made Asks.Matches true, in the order the reason names them (spec
--- 7.6, words in reasons): "item" for an include, "subclass" for a type flag,
--- "class" for a whole-class flag. Meant for a character that matches; nil when
--- no flag applies.
-- @param key string character key
-- @param facts table as for Asks.Matches
-- @treturn string|nil
function Asks.MatchKind(key, facts)
    local entry = DB.Data().characters[key]
    if type(entry) ~= "table" or type(entry.asks) ~= "table" then
        return nil
    end
    local asks = entry.asks
    if type(asks.items) == "table" and asks.items[facts.itemID] == "include" then
        return "item"
    end
    if type(asks.types) ~= "table" then
        return nil
    end
    local exact = string.format("%d:%d", facts.class, facts.subclass)
    if FlagMatches(asks.types[exact], facts.quality) then
        return "subclass"
    end
    if FlagMatches(asks.types[string.format("%d:*", facts.class)], facts.quality) then
        return "class"
    end
    return nil
end

--- The characters whose wants match an item, in the global priority order
--- (LootLogicDB.order), eligible or not: the engine picks among them (spec 7.2
--- step 4).
-- @param facts table as for Asks.Matches
-- @treturn table list of character keys
function Asks.Wanters(facts)
    local wanters = {}
    for _, key in ipairs(DB.Data().order) do
        if Asks.Matches(key, facts) then
            wanters[#wanters + 1] = key
        end
    end
    return wanters
end

--- Turns a type flag on, or clears it ("off" means clear, spec 13). "on"
--- keeps a flag that is already set as it is, minimum quality included. The
--- minimum quality stays "any" in M1, so a new flag is an empty table. Bumps
--- asks on a change.
-- @param key string character key
-- @param typeKey string "class:subclass" or "class:*", as numbers
-- @param setting string "on", "off" or "clear"
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown"
function Asks.SetType(key, typeKey, setting)
    local asks, reason = Editable(key)
    if not asks then
        return nil, reason
    end
    local types = asks.types
    if setting == "on" then
        if types[typeKey] then
            return "unchanged"
        end
        types[typeKey] = {}
    else
        if not types[typeKey] then
            return "unchanged"
        end
        types[typeKey] = nil
    end
    Generations.Bump("asks")
    return "changed"
end

--- Includes or excludes an item, or clears its entry (spec 13: "on" includes
--- the item even if its type is off, "off" excludes it even if its type is
--- on). Bumps asks on a change.
-- @param key string character key
-- @param itemID number
-- @param setting string "include", "exclude" or "clear"
-- @treturn string|nil "changed" or "unchanged"; nil after a refusal
-- @treturn string|nil "readonly" or "unknown"
function Asks.SetItem(key, itemID, setting)
    local asks, reason = Editable(key)
    if not asks then
        return nil, reason
    end
    local wanted = nil
    if setting ~= "clear" then
        wanted = setting
    end
    if asks.items[itemID] == wanted then
        return "unchanged"
    end
    asks.items[itemID] = wanted
    Generations.Bump("asks")
    return "changed"
end
