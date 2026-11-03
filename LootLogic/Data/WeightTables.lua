--[[
The shipped weight tables (technical findings 14.1; spec 8.2): exactly the four
tables of M1, computed by the team with the WoWSims Forever sim (MIT; notice in
THIRD_PARTY_NOTICES.md). Test tables live in the test fixtures, never here.

Each value is per rating point as the sim gives it, from the reports in
tools/statweights/results/m1/ (signs kept). percent is empty: no table here
lists percent-based keys.
]]

local _, ns = ...

local SIM_COMMIT = "3e41c53fafe13bbce337e2784061edf2c5a5b97f"
local CONFIDENCE = "computed by the team with WoWSims Forever, unverified in game"
local TANK_CONFIDENCE =
    "computed by the team with WoWSims Forever, assumes group tanking, unverified in game"

ns.WeightTables = {
    -- weights-m1-report.md, "Canonical" line of Warlock Affliction.
    ["WARLOCK:affliction"] = {
        sim = "ui/specs/warlock/dps",
        commit = SIM_COMMIT,
        inputs = "build sm_ruin (talents 2550002013520105--0550205003), gear set "
            .. "preraid, target mode 0.05, seed 101, reference spell damage, no bonus stats",
        confidence = CONFIDENCE,
        weights = {
            SP = 1,
            SPDMG = 1,
            SP_SHADOW = 0.9012,
            SP_FIRE = 0.0988,
            HIT = 0.9511,
            CRIT = 0.7985,
            HASTE = 0.5009,
            SPELLPIERCING = 0.9585,
            INT = 0.2778,
            SPI = 0.1152,
            MP5 = 0.2223,
            STA = 0,
            EXPERTISE = 0,
        },
        percent = {},
    },

    -- weights-m1-report.md, "Canonical" line of Shaman Enhancement.
    ["SHAMAN:enhancement"] = {
        sim = "ui/specs/shaman/enhancement",
        commit = SIM_COMMIT,
        inputs = "build testing (talents 053303102-053030031005102251-03, carries its "
            .. "own gear), hit rating offset -40 (40 rating removed from gear at 8.2% hit, "
            .. "so below the 8% cap; the hit weight is the below-the-cap value), target mode 0.05, "
            .. "seed 101, reference attack power",
        confidence = CONFIDENCE,
        weights = {
            STR = 2.2,
            AGI = 1.6311,
            INT = 2.4863,
            AP = 1,
            HIT = 8.1082,
            CRIT = 3.4698,
            HASTE = 2.8814,
            EXPERTISE = 4.1063,
            SPDMG = 2.4209,
            SP = 2.4209,
            SP_NATURE = 0.8447,
            SPELLPIERCING = 5.9399,
            DPS_MH = 13.9924,
        },
        percent = {},
    },

    -- weights-m1-tanks-report.md, "Combined" column of Druid Bear. ARMOR takes
    -- the StatArmor value, AP the attack power value (feral attack power is
    -- identical); ArmorPenetration, PhysicalDamage and ArmorNoMods are dropped.
    ["DRUID:bear"] = {
        sim = "ui/specs/druid/feralbear",
        commit = SIM_COMMIT,
        inputs = "hand-assembled build (talents 050022-2322030212310212501-055, "
            .. "adaptive APL, the sim's dev-only level 60 placeholder gear set, "
            .. "Tauren, preset consumables, buffs and debuffs), 180 s fight with "
            .. "5 s variation, one level 63 target, minimum base damage 6000, "
            .. "armour 3731, tank Player 0, preset healing model; target mode 0.05, "
            .. "seed 101; 0.6 x threat weights (Strength = 1) + 1.15 x TMI weights "
            .. "(Stamina = 1)",
        confidence = TANK_CONFIDENCE,
        weights = {
            STR = 0.6,
            AGI = 0.4854,
            STA = 1.1426,
            AP = 0.2727,
            HIT = 0.8566,
            CRIT = 0.4673,
            HASTE = 0.2993,
            EXPERTISE = 0.8147,
            DEF = 1.0035,
            DODGE = 0.0586,
            ARMOR = 0.2031,
            BONUSARMOR = 0.2048,
            DPS_MH = 3.8182,
            SPELLPIERCING = 0,
        },
        percent = {},
    },

    -- weights-m1-tanks-report.md, "Combined" column of Paladin Protection.
    -- Dodge and parry are below 0 as measured (spec 8.2, tank tables). SP is
    -- the spell damage weight plus the healing power weight (0), so it equals
    -- SPDMG; ArmorPenetration and ArmorNoMods are dropped.
    ["PALADIN:protection"] = {
        sim = "ui/specs/paladin/protection",
        commit = SIM_COMMIT,
        inputs = "hand-assembled build (talents 050050002-05302102213301531-502, "
            .. "default APL, the sim's dev-only level 60 placeholder gear set, "
            .. "Human, preset consumables, buffs and debuffs), 180 s fight with "
            .. "5 s variation, one level 63 target, minimum base damage 6000, "
            .. "armour 3731, tank Player 0, preset healing model; target mode 0.05, "
            .. "seed 101; 0.6 x threat weights (Strength = 1) + 1.15 x TMI weights "
            .. "(Stamina = 1)",
        confidence = TANK_CONFIDENCE,
        weights = {
            STR = 0.6037,
            SP = 1.186,
            SPDMG = 1.186,
            HEAL = 0,
            AGI = 0.5949,
            STA = 1.1446,
            AP = 0.2501,
            HIT = 2.3069,
            CRIT = 0.9066,
            HASTE = 0.4331,
            EXPERTISE = 1.2691,
            DEF = 0.2992,
            BLOCK = 0.9614,
            BLOCKVALUE = 0.0782,
            DODGE = -0.1555,
            PARRY = -0.0419,
            ARMOR = 0.038,
            BONUSARMOR = 0.038,
            DPS_MH = 3.5014,
            SPELLPIERCING = 0,
        },
        percent = {},
    },
}
