---
name: lootlogic-technical-findings
description: "LootLogic: what is known about the Forever client's APIs, other addons, file layout, events, tests and live checks. Companion to the spec; section numbers match docs/spec.md."

---

# LootLogic: technical findings

The discovery work behind `docs/spec.md`: what the Forever client and other addons provide, the file layout and data files, events, testing, and the live checks. The spec says what LootLogic does; this file says what is known about how to do it. Section numbers match the spec, so a reference such as "section 5" or "live check L3" in either document points here or there by number.

Confidence labels are as in the spec: **confirmed**, **source-read**, **from memory**, **unverified**.

---

## 5. Forever facts this design rests on

| Fact | Evidence | Confidence |
|---|---|---|
| Interface 16001, game type `camelot`. From build 70170, `WOW_PROJECT_CAMELOT = 18` and `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`; earlier builds reported `WOW_PROJECT_MAINLINE`. Retail engine and UI. | BetterBags `.claude/rules/camelot-forever.md` and commit #1117; EUI client gate; Auctionator, Questie and OutfitterForever reference `WOW_PROJECT_CAMELOT` | source-read |
| **No account (warband) bank on Forever.** `Enum.BagIndex` still declares `AccountBankTab_1..9`, but the bank does not exist. | BetterBags commit #1092 ("Confirmed out-of-band that Forever has no warbank") | source-read. Live check L33. |
| **Bank = 9 character bank tabs, bag IDs 6 to 14** (`Enum.BagIndex.CharacterBankTab_1..9`), scanned with `C_Container`. Tabs are bought one at a time (confirmed by the team in beta play), so a tab that is not bought reports no slots and is skipped. There are 9 tabs: one included, 8 purchasable (confirmed by the team in beta play). `Enum.BagIndex` has no `Bank` member (`Characterbanktab = -2`, `Keyring = -1`). Backpack bags are 0 to 4; the reagent bag is 5. | BetterBags camelot-forever.md §2 and §3; EUI Bags (reagent bag 5) | source-read |
| `C_Container.*`, `C_Item.GetItemInfo/GetItemInfoInstant/GetItemStats/IsBound/IsBoundToAccountUntilEquip/DoesItemExist/DoesItemExistByID/GetDetailedItemLevelInfo`, `ItemLocation`, `Item:CreateFromItemID` and `ContinueOnItemLoad`, the `GET_ITEM_INFO_RECEIVED`, `ITEM_DATA_LOAD_RESULT` and `BAG_UPDATE_DELAYED` events, `TooltipDataProcessor.AddTooltipPostCall`, `C_TooltipInfo.GetItemByID/GetBagItem` | Used across installed Forever addons (EUI Bags, AHDB, Auctionator, Journey Tracker) | source-read |
| `C_Item.GetItemStats(link)` returns `ITEM_MOD_*` keys including `ITEM_MOD_CRIT_RATING_SHORT`, `ITEM_MOD_HIT_RATING_SHORT`, `ITEM_MOD_SPELL_POWER_SHORT`, `ITEM_MOD_MANA_REGENERATION_SHORT` and `ITEM_MOD_DAMAGE_PER_SECOND_SHORT` | EUI `EllesmereUIBlizzardSkin_CharacterSheetForever.lua` (Forever-only file); Journey Tracker | source-read |
| Forever items carry hit and crit as **rating points**. Wowhead Forever shows crit 14 as "+1.0%" on Zandalar Augur's Hauberk [19828]. | Wowhead Forever item page, read by the team | source-read (one data point; level dependence unknown) |
| `UnitName("player")` returns **two values, first and last name** | Forever Ledger `Core.lua` `ns.FullName` | confirmed (team, beta play; L2) and source-read. Outfitter Forever reads only the first. |
| `GetSkillLineInfo` is absent or empty, so weapon and armour proficiencies cannot be read from skill lines | Beta client saved data: every skill row has the header "Professions" | confirmed (client-written data) |
| Proficiency spells exist with Classic IDs: Cloth 9078, Leather 9077, Mail 8737, Plate Mail 750, Shield 9116, Dual Wield 674. Weapon skills: One-Handed Maces 198, Two-Handed Maces 199, Staves 227, Daggers 1180, Fist Weapons 15590, Polearms 200, Bows 264, Guns 266, Crossbows 5011, Thrown 2567, Wands 5009, One-Handed Axes 196, Two-Handed Axes 197, One-Handed Swords 201, Two-Handed Swords 202. | Game data dump, build 1.60.1.70532 plus server hotfixes | source-read (data). Read per character with `IsPlayerSpell` (from memory; L6). |
| Weapon training is enforced ("missing proficiency" on an untrained mace) | Play report (beta) | confirmed |
| `C_EquipmentSet` exists, and the Equipment Manager pane exists in the paper doll | Called unguarded on every bag refresh by EUI Bags 9.6.9, by Outfitter Forever (`GetNumEquipmentSets`) and by Baganator 838. EUI BlizzardSkin hooks `PaperDollEquipmentManagerPane_Update`. | source-read (3 addons). L1. |
| At `PLAYER_LOGOUT` the client has already cleared XP, money, gear, bags, skills and completed quests | Beta client saved data and an addon comment (build 70245) | confirmed (beta) |
| AH cut: **5% at the faction AHs** (live check L27). There is no neutral AH that players can post on (team research, 2026-11-02); the 15% case appears only in the tools' code. The deposit returns with a sale. | AHDB `Sell.lua` `ADB:AuctionCut`; Forever Ledger `Auctions.lua` (a sale mail dated 2026-10-04) | source-read (two authors) |
| Some items have a vendor price in the data but merchants refuse them (Instant Poison) | AHDB `Vendor.lua` | source-read |
| One full AH scan per 15 minutes per client session, about 85K entries | AHDB `Scan.lua` notes; Forever Ledger | source-read |
| Item class/subclass IDs follow the Classic encoding (table below). Most trade goods stack to 20; Weak Flux 10; unstackables 1. | Game data dump, build 1.60.1.70532 plus hotfixes | source-read (data). L8. |
| Profession tools are **Weapon: Miscellaneous (2/14)**: Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight Spanner. Fishing poles are 2/20. Flint and Tinder is 7/11. Runed rods are 7/12 and BoP. | Game data dump | source-read (data) |
| Hearthstone [6948] is 15/0 (Junk subclass), quality 1, BoP, no sell price | Game data dump | source-read (data) |

**Item classes and subclasses in the Forever data** (game data dump, 1.60.1.70532 plus hotfixes, 24,170 items). Display names come from the client (`C_Item.GetItemClassInfo`, `GetItemSubClassInfo`); never hard-code them. The table gives examples from the data, not a list to check against: a class or subclass exists when those calls return a name for it, so `/ll want` accepts any type the client names and its error messages list the subclasses the client returns for the class (spec 13; L8 and L61 confirm).

| Class | Subclasses present (examples) |
|---|---|
| 0 Consumable | 0 explosives/devices, 1 Potion, 2 Elixir (Elixir of Wisdom), 3 Flask, 4 Scroll, 5 Food and Drink, 6 Item Enhancement, 7 Bandage, 8 Other, 14, 15 |
| 1 Container | 0 Bag, 1 Soul, 2 Herb, 3 Enchanting, 6 Mining, 7 Skinning, 11 Reagent bag (Linen Reagent Bag) |
| 2 Weapon | 0 to 10, 13 to 20. 14 Miscellaneous = profession tools; 19 Wand; 20 Fishing pole. Subclasses 9 and 17 have no entry in `subclassSpell`: L8 confirms what they hold, and each is given its spell or marked unusable. |
| 4 Armor | 0 Miscellaneous (rings, trinkets, necks, shirts), 1 Cloth, 2 Leather, 3 Mail, 4 Plate, 5 Cosmetic, 6 Shield, 7 Libram, 8 Idol, 9 Totem |
| 5 Reagent | 0 (Ankh and others) |
| 6 Projectile | 2 Arrow, 3 Bullet |
| 7 Trade Goods | 0, 1 Parts, 2 Explosives, 5 Cloth (includes thread), 6 Leather (includes Salt), 7 Metal and Stone, 8 Meat, 9 Herb, 10 Elemental, 11 Other (vials, dyes, flux, gems, fish, Flint and Tinder), 12 Enchanting (dusts, essences, rods, Mote of Magic) |
| 9 Recipe | 0 Book (class tomes), 1 Leatherworking, 2 Tailoring, 3 Engineering, 4 Blacksmithing, 5 Cooking, 6 Alchemy, 7 First Aid, 8 Enchanting, 9 Fishing |
| 11 Quiver | 2 Quiver, 3 Ammo pouch |
| 12 Quest | 0 |
| 13 Key | 0, 1 |
| 15 Miscellaneous | 0 Junk (Hearthstone too), 1 Reagent (Soul Shard, Light Feather), 2 Pet, 3 Holiday, 4 Other (crates), 5 Mount |
| 18 | WoW Token |

**Enumerating the types the client names** (the class list and subclass lists in the `/ll want` errors, and short-name matching such as `cloth` for 4:1 and 7:5; spec 13): class IDs 0 to 20 with `C_Item.GetItemClassInfo(classID)`, and for every class ID, subclass IDs 0 to 20 with `C_Item.GetItemSubClassInfo(classID, subclassID)`. Every ID with a non-nil name is kept, and the loop does not stop at the first nil, because the numbering has gaps (class 2 has no subclasses 11 and 12). Lists are printed in numeric order: classes by class ID, a class's subclasses by subclass ID. That an unused ID returns nil and that no ID above 20 is named are from memory (L61). If L61 fails, the classes and subclasses come from a built-in table of the known ones (the table above).

---

## 6. Data model

- **Character key:** `first .. " " .. last .. "-" .. GetRealmName()`. If the second `UnitName` value is missing or contains "-" (non-Forever behaviour), the first name alone is used (Forever Ledger's rule). `GetRealmName()` is expected to return the region (unverified, L3).
- **Eligibility:** `UnitFactionGroup` and `GetRealmName` give the faction and the region compared for a destination. This is the rule Forever Ledger uses for "could mail you items" (source-read; L3). The call that reveals a character's ruleset is not known (L53), so LootLogic cannot hide characters on another ruleset: mail to one is refused by the game.
- **Migrations** run at `ADDON_LOADED`. The proficiency snapshot is the `IsPlayerSpell` result for each proficiency spell.
- **Stats** are re-read through `GetItemStats`.
- **Mail recipient to roster:** match the typed "First Last" case-insensitively against roster full names in the current character's region.

---

## 7. Classification algorithm

### 7.1 Reading item facts

Read per bag slot from `C_Container.GetContainerItemInfo(bag, slot)` and the item APIs:
- From the slot: `itemID`, `hyperlink` (the link), `stackCount` (the stack), `quality`, `isBound`, `hasNoValue`, `isQuest` (`GetContainerItemQuestInfo`). The field names are live check L7; the link format the parser reads is L52.
- From `GetItemInfoInstant`: `classID`, `subclassID`, `equipLoc`.
- From `GetItemInfo`: `bindType` (field 14), `reqLevel` (field 5), `sellPrice` (field 11).
- `isAccountBound`: the account bind types, or `IsBoundToAccountUntilEquip` (live check L24).
- `classRestriction`: the tooltip "Classes:" line, matched through `ITEM_CLASSES_ALLOWED` (live check L51).
- `unique`: `C_Item.GetItemUniquenessByID` if it exists, otherwise the tooltip lines `ITEM_UNIQUE` and `ITEM_UNIQUE_EQUIPPABLE` (L21).
- `itemLevel`: `C_Item.GetDetailedItemLevelInfo` (source-read, section 5).
- `vendorPrice`: `sellPrice`, forced to 0 when `hasNoValue` or when AHDB marks the item unsellable (11.2).
- `knownHere` (class 9 only): the tooltip line `ITEM_SPELL_KNOWN`, cached as in section 10 (from memory).
- `unscoredEffect` (gear only, cached per link with the stats): from the item's tooltip lines, `C_TooltipInfo.GetHyperlink(link).lines` (the call is used by Auctionator and EllesmereUI on Forever: source-read). On Forever the client draws each item stat as an "Equip:" line from a `TOOLTIP_ITEM_STAT_<stat>_INCREASE` or `_DECREASE` format string (for example `TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE`); EllesmereUI Forever Essentials rewrites those lines by matching the same strings (source-read). A line is an effect that is not scored when it starts with `ITEM_SPELL_TRIGGER_ONUSE` ("Use:") or `ITEM_SPELL_TRIGGER_ONPROC` ("Chance on hit:") (both from memory), or starts with `ITEM_SPELL_TRIGGER_ONEQUIP` ("Equip:", source-read) and matches none of the `TOOLTIP_ITEM_STAT_*` formats, each format read as a pattern with its numbers as wildcards. Set bonus lines (`ITEM_SET_BONUS`, "Set: ...") are not counted. Live check L56.
- `holding`: the sum of `stackCount` over the slots of the container being classified (bags 0 to 5, or bank tabs 6 to 14) that hold the same itemID.

The instance key is `itemID:suffixID`: the suffix is the seventh field of the item link (`item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:...`), 0 when the item has none. Outfitter Forever stores the same pair as `Code` and `SubCode`; Auctionator's classic path keys random-suffix gear as `gr:<itemID>:<suffix>`. If Forever gives suffix variants separate item IDs (unverified), the suffix is always 0.

**A link built from an instance key** (`/ll why itemID:suffixID` when no bag stack matches, spec 13): the item string `item:<itemID>:0:0:0:0:0:<suffixID>` (the suffix in the seventh field, as above), passed to `C_Item.GetItemInfo`, whose second value is the link (from memory; nil until the item's data loads, so the result is pending as for any link). Whether a link built this way gives a random-suffix roll its stats is from memory: a roll may also need a value that its own link carries in a later field. L57 compares the stats of a built link with those of the roll's own link.

Pending items: `GetItemInfo` returns nil until the data is cached; reclassify on `ITEM_DATA_LOAD_RESULT`.

### 7.5 Edge cases

- **Random-suffix gear:** Forever appears to give suffix variants separate item IDs (Forever Ledger note, unverified). Auctionator keys Forever gear by itemID (its `ITEM_LEVEL_THRESHOLD` is 168, above every Forever item level).
- **Link-only items (no bag slot).** The tooltip getter says which case applies: `GetBagItem` for a bag item, `GetInboxItem` for a mailbox attachment (L11), a hyperlink getter for other links. Whether BetterBags' callback carries slot and bound state is live check L47. The cache keys are in section 15 (`L|link`, and `I|link` for a mailbox attachment).
- **Refundable purchases:** `C_Container.GetContainerItemPurchaseInfo` (from memory; L55).
- **Combat:** heavy recomputes wait for `PLAYER_REGEN_ENABLED`. The secret-value guard uses `issecretvalue`, which exists on Forever and is used by many Forever addons (L25).

---

## 8. Gear ranking

- **8.1 Stats.** Source: `C_Item.GetItemStats(link)`. Keys are `ITEM_MOD_*`, mapped through `Data/ItemMods.lua` (14.1). Weapon speed is not in `GetItemStats` and has no canonical key, so it is not scored (spec 8.1); should a later table weight it, it is in the tooltip line (`C_TooltipInfo.GetHyperlink`, `WEAPON_SPEED` format; L22).
- **8.2 Weights.** Each table is taken from the WoWSims Forever sim (`wowsims/forever`, folders in 14.1), or is the team's own where that is not possible (spec 8.2).
- **Spec detection.** None is designed in: the client's talent and spec APIs have not been checked for Forever (unverified), so the player picks the spec.
- **8.3 Can this character use it.** Armour: `IsPlayerSpell(9078/9077/8737/750)`. Weapons: the weapon-skill spells (section 5). `C_PlayerInfo.CanUseItem(itemID)` (retail API, from memory) for here only (L5); an untrained but trainable type counts as usable whatever it returns (spec 8.3). Backstop for here's armour type: the red "cannot use" line in the item tooltip. Shield is spell 9116 and Dual Wield 674 (section 5). A weapon subclass with no entry in `subclassSpell` needs no proficiency. Relics by class: Libram 4/7, Idol 4/8, Totem 4/9. The class restriction is the tooltip "Classes:" line (L51).
- **8.4 Slots.** Slot group from `INVTYPE`:

| Slot group | INVTYPE |
|---|---|
| head | HEAD |
| neck | NECK |
| shoulder | SHOULDER |
| back | CLOAK |
| chest | CHEST, ROBE |
| wrist | WRIST |
| hands | HAND |
| waist | WAIST |
| legs | LEGS |
| feet | FEET |
| finger (x2) | FINGER |
| trinket (x2) | TRINKET |
| ranged/relic | RANGED, RANGEDRIGHT, THROWN, RELIC |
| main hand | WEAPON, WEAPONMAINHAND |
| off hand | WEAPON (dual wield), WEAPONOFFHAND, SHIELD, HOLDABLE |
| two-hand | 2HWEAPON |


---

## 9. Loadouts and gear sets

### 9.1 What exists on Forever (research)

| Source | Forever | Storage and API | Readable from another character? |
|---|---|---|---|
| Blizzard Equipment Manager (`C_EquipmentSet`) | Exists (source-read, 3 addons; L1) | `GetEquipmentSetIDs`, `GetEquipmentSetInfo`, `GetItemIDs`, `GetItemLocations` (unverified, L1: neither gives a suffix, so the import reads the suffix from the link at the member's location when the item is worn or in the bags, and stores 0 otherwise); event `EQUIPMENT_SETS_CHANGED` (from memory, consistent with EUI and Baganator use) | No: server-side, per character. Copy at login. |
| **Outfitter Forever** v1.9.1 (MIT, installed) | Built for Forever | **Per character:** `gOutfitter_Settings` (`SavedVariablesPerCharacter`). Live `Outfitter.Settings.Outfits[categoryID] = { outfit, ... }`. Outfit items keyed by slot name: `{ Code=itemID, SubCode=suffix, UniqueID, EnchantCode, JewelCode1..4, Name, InvType, ... }`. **Events:** `Outfitter:RegisterOutfitEvent("OUTFITTER_INIT" \| "ADD_OUTFIT" \| "DELETE_OUTFIT" \| "EDIT_OUTFIT" \| "DID_RENAME_OUTFIT" \| "WEAR_OUTFIT" \| "UNWEAR_OUTFIT", fn)`. **Account-wide copies since 1.8.0:** `gOutfitter_GlobalSettings.Characters["FirstName-Realm"] = { Name, Realm, Class, ClassFile, Saved, Outfits, Count }`, saved at login and at logout or reload. Outfits stored in the Equipment Manager (`StoredInEM`) are left out of the copy. | **Yes**, through the global copy. It is keyed by **first name only**, so two characters sharing a first name collide. |
| ItemRack Universal 4.56.1 (TOC 16001, `Bl4ut0/ItemRack-Universal`) | Supports Forever (`ItemRack.IsForever()`) | `ItemRackUser.Sets[name].equip[invSlot] = "itemID:enchant:..."`, per character. Names starting with `~` are internal. Events: `ItemRack:RegisterExternalEventListener("ITEMRACK_SET_SAVED" \| "ITEMRACK_SET_DELETED", fn)`. | No |
| ItemRack Forever (CurseForge) | Page blocked (403) | Probably the same format | Unknown |
| Loadout v0.5.0 (MIT, Forever and TBC Anniversary) | Built for Forever | Source not found on GitHub; saved-variables format unknown | Unknown |
| Baganator GearSwap (AGPLv3) | TBC Classic Anniversary only | Maps bag slots to equipment slots | Not relevant |
| EllesmereUI Bags | Reads `C_EquipmentSet` only ("Split set gear by set") | | Not relevant |

**Reading another character's sets.** Outfitter keeps an account-wide copy of every character's outfits. LootLogic matches it to a roster character by first name plus region; where two characters share a first name the match is ambiguous and their sets are skipped (spec risk 6). The Equipment Manager is per character and server-side, so LootLogic copies a character's sets when it logs in. ItemRack Universal also stores sets per character.

---

## 10. Recipes and class books

The "Already known" check reads the tooltip line `ITEM_SPELL_KNOWN`. The cache is cleared on `NEW_RECIPE_LEARNED`, `LEARNED_SPELL_IN_SKILL_LINE` and `SPELLS_CHANGED` (from memory; L23).

---

## 11. Price providers

### 11.1 Research

| Provider | Forever | What it exposes (exact) | Use |
|---|---|---|---|
| **Auctionator** 341 (installed; TOC lists 16001; ModernAH path; `IsForever` constant) | Yes; beta saved data holds a full price DB (184 KB) | **Public API, documented as stable** (`Source/API/v1/README.md`). **Every call needs a non-empty string callerID ("LootLogic") or errors.**<br>`GetAuctionPriceByItemID(callerID, itemID)`: copper or nil (the minimum buyout at the last scan).<br>`GetAuctionPriceByItemLink(callerID, link)`.<br>`GetAuctionAgeByItemID(callerID, itemID)`: **days since last seen, or nil if over 21 or never**.<br>`GetVendorPriceByItemID`: its vendor cache.<br>`RegisterForDBUpdate(callerID, fn)`: fires after incremental scan processing and full scan completion.<br>All return nil while `Auctionator.Database` is not loaded. | v1 provider |
| **AHDB** v2.6.0 (`AuctionDB` folder, "WoW Forever edition", LGPLv3 in the TOC with GPLv3 text in LICENSE, installed) | Yes, built for Forever | **No documented API.** A global table `_G.AuctionDB` holds the methods (the author's comment: scan data "goes to whoever listens (e.g. add-ons on top of AHDB)").<br>`AuctionDB:LastPrice(itemID, house)`: `{ts, min, median, qty}`.<br>`AuctionDB:PlayerHouse()`: `"Horde"`, `"Alliance"` or `"Neutral"`.<br>`AuctionDB:Typical(itemID, house, days)`.<br>`AuctionDB:SellablePrice(itemID)`: nil when vendors refuse.<br>`AuctionDB:AuctionCut()`.<br>`AuctionDB:Listen("SCAN_DATA", fn)` and `AuctionDB:Listen("HISTORY_MERGED", fn)`.<br>Saved data: `AuctionDBForeverSaved.houses[house].items[itemID] = "ts,min,median,qty ts,..."` (recent scans), `.daily[itemID]` = "ts,min,median,qty,scans ..." (one point per older day, 180 days; `LastPrice` returns the last point of `items`, else of `daily`, and the fallback reader does the same, so an item in neither is `neverseen`), `.houses[house].scans = {{ts, entries, items}, ...}`. | v1 provider. Every call in `pcall`; if a method is missing, parse the saved-data string. `min` and `median` are 0 when the scan saw only bids; a point with min 0 is not a price, so the provider uses the newest earlier point with min above 0 and returns nil only when there is none. Earlier points come from the saved-data string even when `LastPrice` exists; the price then takes that point's `ts` (its age) and `inLastScan = false`. |
| TradeSkillMaster | **No.** Latest file (2026-10-14) has no 1.60.1 version. | `TSM_API.GetCustomPriceValue` | Not supported; re-check later |
| Oribos Exchange | No (retail realm data) | | No |
| Forever Ledger (MIT, 16001) | Yes | No public API (private `ns`); its own scan, and it also reads Auctionator | Later: a saved-data reader, or ask the maintainer for `ForeverLedger.API.GetPrice` |
| WoW Forever Tracker v57 | Yes | Own scan saved in `WFT_MARKET`; no API found | Later |

### 11.2 Reading prices

- **Vendor price:** `select(11, C_Item.GetItemInfo(id))`, forced to 0 when `hasNoValue` or when `AuctionDB:SellablePrice(id)` returns nil. `Prices/Vendor.lua` calls it only when the global `AuctionDB` and its `SellablePrice` exist, inside `pcall`: an error leaves the sell price standing, and a nil result is taken as unsellable (whether AHDB also returns nil for an item it never saw is unverified).
- **House:** `UnitFactionGroup("player")`, not `AuctionDB:PlayerHouse()`, which may report Neutral (unverified; L9).
- **Age:** AHDB gives it from `ts` (the current time minus `ts`). AHDB knows `inLastScan`: the item's last point `ts` equals the house's last scan `ts`. Auctionator gives whole days only and cannot say `inLastScan`, so it does not define `honoursLastScan` and `requireLastScan` is for AHDB: with the setting on and AHDB available, `Prices.Best` does not ask Auctionator; with Auctionator alone the setting is ignored and Auctionator prices are judged by age. Reading Auctionator's database to infer its latest scan is not done in v1.
- **Data present:** Auctionator's public API has no call that says whether any price data exists, so "no scan data at all" is inferred from no item classified this session having a price (spec 7.6). A price with no age (over 21 days, 11.1) counts as a price here, so its item ends `stale`, not `noscan`.
- **Newest price age** (the Status tab, `/ll status` and checklist line 5, `docs/ux.md` 2.2 and 3.5): for AHDB, the age of the house's latest scan (its `scans` list, 11.1). Auctionator has no call for it either, so its newest price age is the smallest age among the prices LootLogic has read from it this session (only items that reach step 6 read a price). With none read yet, its line is "Auctionator found, no price seen yet". When every price read from it this session has no age (over 21 days), it has no newest price age: its line is "Auctionator: price over 21 d old", and it does not make checklist line 5 done. Checklist line 5 is done when the newest price age of some provider is at most `maxPriceAgeDays`.
- **Price updates:** Auctionator `RegisterForDBUpdate`; AHDB `SCAN_DATA` and `HISTORY_MERGED` (section 15).

---

## 12. Bag addons and adapters

### 12.2 Compatibility (researched 2026-10-28)

| Addon | Forever? | Integration mechanism (exact) | Lifecycle and refresh | Status |
|---|---|---|---|---|
| **BetterBags** v0.8.9 (MIT, `Cidan/BetterBags`, very active). Forever: `BetterBags_Camelot.toc` (Interface 16001) and `core/forever.lua`. | Yes (source-read) | **Real category API** (`examples/plugin/plugin.lua`, `data/categories.lua`):<br>`local BB = LibStub("AceAddon-3.0"):GetAddon("BetterBags")`<br>`local cats = BB:GetModule("Categories")`<br>`cats:RegisterCategoryFunction("LootLogic", fn(data) -> categoryName \| nil)` (`data.itemInfo.itemID` etc.)<br>`cats:ReprocessAllItems(ctx)` with `ctx = BB:GetModule("Context"):New("LootLogic")`<br>Categories from a function are ephemeral: not saved in BetterBags' database, gone if LootLogic is disabled. | Results are **cached per itemID** until `ReprocessAllItems`, which is documented as expensive. Call it only on a classification-generation change, debounced to at most once per 2 s. Two rolls of one item ID share a category: acceptable, since gear routing is rarely split by roll. | **v1, first adapter** (about 60 lines). Section 12.5 has the evidence and risk notes. |
| **Bagnon** 12.1.7 and **Bagnonium** (formerly Combuctor), both on **BagBrother** (All Rights Reserved; TOC lists 16001) | Yes (TOC) | Rules API (BagBrother wiki): `BagBrother.Rules:Register{ id = "lootlogic_<key>", title = "Zugar", icon = <texture>, filter = function(frame, bag, slot, family, info) return ... end }`. Rules show as filters or tabs, not grouped sections. No documented item-overlay API. | Register one rule per category at login. `Rules:Unregister(id)` and register again when the roster changes. | **v1, second** (rules only, about 70 lines). Overlay is an upstream request. |
| **ArkInventory** 3.12.17 (CurseForge file lists 1.60.1; changelog: "updated toc to 1.60.01", "characters being unique across firstname+lastname"). No licence published (the GitHub repository holds docs only); treated as all rights reserved. | Yes (listing) | Rule-function plugins (documented by ArkInventoryCharacterRules):<br>`local m = ArkInventoryRules:NewModule("LootLogic"); ArkInventoryRules.Register(m, "LOOTLOGIC", fn)`<br>The current item is `ArkInventoryRules.Object` (`.class == "item"`, link in `.info.h`; bag and slot fields unverified). The player writes rules such as `lootlogic("zugar")` or `lootlogic("ah")` and assigns each to a category. | Evaluated by ArkInventory; refresh call unknown (find in game) | **v1, third** if L18 passes in time, otherwise v1.1. Needs user rule setup, so it is documented. |
| **EllesmereUI Bags** 9.6.9 (installed; Forever first-class) | Yes | `EUI_Bags.RegisterItemOverlayIcon(name, updateFn(btn, data{bag, slot, info, itemLink}))` (public; documented in `EUI_Bags_Slots.lua`). Runs for every painted slot in bags, reagent bag and bank; frames go on `btn._textOverlay`.<br>**No category API.** `EUI_CategoryManager:AssignItem` is unsuitable (account-wide, saved, keyed by itemID).<br>Refresh via `EUI_Bags:RefreshInventory()`. | Register at login if loaded | **v1 overlay** (about 40 lines), for the record |
| **Blizzard bags** (default) | Yes: retail frames `ContainerFrameCombinedBags`, `ContainerFrame1..N` (EllesmereUI references them on Forever) | No API. Post-hook each container frame's item update, then paint the overlay (a corner badge) on each item button: `hooksecurefunc(frame, "UpdateItems", fn)`, iterate the frame's item buttons, read `button:GetBagID()` and `button:GetID()` (retail pattern, from memory). | Hook once at `PLAYER_LOGIN`; repaint visible frames on our change callback | **v1** (must verify, L10) |
| **Tooltip line** (every bag addon) | Yes: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)` is used by AHDB and Auctionator on Forever | Our one line. Bag slot from `tooltip:GetPrimaryTooltipInfo().getterName == "GetBagItem"` and `getterArgs` {bag, slot} (from memory, L11); otherwise the link-only result of spec section 7.5 (a line for every result except `nobody`, which shows only with `display.tooltipNoWant`). No line on the player's equipped items (getter `GetInventoryItem`, from memory; L11).<br>**Which tooltip:** the post-call runs for every item tooltip. The main item tooltip (`GameTooltip`) and the chat-link popup (`ItemRefTooltip`) get the line; the comparison tooltips (`ShoppingTooltip1`, `ShoppingTooltip2`) do not. They are told apart by the tooltip object and its `GetPrimaryTooltipInfo()` (frame names and getters from memory; L60). If L60 finds no way to tell them apart, the line shows on every item tooltip whose owner is not a character-pane slot, comparison tooltips included.<br>**Shift detail:** added when `IsShiftKeyDown()` is true as the post-call runs. On `MODIFIER_STATE_CHANGED` for `LSHIFT` or `RSHIFT` while an item tooltip with the line is shown, the tooltip is set again from its owner, so the post-call runs again and the detail follows the key without a new hover (all from memory; L59). If L59 fails, the detail is shown only by `/ll why` (spec 13). | Every tooltip show, and a Shift press or release while one is shown | **v1** |
| **Baganator** 838 (CurseForge file 2026-10-20 lists 1.60.1; TOC `16001`; `addonTable.Constants.IsForever`). Needs **Syndicator** 285 (TOC 16001). Source: the CurseForge zip, mirrored at `github.com/austinrr/baganator-mirror`. | Yes (source-read) | `Baganator.API` has **no category API**. What exists:<br>`RegisterCornerWidget(label, id, onUpdate(cornerFrame, details), onInit(itemButton), defaultPosition, isFast)` (`details` has `itemLink`, `itemID`, `itemLocation {bagID, slotIndex}`, `isBound`)<br>`RegisterJunkPlugin(label, id, fn(bagID, slotID, itemID, itemLink))` (one active; feeds `#junk`)<br>`RegisterUpgradePlugin(label, id, fn(itemLink))` (one active; feeds `#upgrade`)<br>`RegisterItemSetSource(label, id, getItemSetInfo(location, guid, itemLink), getAllSetNames())`: set names become search keywords; the "Equipment Sets" auto category groups by the first set name<br>`RequestItemButtonsRefresh()` | | **Deferred.** v1 uses none of these. Tooltip line only, until 12.3's category API exists. |
| AdiBags | **No.** Last release 2024-09 (TOC 110002, no 1.60.1 file). | `AdiBags:RegisterFilter` (from memory) | | Not supported |
| ForeverForge Bags (Forever-only, GPLv3, needs the ForeverForge core; sections can "sell at vendor, bank, post at AH") | Yes (CurseForge page) | No integration API known | | Tooltip only; upstream request candidate |
| Sorted | Unknown (CurseForge blocked; no Forever evidence) | Unknown | | Tooltip only |
| LiteBag (GPL-2.0), Inventorian | **No** (TOCs 120105 and 120007+, retail only) | | | Not supported |
| ForeverUI, ElvUI bags | Not checked | | | Tooltip; check later |

### 12.3 Proposed Baganator hook

`Baganator.API.RegisterCategorySource(label, id, getCategoryNames() -> {{id, name, color?}}, getItemCategory(itemLocation, itemLink) -> id | nil)`. Each source appears as an auto category type beside `equipment_sets` and `tradeskillmaster`. `ComposeCategories.GetAuto` already builds attached-item groups for those two, so the change is small. Plus `Baganator.API.RequestCategoriesRefresh()`.

Other proposed hooks:
- EllesmereUI Bags: `EUI_CategoryManager:RegisterClassifier(team, fn(itemLink, itemID, bag, slot) -> categoryName | nil, opts {group = "LootLogic", priority})`, called in `ClassifyItem` after user assignments and before type matching. Plus `EUI_Bags:RequestRefresh(reason)`.
- Bagnon and BagBrother: `BagBrother.Items:RegisterOverlay(id, fn(button, bag, slot, info))`, run after each item update.
- ForeverForge Bags: `ForeverForge.Bags.RegisterSectionSource(id, getSections(), getItemSection(bag, slot))`.
- Forever Ledger: `ForeverLedger.API.GetPrice(itemID) -> copper, ageSeconds`.

Baganator's transfer button acts on the current search: `Transfers.AddToMail` at a mailbox, `Transfers.VendorItems` at a merchant. Not used (spec 23).

### 12.4 Adapter architecture

Each adapter is wrapped in `pcall`. `ReprocessAllItems` is expensive (BetterBags caches per itemID). Because BetterBags caches per item ID, its bags and bank views can show one container's result for both; the tooltip shows each container's own (spec 7.5, stacks).

### 12.5 BetterBags as the first adapter: evidence and risks

- **Downloads:** about 4.82M on CurseForge across **all** game versions (CFWidget, 2026-10-28). Forever-specific use is unknown: those files are tagged for five flavours at once, so Forever players cannot be separated out.
- **Forever support:**
  - `core/forever.lua` and `BetterBags_Camelot.toc` arrived on **2026-09-18** (PR #1092, release v0.5.7, the first CurseForge file tagged 1.60.1).
  - The build-70170 load crash was fixed on **2026-10-02** (#1117).
  - 101 of its CurseForge files are tagged 1.60.1.
  - The 2026-10-27 releases (v0.8.7 at 01:30, v0.8.8 at 02:25, v0.8.9 at 02:40 UTC) were bug fixes (Next theme text truncation, a logout Lua error), not the Forever port.
- **What the 2026-10-27 cluster does show:** a frequent release cadence (three releases on 2026-10-27). APIs may move: the old `Create*` category functions were already replaced by `CreateCategory`.
- **Forever plugin:** a separate "Betterbags - Forever" plugin exists (CurseForge `betterbags-forever`, about 7,900 downloads, created 2026-09-14, v0.3.0 on 2026-10-14). It adds Forever item categories (consumables, professions, dungeons, raids). It may compete with our categories for the same items. Precedence follows BetterBags' category priorities, to verify in game (L17).
- **Licence and source:** MIT, open repo `Cidan/BetterBags`, extensive test suite (1,016 specs per its commit notes). Upstream PRs are realistic.
- **Automation:** BetterBags has per-category automation (`AutomationOf`: "sell" or "destroy"; Auto Sell waits for confirmation in the vendor dock unless turned off). Whether a plugin's function category can carry automation is unverified (spec 23).

---

## 13. In-game UI

The three item keybindings read `GameTooltip:GetItem()` ("toggle window" toggles the window as `/ll` does); bindings are declared in `Bindings.xml`. The cursor item on the Wants item slot comes from `GetCursorInfo` (L37).

**Item IDs in commands** (`/ll want`, `/ll why`, `/ll protect`; spec 13, errors). `C_Item.DoesItemExistByID(id)` says whether the client knows the item ID, without the item's data being loaded (source-read: Auctionator's full scan, `Source_ModernAH/FullScan/Mixins/Frame.lua`, calls it on Forever to skip IDs that do not exist before requesting item data; that it answers true for a real item that is not cached is from memory, L58). false: "Item N does not exist." and nothing changes. true: the ID is accepted, and the reply names it "item N", with its name when the data is loaded. The call missing or failing (it runs in `pcall`) is the client not being able to tell: the ID is accepted the same way.

---

## 14. Module layout and TOC

```
LootLogic/                       (the addon folder, in the project repository)
  LootLogic.toc
  LICENSE, THIRD_PARTY_NOTICES.md, LICENSES/   copies of the repo-root files and folder, made when packaging, so they ship in the CurseForge zip
  Bindings.xml
  Art/Icon.tga         the TOC icon
  Locale/enUS.lua      all player-facing strings in one table, ns.L (see "Locale table" below)
  Core/Init.lua        version (the TOC's Version line, read with C_AddOns.GetAddOnMetadata; unverified, L63), constants
  Core/Util.lua        money format, keys, secret-value guard, pcall wrapper (Util.Pcall(fn, ...) returns true, then fn's values, or false and the error text), debounce
  Core/Generations.lua the cache generation counters, Generations.Bump(name), Generations.Get(name), Generations.Total() and Generations.OnBump(fn) (section 15); Core and Model code bumps them, Cache.lua reads them
  Core/Log.lua         the debug log writer, the "LootLogic:" chat line printer, the Errors list and the per-item pcall guard; text comes from ns.L; it reads and writes debug.log and debug.maxLog through the LootLogicDB global, since it loads before DB.lua
  Core/Events.lua      one event frame; Events.Register(event, handler), handlers of one event run in registration order (see section 14, Events)
  Core/DB.lua          defaults, schema migrations, the read-only state (DB.IsReadOnly()) and the saved-data accessor DB.Data()
  Data/ItemMods.lua    ITEM_MOD_* -> canonical stat keys (section 14.1)
  Data/ItemClasses.lua class/subclass default dispositions, tool item IDs, never-touch IDs (Hearthstone)
  Data/Slots.lua       INVTYPE -> slot groups, armour slots; bag IDs from Enum.BagIndex (bags 0-5, bank tabs 6-14)
  Data/Proficiency.lua proficiency spell IDs; class tables (the team's record of Classic training levels, marked unverified)
  Data/Specs.lua       the spec catalogue: id, class, label, assumed flag (section 14.1)
  Data/WeightTables.lua one shipped weight table per spec (the team's own: computed with WoWSims Forever or hand-written, section 14.1)
  Data/Templates.lua   shipped want templates (docs/ux.md 4.3)
  Data/TypeExamples.lua  example items per item type, for Wants search and the type tree
  Model/Roster.lua     character key, eligibility, order, display names
  Model/Snapshot.lua   gear, bags, bank, inbox, inbound, proficiency capture
  Model/Loadouts.lua   loadouts, worn flag, link to imported sets (v1.1: recorded items)
  Model/Sets.lua       protect lists; Equipment Manager and Outfitter membership import (v1.1: ItemRack, Loadout)
  Model/Asks.lua       want matching (the table keeps the name asks)
  Model/Recipes.lua    v1 live known-check (v1.1 store)
  Prices/Prices.lua    the provider registry, Prices.Register, Prices.Best, Prices.OnChanged, Prices.NotifyChanged, Prices.Status (11.2)
  Prices/Auctionator.lua, Prices/AHDB.lua   each registers one provider
  Prices/Vendor.lua    the vendor price (Prices.GetVendorPrice); not a registered provider
  Engine/Cache.lua     per-result caches, keyed by the generations from Generations
  Engine/Stats.lua     GetItemStats -> canonical keys, cache
  Engine/ItemFacts.lua facts from bag slot or link, pending handling
  Engine/Scoring.lua   usability, baselines per loadout spec and armour rule, upgrade test
  Engine/Classify.lua  the order in section 7.2
  Engine/Detail.lua    the detail lines for the Shift detail and /ll why (docs/ux.md)
  API.lua              the core API (spec 12.4): ns.API
  Adapters/Adapters.lua   the adapter registry, Adapters.Register; detects and starts each adapter at login, in the order of spec 12.1
  Checklist.lua        the setup checklist lines and the status block as data (docs/ux.md 2.2); /ll status prints them in M1 and UI/Status.lua shows them from M2
  Display/Tooltip.lua, Display/Overlay.lua, Display/LoginLines.lua   LoginLines prints the login chat lines (docs/ux.md 6)
  Adapters/BetterBags.lua, Adapters/BagBrother.lua, Adapters/ArkInventory.lua, Adapters/EllesmereUI.lua   each registers one adapter
  Display/BlizzardBags.lua   loads after the other adapter files and registers with Adapters.Register as the default-bag adapter (order 5 of spec 12.1)
  UI/Widgets.lua, UI/Contents.lua, UI/Characters.lua, UI/Wants.lua, UI/Weights.lua, UI/Protect.lua, UI/Settings.lua, UI/Status.lua, UI/Welcome.lua, UI/Main.lua   Main last: it looks up the tab modules; Welcome is the first-run dialog; its first button ([Show commands] in M1, [Open setup] from M2) calls the function that `Slash.lua` and `UI/Main.lua` (both below it) set on `ns.Welcome` when they load: `Welcome.onShowCommands` and `Welcome.onOpenSetup`, and a button whose callback is not set does nothing
  Probe.lua            the /ll probe checks (section 18)
  Slash.lua            command parsing and handlers, and the handlers the key bindings call (ns.Slash); after UI/ because they open the window
  Globals.lua          the only file that creates globals (the client creates LootLogicDB from the TOC, and Core/DB.lua fills it): the LootLogic table (LootLogic.API = ns.API, LootLogic.Slash = ns.Slash, which Bindings.xml calls), LootLogicOnCompartmentClick, SLASH_LOOTLOGIC1 (/ll), SLASH_LOOTLOGIC2 (/lootlogic) and SlashCmdList.LOOTLOGIC = ns.Slash.Run (it takes the typed message), the BINDING_ labels (BINDING_HEADER_LOOTLOGIC; each BINDING_NAME_LOOTLOGIC_<ACTION> is named when M2 adds Bindings.xml); wiring only
tests/                           (outside the addon folder; never shipped)
  run.py                         runs Lua 5.1 through lupa
  Harness.lua                    builds the table h (assertions, Fixture, Stub)
  stubs/Wow.lua                  fake WoW API
  fixtures/                      item facts, snapshots, provider data
  Test*.lua
```

```
## Interface: 16001
## Title: LootLogic
## Notes: Sorts bag items into destination categories (other characters, Equip, AH, Vendor, Vendor/AH) for alts.
## Author: LootLogic contributors
## X-License: MIT
## Version: @project-version@
## SavedVariables: LootLogicDB
## OptionalDeps: Auctionator, AuctionDB, BetterBags, BagBrother, Bagnon, Bagnonium, ArkInventory, EllesmereUI, EllesmereUIBags, OutfitterForever
## AddonCompartmentFunc: LootLogicOnCompartmentClick
## IconTexture: Interface\AddOns\LootLogic\Art\Icon
```

The `.lua` lines of the TOC follow the layout order exactly, top to bottom. That order is the load order, and it is a dependency order: a file looks up only modules from files above it (`local Cache = ns.Cache` at the top of `Scoring.lua` works because `Cache.lua` loads first), and no module looks up one below it. Where a lower module must tell a higher one that something changed, either the state lives in the lower module and the higher one reads it (the cache generation counters live in `Core/Generations.lua`: `Loadouts`, `Asks`, `Snapshot` and the rest call `Generations.Bump("loadouts")`, and `Cache.lua` reads them), or the higher one registers a callback (`Prices.OnChanged`). A file that needs a module below it is a layout bug: move the file or add one of these. `Locale/enUS.lua` loads first of all, so every Core file can look up `ns.L`. The TOC of a milestone lists only the files that exist at that milestone, in layout order, and each later milestone adds its files at their layout position. `tests/run.py` reads `LootLogic/LootLogic.toc`. **A file belongs to the first milestone whose contents use it.** M0 has `Locale/enUS.lua`, every `Core/` file, `Data/` except `Templates.lua` and `TypeExamples.lua`, `Model/`, `Prices/Prices.lua`, `Prices/Vendor.lua` and `Engine/Cache`, `Stats`, `ItemFacts`, `Scoring` and `Classify`. M1 adds `Engine/Detail.lua`, `API.lua`, `Checklist.lua`, `Prices/Auctionator.lua`, `Display/Tooltip.lua`, `Display/LoginLines.lua`, `UI/Widgets.lua`, `UI/Welcome.lua`, `Probe.lua`, `Slash.lua` and `Globals.lua`. M2 adds the rest (`Data/Templates.lua`, `Data/TypeExamples.lua`, `Prices/AHDB.lua`, `Adapters/`, the other `Display/` files, the other `UI/` files and `Bindings.xml`), each at its layout position. `Core/Log.lua` is whole in M0 (the `/ll debug` command is M1). Every `Model/` file is also written in M0 with the functions that M0 and M1 use (the capture functions of `Snapshot.lua` and the import functions of `Sets.lua` are tested there with the stubs); M1 and M2 only run them against the live client. The Model functions that only an M2 feature uses (forget character, the display-name override setter, class override, settings edits, templates and "Copy from") are written in M2 with that feature. `Model/Roster.lua` computes the display names (spec 6). A test belongs to the milestone of the file it tests: the Auctionator provider tests are M1's, the AHDB and adapter tests are M2's, and M0's "all offline tests" are the tests of M0 files. The non-Lua files follow the same rule: the TOC of M0 has the `## Interface`, `Title`, `Notes`, `Author`, `X-License`, `Version`, `SavedVariables` and `OptionalDeps` lines; M1 adds `## IconTexture`, `## AddonCompartmentFunc` and `Art/Icon.tga`; `LICENSE`, `THIRD_PARTY_NOTICES.md` and `LICENSES/` are copied in when packaging. The engine tests do not load `Globals.lua`; the live checks cover it (L50 for the compartment). A Forever-only addon can use a plain `.toc` with `Interface: 16001`, as AHDB does.

**Namespace keys.** Each file receives `local addonName, ns = ...` (the client supplies both). The key a file defines on `ns` is its file name without the folder and extension: `Util.lua` is `ns.Util`, `Scoring.lua` is `ns.Scoring`, `Specs.lua` is `ns.Specs`, `WeightTables.lua` is `ns.WeightTables`, `Prices/Prices.lua` is `ns.Prices`, `Adapters/Adapters.lua` is `ns.Adapters`, `UI/Weights.lua` is `ns.Weights`. The one exception is `Locale/enUS.lua`, which fills `ns.L`. There are no sub-tables: file names are unique across the addon, so the key needs no folder level, and a new file must not reuse an existing name (`Data/WeightTables.lua` and `UI/Weights.lua` differ for this reason).

A file creates its table once, at the top, as `local Scoring = {}` followed by `ns.Scoring = Scoring`, and defines its functions on it. The bare names the spec shows (`Adapter = {`, `Weights = {`) are shapes, not code. `Prices/Auctionator.lua`, `Prices/AHDB.lua` and the four adapter files define no key; they register with the module above them. `Display/BlizzardBags.lua` registers the default-bag adapter and defines no key either. `Prices/Vendor.lua` defines no key either; it adds `GetVendorPrice` to `ns.Prices`. `Globals.lua` links the `LootLogic` table's members: `LootLogic.API = ns.API` and `LootLogic.Slash = ns.Slash`.

**Events.** `Events.Register(event, handler)` adds a handler for a game event; `handler(event, ...)` receives the event name and its arguments. Any file may register for any event, at load time (the top level of the file). The handlers of one event run in registration order, which is TOC order, so the dependency order of section 14 is the run order: for `ADDON_LOADED` (LootLogic) `DB` initialises first; for `PLAYER_LOGIN` the roster entry and default loadout (`Model/`) run before `Prices` (provider `OnUpdate` calls), `Adapters` (`Detect`, `Init`) and `LoginLines` (schedules the lines); for `PLAYER_ENTERING_WORLD` the snapshot runs before the initial classification. A handler that errors is caught with `pcall` and recorded in the Errors list under the area `events` (no chat line), and the next handler still runs. `Events.Register` also works after load: `/ll debug on` registers the extra events that are only logged (section 15), and those handlers stay registered and do nothing while `debug.enabled` is false (there is no unregister). `Events.lua` writes the debug `event` line for every event it dispatches, before it calls the handlers, except `GET_ITEM_INFO_RECEIVED` and `ITEM_DATA_LOAD_RESULT`, whose one batch line ("12 items loaded", section 15) comes from the item-data handler. Arguments are written with `tostring`, separated by ", "; a table is written `<table>` and a secret value (the guard in `Util.lua`) `<secret>`.

**Errors.** `Log.Error(area, message)` adds the entry `{ time = GetServerTime(), area = <string>, message = <string>, count = <number> }` to the Errors list in memory (the list is not saved). An entry equal to the newest one in area and message adds 1 to its `count` instead of a new entry. The list keeps the last 20 entries; `Log.errorCount` counts every error this session, which is the "N this session" of `docs/ux.md`. `Log.Error` records the entry and writes the debug line `error: <area>: <message>`; it prints no chat line. **`Log.Guard(area, fn, ...)`** is the per-item guard: it runs `pcall(fn, ...)`, returns what `fn` returned on success, and on an error calls `Log.Error(area, message)` and returns nil. `Classify.lua` wraps the classification of one item in `Log.Guard("engine", ...)`, and a nil return becomes the result `{ category = "none", reasonCode = "error", reasonText = <the error text of docs/ux.md 6>, linkOnly = <true for an item with no bag slot (spec 7.5), else false> }` (spec 7.6, 12.4), so the tooltip shows the error text of `docs/ux.md` 6. `Cache` stores that result like any other, so the item is not retried until a generation it used moves. The areas are `engine` (the guard), `provider:<id>` (a provider call), `events` (a failing event handler), `prices` (a duplicate provider id, or a failing `Prices.OnChanged` callback) and `db` (a failed migration). The engine error chat line (once per session) is printed by `Log.Guard` when the area is `engine`, and the provider error chat line (once per session in total, as `docs/ux.md` 6 says) by `Prices.lua`, both through `Log.Chat(text)`. The provider line is printed only when `IsAvailable` or `GetPrice` raises (an error in `HasData` or `OnUpdate` is recorded and prints nothing), and its text names the first other provider that `Best` would ask now (in `providerOrder`, honouring `requireLastScan`), or says no prices until it works when there is none.

**Help and Welcome.** `/ll` with no argument, `/ll help` and the Welcome dialog's [Show commands] print the same list: a header line, one line per command (`L.help<Command>`: the usage, then the purpose in a few words), only for commands the build has (the M2 commands appear from M2), and the line `L.helpMultiPC` saying what `docs/ux.md` 2.3 says under "More than one PC". `/ll` with no argument then prints the checklist. The dialog's first button also closes it and sets `ui.firstRunDone`. The dialog waits until 5 seconds after `PLAYER_LOGIN` (the same moment the login chat lines print), then until the player is out of combat and none of `StaticPopup1` to `StaticPopup4` is shown, checking every 2 seconds (the `IsShown` test is from memory; live check L43).

**Classify result.** `Classify.lua` returns the result of spec 12.4. In M0 it sets `category` (`"none"` is a category), `reasonCode`, `reasonText` and `linkOnly`. `reasonText` is built from `ns.L` (the texts of spec 7.6 and 13, with the fill-in values of the reason). The rest is added in M1: `detail` by `Engine/Detail.lua`, and `label`, `color`, `icon`, `short` and `line` by `API.lua` from the palette of `docs/ux.md` 7. The M0 tests check the four fields it sets.

**Saved data.** `Core/DB.lua` fills `LootLogicDB` at `ADDON_LOADED`: it runs the migrations in order, then deep-fills the defaults (spec 6: tables merged key by key; a list is one value; a value of the wrong type is replaced by the default; unknown keys are kept). When the saved schema is newer than the code it changes nothing, `DB.IsReadOnly()` returns true for the session, and it prints once, through `Log.Chat`, "LootLogic: saved data is newer than this version and is left unchanged." While `DB.IsReadOnly()` is true, the capture functions of `Snapshot.lua` write nothing (no snapshots, no `lastSeen`). The refusal of commands that change data belongs to `Slash.lua` (M1), which checks `DB.IsReadOnly()`; the Settings tab greys its controls (`docs/ux.md` 3.8). A migration runs on a copy of the data, and the copy replaces the data only when the migration succeeds. When one fails, `DB.lua` stops, skips the default-fill, keeps the schema at the last good step, makes the session read-only like a newer schema, records `Log.Error("db", message)` and prints once "LootLogic: saved data could not be upgraded and is left unchanged." A brand-new `LootLogicDB` (nil, or not a table) runs no migration: it starts at the code's schema with the defaults. **`DB.Data()`** returns `LootLogicDB`, or, in a read-only session, a copy of it deep-filled with the defaults, built once at load and never assigned to the global; code outside `DB.lua` reads saved data through it, so a newer schema with missing tables does not raise errors (`Log.lua` reads `LootLogicDB` directly, as it loads first).

**API counters.** `Generations.Bump(name)` also adds 1 to a total, `Generations.Total()`. `Generations.OnBump(fn)` registers a listener that gets `(name)` on each bump. The names are `asks`, `gearHere`, `gearOthers`, `loadouts`, `prices`, `roster` and `settings`; `Bump` and `Get` raise an error for any other name (a code error). Listeners run inside `Bump`, each responsible for catching its own errors (`API.lua`'s wraps its body in `Log.Guard`), because `Generations.lua` loads before `Log.lua`. `API.GetGeneration()` returns `Generations.Total()`. `API.lua` registers one `OnBump` listener and calls every `RegisterCallback("CHANGED", fn)` callback as `fn(generation, name)` once per frame at most (`C_Timer.After(0, ...)`), `name` being the first bump's name in that frame. M1's `API.lua` has both functions; only adapters (M2) use them.

**Registering.** `Prices.Register(provider)` takes the table of spec 11.2 (`id`, `label`, `IsAvailable`, `GetPrice`, `OnUpdate`); providers register in file order, and `providerOrder` (spec 6) decides ties. `Register` ignores a second provider with an id already registered (and logs it); an id missing from `providerOrder` goes last. `Prices.lua` calls each available provider's `OnUpdate(fn)` once at `PLAYER_LOGIN`, and again on the `ADDON_LOADED` of a provider's addon that was not available before. The notice, `Prices.NotifyChanged(providerId)`, bumps the price generation with `Generations.Bump("prices")` and then calls every `Prices.OnChanged(callback)` callback with `(providerId)`, each through `Log.Guard("prices", ...)` so a failing callback does not stop the next. **`Prices.Best(itemID, link)`** returns `price, source` on success, where `price` is the table `GetPrice` returned (`unit`, `ageDays`, ...) and `source` is a table `{ id = <provider id>, label = <provider label> }`; with no usable price it returns `nil, reason`, a table `{ code = <"stale"|"notinscan"|"neverseen"|"noscan"|"noprovider">, price = <the old price or nil>, provider = <id or nil> }` (spec 7.6). A provider may also define `HasData()`, which returns false when it knows it holds no data at all (AHDB with no scans); Auctionator defines none. `Best` returns the `noscan` reason when at least one provider is available, no provider has returned a price this session (a local in `Prices.lua`, set the first time any provider returns a price), and no available provider's `HasData()` returns true. The first price a provider returns in a session sets that flag and then calls `Prices.NotifyChanged(providerId)` just after the current `Best` call returns (`C_Timer.After(0, ...)`, so a classification in progress is not interrupted); the notice bumps the price generation and runs the `OnChanged` callbacks, so results that showed `noscan` are recomputed and the adapters refresh. The flag lasts until `/reload`. With `requireLastScan` on, `Best` asks only the providers with `honoursLastScan` (AHDB) while one of them is available, and otherwise ignores the setting. `Prices.LastScanIgnored()` returns true when the setting is on, a provider is available and none honours it (Auctionator alone); the login line, the Settings note and the Status row read it. When several providers fail with the same code, the reason carries the one with the smallest `ageDays` (its price and provider). **`Prices.Status()`** returns a list, one entry per registered provider in `providerOrder`: `{ id, label, available, seen, newestAgeDays, error }`, where `seen` is true once any price was read from the provider this session, `newestAgeDays` is the smallest `ageDays` among those prices (nil when none was read or every one had no age; `seen` tells the two apart, for the two lines of section 11.2) and, for AHDB, the age of the house's latest scan (11.1), and `error` is the last error text or nil (cleared by the next call of the same function, `IsAvailable`, `GetPrice`, `HasData` or `OnUpdate`, that does not error); AHDB's entry also carries `items`, `lastScan` and `house` for the Status tab. `Prices.lua` updates the table whenever a provider returns a price or errors; the checklist, `/ll status` and `/ll probe` read it. **`Prices.GetVendorPrice(itemID, sellPrice, hasNoValue)`** takes the facts the caller already has (`ItemFacts.lua` loads after `Prices`, so it passes them in) and returns the sell price, forced to 0 when `hasNoValue` is true or AHDB marks the item unsellable. `Adapters.Register(adapter)` takes `{ id, Detect, Init, Refresh }` (`Detect` returns whether the bag addon is present); `Adapters.lua` calls `Detect`, then `Init(ns.API)`, at `PLAYER_LOGIN` for each adapter in registration order, which is the order of spec 12.1 (the four adapter files load in that order, then `Display/BlizzardBags.lua`), and again on the `ADDON_LOADED` of any bag addon whose adapter has not started yet. `Display/BlizzardBags.lua` registers as the default-bag adapter (its `Detect` returns true), so it has its place in the order, its Status row and its toggle like the others.

**Tools.** The tool files sit at the repository root, outside the addon folder, so none of them ships: `stylua.toml`, `.luacheckrc` and `.gitattributes` (LF for Lua files). StyLua and luacheck run over `LootLogic/` (including `Data/`) and `tests/`. `.luacheckrc` sets `max_line_length = 100` and `max_comment_line_length = 80`, and lists the allowed globals in two parts: `globals` holds the addon's own (`Globals.lua`, style guide section 3) and `read_globals` the WoW functions and tables the code reads. The `read_globals` list is written by hand from the API the code and `tests/stubs/Wow.lua` use, kept in step with the stubs, and not copied from another addon's configuration (`CONTRIBUTING.md`). A `files["tests/"]` entry adds the harness globals, and a `files["tests/stubs/Wow.lua"]` entry lists the WoW names that file assigns as writable `globals`, so the stub raises no read-only warning while the addon files still read them as read-only. A `files["tests/TestVendor.lua"]` entry lists `AuctionDB`, the global that file sets to stand in for AHDB's. The same configuration lints `Globals.lua`, which is the only file that may create the addon's own globals; `Core/DB.lua` also assigns `LootLogicDB`, the saved variable named in the TOC, and the configuration lists it.

**Locale table.** `Locale/enUS.lua` fills `ns.L`, a table of `camelCase` keys to English strings (`L.itemDoesNotExist = "Item %d does not exist."`). The strings in `docs/ux.md` are the enUS values; where it shows a variable part (`<provider>`, `<error>`), the value holds a `string.format` placeholder (`%s`, `%d`), and the code calls `string.format(L.key, ...)`. All player-facing text is in `ns.L`, including the reason and error texts of spec 7.6 and 13, not only the `docs/ux.md` strings. An optional part (" (assumed)", "; effect not scored") is its own key that the code appends; a joined list is joined by the code with ", ", and "and N more" is its own key; a singular and a plural are two keys (`upgradesWaitingOne`, `upgradesWaitingMany`) chosen by the count. Money is written as gold, silver and copper parts ("1g 2s", "4g 10s", "35c"), each part left out when zero and none padded; zero is "0c". A reason code maps to the key `reason` followed by the code with a capital first letter (`inuse` gives `L.reasonInuse`). Tests compare texts built from `ns.L`, so rewording a string does not break a test. Where a language could need another order, write numbered placeholders (`%1$s`). `Locale/enUS.lua` sets a metatable whose `__index` returns the key, so a missing string shows its key on screen instead of raising an error. Other languages, when added, are files named for the client locale that overwrite keys of `ns.L` only when `GetLocale()` matches.

BetterBags' plugin example says a plugin "must have a dependency on BetterBags". We use OptionalDeps and detect at runtime instead; verify (L16).

### 14.1 Data files

Lookup tables live in `Data/` files, not in the spec. This section gives each file's shape, source and a few sample rows. Each file is first written in the milestone that needs it (most from the beta client data in M0; `Data/Templates.lua` and `Data/TypeExamples.lua` in M2; `Data/WeightTables.lua` from WoWSims Forever or the team's own, the four M1 tables in M0, the assumed-spec tables in M2, the rest in M4), then checked against the live client from launch (2026-11-05) and corrected as needed. Where the best source is the running game, the file does not exist, and the spec says so. Where a source record is not in the repository (the profession tool item IDs, the nine class training tables, and the `ITEM_MOD_*` names beyond those the sources show), the rows are written from memory of Classic, each marked from memory and unverified (the class tables keep their label, "Classic baseline, unverified for Forever", spec 8.3), and are corrected from the live client. The assumed spec of each class (spec 8.2) is the row of that class flagged `assumed = true`. From M0 the flag is set on the four rows of the M1 tables (Druid Bear, Paladin Protection, Shaman Enhancement, Warlock Affliction), so a class with no flagged row has `spec = nil`; M2 flags a row for every class and moves the Druid and Paladin flags (spec 8.2).

**`Data/Specs.lua`: spec catalogue.** One row per spec: id (`CLASS:name`, upper-case class token and lower-case name), class and display label. The labels are the classic talent tree names; the ids, and the Bear and Cat split of Druid Feral Combat (two roles with different stats), are LootLogic's. The list of 28:

| Class | Specs (id suffix) | WoWSims Forever class folder (`ui/specs/<class>/`; the sim's subfolders in brackets, read 2026-11-01 at commit `2430d539`) |
|---|---|---|
| Warrior | `arms`, `fury`, `protection` | `ui/specs/warrior` (`dps`, `protection`) |
| Paladin | `holy`, `protection`, `retribution` | `ui/specs/paladin` (`holy`, `protection`, `retribution`) |
| Hunter | `beastmastery`, `marksmanship`, `survival` | `ui/specs/hunter` (`dps`, builds per tree inside) |
| Rogue | `assassination`, `combat`, `subtlety` | `ui/specs/rogue` (`dps`, builds per tree inside) |
| Priest | `discipline`, `holy`, `shadow` | `ui/specs/priest` (`healer`, `dps`) |
| Shaman | `elemental`, `enhancement`, `restoration` | `ui/specs/shaman` (`elemental`, `enhancement`, `restoration`) |
| Mage | `arcane`, `fire`, `frost` | `ui/specs/mage` (`dps`, builds per tree inside) |
| Warlock | `affliction`, `demonology`, `destruction` | `ui/specs/warlock` (`dps`, builds per tree inside) |
| Druid | `balance`, `bear`, `cat`, `restoration` | `ui/specs/druid` (`balance`, `feralbear`, `feralcat`, `restoration`; Bear and Cat weights in `feral_ep.ts`) |

```lua
Specs = {
    ["DRUID:bear"] = { class = "DRUID", label = "Bear", assumed = true },
    ["DRUID:cat"] = { class = "DRUID", label = "Cat" },
    ["WARLOCK:affliction"] = { class = "WARLOCK", label = "Affliction" },
}
```

The labels are the classic talent tree names (L48). The sim's folders are per sim spec, not per talent tree (the column above): Hunter, Mage, Rogue and Warlock have one `dps` folder each with builds per tree inside, and Bear and Cat share `feral_ep.ts`. Which spec takes a preset, which is computed and which is written by the team is listed under `Data/WeightTables.lua` below (spec 8.2); the tables are built in M0 for the four M1 specs, M2 for the remaining assumed specs and M4 for the rest. The tree names the client reports are live check L48.

**`Data/WeightTables.lua`: weight tables.** One table per spec id: a table computed by the team with the WoWSims Forever sim (MIT; sim commit and inputs recorded), or one written by the team (spec 8.2), with the sim's names mapped to canonical keys:

| WoWSims stat (names from `proto/common.proto`, source-read at commit `2430d539`) | Canonical key |
|---|---|
| StatStrength, StatAgility, StatStamina, StatIntellect, StatSpirit | STR, AGI, STA, INT, SPI |
| StatArmor | ARMOR |
| StatBonusArmor | BONUSARMOR |
| StatArmorNoMods | ARMOR |
| StatAttackPower, StatFeralAttackPower | AP |
| StatRangedAttackPower | RAP |
| StatSpellDamage | SPDMG, and part of SP (below) |
| StatHealingPower | HEAL, and part of SP (below) |
| StatArcaneDamage, StatFireDamage, StatFrostDamage, StatHolyDamage, StatNatureDamage, StatShadowDamage | SP_ARCANE, SP_FIRE, SP_FROST, SP_HOLY, SP_NATURE, SP_SHADOW |
| StatHitRating, StatCritRating, StatHasteRating | HIT, CRIT, HASTE (one rating each for melee, ranged and spells) |
| StatMP5 | MP5 |
| StatDefenseRating, StatDodgeRating, StatParryRating, StatBlockRating, StatBlockValue | DEF, DODGE, PARRY, BLOCK, BLOCKVALUE |
| PseudoStatMainHandDps, PseudoStatOffHandDps, PseudoStatRangedDps | DPS_MH, DPS_OH, DPS_RANGED |
| The sim's real resistance stats (only where a table weights them and they are not placeholders) | RES_<school> |
| StatExpertiseRating | EXPERTISE (7 items in the sim's database; the sim caps it at 6.5%, which a linear sum cannot apply) |
| StatSpellPiercing | SPELLPIERCING (Forever's name for spell penetration; 33 items) |
| StatHealth, StatMana, StatArmorPenetration, StatPhysicalDamage, the resistance placeholders, the per-school hit pseudo-stats | dropped |

**Spell power.** The sim has no spell power stat. In the sim's item data a "spell power" item carries equal Spell Damage and Healing Power (source-read), so a point of it is worth the Spell Damage weight plus the Healing Power weight, and a table's `SP` is that sum (what `GetItemStats` returns for each kind of item is live check L4).

**Which spec has which source** (decided; coverage read from the sim's `presets.ts` files):
- **Computed by the team with the sim, 23:** Warrior (Arms, Fury, Protection), Paladin (Protection, Retribution), Rogue (Assassination, Combat, Subtlety), Priest Shadow, Shaman (Elemental, Enhancement), Druid (Balance, Bear, Cat), Hunter (Beast Mastery, Marksmanship, Survival), Mage (Arcane, Fire, Frost), Warlock (Affliction, Demonology, Destruction). The sim's shipped presets exist for 13 of these (all but the 10 Hunter, Mage, Warlock and Paladin Protection specs) and are compared with the computed tables as a cross-check. A preset is a snapshot of the sim at the commit that wrote it (the Shaman Enhancement preset reproduces within about 0.05 per stat at its own commit and differs on the current sim; `docs/sim-learnings.md`).
- **Written by the team, 5:** the healers: Paladin Holy, Shaman Restoration, Druid Restoration (the sim has neither a simulation nor a preset for them), and Priest Discipline and Holy (the sim has the heal spells and hand-set presets but no healing rotation, so a computed table would rest on a rotation the team wrote; `docs/sim-learnings.md` section 6). They are computed instead once the sim implements healing and ships a healer rotation.

**Tank tables: Druid Bear and Paladin Protection** (spec 8.2; the run and what it showed: `docs/sim-learnings.md` section 9). The DPS weights alone value Stamina, armour and block value at about 0 and defense, dodge and parry below 0, so these two tables use the recipe the sim states for its own Warrior Protection weights (`ui/specs/warrior/protection/presets.ts` lines 34 to 36 at commit `3e41c53f`; source-read): 0.6 x the threat weights with Strength = 1, plus 1.15 x the TMI weights with Stamina = 1, measured on the table's gear set.
- **Formula:** for each stat, `0.6 * TPS(stat) / TPS(Strength) + 1.15 * TMI(stat) / TMI(Stamina)`, from the raw signed weights in the JSON the stat weights program writes. Not from the engine's EP column, which is an absolute value and, for TMI, uses Armor as its reference. TMI weights are below 0 for a stat that helps (a lower TMI is better), so dividing by Stamina's negative TMI weight turns them positive. Main hand DPS is combined the same way. Death probability is not used.
- **Keys:** as in the stat map above. `StatArmor` and `StatArmorNoMods` both map to ARMOR, and ARMOR takes the `StatArmor` value, as the recipe weighs ArmorNoMods as Armor. ArmorPenetration and PhysicalDamage are dropped; SPELLPIERCING is not weighed (0); Protection's `HEAL` is 0, so its `SP` equals `SPDMG`. No percent-based keys.
- **Signs kept:** a weight below 0 is shipped as measured (Paladin Protection's dodge and parry); the table values a tank in a group.
- **Label:** the table's `confidence` text adds "assumes group tanking", for example "computed by the team with WoWSims Forever, assumes group tanking, unverified in game".
- **Inputs of the M1 tables** (the sim has no build file for either spec, so each build is assembled from its spec's `presets.ts`): sim commit `3e41c53fafe13bbce337e2784061edf2c5a5b97f`, the `tools/statweights` program unchanged, target mode at 0.05 (`-epci 0.05 -maxmult 3000`), seed 101. One encounter for both: a 180 s fight with 5 s variation and one level 63 target with minimum base damage 6000 (the Bear presets' Mount Hyjal value) and armour 3731, the player named as tank (`tanks = [Player 0]`), and the presets' healing model. Druid Bear: talents `050022-2322030212310212501-055`, `apls/adaptive.apl.json`, `gear_sets/default.gear.json` (the sim's dev-only level 60 placeholder), Tauren, the presets' consumables, buffs and debuffs, the spec's 16 `epStats` plus main hand DPS. Paladin Protection: talents `050050002-05302102213301531-502`, `apls/default.apl.json`, `gear_sets/default.gear.json` (dev-only placeholder), Human, the presets' consumables, buffs and debuffs, the spec's 18 `epStats` plus main hand DPS. The reference stat of each run (Agility for Bear, Strength for Protection) only scales the EP the program prints; the formula uses raw weights, so it does not depend on it.

```lua
Weights = {
    ["WARLOCK:affliction"] = {
        sim = "ui/specs/warlock/dps",
        commit = "<sha>",
        inputs = "<gear set, build>",
        confidence = "computed by the team with WoWSims Forever, unverified in game",
        -- Illustrative values, not from the Forever sim.
        weights = {
            SP = 1,
            SPDMG = 1,
            SP_SHADOW = 0.9,
            SP_FIRE = 0.1,
            HIT = 1.28,
            CRIT = 0.57,
            HASTE = 0.78,
            INT = 0.23,
            MP5 = 0.14,
            STA = 0.01,
        },
        -- Per rating point, as the sim gives it. Only a table the team writes
        -- by hand per 1% lists keys here, divided by the rating-per-% at load.
        percent = {},
    },
}
```

**`Data/Slots.lua`: slot groups.** The INVTYPE to slot-group table of spec 8.4, the slot word each group uses in reasons (spec 7.6), plain enUS words kept in `ns.L`: head, neck, shoulder, back, chest, wrist, hands, waist, legs, feet, ring, trinket, ranged, two-hander, main-hand weapon, off-hand, the eight armour slot groups used by `bestArmorOnly` (head, shoulder, chest, wrist, hands, waist, legs, feet), and the bag ID ranges (bags 0 to 5, bank tabs 6 to 14). **`Data/Templates.lua`:** the shipped want templates of ux 4.3 (M2).

**`Data/ItemMods.lua`: stat keys.** Maps the game's `ITEM_MOD_*` keys from `C_Item.GetItemStats` to the canonical keys of section 8.1. Source: the key names the game returns (live check L4), with the beta data dump as a starting list. Unknown keys are ignored and logged once.

```lua
ItemMods = {
    -- The name is from memory.
    ITEM_MOD_STRENGTH_SHORT = "STR",
    -- The next four are Blizzard keys (source-read; L4).
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    -- A Blizzard key (source-read; L4). Scored as DPS_MH, DPS_OH or DPS_RANGED
    -- by the hand it is judged in (spec 8.1).
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}
```

**`Data/Proficiency.lua`: proficiency.** Whether a character can use an armour or weapon type is read from the game with `IsPlayerSpell` (section 5, L6) and kept in the snapshot, so no table is needed for what the character knows now. The file holds only what the game cannot say: the **class table** (the level at which each class can wear or wield each type: used for the level look-ahead and for a type not yet trained, spec 8.3), marked "Classic baseline, unverified for Forever", and the spell IDs to query. Source: the data dump and the Classic baseline.

```lua
Proficiency = {
    spells = {
        cloth = 9078,
        leather = 9077,
        mail = 8737,
        plate = 750,
        shield = 9116,
        dualWield = 674,
        -- ...
    },
    -- Each value is the level at which the class can use it (1 = from the
    -- start); unverified for Forever. A class that dual wields also has
    -- dualWield = <level> (for example ROGUE = 1); a class without the skill
    -- has no field.
    classes = {
        SHAMAN = {
            armor = { ["4:1"] = 1, ["4:2"] = 1, ["4:3"] = 40, ["4:6"] = 1 },
            weapons = { ["2:4"] = 1, ["2:10"] = 1, ... },
        },
    },
}
```

```lua
-- Item class:subclass -> proficiency spell (from memory).
Proficiency.subclassSpell = {
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
}
```

The class tables cover all nine classes: armour and weapons are keyed like `subclassSpell` ("4:3", "2:4"), the value being the level at which the class can use them.

**`Data/ItemClasses.lua`: dispositions, tools and never-touch items.** Per class and subclass defaults ("stay" or "sell", spec 7.2 step 5), the profession tool list, and the never-touch IDs. Source: the data dump for the dispositions and the tool classes (profession tools are 2/14, fishing poles 2/20, Flint and Tinder 7/11, runed rods 7/12); the tool item IDs are written from memory (section 14.1, above). The tool rows say which profession needs the tool.

```lua
-- Keys are always text: "<class>" or "<class>:<subclass>".
ItemClasses.dispositions = {
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
}

-- [itemID] = profession.
ItemClasses.tools = {
    -- Mining Pick.
    [<itemID>] = "Mining",
    -- Skinning Knife.
    [<itemID>] = "Skinning",
}

-- Hearthstone.
ItemClasses.neverTouch = { [6948] = true }
```

**`Data/TypeExamples.lua`: example items per item type.** Shown under each class and subclass in the Wants type tree and searched by Wants search (`docs/ux.md` 4.2). Source: the data dump, chosen by hand for names a player recognises. Item names come from the client at run time (`C_Item.GetItemNameByID`), so the file stores IDs, and falls back to a short label when the name is not cached yet.

```lua
-- ["class:subclass"] = { ids = { itemIDs }, label = "fallback text" }.
TypeExamples = {
    ["7:5"] = {
        ids = { <Linen Cloth ID>, <Wool Cloth ID>, <thread ID> },
        label = "Linen, Wool, thread",
    },
    ["7:11"] = {
        ids = { ... },
        label = "vials, dyes, flux, gems, fish, Flint and Tinder",
    },
}
```

---

## 15. Events, caching and performance

| Event | Work | Confidence |
|---|---|---|
| `ADDON_LOADED` (LootLogic) | DB defaults and migration | from memory |
| `ADDON_LOADED` (others) | Adapter and provider detection (BetterBags, BagBrother, ArkInventory, EUI Bags, Auctionator, AuctionDB, OutfitterForever; ItemRack and Loadout from v1.1) | from memory |
| `PLAYER_LOGIN` | Detect addons already loaded (an addon that loads first fires no `ADDON_LOADED` we see), price providers included; set `lastSeen`. Schedule the login chat lines (added, first-run, no-price, and from M2 the last-scan line) together, 5 s later with `C_Timer`, in that order (`docs/ux.md` 2.1); the no-price line is decided when the lines print: it prints only if no price provider is available then (a provider that becomes available before the 5 s are up suppresses it). Roster entry (name, region, faction, class, race, level). Hook the global `SendMail` (exists on Forever: source-read, Journey Tracker; hook behaviour L13). Hook default bag frames. Default loadout for a new character. | from memory |
| `PLAYER_ENTERING_WORLD` | On the initial login and on reload only: debounced full snapshot (gear, bags, proficiency, imported sets); initial classification; then the mail-upgrade line (spec 13): classify the links in `inbox.gear` and `inbound` for this character with `ClassifyLink(link, true)`, waiting for item data (skip any still pending after 10 s) | from memory |
| `PLAYER_EQUIPMENT_CHANGED` | Snapshot gear and proficiency; bump the here-gear generation | from memory |
| `SPELLS_CHANGED` | Snapshot gear and proficiency; bump the here-gear generation; clear the "Already known" cache (section 10) and bump `gen.asks` | from memory; L23 |
| `NEW_RECIPE_LEARNED`, `LEARNED_SPELL_IN_SKILL_LINE` | Clear the "Already known" cache (section 10); bump `gen.asks` | from memory; L23 |
| `PLAYER_LEVEL_UP` | Store the new level in the roster entry (the event's first argument; `UnitLevel` may still return the old level during the event, from memory); snapshot gear and proficiency; bump the here-gear generation | from memory |
| `BAG_UPDATE_DELAYED` | Snapshot bags 0 to 5 (equippable links, counts); bump `gen.gearHere` when an equippable item entered, left or moved; mark changed slots; adapters refresh (debounced 0.2 s) | from memory |
| `BANKFRAME_OPENED` | Bank snapshot of tabs 6 to 14 from `Enum.BagIndex.CharacterBankTab_1..9`, and bank slots are classified. **Not** `BANK_CONTAINER` and `NUM_BANKBAGSLOTS` (section 5). | from memory; L40 |
| `BAG_UPDATE_DELAYED` while the bank is open | Also re-snapshot tabs 6 to 14 (moves inside the bank fire bag events; `PLAYERBANKSLOTS_CHANGED` serves the old main bank container Forever lacks, from memory) | from memory; L40 |
| `BANKFRAME_CLOSED` | Stop classifying bank slots and keep the last snapshot; never snapshot at close. The bank counts as open from `BANKFRAME_OPENED` to `BANKFRAME_CLOSED`; a reload starts with it closed and keeps the snapshot taken before it | from memory; L40 |
| `MERCHANT_SHOW`, `AUCTION_HOUSE_SHOW`, `MAIL_SHOW` | Only when `ui.autoOpenContents` is on: open the window on the Contents tab if it is closed (never closes it, never moves it). | from memory; L38 |
| `MAIL_SHOW`, `MAIL_INBOX_UPDATE` | Inbox snapshot; clear an `inbound` entry for here only when a matching attachment (item and count) is in the snapshot, or when the entry is older than the 30-day mail lifetime. An entry still in transit stays, so the item keeps counting as owned | from memory; L49 |
| `MAIL_SEND_SUCCESS` (after the `SendMail` hook captured recipient and attachments) | Append to the recipient's `inbound` if it is a roster character. `MAIL_FAILED` drops the pending capture. | from memory; L13 |
| `GET_ITEM_INFO_RECEIVED`, `ITEM_DATA_LOAD_RESULT` | Retry pending items (batched). An owned piece that loads after it was left out of the baselines (spec 8.4, pieces still loading: 10 s after its first request, timed with `C_Timer`) bumps `gen.gearHere` for here's piece, `gen.gearOthers` for another character's | from memory; L28 |
| `EQUIPMENT_SETS_CHANGED`, Outfitter events (v1.1: ItemRack events) | Re-import set membership | from memory (Equipment Manager, L1); source-read (Outfitter, L29); unverified (ItemRack, L30) |
| Auctionator `RegisterForDBUpdate`; AHDB `SCAN_DATA` and `HISTORY_MERGED` | Bump the price generation | source-read; L9 |
| `PLAYER_REGEN_ENABLED` | Run deferred work | from memory |
| `MODIFIER_STATE_CHANGED` | For `LSHIFT` or `RSHIFT` while an item tooltip with the LootLogic line is shown: set the tooltip again from its owner, so the Shift detail follows the key (12.2) | from memory; L59 |
| `PLAYER_LOGOUT` | Write `lastSeen` only (with debug on, also the `logout` line of the debug log, below). Never snapshot here: the client has already cleared the data (beta finding). | confirmed (beta data); L32 |

**Caches and generations:**
- Generations (the counters are in `Core/Generations.lua`; the code that causes a change calls `Generations.Bump(name)`, and `Cache.lua` reads them to key its results), and what bumps each: `gen.gearHere` (gear, level, proficiency, an equippable bag change, the bank and inbox snapshots, one of here's owned pieces loading after it was left out); `gen.gearOthers` (inbound mail recorded, another character's owned piece loading after it was left out); `gen.loadouts` (loadout edits, imported-set refresh); `gen.asks` (wants, Protect lists, the recipe known-check cache being cleared); `gen.roster` (order, Receives gear, display names, a new character); `gen.settings` (settings and class overrides); `gen.prices` (a provider's notice of new data).
- The result cache key is `bag:slot|link|bound|holding` for bag items (so two identical copies can have different results) and `L|link` for link-only results (`I|link` for an inbox attachment); holding only matters for step 6.
- Each entry stores the generations it used, and is stale when any of them moved. So price changes invalidate only results that reached step 6.
- Price freshness also changes with the clock, with no generation moving. An entry that reached step 6 stores `validUntil` (an Auctionator price has no timestamp, so an entry relying on one is rechecked when Auctionator's day turns, below): the earliest time a price it relied on crosses `maxPriceAgeDays` (a usable price turning stale gives Vendor/AH). It is stale once `now >= validUntil`. One `C_Timer` is kept for the earliest `validUntil`; when it fires, those entries are recomputed and the adapters refresh. M0 stores `validUntil` and treats an entry as stale once `now >= validUntil`; the timer arrives in M2 with its first consumer, the adapters.
- **Auctionator's day turn.** Auctionator computes an age when asked, in whole 24-hour days counted from midnight on 1 January 2020 by the computer's clock (source-read: `Source/Constants/Main.lua` and `Source/Database/Mixin.lua`, read for its behaviour only). That the start date is taken in local time is from memory, so the day turns at local midnight, an hour off while summer time differs from 1 January. Until L9 notes the time the age turned, an entry relying on an Auctionator price has as its `validUntil` the next 00:00 or 01:00 on the computer's local clock, whichever comes first, so a turn anywhere from 23:00 to 01:00 is seen within an hour of it; L9's note then sets the one time to use.

**Debug log** (`/ll debug on`, spec 13). Each line is `[hh:mm:ss] <area>: text`, echoed to chat with the "LootLogic debug:" prefix and kept in `debug.log` (the last `debug.maxLog` lines). Nothing is logged while debug is off; errors go to the Errors list either way. Debug counts as off, and `Log` writes nothing and creates no table, when `LootLogicDB` is nil, has no `debug` table (`Log` is called before `DB.lua` has filled the defaults, or on the very first load), or `debug.enabled` is false. When the saved schema is newer than the code (spec 6; `Log.lua` compares `LootLogicDB.schema` with `Init.schemaVersion`, so the very first event line is not written either; after a failed migration `DB.lua` calls `Log.LockDebug()`, so only the `event` line of that one `ADDON_LOADED` was already written), debug logging is off for the session, so `LootLogicDB` stays unchanged, and `/ll debug on` refuses like any command that changes data. While debug is on, LootLogic logs:
- `event`: each event in the table above when it fires, with its arguments. `GET_ITEM_INFO_RECEIVED` and `ITEM_DATA_LOAD_RESULT` are not logged one by one: each batch of retried items gives one line ("12 items loaded"). While debug is on, LootLogic also registers `PLAYERBANKSLOTS_CHANGED`, and `MERCHANT_SHOW` and `AUCTION_HOUSE_SHOW` when `ui.autoOpenContents` is off, only to log them (L38, L40).
- `snapshot`: each snapshot taken (gear, bags, bank, inbox, proficiency, imported sets), with how many links or items it stored.
- `mail`: what the `SendMail` hook captured (the recipient, and each attachment's link and count), then `MAIL_SEND_SUCCESS` with the `inbound` entry added, or `MAIL_FAILED` (L13); and each `inbound` entry that an inbox snapshot clears (L49).
- `recipes`: each clearing of the "Already known" cache, with the event that caused it (L23).
- `prices`: each provider notice of new data, with how many cached results it made stale.
- `stats`: an unknown `ITEM_MOD_*` key, once per key and session (spec 8.1).
- `logout`: at `PLAYER_LOGOUT`, how many of the equipped slots 1 to 19 return a link (`GetInventoryItemLink`) and how many bag slots hold an item, read only for this line and never stored (L32). The game writes the saved data after `PLAYER_LOGOUT` (from memory), so this line is read in the saved-variables file after logging out.
- `error`: each entry added to the Errors list, as `<area>: <message>`.
- `classify`: one line per full classification, with the number of items and the time taken (the figure `/ll perf` prints).

**Budget** (measured with `debugprofilestop` and `/ll perf`):
- A cached refresh of 100 slots: under 1 ms.
- A full recompute of 100 items × 4 characters × up to 3 loadout specs: target under 20 ms (unverified until L35), spread over frames (`C_Timer.After(0)` batches of 25) when above 10 ms.
- BetterBags `ReprocessAllItems`: at most once per 2 s.
- Overlay painting reuses one texture pair per button.

**Saved-data size:** about 4 characters × (19 gear links + about 100 bag items + about 150 bank items) as strings, around 60 KB.

---

## 17. Testing strategy (no client until 2026-11-05)

### 17.1 Offline (before launch)
- **Harness:** each `Test*.lua` returns named test functions; `run.py` prints PASS or FAIL per case and exits non-zero on any failure; the loading is described under Runner. Stubs also needed: `C_AddOns.GetAddOnMetadata` (the version, keyed by addon), the chat output (`print` and `DEFAULT_CHAT_FRAME:AddMessage`, captured for the tests), `GetInventoryItemLink`, `C_Container.GetContainerItemPurchaseInfo`, `GetInboxNumItems`, `GetInboxItem`, `GetInboxItemLink`, `GetSendMailItem`, `SendMail`, `UnitRace`, `GetServerTime`, `GetTime`, `InCombatLockdown`, `C_Item.GetItemClassInfo`, `C_Item.GetItemSubClassInfo`, `C_Item.GetItemNameByID`, `C_PlayerInfo.CanUseItem`, `C_Item.GetItemUniquenessByID`, `C_Item.DoesItemExistByID`, the `ITEM_*` and `TOOLTIP_ITEM_STAT_*` global strings, `CreateFrame`, `SlashCmdList`, `issecretvalue`, `hooksecurefunc` and the Lua helpers `strsplit`, `strtrim` and `wipe`.
- **Runner:** Lua 5.1 through `lupa.lua51` (the project uses lupa; `pip install lupa`). The command is `python tests/run.py` from the repository root; an optional argument runs only the cases whose label `<file>: <case>` contains it (case-sensitive), so `python tests/run.py TestScoring` selects a file. For each test case `run.py` starts a fresh runtime, loads `stubs/Wow.lua`, then `Harness.lua` (which builds `h`), then the `.lua` lines of the TOC in order (except `Globals.lua`), each called as `chunk("LootLogic", ns)` with one shared `ns` table, then the test file, then runs that one case. No state carries from one case to the next.
- **Test file contract:** a `Test*.lua` file is called with `addonName, ns, h` and returns a table of cases: a descriptive string key (`["Classify: a protected item stays"]`) to a function with no arguments. Cases run in key order. The harness table `h` holds: `h.Fixture(name)` (loads `tests/fixtures/<name>.lua`, a file that returns a table); the assertions `h.Equal(actual, expected, label)`, `h.DeepEqual(actual, expected, label)`, `h.True(value, label)` and `h.Nil(value, label)`, each raising an error naming the label, the expected and the actual value; and `h.Stub`, the control table of the fake client (set an item, a bag slot, a price, scripted tooltip lines; advance the manual clock; choose the character that is "here": name, race, class, level, faction and realm; set the known spells for `IsPlayerSpell`; open and close the bank; set the inbox; set combat lockdown; make an item pending and then loaded, firing `GET_ITEM_INFO_RECEIVED`; and fire any event on the addon's event frame, such as `ADDON_LOADED` and `PLAYER_LOGIN`). `LootLogicDB` is set by a case before it fires `ADDON_LOADED`: the case assigns a fixture table to the global, so the fixtures hold the characters' saved data and `h.Stub` holds the live client. A case passes when it returns without error; `run.py` catches the error, prints `FAIL <file>: <case>: <message>`, and exits non-zero after all cases ran. Fixtures are Lua tables so a test can read them directly; the stub reads the same tables. The setter names of `h.Stub` are listed in a comment at the top of `stubs/Wow.lua`. **The clock:** the code reads `GetServerTime()` for every "now" (AHDB ages, the Auctionator day turn, the debug log's `[hh:mm:ss]`, saved timestamps), turning it into local time with `date(format, GetServerTime())`, and `GetTime()` for session intervals; waits use `C_Timer`. The stub's one manual clock drives `GetServerTime`, `GetTime`, `time`, `date` and `C_Timer` together. The test computer is UTC: the stub replaces `date` with a version that formats in UTC (`os.date("!" .. format, t)`), so a test's expected times do not depend on the machine's time zone or daylight saving; `h.Stub` can set a fixed offset in seconds for a case that needs another zone. `C_Timer.After` cannot be cancelled; `C_Timer.NewTimer(seconds, fn)` returns an object with `Cancel()`, and the stub provides both. These four calls (`C_Timer.NewTimer` with `Cancel`, `GetServerTime`, `date`, `GetTime`) are from memory and tested by L63; if `NewTimer` is missing, the code keeps one `C_Timer.After` per timer with a token that the callback compares before it acts, and the stub drops `NewTimer`.
- **Stub API (`stubs/Wow.lua`):**
  - `C_Item`: GetItemInfo, GetItemInfoInstant, GetItemStats, GetDetailedItemLevelInfo, IsBound, IsBoundToAccountUntilEquip, DoesItemExist.
  - `C_Container`: GetContainerNumSlots, GetContainerItemInfo, GetContainerItemQuestInfo.
  - `Enum.BagIndex`: with CharacterBankTab_1..9.
  - Unit functions: UnitName (two values), UnitClass, UnitLevel, UnitFactionGroup.
  - GetRealmName, IsPlayerSpell, C_EquipmentSet, C_TooltipInfo (scripted lines), TooltipDataProcessor, C_Timer (After and NewTimer on the manual clock), `date` and `time` (UTC, manual clock), event dispatch.
  - M0's tests of the price rules register their own fake provider in the test with `Prices.Register({ id, label, IsAvailable, GetPrice, OnUpdate, HasData, honoursLastScan })`; the Auctionator and AHDB fakes below are used from M1 and M2, with their files.
  - Fakes for `Auctionator.API.v1`, `AuctionDB`, BetterBags (through a LibStub/AceAddon stub with a Categories module), `BagBrother.Rules`, `ArkInventoryRules`, and `Outfitter` with `gOutfitter_GlobalSettings`.
  - Table-driven from fixtures. Item facts are written by hand (a few real IDs per class and slot): id, class, subclass, quality, bind, stack, sell price, required level, slot, stats mapped to `ITEM_MOD_*`.
- **Fixtures:**
  - Test-only weight tables for the fixture specs that ship no table in M0 (Druid Cat and Restoration, Paladin Holy), with hand-written values, never shipped; and a fifth character of a class with no table (a Mage with `spec = nil`).
  - Item facts for a hand-picked set of items (a few per class and slot), written by hand.
  - Synthetic price responses, served through the fake of `Auctionator.API.v1`.
  - Synthetic AHDB strings.
  - Snapshots of four fake characters with hand-written loadouts (Druid: Bear worn, Cat, Restoration with `armor = "any"`; Paladin: Protection worn, Holy; Warlock: Affliction worn; Shaman: Enhancement worn), and hand-written wants.
- **Tests:** M0 has tests for M0 work only; a test for an M1 or M2 file is written with that file, and the bullets below say when it is not M0's.
  - Price rules, events, errors and generations: `Prices.Best` and the `noscan` rule (with a fake provider registered in the test), `LastScanIgnored`, `NotifyChanged` timing, `Prices.Status`, the order of `Events` handlers, the Errors list and `Log.Guard`, and `Generations.Total` and `OnBump`.
  - Classification order: one case per step and per edge-case row in 7.5.
  - Want matching: min quality, include and exclude, class restriction, global order.
  - AH rule: threshold matrix, vendor 0, the holding example (vendor 0 or `minGainPct = 0`; 120 Linen at a 1c net gain clears 1s; one item does not), stale prices, no provider gives Vendor/AH.
  - Scoring: ring, trinket, 2H versus MH+OH and off-hand baselines, bestArmorOnly (global and per-loadout override), look-ahead with `hereWinsInLookAhead` on and off, unique, several loadouts, "in use" protection, a better piece for a stowed loadout becomes its set piece and stays (the old piece loses "in use"), imported-set protection. A baseline piece still loading keeps the candidate pending, and is left out once 10 s have passed (manual clock). An item with a "Use:" or "Chance on hit:" line, or an "Equip:" line that matches no `TOOLTIP_ITEM_STAT_*` format, gets "; effect not scored"; one whose "Equip:" lines are all stats does not (scripted tooltip lines).
  - Migrations, in M0: the framework (migrations run in order, defaults deep-filled without overwriting, a newer saved schema left unchanged, with `DB.IsReadOnly()` true, the notice printed once and the capture functions writing nothing; the refusal of commands is `Slash.lua`'s and its test is M1's; a list default kept whole, and a value of the wrong type replaced by its default). Not an M0 test, written in M2 with it: the M2 migration (`tooltipNoWant` off; `spec = nil` gets the assumed spec; assumed Bear and Protection move to Cat and Retribution; a chosen spec is kept).
  - Providers (Auctionator in M1, AHDB in M2): Auctionator callerID errors and nil database; AHDB pcall fallback and string parsing.
  - Adapters (M2): what BetterBags' category function returns per scripted bag; BagBrother filters; ArkInventory rule.
  - **Assertions only:** every case states its expected verdict, written from the rules in the spec.
- **Performance smoke test:** 4 characters × 140 slots in under 50 ms in plain Lua 5.1 (a target and a loose proxy for the client, unverified until L35).

### 17.2 What must wait for the live client
- Every API marked from memory or unverified (section 18). Event timing, item-cache behaviour, secret values in combat.
- Every adapter's visual result: BetterBags caching and section order; the interplay with the "Betterbags - Forever" plugin; Bagnon rules; the default-bag overlay.
- Mail capture, the AH cut, real provider behaviour.
- Performance in the client. Taint or secure-button side effects of overlays: none expected, since we only post-hook and never touch secure attributes.

### 17.3 In game
- `/ll probe` prints PASS, FAIL or SKIP for each check in section 18 that can run automatically.
- A written checklist per milestone, with the milestone's pass rule (`docs/TESTING.md`, started with the M1 rule), in the style of Forever Ledger's (its `docs/TESTING.md`: numbered steps, each with what should happen).

---

## 18. Live-client checks (first sessions after 2026-11-05)

Pass rules: each automatic check has a pass rule (its Expected column read as a test). A check is SKIP, with the reason, when the addon is absent or a precondition is not met (an empty slot, an uncached item, no scan). L2 passes on two non-empty strings; L21 uses a fixed item ID; L48 passes when every tree name matches a label in `Data/Specs.lua` (Feral Combat matches Bear and Cat). L4 runs its first step on the slot 5 item (SKIP when it has no rating stat) and its later steps on fixed item IDs from the data dump (a spell power item, a healing item, an expertise item and a spell piercing item); each prints its keys and passes when it returns a table. L6 passes when the call returns booleans and Cloth (9078) is true for a cloth-capable class (untrained skills may be false). L61 prints every class and subclass it finds under its result line, in numeric order, and saves them with its result. L62 passes when `_VERSION` is `Lua 5.1` and `table.unpack` is absent, and prints the line it measured (the other values are noted by hand). `/ll probe` prints `L<n> PASS|FAIL|SKIP <value>` and saves the results in `debug.probe`. L28 is SKIP when item 19019 is already cached; otherwise it waits up to 10 seconds for `ITEM_DATA_LOAD_RESULT` for that item, the same 10 seconds as for an owned piece still loading (spec 8.4): the probe prints the other results at once, then L28's line when the event arrives (PASS, with the time it took) or when the 10 seconds end (FAIL, "no event within 10 s"); "probe done" follows the last line printed. L28's entry in `debug.probe` is filled in when its line is printed; a reload before then leaves it out. L58 makes its calls before L28 requests item 19019, so it sees the item uncached; it passes on `true` then `false`, and is SKIP, as L28 is, when 19019 is already cached. L9 reports each provider separately: a provider that is not installed, has no scan data, or has no price for 2589 is SKIP for that provider (named in the value); it passes when the price has the right shape (Auctionator: a copper number and an integer age; AHDB: a table with numeric `ts` and `min`) and FAILs only on a value of the wrong shape; L9 is SKIP when no provider is left; the next-day turn is noted by hand and is not part of the probe.

| # | Assumption | Exact test | Expected | If wrong | Probe |
|---|---|---|---|---|---|
| L1 | `C_EquipmentSet` and the Equipment Manager work | `/run print(C_EquipmentSet and C_EquipmentSet.GetNumEquipmentSets())`, then save a set in the character pane, with a random-suffix item in it; then `/dump C_EquipmentSet.GetItemIDs(<setID>)` and `/dump C_EquipmentSet.GetItemLocations(<setID>)` with that item worn, in the bags and in the bank | A number; the set saves; item IDs with no suffix, and locations that give the worn slot and the bag slot | Drop the Equipment Manager import; if a call gives the suffix, read it from that call | manual |
| L2 | `UnitName` returns first and last | `/run print(UnitName("player"))` | `Zugar Soulsour` (two values) **Confirmed (team, beta play, 2026-10-31): names are two words.** | Key by first name plus a disambiguator | auto |
| L3 | Region name and faction for eligibility | `/run print(GetRealmName(), UnitFactionGroup("player"))` | The same region string on all four characters; compare characters on different rulesets | Rework eligibility | manual |
| L4 | `GetItemStats` keys on Forever gear | `/dump C_Item.GetItemStats(GetInventoryItemLink("player",5))` on a hit or crit item; then `/dump C_Item.GetItemStats(<link>)` for a spell power item, a healing item, an expertise item and a spell piercing item | `ITEM_MOD_*_RATING_SHORT` keys; note the key for base armour, the keys a spell power item and a healing item return (one spell power key, or separate damage and healing keys), and the keys for expertise and spell piercing | Add tooltip parsing | auto |
| L5 | `C_PlayerInfo.CanUseItem` | `/run print(C_PlayerInfo and C_PlayerInfo.CanUseItem and C_PlayerInfo.CanUseItem(2589))` | Function exists, returns a boolean | Proficiency spells only | auto |
| L6 | Proficiency via `IsPlayerSpell` | `/run for _,id in ipairs({9078,9077,8737,750,9116,674,198,199,227,1180}) do print(id, IsPlayerSpell(id)) end` | true and false matching the class | `IsSpellKnown`, `C_SpellBook.IsSpellKnown`, or tooltip red lines | auto |
| L7 | Container info fields | `/dump C_Container.GetContainerItemInfo(0,1)` | `isBound`, `hasNoValue`, `stackCount`, `quality`, `hyperlink` | Adjust facts | auto |
| L8 | Class and subclass IDs match the data | `/run print(select(6, C_Item.GetItemInfoInstant(2589)))` and `/run for i=0,12 do print(i, C_Item.GetItemSubClassInfo(7,i)) end` and `/run for i=0,20 do print(i, C_Item.GetItemSubClassInfo(2,i)) end` | `7 5`; names for 0 to 2 and 5 to 12; the names of weapon subclasses 9 and 17 | Remap the defaults table | auto |
| L9 | Price providers on Forever | After a scan: `/run local a=Auctionator.API.v1; print(a.GetAuctionPriceByItemID("LootLogic",2589), a.GetAuctionAgeByItemID("LootLogic",2589))` and `/dump AuctionDB:LastPrice(2589, UnitFactionGroup("player"))` and `/dump AuctionDB:PlayerHouse()`; repeat the age call the next day before scanning | Copper and 0, then 1 the next day (note the time it turned); `{ts,min,median,qty}` (note whether `min` is per unit); `PlayerHouse()`: note whether it gives the faction or Neutral at a faction AH | Saved-data readers | auto |
| L10 | Default bag frames and hook points | `/run print(ContainerFrameCombinedBags, ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems, ContainerFrame1 and ContainerFrame1.UpdateItems)` with bags open | Frames and functions exist **Partly confirmed (team, beta play): the player can switch between combined bags and separate bags, so both must work; the frame names are still to be probed.** | Repaint on `BAG_UPDATE_DELAYED` by walking the frames' Items | auto |
| L11 | Tooltip getter for bag and equipped items | Hover a bag item, then `/run local i=GameTooltip:GetPrimaryTooltipInfo(); print(i and i.getterName, i and i.getterArgs and unpack(i.getterArgs))` | `GetBagItem 0 3`; hover an equipped item too: `GetInventoryItem`; an inbox attachment: `GetInboxItem` | Classify by link only in tooltips; for equipped items, skip the line when the tooltip's owner is a character-pane slot button | manual |
| L12 | Mail recipient format | Mail an alt as "First Last", then as "First" | Learn which works **Confirmed (team, beta play): mail needs "First Last"; "First" alone does not work.** | Store the mail name format | manual |
| L13 | `SendMail` hook and `MAIL_SEND_SUCCESS` | Send mail with `/ll debug on` | A log line with recipient and items; the hook reads attachments with `GetSendMailItem(i)` and `GetSendMailItemLink(i)` (from memory) | Track through the send frame | manual |
| L14 | Bank tabs 6 to 14 | At a banker: `/run for b=6,14 do print(b, C_Container.GetContainerNumSlots(b)) end` and `/run print(Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9)` | Slot counts on purchased tabs; 6 and 14 **Part confirmed (team, beta play): tabs are bought one at a time, with a rising price; 9 tabs in all: one included and 8 purchasable (the 9 enum members match).** | Re-derive bank IDs from `Enum.BagIndex` | manual |
| L15 | BetterBags API present | `/run local a=LibStub("AceAddon-3.0"):GetAddon("BetterBags",true); print(a and a:GetModule("Categories").RegisterCategoryFunction, a and a:GetModule("Categories").ReprocessAllItems)` | Two functions | Fall back to tooltip only for BetterBags | auto |
| L16 | BetterBags loads LootLogic's category function without a hard dependency | With LootLogic enabled, open bags | Sections Zugar, AH, Vendor, Vendor/AH, Equip appear | Add `## Dependencies` in a tiny `LootLogic_BetterBags` companion addon | manual |
| L17 | BetterBags precedence and refresh | Install "Betterbags - Forever" too. Loot a wanted item; change a want; check the item moves after `ReprocessAllItems`; note which plugin wins for a shared item. | Our section wins, or the precedence is known | Document precedence; raise our category priority if possible | manual |
| L18 | BagBrother rules and ArkInventory rule function | `/run print(BagBrother and BagBrother.Rules and BagBrother.Rules.Register)` and `/run print(ArkInventoryRules and ArkInventoryRules.Register)`; then use the rule `lootlogic("ah")` | Functions; the rule filters | Disable that adapter | manual |
| L19 | EUI overlay API | `/run print(EUI_Bags and EUI_Bags.RegisterItemOverlayIcon)` (EUI Bags on) | Function | Skip | auto |
| L20 | Rating-to-% conversion | Hover a crit item: compare the tooltip "+x%" with the stat; `/run for _,c in ipairs({CR_HIT_MELEE,CR_HIT_RANGED,CR_HIT_SPELL,CR_CRIT_MELEE,CR_CRIT_RANGED,CR_CRIT_SPELL}) do print(c, GetCombatRatingBonus and GetCombatRatingBonus(c)) end` at two levels; also note how dodge, parry, block and defense appear on an item | Rating per % for hit and crit (spec 8.2: 10 and 14 at level 60), and for dodge, parry and block where an item shows a % (12, 15 and 5), and whether it depends on level; how dodge, parry, block and defense are expressed; the same hit value, and the same crit value, for melee, ranged and spells; haste stays source-read while no item carries it | Fix the weight conversions; if melee, ranged and spell values differ, ask the team about separate keys (spec 8.1) | manual |
| L21 | Uniqueness API | `/run print(C_Item.GetItemUniquenessByID and C_Item.GetItemUniquenessByID(<a unique ring id>))` | Values | Tooltip lines | auto |
| L22 | Weapon speed in tooltip data | `/dump C_TooltipInfo.GetHyperlink(GetInventoryItemLink("player",16)).lines` | A "Speed x.xx" line | Nothing changes in v1 (no table weights speed) | auto |
| L23 | "Already known" and recipe events | Hover a known recipe (expect the `ITEM_SPELL_KNOWN` line); learn a recipe with `/ll debug on` | The line; `NEW_RECIPE_LEARNED` or `LEARNED_SPELL_IN_SKILL_LINE` fires | Rescan on `BAG_UPDATE_DELAYED` | manual |
| L24 | Account-bound or warbound handling | `/run print(C_Item.IsBoundToAccountUntilEquip)`; inspect a warbound item if any | Function | Treat all bound as bound | auto |
| L25 | Secret values on item APIs in combat | In combat: `/run print(issecretvalue(select(11, C_Item.GetItemInfo(2589))))` | false | Defer classification to out of combat | manual |
| L26 | Mail limits | Try mailing an opposite-faction alt or another ruleset | Refused **Confirmed (team, beta play): mail across factions or rulesets is refused. There are no realms.** | Widen eligibility | manual |
| L27 | AH cut | List one cheap item at the faction AH; read the sale mail | 5% | Change the default | manual |
| L28 | Item cache events | `/run print(C_Item.GetItemInfo(19019))` on an uncached item, then watch for `ITEM_DATA_LOAD_RESULT` | nil, then the event within 10 s | `Item:ContinueOnItemLoad` only | auto |
| L29 | Outfitter global copy | `/dump gOutfitter_GlobalSettings.Characters` after saving an outfit on two characters | Keys "First-Realm" with Outfits | Current character only | manual |
| L30 | ItemRack Universal data (v1.1) | `/dump ItemRackUser.Sets` after saving a set | `equip[slot]` strings | Adjust or skip | manual |
| L31 | Stack sizes | `/run print(select(8, C_Item.GetItemInfo(2589)), select(8, C_Item.GetItemInfo(2880)))` | 20 and 10 **Part confirmed (team, beta play): Linen Cloth stacks to 20; Weak Flux is not known.** | v2 split rules only | auto |
| L32 | Data is gone at logout | Known from beta client data; reconfirm with `/ll debug` at logout | Gear empty at `PLAYER_LOGOUT` | n/a | manual |
| L33 | No warband bank | At a banker: `/run print(C_Bank and C_Bank.CanUseBank and Enum.BankType and C_Bank.CanUseBank(Enum.BankType.Account))` | false or nil (BetterBags says none) | **If true:** add an "account bank" destination, which may beat mailing | auto |
| L34 | Baganator gets the tooltip line | With Baganator as the bag addon, hover items | The LootLogic line shows | Check tooltip hooks | manual |
| L35 | Performance | `/ll perf` with full bags and 4 characters; watch BetterBags redraw after `ReprocessAllItems`; open the bank and the Contents tab | Within budget (section 15) | Batch more, cache baselines harder, debounce reprocess longer | manual |
| L36 | Badge legibility | Badges at BetterBags' and the default bags' sizes, with Pawn installed; try 12 and 10 units | Readable and clear of the stack count and Pawn's arrow | Move the badge, shrink it, or use the coloured bar | manual |
| L37 | Item drop and link insertion | Drop a cursor item on the Wants item slot (`GetCursorInfo`); shift-click an item link with a LootLogic edit box focused | The item is read from the cursor; the link is inserted | Use an item ID edit box and `/ll want` only | manual |
| L38 | Merchant, AH and mailbox events | Open a merchant, the AH and the mailbox with `/ll debug on` | `MERCHANT_SHOW`, `AUCTION_HOUSE_SHOW` and `MAIL_SHOW` each log once | Find the right event names, or drop the auto-open setting | manual |
| L39 | Colour-blind CVar | `/run print(GetCVarBool("colorblindMode"))` with the option off and on | false, then true | Palette "auto" follows the setting only; no CVar | manual |
| L40 | Bank events and tabs | At a banker with `/ll debug on`: open and close the bank, move an item | `BANKFRAME_OPENED` and `BANKFRAME_CLOSED` log, and a move inside the bank fires `BAG_UPDATE_DELAYED`; tabs 6 to 14 read while open (extends L14); note whether `PLAYERBANKSLOTS_CHANGED` fires at all | Find the bank events with `/etrace`; re-read tabs 6 to 14 while the bank frame is shown | manual |
| L41 | Window basics | Open the window; press Escape; set the scale to 70% and 150% at two client UI scales | Escape closes it (`UISpecialFrames`); the layout holds | Own Escape handler; clamp the scale range | manual |
| L42 | BetterBags section names and order | With Zugar, AH, Vendor, Vendor/AH and Equip active, note each section's position and any name clash; reorder the categories in BetterBags' own list and reload (extends L17) | Sections appear under our names; the player's order sticks | Prefix our names; accept BetterBags' order (the Contents tab order is ours) | manual |
| L43 | Welcome dialog beside other addons | Fresh `WTF` folder with two or three other addons that show a welcome at login: order, overlap, that ours waits for `StaticPopup` frames to clear, and the 60 s fallback | Dialog shows once, readable, after the others | Adjust the wait or the fallback | manual |
| L44 | A slash in a category name | Register the category "Vendor/AH" in BetterBags and the other adapters | The section shows with the full name | Use a name without the slash, such as "Vendor or AH" | manual |
| L45 | Minimap button | Button shows, drags round the edge, hides from Settings; EllesmereUI's button group picks it up and the click still opens the window; a tooltip shows | Works beside other addons' buttons | Rename or resize the frame, or accept a loose button | manual |
| L46 | Hovered item from a slash command | Hover an item, type `/ll why` in chat, press Enter | The hovered item is explained | Require a link, keep the keybindings | manual |
| L47 | BetterBags category callback data | Register a category function that dumps `data`: does it carry bag, slot, bound state and count? | Slot and bound state present | The adapter finds the first bag slot holding that link and classifies it (BetterBags caches per item ID anyway) | manual |
| L48 | Talent tree names | `/run for i=1,(GetNumTalentTabs and GetNumTalentTabs() or 0) do print(i, GetTalentTabInfo(i)) end`, and the class-spec API of the retail engine if that prints nothing (from memory) | The tree names in `Data/Specs.lua` **The tree names match third-party WoW Forever calculators (seemeta.com, checked 2026-10-31); not yet seen in the client.** | Rename labels; the ids stay | auto |
| L49 | Inbox and mail APIs | Open the mailbox with mail waiting: `/run print(GetInboxNumItems(), GetInboxItemLink(1,1), GetInboxItem(1,1))` and `/run print(ATTACHMENTS_MAX_SEND)` | A count, a link, item fields; the limit is printed; `MAIL_INBOX_UPDATE` fires with `/ll debug on` | Walk the inbox on `MAIL_SHOW` only; adjust the attachment limit | manual |
| L50 | Addon compartment | Open the addon compartment menu (minimap tray) with LootLogic enabled; click its entry | An entry with the icon shows; the click opens the window (`LootLogicOnCompartmentClick`) | Slash command, minimap button and Settings panel button only | manual |
| L51 | Class restriction line | `/run print(ITEM_CLASSES_ALLOWED)`; hover a class-restricted item | The global string exists and matches the tooltip's "Classes:" line | Match the line by pattern from a captured tooltip | manual |
| L52 | Item link format | `/dump GetInventoryItemLink("player",5)` and a bag item link | Links of the form `\|cnIQ4:...\|Hitem:...` (colour token) or the classic hex form; our parser reads both | Fix the parser's colour and item-ID patterns | auto |
| L53 | Which call shows the ruleset | Compare `GetRealmName()` and `GetNormalizedRealmName()` on characters of different rulesets; look in the in-game API documentation (`/api`) for a ruleset or game-mode function; check the character-select text (unverified); also check whether two characters can share a name across rulesets (key collision) | A call that returns PvE, PvP, RP PvE or RP PvP | Add a per-character ruleset setting, or leave mail refusals as the only signal | manual |
| L54 | Specs chosen before M2 | After installing M1, run `/ll loadout <display name> <worn loadout name> <spec>` for each test character | `/ll status` shows no loadout marked assumed on a class that has a table | The M2 migration changes the specs left assumed | manual |
| L55 | Refundable purchase info | Buy an item from a vendor, then `/dump C_Container.GetContainerItemPurchaseInfo(bag, slot, false)` | Refund time and money fields | Drop the "refundable" suffix | manual |
| L56 | Effect lines on gear tooltips (section 7.1) | `/run print(ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC, TOOLTIP_ITEM_STAT_CRIT_PERCENT_INCREASE)`; then `/dump C_TooltipInfo.GetHyperlink(<link>).lines` for an item with a crit or spell power stat and for one with a "Use:" or "Chance on hit:" effect | The four strings print; the stat's "Equip:" line matches a `TOOLTIP_ITEM_STAT_*` format and the effect's line starts with one of the other two prefixes | Count only "Use:" and "Chance on hit:" lines as effects; if those prefixes are missing too, drop the "effect not scored" suffix | manual |
| L57 | A link built from an instance key (section 7.1) | With a random-suffix item in the bags: `/dump C_Item.GetItemStats(select(2, C_Item.GetItemInfo("item:<itemID>:0:0:0:0:0:<suffixID>")))` and `/dump C_Item.GetItemStats(<its own link>)` (SKIP when no item with a suffix is found) | The same stats | `/ll why itemID:suffixID` uses the link of a matching piece in here's gear, bank or inbox snapshot; with none, it asks for a link | manual |
| L58 | Item existence by ID (section 13) | Before item 19019 is loaded: `/run print(C_Item.DoesItemExistByID(19019), C_Item.DoesItemExistByID(99999999), C_Item.GetItemInfo(19019))` | `true false nil` | Accept every item ID in commands, named "item N", and drop the "does not exist" error | auto |
| L59 | Shift detail follows the key on a tooltip already shown (sections 12.2 and 13) | `/run local f=CreateFrame("Frame"); f:RegisterEvent("MODIFIER_STATE_CHANGED"); f:SetScript("OnEvent", function(_, e, k, d) print(e, k, d, IsShiftKeyDown()) end)`, then press and release Shift; then, with LootLogic, hover a bag item, keep the mouse still, press Shift and release it | `MODIFIER_STATE_CHANGED LSHIFT 1 true`, then `... 0 false`; the detail appears when Shift is pressed and goes when it is released, with no new hover (note whether it needs one) | The detail is shown only by `/ll why` | manual |
| L60 | Comparison tooltips and chat-link popups can be told from the item tooltip (sections 12.2 and 13) | `/run TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(t) local i=t:GetPrimaryTooltipInfo(); print(t:GetName(), t:GetOwner() and t:GetOwner():GetName(), i and i.getterName) end)`; hover a gear item in the bags with Shift held, so the comparison tooltips show; click an item link in chat; then `/reload` | One line per tooltip: `GameTooltip` with `GetBagItem`; the comparison tooltips with other names (`ShoppingTooltip1`, `ShoppingTooltip2`, from memory); the popup `ItemRefTooltip` with a hyperlink getter. Note each name, owner and getter | Show the line on every item tooltip whose owner is not a character-pane slot, and accept it on comparison tooltips | manual |
| L61 | Every item class and subclass the client names (section 5; extends L8) | `/run for c=0,20 do local n=C_Item.GetItemClassInfo(c); if n then print(c, n) end; for s=0,20 do local m=C_Item.GetItemSubClassInfo(c,s); if m then print(c..":"..s, m) end end end` | Names in numeric order, the loop going on past each gap: they include 7:0 to 7:2, 7:5 to 7:12 and 2:13 to 2:20; note any class or subclass of the section 5 table that has no name | Use a built-in table of the known classes and subclasses (section 5) | auto |
| L62 | The client runs Lua 5.1 (style guide, StyLua `syntax`, the lupa runner) | `/run print(_VERSION, table.unpack ~= nil, unpack ~= nil, setfenv ~= nil, math.pow ~= nil, bit ~= nil)` | `Lua 5.1 false true true true true` (`table.unpack` absent) | Set StyLua's `syntax` to the version found; run the tests with the matching `lupa` runtime (`lupa.lua52`, `lupa.lua53`); remove any 5.1-only call from the code and the style guide (`unpack`, `setfenv`, `math.pow`, `bit`) | auto |
| L63 | The clock and timer calls exist (clock rule, section 17.1), and the TOC version can be read | `/run local t = C_Timer.NewTimer(1, function() print("fired") end); print(type(t), type(t.Cancel)); t:Cancel(); print(GetServerTime(), date("%H:%M:%S", GetServerTime()), GetTime()); print(C_AddOns.GetAddOnMetadata("LootLogic", "Version"))` | `table function`, no "fired" after a second, then an epoch number, a `hh:mm:ss` time and a small number, then the TOC's Version text | Replace `NewTimer` by `C_Timer.After` with a token the callback checks; if `date` or `GetServerTime` is missing, find the client's equivalent and change the clock rule; if `C_AddOns.GetAddOnMetadata` is missing, try the global `GetAddOnMetadata` in `Core/Init.lua` | auto |

---

## 21. Sources

**Installed addons** (beta client, read 2026-10-28):
- **Auctionator 341:** `Source/API/v1/*.lua`, `Source/API/v1/README.md`, `Source_ModernAH/API/v1/RegisterForDBUpdate.lua`, `Source/Utilities/DBKeyFromLink.lua`, `Source/Database/Mixin.lua`, `Source/Constants/Main.lua` (both read again 2026-11-02 for the day count behind the price age), `Source_ModernAH/FullScan/Mixins/Frame.lua` (read 2026-11-02: `C_Item.DoesItemExistByID`), `Auctionator.toc`.
- **AuctionDB (AHDB) v2.6.0:** `AuctionDB.lua`, `History.lua`, `Scan.lua`, `Tooltip.lua`, `Vendor.lua`, `Sell.lua`.
- **EllesmereUIBags 9.6.9:** `EllesmereUIBags_Categories.lua`, `EUI_Bags_Slots.lua` (overlay API), and the Grid, List and Bank files.
- **Other EUI modules:** EllesmereUIBlizzardSkin `_CharacterSheetForever.lua` and `_CharacterSheet.lua`; EllesmereUI Forever Essentials 9.7.2 `_SimplifiedStats.lua` (read 2026-11-02: the client's "Equip:" stat format strings, `TOOLTIP_ITEM_STAT_*`).
- **OutfitterForever v1.9.1:** `Outfitter.lua` (global character copies, events), `OutfitterBaganator.lua`, `OutfitterInventory.lua`, `OutfitterForever.toc`.
- **Questie** (evidence of `WOW_PROJECT_CAMELOT`); **WoW Forever Tracker v57** (`WFT_MARKET`, no API found).
- **Journey Tracker 0.6.13** (evidence that `GetItemStats` and `SendMail` exist on Forever); **Beta client saved data** (captured characters).

**Beta saved data:** captured character files (link format `|cnIQ4:|Hitem:...`, skills fallback) and the Auctionator saved data.

**Game data:** a data dump of build 1.60.1.70532 plus server hotfixes (item classes, stacks, tools, proficiency spells).

**Web:** the Wowhead Forever page for [19828] (crit rating per %); seemeta.com talent calculators (tree names, 2026-10-31); Pawn's Forever files on CurseForge.

**GitHub** (via `gh`, 2026-10-28):
- `Cidan/BetterBags` (main, 2026-10-27): `examples/plugin/plugin.lua`, `data/categories.lua` (category function, reprocess, automation), `core/forever.lua`, `BetterBags_Camelot.toc`, `.claude/rules/camelot-forever.md` (Forever detection, bank tabs, no warbank), commits #1092 (2026-09-18) and #1117 (2026-10-02), releases v0.8.5 to v0.8.9.
- Baganator 838 release files (the CurseForge zip, mirrored at `github.com/austinrr/baganator-mirror`): `API/Main.lua`, `API/EquipmentSets.lua`, `API/ItemButton.lua`, `API/Junk.lua`, `API/Upgrades.lua`, `CategoryViews/ComposeCategories.lua`, `CategoryViews/ItemsPreparation.lua`, `ItemViewCommon/EquipmentSetInfo.lua`, `ItemViewCommon/ItemButton.lua`, `Transfers/AddToMail.lua`, `Transfers/VendorItems.lua`, `Core/Constants.lua`.
- Syndicator 285 release files (the CurseForge zip, repackaged unofficially at `github.com/hippuli/Syndicator`): `API/Main.lua`, `Search/CheckItem.lua`.
- **Bagnon family:** `Jaliborc/Bagnon`, `Jaliborc/BagBrother` (`core/api/rules.lua`, TOC), the BagBrother wiki "Rules-API", `Jaliborc/Bagnonium` (formerly Combuctor, TOC).
- **TOC checks:** `AdiAddons/AdiBags`, `xod-wow/LiteBag`, `Nevcairiel/Inventorian`.
- **ArkInventory:** `arkayenro/arkinventory` (`ChangeHistory.md`), `rockschtar/ArkInventoryCharacterRules`.
- `Bl4ut0/ItemRack-Universal` (`ItemRack.lua`, TOC).
- `ivellos/forever-ledger` (`Core.lua` FullName, `Prices.lua`, `Auctions.lua` cut and deposit, TOC; `docs/TESTING.md`, read 2026-11-02 for the form of an in-game checklist, nothing copied).
- `wowsims/forever` (read 2026-11-01 at commit `2430d539`, folders under `ui/specs/`; MIT, copyright 2022 wowsims team).

**CurseForge** (pages and the CFWidget API, 2026-10-28):
- File version lists and totals: BetterBags (about 4.82M downloads; 101 files tagged 1.60.1 from v0.5.7 on 2026-09-18), "Betterbags - Forever" (`betterbags-forever`, about 7,900 downloads, v0.3.0 2026-10-14), Baganator, Bagnon, ArkInventory, AdiBags, Auctionator, TradeSkillMaster.
- Project pages: ForeverForge Bags, Outfitter Forever, Loadout, Baganator GearSwap, Bagnonium.
- Search for "lootlogic" and "loot logic" (no clash).
