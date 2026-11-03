--[[
The game's ITEM_MOD_* keys from C_Item.GetItemStats mapped to the canonical
stat keys of spec 8.1 (technical findings 14.1). A key not listed here is
ignored and logged once by Engine/Stats.lua.
]]

local _, ns = ...

-- The value "DPS" is scored as DPS_MH, DPS_OH or DPS_RANGED by the hand the
-- item is judged in (spec 8.1).
local ItemMods = {
    -- The five Blizzard keys the Forever sources show (source-read; L4).
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",

    -- Every name below is from memory of the Blizzard globals, unverified for
    -- Forever (live check L4 lists the keys the client returns; fallback:
    -- tooltip parsing).
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPDMG",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "SPELLPIERCING",
    ITEM_MOD_BONUS_ARMOR_SHORT = "BONUSARMOR",
    -- No row for feral attack power (a druid-only key), spell power by school
    -- or resistances: unknown keys are ignored and logged, and L4 finds the
    -- names.
    -- Base armour is the key note of L4; the Blizzard name for it in the stats
    -- table is from memory.
    RESISTANCE0_NAME = "ARMOR",
}

ns.ItemMods = ItemMods
