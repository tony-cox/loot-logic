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

-- Debug log lines (technical findings 15, Debug log): the imported-set
-- snapshots (sets, items) and the known-recipe cache clearing (the event).
L.snapshotSetsEquipment = "imported sets, Equipment Manager: sets %d, items %d"
L.snapshotSetsOutfitter = "imported sets, Outfitter: sets %d, items %d"
L.recipesCleared = "known-recipe cache cleared by %s"

-- Debug log lines of Model/Snapshot.lua (technical findings 15, Debug log).
L.snapshotGear = "gear: %d links"
L.snapshotProficiency = "proficiency: %d spells known"
L.snapshotBags = "bags: %d gear links, %d item IDs"
L.snapshotBank = "bank: %d gear links, %d item IDs"
L.snapshotInbox = "inbox: %d gear links, %d item IDs"
L.logoutCounts = "equipped slots with a link: %d, bag slots holding an item: %d"
L.mailNoAttachments = "no attachments"
L.mailCaptured = "SendMail to %s: %s"
L.mailSentStranger = "MAIL_SEND_SUCCESS: %s is not on the roster, nothing recorded"
L.mailInboundAdded = "MAIL_SEND_SUCCESS: inbound entry added for %s: %s x%d"
L.mailFailed = "MAIL_FAILED: capture dropped"
L.mailClearedSeen = "inbound entry cleared, seen in the inbox: item %s x%s"
L.mailClearedOld = "inbound entry cleared, older than 30 days: item %s x%s"
