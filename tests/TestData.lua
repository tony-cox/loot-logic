local _, ns, h = ...

-- The canonical stat keys of spec 8.1 (RES_<school> is checked by prefix).
local CANONICAL = {}
for key in
    string.gmatch(
        "STR AGI STA INT SPI ARMOR AP RAP SP SPDMG HEAL HIT CRIT HASTE MP5 HP5 DEF DODGE "
            .. "PARRY BLOCK BLOCKVALUE BONUSARMOR EXPERTISE SPELLPIERCING DPS_MH DPS_OH "
            .. "DPS_RANGED SP_ARCANE SP_FIRE SP_FROST SP_HOLY SP_NATURE SP_SHADOW",
        "%S+"
    )
do
    CANONICAL[key] = true
end

local function isCanonical(key)
    return CANONICAL[key] == true or string.find(key, "^RES_%u+$") ~= nil
end

local function count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

return {
    ["every ItemMods value is a canonical key or DPS"] = function()
        local n = 0
        for modKey, value in pairs(ns.ItemMods) do
            n = n + 1
            h.True(value == "DPS" or isCanonical(value), modKey .. " maps to " .. tostring(value))
        end
        h.True(n > 0, "ItemMods is not empty")
    end,

    ["ItemMods holds the five source-read keys"] = function()
        local mods = ns.ItemMods
        h.Equal(mods.ITEM_MOD_CRIT_RATING_SHORT, "CRIT", "crit")
        h.Equal(mods.ITEM_MOD_HIT_RATING_SHORT, "HIT", "hit")
        h.Equal(mods.ITEM_MOD_SPELL_POWER_SHORT, "SP", "spell power")
        h.Equal(mods.ITEM_MOD_MANA_REGENERATION_SHORT, "MP5", "mp5")
        h.Equal(mods.ITEM_MOD_DAMAGE_PER_SECOND_SHORT, "DPS", "dps")
    end,

    ["every INVTYPE of the slot table has its group"] = function()
        local expected = {
            HEAD = "head",
            NECK = "neck",
            SHOULDER = "shoulder",
            CLOAK = "back",
            CHEST = "chest",
            ROBE = "chest",
            WRIST = "wrist",
            HAND = "hands",
            WAIST = "waist",
            LEGS = "legs",
            FEET = "feet",
            FINGER = "finger",
            TRINKET = "trinket",
            RANGED = "ranged",
            RANGEDRIGHT = "ranged",
            THROWN = "ranged",
            RELIC = "ranged",
            WEAPON = "mainHand",
            WEAPONMAINHAND = "mainHand",
            WEAPONOFFHAND = "offHand",
            SHIELD = "offHand",
            HOLDABLE = "offHand",
            ["2HWEAPON"] = "twoHand",
        }
        local n = 0
        for invType, group in pairs(expected) do
            n = n + 1
            h.Equal(ns.Slots.invTypeGroup["INVTYPE_" .. invType], group, invType)
        end
        h.Equal(count(ns.Slots.invTypeGroup), n, "no extra INVTYPE")
        h.Equal(ns.Slots.alsoGroup.INVTYPE_WEAPON, "offHand", "dual wield group")
        h.Equal(ns.Slots.slotCount.finger, 2, "two ring slots")
        h.Equal(ns.Slots.slotCount.trinket, 2, "two trinket slots")
    end,

    ["every group has its slot word"] = function()
        local words = {
            head = "head",
            neck = "neck",
            shoulder = "shoulder",
            back = "back",
            chest = "chest",
            wrist = "wrist",
            hands = "hands",
            waist = "waist",
            legs = "legs",
            feet = "feet",
            finger = "ring",
            trinket = "trinket",
            ranged = "ranged",
            mainHand = "main-hand weapon",
            offHand = "off-hand",
            twoHand = "two-hander",
        }
        h.Equal(#ns.Slots.groups, 16, "group count")
        for _, group in ipairs(ns.Slots.groups) do
            h.Equal(ns.Slots.Word(group), words[group], group)
        end
        for _, group in pairs(ns.Slots.invTypeGroup) do
            h.True(words[group] ~= nil, "group " .. group .. " is listed")
        end
    end,

    ["the armour slots and the bag ranges"] = function()
        h.DeepEqual(
            ns.Slots.armorGroups,
            { "head", "shoulder", "chest", "wrist", "hands", "waist", "legs", "feet" },
            "armour slot groups"
        )
        h.DeepEqual(ns.Slots.bags, { first = 0, last = 5 }, "bags")
        h.DeepEqual(ns.Slots.bankTabs, { first = 6, last = 14 }, "bank tabs")
    end,

    ["dispositions equal the technical findings table"] = function()
        h.DeepEqual(ns.ItemClasses.dispositions, {
            ["0"] = "stay",
            ["1"] = "stay",
            ["2"] = "sell",
            ["4"] = "sell",
            ["5"] = "stay",
            ["6"] = "stay",
            ["7"] = "sell",
            ["9"] = "sell",
            ["11"] = "stay",
            ["12"] = "stay",
            ["13"] = "stay",
            ["18"] = "stay",
            ["15:0"] = "sell",
            ["15:1"] = "stay",
            ["15:2"] = "stay",
            ["15:3"] = "stay",
            ["15:4"] = "stay",
            ["15:5"] = "stay",
        }, "dispositions")
    end,

    ["the Hearthstone is never touched and tables name a profession"] = function()
        h.True(ns.ItemClasses.neverTouch[6948], "Hearthstone")
        h.Equal(count(ns.ItemClasses.neverTouch), 1, "only the Hearthstone")
        for itemID, profession in pairs(ns.ItemClasses.tools) do
            h.Equal(type(itemID), "number", "tool item ID")
            h.Equal(type(profession), "string", "tool profession")
        end
        h.Equal(ns.ItemClasses.tools[2901], "Mining", "Mining Pick")
        h.Equal(ns.ItemClasses.tools[7005], "Skinning", "Skinning Knife")
    end,

    ["subclassSpell equals the technical findings table"] = function()
        h.DeepEqual(ns.Proficiency.subclassSpell, {
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
        }, "subclassSpell")
        h.Nil(ns.Proficiency.subclassSpell["2:9"], "no entry for 2:9")
        h.Nil(ns.Proficiency.subclassSpell["2:17"], "no entry for 2:17")
    end,

    ["the proficiency spells include the armour, shield, Dual Wield and weapon spells"] = function()
        local spells = ns.Proficiency.spells
        h.Equal(spells.cloth, 9078, "cloth")
        h.Equal(spells.leather, 9077, "leather")
        h.Equal(spells.mail, 8737, "mail")
        h.Equal(spells.plate, 750, "plate")
        h.Equal(spells.shield, 9116, "shield")
        h.Equal(spells.dualWield, 674, "dual wield")
        -- Every spell of subclassSpell is also in spells.
        local known = {}
        for _, id in pairs(spells) do
            known[id] = true
        end
        for key, id in pairs(ns.Proficiency.subclassSpell) do
            h.True(known[id], key .. " spell " .. id .. " is in spells")
        end
    end,

    ["the class tables cover the nine classes with valid keys and levels"] = function()
        local classes = ns.Proficiency.classes
        h.Equal(count(classes), 9, "class count")
        for _, class in ipairs({
            "WARRIOR",
            "PALADIN",
            "HUNTER",
            "ROGUE",
            "PRIEST",
            "SHAMAN",
            "MAGE",
            "WARLOCK",
            "DRUID",
        }) do
            local row = classes[class]
            h.True(row ~= nil, class .. " has a row")
            for key, level in pairs(row.armor) do
                h.True(string.find(key, "^4:%d+$") ~= nil, class .. " armour key " .. key)
                h.True(ns.Proficiency.subclassSpell[key] ~= nil, class .. " " .. key .. " spell")
                h.True(level >= 1 and level <= 60, class .. " armour level")
            end
            for key, level in pairs(row.weapons) do
                h.True(string.find(key, "^2:%d+$") ~= nil, class .. " weapon key " .. key)
                h.True(ns.Proficiency.subclassSpell[key] ~= nil, class .. " " .. key .. " spell")
                h.True(level >= 1 and level <= 60, class .. " weapon level")
            end
            h.True(row.dualWield == nil or row.dualWield >= 1, class .. " dual wield level")
        end
        h.Equal(classes.ROGUE.dualWield, 1, "rogue dual wields from the start")
        h.Equal(classes.SHAMAN.armor["4:3"], 40, "shaman mail at 40")
        h.Equal(classes.PALADIN.armor["4:4"], 40, "paladin plate at 40")
        h.Nil(classes.MAGE.dualWield, "mage has no Dual Wield")
        h.Nil(classes.SHAMAN.dualWield, "shaman has no Dual Wield")
    end,

    ["Specs has 28 rows with the listed suffixes per class"] = function()
        local suffixes = {
            WARRIOR = { "arms", "fury", "protection" },
            PALADIN = { "holy", "protection", "retribution" },
            HUNTER = { "beastmastery", "marksmanship", "survival" },
            ROGUE = { "assassination", "combat", "subtlety" },
            PRIEST = { "discipline", "holy", "shadow" },
            SHAMAN = { "elemental", "enhancement", "restoration" },
            MAGE = { "arcane", "fire", "frost" },
            WARLOCK = { "affliction", "demonology", "destruction" },
            DRUID = { "balance", "bear", "cat", "restoration" },
        }
        h.Equal(count(ns.Specs), 28, "row count")
        for class, list in pairs(suffixes) do
            for _, suffix in ipairs(list) do
                local row = ns.Specs[class .. ":" .. suffix]
                h.True(row ~= nil, class .. ":" .. suffix .. " exists")
                h.Equal(row.class, class, class .. ":" .. suffix .. " class")
                h.Equal(type(row.label), "string", class .. ":" .. suffix .. " label")
            end
        end
        for id, row in pairs(ns.Specs) do
            h.Equal(string.sub(id, 1, #row.class + 1), row.class .. ":", id .. " prefix")
        end
        h.Equal(ns.Specs["DRUID:bear"].label, "Bear", "bear label")
        h.Equal(ns.Specs["DRUID:cat"].label, "Cat", "cat label")
    end,

    ["only the four M1 rows are assumed"] = function()
        local assumed = {}
        for id, row in pairs(ns.Specs) do
            if row.assumed then
                h.True(row.assumed == true, id .. " assumed is true")
                assumed[#assumed + 1] = id
            end
        end
        table.sort(assumed)
        h.DeepEqual(assumed, {
            "DRUID:bear",
            "PALADIN:protection",
            "SHAMAN:enhancement",
            "WARLOCK:affliction",
        }, "assumed rows")
    end,

    ["WeightTables has exactly the six M1 ids, each in Specs"] = function()
        h.Equal(count(ns.WeightTables), 6, "table count")
        for _, id in ipairs({
            "DRUID:bear",
            "PALADIN:protection",
            "PALADIN:retribution",
            "SHAMAN:enhancement",
            "WARLOCK:affliction",
        }) do
            local t = ns.WeightTables[id]
            h.True(t ~= nil, id .. " has a table")
            h.True(ns.Specs[id] ~= nil, id .. " is in Specs")
            h.Equal(t.commit, "16e85426c43340f73f4f6ddc84938d4385890ea8", id .. " commit")
            h.Equal(type(t.sim), "string", id .. " sim")
            h.Equal(type(t.inputs), "string", id .. " inputs")
            h.Equal(type(t.confidence), "string", id .. " confidence")
        end
        local resto = ns.WeightTables["DRUID:restoration"]
        h.True(resto ~= nil, "restoration has a table")
        h.True(string.find(resto.confidence, "team judgement", 1, true) ~= nil, "healer source")
    end,

    ["every weight key is canonical, every weight a number, every percent list empty"] = function()
        for id, t in pairs(ns.WeightTables) do
            h.True(count(t.weights) > 0, id .. " has weights")
            for key, value in pairs(t.weights) do
                h.True(isCanonical(key), id .. " key " .. key)
                h.Equal(type(value), "number", id .. " " .. key)
            end
            h.Equal(count(t.percent), 0, id .. " percent is empty")
        end
    end,

    ["the tank tables say they assume group tanking and the others do not"] = function()
        local weightTables = ns.WeightTables
        for _, id in ipairs({ "DRUID:bear", "PALADIN:protection" }) do
            h.True(
                string.find(weightTables[id].confidence, "assumes group tanking", 1, true) ~= nil,
                id .. " label"
            )
        end
        for _, id in ipairs({ "SHAMAN:enhancement", "WARLOCK:affliction" }) do
            h.Nil(string.find(weightTables[id].confidence, "tanking", 1, true), id .. " label")
        end
    end,

    ["weights keep the signs and values of the reports"] = function()
        local prot = ns.WeightTables["PALADIN:protection"].weights
        h.True(prot.DODGE < 0, "paladin dodge below 0")
        h.True(prot.PARRY < 0, "paladin parry below 0")
        h.Equal(prot.DODGE, -0.1754, "paladin dodge")
        h.Equal(prot.PARRY, -0.03, "paladin parry")
        h.Equal(prot.SP, prot.SPDMG, "paladin SP equals SPDMG")
        h.Equal(prot.HEAL, 0, "paladin HEAL")
        h.Equal(prot.SPELLPIERCING, 0, "paladin spell piercing")
        local bear = ns.WeightTables["DRUID:bear"].weights
        h.Equal(bear.ARMOR, 0.2095, "bear armour takes the Armor value")
        h.Equal(bear.AP, 0.2727, "bear AP")
        h.Equal(bear.SPELLPIERCING, 0, "bear spell piercing")
        local shaman = ns.WeightTables["SHAMAN:enhancement"]
        h.Equal(shaman.weights.HIT, 8.4048, "shaman hit")
        h.Equal(shaman.weights.SP, shaman.weights.SPDMG, "shaman SP")
        h.True(string.find(shaman.inputs, "-40", 1, true) ~= nil, "shaman records its hit offset")
        local warlock = ns.WeightTables["WARLOCK:affliction"].weights
        h.Equal(warlock.SP_SHADOW, 0.9009, "warlock shadow")
        h.Equal(warlock.EXPERTISE, 0, "warlock expertise not weighed")
    end,

    ["the tool list holds Flint and Tinder and the runed rods"] = function()
        local tools = ns.ItemClasses.tools
        h.Equal(tools[4471], "Cooking", "Flint and Tinder")
        for _, id in ipairs({ 6218, 6339, 11130, 11145, 16207 }) do
            h.Equal(tools[id], "Enchanting", "rod " .. id)
        end
    end,

    ["ItemMods has no feral attack power row"] = function()
        h.Nil(ns.ItemMods.ITEM_MOD_FERAL_ATTACK_POWER_SHORT, "feral attack power")
    end,

    ["weighed keys with no ItemMods source are the named known gap"] = function()
        -- D153 item 1: school power and resistances have no rows until L4.
        local knownGap = { SP_FIRE = true, SP_SHADOW = true, SP_NATURE = true, SP_HOLY = true }
        local sourced = { DPS_MH = true, DPS_OH = true, DPS_RANGED = true }
        for _, key in pairs(ns.ItemMods) do
            sourced[key] = true
        end
        for id, t in pairs(ns.WeightTables) do
            for key in pairs(t.weights) do
                h.True(sourced[key] or knownGap[key], id .. " weighs " .. key .. " with no source")
            end
        end
        for key in pairs(knownGap) do
            h.True(not sourced[key], key .. " is listed as a gap but has a source")
        end
    end,

    ["each weight table equals its report line"] = function()
        local tables = ns.WeightTables
        h.DeepEqual(tables["WARLOCK:affliction"].weights, {
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
        }, "warlock")
        h.DeepEqual(tables["SHAMAN:enhancement"].weights, {
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
        }, "shaman")
        h.DeepEqual(tables["DRUID:bear"].weights, {
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
        }, "bear")
        h.DeepEqual(tables["PALADIN:protection"].weights, {
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
        }, "paladin")
    end,

    ["the 28 spec labels"] = function()
        local labels = {}
        for id, row in pairs(ns.Specs) do
            labels[id] = row.label
        end
        h.DeepEqual(labels, {
            ["WARRIOR:arms"] = "Arms",
            ["WARRIOR:fury"] = "Fury",
            ["WARRIOR:protection"] = "Protection",
            ["PALADIN:holy"] = "Holy",
            ["PALADIN:protection"] = "Protection",
            ["PALADIN:retribution"] = "Retribution",
            ["HUNTER:beastmastery"] = "Beast Mastery",
            ["HUNTER:marksmanship"] = "Marksmanship",
            ["HUNTER:survival"] = "Survival",
            ["ROGUE:assassination"] = "Assassination",
            ["ROGUE:combat"] = "Combat",
            ["ROGUE:subtlety"] = "Subtlety",
            ["PRIEST:discipline"] = "Discipline",
            ["PRIEST:holy"] = "Holy",
            ["PRIEST:shadow"] = "Shadow",
            ["SHAMAN:elemental"] = "Elemental",
            ["SHAMAN:enhancement"] = "Enhancement",
            ["SHAMAN:restoration"] = "Restoration",
            ["MAGE:arcane"] = "Arcane",
            ["MAGE:fire"] = "Fire",
            ["MAGE:frost"] = "Frost",
            ["WARLOCK:affliction"] = "Affliction",
            ["WARLOCK:demonology"] = "Demonology",
            ["WARLOCK:destruction"] = "Destruction",
            ["DRUID:balance"] = "Balance",
            ["DRUID:bear"] = "Bear",
            ["DRUID:cat"] = "Cat",
            ["DRUID:restoration"] = "Restoration",
        }, "labels")
    end,
}
