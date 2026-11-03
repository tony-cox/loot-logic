--[[
The spec catalogue: id ("CLASS:name"), class and display label (technical
findings 14.1; spec 8.2). The labels are the classic talent tree names (the
client's names are live check L48; fallback: rename the labels, the ids
stay). The ids, and the Bear and Cat split of Druid Feral Combat, are
LootLogic's. assumed = true marks the class's assumed spec: from M0 only the
four rows of the M1 tables carry it (spec 8.2).
]]

local _, ns = ...

ns.Specs = {
    ["WARRIOR:arms"] = { class = "WARRIOR", label = "Arms" },
    ["WARRIOR:fury"] = { class = "WARRIOR", label = "Fury" },
    ["WARRIOR:protection"] = { class = "WARRIOR", label = "Protection" },
    ["PALADIN:holy"] = { class = "PALADIN", label = "Holy" },
    ["PALADIN:protection"] = { class = "PALADIN", label = "Protection", assumed = true },
    ["PALADIN:retribution"] = { class = "PALADIN", label = "Retribution" },
    ["HUNTER:beastmastery"] = { class = "HUNTER", label = "Beast Mastery" },
    ["HUNTER:marksmanship"] = { class = "HUNTER", label = "Marksmanship" },
    ["HUNTER:survival"] = { class = "HUNTER", label = "Survival" },
    ["ROGUE:assassination"] = { class = "ROGUE", label = "Assassination" },
    ["ROGUE:combat"] = { class = "ROGUE", label = "Combat" },
    ["ROGUE:subtlety"] = { class = "ROGUE", label = "Subtlety" },
    ["PRIEST:discipline"] = { class = "PRIEST", label = "Discipline" },
    ["PRIEST:holy"] = { class = "PRIEST", label = "Holy" },
    ["PRIEST:shadow"] = { class = "PRIEST", label = "Shadow" },
    ["SHAMAN:elemental"] = { class = "SHAMAN", label = "Elemental" },
    ["SHAMAN:enhancement"] = { class = "SHAMAN", label = "Enhancement", assumed = true },
    ["SHAMAN:restoration"] = { class = "SHAMAN", label = "Restoration" },
    ["MAGE:arcane"] = { class = "MAGE", label = "Arcane" },
    ["MAGE:fire"] = { class = "MAGE", label = "Fire" },
    ["MAGE:frost"] = { class = "MAGE", label = "Frost" },
    ["WARLOCK:affliction"] = { class = "WARLOCK", label = "Affliction", assumed = true },
    ["WARLOCK:demonology"] = { class = "WARLOCK", label = "Demonology" },
    ["WARLOCK:destruction"] = { class = "WARLOCK", label = "Destruction" },
    ["DRUID:balance"] = { class = "DRUID", label = "Balance" },
    ["DRUID:bear"] = { class = "DRUID", label = "Bear", assumed = true },
    ["DRUID:cat"] = { class = "DRUID", label = "Cat" },
    ["DRUID:restoration"] = { class = "DRUID", label = "Restoration" },
}
