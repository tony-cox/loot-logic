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
L.typeQualified = "%s: %s"

-- Classification reasons (spec 7.6).
L.reasonWanted = "wants %s"
L.reasonWantedhere = "wanted by you: %s"
L.reasonQuest = "quest item, key or token"
L.reasonNevertouch = "always kept"
L.reasonProtected = "on the Protect list"
L.reasonInset = "in set %s"
L.reasonTool = "profession tool"
L.reasonNovalue = "no vendor value"
L.reasonClassstay = "kept by the class setting"
L.reasonNoprovider = "no price addon"
L.reasonNoscan = "no AH price yet: scan"
L.reasonNeverseen = "never seen on the AH"
L.reasonStale = "price %s old, max %d; was %s each (%s)"
L.reasonNotinscan = "not in the last scan"
L.reasonAh = "%s each, +%s over vendor after the %d%% cut; %s, %s"
L.reasonVendor = "AH gain below threshold; sells for %s each"
L.reasonVendorbound = "bound, sells for %s each"
L.reasonGrey = "grey item, sells for %s each"
L.reasonBelowthreshold = "AH gain below threshold, no vendor value"
L.reasonNobody = "nobody wants this (not in your bags)"
L.reasonError = "error on an item, see /ll status."
L.reasonInuse = "best %s %s owned"
L.reasonNospec = "no gear advice for %s in this build"
L.reasonEquipat = "equip at level %d"
L.reasonEmptySlot = "%s, empty %s slot"
L.reasonEquip = "+%s%% %s over %s"
L.reasonGearfor = "+%s%% %s over %s"
L.reasonRunner = "; %s +%s%%"
L.reasonPair = "%s and %s"
L.reasonPairLocated = "%s, and %s"
L.reasonItemLocation = "%s, %s"
L.reasonMainHand = " (main hand)"
L.reasonOffHand = " (off hand)"
L.reasonRunnerEmpty = "; %s, empty %s slot"
L.reasonAtLevel = "; at level %d"
L.reasonAssumed = " (assumed)"
L.reasonIlvl = " (ilvl)"
L.reasonLoadout = " (%s)"
L.reasonRefundable = "; refundable"
L.reasonNoVendorValue = "; no vendor value"
L.reasonNotInBags = "; not in your bags"
L.reasonEffect = "; effect not scored"
L.reasonTrain = "; train %s first"
L.skillDualWield = "Dual Wield"
L.reasonBetter = "; a better %s %s is %s"
L.reasonAgeDays = "%d d"
L.reasonAgeOver = "over 21 d"
L.reasonWhereWorn = "worn"
L.reasonWhereBags = "bags"
L.reasonWhereBank = "bank"
L.reasonWhereMail = "mail"
L.reasonBetterBags = "in your bags"
L.reasonBetterBank = "in your bank"
L.reasonBetterMail = "in your mail"

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

-- Debug log lines of Engine/ (technical findings 15, Debug log): the price
-- notice (provider id, results made stale), an unknown ITEM_MOD_* key, and the
-- item-data batch (the one line that replaces the per-event lines).
L.pricesStale = "%s: new data, %d cached results made stale"
L.statsUnknownKey = "unknown stat key %s, ignored"
L.itemsLoadedOne = "1 item loaded"
L.itemsLoadedMany = "%d items loaded"

-- The debug "classify" line of one full pass: items classified, milliseconds.
L.classifyPass = "%s: %d items in %.1f ms"
