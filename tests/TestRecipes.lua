local _, ns, h = ...

local Generations = ns.Generations
local Recipes = ns.Recipes

local RECIPE = "|cffffffff|Hitem:2598:0:0:0:0:0:0:0:60|h[Pattern: Red Linen Bag]|h|r"
local BOOK = "|cffffffff|Hitem:3334:0:0:0:0:0:0:0:60|h[Recipe: Something]|h|r"

local function Boot()
    LootLogicDB = nil
    h.Stub.FireEvent("ADDON_LOADED", "LootLogic")
end

return {
    ["Recipes: the Already known line means known"] = function()
        h.Stub.SetTooltipLines(
            RECIPE,
            { "Pattern: Red Linen Bag", "Already known", "Requires Tailoring" }
        )
        h.Equal(Recipes.KnownHere(RECIPE), true, "known")
    end,

    ["Recipes: a tooltip without the line means not known"] = function()
        h.Stub.SetTooltipLines(BOOK, { "Recipe: Something", "Requires Cooking" })
        h.Equal(Recipes.KnownHere(BOOK), false, "not known")
    end,

    ["Recipes: no tooltip yet gives nil and remembers nothing"] = function()
        h.Nil(Recipes.KnownHere(RECIPE), "no data")
        h.Stub.SetTooltipLines(RECIPE, { "Already known" })
        h.Equal(Recipes.KnownHere(RECIPE), true, "once the tooltip exists")
    end,

    ["Recipes: a secret line gives nil and remembers nothing"] = function()
        local secret = h.Stub.MakeSecret()
        h.Stub.SetTooltipLines(RECIPE, { secret })
        h.Nil(Recipes.KnownHere(RECIPE), "secret")
        h.Stub.SetTooltipLines(RECIPE, { "Already known" })
        h.Equal(Recipes.KnownHere(RECIPE), true, "later")
    end,

    ["Recipes: the answer is remembered for the session"] = function()
        h.Stub.SetTooltipLines(RECIPE, { "Already known" })
        Recipes.KnownHere(RECIPE)
        h.Stub.SetTooltipLines(RECIPE, { "Not known now" })
        h.Equal(Recipes.KnownHere(RECIPE), true, "remembered")
        h.Equal(h.Stub.TooltipCalls(), 1, "tooltip read once")
    end,

    ["Recipes: each of the three events clears the cache, bumps asks and logs it"] = function()
        Boot()
        LootLogicDB.debug.enabled = true
        for index, event in ipairs({
            "NEW_RECIPE_LEARNED",
            "LEARNED_SPELL_IN_SKILL_LINE",
            "SPELLS_CHANGED",
        }) do
            local recipe = string.format("|Hitem:%d:0:0:0:0:0:0:0:60|h[R]|h", 5000 + index)
            h.Stub.SetTooltipLines(recipe, { "Requires Tailoring" })
            h.Equal(Recipes.KnownHere(recipe), false, event .. ": not known")
            h.Stub.SetTooltipLines(recipe, { "Already known" })
            h.Equal(Recipes.KnownHere(recipe), false, event .. ": cached")
            h.Stub.FireEvent(event)
            h.Equal(Recipes.KnownHere(recipe), true, event .. ": read again")
            h.Equal(Generations.Get("asks"), index, event .. ": asks")
            local log = LootLogicDB.debug.log
            h.True(
                string.find(log[#log], "recipes: known-recipe cache cleared by " .. event, 1, true),
                event .. ": debug line: " .. log[#log]
            )
        end
    end,

    ["Recipes: without the global string a recipe counts as not known, uncached"] = function()
        h.Stub.SetTooltipLines(RECIPE, { "Already known" })
        h.Stub.SetItemSpellKnown(nil)
        h.Equal(Recipes.KnownHere(RECIPE), false, "no string")
        h.Equal(h.Stub.TooltipCalls(), 0, "no tooltip read")
        h.Stub.SetItemSpellKnown("Already known")
        h.Equal(Recipes.KnownHere(RECIPE), true, "string back")
    end,

    ["Recipes: the cache is per item"] = function()
        h.Stub.SetTooltipLines(RECIPE, { "Already known" })
        h.Stub.SetTooltipLines(BOOK, { "Recipe: Something" })
        h.Equal(Recipes.KnownHere(RECIPE), true, "recipe")
        h.Equal(Recipes.KnownHere(BOOK), false, "book")
    end,
}
