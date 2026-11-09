-- Written by hand for LootLogic. The WoW names are the ones the addon code and
-- tests/stubs/Wow.lua use; keep the list in step with the stub.
std = "lua51"
max_line_length = 100
max_comment_line_length = 80

-- The saved variable named in the TOC and the addon's own globals, which
-- Globals.lua creates (style guide 3), and the name of the one frame the client
-- must find by name (UI/Welcome.lua creates it). The BINDING_ labels join in the
-- stage that adds them.
globals = {
    "LootLogicDB",
    "LootLogic",
    "LootLogicOnCompartmentClick",
    "LootLogicWelcome",
    "SLASH_LOOTLOGIC1",
    "SLASH_LOOTLOGIC2",
}

-- SlashCmdList is the client's table: read-only except the one field the addon
-- writes.
read_globals = {
    SlashCmdList = {
        fields = {
            LOOTLOGIC = { read_only = false },
        },
    },
    "ATTACHMENTS_MAX_RECEIVE",
    "ATTACHMENTS_MAX_SEND",
    "AuctionDB",
    "Auctionator",
    "C_AddOns",
    "C_Bank",
    "C_Container",
    "C_EquipmentSet",
    "C_Item",
    "C_PlayerInfo",
    "C_Timer",
    "C_TooltipInfo",
    "C_Texture",
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
    "CreateFrame",
    "EUI_Bags",
    "Enum",
    "EquipmentManager_UnpackLocation",
    "GetBuildInfo",
    "GetCVarBool",
    "GetFileIDFromPath",
    "GetInboxItem",
    "GetInboxItemLink",
    "GetInboxNumItems",
    "GetInventoryItemLink",
    "GetNumTalentTabs",
    "GetRealmName",
    "GetSendMailItem",
    "GetSendMailItemLink",
    "GetServerTime",
    "GetTalentTabInfo",
    "GetTime",
    "GOLD_FONT_COLOR",
    "GRAY_FONT_COLOR",
    "GREEN_FONT_COLOR",
    "MAGENTA_FONT_COLOR",
    "NORMAL_FONT_COLOR",
    "ORANGE_FONT_COLOR",
    "RAID_CLASS_COLORS",
    "RED_FONT_COLOR",
    "ITEM_CLASSES_ALLOWED",
    "ITEM_SET_BONUS",
    "ITEM_SPELL_KNOWN",
    "ITEM_SPELL_TRIGGER_ONEQUIP",
    "ITEM_SPELL_TRIGGER_ONPROC",
    "ITEM_SPELL_TRIGGER_ONUSE",
    "ITEM_UNIQUE",
    "ITEM_UNIQUE_EQUIPPABLE",
    "InCombatLockdown",
    "IsPlayerSpell",
    "IsShiftKeyDown",
    "ItemLocation",
    "LOCALIZED_CLASS_NAMES_FEMALE",
    "LOCALIZED_CLASS_NAMES_MALE",
    "LibStub",
    "Outfitter",
    "TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE",
    "TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE",
    "TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE",
    "TooltipDataProcessor",
    "UIParent",
    "UISpecialFrames",
    "UnitClass",
    "UnitFactionGroup",
    "UnitLevel",
    "UnitName",
    "UnitRace",
    "WEAPON_SPEED",
    "BLUE_FONT_COLOR",
    "YELLOW_FONT_COLOR",
    "date",
    "debugprofilestop",
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

-- The classification test that covers an unsellable item sets the same global.
files["tests/TestClassifyA.lua"] = {
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
        "C_PlayerInfo",
        "C_Timer",
        "C_TooltipInfo",
        "C_Texture",
        "CreateFrame",
        "DEFAULT_CHAT_FRAME",
        "Enum",
        "EquipmentManager_UnpackLocation",
        "GetBuildInfo",
        "GetCVarBool",
        "GetFileIDFromPath",
        "GetInboxItem",
        "GetInboxItemLink",
        "GetInboxNumItems",
        "GetInventoryItemLink",
        "GetRealmName",
        "GetSendMailItem",
        "GetSendMailItemLink",
        "GetServerTime",
        "GetTime",
        "GOLD_FONT_COLOR",
        "GRAY_FONT_COLOR",
        "GREEN_FONT_COLOR",
        "MAGENTA_FONT_COLOR",
        "NORMAL_FONT_COLOR",
        "ORANGE_FONT_COLOR",
        "RAID_CLASS_COLORS",
        "RED_FONT_COLOR",
        "ITEM_CLASSES_ALLOWED",
        "ITEM_SET_BONUS",
        "ITEM_SPELL_KNOWN",
        "ITEM_SPELL_TRIGGER_ONEQUIP",
        "ITEM_SPELL_TRIGGER_ONPROC",
        "ITEM_SPELL_TRIGGER_ONUSE",
        "ITEM_UNIQUE",
        "ITEM_UNIQUE_EQUIPPABLE",
        "InCombatLockdown",
        "IsPlayerSpell",
        "ItemLocation",
        "IsShiftKeyDown",
        "LOCALIZED_CLASS_NAMES_FEMALE",
        "LOCALIZED_CLASS_NAMES_MALE",
        "Outfitter",
        "SendMail",
        "SlashCmdList",
        "TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE",
        "TOOLTIP_ITEM_STAT_HIT_PERCENT_INCREASE",
        "TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE",
        "TooltipDataProcessor",
        "UIParent",
        "UISpecialFrames",
        "UnitClass",
        "UnitFactionGroup",
        "UnitLevel",
        "UnitName",
        "UnitRace",
        "WEAPON_SPEED",
        "BLUE_FONT_COLOR",
        "YELLOW_FONT_COLOR",
        "date",
        "debugprofilestop",
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
