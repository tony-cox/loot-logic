---
name: lootlogic-spec
description: "LootLogic: specification for a shared, standalone WoW Forever addon that sorts every bag item into a destination category (another character, Equip, AH, Vendor, Vendor/AH, or none) and fills those categories in the player's bag addon. Design, data model, algorithm, gear ranking with loadouts, sets, price and bag adapters, UI, tests, build plan and live-client checks. Nothing has run on a live Forever client."

---

# LootLogic: specification

**Status:** v1 is under implementation: milestone M0 is under way (section 19), and this spec is the source of truth for the code in `LootLogic/`. The live client arrives 2026-11-05, so every runtime claim below is graded by evidence, not by test.

**Related:**
- `docs/ux.md`: the UX and workflow design: journeys, tab layouts, the Wants editor, wording and accessibility. This spec says what LootLogic does; the UX document says how it looks and flows.
- `docs/technical-findings.md`: the Forever API findings, other addons, file layout, events, tests and live checks behind this spec. Its section numbers match this spec, and each finding carries its confidence label.
- `docs/decisions.md`: the decision log.

**This spec describes version 1 as the product.** It says what LootLogic needs and what it does with it. Where the game or another addon supplies a fact, and the call that reads it, is never in this spec: it is in technical findings, under the same section number. Changes planned for versions 1.1 and 2 are in sections 22 and 23, each pointing back to the sections it changes.

**Confidence labels used throughout:**
- **confirmed:** seen working on a Forever client, either by a team member or in beta saved data the client wrote.
- **source-read:** read in addon or game-data source that was written and released for the Forever client. Strong evidence the API exists and behaves as the author assumed, but not tested by us.
- **from memory:** retail or Classic API knowledge, not checked in any Forever source.
- **unverified:** a guess or a placeholder.

---

## 1. Summary of decisions

| Topic | Decision |
|---|---|
| Name | **LootLogic**. No clash on CurseForge: searched 2026-10-28, the nearest names are Lootlog, Lootlog Classic, Spoils LootLogger and LootIQ. The project stays private until well tested. Licence: MIT (`LICENSE`; third-party material in `THIRD_PARTY_NOTICES.md`). Sources and licences: section 21. |
| Categories | One per **other** character (labelled with its display name), **Equip**, **AH**, **Vendor**, **Vendor/AH**, and none. **Vendor/AH** holds unwanted, sellable items where LootLogic cannot pick vendor or auction house (no usable price): the choice is the player's. |
| Read-only | LootLogic **never sells, mails, lists on the AH, deletes or moves items**. It **does** register categories in the bag addon and fill them where the bag addon supports it (section 12). Elsewhere it falls back to an overlay on item buttons plus a tooltip line. |
| Core contract | `ClassifyBagSlot` and `ClassifyLink` return a result (fields in section 12.4). Bag adapters are thin. The tooltip line works with any bag addon. |
| Wants | Per character: item class/subclass flags, each with an optional minimum quality, plus per-item include and exclude. Stored in account-wide SavedVariables, edited only in game. Quantity caps are a later addition (section 23). |
| Priority | **Wants:** the current character wins if it wants the item; otherwise the first wanting character in **one global character order** that the player sets in the UI. **Gear:** the current character wins if the item is an upgrade for it, including within the level look-ahead window (both are parameters). Otherwise the biggest score gain wins, with the player's character order as the tie-break. |
| Loadouts | Each character has one or more **loadouts**, each a name plus a spec (weights). The **worn loadout** is the one the character is wearing. A loadout can be linked by name to an **imported set** (section 4), read-only, for labels. Every member of an imported set is protected, linked or not. |
| Gear ranking | Built in: a weighted sum of stats. The baseline is the best owned piece per loadout spec, armour rule and evaluated level (worn, bags, bank, inbox and mail on the way). Gear that is best at any level in the look-ahead window is protected, preserving useful intermediate upgrades without keeping inferior alternatives. |
| Sets | A Protect list; read-only import of set membership from the Blizzard Equipment Manager and Outfitter Forever (members always stay); and the "best owned per loadout spec" protection. |
| Prices | Optional providers: **Auctionator** and **AHDB**. The freshest price wins. **No usable price means Vendor/AH.** That covers no price addon at all, an item not seen, a stale price, or (if enabled) missing from the latest scan. Never Vendor (agreed). |
| AH rule | AH cut %, minimum copper gain and minimum % gain are all settings (defaults 5%, 1s, 10%), combined with AND. The copper floor applies to the whole holding; the % floor applies per unit. |
| Bags | **BetterBags first** (real category API, Forever build). Then Bagnon/Bagnonium rules, the ArkInventory rule function, the EllesmereUI overlay, and the default-bag overlay with the tooltip fallback. **Baganator is deferred** until it has a writable category API (an upstream request); meanwhile it gets the tooltip line only. |
| Recipes | A live "Already known" check for the current character. Without stored knowledge of the other characters, unknown counts as wanted. |

---

## 2. Goals and non-goals

### Goals
1. Every item in the bags, and in the bank while it is open, gets one answer live in game: which other character it goes to, Equip, AH, Vendor, Vendor/AH, or nothing.
2. The town trip becomes mechanical, in whatever order the player likes: **Vendor** items are sold, **AH** items are listed, each character's category is mailed to that character, and **Vendor/AH** is decided by hand. Whatever is left belongs to the current character.
3. Works for any account with several characters. Nothing about any particular account is hard-coded: all nine classes and both factions are handled. English client only (tooltip patterns).
4. Independent of any one bag addon or price addon. Degrades to overlay plus tooltip.
5. No runtime dependency on any gear addon. No embedded libraries.
6. **Licensing.** LootLogic is MIT. The only third-party material it may ship is stat weights computed with the WoWSims Forever sim (MIT, notice included; the sim's own code and presets are not shipped). Other addons are used through their public APIs at run time; none of their code is included (section 21).

### Non-goals
- **Item actions.** Selling, mailing, listing on the AH, deleting or moving items: possible later additions (section 23). Read-only still means categories are registered and filled in the bag addon (section 1).
- **Quantity caps** ("stop at 200"): a later addition (section 23).
- **Swapping gear:** Outfitter, ItemRack and Loadout do that. LootLogic only reads their set membership.
- **Strategy:** keep versus list on the AH for crafting materials stays the player's call. LootLogic only applies the flags the player sets.
- **Price history and trends:** out of scope. Other addons already show them.
- **Holdings tally** across bags, bank and mail for planning: outside the addon.
- **Transmog and appearance collecting.** Forever has appearances: BoE items with an uncollected appearance become soulbound when sold to a vendor (from the 1.60.x beta patch notes).
- **Writing to any other addon's saved data.** BetterBags categories come from a registered function and are ephemeral, not saved (section 12).

---

## 3. User stories

1. **Town trip.** I open my bags at a city. BetterBags shows the sections **Zugar**, **Boneset**, **AH**, **Vendor** and **Vendor/AH**; the rest sits in my usual sections. In any order, I sell Vendor, list AH, mail each name its section, and decide Vendor/AH by hand.
2. **Loot for an alt.** I loot Linen Cloth on the shaman. It appears in the Zugar section, and the tooltip says "LootLogic: Zugar (wants Trade Goods: Cloth)".
3. **Upgrade for me.** A green belt drops that beats my worn belt for my worn loadout. It shows in **Equip** with "LootLogic: Equip (+11% Bear over Thick Hide Belt, worn)".
4. **Upgrade for alts.** A BoE ring beats Zugar's weaker ring by 18% and Boneset's by 6%. It goes to **Zugar** (biggest gain), and the tooltip names both.
5. **Bag set.** My druid has loadouts Bear (worn), Cat and Resto. The best Cat piece for each slot shows no category ("LootLogic: stays (best Cat chest owned)") and is never put in Vendor or AH. When a better Cat chest drops, it becomes the one that stays and the old one is judged like any other item. Items in my Equipment Manager set "Cat" stay too.
6. **Known recipe.** I loot a Blacksmithing plan my paladin already knows while on the paladin. It is not kept for the paladin, so it falls through to AH, Vendor or Vendor/AH.
7. **No price.** A BoE blue never seen on the AH shows **Vendor/AH** ("LootLogic: Vendor/AH (never seen on the AH)"). The same happens for every tradable unwanted item when no price addon is installed.
8. **Wants editor.** `/ll`, Wants tab, pick Zugar, tick Trade Goods: Cloth, add an exclude for Felcloth. Categories update immediately.
9. **Explain.** I shift-hover an item (or `/ll why`) and see why it got its category: matched wants, scores per loadout, prices and thresholds.
10. **First run and checklist.** On the first login a small welcome dialog explains the addon once; a checklist (Status tab, or `/ll status` in M1) shows what is left to set up. Design: `docs/ux.md` sections 2.1 and 2.2.
11. **A new alt later.** I make a new character. One chat line says it was added with an assumed spec; its checklist shows spec and wants open. Design: `docs/ux.md` sections 1.2 and 2.3.
12. **Baganator user.** My bag addon has no sections, so I open the Contents tab and see my bags by category, with counts and estimated cash, and click a row for its items and the reasons. Design: `docs/ux.md` section 3.4.
13. **Want from the item.** I hover Linen Cloth, press the "add hovered item to wants" key, pick Zugar and "all Cloth" or "only Linen Cloth". Design: `docs/ux.md` section 4.4.

---

## 4. Terms

- **Here:** the character currently logged in.
- **Roster:** every character on the account that has logged in once with LootLogic enabled.
- **Eligible destination:** a roster character that has the **same faction and the same region** as here, and is not here. The game refuses mail between factions and between rulesets (confirmed by the team in beta play; live check L26). LootLogic cannot tell a character's ruleset, so it can name a character that the game then refuses mail for (unverified; L53). How region and faction are read: technical findings 5 and 6.

  **Region and ruleset.** Forever has no realms. A player's characters all belong to one region (NA, EU and so on), and there are four rulesets (PvE, PvP, RP PvE, RP PvP) whose characters cannot mail each other (team, beta play). The region is the last part of a character's key (section 6).
- **Tradable:** can be mailed to another of the player's characters. That means not soulbound and not a quest item. BoE-not-yet-bound and unbound items count. Account-bound or warbound-until-equipped items count for routing, never for AH.
- **AH-able:** tradable and not account-bound.
- **Want:** a character's flag for an item class/subclass (optionally with a minimum quality), or an explicit per-item include. A per-item exclude cancels a want.
- **Spec:** a named set of stat weights for one class and role, for example Druid Bear (id `DRUID:bear`; the list of specs is in technical findings 14.1). LootLogic does not detect which spec a character plays: the player picks it, and a new character starts with an assumed one (section 8.2).
- **Loadout:** a name plus a spec, belonging to one character, for example "Cat" with spec `DRUID:cat`.
  - The **worn loadout** is the one the character wears.
  - A loadout may be linked by name to an imported set.
- **Imported set:** a gear set the player already keeps in another addon (an Outfitter Forever outfit) or in the game's own Equipment Manager. LootLogic reads which items are in it, when the player logs in and when the set changes, and never creates, edits or equips one. Where each is stored, and how another character's sets are read: technical findings 9.1.
- **Usable price:** a provider price that exists, is at most `maxPriceAgeDays` old, and (when `requireLastScan` is on and AHDB is available) appeared in AHDB's latest full scan. Auctionator cannot say, so `requireLastScan` is for AHDB (section 11.2). Age is counted in whole days, rounded down; a price with no age is not usable. When both providers have a usable price, the one with the smaller age wins, then `providerOrder`.

---

## 5. What this design depends on

LootLogic relies on the game providing the following. The evidence, the API for each and the confidence label are in `docs/technical-findings.md` section 5.

- Each character's first and last name, region and faction.
- Every bag slot's item: ID, link, count, quality, bound state, vendor price, class and subclass, and its stats (hit and crit as rating points).
- The bank as nine character bank tabs, one included and eight bought one at a time. There is no account (warband) bank.
- Which armour and weapon types a character has learned.
- Equipment Manager sets.
- Item classes and subclasses in the Classic encoding, with display names from the client.
- The AH cut: 5% at the faction AHs. There is no neutral AH that players can post on (team research, 2026-11-02; not seen on a live client).
- Nothing at logout: the client has already cleared character data by then, so LootLogic saves what it needs while the player is in the game.

**How item types shape wants.** A want is a flag on an item type (a class and subclass in the game's own classification), so it takes every item of that type, no more and no less. The game's classification does not always match how a player thinks of items:
- Meat is one type (Trade Goods: Meat). A druid who wants it for well-fed food gets every meat item, whatever it is for.
- An elixir has no type of its own: all elixirs are Consumable: Elixir. A warlock who wants only Elixir of Wisdom cannot use a type want without pulling every elixir, so it uses a per-item include instead.
- Thread is in Trade Goods: Cloth and Salt is in Trade Goods: Leather, so a want for cloth also pulls thread, and a want for leather also pulls salt.

---

## 6. Data model (SavedVariables)

The only SavedVariable is the account-wide `LootLogicDB`. External tools never write it: the game overwrites it at logout. The schema is versioned, and migrations run when the addon loads.

```lua
LootLogicDB = {
    -- 1 in M0 and M1; M2 raises it to 2 (Notes: Migrations).
    schema = 1,
    settings = {
        ah = {
            -- The faction AH cut (section 7.4).
            ahCutPct = 5,
            -- 1s, applied to the whole holding of the item.
            minGainCopper = 100,
            -- Per unit, relative to vendor price.
            minGainPct = 10,
            -- Older = no usable price = Vendor/AH.
            maxPriceAgeDays = 7,
            -- true: the price must be in the provider's latest full scan.
            -- Needs AHDB: Auctionator cannot tell, so with Auctionator alone
            -- this is ignored, and with both only AHDB prices count
            -- (section 11.2).
            requireLastScan = false,
            -- Tie-break when two prices are equally fresh.
            providerOrder = { "ahdb", "auctionator" },
        },
        gear = {
            -- An item may need up to N levels more than the character has.
            lookAheadLevels = 5,
            -- The current character keeps an upgrade it can wear within the
            -- look-ahead (agreed, v1).
            hereWinsInLookAhead = true,
            -- A gain below this is not an upgrade.
            minUpgradePct = 1,
            -- Armour slots: a type below the best wearable one is never an
            -- upgrade or "in use", and counts in a baseline only when worn.
            -- A loadout's armor overrides it (8.3).
            bestArmorOnly = true,
            -- An item with none of the stats the spec weights: compare item
            -- level, labelled "ilvl".
            itemLevelFallback = true,
        },
        -- Characters not seen this long are named in the login chat line; the
        -- bank uses it too.
        staleDays = 14,
        -- The login line about stale characters, the scan summary line, the
        -- mail-recorded line, and the login line about upgrades waiting in the
        -- character's mail (section 13, Settings).
        notify = {
            staleSnapshot = true,
            scanSummary = true,
            mailRecorded = false,
            mailUpgrade = true,
        },
        -- The player's changes only: "stay" or "sell" for "<class>" or
        -- "<class>:<subclass>" when no want matches. The shipped defaults are
        -- in Data/ItemClasses.lua (technical findings 14.1).
        classOverride = {},
        display = {
            tooltip = true,
            overlay = true,
            -- Show a line on tooltips of items not in the bags that nobody
            -- wants. The default in the M0 code is off; M1 changes the
            -- default to on, and M2 changes it back to off, with a migration
            -- that turns it off in saved data.
            tooltipNoWant = false,
            badge = {
                enabled = true,
                position = "TOPRIGHT",
                size = 12,
                smallFallback = 26,
            },
            -- "default", "colorblind", or "auto" (follow the client CVar).
            palette = "auto",
        },
        -- No baganator entry until a category API exists (section 12.3).
        adapters = {
            betterbags = { enabled = true },
            bagbrother = { enabled = true },
            arkinventory = { enabled = true },
            ellesmere = { enabled = true },
            blizzard = { enabled = true },
        },
    },

    ui = {
        -- Set when the first-run welcome dialog is closed either way.
        firstRunDone = false,
        lastTab = "contents",
        wantsFor = nil,
        scale = 1,
        point = nil,
        checklistHidden = false,
        minimap = { hide = false, angle = 215 },
        -- Acknowledged checklist lines ("gear only", "tooltip only").
        ack = {},
        -- Open the Contents tab at the merchant, AH or mailbox.
        autoOpenContents = false,
    },

    -- Global priority, set in the UI.
    order = {
        "Chamoomile Rejuvenade-<region>",
        "Boneset Hallowine-<region>",
        -- ...
    },

    characters = {
        ["Chamoomile Rejuvenade-<region>"] = {
            first = "Chamoomile",
            last = "Rejuvenade",
            region = "<region>",
            faction = "Horde",
            class = "DRUID",
            race = "Tauren",   -- the client's race token (unverified; L3)
            level = 23,
            -- nil: true; false: no gear upgrades routed to it (step 3b); its
            -- wants still apply (bank alts).
            receivesGear = nil,
            -- Optional override, at most 14 characters; nil = automatic (see
            -- Notes).
            displayName = nil,
            lastSeen = <epoch>,
            build = "1.60.1.xxxxx",
            lootLogicVersion = "1.0.0",

            -- At least one; exactly one has worn = true; spec may be nil in M1
            -- only (8.2).
            loadouts = {
                {
                    name = "Bear",
                    spec = "DRUID:bear",
                    worn = true,
                    assumed = false,
                    link = { source = "outfitter", set = "Tank" },
                },
                {
                    name = "Cat",
                    spec = "DRUID:cat",
                    link = { source = "equipmentset", set = "Cat" },
                },
                {
                    name = "Resto",
                    spec = "DRUID:restoration",
                    -- nil = use the setting, "best" or "any" (8.3).
                    armor = "any",
                },
            },

            -- Read-only membership, refreshed at login and on set-addon
            -- events.
            importedSets = {
                ["outfitter:Tank"] = {
                    source = "outfitter",
                    name = "Tank",
                    updatedAt = <epoch>,
                    items = { { id = <itemID>, suffix = <suffixID> }, ... },
                },
                ["equipmentset:Cat"] = {
                    source = "equipmentset",
                    name = "Cat",
                    updatedAt = <epoch>,
                    items = { { id = <itemID>, suffix = <suffixID> }, ... },
                },
            },

            -- Snapshot of the known proficiency spells.
            proficiency = {
                updatedAt = <epoch>,
                spells = { [9077] = true, [198] = true, [199] = true, ... },
            },

            -- Equipped: slots 1 to 19. Shirt 4 and tabard 19 are stored but
            -- ignored in scoring.
            gear = {
                updatedAt = <epoch>,
                slots = { [1] = link, ..., [19] = link },
            },
            -- Bags 0 to 5.
            bags = {
                updatedAt = <epoch>,
                gear = { link, ... },
                ids = { [itemID] = count },
            },
            -- Tabs 6 to 14, only while the bank is open.
            bank = {
                updatedAt = <epoch>,
                gear = { link, ... },
                ids = { [itemID] = count },
            },
            inbox = {
                updatedAt = <epoch>,
                gear = { link, ... },
                ids = { [itemID] = count },
            },
            -- Sent by the player's own characters, not yet seen in their
            -- inbox.
            inbound = {
                {
                    sentAt = <epoch>,
                    from = <characterKey>,
                    id = <itemID>,
                    link = link,
                    count = 1,
                },
                -- ...
            },

            -- The character's wants: types, and specific items.
            asks = {
                -- "class:subclass", or "class:*" for a whole class, each with
                -- an optional minQuality, for example
                -- ["4:*"] = { minQuality = 2 }.
                types = { ["7:8"] = {} },
                -- [itemID] = "include" or "exclude".
                items = {},
            },

            -- A plain item ID (every roll), or an instance key
            -- (itemID:suffixID) for one roll.
            protect = { ["<itemID>"] = true, ["12345:-17"] = true },
        },
    },

    -- No weights table: the shipped weights are read-only
    -- (Data/WeightTables.lua).

    protectGlobal = {},
    debug = {
        enabled = false,
        -- Log lines are "[hh:mm:ss] <area>: text".
        log = {},
        maxLog = 300,
        -- probe = { updatedAt, build, results }
        probe = nil,
    },
}
```

**Notes:**
- **Character key:** first name, a space, last name, a hyphen and the region ("Chamoomile Rejuvenade-<region>"). A character always has a first and a last name, so the key has no one-name form. How the parts are read: technical findings 6.
- **Item keys:** an item instance is `itemID:suffixID` (suffix 0 when none). An imported-set member whose roll is not known when it is imported is stored with suffix 0, and in step 1c it matches every roll of its item ID. Imported-set and loadout items store the two parts as `id` and `suffix`.
- **Migrations:** `migrations[n]` upgrades schema n-1 to n, in order (M2 raises `schema` to 2: `migrations[2]`, written and tested in M2 with the tables it assigns, turns `tooltipNoWant` off and applies the spec changes of section 8.2; M0 builds the framework with schema 1 and no migration), and defaults are deep-filled afterwards without overwriting. Deep-fill merges tables key by key; a list (`providerOrder`, `order`) is one value, kept whole when saved; a saved value of a different type from its default is replaced by the default; keys the code does not know are kept. If the saved schema is newer than the code, LootLogic leaves `LootLogicDB` unchanged for the session (no snapshots, no `lastSeen`, and commands that change data refuse), classifies from what is stored, and says so once, with the chat line "LootLogic: saved data is newer than this version and is left unchanged." (technical findings 14). A migration that fails is treated the same way, with the line "LootLogic: saved data could not be upgraded and is left unchanged."
- **Display name:** the one name used for a character everywhere (bag sections, Wants buttons, Characters tab, tooltips, slash commands).
  - **Automatic:** the first name. If two or more registered characters share a first name (eligible or not, so a name does not change when eligibility does), each gets the first name, a space, and one letter of its surname: the letter at the first position where its surname differs from every other surname in the group, ignoring case, where a position past the end of a shorter surname counts as different ("Zugar Sou" and "Zugar Sun" become "Zugar o" and "Zugar u"; the surnames Tan and Tna give "a" and "n", and Sou and Sunny give "o" and "u"). A surname that is the start of another gets the first name alone ("Chamoomile Rocketship" and "Chamoomile Rocketships" become "Chamoomile" and "Chamoomile s"). The result is at most 14 characters (a first name of up to 12 letters, a space and a letter). When this does not give every character in the group a name of its own (two would get the same name, or a surname has no such letter and is not the start of another: with Tan, Tna and Tnn, Tan and Tna would both get "a" and Tnn would get none), every character in the group gets its full "First Last" (up to 25 characters), as it does when two surnames are the same ignoring case.
  - **Override:** the player can set `displayName` per character on the Characters tab, at most 14 characters and unique among registered characters. It replaces the automatic name. A character that registers later never changes or clears it.
  - **Clash with an override:** an automatic name never equals another character's override. When it would, that character gets its full "First Last" instead; if that also equals an override, it gets a number as well, the first free one from 2 ("Foo Bar 2"; up to 27 characters).
  - **Computed, not stored,** unless overridden. Registering a character with the same first name as an existing one can rename the existing one's section once.
  - **Narrow places** (buttons, badges) cut a long display name with an ellipsis and show the full name on hover.
  - **Slash commands** accept a display name or the full "First Last". A display name wins: a command tries an exact display-name match first, and a full name only when no display name matches, so a character whose override is "Foo Bar" is named by "Foo Bar" even when another character's full name is Foo Bar. An ambiguous name does nothing and says which names to use. A first name alone is also accepted when only one character has it and no display name matches.
- **New characters:** they get one loadout, named after its spec (for example "Cat"), or after the class (the client's class name, such as "Mage") when M1 gives it no spec, with `worn = true` and the class's **assumed spec** (section 8.2) and `assumed = true`. The UI asks for the real spec; picking one replaces it and clears the flag. A new character's key is appended to the end of `order`. In M1 a class with no weight table gets `spec = nil` with `assumed = true` (section 8.2); `/ll reset <name>` recreates the loadout the same way.
- **Stats are never stored.** Links are stored as strings, and stats are re-read from the game on the current client.

---

## 7. Classification algorithm

### 7.1 Inputs (item facts)
For every item LootLogic needs the facts below. Where each comes from in the game, and the call that reads it, is in technical findings 7.1.
- **Identity:** item ID, link, stack count and quality.
- **Bound state:** whether the item is soulbound, and `isAccountBound`: whether it is bound to the account rather than one character (live check L24).
- **Type:** class, subclass and equip location (the slot type it is worn in).
- **Binding and level:** when the item binds (on pickup, on equip), and its required level.
- **Quest item:** whether the item is a quest item.
- **No vendor value:** whether vendors refuse the item.
- `classRestriction`: the classes allowed to use the item, if it names any (live check L51).
- `unique`: whether the item is unique-equipped (live check L21).
- `vendorPrice`: what a vendor pays per unit, forced to 0 when the item has no vendor value or when AHDB marks it unsellable (section 11.2).
- `itemLevel`: the item level, used for `itemLevelFallback` (source-read, technical findings 7.1).
- `knownHere` (recipes and class books only): whether the current character already knows it (from memory; technical findings 10).
- `unscoredEffect` (gear only): whether the item has an effect that is not one of its stats: a use effect, a chance on hit, or an "Equip:" effect that is not a stat (section 8.1; technical findings 7.1, live check L56).
- `holding`: the total count of this itemID in the container being classified (bags or bank). Used by the AH rule.

The facts of an item whose data the game has not loaded yet are incomplete: the item is pending (step 0). The names of the slot fields are live check L7 and the link format is L52.

### 7.2 Order (first match wins)

```
classify(slot, here):
 0  PENDING   facts incomplete (item data not loaded yet) -> no category; request load; reclassify when the data loads
 1  HARD STAY (no category, with a reason)
    a quest item (class 12 or quest info), key (class 13), WoW Token (18), or an item on the never-touch list (Hearthstone)
    b on a Protect list (here, or global)
    c a member of one of here's imported sets (Outfitter, Equipment Manager)
    d profession tool (2/14, 2/20, or the built-in tool list: Flint and Tinder, runed rods, ...) unless the tool is tradable and a want by here or any eligible character matches it (step 4 then decides who); a soulbound tool always stays
    e soulbound (account-bound items count as tradable, section 4) and vendorPrice == 0 and not gear (step 3 decides gear first; gear left over reaches step 6 and gets `novalue`): "no vendor value", unless a want by here matches
 2  GREY      quality 0:
    here includes the item ID -> none (reason `wantedhere`)
    another eligible character includes it and it is tradable -> that character (the first such character in the order; reason `wanted`)
    otherwise VENDOR if vendorPrice > 0 (reason `grey`), else none (reason `novalue`)
 3  GEAR      equippable armour or weapon (equipLoc set; not shirt, tabard, ammo, bags, quivers, cosmetic armour 4:5, or a profession tool from step 1d). Evaluated in the order 3a, 3c, 3b, once the owned pieces they compare with have loaded (until then the item is pending, as in step 0; 8.4, pieces still loading):
    0 here has a loadout with no scoreable spec (`spec = nil`, or a saved spec with no weight table in this build): a bag or bank item that is equippable gear stays, reason `nospec`, and the steps below are skipped; for a link-only result, a mailbox attachment included (it is link-only for this rule), 3a and 3c are skipped and 3b runs
    a here, usable now and an upgrade under the spec of the worn loadout (the worn loadout) -> EQUIP
      here, required level above here's level but within lookAheadLevels, and an upgrade under any of here's loadout specs (the reason names the loadout when it is not the worn one):
         hereWinsInLookAhead -> none, reason `equipat`
         otherwise -> continue to 3b (if nobody else wins: none, reason `equipat`)
      an item here can use now that is an upgrade only under a loadout that is not worn is not a look-ahead item: it skips 3a and reaches 3c (`inuse`)
    b tradable and not "in use" for here (3c): every eligible character c with Receives gear on, that can use it within lookAheadLevels
         and for whom it passes the upgrade test of 8.4 (so the minimum upgrade % applies)
         -> the c with the largest relative gain (ties: first in the player's character order) -> CHARACTER(c)
         a character's gain is its best gainPct over its loadouts; the tooltip names that loadout
    c "in use": a best owned piece at any level from here's current level through the look-ahead window, for one of here's scored loadout specs in its slot group (for the main-hand, off-hand and two-hand groups, only a winning set at that level; section 8.6) -> none (reason `inuse`)
       This runs after 3a, so a new arrival that beats the worn piece still gets Equip. In 3c the candidate counts as owned under every loadout spec: under the worn loadout's spec 3a has taken every upgrade, so a candidate that is best there but below `minUpgradePct` (or tied with a piece of a different link) stays as `inuse`; under another loadout's spec a better piece becomes a winner at the levels where it is best and stays. A replaced piece reaches the later steps (other characters, wants, then the sell rules) only when it no longer wins at any level in the window for any scored loadout.
    d otherwise continue to step 4 (wants can still claim gear, for example a disenchanter), except an item whose 3a result was `equipat`, which stops at none
 4  WANTS     wanters = characters whose wants match (7.3), minus excludes and class restrictions (an item include is exempt from the restrictions)
    here in wanters -> none (reason `wantedhere`)
    tradable: first eligible wanter in the global order -> CHARACTER(wanter)
 5  STAYS     disposition for (classID[:subclassID]) == "stay" -> none. Lookup: the player's class:subclass override, the player's class override,
            the shipped class:subclass, the shipped class, then "stay"
 6  SELL
    not AH-able (soulbound, account-bound, BoP): VENDOR if vendorPrice > 0 (reason `vendorbound`), else none (reason `novalue`)
    AH-able:
      no usable price (no provider installed, never seen, older than `maxPriceAgeDays`,
        or requireLastScan with AHDB and not in the latest scan)  -> VENDOR/AH  (never Vendor: agreed)
        (an item with vendorPrice == 0 keeps this answer; its reason adds "; no vendor value", 7.6)
      AH rule (7.4) passes                            -> AH
      vendorPrice > 0                                   -> VENDOR (reason `vendor`)
      otherwise                                         -> none (reason `belowthreshold`)
 7  none
```

### 7.3 Want matching
For character `c` and item `i`, in order:
1. `c.asks.items[i.itemID] == "exclude"`: no match.
2. `c.asks.items[i.itemID] == "include"`: match, whatever the quality, the class restriction and a known recipe.
3. Otherwise a match if `c.asks.types["class:subclass"]` or `c.asks.types["class:*"]` exists and `i.quality >= minQuality` (when a minimum is set). If both exist with different minimums, it is a match if either matches.
4. Class restriction: if the item names classes and `c.class` is not among them, no match. This keeps "Recipe: Book" wants safe.
5. Recipes (class 9): if `c` is known to already know the recipe, no match (section 10). LootLogic knows this for here only.

**Priority among other wanters:** the order of `LootLogicDB.order`, one global order in v1. The same order breaks ties on gear gain (step 3b). Known limitation: wants and gear ties cannot have different priority orders.

**Why there is no per-want ordering:** with flags only, every unit of an item goes to a single winner, so per-want order only changes *who* wins. Per-item excludes already let the player choose that: exclude Solid Stone on the paladin and it goes to the warlock. Per-want order earns its place with quantity caps, when two wanters should share. Per-want order is a later addition (section 23).

### 7.4 AH rule (all three inputs are settings)

```
unit        = provider min buyout per unit (copper)
net         = floor(unit * (1 - ahCutPct / 100))
gainPerUnit = net - vendor            (vendor = vendorPrice, section 7.1)
gainTotal   = gainPerUnit * holding    (all units of this item in the container being classified, bags or bank: one listing action)
AH  when  gainTotal >= minGainCopper
       and  gainPerUnit > 0
       and  (vendor == 0  or  gainPerUnit * 100 >= vendor * minGainPct)
```

**Worked example:** 120 Linen Cloth at a net gain of 1 copper each makes 120 copper, which clears a 1 silver floor. A single item with a 1 copper gain does not. The percentage rule stays per unit, so the example holds with a vendor price of 0 or `minGainPct = 0`.

How the settings interact:
- **AND.** The absolute floor stops postings worth a few copper. The percentage floor stops items whose vendor price is already close to what the AH pays.
- **The cut is applied first,** so it moves every item toward Vendor.
- **`minGainPct` only bites on items with a vendor value.** Items vendors refuse are judged on `minGainCopper` alone.
- **Defaults are starting values only:** 5%, 1s, 10%. Setting both thresholds to 0 gives the simplest rule: list when the gain after the cut is above 0.
- **The deposit is not counted.** It comes back with a sale and is only lost on unsold auctions. A later stage may add an "expected sale rate" factor.
- **Vendor/AH is not part of this rule.** It is decided before it: no usable price means Vendor/AH.

### 7.5 Edge cases

| Case | Handling |
|---|---|
| Stacks and partial stacks | No quantities in v1. Every stack of one itemID in the same container (the bags, or the bank while it is open) gets the same category on this character; the bags and the bank can differ, because the AH rule counts each container's holding (a bag addon that caches per item ID may show one container's result for both; the tooltip shows each container's own: technical findings 12.4). Gear is judged per instance (link plus bound state). Quantity caps, if added, will split by whole stacks (section 23). |
| Same item on different characters | It can be "mine" (no category) on one character and in Zugar's section on another. Accepted. |
| Soulbound | Never routed and never listed. Equip if it is an upgrade for here; otherwise the hard stays, "in use" (3c), here's wants and the class dispositions apply as for any item, and what is left goes to Vendor, or none with no vendor value. BoP items inside the loot-trade window count as bound. |
| BoE, not yet bound | Tradable and AH-able. |
| Account-bound or warbound | Routable to an eligible character. Never AH. Otherwise as for soulbound. |
| No price addon installed | Same as "no usable price": every AH-able unwanted item goes to Vendor/AH. Greys and bound items still go to Vendor. |
| Quest items | Always stay (step 1a). |
| Consumables | Stay unless a want matches. A want on a consumable type pulls that type from every character that does not want it too, so the UI warns when class 0 is ticked. |
| Containers (bags) | Stay by default. A larger bag is not an "upgrade" (out of scope). |
| Unique and unique-equipped | Not an upgrade target for another character that already owns one (worn, bags, bank, inbox, inbound). For here, a duplicate unique ring whose twin is worn is compared only against the slot holding its twin; when the twin is in the bags, bank or mail, the duplicate is compared with the usual baseline (the weaker of the best two, 8.4, which never includes two copies of one unique item). |
| Item with no bag slot (link only: AH, vendor window, chat link, mailbox attachment, `/ll why <link>`) | Only the **wants** step (4) and the **gear** step (3) run, because such an item has no bound state, stack count or holding. A result is returned once the item's data has loaded (none while pending, as for bag items). It keeps the reason of the step 3 or 4 branch that matched, treating the item as tradable in steps 3b and 4. Step 3c does not apply (an item that is not owned is not an owned piece), so the code is one of `equip`, `equipat`, `gearfor`, `wanted`, `wantedhere` or `nobody`; a mailbox attachment is the exception, below, except that under `nospec` (step 3-0) it is link-only like any other link: 3a and 3c are skipped and 3b runs. The result has `linkOnly = true` and "; not in your bags" added to the reason text; it is never AH, Vendor or Vendor/AH. When nobody wants the item and it is an upgrade for nobody, the category is none with reason `nobody`, and the tooltip shows a line only when `display.tooltipNoWant` is on (off by default, on in the M1 test build): a dim "nobody wants this (not in your bags)", so silence is not mistaken for a fault. An item whose data is not loaded shows nothing. Link-only results are never counted in the Contents tab. **Mailbox attachment:** it is an owned piece. One mailbox copy with the same link (for a piece of inbound mail classified for the login line, one inbound copy) is left out of here's owned pieces, as a bag candidate's own instance is, and step 3c runs for it as for a bag item, so a better piece for a stowed loadout reads `inuse` in the mailbox ("stays (best Cat chest owned; not in your bags)"), as it will once taken ("stays (best Cat chest owned)"). For a grey (quality 0) item only step 2's include rule runs (`wantedhere`, or `wanted` for another eligible character's include), as in the bags. What each case supplies to LootLogic, and the cache keys, are in technical findings 7.5 and 15. |
| Items awaiting cache data | PENDING: no category and no overlay. Reclassified when the data loads; one request per item per session. Gear is also pending while an owned piece its comparison needs is loading, for at most 10 seconds (8.4, pieces still loading). |
| Items fitting no category | None. They keep their normal bag-addon category or section. |
| Hearthstone, Soul Shards | Hearthstone: the never-touch list (step 1a). Soul Shards: the 15:1 class default "stay" (step 5). |
| Random-suffix gear ("of the Eagle") | Stats come from the link, so each roll is scored on its own. Price addons may give all rolls of an item one shared price, unless the game gives each roll its own item ID (unverified; technical findings 7.5). |
| Refundable purchases | Classified normally. The tooltip adds "refundable" when the game says the purchase is refundable (from memory; L55). |
| Opposite-faction or other-region characters | Never destinations. Shown greyed in the roster. |
| Renamed, transferred or deleted character | The game gives it a new key (or none), so the old entry stays in the roster and stays a destination until forgotten (M2). In M1, `/ll reset <name>` (which clears its wants) and then `/ll gear <name> off` stop routing to it; from M2 the stale line names it after `staleDays`. Whether Forever allows renames is unverified. |
| Character not logged in since a level-up | Snapshot data can be stale, but an idle character's snapshot is still correct unless it was played without LootLogic. Tooltips carry no age warning. Once per session, at login, one chat line names the characters not seen for `staleDays` (14) that can receive gear; the Characters tab and Status show every age. |
| Item in the bank | Classified the same way while the bank is open, for adapters that show the bank. |
| Worn gear from several loadouts | A character may wear pieces that belong to different loadouts, or to none. Nothing depends on which loadout a worn piece came from: every worn piece counts as owned under every loadout spec (8.4); Equip is judged under the worn loadout's spec only (3a); a worn piece that is the best owned one for another loadout's spec is "in use" for it (3c); and a worn piece that is a member of an imported set is a hard stay (1c) whatever it is worn with. |
| Combat | Classification uses item data only, so it is safe in combat. Heavy recomputes wait until combat ends. All values pass a guard against values the game hides in combat (live check L25). |

### 7.6 Reasons and wording

Every result carries one reason code and one reason text. The tooltip is `LootLogic: <category> (<reason>)`, where the category is the character's display name, Equip, AH, Vendor, Vendor/AH or "stays" (the category "none"). The Contents tab shows the same reason text when an item icon is hovered, and Status and `/ll why` use the same codes. Text in `<angle brackets>` is filled in; gear reasons add "(assumed)" when the spec is assumed.

| Code | Category | Reason text |
|---|---|---|
| `wanted` | character | wants <type or item> |
| `wantedhere` | none | wanted by you: <type or item> |
| `gearfor` | character | +18% <Loadout> over <item> (and the next character's gain, if any); when the baseline is a pair (8.4), <item> names both pieces ("over Bonecracker and Buckler"). "; at level N" is added when the item's required level is above that character's level. |
| `equip` | Equip | +11% <Loadout> over <item>, <location>; when the baseline is a pair (8.4), each piece is named with its location ("over Bonecracker, worn, and Buckler, bags") (and "(main hand)" or "(off hand)" for a one-hand weapon judged in both hands) |
| `equipat` | none | equip at level N (and the loadout, if not the worn one) |
| `inuse` | none | best <Loadout> <slot> owned (the worn loadout is named if it is one of several, else the first in the list; the slot word comes from `Data/Slots.lua` (technical findings 14.1), for example chest, ring, trinket, two-hander, main-hand weapon or off-hand) |
| `nospec` | none | no gear advice for <class> in this build |
| `quest` | none | quest item, key or token |
| `nevertouch` | none | always kept |
| `protected` | none | on the Protect list |
| `inset` | none | in set <name> (and its loadout, if linked) |
| `tool` | none | profession tool |
| `novalue` | none | no vendor value |
| `classstay` | none | kept by the class setting |
| `noprovider` | Vendor/AH | no price addon |
| `noscan` | Vendor/AH | no AH price yet: scan |
| `neverseen` | Vendor/AH | never seen on the AH |
| `stale` | Vendor/AH | price N d old, max M; was <price> each (<provider>) |
| `notinscan` | Vendor/AH | not in the last scan |
| `ah` | AH | <price> each, +<gain> over vendor after the <cut>% cut; <provider>, <age> (<gain> is per unit, `gainPerUnit` in 7.4, like <price>) |
| `vendor` | Vendor | AH gain below threshold; sells for <price> each |
| `vendorbound` | Vendor | bound, sells for <price> each |
| `grey` | Vendor | grey item, sells for <price> each |
| `belowthreshold` | none | AH gain below threshold, no vendor value |
| `nobody` | none | nobody wants this (not in your bags) |
| `error` | none | the error text in `docs/ux.md` 6 |

When the baseline is 0 because a slot is empty (nothing owned in the slot group, or one ring or trinket owned and the second slot empty), `equip` and `gearfor` read "<Loadout>, empty <slot> slot" (<slot> is the slot word from `Data/Slots.lua`, as for `inuse`; for example "LootLogic: Zugar (Affliction, empty ring slot)"); an empty-slot runner-up reads "; Boneset, empty ring slot". Gear reasons add " (assumed)" after the loadout when its spec is assumed, " (ilvl)" when the comparison used item level, a runner-up clause ("; Boneset +6%") on `gearfor`, "; train <skill> first" when a weapon skill, armour type or Dual Wield is untrained but trainable, and "; effect not scored" when the item has an effect that is not scored (`unscoredEffect`, 7.1). Any bag item's reason adds "; refundable" for a refundable purchase. A Vendor/AH reason adds "; no vendor value" when the item has no vendor value (7.2 step 6). For `nobody` and `error` the line has no category word: "LootLogic: nobody wants this (not in your bags)" (only with `display.tooltipNoWant`) and "LootLogic: error on an item, see /ll status.". Items still loading have no result and no line. Any result for a piece that would be "in use" for a loadout that is not worn but for one better piece the character owns adds "; a better <loadout> <slot> is <where>" (<where> is worn, in your bags, in your bank or in your mail), whatever the category, for example "LootLogic: AH (12s 30c each, ...; a better Cat chest is in your bags)".

**Which no-price reason is shown.** With no available provider: `noprovider`. With providers but no scan data at all (AHDB with no scans, by its `HasData`; for Auctionator, no item classified this session has a price, where a price with no age counts as a price: technical findings 11.2): `noscan`. The first price any provider returns in a session bumps the price generation, so results that showed `noscan` before it are recomputed (the bump runs just after the current `Prices.Best` call returns: technical findings 14). Otherwise the most informative failure across providers: `stale`, then `notinscan`, then `neverseen`; when several providers fail with the same code the reason carries the one with the smallest age. An Auctionator price with no age (older than 21 days) counts as `stale` ("over 21 d").

**Words in reasons.** A type is named by its subclass when no other class or subclass has that name ("Metal and Stone"), otherwise "Class: Subclass" ("Trade Goods: Cloth", "Trade Goods: Trade Goods"). A location is one of worn, bags, bank or mail. A whole-class want is named by its class ("Armor"). When several wants match, the reason names the item include, else the subclass want, else the class want.


---

## 8. Gear ranking

### 8.1 Stats
- **Source:** the stats the game reports for the item link, cached per link for the session.
- **Mapping:** the game's stat names map to canonical keys (the table is `Data/ItemMods.lua`, technical findings 14.1): `STR AGI STA INT SPI ARMOR AP RAP SP SPDMG HEAL HIT CRIT HASTE MP5 HP5 DEF DODGE PARRY BLOCK BLOCKVALUE BONUSARMOR EXPERTISE SPELLPIERCING DPS_MH DPS_OH DPS_RANGED RES_<school> SP_ARCANE SP_FIRE SP_FROST SP_HOLY SP_NATURE SP_SHADOW`. School power is kept per school, because the sim weights each school separately. Hit, crit and haste are one rating each on Forever (melee, ranged and spells alike; source-read in the sim, unverified in game, L20), so each has a single key.
- **Weapon DPS:** the item's DPS stat is scored as `DPS_RANGED` for a ranged weapon, `DPS_MH` for a two-hander or a weapon judged in the main hand, and `DPS_OH` for a weapon judged in the off hand. A one-hand weapon therefore has a main-hand score and an off-hand score, and each hand's term in 8.4 uses that hand's score.
- **Unknown keys** are ignored and logged once in debug.
- **Weapon speed** is not among the item stats and has no canonical key: no table weights it (the stat map in technical findings 14.1 has no speed stat), so it is not scored. Where it could be read from if a later table weighted it: technical findings 8.1 (L22).
- **Equip effects:** on Forever, hit, crit and spell power are item stats (section 5), and the game shows such a stat as an "Equip:" line (source-read, technical findings 7.1), so most "Equip:" text is a stat and is scored. Any other effect (a use effect, a chance on hit, or an "Equip:" line that is not a stat) is **not** scored (a deliberate limit of v1); the reason adds "; effect not scored" (section 7.6). A set bonus is not an effect of the item and adds nothing. How a stat line is told from an effect is live check L56.

### 8.2 Weights
- `score(item, spec) = sum(weight[k] * value[k])`.
- Weights are per canonical key, **per rating point**, and per spec id (`CLASS:spec`).
- **One table per spec**, shipped in `Data/WeightTables.lua`. Each table has one of two sources (technical findings 14.1 lists which spec has which): weights the team computes with the stat weights engine of the WoWSims Forever sim (`wowsims/forever`, MIT, notice shipped with the addon) for every spec the sim can simulate, recorded as the team's own with the sim commit and inputs; and, for the healers (Paladin Holy, Shaman Restoration, Druid Restoration, Priest Discipline and Priest Holy), weights the team writes by hand from documented assumptions, labelled as team judgement and unverified. The sim's shipped preset weights are not shipped: they are snapshots of the sim at the commit that wrote them and go stale as the sim changes, so the team compares its computed tables with them as a cross-check and explains large differences. The sim cannot simulate the first three, and for the two Priest healers it has the heal spells but no healing rotation, so a computed table would rest on a rotation the team wrote. When the sim implements healing and ships a healer rotation, the five tables are computed too. The Classic and Season of Discovery sims, GearSetImprover and Pawn's default scales are not used. Every spec in `Data/Specs.lua` has its own table; no spec borrows another's. Until a spec's table is written (M1 to M4) it is not offered: the spec pickers and `/ll loadout` list only specs that have a table, so a newly chosen spec always has weights, and the Weights tab lists the same specs. A saved loadout may name a spec unavailable in this build; its saved value is preserved, but it is treated as no spec for scoring and protection (8.5).
- **Tank tables.** The Druid Bear and Paladin Protection tables combine two of the sim's results, threat and survival, in the proportion the sim uses for its own Warrior Protection weights (technical findings 14.1). Such a table values a tank in a group, where holding threat matters, so a stat that costs threat can weigh below 0 even when it helps survival (Paladin Protection's dodge and parry do; observed in the team's runs, with the threat term as the cause unverified), and its label says that it assumes group tanking. Tables that weigh survival alone, for a tank levelling on its own, are a later addition (section 23).
- **Table shape:** per spec id, the source (for a computed table, the sim commit and the inputs used; for a hand-written table, team judgement), confidence, weights by canonical key, and the list of percent-based keys (technical findings 14.1). Stats in the sim's table that Forever items do not carry or that have no key (placeholder resistances, health, mana) are dropped. A spec whose source does not weight EXPERTISE or SPELLPIERCING gives them weight 0.
- **Rating conversion.** The tables the team computes with the sim are already per rating point and need no conversion. A table the team writes by hand per 1% has its hit, crit, haste, dodge, parry and block weights (the keys in its percent list) divided by a rating-per-% at load. The values are the sim's level 60 conversions: hit 10, crit 14, haste 10, dodge 12, parry 15 and block 5 rating per 1% (source-read in the sim; 14 for crit at 60 is also a known tooltip value), marked unverified until L20. DEF is used per point as the sim gives it until L20 says whether items give defense as skill or rating, unverified. Whether rating-per-% changes with level on Forever is unverified (low-level items carry the same 14 crit as level 60 ones; L20), so the conversion is one function of level applied to the same table, giving the level 60 values at every level until L20 says otherwise; a second table is not needed. The Weights tab labels each table with its source and confidence, for example "WoWSims Forever, unverified in game".
- **Assumed spec per class.** A character with no chosen spec gets its class's assumed spec (our placeholder judgement of the most popular levelling spec, unverified): Warrior Arms, Paladin Retribution, Hunter Beast Mastery, Rogue Combat, Priest Shadow, Shaman Enhancement, Mage Frost, Warlock Affliction, Druid Cat. The loadout is marked `assumed`, tooltips say "(assumed)", and the checklist suggests picking the real spec. The tables for these nine specs ship from M2; M1 uses the four tables in the "Specs needed in M1" bullet below.
- The weights are **read-only**: the Weights tab (section 13) shows each spec's table with its source and confidence label, and nothing can be edited.
- **Specs:** every spec in `Data/Specs.lua` (technical findings 14.1) has its own table in `Data/WeightTables.lua` by M4, each with its source and a confidence label. The data is ready before release (milestone M4), so a public player of any spec gets a ranked result.
- **Specs needed in M1:** Druid Bear, Shaman Enhancement, Paladin Protection and Warlock Affliction, the specs of the four characters used to test M1. All four are computed by the team with the sim (technical findings 14.1). M1 is not published. In M1 the assumed spec of those four classes is that spec (Bear for Druid, Protection for Paladin), so a new character of those four classes always starts on a spec with a table. M0 ships these four tables only; tables used by tests live in the test fixtures and are never shipped. A character of any other class has `spec = nil` in M1: wants and prices work, and its equippable gear stays (reason `nospec`). The M2 migration gives every `spec = nil` loadout its class's assumed spec and re-assigns only loadouts still marked `assumed` (Druid Bear to Cat, Paladin Protection to Retribution), never a spec the player chose; the real specs are chosen with `/ll loadout` in M1 first (L54). M2 adds the remaining assumed-spec tables and returns the assumed specs to the list above.
- **Sources:** the weights are computed with the WoWSims Forever sim (MIT, notice shipped), or, for the healers, are the team's own judgement. Scoring is a linear weighted sum against the best owned piece, as a percentage gain (rules in 8.2 to 8.6).

### 8.3 Can this character use it

| Check | Here (live) | Another character (last saved snapshot) |
|---|---|---|
| Required level | `reqLevel <= level` (Equip), or `level < reqLevel <= level + lookAheadLevels` (the look-ahead, section 7.2, 3a) | `reqLevel <= c.level + lookAheadLevels` |
| Armour type | The armour types the character has learned (cloth, leather, mail, plate). For a look-ahead item, the class table (the level at which the class learns each type). An unlearned type that the class table gives at or below the level the item is judged at counts as usable, with the tooltip "train <type> first" | The saved list of learned types, plus the class table for a type not yet learned, as for weapons. For look-ahead across level 40 (mail for shamans and hunters, plate for warriors and paladins) the class table is **Classic baseline, unverified for Forever** (technical findings 14.1). |
| Weapon type | The weapon types learned (a weapon type that needs no training is always usable) | The saved list, plus the class table (unverified) for skills not yet trained. An untrained but trainable skill counts as usable, for here and for other characters, with the tooltip "train <skill> first". |
| Off-hand weapon | Dual Wield learned, or not yet learned and given by the class table at or below the level the item is judged at ("train Dual Wield first") | The saved list, plus the class table for Dual Wield not yet learned |
| Shield | Shield learned | The saved list |
| Relic (Libram, Idol, Totem) | The class must match | Same |
| Class-restricted items | The classes the item allows | Same |
| Unique | Section 7.5 | Same |

- Where the game gives its own can-use answer for the current character, LootLogic uses it only for an item whose required level has already been reached, and never for other characters (technical findings 8.3; L5). An above-level item is judged by the level, class and proficiency rules, without a live veto. An untrained but trainable armour type, weapon skill or Dual Wield counts as usable whatever that answer says (rows above).
- **Evaluated level:** an upgrade candidate is compared at `max(character level, candidate required level)`, within the configured look-ahead window. Its baseline includes only owned pieces usable at that level. At each evaluated level, the class training levels and best-armour rule use that level; learned skills still come from the live character or snapshot. An owned future-level piece cannot suppress an upgrade that can be used sooner.
- `bestArmorOnly`: in the eight armour slots, a type below the best one the character can wear at `max(character level, item's required level)` is never an upgrade. For a candidate, current level covers items usable now (a level 60 shaman has mail, so level 35 leather is never an upgrade); the required level covers look-ahead items. When selecting owned baseline or protected pieces at a particular evaluated level, use that evaluated level for every piece instead, so a lower-level item does not carry an earlier armour rule into a later level. Back, neck, rings, trinkets, shields and off-hands are exempt. With the rule on, a type below the best wearable one is also never "in use" and counts in a baseline only when worn. A loadout can override the setting with `armor = "best"` (rule on) or `"any"` (rule off); nil uses the setting. Every score, baseline and "in use" comparison for a loadout uses that loadout's value (Equip for here uses the worn loadout's), and loadouts with the same spec but a different effective rule (nil resolved to the setting) do not share a comparison (8.5).

### 8.4 Slots and comparison

Slots map to groups: head, neck, shoulder, back, chest (including robes), wrist, hands, waist, legs, feet, finger (two), trinket (two), ranged or relic (ranged weapons, thrown, relics), main hand, off hand (off-hand weapons, shields, held items, and a one-hand weapon when dual wielding) and two-hand. The game's slot-type names for each group are in technical findings 8.4.

Shirt, tabard, ammo, bags, quivers, cosmetic armour and profession tools (step 1d) are ignored, as candidates and as owned pieces.

**Baseline per (character, loadout spec and armour rule, slot group, evaluated level).** Compare with the best piece the character **owns** and can use at the evaluated level (8.3), worn or carried, so it does not matter which set it logged out in. "Owned" means worn, bags, bank (last seen), inbox and inbound mail (imported set members add protection, step 1c, but are not owned pieces: a set member counts as owned only when a snapshot of that character holds the same `itemID:suffixID`). The candidate's own instance is excluded when judging for here. Worn copies always count as owned. When here holds several identical copies (same link) that are not worn, in the bags, bank, inbox or inbound mail, the copy in the lowest bag and slot (bag and bank copies first; inbox and inbound copies, which have no slot, after them) is judged against a baseline that leaves out the other unworn copies; each other copy is judged with that copy counted as owned.

**Progression through the look-ahead window.** Keep the best usable owned gear at each integer level from the character's current level through `current level + lookAheadLevels`, inclusive. A piece can win at several levels; that does not require several copies. A level-20 character can keep a score-20 chest for level 21, a score-30 chest for level 22 and a score-40 chest for level 23. Another level-22 chest scoring 25 loses to the score-30 chest; a level-23 chest scoring 28 also loses to it. The same selection uses the existing pair, unique, tie and armour rules at each level. Here's protection is the union of those winning pieces (8.6); the window does not create recorded sets or saved per-level data.

**Pieces still loading.** Stats are re-read from the game (section 6), so an owned piece whose item data has not loaded cannot be scored. LootLogic requests it, and a candidate whose comparison needs it (an owned piece in the candidate's slot groups, for here or for any character it is compared for in step 3b) is pending until it loads. A piece still not loaded 10 seconds after it was first requested is left out of the baselines until it loads; when it does, the results that used those baselines are recomputed.

| Candidate | Baseline |
|---|---|
| Single-slot item | The best usable owned piece |
| Rings and trinkets | The **weaker of the best two** owned (an empty second slot counts as 0, and so does an owned piece that scores below 0, including for item-level fallback). The best two never include two copies of one unique-equipped item. |
| Two-hander | `max(best 2H, best MH 1H + best off-hand)` |
| One-hand main hand | The best MH 1H. If this spec prefers a 2H (2H > MH + OH), compare candidate + best off-hand against the 2H; the reason names the two-hander. |
| Off-hand | The best off-hand. If this spec prefers a 2H (2H > MH + OH), compare candidate + best MH 1H against the 2H. |
| Nothing owned | 0: any positive score is an upgrade |

**Pairs.** The main-hand and off-hand terms are two different owned instances: one weapon never fills both hands, and two copies count only when the item is not unique-equipped. The best pair is the higher of (best MH 1H + best off-hand of the rest) and (best off-hand + best MH 1H of the rest). In the main-hand and off-hand rows, "best MH 1H" and "best off-hand" are the two pieces of the best pair (the candidate's own instance left out), so an off-hand candidate is compared with the pair's off hand, never with the piece the pair uses as its main hand. A unique-equipped candidate is not an upgrade for a hand when the piece kept in the other hand is the same item. 8.6 uses the same pair.

- **One-hand weapons** that can go in either hand (for a class that dual wields) are judged as main hand and as off hand, and the better gain is used; the reason names the slot.
- **Ties:** when two owned pieces with different links score exactly the same and the score is above 0, item level breaks the tie when `itemLevelFallback` is on; equal item level (or the setting off) leaves both as best, so both are "in use". A piece scoring 0 under a spec is never "in use" for it, whatever its item level. Identical copies (same link) never tie: a worn copy, else the copy in the lowest bag and slot, else an inbox or inbound copy, is the best one.

**Upgrade test:**
- With `baseline > 0`: `gainPct = (candidate - baseline) / baseline * 100`. It is an upgrade if `candidate > baseline` and `gainPct >= minUpgradePct`.
- With `baseline == 0`: an upgrade if `candidate > 0`. `minUpgradePct` does not apply. For ranking in step 3b it counts as an infinite gain, so an empty slot beats any finite `gainPct`; several empty-slot candidates tie and fall to the character order.
- With none of the weighted stats, and with `itemLevelFallback` on: compare item level against the same baseline piece's item level (for a pair baseline, the higher item level of the pair), labelled "ilvl". `gainPct` comes from item level, `minUpgradePct` applies, and it ranks in step 3b like any other gain.
  - When every owned piece in the slot group scores 0, so no piece is the baseline by score, the baseline is the owned piece with the highest item level (rings and trinkets: the weaker of the best two by item level, an empty second slot counting 0), and `minUpgradePct` applies.
  - With nothing owned in the slot group, the empty slot counts as item level 0: the item is an upgrade with an infinite gain, as with `baseline == 0` above, and its reason is the empty-slot reason (7.6), labelled "ilvl". An empty second ring or trinket slot that makes the item-level baseline 0 counts the same way.

**Choosing between other characters** (step 3b): the largest `gainPct` wins, with the first character in `LootLogicDB.order` (the player's character order, the same one that ranks wants) as the tie-break (agreed rule). No name is compared, so renaming a character or registering a namesake cannot change who gets an item. The tooltip line names the runner-up; Shift and `/ll why` list up to two.

### 8.5 Loadouts in scoring
- A character is scored under each of its loadouts, by spec and armour rule (8.3); loadouts with the same spec and the same effective armour rule (nil resolved to `bestArmorOnly`) collapse into one comparison at the same evaluated level. A loadout with `spec = nil` or a saved spec with no weight table in this build is not scored; a character with no scored loadout is never a destination in 3b. An unavailable saved spec is left unchanged and treated as no spec for scoring and here's `nospec` protection (7.2 step 3.0), including when other loadouts are scored.
- An item is an upgrade for here (Equip) if it beats the baseline under the worn loadout's spec, and for another character (step 3b) if it beats the baseline under **any** of its loadout specs. The tooltip names the loadout: "LootLogic: Equip (+11% Bear over Thick Hide Belt, worn)" for here, "LootLogic: Chamoomile (+9% Cat over Ferocious Bracers)" for another character.
- When the item is an upgrade under more than one loadout spec, the reason names the loadout with the largest gain (the worn loadout on a tie); Shift and `/ll why` list the others. When loadouts share a spec and an armour rule, the reason names the worn one if it is among them, else the first in the list.
- When characters are compared (step 3b), a character's gain is its best percentage gain over its loadouts.
- **Limit:** the baseline is the best owned piece per spec, armour rule and evaluated level, not the pieces of a particular set. Two loadouts with the same spec and armour rule share a baseline at the same level.
- **Assumed spec:** a loadout the player has not set uses its class's assumed spec (section 8.2). Tooltips say "(assumed)". Item level is the fallback only when the item has none of the stats the spec weights.

### 8.6 "In use" protection (step 3c)
- For here, any owned piece that is part of a scored loadout's winning gear at any integer level from current level through `current level + lookAheadLevels` stays, with the reason `inuse`. Selection is repeated at each level under that loadout's spec and armour rule (8.3); protection is the union of the winners. The candidate counts as owned under every scored loadout spec, so a better piece for a loadout that is not worn becomes that loadout's best (and stays). A replaced piece loses protection only when it no longer wins at any level for any loadout; it is then judged by the later steps (other characters, wants, then the sell rules). That covers, separately at each level:
  - the best piece per slot group per spec, except the main-hand, off-hand and two-hand groups (below);
  - the best two rings and trinkets;
  - for those groups, only the set that wins the section 8.4 comparison under that spec: the best two-hander, or the best main-hand and off-hand pair (a shield is an off-hand), whichever scores higher with the spec's weights. Equal scores are broken by item level when `itemLevelFallback` is on; if still equal, both sets are "in use". The losing set's pieces are judged like any other item, and the winner is worked out again whenever the owned pieces change. A spec that cannot use one of the sets compares only the usable ones.
- This keeps bag sets safe **without recording sets**.
- An older piece that no loadout ranks first at any level in the window is not "in use" and is judged by the later steps like any other item. `hereWinsInLookAhead` controls priority for a future upgrade in step 3a; it does not disable protection of owned progression gear in step 3c.
- A piece scoring 0 under a spec is never part of that spec's baseline protection, whatever its item level.
- Items in an imported set (step 1c) or on the Protect list (1b) are already hard stays; this adds the same safety for gear that is in no saved set.

### 8.7 Performance of scoring
- Stats are cached per link.
- Baselines are cached per (character, spec, armour rule, slot group, evaluated level). They are invalidated by snapshot changes: here's gear, bags, bank or inbox, a level-up, a loadout change, and inbound mail recorded for any character; also proficiency, a gear setting change, and an owned piece loading after it was left out (8.4, pieces still loading) (an imported-set refresh changes step 1c results, not baselines).
- Candidate upgrades use the baseline at the candidate's evaluated level. Here's "in use" protection also checks the cached winners at each level of the window; the extra comparisons scale with `lookAheadLevels + 1`. Cached comparisons do not scan all owned pieces again for every candidate.

---

## 9. Loadouts and gear sets

LootLogic reads gear sets that other addons keep. It is set **reading**, not set management: LootLogic never swaps gear.

### 9.1 Sources of gear sets

LootLogic reads the sets of Outfitter Forever and of the Blizzard Equipment Manager (the imported sets, section 4), for the current character and for the others. Where each addon keeps its sets, and how another character's sets are read, is in `docs/technical-findings.md` section 9.1.

### 9.2 Design: loadouts
- A **loadout** = `{ name, spec, worn?, assumed?, armor?, link? }`.
  - `worn` marks what is worn. Exactly one per character.
  - `link` optionally names an imported set (`{ source = "outfitter" or "equipmentset", set = "<name>" }`). It is used for labels ("LootLogic: stays (in set Tank (Bear))").
- **Imported sets** are stored separately (`importedSets`), read-only. They are refreshed at login and when the set addon reports a change:
  - **Here:** read from the game or the set addon directly.
  - **Others:** read from the copy Outfitter keeps for all characters, matched by first name plus region. A character whose first name is shared with another is skipped (technical findings 9.1).
- **Every member of any imported set of here stays (step 1c), whether linked to a loadout or not.** Members add no owned piece to any baseline: a member counts as owned only when a snapshot of that character holds the same `itemID:suffixID` (8.4).

### 9.3 Scope and size
**Size (about 380 lines, about 9% of the addon):**
1. **Protect list** per character and global: slash command, keybinding ("toggle protect on hovered item") and UI list. About 150 lines including UI.
2. **Loadouts** `{name, spec, worn, assumed, armor, link}` in the Characters tab, plus the "in use" protection over loadout specs. About 90 lines beyond scoring.
3. **Membership import** from the Equipment Manager (about 60 lines) and Outfitter Forever (about 80 lines). No per-set scoring.

**What would be lost with the worn set only** (none of 1 to 3):
- Bag-set pieces would be judged against the worn set's pieces with the main spec. A BoP cat piece that loses to the worn bear piece under bear weights would land in **Vendor**; a BoE one in AH or another character's section.
- New off-spec upgrades looted while in the main set would be misjudged the same way.
- With the Protect list alone, pinned items are safe, but every set piece needs pinning by hand and new off-spec upgrades are still misjudged.
- Items 2 and 3 close both holes cheaply, which is why they are in v1.

**Minimum guarantee:** an item that is in any imported set of the current character, or that is protected, is never put in Vendor, AH or another character's section.

---

## 10. Recipes and class books (separable feature)

Recipes route by subclass want. **For here only**, LootLogic checks whether the item is already known. If it is, here does not count as wanting it (unless the item is an include of here), so the recipe falls through to other wanters and then to AH, Vendor or Vendor/AH. Class books use the same check plus the class restriction. The answer is remembered for the session and checked again when the character learns a recipe or a spell (technical findings 10; from memory, L23). About 40 lines.

LootLogic only knows what the character it is running on has learned, so a recipe a wanter already knows still routes to it (unknown counts as wanted, agreed rule).

---

## 11. Price providers

### 11.1 Providers

Auctionator has a public API; AuctionDB (AHDB) has a global table with no documented API; the others are not supported on Forever yet. The evidence for each is in `docs/technical-findings.md` section 11.1.


### 11.2 Provider interface

```lua
-- The table each provider file passes to Prices.Register (Prices/Prices.lua).
-- Prices.OnChanged(callback) lets a later module hear that data changed.
local Provider = {
    id = "auctionator",
    label = "Auctionator",
    -- Optional. true when GetPrice reports inLastScan reliably (AHDB).
    honoursLastScan = false,
}

-- Whether the addon is loaded and its API present.
function Provider.IsAvailable() end

-- Returns nil, or:
-- {
--     unit = <copper>,
--     ageDays = <number or nil>,
--     timestamp = <epoch or nil>,
--     quantity = <number or nil>,
--     inLastScan = <boolean or nil>,
-- }
function Provider.GetPrice(itemID, link) end

-- Optional. False when the provider knows it holds no data at all
-- (AHDB with no scans). Auctionator defines none.
function Provider.HasData() end

-- Called when prices changed.
function Provider.OnUpdate(callback) end
```

- `Prices.Best(itemID, link)` asks every available provider. It drops every price that is not usable (below), then keeps the smallest age of those, then applies the `providerOrder` tie-break. When `requireLastScan` is on, only providers that define `honoursLastScan` (AHDB) are asked while one of them is available; if none is, the setting is ignored and every available provider is asked (below). It returns the price with its source, for the tooltip. With no usable price it returns nil and the reason (the code and, for an old price, the price and its provider) that the section 7.6 texts use; the shape is in technical findings 14.
- **Usable price** (section 4): exists, `ageDays <= maxPriceAgeDays`, and `inLastScan` when `requireLastScan` is on and AHDB is available. Anything else, **including no provider at all**, is "no usable price" and gives **Vendor/AH** (section 7.2 step 6).
- **Age and last scan:** AHDB reports an exact age and whether the item was in the latest full scan. Auctionator reports whole days only and cannot say whether the item was in the latest scan, so it does not honour `requireLastScan`. With the setting on: if AHDB is available, only AHDB prices count and Auctionator is not asked (an item AHDB has not seen in its latest scan gets no price, even if Auctionator has a recent one, and AHDB with no scans gives `noscan`); if AHDB is not available, the setting is ignored, Auctionator prices are judged by age alone, and LootLogic says so (`docs/ux.md` 2.1, 3.5 and 3.8). Technical findings 11.2.
- **House:** prices are read for here's faction house (Horde or Alliance) (unverified; L9; technical findings 11.2).
- **Vendor price** (no provider needed): the sell price the game reports, forced to 0 when the item has no value or when AHDB marks it unsellable.
- **Price updates** (either provider's notice of new data) bump the price generation. That invalidates only the cached results that reached step 6.

---

## 12. Bag addons and adapters

### 12.1 Adapter order

| Order | Adapter | What it does |
|---|---|---|
| 1 | **BetterBags** (agreed) | Real categories |
| 2 | **Bagnon and Bagnonium** (BagBrother rules) | Rules as filters or tabs |
| 3 | **ArkInventory** (rule function) | Player-written rules |
| 4 | **EllesmereUI Bags** | Overlay only; for the record |
| 5 | **Default Blizzard bags** | Overlay |
| always | **Tooltip line** | Every bag addon, including Baganator |
| deferred | **Baganator** | Waits for a writable category API (12.3). Until then: tooltip line only. Its item buttons are its own, so the default-bag overlay does not reach them. |

### 12.2 Compatibility

What each bag addon exposes, its licence and the Forever evidence are in `docs/technical-findings.md` section 12.2. In short: BetterBags has a real category API (first adapter); Bagnon and Bagnonium, ArkInventory and EllesmereUI Bags have rule or overlay hooks (later adapters); the default bags take an overlay; Baganator gets the tooltip line only until a category API exists (12.3); every bag addon gets the tooltip line.


### 12.3 Candidate upstream hooks (PRs or maintainer requests)

| Addon | Minimal hook | Behaviour |
|---|---|---|
| **Baganator** (request through the maintainer's CurseForge page). **The precondition for any Baganator adapter.** | Writable external category source | A way to register a category source (a label, its category names and colours, and a function giving an item's category), and a way to ask for a refresh. Each source would appear as an auto category type beside equipment sets and TradeSkillMaster. The exact signatures proposed are in technical findings 12.3. With this, the adapter is about 50 lines. |
| EllesmereUI Bags | Runtime classifier | A function that gives an item's category at run time, called after the player's own assignments and before type matching, with categories built at runtime and never saved; plus a way to ask for a refresh. Signatures in technical findings 12.3. |
| Bagnon / BagBrother | Item overlay | A function run on each item button after it updates. |
| ForeverForge Bags | Section source | A way to register a section source that lists sections and gives an item's section. |
| Forever Ledger | Price API | A call that returns an item's price and the price's age. |

### 12.4 Adapter architecture

```lua
-- Core API (API.lua), the only thing adapters use.

-- Returns a result. Returns nil while the item is pending (its data, or for
-- gear an owned piece it is compared with, still loading: 8.4), for an empty
-- slot, and for a bank slot while the bank is closed. "none" is a category
-- like the others and has a result.
LootLogic.API.ClassifyBagSlot(bag, slot)

-- fromInbox is true for the GetInboxItem getter and for the mail-upgrade login
-- line (7.5, 13). For items with no bag slot (tooltips outside the bags,
-- /ll why <link>, possibly BetterBags data): who-wants-it and gear verdicts
-- only, never AH, Vendor or Vendor/AH (section 7.5).
LootLogic.API.ClassifyLink(link, fromInbox)

-- Returns {
--     { id = "char:<key>", label = "Zugar", color = <color>, icon = <icon> },
--     { id = "ah", ... },
--     ...
-- }. Also gives counts and cash totals for the Contents tab
-- (docs/ux.md 3.4).
LootLogic.API.GetActiveCategories()

-- A number that increases on any change that can alter results (the total
-- of the cache generation bumps, technical findings 14).
LootLogic.API.GetGeneration()

-- fn is called as fn(generation, name), at most once per frame; name is the
-- first generation bumped in that frame (for example "loadouts").
LootLogic.API.RegisterCallback("CHANGED", fn)

-- A result. category is "char:<key>", "equip", "ah", "vendor", "vendorah" or
-- "none". color is the category's palette colour (docs/ux.md 7); for "none",
-- the tooltip's default text colour, dimmed grey for reason nobody and red for
-- reason error (section 13). There is one code and one text per reason, so
-- tooltips, the Contents tab and Status word it the same way. A "none" result
-- carries its reason too.
result = {
    category = "char:<key>",
    label = "Zugar",
    color = { r = <r>, g = <g>, b = <b> },
    icon = <fileID>,
    short = "Z",
    -- A code from section 7.6.
    reasonCode = <code>,
    reasonText = "wants Trade Goods: Cloth",
    line = "LootLogic: Zugar (wants Trade Goods: Cloth)",
    linkOnly = false,
    detail = {
        wants = {
            winner = <key>,
            others = { { key = <key>, why = <why> }, ... },
        },
        -- Each entry has the fields key, loadout, spec, assumed, itemLevel,
        -- candidate, baseline, baselineItem, baselineWhere, bankAge and
        -- gainPct. baselineItem and baselineWhere hold two entries for a pair
        -- baseline.
        gear = { <entry>, ... },
        -- Fields: source, unit, ageDays, net, vendor, gainPerUnit, gainTotal.
        price = <price>,
    },
}

-- Adapter contract (Adapters/*.lua and Display/BlizzardBags.lua).
Adapter = {
    id = "betterbags",
}

-- Whether the addon is loaded and its API present.
function Adapter.Detect() end

-- Registers hooks once.
function Adapter.Init(api) end

-- Called on CHANGED (debounced per adapter).
function Adapter.Refresh(reason) end
```

- Adapters never classify, and classification never knows about adapters. An adapter shows no section for "none" and for a pending item.
- Each adapter is guarded so an error in it cannot break the others, and can be disabled in settings.
- The Status tab shows each bag adapter as active, idle or failed, and each set source (Equipment Manager, Outfitter) as found, active or failed, with the error.

### 12.5 BetterBags as the first adapter
BetterBags is first because it has a real category API and an open (MIT) repository where upstream fixes are realistic. Its Forever support is recent (September 2026), it releases often, and a separate "Betterbags - Forever" plugin may compete for the same items (risk 2). The evidence is in `docs/technical-findings.md` section 12.5.

---

## 13. In-game UI

**Main window:** `/ll` or `/lootlogic`, also the addon compartment (live check L50). Plain frames, no embedded libraries. A **minimap button** (M2) opens it too: one plain named button on the minimap, drag to move round the edge (`ui.minimap.angle`), a Settings tick to hide it (`ui.minimap.hide`), left-click toggles the window, tooltip "LootLogic" with the click hint. Built by hand, so no LibDBIcon. Named frame and standard size, so a minimap-button collector such as EllesmereUI's can group it (unverified; L45). The Blizzard Settings panel gets a LootLogic category with a button that opens the window.

**Tabs** (in order, per `docs/ux.md` section 3.1): Contents, Characters, Wants, Weights, Protect, Settings, Status.
0. **Contents** (M2). One row per category with stacks, items and estimated cash, in this order: the other characters (player's character order), AH, Vendor, Vendor/AH, Equip, then a "No category" row; a total cash line; and click-through to the items with the reason for each. A state summary, no directives. `/ll contents`. Design: `docs/ux.md` section 3.4.
1. **Characters.** The roster in priority order. Each row shows:
   - up and down buttons, class icon, display name (editable), level, the worn loadout's spec, whether it receives gear, the number of want types, mail on the way, last seen;
   - a "Forget character" button (asks first) in the expanded row.

   Below the list, a Contested line names the winner for each want type that two or more eligible characters claim.

   Greyed rows are characters that are not eligible destinations from here. Expanding a row shows its **loadouts**:
   - name (click to rename), spec dropdown, an armour dropdown (use the setting, best only, any), a "worn" radio (the loadout the character is wearing now);
   - "linked set" dropdown (imported Outfitter and Equipment Manager sets of that character, or none);
   - add and remove.
2. **Wants.** A row of character buttons (class icon, name in class colour), up to 8, and a dropdown beyond that. It opens on here the first time each session, then on the last character edited.
   - **Left:** the item class tree (client names). Class rows expand to subclasses; each ticked row has a minimum-quality dropdown (any, common, uncommon, rare, epic).
   - **Right:** item includes and excludes (icon, name, Include or Exclude toggle, remove). Add by dropping an item on a slot (the item held on the cursor) or shift-clicking a link into the box.
   - **Search** filters the tree by type name and by example item, because the list of possible wants is very large (`docs/ux.md` 4.2). Example items for each type come from `Data/TypeExamples.lua`.
   - **Contested markers** on a type another eligible character also wants (`docs/ux.md` 4.2).
   - **Templates**: shipped sets of type flags applied by merge, with a one-line diff before applying (`docs/ux.md` 4.3; `Data/Templates.lua`).
   - **Buttons:** "Copy from".
   - A warning shows when class 0 (Consumable) is ticked.
3. **Weights** (read-only). A spec list by class, and for the selected spec its stat weights with the source and confidence label (for example "WoWSims Forever, unverified in game"). No edit boxes.
4. **Protect.** Per-character and global lists. Add by drop slot or keybinding.
5. **Settings.**
   - AH rule: AH cut %, minimum gain (money input, "whole holding"), minimum gain % ("per unit"), max price age, require last scan.
   - Provider order.
   - Gear: look-ahead levels, "current character keeps upgrades within the look-ahead", minimum upgrade %, best armour only (each loadout can override it), item level fallback.
   - Per-class disposition (Stay or Sell, plus Miscellaneous subclasses): changes are saved as overrides; the shipped defaults are not copied.
   - Display: tooltip, overlay, badge position and size, palette, "show a line when nobody wants an item that is not in my bags" (off by default), minimap button (show or hide), "open the Contents tab at the merchant, AH or mailbox" (off by default).
   - Window: scale (70% to 150%).
   - Notifications: the login line about stale characters (`notify.staleSnapshot`) and how many days count as stale (`staleDays`), the scan summary line (`notify.scanSummary`), the line when mail is recorded (`notify.mailRecorded`, off by default), and the login line about upgrades waiting in the character's own mail (`notify.mailUpgrade`, on by default): once per session, once item data has loaded, every piece in the character's last-seen inbox and its inbound mail that comes out as `equip`, `equipat` or `inuse` (it is the best owned piece for one of its loadouts) is named with the loadout, for example "2 upgrades are waiting in your mail: [Chestguard] (Cat), [Ring] (Bear). Collect them at a mailbox." (the first three, then "and N more"). The inbox is as of the last mailbox visit; no line is shown when nothing qualifies.
   - Adapters: per-addon toggles (BetterBags, BagBrother, ArkInventory, EllesmereUI Bags, default bags).
6. **Status.** The setup checklist (`docs/ux.md` 2.2 and 3.5), then providers found, with the newest price age (for Auctionator, the newest of the prices LootLogic has read this session, as its public API gives no other: technical findings 11.2); tooltip hook active; adapters active, idle or failed; set sources (Equipment Manager, Outfitter) found, active or failed; snapshot age per character; version, schema, build; the last 20 errors.

**Tooltip line:** one coloured line on the item tooltip and on item-link popups only (not on comparison tooltips, and not on the player's own equipped items), with the category word in the palette colour and ages shown as "today" or "N d". The word "stays" (category none) is in the tooltip's default text colour, the `nobody` line in that colour dimmed grey and the `error` line in red, in both palettes (`docs/ux.md` 7). How a comparison tooltip and an item-link popup are told from the item tooltip is from memory (technical findings 12.2, live check L60); if they cannot be told apart, the line also shows on comparison tooltips. It is `LootLogic: <category> (<reason>)`, with the reasons of section 7.6. For example:
- "LootLogic: Zugar (wants Trade Goods: Cloth)"
- "LootLogic: Equip (+11% Bear over Thick Hide Belt, worn)"
- "LootLogic: AH (12s 30c each, +8s over vendor after the 5% cut; Auctionator, today)"
- "LootLogic: Vendor/AH (no AH price yet: scan)"
- "LootLogic: stays (best Cat chest owned)"

**Holding Shift** and `/ll why` add the detail, at most 8 lines, in this order, each part only when it applies: the category line; one wants line (the winner, then the characters that lose, in the player's character order); one gear line per loadout comparison (8.5) of the character the result is about (the winner for `gearfor`, here for any other result of a gear item), largest gain first, each with its gain or loss and its baseline (a bank baseline adds "bank seen N d ago", or "bank not seen" with no bank snapshot); one line with up to two runners-up (step 3b); then two price lines when a price was read (source, unit price, age and net after the cut; the gain per unit and for the whole holding, and the thresholds). When the parts come to more than 8 lines, the gear lines with the smallest gains are cut and the last one kept ends "(and N more)". Pressing or releasing Shift while the tooltip is shown adds or removes the detail without a new hover (from memory: technical findings 12.2, live check L59); if it cannot, the detail is shown only by `/ll why`. Layout and examples: `docs/ux.md` 5.4.

**Overlay:** a corner badge by category: a square badge with a letter for Equip, AH, Vendor and Vendor/AH (E, A, V, ?), and a round badge with the first letter of the display name, in class colour, for a character (letters on a collision: `docs/ux.md` section 7). The item's border is left alone, because it shows quality. Shown on default bags and EUI Bags; design in `docs/ux.md` section 7.

**Slash commands:** all exist from M1 unless marked (M2).

| Command | Action |
|---|---|
| `/ll` | Toggle the window. In M1, which has no window, print the setup commands below and the checklist (as `/ll status`) |
| `/ll why [link, item ID or itemID:suffixID]` | Explain the hovered or given item in chat |
| `/ll protect [link, item ID or itemID:suffixID]` | Toggle protect for here (`/ll protect global [...]` for the global list). A link or an `itemID:suffixID` protects that roll; a plain item ID protects every roll |
| `/ll loadout <display name> <loadout> <spec> [worn]` | Add or edit a loadout; `worn` makes it the worn one and clears the flag on the others. The name is required. `/ll loadout <display name> <loadout> remove` deletes it (never the worn one). `/ll loadout <display name> <loadout> armor best\|any\|default` sets the loadout's armour rule (`default` sets `armor` to nil, so the loadout follows the global best-armour-only setting: on by default, changeable in the Settings tab from M2). Setting a loadout's spec clears its assumed flag, also when it is the spec it already has ("LootLogic: Zugar Affliction now uses Affliction (picked)"); only a picked spec set again answers "Zugar Affliction already uses Affliction." |
| `/ll order [<display name> ...]` | With names, set the priority order: the listed names first in that order, the rest after them in their old order; an unknown or ambiguous name stops the command and nothing changes. With none, print it |
| `/ll want <display name> <type or item> [on\|off\|clear]` | `clear` removes the type flag or the item entry; for a type, `off` means `clear`. Turn a **type** or a **specific item** on or off in a character's wants (default on). A type is as in the grammar below; the last word is the switch when it is `on`, `off` or `clear`. An item is a link or item ID: `on` includes it even if its type is off, `off` excludes it even if its type is on. Templates (`/ll want <name> template <template>`) arrive in M2 |
| `/ll types [text]` (M2) | List the item types the client knows, with the exact name to type and the numbers: no text lists the classes, a class name lists its subclasses, other text lists every type whose name contains it (for example `Armor: Cloth (4:1)`, `Trade Goods: Cloth (7:5)`). The command-line counterpart of the Wants tab's type tree, for players who prefer commands |
| `/ll gear <display name> on\|off` | Set the character's Receives gear switch |
| `/ll help` | Print the command list |
| `/ll contents` (M2) | Open the window on the Contents tab |
| `/ll wants [<display name>]` (M2) | Open the window on the Wants tab, on that character when a name is given |
| `/ll status` | Print the setup checklist and the providers, adapters and snapshot ages in chat in M1; from M2 it opens the window on the Status tab. It also prints the session's last 5 errors |
| `/ll refresh` | Rebuild caches and refresh adapters |
| `/ll probe` | Run the automatic live-client checks (technical findings 18) and print PASS, FAIL or SKIP (with the reason) for each; the manual ones are listed with what to do |
| `/ll perf` | Timing of the last full classification |
| `/ll debug on\|off` | Debug logging: lines echo to chat with a "LootLogic debug:" prefix, and the last `debug.maxLog` lines are kept in the saved data, readable after a reload. What it records (events, snapshots, mail capture, the logout check and more): technical findings 15 |
| `/ll reset`, `/ll reset <display name>`, `/ll reset all`, `/ll reset confirm` | Clear the settings and the window settings (everything except `firstRunDone`); one character's loadouts (recreated as one worn loadout with the assumed spec), wants, protect list and switches (not its snapshot); or everything including the roster (the current character is registered again at once, and `firstRunDone` is kept). Each prints what it would clear, and nothing happens until `/ll reset confirm` is typed within 30 seconds |

**Command grammar.**

- **Case and aliases:** commands, names and types are case-insensitive; `/lootlogic` is the same as `/ll`. `/ll help` prints the command list; an unknown word gets "Unknown command 'foo'. /ll help lists them."
- **Names:** a display name or the full "First Last" (section 6). A name may contain spaces. The parser takes the **longest prefix of the arguments that matches** a roster display name or full name; when that text is one character's display name and another's full name, the display name wins (section 6). Quotes are also accepted (`"Boneset H"`). An unknown name says "LootLogic does not know Bob yet. Log in on Bob once with LootLogic enabled." and an ambiguous one lists the valid names. Neither changes anything.
- **Item or type?** The parser decides by the shape of the argument. A link, or a bare number (`2589`), is an **item**. `class:subclass` as numbers with a colon (`7:5`) or `class:*` for a whole class (`4:*`) is a **type**. Anything else is tried as a type name (`Trade Goods: Cloth`), which is the recommended form. **Gotcha:** a bare number is always an item ID, so `/ll want Zugar 75` means item 75, and a whole class must be written `4:*`, never `4`.
- **Items** (`/ll want`, `/ll why`, `/ll protect`): a link (shift-click an item into the chat box) or an item ID. `/ll why` and `/ll protect` also accept an instance key, `itemID:suffixID` (for example `12345:-17`), for one random-suffix roll; `/ll want` does not, because it has the same shape as a type (`7:5`) and wants are about the item, not a roll. A plain item ID protects every roll. Item names are not accepted, because the game can look up a name only for items already seen. The parser cuts the link out of the arguments first, then matches the character name on what remains.
- **Types** (`/ll want`; type names work in M1 too, only `/ll types` and the Wants tab wait for M2; the numbers are in technical findings section 5): documented and recommended as the client's class and subclass names, `Class: Subclass` as the client names them (`Trade Goods: Cloth`, `Armor: Cloth`), or just the class name for a whole class (`Armor`). An exact class name means the whole class even when a subclass has the same name (`Trade Goods`, `Consumable`, `Reagent`, `Quiver`, `Key`, `Quest`); that subclass is typed `Class: Subclass` (`Trade Goods: Trade Goods`) or by number (`7:0`). Case does not matter. `class:subclass` numbers (`7:5`, `4:*`) and a short subclass name that only one type has are also accepted. A short name that matches several types (`cloth` is both 4:1 and 7:5) lists the matches, with their full names and numbers, and changes nothing. A type exists when the game client gives it a name: any such type is accepted, whether or not technical findings 5 lists it, and the error messages below list the classes and subclasses the client names, in numeric order (which numbers are read: technical findings 5; L8, L61). The minimum quality of a type stays at "any" in M1; it is set in the Wants tab (M2).
- **Reply:** every command answers with one chat line starting "LootLogic:" that says what changed and names what it understood, so a mistyped number shows up. Examples: "LootLogic: Zugar now wants Trade Goods: Cloth" and "LootLogic: Zugar now wants item 2589 [Linen Cloth]". Errors say the cause and the fix.
- **Loadout names** (`/ll loadout`): a trailing `remove`, or a trailing `armor best`, `armor any` or `armor default`, is read first; what is left is the character name and the loadout name, with no spec. Otherwise the rest is parsed as below. After the character name, the loadout name may be quoted (`"Tank set"`). Unquoted, it is the text between the character name and the spec. The spec is the longest suffix of the arguments (before an optional trailing `worn`) that matches a spec of the character's class by label or id, ignoring case; if no suffix matches, the last word is reported as the unknown spec, so a spec with a space (`Beast Mastery`) works without quotes. When only one word, or one quoted name, follows the character name (apart from a trailing `worn`), the loadout name or the spec is missing, whether or not that word is a spec: the command prints its usage line (errors).
- **Loadout rules:** loadout names are case-insensitive and unique per character. In M1 a class with no weight table gets "No specs for Mage in this build."; removing the worn loadout gets "<loadout> is the worn loadout; make another one the worn one first."
- **Protect keys:** a link to an item with no suffix, or `itemID:0`, stores the plain item ID; a toggle removes the exact key it would store. If only the plain item ID is stored and the toggle names one roll (a link or `itemID:suffixID` with a non-zero suffix), it replies "Every roll of <item> is protected; /ll protect <itemID> removes it." (with `global` when the global list was given) and changes nothing. `/ll why <item ID>` explains the first matching stack in the bags (the lowest bag and slot), otherwise the link-only result. `/ll why <itemID:suffixID>` does the same with the first stack whose item ID and suffix both match; when none does, it explains the link-only result for a link built from the two numbers (technical findings 7.1; L57).
- **Hovered item:** `/ll why` and `/ll protect` with no link use the hovered item; whether the tooltip is still shown after typing in chat is unverified (L46). If not, they need a link, and the keybindings still work.

**Errors.** A mistyped command must never leave the player guessing. Four rules cover every command:

1. **Every argument is checked.** An argument that matches nothing gives "No <kind> matches '<text>'", followed by the valid choices when there are 10 or fewer (item classes are always listed), or a pointer to the listing command (`/ll types` from M2, `/ll order`, `/ll help`) when there are more.
2. **A wrong number of arguments** prints that command's usage line and one example.
3. **Nothing changes on any error.** There are no half-applied results.
4. **A near match** is suggested when there is one obvious candidate.

| Mistake | Message |
|---|---|
| Unknown character | "LootLogic does not know Bob yet. Log in on Bob once with LootLogic enabled." |
| Ambiguous character | "Which Boneset? Boneset H or Boneset W." |
| Unknown class (`Armr: Cloth`) | "No item class matches 'Armr'. Classes: Consumable, Container, Weapon, Armor, ..." (every class the client names, in numeric order: technical findings 5, L61) |
| Right class, unknown subclass (`Armor: Clth`) | "Armor has no subclass 'Clth'. Armor subclasses: Miscellaneous, Cloth, Leather, Mail, Plate, ..." (every subclass the client names for the class, in numeric order: technical findings 5, L61) |
| Unknown type, no class given (`clth`) | "No item type matches 'clth'. Try /ll types cloth." (M1: "Try a number like 7:5.") |
| Type number the client gives no name (`7:99`, `99:1`) | "Item type 7:99 does not exist." |
| Ambiguous type (`cloth`) | "'cloth' matches Armor: Cloth (4:1) and Trade Goods: Cloth (7:5). Type the full name." |
| `/ll types xyz` with no match | "No item type contains 'xyz'." |
| Item ID the client says is not an item | "Item 99999999 does not exist." The client answers at once, without the item being loaded (from memory; technical findings 13, L58); when it cannot answer, the ID is accepted and named "item 99999999" |
| Missing or extra arguments | The usage line and an example: "/ll want <name> <type or item> [on\|off\|clear]. Example: /ll want Zugar Trade Goods: Cloth" |
| Bad `on`/`off` word, or a bad word in `/ll gear`, `/ll debug`, `/ll protect global`, `/ll loadout ... armor` | The usage line for that command |
| Unknown spec in `/ll loadout` | "Unknown spec 'bare'. Specs for Druid: Bear, Cat, Restoration, Balance." (before M4 only specs with a table are listed, with "in this build": M1 "Specs for Druid in this build: Bear.", M2 and M3 "Specs for Druid in this build: Bear, Cat.") |
| `/ll loadout <name> <loadout> remove` or `... armor ...` naming a loadout the character does not have | "Zugar has no loadout 'Foo'. Loadouts: Affliction, Demonology." ("Loadouts: none." when it has none); the character's loadouts are listed as rule 1 says |
| `/ll loadout` with no spec, such as `worn` straight after the loadout name (`/ll loadout Zugar Tank worn`) | The usage line and an example, as for missing arguments: "/ll loadout <name> <loadout> <spec> [worn]. Example: /ll loadout Zugar Affliction Affliction worn" |
| Unknown template (M2) | "No template named 'foo'. Templates: ..." |
| Unknown command | "Unknown command 'foo'. /ll help lists them." |
| `/ll why` or `/ll protect` with no link and nothing hovered | "Hover an item or give a link." |
| `/ll reset confirm` with nothing pending, or after 30 seconds | "Nothing to confirm. Type /ll reset first." |
| Wants for a character that cannot receive from here | Allowed and saved: "Otherguy cannot receive from this character (faction)." |
| A change that changes nothing | "Zugar already wants Trade Goods: Cloth." |

**Keybindings (all M2, none bound by default):** "LootLogic: toggle window" and "LootLogic: toggle protect on hovered item" and "LootLogic: explain hovered item" and "LootLogic: add hovered item to wants" (M2; opens a small popup, `docs/ux.md` 4.4). The three item bindings read the item under the mouse; no secure item-button hooks.

---

## 14. Module layout and data files

The file layout, the TOC and the shape of each data file (`Data/ItemMods.lua`, `Data/Slots.lua`, `Data/Proficiency.lua`, `Data/ItemClasses.lua`, `Data/TypeExamples.lua`, `Data/Specs.lua`, `Data/WeightTables.lua`, `Data/Templates.lua`) are in `docs/technical-findings.md` section 14. Data files hold lookup tables, not rules; the rules stay in this spec.

---

## 15. Events, caching and performance

The events LootLogic reacts to, how results are cached and invalidated, and the performance notes are in `docs/technical-findings.md` section 15.

---

## 16. Data for external tools

- `LootLogicDB` is plain Lua with a `schema` number, documented in section 6. External tools **may read** the roster, loadouts, gear, bags, bank, imported sets, wants and protect lists after a logout or `/reload`. **External tools never write it**: the game overwrites it at logout.

---

## 17. Testing strategy

Tests are assertions: hand-written cases with expected results taken from the rules in this spec, run offline before the live client arrives. The runner, stubs and fixtures are in `docs/technical-findings.md` section 17.

---

## 18. Live-client checks

The checks to run in the first sessions after 2026-11-05 are in `docs/technical-findings.md` section 18 (L1 to L63). Each tests an assumption this spec makes, with the test, the expected result and what changes if it is wrong. Claims here that rest on a check name it, for example "live check L3".

---

## 19. Staged build plan

| Stage | Contents | When | Done when |
|---|---|---|---|
| **M0: Engine offline** | Repo skeleton, DB and the migration framework (schema 1, no migration yet), roster, loadouts, wants, facts, stats, scoring, classification, AH rule, providers (stubbed), the four M1 weight tables (8.2), tests and fixtures | Before launch | All offline tests pass (the `migrations[2]` test is M2's; a test belongs to the milestone of the file it tests, technical findings 14) |
| **M1: Probe and tooltip** | **No window.** Snapshot capture, `/ll probe`, tooltip line, `/ll why`, the Auctionator provider, debug log, first-run welcome dialog (once per account), and these chat lines: added, first-run, no-price, provider error and engine error (`docs/ux.md` 2.1 and 6). No forget or rename in M1: they arrive with the Characters tab in M2. Setup by slash command: `/ll loadout`, `/ll want`, `/ll order`, `/ll gear`, `/ll protect`, `/ll status`; `/ll` prints them and the checklist | Launch week | By the M1 pass rule in `docs/TESTING.md`: L1 to L14 (L9 against Auctionator only), L20 to L28, L31, L32, L40, L43, L46, L49, L51 to L53 and L55 to L63 pass (a check that fails does not block M1 when its documented fallback is built), and tooltips are correct on the 4 test characters over three town trips each. Before M2 the team chooses each test character's spec by hand (L54). |
| **M2: BetterBags v1** | BetterBags adapter, default-bag overlay, Protect tab, loadouts in the Characters tab, Equipment Manager and Outfitter membership import, minimal settings (with the `requireLastScan` toggle and its login line), Wants editor, Weights viewer (read-only), the assumed-spec tables for all nine classes and the assumed specs back on the list in 8.2, `migrations[2]` and its test (schema 2, section 6), `/ll types`, minimap button, Contents tab, checklist on the Status tab, the AHDB provider, the stale, scan summary, mail-recorded and mail-upgrade chat lines with their switches in the Settings tab, and the adapter-failed chat line | Week 2 | A tester does a full town trip from the BetterBags sections alone. L15 to L17, L29, L33, L34, L36 to L39, L41 to L45, L47 and L50 pass, and L9 passes for AHDB. |
| **M3: More adapters** | BagBrother (Bagnon, Bagnonium), ArkInventory rule function (with docs), EUI overlay, the full Status tab (providers, adapters, set sources, errors), performance pass | Week 3 | L18, L19 and L35 pass |
| **M4: Weights complete** | Weights for every spec in `Data/Specs.lua` (section 8.2), each with its source (the sim commit and inputs of a computed table, or team judgement) and a confidence label; the tables reviewed by the team | Before publish | L48 confirms the tree names. Every spec has its own table; no spec borrows another spec's table; the team has reviewed each table's source |
| **Publish** | README, CurseForge project (name clear as of 2026-10-28) | When the team decides | |

Later versions are in sections 22 (version 1.1) and 23 (version 2).

**Rough size:**
- Engine and data: about 1,600 lines.
- Snapshot, loadouts and sets: about 530.
- Providers: about 200.
- Display and adapters: about 450.
- UI: about 1,250.

That is **about 4,000 lines of Lua**.

---

## 20. Risks

1. **Nothing is testable until 2026-11-05.** About a third of the client APIs this relies on are evidenced only by other addons' source or by memory. Mitigation: M1 is probes plus the tooltip; integration waits for passing probes.
2. **BetterBags is the first adapter but an unknown on Forever** (12.5):
   - Forever-specific use is unknown.
   - It ships several releases a day at times.
   - It caches per itemID, and reprocessing every item is expensive.
   - The "Betterbags - Forever" plugin may compete for the same items.

   Mitigations: the debounced reprocess, the tooltip line as a fallback in every case, and an MIT open repo where upstream fixes are realistic.
3. **Baganator users get only the tooltip line** until Baganator offers a category API. Baganator is the most-downloaded bag addon among Forever-tagged files on CurseForge (file listings read through CFWidget on 2026-10-27), so this limits the shared audience. Mitigation: the upstream request (12.3).
4. **Weights quality.** The weights are unverified in game, the five hand-written healer tables are team judgement, and the rating conversions those tables need are source-read in the sim and unverified in game (L20). A wrong weight can mark an upgrade as Vendor. Mitigations: "in use" protection over loadout specs, the Protect list, imported-set protection, Vendor/AH, explanations on Shift, read-only v1, and the hand-written test cases.
5. **Snapshot staleness.** Other characters are only as fresh as their last login, the bank as the last bank visit, and mail in transit relies on recording the mail when it is sent. Mitigation: ages on the Characters tab and Status, one chat line at login naming characters not seen for `staleDays`; inbound mail counted as owned.
6. **Outfitter key collision** (first name only), and its exclusion of Equipment-Manager-stored outfits from the global copy.
7. **Loadouts without recorded items** cannot tell two same-spec sets apart, or rank a piece "for this set" against a better piece in another set. Accepted; recorded loadout item lists (section 22) fix it.
8. **Secret values** on Forever in combat. Mitigation: guards and deferral.
9. **Performance** with large bags, bank views, five or more characters and several loadouts each. Mitigation: generations, baseline caches, batching.
10. **Flags-only routing** sends everything of a type to one character until quantity caps (section 23) are added (accepted).
11. **Vendor/AH volume.** With no price addon, or right after launch when few items have been scanned, Vendor/AH may be large. That is intended (Vendor versus AH is a human call without price data), but the town trip is longer until scans accumulate. The Contents tab shows the size of the pile at a glance, and the later quality split (section 23) is the relief valve if needed.

---

## 21. Sources and licences

The sources behind this spec are listed in `docs/technical-findings.md` section 21.

Checked 2026-10-31. The rules are in `CONTRIBUTING.md`. "Use" says what LootLogic does with each source.

| Source | Licence (how checked) | Use in LootLogic |
|---|---|---|
| WoWSims Forever (`wowsims/forever`) | MIT (repository LICENSE, copyright 2022 wowsims team; checked 2026-11-01 at commit `2430d539`) | Stat weights computed by the team by running the sim's stat weights engine, with the MIT notice shipped inside the addon folder and a link back to the sim; the sim commit and inputs are recorded per table. The sim's shipped preset weights are used only as a cross-check and are not shipped |
| BetterBags | MIT (repository) | Runtime category API; behaviour read for the adapter |
| Forever Ledger | MIT (repository) | Ideas (name key, eligibility); a notice is added if any code is adapted |
| Outfitter Forever | MIT (LICENSE in its folder) | Runtime globals and events |
| AuctionDB (AHDB) | LGPLv3 in the TOC, GPLv3 text in LICENSE | Runtime global table; when a method is missing, LootLogic reads the saved-data string (format in technical findings 11.1) |
| Auctionator | All Rights Reserved (LICENSE) | Runtime public API (version 1 of Auctionator's API) only; internal files (item keying, the day count behind its price age) read as evidence, nothing copied |
| EllesmereUI Bags | Custom, all rights reserved | Runtime overlay API; code read to design the proposed classifier hook (12.3) |
| BagBrother, Bagnon and Bagnonium (formerly Combuctor) | All Rights Reserved (X-License in the TOC) | Runtime Rules API |
| ArkInventory | No licence published (the GitHub repository holds docs only); treated as all rights reserved | Runtime rule function |
| Baganator and Syndicator | All Rights Reserved (LICENSE in each release, checked 2026-10-31) | Code read to learn its API and to design the proposed category API (12.3); nothing copied; none used (the tooltip line uses the game tooltip) |
| Pawn | CC BY-NC-ND 3.0 | Scale-string format interop only (section 23); no code |
| ItemRack Universal | No licence published: its README keeps ItemRack Classic's licence, and ItemRack Classic's repository states none; treated as all rights reserved | Importer (section 22), runtime saved-variable shape |
| Journey Tracker | No licence stated | Evidence that `GetItemStats` and the global `SendMail` exist on Forever |
| Questie | Historic code treated as all rights reserved, newer contributions GPLv3 (LICENSE.md) | Evidence of the `WOW_PROJECT_CAMELOT` constant |
| Other EllesmereUI modules | Custom, all rights reserved | Evidence that client APIs and the stat key names exist on Forever |
| ArkInventoryCharacterRules | MIT (README) | The shape of an ArkInventory rule function |
| WoW Forever Tracker | MIT per its CurseForge page, no licence file (unverified) | Listing only: it saves its own scan data and has no API we found; no code used |
| Baganator GearSwap | AGPLv3 (CurseForge page) | Listing only; not used |
| Loadout | MIT (CurseForge page, unverified) | Importer (section 22); saved-variable format unknown |
| Listings and TOCs only | Various | Whether an addon supports Forever: Betterbags - Forever, ForeverForge Bags, LiteBag, AdiBags, Inventorian, TradeSkillMaster, Oribos Exchange; seemeta.com for talent tree names |
| Wowhead, CurseForge, CFWidget | Site terms | Individual facts with dates; no scraping |
| Game client data (build 1.60.1.70532) | Blizzard terms | Item, spell and class IDs are the team's own records from the beta client (unverified; L6, L8), apart from the profession tool item IDs, written from memory of Classic (unverified); the class training levels in `Data/Proficiency.lua` are the team's record of the Classic baseline, unverified for Forever; no game data extract is committed |
| lupa (tests only) | MIT (repository LICENSE) | Test runner; not shipped |

Still unverified: Blizzard's wording on extracting game data. The licence, the notices file and the `LICENSES/` folder are copied into the addon folder when packaging (`LootLogic/LICENSE`, `LootLogic/THIRD_PARTY_NOTICES.md`, `LootLogic/LICENSES/`), so they ship with the weight tables in every packaged build, from M1.

---

## 22. Version 1.1: what changes

Version 1.1 follows once version 1 is trusted. Every item below changes a section named in brackets and needs no data migration unless stated.

- **Recorded loadout item lists** (sections 4, 6, 8.4, 8.5, 9). A loadout that is not worn gains an item list (`items = { [slot] = { id=, suffix=, link= } }`) and a save time (`updatedAt`), added to the same entries. The worn loadout never needs one: its item list is the equipped-gear snapshot. Recorded items also count as owned pieces (8.4) and join the hard stays (7.2 step 1c). A loadout with a recorded list is also compared against its own pieces, which gives "Upgrade for set: Cat (+12% over the Cat set's chest)" even when a better chest exists in another set (8.5). `/ll loadout save <loadout>` records the worn gear (13). The Characters tab gets a Sets view and a "save worn gear into this loadout" button (13). A staleness flag reads "Cat saved 9 days ago, 2 pieces no longer owned". The ItemRack Universal and Loadout importers join the Equipment Manager and Outfitter ones (9.1). About 550 lines. Done when the druid set scenario passes in game and L30 passes. Adding the two fields to the stored loadouts needs no migration, because version 1 already stores loadouts as a list of tables.
- **Stored recipe knowledge** (sections 6, 7.3 step 5, 10). At each login, and when a recipe item enters the bags, the logged-in character checks every recipe item ID present in any roster snapshot (bags, bank, inbox, inbound) and stores `recipes[itemID] = { known, t }` on its own record. Other characters' known recipes then skip that wanter. About 150 lines; the login cost is one check per recipe ID (tens). Items not yet loaded are requested and retried.
- **Editable weights** (sections 8.2, 13). Editing, stored edits and "Reset to the shipped table" on the Weights tab; user-named custom specs; shared weights; a weights import and export string. The stored edits add a `weights` table to `LootLogicDB`.
- **Wants import and export string** (section 13, Wants tab): copy a character's wants as text to share or move between PCs. Chosen for 1.1 because templates and "Copy from" already cover setting up one's own characters, and a public string format is easier to keep stable once the wants data has settled in live testing.
- **Contents tab** (section 13): the last-seen bank (the Bank view when the bank is closed, from a stored snapshot or a bag addon), a view of the recorded inbound mail, and a view of any character's last-seen bags, including characters that are not logged in.
- **Characters tab** (section 13): a [details] link on the Contested line, listing each contested type with the winner and every character that loses it.
- **Size:** about 750 lines.

---

## 23. Version 2 and further possible additions

Version 2 follows version 1.1. The first two items change the data model: `asks` gains `caps = { ["7:8"] = 200 }` and `priority = { ["7:8"] = { key, key } }` beside `types` and `items`, and no migration is needed. The rest are possible additions, in no fixed order and not scheduled.

- **Quantity caps** (sections 6, 7.5, 20): whole stacks, amounts that leave a character rounded to whole stacks, with an in-session ledger that subtracts what has already been mailed or sold so the next stack is not mislabelled.
- **Per-want (per item type) priority** (sections 6, 7.3), so that two wanters can share once caps exist.
- **One-click Vendor at merchants** (section 12.5), possibly through BetterBags category automation, if a plugin's category can carry it (unverified; technical findings 12.5). It would be the player's choice in BetterBags, never set by LootLogic.
- **"Attach this section" at the mailbox.**
- **Pawn scale import** (section 8.2): a public text format; Pawn has Forever-only files on CurseForge during the beta.
- **No-price quality split** (section 7.2 step 6): with no usable price, uncommon or better to Vendor/AH and the rest to Vendor. Version 1 always uses Vendor/AH.
- **Wants preview** (section 13, Wants tab): the live classification of the bags for the selected character (what it gets, what it wants but goes elsewhere with the winner and why, and other characters' last-seen bags), with a button that adds the excludes needed to make that character the winner. Left out because the space needed grows with the number of wants.
- **Docked trip strip:** a slim panel beside the merchant, mail or AH frame showing that stop's category and total (`docs/ux.md` 5.3).
- **Outfitter roster hint:** use Outfitter's data to hint at characters that have not logged in yet; version 1 registers by login only (`docs/ux.md` 2.3).
- **Remembered Vendor/AH calls** (section 7.2 step 6): the player marks a no-price item Vendor or AH once, and LootLogic remembers it per item ID across the account, either only while there is no usable price or in an "always" mode that beats the price. One-click buttons on a Contents tab list, keybindings on the hovered item and a `/ll mark` command would record it. The call stays the player's; it is only remembered. In version 1 Vendor/AH comes back every trip, as without the addon.
- **Keep category** for loadout gear that is not worn: a visible bag section (one shared "Keep", or one per loadout such as "Keep: Cat"). In version 1 such gear has no category and only its tooltip says why it stays.
- **Solo tank specs** (section 8.2): extra specs such as "Paladin Protection - Solo", weighted on survival alone from the sim's results, for a tank that levels on its own; the custom weights of version 1.1 (section 22) also let a player make one.
- **Upgrade chat line:** a setting, off by default, that prints a chat line when a looted item beats a loadout on any character, so upgrades while levelling, and a stowed loadout's piece being replaced, are noticed.
- **"Mail to" button:** a button on the Contents tab, enabled while the mailbox is open, that fills the mail recipient with a character's full name. It attaches nothing. The game already completes the player's own character names in that box (confirmed in beta), so the gain is small. Mail needs "First Last" (confirmed by the team in beta play, L12). Natural to build with "attach this section" if mail handling is ever added.
- **Faster cold first pass:** bucket the owned pieces by slot group once per character, so that building a baseline stops rescanning all owned pieces for each (character, loadout, group, level) key. Memoizing `ItemFacts.FromLink` alone measured about 250 ms down to about 106 ms on the all-gear offline proxy. Revisit after live check L35 shows the real cost.
- **Baganator tile marker:** a category badge on Baganator's own item tiles through its public corner-widget call, so Baganator users get the at-a-glance marker that default-bag users have. The player probably has to enable the widget in Baganator's settings (unverified). It needs a live check of the call, and nothing in version 1 interacts with Baganator beyond the tooltip line every bag addon gets. Until then Baganator users have the tooltip line and the Contents tab.
- **Whole-setup weapon comparison** (section 8.4): compare every main-hand and off-hand pair and two-hander with and without the candidate, and take the gain on the whole setup, instead of the gain on one hand. A unique weapon next to its own twin, and a different partner that makes a pair better, would then need no special rule. It changes the gain a player sees for every weapon, so it needs an owner decision and a rewrite of the 8.4 weapon rows first.
- **Baganator adapter,** once a category API exists (12.3). Baganator's own transfer button acts on the current search, so once our categories exist in Baganator through that API, searching a category could attach or sell it with no LootLogic code (technical findings 12.3).
