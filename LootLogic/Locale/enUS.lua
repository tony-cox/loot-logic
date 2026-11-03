--[[
English strings. Every player-facing text lives in ns.L; a missing key shows its
own name instead of raising an error (technical findings 14, Locale table).
]]

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

ns.L = L

-- Chat prefixes (technical findings 15, Debug log; docs/ux.md 6).
L.chatPrefix = "LootLogic:"
L.debugPrefix = "LootLogic debug:"

-- The engine error chat line, without the prefix (docs/ux.md 6).
L.errorEngine = "error on an item, see /ll status."

-- The saved-data notices, without the prefix (technical findings 14).
L.dataNewer = "saved data is newer than this version and is left unchanged."
L.dataNotUpgraded = "saved data could not be upgraded and is left unchanged."

-- The provider error chat lines, without the prefix (docs/ux.md 6): the
-- provider's label, the error text and the label of the provider still used.
L.providerFailedUsing = "%s failed (%s); using %s."
L.providerFailedNone = "%s failed (%s); no prices until it works."

-- The Errors entry for a second provider with a registered id (technical
-- findings 14, Registering).
L.providerDuplicate = "provider id %s is already registered; the second is ignored."

-- Money parts (technical findings 14, Locale table).
L.moneyGold = "%dg"
L.moneySilver = "%ds"
L.moneyCopper = "%dc"

-- Slot words used in reasons (spec 7.6; technical findings 14.1).
L.slotHead = "head"
L.slotNeck = "neck"
L.slotShoulder = "shoulder"
L.slotBack = "back"
L.slotChest = "chest"
L.slotWrist = "wrist"
L.slotHands = "hands"
L.slotWaist = "waist"
L.slotLegs = "legs"
L.slotFeet = "feet"
L.slotFinger = "ring"
L.slotTrinket = "trinket"
L.slotRanged = "ranged"
L.slotMainHand = "main-hand weapon"
L.slotOffHand = "off-hand"
L.slotTwoHand = "two-hander"
