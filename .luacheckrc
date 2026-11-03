-- Written by hand for LootLogic. The WoW names are the ones the addon code and
-- tests/stubs/Wow.lua use; keep the list in step with the stub.
std = "lua51"
max_line_length = 100
max_comment_line_length = 80

-- The saved variable named in the TOC. Globals.lua adds the addon's other
-- globals in M1.
globals = {
    "LootLogicDB",
}

read_globals = {
    "ATTACHMENTS_MAX_RECEIVE",
    "ATTACHMENTS_MAX_SEND",
    "AuctionDB",
    "C_AddOns",
    "C_Container",
    "C_EquipmentSet",
    "C_Item",
    "C_Timer",
    "C_TooltipInfo",
    "CreateFrame",
    "Enum",
    "EquipmentManager_UnpackLocation",
    "GetBuildInfo",
    "GetInboxItem",
    "GetInboxItemLink",
    "GetInboxNumItems",
    "GetInventoryItemLink",
    "GetRealmName",
    "GetSendMailItem",
    "GetSendMailItemLink",
    "GetServerTime",
    "GetTime",
    "ITEM_CLASSES_ALLOWED",
    "ITEM_SET_BONUS",
    "ITEM_SPELL_KNOWN",
    "ITEM_SPELL_TRIGGER_ONEQUIP",
    "ITEM_SPELL_TRIGGER_ONPROC",
    "ITEM_SPELL_TRIGGER_ONUSE",
    "ITEM_UNIQUE",
    "ITEM_UNIQUE_EQUIPPABLE",
    "IsPlayerSpell",
    "ItemLocation",
    "LOCALIZED_CLASS_NAMES_FEMALE",
    "LOCALIZED_CLASS_NAMES_MALE",
    "Outfitter",
    "TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE",
    "TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE",
    "TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE",
    "UnitClass",
    "UnitFactionGroup",
    "UnitLevel",
    "UnitName",
    "UnitRace",
    "date",
    "gOutfitter_GlobalSettings",
    "hooksecurefunc",
    "issecretvalue",
    "strsplit",
    "strtrim",
    "time",
    "wipe",
}

-- Addon code may not reach os (the stub clock must be the only time source:
-- read GetServerTime), io or module loading (from memory, absent on the
-- client). Tests and the runner may.
files["LootLogic/"] = {
    not_globals = { "os", "io", "require", "package", "module", "loadfile", "dofile" },
}

-- The tests read the client names above and the chat frame the stub captures.
files["tests/"] = {
    read_globals = {
        "DEFAULT_CHAT_FRAME",
        "SendMail",
    },
}

-- The vendor price tests set the AuctionDB global that AHDB would create.
files["tests/TestVendor.lua"] = {
    globals = { "AuctionDB" },
}

-- The stub defines the client names, so it may assign them.
files["tests/stubs/Wow.lua"] = {
    globals = {
        "ATTACHMENTS_MAX_RECEIVE",
        "ATTACHMENTS_MAX_SEND",
        "C_AddOns",
        "C_Container",
        "C_EquipmentSet",
        "C_Item",
        "C_Timer",
        "C_TooltipInfo",
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "Enum",
        "EquipmentManager_UnpackLocation",
        "GetBuildInfo",
        "GetInboxItem",
        "GetInboxItemLink",
        "GetInboxNumItems",
        "GetInventoryItemLink",
        "GetRealmName",
        "GetSendMailItem",
        "GetSendMailItemLink",
        "GetServerTime",
        "GetTime",
        "ITEM_CLASSES_ALLOWED",
        "ITEM_SET_BONUS",
        "ITEM_SPELL_KNOWN",
        "ITEM_SPELL_TRIGGER_ONEQUIP",
        "ITEM_SPELL_TRIGGER_ONPROC",
        "ITEM_SPELL_TRIGGER_ONUSE",
        "ITEM_UNIQUE",
        "ITEM_UNIQUE_EQUIPPABLE",
        "IsPlayerSpell",
        "ItemLocation",
        "LOCALIZED_CLASS_NAMES_FEMALE",
        "LOCALIZED_CLASS_NAMES_MALE",
        "Outfitter",
        "SendMail",
        "TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE",
        "TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE",
        "TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE",
        "UnitClass",
        "UnitFactionGroup",
        "UnitLevel",
        "UnitName",
        "UnitRace",
        "date",
        "gOutfitter_GlobalSettings",
        "hooksecurefunc",
        "issecretvalue",
        "print",
        "strsplit",
        "strtrim",
        "time",
        "wipe",
    },
}
