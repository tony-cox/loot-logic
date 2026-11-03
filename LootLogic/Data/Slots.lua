--[[
Slot groups: the INVTYPE to group table of spec 8.4, the slot word each group
uses in reasons, the armour slot groups of bestArmorOnly and the bag ID ranges
(technical findings 8.4 and 14.1).
]]

local _, ns = ...

local L = ns.L

local Slots = {}
ns.Slots = Slots

-- The groups, in the order of spec 8.4. A ring or a trinket has two slots.
Slots.groups = {
    "head",
    "neck",
    "shoulder",
    "back",
    "chest",
    "wrist",
    "hands",
    "waist",
    "legs",
    "feet",
    "finger",
    "trinket",
    "ranged",
    "mainHand",
    "offHand",
    "twoHand",
}

Slots.slotCount = { finger = 2, trinket = 2 }

-- The client's slot-type names (the equipLoc value of GetItemInfoInstant, with
-- the INVTYPE_ prefix; technical findings 8.4 states this form. From memory,
-- unverified; live check L8).
Slots.invTypeGroup = {
    INVTYPE_HEAD = "head",
    INVTYPE_NECK = "neck",
    INVTYPE_SHOULDER = "shoulder",
    INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest",
    INVTYPE_ROBE = "chest",
    INVTYPE_WRIST = "wrist",
    INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist",
    INVTYPE_LEGS = "legs",
    INVTYPE_FEET = "feet",
    INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket",
    INVTYPE_RANGED = "ranged",
    INVTYPE_RANGEDRIGHT = "ranged",
    INVTYPE_THROWN = "ranged",
    INVTYPE_RELIC = "ranged",
    INVTYPE_WEAPON = "mainHand",
    INVTYPE_WEAPONMAINHAND = "mainHand",
    INVTYPE_WEAPONOFFHAND = "offHand",
    INVTYPE_SHIELD = "offHand",
    INVTYPE_HOLDABLE = "offHand",
    INVTYPE_2HWEAPON = "twoHand",
}

-- A one-hand weapon that fits either hand is also judged in this group when
-- the character dual wields (spec 8.4).
Slots.alsoGroup = { INVTYPE_WEAPON = "offHand" }

-- The key in ns.L of each group's slot word (spec 7.6; technical findings
-- 14.1).
Slots.wordKey = {
    head = "slotHead",
    neck = "slotNeck",
    shoulder = "slotShoulder",
    back = "slotBack",
    chest = "slotChest",
    wrist = "slotWrist",
    hands = "slotHands",
    waist = "slotWaist",
    legs = "slotLegs",
    feet = "slotFeet",
    finger = "slotFinger",
    trinket = "slotTrinket",
    ranged = "slotRanged",
    mainHand = "slotMainHand",
    offHand = "slotOffHand",
    twoHand = "slotTwoHand",
}

--- The slot word of a group ("ring" for finger, "two-hander" for twoHand).
-- @param group string one of Slots.groups
-- @treturn string
function Slots.Word(group)
    return L[Slots.wordKey[group]]
end

-- The eight slot groups of bestArmorOnly (spec 8.3); back, neck, rings,
-- trinkets, shields and off-hands are exempt.
Slots.armorGroups = {
    "head",
    "shoulder",
    "chest",
    "wrist",
    "hands",
    "waist",
    "legs",
    "feet",
}

-- Bag IDs as numbers: bags 0 to 5 (backpack and bags 0 to 4, the reagent bag
-- 5) and the bank tabs 6 to 14. These are the values of Enum.BagIndex
-- (CharacterBankTab_1 to _9) that live check L14 confirms; the file does not
-- read the Enum.
Slots.bags = { first = 0, last = 5 }
Slots.bankTabs = { first = 6, last = 14 }
