--[[
The M1 weight tables (spec 8.2; technical findings 14.1). Computed tables use
WoWSims Forever (MIT; notice in THIRD_PARTY_NOTICES.md). Inputs and raw results
are recorded in tools/statweights/results/m1-refresh. Restoration is team
judgement, not a simulation. All tables are unverified in game.
]]

local _, ns = ...

local SIM_COMMIT = "16e85426c43340f73f4f6ddc84938d4385890ea8"
local CONFIDENCE = "computed by the team with WoWSims Forever, unverified in game"
local TANK_CONFIDENCE =
    "computed by the team with WoWSims Forever, assumes group tanking, unverified in game"

ns.WeightTables = {
    ["WARLOCK:affliction"] = {
        sim = "ui/specs/warlock/dps",
        commit = SIM_COMMIT,
        inputs = "sm_ruin build, preraid gear, seed 101, target 0.05, spell damage reference",
        confidence = CONFIDENCE,
        weights = {
            SP = 1,
            SPDMG = 1,
            SP_SHADOW = 0.9009,
            SP_FIRE = 0.0991,
            HIT = 0.9587,
            CRIT = 0.7741,
            HASTE = 0.5187,
            SPELLPIERCING = 0.9504,
            INT = 0.3025,
            SPI = 0.0964,
            MP5 = 0.2118,
            STA = 0,
            EXPERTISE = 0,
        },
        percent = {},
    },
    ["SHAMAN:enhancement"] = {
        sim = "ui/specs/shaman/enhancement",
        commit = SIM_COMMIT,
        inputs = "testing build, hit rating offset -40, seed 101, target 0.05, "
            .. "attack power reference",
        confidence = CONFIDENCE,
        weights = {
            STR = 2.2,
            AGI = 1.7454,
            INT = 3.179,
            AP = 1,
            HIT = 8.4048,
            CRIT = 3.6346,
            HASTE = 2.9068,
            EXPERTISE = 4.3434,
            SPDMG = 2.2487,
            SP = 2.2487,
            SP_NATURE = 0.9275,
            SPELLPIERCING = 6.0788,
            DPS_MH = 14.0353,
        },
        percent = {},
    },
    ["DRUID:bear"] = {
        sim = "ui/specs/druid/feralbear",
        commit = SIM_COMMIT,
        inputs = "assembled build, placeholder gear, boss damage 6000, seed 101, "
            .. "target 0.05; 0.6 threat plus 1.15 TMI",
        confidence = TANK_CONFIDENCE,
        weights = {
            STR = 0.6,
            AGI = 0.506,
            STA = 1.1553,
            AP = 0.2727,
            HIT = 0.8459,
            CRIT = 0.4557,
            HASTE = 0.2878,
            EXPERTISE = 0.8198,
            DEF = 0.9852,
            DODGE = 0.0628,
            ARMOR = 0.2095,
            BONUSARMOR = 0.211,
            DPS_MH = 3.8182,
            SPELLPIERCING = 0,
        },
        percent = {},
    },
    ["PALADIN:protection"] = {
        sim = "ui/specs/paladin/protection",
        commit = SIM_COMMIT,
        inputs = "defaults SIML, placeholder gear, boss damage 6000, seed 101, "
            .. "target 0.05; 0.6 threat plus 1.15 TMI",
        confidence = TANK_CONFIDENCE,
        weights = {
            STR = 0.6047,
            SP = 1.3219,
            SPDMG = 1.3219,
            HEAL = 0,
            AGI = 0.6649,
            STA = 1.1484,
            AP = 0.2501,
            HIT = 2.9632,
            CRIT = 0.9925,
            HASTE = 1.0368,
            EXPERTISE = 3.1117,
            DEF = 0.3018,
            BLOCK = 1.379,
            BLOCKVALUE = 0.0904,
            DODGE = -0.1754,
            PARRY = -0.03,
            ARMOR = 0.0378,
            BONUSARMOR = 0.0378,
            DPS_MH = 3.5016,
            SPELLPIERCING = 0,
        },
        percent = {},
    },
    ["PALADIN:retribution"] = {
        sim = "ui/specs/paladin/retribution",
        commit = SIM_COMMIT,
        inputs = "defaults SIML, unsealed wrath build, default APL, hit offset -40 for hit weight, "
            .. "seed 101, target 0.05, attack power reference",
        confidence = CONFIDENCE,
        weights = {
            STR = 2.4,
            AGI = 1.7718,
            INT = 1.4653,
            AP = 1,
            SP = 1.9508,
            SPDMG = 1.9508,
            SP_HOLY = 1.6136,
            HIT = 6.8769,
            CRIT = 2.4863,
            HASTE = 3.1594,
            EXPERTISE = 5.0517,
            SPELLPIERCING = 0.4004,
            MP5 = 0.0066,
            DPS_MH = 14.2421,
        },
        percent = {},
    },
    ["DRUID:restoration"] = {
        inputs = "team judgement: healing power first, mana and throughput secondary",
        confidence = "team judgement, unverified in game",
        weights = {
            SP = 1,
            HEAL = 1,
            INT = 0.3,
            SPI = 0.2,
            MP5 = 0.5,
            CRIT = 0.2,
            HASTE = 0.5,
            STA = 0.1,
        },
        percent = {},
    },
}
