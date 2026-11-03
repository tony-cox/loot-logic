--[[
The known-recipe check for the current character (spec 10; technical findings
10): whether a recipe or class book shows the "Already known" tooltip line. The
answer is remembered for the session and forgotten when the character learns a
recipe or a spell. Which items it is asked about (class 9) is the caller's
choice.
]]

local _, ns = ...

local Recipes = {}
ns.Recipes = Recipes

local Events = ns.Events
local Generations = ns.Generations
local L = ns.L
local Log = ns.Log
local Util = ns.Util

-- itemID -> true or false, for the session.
local cache = {}

--- Whether the current character already knows the recipe or book: its tooltip
--- has the line ITEM_SPELL_KNOWN ("Already known"). The tooltip lines come
--- from C_TooltipInfo.GetHyperlink(link).lines, each with leftText (the call
--- is source-read on Forever, technical findings 7.1; the field name is from
--- memory; the ITEM_SPELL_KNOWN line is from memory; live check L23). Returns
--- nil, and remembers nothing, when the game gives no tooltip yet or the text
--- is a secret value.
-- @param link string item link
-- @treturn boolean|nil
function Recipes.KnownHere(link)
    local itemID = Util.ParseLink(link)
    if itemID and cache[itemID] ~= nil then
        return cache[itemID]
    end
    -- A client without the global string cannot tell: not known, which routes
    -- as wanted (spec 1, Recipes), and nothing is remembered.
    if type(ITEM_SPELL_KNOWN) ~= "string" then
        return false
    end
    local data = C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then
        return nil
    end
    local known = false
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if Util.IsSecret(text) then
            return nil
        end
        if text and string.find(text, ITEM_SPELL_KNOWN, 1, true) then
            known = true
            break
        end
    end
    if itemID then
        cache[itemID] = known
    end
    return known
end

-- Forgets every answer, bumps asks and writes the debug line with the event
-- (technical findings 15).
local function Clear(event)
    wipe(cache)
    Generations.Bump("asks")
    Log.Debug("recipes", string.format(L.recipesCleared, event))
end

-- All three events are from memory (live check L23; fallback: rescan on
-- BAG_UPDATE_DELAYED).
Events.Register("NEW_RECIPE_LEARNED", Clear)
Events.Register("LEARNED_SPELL_IN_SKILL_LINE", Clear)
Events.Register("SPELLS_CHANGED", Clear)
