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

-- /ll probe (technical findings 18). The line forms, the statuses and the
-- wording of each SKIP reason and FAIL value are short factual texts chosen for
-- the probe; "probe done", "no event within 10 s", "call missing" and
-- "returned nothing" are the documented ones. API names stay as the client
-- spells them, in the code or in these texts.
L.probePass = "PASS"
L.probeFail = "FAIL"
L.probeSkip = "SKIP"
L.probeLine = "L%d %s %s"
L.probeManualLine = "L%d manual: %s"
L.probeManualLineM1 = "L%d manual (M1): %s"
L.probeDone = "probe done"
L.probeBusy = 'a probe is still waiting. Try again after "probe done".'
L.probeCallMissing = "call missing"
L.probeReturnedNothing = "returned nothing"
L.probeNoEvent = "no event within 10 s"
L.probeNotRun = "did not run"
L.probeNotTable = "returned %s, not a table"
L.probeNotLoaded = "item data not loaded"
L.probeSlotEmpty = "slot %d is empty"
L.probeBagEmpty = "bag %d slot %d is empty"
L.probeNoRatingKey = "no rating key: %s"
L.probeStep = "%s %s %s"
L.probeSlotStep = "slot %d"
L.probeItemStep = "%s (item %d)"
L.probeSpellPower = "spell power"
L.probeHealing = "healing"
L.probeExpertise = "expertise"
L.probeSpellPiercing = "spell piercing"
L.probeMissingFields = "missing: %s"
L.probeMissingRetry = "missing: %s. Retry with the bags open"
L.probeHeadNotRun = "head slot not run, slot 1 is empty"
L.probeHeadSlot = "head slot type %s"
L.probeNamesMissing = "no name for %s"
L.probeClassItem = "class %s subclass %s"
L.probeAuctionator = "Auctionator"
L.probeAHDB = "AHDB"
L.probeHalf = "%s %s %s"
L.probeAbsent = "not installed"
L.probeApiMissing = "API.v1 or its two functions are missing"
L.probeNoPrice = "no price for the item"
L.probeNoAge = "no age beside the price (over 21 days)"
L.probeWrongType = "another type: %s"
L.probeLastPriceMissing = "LastPrice is missing"
L.probeNoLastPrice = "no last price for the item"
L.probeWrongShape = "another shape: %s"
L.probeHouse = "house %s"
L.probeAliasAbsent = "none"
L.probeFramesFound = "all present"
L.probeNoBetterBags = "BetterBags not found"
L.probeNotFunction = "not a function: %s"
L.probeUniquenessMissing = "GetItemUniquenessByID missing"
L.probeNoWeaponSpeed = "WEAPON_SPEED or the tooltip lines are missing"
L.probeNoSpeedLine = "no line matches the speed format"
L.probeStacks = "stack sizes %s and %s"
L.probeBankClosed = "bank is closed"
L.probeBankValue = "CanUseBank gave %s"
L.probeNoTabs = "no talent tabs"
L.probeClass = "class %s"
L.probeTab = "tab %d %s %s"
L.probeMatch = "match"
L.probeNoMatch = "no match"
L.probeLinkPart = "%s %s %s"
L.probeLinkSlot = "slot %d"
L.probeLinkBag = "bag %d slot %d"
L.probeLinkOk = "ok"
L.probeLinkBad = "bad form or unreadable ID"
L.probeNoLinks = "no slot 5 link and no bag link"
L.probeCandidate = "%d %s %s %s"
L.probeChosen = "item %d %s %s %s"
L.probeNoCandidate = "no candidate item qualifies"
L.probeNoCandidateApi = "DoesItemExistByID is missing"
L.probeNoServerTime = "GetServerTime unavailable, run key recorded as unknown"
L.probeNoBuild = "GetBuildInfo unavailable, build recorded as unknown"
L.probeCandidateError = "the L58 calls raised an error"
L.probeLoaded = "item %d loaded in %.1f s, success %s"
L.probeNamesFound = "%d names found"
L.probeName = "%s %s"
L.probeFailedParts = "failed: %s"
L.probePartError = "%s (%s)"
L.probeTimerFired = "cancelled timer fired"

-- The manual list of /ll probe (technical findings 18, Output): each check's
-- Assumption column as plain text. L5 is the above-level part only.
L.probeAssumptionL1 = "C_EquipmentSet and the Equipment Manager work"
L.probeAssumptionL3 = "Region name and faction for eligibility"
L.probeAssumptionL5 = "C_PlayerInfo.CanUseItem answer for an item above the player's level"
L.probeAssumptionL11 = "Tooltip getter for bag and equipped items"
L.probeAssumptionL12 = "Mail recipient format"
L.probeAssumptionL13 = "SendMail hook and MAIL_SEND_SUCCESS"
L.probeAssumptionL14 = "Bank tabs 6 to 14"
L.probeAssumptionL16 = "BetterBags loads LootLogic's category function without a hard dependency"
L.probeAssumptionL17 = "BetterBags precedence and refresh"
L.probeAssumptionL18 = "BagBrother rules and ArkInventory rule function"
L.probeAssumptionL20 = "Rating-to-% conversion"
L.probeAssumptionL23 = '"Already known" and recipe events'
L.probeAssumptionL25 = "Secret values on item APIs in combat"
L.probeAssumptionL26 = "Mail limits"
L.probeAssumptionL27 = "AH cut"
L.probeAssumptionL29 = "Outfitter global copy"
L.probeAssumptionL30 = "ItemRack Universal data (v1.1)"
L.probeAssumptionL32 = "Data is gone at logout"
L.probeAssumptionL34 = "Baganator gets the tooltip line"
L.probeAssumptionL35 = "Performance"
L.probeAssumptionL36 = "Badge legibility"
L.probeAssumptionL37 = "Item drop and link insertion"
L.probeAssumptionL38 = "Merchant, AH and mailbox events"
L.probeAssumptionL39 = "Colour-blind CVar"
L.probeAssumptionL40 = "Bank events and tabs"
L.probeAssumptionL41 = "Window basics"
L.probeAssumptionL42 = "BetterBags section names and order"
L.probeAssumptionL43 = "Welcome dialog beside other addons"
L.probeAssumptionL44 = "A slash in a category name"
L.probeAssumptionL45 = "Minimap button"
L.probeAssumptionL46 = "Hovered item from a slash command"
L.probeAssumptionL47 = "BetterBags category callback data"
L.probeAssumptionL49 = "Inbox and mail APIs"
L.probeAssumptionL50 = "Addon compartment"
L.probeAssumptionL51 = "Class restriction line"
L.probeAssumptionL53 = "Which call shows the ruleset"
L.probeAssumptionL54 = "Specs chosen before M2"
L.probeAssumptionL55 = "Refundable purchase info"
L.probeAssumptionL56 = "Effect lines on gear tooltips (section 7.1)"
L.probeAssumptionL57 = "A link built from an instance key (section 7.1)"
L.probeAssumptionL59 =
    "Shift detail follows the key on a tooltip already shown (sections 12.2 and 13)"
L.probeAssumptionL60 = "Comparison tooltips and chat-link popups can be told from the item tooltip"
    .. " (sections 12.2 and 13)"

-- /ll in this build (technical findings 14, Slash.lua). Replaced when the help
-- list and the other commands arrive.
L.slashPlaceholder = "only /ll probe and /ll debug on|off work in this build."

-- The /ll debug replies, without the prefix (spec 13).
L.debugOn = "debug is on. Lines echo to chat and the last %s are kept in the saved data."
L.debugOff = "debug is off."
L.debugAlreadyOn = "debug is already on."
L.debugAlreadyOff = "debug is already off."
L.debugUsage = "/ll debug on|off. Example: /ll debug on"
L.debugReadOnly = "saved data is left unchanged, so debug cannot be changed."
