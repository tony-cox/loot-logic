--[[
The proficiency spell IDs to query and the class tables (technical findings
14.1 and 5; spec 8.3). What a character knows now is read from the game with
IsPlayerSpell; this file holds only what the game cannot say.
]]

local _, ns = ...

local Proficiency = {}
ns.Proficiency = Proficiency

-- Armour, shield and Dual Wield spells and the weapon skill spells (game data
-- dump, source-read; read per character with IsPlayerSpell, from memory, L6).
Proficiency.spells = {
    cloth = 9078,
    leather = 9077,
    mail = 8737,
    plate = 750,
    shield = 9116,
    dualWield = 674,
    oneHandedAxes = 196,
    twoHandedAxes = 197,
    bows = 264,
    guns = 266,
    oneHandedMaces = 198,
    twoHandedMaces = 199,
    polearms = 200,
    oneHandedSwords = 201,
    twoHandedSwords = 202,
    staves = 227,
    fistWeapons = 15590,
    daggers = 1180,
    thrown = 2567,
    crossbows = 5011,
    wands = 5009,
}

-- Item class:subclass -> proficiency spell (from memory; L6, and L8 for the
-- subclass numbers). Weapon subclasses 9 and 17 have no entry until L8 says
-- what they hold.
Proficiency.subclassSpell = {
    ["2:0"] = 196,
    ["2:1"] = 197,
    ["2:2"] = 264,
    ["2:3"] = 266,
    ["2:4"] = 198,
    ["2:5"] = 199,
    ["2:6"] = 200,
    ["2:7"] = 201,
    ["2:8"] = 202,
    ["2:10"] = 227,
    ["2:13"] = 15590,
    ["2:15"] = 1180,
    ["2:16"] = 2567,
    ["2:18"] = 5011,
    ["2:19"] = 5009,
    ["4:1"] = 9078,
    ["4:2"] = 9077,
    ["4:3"] = 8737,
    ["4:4"] = 750,
    ["4:6"] = 9116,
}

-- Classic baseline, unverified for Forever. From memory of the Classic
-- trainers: no live check covers the training levels (L6 checks the spells and
-- L8 the subclass numbers). Each value is the level at which the class can use
-- the type (1 = from the start), keyed like subclassSpell; dualWield = <level>
-- only where the class has the skill. Spec 8.3 uses the table for the level
-- look-ahead and for a type not yet trained.
Proficiency.classes = {
    WARRIOR = {
        armor = { ["4:1"] = 1, ["4:2"] = 1, ["4:3"] = 1, ["4:4"] = 40, ["4:6"] = 1 },
        weapons = {
            ["2:0"] = 1,
            ["2:1"] = 1,
            ["2:2"] = 1,
            ["2:3"] = 1,
            ["2:4"] = 1,
            ["2:5"] = 1,
            ["2:6"] = 1,
            ["2:7"] = 1,
            ["2:8"] = 1,
            ["2:10"] = 1,
            ["2:13"] = 10,
            ["2:15"] = 1,
            ["2:16"] = 1,
            ["2:18"] = 1,
        },
        dualWield = 20,
    },
    PALADIN = {
        armor = { ["4:1"] = 1, ["4:2"] = 1, ["4:3"] = 1, ["4:4"] = 40, ["4:6"] = 1 },
        weapons = {
            ["2:0"] = 1,
            ["2:1"] = 1,
            ["2:4"] = 1,
            ["2:5"] = 1,
            ["2:6"] = 1,
            ["2:7"] = 1,
            ["2:8"] = 1,
        },
    },
    HUNTER = {
        armor = { ["4:1"] = 1, ["4:2"] = 1, ["4:3"] = 40 },
        weapons = {
            ["2:0"] = 1,
            ["2:1"] = 1,
            ["2:2"] = 1,
            ["2:3"] = 1,
            ["2:6"] = 1,
            ["2:7"] = 1,
            ["2:8"] = 1,
            ["2:10"] = 1,
            ["2:13"] = 1,
            ["2:15"] = 1,
            ["2:16"] = 1,
            ["2:18"] = 1,
        },
        dualWield = 20,
    },
    ROGUE = {
        armor = { ["4:1"] = 1, ["4:2"] = 1 },
        weapons = {
            ["2:2"] = 1,
            ["2:3"] = 1,
            ["2:4"] = 1,
            ["2:7"] = 1,
            ["2:13"] = 1,
            ["2:15"] = 1,
            ["2:16"] = 1,
            ["2:18"] = 1,
        },
        dualWield = 1,
    },
    PRIEST = {
        armor = { ["4:1"] = 1 },
        weapons = { ["2:4"] = 1, ["2:10"] = 1, ["2:15"] = 1, ["2:19"] = 1 },
    },
    SHAMAN = {
        armor = { ["4:1"] = 1, ["4:2"] = 1, ["4:3"] = 40, ["4:6"] = 1 },
        weapons = {
            ["2:0"] = 1,
            ["2:1"] = 1,
            ["2:4"] = 1,
            ["2:5"] = 1,
            ["2:10"] = 1,
            ["2:13"] = 1,
            ["2:15"] = 1,
        },
    },
    MAGE = {
        armor = { ["4:1"] = 1 },
        weapons = { ["2:7"] = 1, ["2:10"] = 1, ["2:15"] = 1, ["2:19"] = 1 },
    },
    WARLOCK = {
        armor = { ["4:1"] = 1 },
        weapons = { ["2:7"] = 1, ["2:10"] = 1, ["2:15"] = 1, ["2:19"] = 1 },
    },
    DRUID = {
        armor = { ["4:1"] = 1, ["4:2"] = 1 },
        weapons = {
            ["2:4"] = 1,
            ["2:5"] = 1,
            ["2:6"] = 1,
            ["2:10"] = 1,
            ["2:13"] = 1,
            ["2:15"] = 1,
        },
    },
}
