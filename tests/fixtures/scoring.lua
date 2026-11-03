-- Test-only weights and character snapshots (technical findings 17.1).
return {
    weights = {
        ["DRUID:cat"] = { weights = { AGI = 2, STR = 1, DPS_MH = 3, DPS_OH = 1,
            DPS_RANGED = 4 }, percent = {} },
        ["DRUID:restoration"] = { weights = { INT = 2, HEAL = 1 }, percent = {} },
        ["PALADIN:holy"] = { weights = { INT = 2, HEAL = 1, HIT = 10, CRIT = 14,
            HASTE = 10, DODGE = 12, PARRY = 15, BLOCK = 5 },
            percent = { "HIT", "CRIT", "HASTE", "DODGE", "PARRY", "BLOCK" } },
    },
    characters = {
        druid = { class = "DRUID", level = 60, proficiency = { spells = { [9077] = true } },
            loadouts = { { name = "Bear", spec = "DRUID:bear", worn = true },
                { name = "Cat", spec = "DRUID:cat" },
                { name = "Restoration", spec = "DRUID:restoration", armor = "any" } } },
        paladin = { class = "PALADIN", level = 60, proficiency = { spells = { [750] = true } },
            loadouts = { { name = "Protection", spec = "PALADIN:protection", worn = true },
                { name = "Holy", spec = "PALADIN:holy" } } },
        warlock = { class = "WARLOCK", level = 60, proficiency = { spells = { [9078] = true } },
            loadouts = { { name = "Affliction", spec = "WARLOCK:affliction", worn = true } } },
        shaman = { class = "SHAMAN", level = 60, proficiency = { spells = { [8737] = true } },
            loadouts = { { name = "Enhancement", spec = "SHAMAN:enhancement", worn = true } } },
        mage = { class = "MAGE", level = 60, loadouts = { { name = "Mage", worn = true } } },
    },
}
