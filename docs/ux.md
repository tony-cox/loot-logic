---
name: lootlogic-ux
description: "LootLogic UX and workflow design pass: personas, the end-to-end journey (install, registration, setup, town trip, new alts, stale data), first-run checklist, ASCII layouts for the Contents, Characters, Wants, Weights, Protect, Settings and Status tabs with empty, loading, stale and error states, Wants editor usability, Vendor/AH handling, stale-data feedback, accessibility, and a live-client tuning list. Nothing tested in a live Forever client."

---

# LootLogic: UX and workflow design pass

Companion to `docs/spec.md` ("the spec"; section numbers below refer to it unless they say otherwise). Nothing here has run on a Forever client. Client behaviour keeps the spec's labels (source-read, from memory, unverified), and **untested** marks anything that waits for the live client (2026-11-05).

**Terms:** the **current character** is the one the player is logged in on now. "This tab" and "this screen" mean the view being described. Characters are named by **display name**: the first name, given a space and one distinguishing letter when two characters share one (the full name when one letter cannot tell them apart), or set by the player (spec section 6, notes). The examples use Chamoomile as the current character.

**Why this file exists:** the spec's section 13 lists tabs, the tooltip line, the overlay and slash commands. It has no end-to-end workflow, first run, layouts, empty or error states, Wants editor usability, Vendor/AH handling, or stale-data feedback. This file covers those. The history of the decisions behind it is in `docs/decisions.md`.

---

## 1. Personas and the journey

### 1.1 Personas

| | **Solo alt player** | **Power user** |
|---|---|---|
| Characters | A main plus one or two alts (a crafter or a bank alt) | Five: Chamoomile (druid), Jujuniper (shaman), Boneset (paladin) and Zugar (warlock), all Horde, plus Otherguy (priest, Alliance) |
| Bag addon | Default bags or Baganator (the most-downloaded Forever bag addon in the beta ranking), so badges or tooltip only | BetterBags (sections) |
| Prices | Often none, or Auctionator scanned rarely | Auctionator and AHDB |
| Sets | None | Druid with three loadouts; Outfitter and the Equipment Manager |
| Wants | "Send cloth to my tailor" | Blacksmithing on the paladin, Tailoring and Engineering on the warlock, cooking ingredients to the druid; a keep list per profession |
| Play pattern | Main daily, alts now and then | Characters levelled in sequence; the three Horde alts wait at low level (5 to 12) in an inn for days |
| Tolerance | Low for setup: expects defaults to work, gives up at the first confusing screen | High for setup, low for noise; checks the engine before trusting it (Shift reasons) |
| Biggest risk | A big Vendor/AH pile with no price addon, and no full view of it when the bags show tooltips only | False alarms (stale warnings on idle alts); contested wants settled silently by the order |

Design rule from the pair: **defaults serve the solo player, and nothing the power user relies on is hidden behind them.** In practice: a full list inside LootLogic's own window (the Contents tab, section 3.4) and explanations on Shift everywhere.

### 1.2 End-to-end journey

| Stage | Player does | LootLogic does and says | Notes |
|---|---|---|---|
| Install | Installs LootLogic; ideally BetterBags and a price addon | Nothing until login | |
| First login ever (empty `LootLogicDB`) | Logs in | Registers the character that just logged in (key, class, faction, level, gear, proficiency) and creates the account-wide data; shows a small welcome dialog once, with a button to open setup (section 2.1) | Once per account |
| First login on each other character | Logs in on each alt | Registers it (key, class, faction, level, gear, proficiency), creates one worn loadout, named after the class's assumed spec, with that spec, puts it last in the order; one chat line | SavedVariables are written at logout and read at login, so the next character played sees the new one |
| Setup, one sitting, any character | Characters tab: order and a spec per loadout for everyone. Wants tab: a template or ticks per character | Checklist lines turn done | Every character's specs and wants can be edited from any character |
| First prices | Scans at the AH | Chat line: "LootLogic: prices updated: 9 items left Vendor/AH (6 AH, 3 Vendor)." | If the first AH visit comes late, Vendor/AH is large in the first days |
| Steady state (levelling) | Loots | Tooltip line on every item; sections fill (BetterBags) or badges appear (default bags) | No chat in steady state |
| Town trip | AH, merchant and mailbox, in any order | Section 5 | v1 never moves items |
| New alt later | Creates it, logs in | As "first login on each other character"; that character's checklist shows spec and wants open | Gear is ranked by its class's assumed spec until the player picks one |
| A character goes idle | Doesn't play it for weeks | Snapshot unchanged and still correct unless played elsewhere; age shown in Characters and Status; one chat line at login names characters not seen for `staleDays` | Section 6 |
| Price addon added later | Installs Auctionator or AHDB | The checklist's Prices line changes from "No price addon" to "Auctionator found, no price seen yet"; Vendor/AH stays until the first scan, then the scan chat line | |
| Bag addon changed | For example Baganator to BetterBags | Adapter detected at login; checklist line updates | |
| Set addon changed | For example Outfitter added or removed | Set sources detected at login; the linked-set dropdown and the Status Sets row update | |

### 1.3 Setup order, and why

1. **Log in on every character once.** Nothing can be routed to a character LootLogic has not seen (2.3).
2. **Order** (Characters tab). It settles contested wants. For example, Metal and Stone (7:7) can be wanted by both the paladin (Blacksmithing) and the warlock (Engineering).
3. **Specs**, one per loadout (Characters tab). A new character has one loadout, which uses its class's assumed spec, shown as "(assumed)", until the player picks one.
4. **Wants** (Wants tab): a template first, then adjust.
5. **A price scan** once an AH is reachable. Until then Vendor/AH is large by design (spec risk 11).

The checklist (2.2) follows the same order; the character order has no line, because any order is valid.

---

## 2. First run

### 2.1 What the player is told

**First load on the account** (empty DB): the "added" line for the character (below), this first-run line, and the no-price line when no price addon is found (order under "Chat lines at login"), then a small welcome dialog. The window does not open by itself.

> LootLogic: log in once on each of your other characters so they appear. /ll to set up.

The chat line goes out 5 seconds after `PLAYER_LOGIN`, together with the other login lines (below), whether or not the dialog can show yet. The window also says this in the Characters tab footer and on the Status checklist.

> **LootLogic**
> LootLogic shows where each item in your bags should go: to another character, to equip, to list on the AH, to vendor, or to Vendor/AH for you to decide. It never moves items: you still sell, list and mail.
> LootLogic only knows characters that have logged in once with it enabled. You will not get its full value until you have logged in on each of your characters, so it can sort gear and items for them.
>
> Setup is optional but makes it more useful. It takes a few minutes and you can do it later with /ll.
>
> [Open setup]  [Not now]

- **In M1 there is no window.** The first button reads [Show commands] and prints the setup commands in chat (`/ll loadout`, `/ll want`, `/ll order`, `/ll gear`, `/ll protect`, `/ll status`); from M2 it is [Open setup]. `/ll` prints the same list in M1, then the checklist (as `/ll status`). The first button also closes the dialog, which sets `ui.firstRunDone` like [Not now].
- **[Open setup]** (M2) opens the main window on the Characters tab with the current character's row expanded, so the player can pick its spec straight away. That is the one setup step that changes results most. The Status tab (the checklist of everything else) is one click away. (This is the page where the player sets up their character, not the Settings tab, which holds the AH rule and display options.)
- **[Not now]**, the close button and Escape all close it. None of them opens the window.
- It appears **once per account** (`ui.firstRunDone`, set when the dialog closes, by any button, the close button or Escape). It is never shown again, including on later characters. `/ll` opens the window at any time.
- It is a small dialog in the upper middle of the screen, not a full-screen blocker: it can be dragged, it does not take keyboard focus, and the player can keep playing with it open.

**Sharing the screen with other addons and the client.** On a fresh install, or when several addons are installed together, each may show its own welcome at the same login. Nothing lets addons coordinate, so LootLogic is the polite one:

- It waits until 5 seconds after `PLAYER_LOGIN` (the moment the login chat lines print), the player is not in combat, and no client dialog (any of `StaticPopup1` to `StaticPopup4`) is shown. It checks again every 2 seconds.
- Its frame strata is `DIALOG`, below the client's own dialogs and below any addon that uses a higher strata, so it never covers another addon's dialog and never blocks one.
- If it cannot show within 60 seconds, it gives up for that session, relying on the chat line above, and does not set `ui.firstRunDone`. It tries again at the next login.
- Closing another addon's dialog does not trigger ours early; the checks above decide.
- Behaviour with two or three other addons doing the same is **untested** (L43).

Status tab, top block (shown above the checklist whenever the Status tab is open):

> **LootLogic shows where each item should go. You still do the selling, listing and mailing.**
> 1. Log in on each of your characters once. They add themselves.
> 2. Pick a spec for each character, for better gear advice.
> 3. Tick what each character collects (Wants).
>
> Optional: Auctionator or AHDB, so LootLogic can tell items to vendor from items to list on the AH.

**Chat lines at login, in this order:** (1) the "added" line for a character registered at this login, including the first one on a new account (in M1, a character of a class with no weight table gets: "LootLogic: <name> added (Mage 1, Horde). No gear advice for Mage in this build."); (2) the first-run line, on every login until `firstRunDone` is set; (3) the no-price line, on the same logins as the first-run line; (4) the last-scan line, when `requireLastScan` is on and Auctionator is the only price provider ("LootLogic: 'Only prices from the latest scan' is on, but Auctionator cannot tell which items were in the last scan, so it is ignored. Use AHDB for this."); (5) the stale line; (6) the mail-upgrade line, when upgrades are waiting in the character's own mail. M1 shows (1) to (3) only: the last-scan line arrives in M2 with the `requireLastScan` toggle (it has no switch of its own), and the stale and mail-upgrade lines with their switches in the Settings tab (3.8). Lines (1) to (4) print together, in this order, 5 seconds after `PLAYER_LOGIN`. The no-price line is decided when the lines print: it appears only if no price provider is available then.

**First login of any character:**

> LootLogic: Zugar added (Warlock 1, Horde). Assuming Affliction until you pick a spec. /ll to set up spec and wants.

### 2.2 Setup checklist

Computed live from the DB and the detected addons. Nothing is stored except "hide when complete" and the acknowledgements ("gear only", "tooltip only"), kept in `ui.ack`. Every line carries a text tag, so colour is never the only cue.

| # | Line | Tag and text when not done | Done when | Button |
|---|---|---|---|---|
| 1 | This character registered | always done | automatic | |
| 2 | Roster | info: "5 characters. Missing one? Log in on it once." | at least two eligible characters | |
| 3 | Spec on every loadout of every character | TIP: "Zugar is using an assumed spec (Affliction)." | every spec is picked or kept; in M1 a loadout with no spec (a class with no weight table) shows info "Mage: no gear advice in this build." and counts as done | [Keep Affliction] accepts the assumed spec and clears the flag; [Pick spec] jumps to the row, expanded |
| 4 | Wants per character | TIP: "Jujuniper wants nothing: only gear upgrades go there." | any want or include, or "gear only" acknowledged; or Receives gear is off | [Wants] opens that character; [Gear only] accepts that the character wants nothing (it still gets gear upgrades) |
| 4 | Wants, character with Receives gear off | info: "Bankalt wants nothing and receives no gear: nothing goes there." | counts as done | none |
| 5 | Prices | TIP: "No price addon" / "Auctionator found, no price seen yet" / "Auctionator: price over 21 d old" / "Newest price seen 9 d old" | a usable provider price exists (at most `maxPriceAgeDays` old); for Auctionator, a price LootLogic has read this session, because its public API cannot list its prices (technical findings 11.2). A price with no age (over 21 days) does not make it done | |
| 6 | Bag display | info: "Baganator: tooltip line only; the Contents tab is your list" ([done] reads "BetterBags sections active"). **NEED** when an adapter failed. | an adapter active, or tooltip-only acknowledged | [Retry] on failure; [Tooltip only] accepts the tooltip line as the bag display |
| 7 | Bank seen on the current character | info: "Open your bank once so gear upgrades count it." | `bank.updatedAt` set | |

NEED means results are misleading without it; TIP and info are advice. A complete checklist collapses to one line ("Setup complete") above the Status block. **In M1** (no window) the checklist prints in chat. Lines 4 and 6 print as info only. Line 3's tip reads "type /ll loadout Zugar Affliction Affliction to keep it" (that command clears the flag). Line 6 reads "Bags: tooltip line only in this build."

### 2.3 Unseen alts

A character joins the roster only by logging in with LootLogic enabled. Before that LootLogic has no key, faction, class, level, gear or proficiency for it, so **nothing can be sent to it and its wants cannot be set**. The player is told wherever they would look:

| Where | Message |
|---|---|
| Characters tab footer | "Not listed? Log in on that character once with LootLogic enabled. Nothing can be sent to a character LootLogic has not seen." |
| Wants tab when only the current character is registered | "You are the only character LootLogic knows. Wants for your other characters can be set once they have logged in." The editor still works for the current character. |
| `/ll want Bob <link>` | "LootLogic does not know Bob yet. Log in on Bob once with LootLogic enabled." |
| Checklist line 2 | "5 characters. Missing one? Log in on it once." |

**More than one PC:** `LootLogicDB` lives in the local WTF folder. A character played only on another computer is unseen on this computer; one played on both is as fresh as its last login on this one. The help text says so. LootLogic cannot detect it.

There are no placeholder characters in v1: a character exists only once it has logged in.

Command errors suggest a candidate only when exactly one is one insertion, deletion, substitution or adjacent transposition away. Character reset restores Receives gear to its default, replaces the loadouts with one default worn loadout, and clears wants and protect, while preserving the display name, imported membership, identity and snapshots. A valid reset preview replaces the previous one; invalid commands leave it pending, and confirmation at exactly 30 seconds is valid. Quote a character named `all` or `confirm` to distinguish it from the reserved reset commands. `/ll perf` reports the scope, item count and elapsed time of the latest completed full classification, or says when none has completed.

If the client cannot supply item type names, `/ll want` reports that types are unavailable and leaves saved data unchanged when resolving a type.

---

## 3. The window and its views

Everything in this section is one window, LootLogic's main window. Apart from the welcome dialog (2.1), the template apply dialog (4.3) and the add-to-wants popup (4.4), there is no other LootLogic screen in v1: the tooltip line, item badges and chat lines are not windows. Each view below is a tab of that window. Every view opens with a **Where** line: what the view is, and every way to reach it.

### 3.1 Window

**Opening it:**

| How | What happens |
|---|---|
| `/ll` or `/lootlogic` | Toggles the window. Opens on the last tab used (none used yet: Contents). |
| `/ll contents`, `/ll wants`, `/ll status` | Opens the window on that tab (`/ll wants Zugar` opens the Wants tab on that character). |
| Minimap button | Left-click toggles the window; drag to move it round the minimap; hide it from the Settings tab (M2). Minimap-button groupers such as EllesmereUI's may collect it (L45). |
| Addon compartment | Same as `/ll` (spec section 13; untested on Forever). |
| Blizzard Settings panel, LootLogic category | A button opens the window (spec section 13). |
| First login on the account | A welcome dialog appears once; its [Open setup] button opens the window on the Characters tab (2.1). |
| Buttons inside the window | The checklist and the Characters tab jump between tabs (listed under each view). |

No key is bound by default; the player can bind one to "toggle window" in the client's Key Bindings screen. The window never opens by itself, except by one setting, off by default: "open the Contents tab at the merchant, AH or mailbox", for players whose bag addon has no sections (Baganator, default bags). It opens only if the window is closed, and never closes it.

**Tabs, in order:**

| Tab | What it is | Layout | Reached from |
|---|---|---|---|
| Contents | What the current character's bags hold, by category, with cash totals | 3.4 | Tab; `/ll contents`; `/ll` with no tab used yet; the merchant, AH or mailbox setting |
| Characters | Roster, order, specs | 3.2 | Tab; checklist [Pick spec]; the welcome dialog's [Open setup] |
| Wants | What each character collects | 3.3 | Tab; `/ll wants [name]`; Characters "Wants" cell; checklist [Wants] |
| Weights | Stat weights per spec | 3.6 | Tab |
| Protect | Protect lists | 3.7 | Tab |
| Settings | AH rule, providers, gear, display, adapters | 3.8 | Tab |
| Status | Setup checklist and addon health | 3.5 | Tab; `/ll status`; chat lines that say "see /ll status" |

- **Size:** 680 x 470 UI units at scale 1, fixed. A scale slider (70% to 150%) in Settings stacks on the client UI scale.
- **Regions:** title bar 24, tab strip 24, content about 396, footer hint line 22.
- Movable, position saved. Escape closes (`UISpecialFrames`, from memory, untested).
- Plain frames and client font objects (`GameFontNormal`, `GameFontHighlightSmall`), so text follows the client's font scaling.

Mockups show proportions, not pixels. `Dr`, `Pa`, `Wl`, `Sh` stand for class icons; `[ic]` for item icons.

### 3.2 Characters tab

**Where:** the second tab of the main window. You get here by clicking the tab, by [Pick spec] on the Status checklist (which scrolls to that character's row and expands it), or by the welcome dialog's [Open setup] (which expands the current character's row).

**Why you are here:** you have just added a character, or an item went somewhere you did not expect, and you want to say who matters most and what each character is. Almost every visit is one of three jobs: put the characters in priority order, give each one a spec for better gear advice, or find out why a contested item went to someone else.

**What you get:** you stop being asked "who should get this?" at the bank. You decide once, here, and every later item follows the order. The Gear column and the contested line show the consequences before you find them in your bags: a character with Gear OFF gets no gear upgrades, and a contested type names its winner.

```
+- LootLogic ----------------------------------------------------- [x] -+
| Contents [Characters] Wants  Weights  Protect  Settings  Status       |
+-----------------------------------------------------------------------+
| Order decides who gets an item several characters want.               |
| Gear: the biggest gain wins; the order breaks a tie.                  |
|                                                                       |
|  #           Name        Lvl  Worn spec     Gear  Wants   Mail  Seen  |
|  1 [^][v] Dr Chamoomile  23   Bear          on    1 type  -     you   |
|  2 [^][v] Pa Boneset     12   Protection    on    2 types 2     2 d   |
|  3 [^][v] Wl Zugar        5   Affliction*   on    2 +2    -     9 d   |
|  4 [^][v] Sh Jujuniper   10   Enhancement   on    -       -     1 d   |
|     -     Pr Otherguy    60   Holy          -     -       -     12 d  |
|              Alliance: cannot receive from Chamoomile                 |
|                                                                       |
| Contested Metal and Stone: Boneset wins, Zugar wants it too           |
|                                                                       |
| v Zugar, Warlock 5, Horde                                             |
|   Worn  Name       Spec                   Linked set                  |
|   (o)   [Affliction] [Affliction*    v]  [none                v] [-]  |
|         Armour: [use the setting v]                                   |
|   [+ loadout]  [Keep Affliction]                                      |
|   [x] Receives gear upgrades   [Forget Zugar...]                      |
+-----------------------------------------------------------------------+
| Not listed? Log in on that character once with LootLogic enabled.     |
+-----------------------------------------------------------------------+
```

- Class colour on the name, class icon as the second cue.
- **Gear:** on, or OFF (switched off, for example for a bank alt). Clickable.
- **Wants:** a count; click opens the Wants tab on that character.
- **Mail:** items recorded as mailed to that character and not yet seen in its inbox (depends on L13, untested).
- **Seen:** snapshot age. Past `staleDays` it reads "16 d (old)": text plus colour.
- **Contested:** every want type claimed by two or more eligible characters, with the winner. Hidden when there are none.

**Specs and loadouts.** A character's spec is set on a **loadout**, not on the character. A loadout is a name plus a spec, for example "Cat" with the Cat spec.
- A new character has one loadout, named after its class's assumed spec by default, with that spec. "Pick a spec for the character" means picking the spec on that loadout.
- A character that plays more than one role (a druid who tanks, heals and does damage) can add a loadout for each, with its own spec.
- Exactly one loadout is the **worn** one: the role the character is wearing now. Move the radio when the character changes role.
- A loadout can be **linked** to a gear set the player already has in Outfitter or the Blizzard Equipment Manager. The link only labels the set's pieces in tooltips ("LootLogic: stays (in set Tank (Bear))"); every piece of an imported set stays whether it is linked or not. It does not set the spec.
- Gear is scored under the spec of every loadout. A piece that is the best owned piece under two loadouts' specs stays for both; a new item that beats it under only one of them becomes that loadout's best piece, and the old piece stays while it is still the best under the other. On the current character an item is an upgrade (Equip) only under the worn loadout's spec; under another loadout's spec, a piece that becomes best at any level in the window stays. A replaced piece is judged like any other item only when it no longer wins at any level in the window for any scored loadout. For another character an item is an upgrade if it beats what that character owns under any of its loadouts, and the tooltip names the loadout ("Chamoomile (+9% Cat over Ferocious Bracers)"). In v1, loadouts that share a spec and an armour rule share one comparison, and a loadout is not compared with the pieces of its own set (that is v1.1).
- Most players need only the first loadout. Extra loadouts are for characters that swap roles.

**Reading the screen** (items marked *design choice* are not fixed by the spec and can be changed):

| Element | Meaning |
|---|---|
| `#` and `[^][v]` | Position in the priority order. 1 wins contested wants. The buttons move the row up or down. Ineligible rows have none. |
| Name | The display name, in class colour with the class icon. Click it to change it (at most 14 characters, unique). Blank restores the automatic name. |
| Lvl | Level when the character was last seen. |
| Worn spec | The spec of the character's **worn** loadout, the one the character is wearing now. An asterisk (`Affliction*`) marks an assumed spec that the player has not picked; click to pick another, or press [Keep Affliction] on the expanded row to accept it. |
| Wants "2 types" | The number of item types (class or subclass flags) ticked for that character. Item includes and excludes are counted as "+N" after it ("2 +2": two types, two items). *Design choice.* |
| Ineligible row (Otherguy) | A character that cannot receive from the current character (for example, the other faction). Greyed, no order buttons, the reason on a second line. Not a destination. |
| Expanded row (`v Zugar, ...`) | That character's loadouts. Click the row header to expand or collapse. |
| Worn radio `(o)` | Marks the loadout the character is wearing now. Exactly one per character; move it when the character changes role. |
| Loadout name | Click it to rename the loadout (unique per character, case ignored). The default name is the spec's name and has no special meaning. |
| Spec, Linked set | The loadout's spec, and an imported Outfitter or Equipment Manager set linked to it, or none. |
| Armour | Use the setting (Settings tab), best armour only, or any armour, for this loadout. A druid can set Resto to any armour (cloth counts) and leave Bear on best only. |
| `[-]`, `[+ loadout]` | Remove this loadout, add another. |
| Receives gear upgrades | Off means no gear upgrades are routed to the character (Gear shows OFF); its wants still apply. For bank alts. On by default. |
| Forget | Deletes the character's stored data after a confirmation. It reappears if it logs in again. |

| State | What shows |
|---|---|
| Empty (only the current character) | One row (you). Content text: "Only Chamoomile so far. Log in on each of your other characters once with LootLogic enabled; they appear here. Nothing can be sent to a character LootLogic has not seen." |
| Loading | The linked-set dropdown reads "reading Outfitter..." until the import finishes. Rows never wait on it. |
| Stale | The Seen cell as above. Hover: "Zugar's gear, bags and level as of 16 d ago on this PC. Wants are not affected." |
| Error | A row whose snapshot will not load shows "data error: log in on Zugar to refresh" in place of level and spec, and is not a destination. Detail in Status. |
| Ineligible | Greyed, no order buttons, the reason on a second line (faction or region). |

### 3.3 Wants tab

**Where:** the third tab of the main window. You get here by clicking the tab, by clicking a character's Wants count on the Characters tab, by [Wants] on the Status checklist (both open it on that character), or by `/ll wants [name]`. It opens on the current character the first time each session, then on the character last edited (4.1).

**Why you are here:** you want a character to collect something, such as cloth for the tailor or ore for the blacksmith, without having to remember to send it. This is the screen where a decision about a profession becomes a standing instruction.

**What you get:** the "Zugar needs cloth" problem solved once. Tick a type (or apply a template for the profession) and every cloth item in your bags is routed to Zugar from then on. When you leave you know what each alt will collect, and where two characters want the same thing, who wins.

```
+-----------------------------------------------------------------------+
| For: [Chamoomile] [Boneset] [*Zugar*] [Jujuniper] [Otherguy]          |
|      [Template v]  [Copy from v]                                      |
+-------------------------------+---------------------------------------+
| Search [               ]      |  Items for Zugar                      |
|                               |  [ic] Elixir of Wisdom  Include  [x]  |
| v Trade Goods                 |  [ic] Felcloth          Exclude  [x]  |
|   [x] Cloth       [any    v]  |  [ drop an item, or shift-click ]     |
|       Linen, Wool, thread...  |                                       |
|       (110 in bags)           |                                       |
|   [ ] Leather                 |                                       |
|   [x] Metal and Stone [any v] |                                       |
|     Boneset wants it too: wins|                                       |
|   [ ] Parts                   |                                       |
| > Recipe                      |                                       |
| > Consumable (careful)        |                                       |
| > Armor                       |                                       |
+-------------------------------+---------------------------------------+
| Changes apply at once. Shift-hover a bag item for how it was sorted.  |
+-----------------------------------------------------------------------+
```

Behaviour is in section 4.

**Reading the screen:**

| Element | Meaning |
|---|---|
| `For:` button row | Whose wants are being edited. The starred one is selected (4.1). |
| Template, Copy from | Apply a shipped starter set of flags, or copy another character's wants. Both merge (4.3). |
| Search | Filters the tree by type name and by example item (4.2). |
| `v` and `>` | Expanded and collapsed tree rows. |
| `[x]` and `[ ]` on a tree row | Whether the selected character collects that item type. |
| `[any v]` | Minimum quality for that type: any, common, uncommon, rare or epic. |
| Grey sub-line ("Linen, Wool, thread...") | Examples of what the type contains (4.2). |
| "(110 in bags)" | Units of that type in the current character's bags. |
| "Boneset wants it too: wins" | Another eligible character also wants the type, and who wins by the order (4.2). |
| "(careful)" | The type is Consumable. Ticking it shows a warning (4.2). |
| Right pane, "Items for Zugar" | Single-item includes and excludes. `[x]` removes one. Add by dropping an item or shift-clicking a link. |

| State | What shows |
|---|---|
| Only the current character registered | One button; notice as in 2.3 |
| No wants | Right pane: "Zugar wants nothing. Tick types on the left or pick a template." |
| Ineligible character | Notice: "Otherguy is Alliance: cannot receive from Chamoomile." Editing still allowed. |

### 3.4 Contents tab

**Where:** the first tab of the main window. You get here by clicking the tab, by `/ll contents`, by `/ll` when no tab has been used yet, or by the "open the Contents tab at the merchant, AH or mailbox" setting (3.1).

**Why you are here:** you want to see what the current character's bags hold, sorted by where each item belongs, without opening each bag or hovering over each item. For players whose bag addon shows tooltips only, this is the only complete list.

**What you get:** the state of the bags. One row per category with how many stacks and items it holds and what they are worth in cash, and a total. Click a row to show its items as icons; hovering one gives its reason. The tab states what is there and never says what to do. A "notice" in any state table is a line of text inside the tab, never a pop-up.

```
+-----------------------------------------------------------------------+
| Chamoomile's bags   [Bags] [Bank]        Prices: Auctionator, today   |
+-----------------------------------------------------------------------+
| Classification Stacks   Items   Cash                                  |
| Boneset             3      45   -                                     |
| Zugar               8     120   -                                     |
| AH                  6      88   about 4g 10s (after the AH cut)       |
| Vendor             14      31   2g 31s                                |
| Vendor/AH           5       5   1g 2s (vendor price)                  |
| Equip               1       1   -                                     |
| No category         2       2   -                                     |
|                                 ---------------------------------     |
| Total cash                      about 7g 43s                          |
+-----------------------------------------------------------------------+
| Vendor/AH (5 items)                                                   |
|  [ic] [ic] [ic] [ic] [ic]            (hover an icon for its reason)   |
|                                                                       |
+-----------------------------------------------------------------------+
```

- **Row order:** the things to move come first: the other characters in the player's character order, then AH, Vendor and Vendor/AH; then Equip (for the player's own use), then No category.
- Clicking a row lists its items in the lower pane in place of the Vendor/AH list. The pane shows Vendor/AH when the window opens, because that is the category with a reason worth reading.
- The lower pane shows each stack as an item icon with its count, sorted by value, highest first, so a long list stays compact. Hover an icon for the item tooltip and a line with the reason (the same words as the bag tooltip) and the cash value.
- **No category** is every item with no destination: gear the character will wear later ("equip at level 25"), loadout and set gear, Protect-list items, quest items and the rest. They are not a category in the bag addon; the row exists so that the table adds up to the whole bag: the stacks and items in all rows together equal what the container holds. Its icons are grouped by reason.
- **Equip** shows "-" for cash. The size of the upgrade is in the icon's hover line ("+11% Bear over Thick Hide Belt, worn").
- **AH cash** is the providers' min buyout after the AH cut, summed. It is an estimate and the hover says so. Unsold auctions return and may sell for less, so the total is not a promise.
- **Vendor/AH cash** is the vendor price, a floor, since listing may fetch more.
- **Total cash** adds the AH, Vendor and Vendor/AH rows (Vendor/AH rows at the vendor price). Character and Equip rows are not cash.

**Reading the screen:**

| Element | Meaning |
|---|---|
| `[Bags] [Bank]` | Which container the table covers. Bank needs the bank to be open (see the states below). |
| "Prices: Auctionator, today" | The price source in use and the age of its newest price. |
| **Classification** | The category: another character (by display name), or Equip, AH, Vendor, Vendor/AH, or No category. |
| **Stacks** | The number of bag slots holding items for that category. One slot is one stack, full or partial. *Design choice: not defined in the spec.* |
| **Items** | The total units across those stacks. 8 stacks holding 120 items is 8 slots with 120 units in all. |
| **Cash** | Estimated cash if the row were sold. Characters, Equip and No category: "-", because the value is theirs to use. AH: estimated proceeds after the AH cut. Vendor: the summed merchant price. Vendor/AH: the vendor price. |
| **Total cash** | The sum of the cash rows. |
| Item icons | One icon per item stack with its count; the tooltip adds the reason and cash value. |

| State | What shows |
|---|---|
| Nothing routed | "Nothing is routed. Everything in these bags stays with Chamoomile." |
| No price addon | Notice: "No price addon: everything tradable that nobody wants is in Vendor/AH. Auctionator or AHDB would sort most of it." |
| Provider, no scan | Notice: "No AH scan yet: Vendor/AH holds everything tradable that nobody wants." |
| Loading | "3 items still loading." Rows show what is known. |
| Error | "2 items could not be sorted: see Status." |
| [Bank] with the bank closed | "Open your bank to sort it." |

### 3.5 Status tab with the checklist

**Where:** the last tab of the main window. You get here by clicking the tab, `/ll status`, or any chat line that says "see /ll status".

**Why you are here:** either it is your first time and you want to know what to do next, or something looks wrong (an item is not sorted, a price is missing, a section has vanished) and you want to find the cause.

**What you get:** confidence. The checklist turns "is this set up properly?" into a short list with a button beside each gap. The status block says which addons LootLogic found and whether they work, so a bad result can be traced to its cause (no prices yet, a bag addon failed, a character not seen for weeks). It is also what you copy into a bug report. The mock leaves out the top block (2.1), which sits above the checklist.

```
+-----------------------------------------------------------------------+
| SETUP                                                     4 of 6 done |
|  [done] Chamoomile registered (you)                                   |
|  [done] Roster: 5 characters. Missing one? Log in on it once.         |
|  [TIP ] Zugar is using an assumed spec (Affliction).                  |
|         [Keep Affliction] [Pick spec]                                 |
|  [TIP ] Jujuniper wants nothing: only gear upgrades go there.         |
|         [Wants] [Gear only]                                           |
|  [done] Prices: Auctionator today; AHDB scan 14:02 (Horde)            |
|  [done] Bags: BetterBags sections active                              |
|  [info] Open your bank once so gear upgrades count it.                |
+-----------------------------------------------------------------------+
| STATUS                                                                |
|  Prices  Auctionator   found   newest 0 d                             |
|          AHDB          found   newest 0 d   1,204 items               |
|                        last scan 14:02   house Horde                  |
|  Bags    BetterBags    active  last refresh 2 s ago                   |
|          Default bags  idle    (BetterBags draws the bags)            |
|          Tooltip       active                                         |
|  Sets    Equipment Manager  active                                    |
|          Outfitter          active                                    |
|  Roster  Chamoomile now, Jujuniper 1 d, Boneset 2 d, Zugar 9 d,       |
|          Otherguy 12 d                                                |
|  Build   LootLogic 1.0.0, schema 2, client 1.60.1.70532               |
|  Errors  none this session                       [Copy] [Clear]       |
+-----------------------------------------------------------------------+
```

| State | What shows |
|---|---|
| Loading (first seconds after login) | "Checking addons..." in the Prices and Bags rows until the `PLAYER_LOGIN` work is done |
| No provider | Prices row: "none: everything tradable that nobody wants goes to Vendor/AH"; checklist line 5 as TIP |
| Provider error | "AHDB: error (LastPrice missing), reading its saved data instead" or "AHDB: off after an error"; the error in the Errors list |
| Adapter failed | Bags row: "BetterBags: FAILED: <first line>. Tooltips still work." [Retry] [Turn off]. Checklist line 6 turns NEED. |
| Errors | "3 this session", the last 20 in a scroll list |

[Copy] fills a selectable edit box; an addon cannot write to the clipboard.

**Reading the screen:**

| Element | Meaning |
|---|---|
| `[done]`, `[NEED]`, `[TIP ]`, `[info]` | Checklist tags (2.2). NEED means results are misleading without it. |
| "4 of 6 done" | Checklist lines 1 to 6 that are done, out of 6. Line 7 (bank) is advice and never counts. Lines 2 and 6 count although their not-done tag is info, and line 4's "receives no gear" line counts as done. |
| Prices rows | One per price provider found. "newest 0 d" is the age in days of its newest price (for Auctionator, the newest of the prices LootLogic has read this session; "no price seen yet" before the first, and "Auctionator: price over 21 d old" when every price read has no age because it is older than 21 days). "1,204 items" is how many items it has prices for (AHDB only; Auctionator's public API gives no count, so its row omits it). When `requireLastScan` is on and Auctionator is the only provider, its row adds "latest-scan setting ignored (needs AHDB)". "last scan 14:02, house Horde" is when the AH was last scanned and for which faction's auction house. |
| Bags rows | One per bag display. **active** means it is drawing categories now. **idle** means it is installed but another addon draws the bags. "last refresh 2 s ago" is the last time LootLogic updated it. |
| Sets rows | One per set source found (Equipment Manager, Outfitter). **active** means its sets can be read for the linked-set dropdown and for protection; **found** means it is installed but no set has been read yet; **failed** shows the error, as for a bag addon. |
| Roster | How long ago each character was last seen. |
| Build | LootLogic version, the saved-data format version (schema), and the game client build. |
| Errors, `[Copy]`, `[Clear]` | Errors this session. Copy opens a box to select from. Clear empties the list. |

### 3.6 Weights tab

**Where:** the fourth tab of the main window. You get here by clicking the tab.

**Why you are here:** a gear recommendation looks wrong and you want to see how a spec's stats are counted.

**What you get:** gear routing you can check: how much each stat counts for each spec, with where the numbers came from. Read-only in v1: nothing here changes a result, so nothing needs saving or confirming.

```
+-----------------------------------------------------------------------+
| Search [            ]  | Warlock: Affliction                          |
|                        | WoWSims Forever, unverified in game          |
| v Druid                | Sim commit 3f9a1c2                           |
|   Balance              |                                              |
|   Bear                 |  Stat                  Weight per point      |
|   Cat                  |  Hit rating            1.28  ############    |
|   Restoration (team)   |  Spell power           1.00  #########       |
| > Hunter               |  Shadow spell power    0.90  ########        |
| > Mage                 |  Haste rating          0.78  #######         |
| > Paladin              |  Crit rating           0.57  #####           |
| > Priest               |  Intellect             0.23  ##              |
| > Rogue                |  Mana per 5 seconds    0.14  #               |
| > Shaman               |  Fire spell power      0.10  #               |
| v Warlock              |  Stamina               0.01                  |
|   Affliction  (you)    |                                              |
|   Demonology           |  Used by: Zugar (Demonology)                 |
|   Destruction          |  Stats not listed count for nothing.         |
| > Warrior              |                                              |
+------------------------+----------------------------------------------+
| Weights are read-only in this version.                                |
+-----------------------------------------------------------------------+
```

- **Left:** the spec list, grouped by class, collapsed except for the classes of the roster's characters (the class of the selected character's worn spec starts expanded and selected). It lists only specs that have a table (spec 8.2). Search filters by class and spec name.
- **Right header:** class and spec label, then the table's source and confidence label, shortened to fit the pane (for example "WoWSims Forever, unverified in game"; "WoWSims Forever, assumes group tanking, unverified in game" for the Druid Bear and Paladin Protection tables; or "Team judgement, unverified" for the five hand-written healer tables), then the sim commit for a computed table (the table's `commit`, technical findings 14.1).
- **Right table:** one row per stat with a weight above 0, sorted by weight, highest first. The bar is drawn to the largest weight in the table, so the shape of the table reads at a glance. The number is the weight per rating point (spec 8.2), shown to two decimals.
- A table written by hand per 1% shows the weights after the load-time conversion to per rating point, with a footer note "Written per 1%; shown per rating point at the level 60 conversion (unverified)".
- **Used by:** the roster's loadouts that use this spec, so the tab answers "who is this table scoring?". Clicking a name opens the Characters tab on that character.
- **Specs in the list marked `(team)`** are hand-written healer tables. `(you)` marks the spec of the current character's worn loadout.

**Reading the screen:**

| Element | Meaning |
|---|---|
| Class and spec rows | Every spec with a shipped table. `v` and `>` expand and collapse a class. |
| Source line | Where the numbers came from, with its confidence label. The label is the only place the player can see that a table is unverified. |
| Stat, Weight, bar | A stat's name (the client's wording), its weight per rating point, and the weight against the largest one. |
| "Used by" | Loadouts on the roster that use this spec. |
| "Stats not listed count for nothing" | A stat with weight 0 or no weight does not change a score. Weapon speed is never scored (spec 8.1). |

| State | What shows |
|---|---|
| Nothing selected (first open, no roster match) | The first spec in the list, expanded, with its table |
| Search matches nothing | "No spec matches 'xyz'." in the left pane; the right pane keeps the last table |
| Class with no table yet (before M4) | The class is absent from the list, and so are its specs |
| Table missing or unreadable | "This table could not be read. Gear for this spec is not scored; see Status." and the error in the Errors list |
| Spec is assumed for a character | "Used by: Zugar (Affliction, assumed spec)" |

### 3.7 Protect tab

**Where:** the fifth tab of the main window. You get here by clicking the tab. The tab's contents change with `/ll protect` and the "toggle protect on hovered item" key (M2) while it is open.

**Why you are here:** you want to stop LootLogic suggesting an item for sale, or you want to check or undo what you protected earlier.

**What you get:** control over the exceptions in one place: the protected items, for one character and for all. A protected item is never put in Vendor, AH or another character's section (spec 7.2 steps 1b and 3c); it still shows in the Contents tab under No category, with the reason "protected".

```
+-----------------------------------------------------------------------+
| For: [*Chamoomile*] [Boneset] [Zugar] [Jujuniper] [Otherguy]          |
+--------------------------------------+--------------------------------+
| Chamoomile only (3)                  | Every character (2)            |
|                                      |                                |
| [ic] Ferocious Bracers     [x]       | [ic] Hearthstone       [x]     |
| [ic] Gnarled Staff                   | [ic] Mining Pick       [x]     |
|      this roll only        [x]       |                                |
| [ic] Thick Hide Belt       [x]       |                                |
|                                      |                                |
|   [ drop an item here, or            |   [ drop an item here, or      |
|     shift-click a link ]             |     shift-click a link ]       |
+--------------------------------------+--------------------------------+
| Also kept without being listed: pieces of Outfitter and Equipment     |
| Manager sets, and the best piece you own for each loadout's spec.     |
+-----------------------------------------------------------------------+
```

- **For:** the same character button row as the Wants tab (4.1): up to 8 buttons, a dropdown beyond that, the character last edited remembered separately from the Wants tab (`ui.protectFor`; *design choice*). It opens on the current character the first time each session, then on the character last edited. The left list is that character's list; it only affects results while that character is the one logged in, which is why it is a per-character list.
- **Right list:** the global list, the same for every character, whichever button is selected.
- **Each row:** item icon and name (hover for the item tooltip), a second line "this roll only" when the entry is an instance key (`itemID:suffixID`, spec 6) and nothing when it protects every roll, and `[x]` to remove. A plain item ID row has no second line.
- **Adding:** drop an item held on the cursor on the slot at the bottom of a list, or shift-click a link into it (the same box behaviour as the Wants right pane, L37). A dropped or linked item with a suffix adds that roll only; to protect every roll the player uses `/ll protect <itemID>`. Dropping an item already in that list does nothing and flashes its row. The "toggle protect" key and `/ll protect` toggle an entry on the current character's list (or, with `global`, the global list), whichever character button is selected, and the tab updates at once if open.
- **Names load late:** a row whose item data is not cached shows "item 12345" and fills in when loaded.
- **Footer:** a fixed line telling the player what is protected without being listed, so a missing entry for a set piece is not a worry.

**Reading the screen:**

| Element | Meaning |
|---|---|
| Left heading "Chamoomile only (3)" | The selected character's list and how many entries it has |
| Right heading "Every character (2)" | The global list |
| "this roll only" | The entry is one random-suffix roll, not the whole item |
| `[x]` | Remove the entry. No confirmation: adding it again is one drop. |
| Drop slot | Add by dropping an item or shift-clicking a link |

| State | What shows |
|---|---|
| Empty list | The slot, with "Nothing protected for Chamoomile." above it (global: "Nothing protected for every character.") |
| Only the current character registered | One button; no notice needed: the lists still work |
| Another character selected | The left list is theirs, with the note "Applies when you are logged in on Boneset." |
| Duplicate across lists | An item in both lists shows "also on the global list" under its name in the left list. It stays protected until it is removed from both. |
| Plain ID stored, one roll toggled (`/ll protect`) | The command's chat message applies (spec 13); the tab does not change |
### 3.8 Settings tab

**Where:** the sixth tab of the main window. You get here by clicking the tab, or from a Blizzard Settings panel button (spec 13) that opens the window. It is not the page where characters are set up: that is the Characters tab (2.1).

**Why you are here:** the AH rule does not match how you sell, or a display choice (badges, colours, tooltip) bothers you.

**What you get:** LootLogic bends to how you play: your AH cut and minimum gain, your price source order, and a display that suits your eyes. Every change applies at once and is saved at once; there is no Save or Apply button.

The tab has two panes, as the Weights tab does. The left pane lists seven groups; the right pane shows the selected group and scrolls if it is longer than the window. The tab remembers the last group (`ui.settingsGroup`; *design choice*).

```
+-----------------------------------------------------------------------+
| [Sell rule]        | Sell rule: when an item goes to the AH           |
|  Gear              |                                                  |
|  Item classes      |  AH cut            [ 5 ]%                        |
|  Display           |  Minimum gain      [ 0 ]g [ 1 ]s [ 0 ]c          |
|  Notifications     |    for the whole stack, not each item            |
|  Window            |  Minimum gain      [ 10 ]%  of the vendor price  |
|  Adapters          |    for each item                                 |
|                    |  Oldest usable price   [ 7 ] days                |
|                    |  [ ] Only prices from the latest scan            |
|                    |                                                  |
|                    |  Price source order (used when ages tie)         |
|                    |   1  AHDB          [^][v]                        |
|                    |   2  Auctionator   [^][v]                        |
|                    |                                                  |
|                    |  [Reset this group to defaults]                  |
+--------------------+--------------------------------------------------+
| Changes apply at once. /ll reset clears every setting.                |
+-----------------------------------------------------------------------+
```

**Groups and controls.** The labels are the words on screen. Defaults are the spec's (section 6); each control stores the key shown.

*Sell rule* (`settings.ah`): the "AH rule" of spec 7.4.

| Control | Key | Notes |
|---|---|---|
| AH cut, percent | `ahCutPct` | Whole number, 0 to 50. The default is 5, the faction AH cut. |
| Minimum gain for the whole stack | `minGainCopper` | Three boxes (gold, silver, copper) that show and store one copper amount. An amount above the maximum the boxes hold is clamped. |
| Minimum gain for each item, percent | `minGainPct` | Whole number, 0 to 100. Only applies to items with a vendor price (spec 7.4); the hint says so. |
| Oldest usable price | `maxPriceAgeDays` | Whole days, 0 to 60. 0 means only prices seen today. |
| Only prices from the latest scan | `requireLastScan` | Tick box. Hint: "Needs AHDB. With AHDB installed, only its prices are used. With only Auctionator this is ignored." When the setting is on and Auctionator is the only provider, the hint turns into the warning of the login line (2.1). |
| Price source order | `providerOrder` | Two rows with up and down buttons. Only a tie-break when two prices are equally fresh (spec 4). A provider that is not installed stays listed and greyed ("not installed"). |

*Gear* (`settings.gear`):

| Control | Key | Notes |
|---|---|---|
| Look ahead, levels | `lookAheadLevels` | Whole number, 0 to 10. Keeps the best usable gear at each level in the window, preserving intermediate upgrades and discarding inferior alternatives for the same level. |
| The character you are on keeps upgrades within the look-ahead | `hereWinsInLookAhead` | Tick box. Greyed when look-ahead is 0. |
| Smallest gain that counts as an upgrade, percent | `minUpgradePct` | Number, 0 to 50, one decimal. |
| Best armour only | `bestArmorOnly` | Tick box. Hint: "Each loadout can override this on the Characters tab." |
| Compare item level when no stat is weighted | `itemLevelFallback` | Tick box. |

Gear advice compares a candidate with owned gear usable at the level the candidate can first be used, or the current level if later. A stronger item for a later level does not hide an intermediate upgrade. A piece that is best at any level in the window stays; one that never wins follows the usual routing and sell rules. Rings, trinkets and weapons use their pair rules separately at each level (spec 8.4 to 8.6). This needs no per-level setup or recorded sets. The current-character priority switch affects the order of upgrade routing, not protection of owned progression gear.

A saved loadout whose spec has no weights in this build gives no gear advice, like a loadout with no spec. Its saved choice remains intact. For the current character, equippable bag and bank gear stays with the existing "no gear advice for <class> in this build" reason, including when another loadout can be scored; link-only results can still advise for other characters (spec 7.2). Future-level gear is judged from level, class and proficiency rules without a live usability veto (spec 8.3).

*Item classes* (`settings.classOverride`): one list of the item classes and Miscellaneous subclasses, in the client's names, from the shipped defaults (technical findings 14.1).

```
|  Item class              Nobody wants it, so   |
|  Weapon                  [Sell v]              |
|  Armor                   [Sell v]              |
|  Consumable              [Stay v]              |
|  Trade Goods             [Sell v]              |
|  Miscellaneous: Junk     [Sell v]              |
|  Miscellaneous: Reagent  [Sell v]  changed [x] |
```

- Each row is a Stay or Sell dropdown. Stay means the item is kept; Sell means it is sorted to Vendor, AH or Vendor/AH (spec 7.2 step 5).
- A row the player changed from the default shows "changed" and a `[x]` that removes the override. Rows at the default show nothing. Only changes are saved (the shipped defaults are not copied).
- Hint at the top: "Applies only when no character wants the item and it is not gear anyone needs."

*Display* (`settings.display`, `ui.minimap`):

| Control | Key | Notes |
|---|---|---|
| Item tooltip line | `display.tooltip` | Tick box. |
| Show a line for items nobody wants that are not in my bags | `display.tooltipNoWant` | Tick box, off by default. Greyed when the tooltip line is off. |
| Item badge | `display.overlay` | Tick box. |
| Badge position | `display.badge.position` | Dropdown: top left, top right, bottom left, bottom right. Greyed when the badge is off. Hint: "The stack count is bottom right." |
| Badge size | `display.badge.size` | Slider, 8 to 20 units. Greyed when the badge is off. |
| Colours | `display.palette` | Dropdown: Automatic (follow the client colour-blind setting), Default, Colour-blind. A swatch row beside it shows the four category colours with their letters. |
| Show the minimap button | `ui.minimap.hide` (inverted) | Tick box. |
| Open the Contents tab at the merchant, AH or mailbox | `ui.autoOpenContents` | Tick box, off by default. |

*Notifications* (`settings.notify`, `staleDays`): each is a tick box with a one-line example of the chat line.

| Control | Key | Default |
|---|---|---|
| Login line about characters not seen for [14] days | `notify.staleSnapshot`, `staleDays` | on; days: whole number, 1 to 365. The days value also sets when a bank snapshot counts as old, so it stays editable when the tick is off. |
| Line after each AH scan | `notify.scanSummary` | on |
| Line when mail is recorded | `notify.mailRecorded` | off |
| Login line about upgrades waiting in your mail | `notify.mailUpgrade` | on |

*Window* (`ui.scale`): one slider, 70% to 150% in steps of 5, applied as it moves. Hint: "On top of the game's UI scale."

*Adapters* (`settings.adapters`): one tick box per bag addon: BetterBags, BagBrother, ArkInventory, EllesmereUI Bags and the default bags. An addon that is not installed shows its box greyed with "not installed". An adapter that failed shows "failed: see Status". Changing a box applies after `/reload` for a bag addon that has to be hooked at load, and says so beside the box (*untested*).

**Reading the screen:**

| Element | Meaning |
|---|---|
| Left group list | The seven groups. The selected one is highlighted and also marked in text (`[Sell rule]`), so colour is not the only cue. |
| Greyed control | Does not apply while another control is off or something is missing. A line of text says why on hover. |
| "changed" | A class row that differs from the shipped default. |
| `[Reset this group to defaults]` | Sets every control in the group to its default after a confirmation ("Reset the Sell rule settings?"). Item classes: removes every override. It does not touch any other group, wants, loadouts or protect lists. |
| Footer | `/ll reset` clears every setting (spec 13). |

| State | What shows |
|---|---|
| A value is out of range or not a number | The box keeps the last good value and flashes red; a line under it gives the range ("0 to 50") |
| No price addon installed | Sell rule: a line at the top "No price addon found: the AH rule has nothing to work on until one is installed." The controls stay editable. |
| Only one price provider installed | The order control is greyed with "Needs two price addons" |
| A setting changed | The next classification uses it; the Contents tab and tooltips update within a second |
| Saved data newer than the addon, or not upgraded | Every control is greyed with the notice of spec 6 (the saved data is newer than the addon, or could not be upgraded, and is left unchanged) |

---

## 4. Wants editor usability

### 4.1 Character picker
A **button row** (names in class colour, with class icons) shows the whole roster and switches character in one click. Up to 8 buttons, a dropdown beyond that. It opens on the current character the first time each session, then remembers the last character edited (`ui.wantsFor`), which suits setting up all alts from one character.

### 4.2 The type tree
- Client names (`GetItemClassInfo`, `GetItemSubClassInfo`), as in the spec.
- **Search** filters classes and subclasses by name and by example item.
- **Examples** under each subclass, from a small shipped list built from the game data dump (`Data/TypeExamples.lua`): "Linen, Wool, thread..." under Cloth; "vials, dyes, flux, gems, fish, Flint and Tinder" under Other (7:11). Names like "Other" and "Parts" are unusable without them.
- **Contested marker** on any row another eligible character also wants: "Boneset wants it too: wins" or "Boneset wants it too: Zugar wins". The global order becomes visible where the choice is made.
- **Bag count** under a ticked row: "(110 in bags)".
- Ticking a Consumable type shows a warning, because every character uses consumables (potions, food, scrolls) and the tick pulls that type from all of them: "Every consumable of this type on your other characters will be sorted to Zugar."

### 4.3 Templates
A template is a set of type flags (and, rarely, item includes), applied by **merge**, never replace. A one-line diff shows before applying, including any contest: "Adds Metal and Stone, Parts and Recipe: Engineering. Boneset also wants Metal and Stone and wins (order)." Templates are shipped data (`Data/Templates.lua`); IDs from technical findings section 5 (source-read data, L8).

| Template | Flags | Note |
|---|---|---|
| Tailoring | 7:5 Cloth, 9:2 | Thread is in 7:5 |
| Leatherworking | 7:6 Leather, 9:1 | Salt and hides are in 7:6 (Light Hide 783: game data) |
| Alchemy | 7:9 Herb, 9:6 | Vials are vendor goods in 7:11; not included |
| Enchanting | 7:12 Enchanting, 9:8 | Runed rods are BoP: they always stay |
| Blacksmithing | 7:7 Metal and Stone, 9:4 | Flux is 7:11 (Weak Flux 2880: game data); add per item if wanted |
| Engineering | 7:7, 7:1 Parts, 9:3 | Contests Blacksmithing on 7:7 |
| Cooking | 7:8 Meat, 9:5 | Eggs are 7:8 too (Small Egg 6889: game data) |
| First Aid | 7:5 Cloth, 9:7 | Contests Tailoring on 7:5 |
| Fishing | 9:9, 2:20 Fishing pole | There is no fishing loadout to compare poles against, so poles are routed by this want |
| Disenchanter | 2:* and 4:*, minimum Uncommon | Gear routing (step 3) runs first, so this only catches gear that is an upgrade for nobody |

- The apply dialog has an "include recipes" box, on by default. Recipes use the v1 "Already known" check for the current character only (spec section 10), so a recipe the wanter already knows still routes to it until v1.1.
- **No armour-class templates.** Gear is routed by score (step 3) before wants are read, so an "all Leather" want only collects leftovers that are an upgrade for nobody, and hoards them on one character. The Disenchanter template covers the one case where that is the point.

**Copy from:** merges by default; a "replace" option clears the target first. Includes and excludes are copied.

**Import and export string (v1.1, not in v1).** A character's wants as a short text string, in the same family as the weights string, to copy, share or move to another PC. An external tool could also generate one from a list to paste in game (external tools still never write `LootLogicDB`). In v1, templates and "Copy from" set up the player's own characters.

### 4.4 Click budget: "Zugar needs cloth"

| Path | Steps | Actions |
|---|---|---|
| Tree | `/ll` (key), Wants tab, Zugar, expand Trade Goods, tick Cloth | 5 |
| Search | `/ll`, Wants, Zugar, type "cloth", tick | 4 plus typing |
| Template | `/ll`, Wants, Zugar, Template, Tailoring, Apply | 6, and sets recipes too |
| From the item | Hover Linen Cloth, press "add hovered item to wants", pick Zugar, pick "all Cloth" or "only Linen Cloth" | 3 |
| Slash (spec) | `/ll want Zugar [Linen Cloth]` | 1 command; an item include, not the type |

Target: **at most 5 actions** from a closed window to a working want, **3 from the item**. The item path needs the "add hovered item to wants" keybinding and a small popup. The window remembers tab and character, so later edits are 2 or 3 clicks.

---

## 5. The town trip

### 5.1 Order

There is no fixed order: the player visits the AH, the merchant and the mailbox as suits them, and the Contents tab shows all three piles at any time. One fact is worth knowing: a fresh AH scan moves items out of Vendor/AH, so selling Vendor items before a scan can vendor something the scan would have put in AH. What is still Vendor/AH after a fresh scan is an item nobody is selling, and the choice of vendor or AH is the player's.

### 5.2 How categories update

| Player action | LootLogic sees | Effect | Feedback |
|---|---|---|---|
| Sells to a merchant | `BAG_UPDATE_DELAYED` | The stack leaves Vendor; a buyback comes back and is sorted again | Section count and Contents totals drop |
| Posts at the AH | `BAG_UPDATE_DELAYED` | Leaves AH; unsold auctions return by mail and are sorted when taken | As above |
| Scans the AH | Auctionator `RegisterForDBUpdate`, AHDB `SCAN_DATA` | Step-6 results recomputed: Vendor/AH shrinks, some AH and Vendor swap | One chat line per scan (setting, on) |
| Mails a roster character | `SendMail` hook and `MAIL_SEND_SUCCESS` (L13, untested) | Items leave the section and are recorded as inbound, so they count as the recipient's gear. A second ring bound for Zugar may now go to Boneset, because Zugar's baseline rose. | Mail column on the Characters tab; optional chat line "mail to Zugar recorded (3 items)" (off) |
| Mails part of a stack | Split, then send | Flags only: the rest stays in Zugar's section | "Zugar 8" remains |
| Deposits in the bank | Bag update; bank view while open | Sorted the same way in the bank | |

Two side effects to expect:
- **BetterBags caches per item ID** until `ReprocessAllItems`, which runs at most once per 2 s (technical findings 12.2). A section can lag a sale by up to 2 s. Untested.
- **Items can change section mid-trip** after a scan or a mail (the ring case). That is correct and the tooltip explains it. If it annoys in practice, a "hold categories while a merchant, AH or mailbox is open" setting is the thing to try (8.1).

### 5.3 What read-only v1 can and cannot do

| Can | Cannot |
|---|---|
| Sort every item and show it in sections, badges, tooltips and the Contents tab | Sell, list, mail, attach, split, delete or move any item |
| Total vendor value and estimated AH value per category | Choose quantities (flags only until v2) |
| List each character's items | Confirm a mail arrived until the recipient opens its mailbox |
| Record wants and Protect entries | Fill the mail recipient or open any frame |
| Record mail sent to roster characters as inbound | Know about play on another PC or with LootLogic off |

A docked "trip strip" (a slim panel beside the merchant, mail or AH frame with that stop's category and total) is a possible later addition (spec section 23). The Contents tab covers it for v1.

### 5.4 Shift detail and `/ll why`

An item-link popup that matches an item ID and random suffix in the player's bags shows the first matching bag item's verdict, followed by " (matches an item in your bags)". Without a match it shows the link-only verdict. Holding Shift over an item adds the detail under the tooltip line; `/ll why` prints the same lines in chat, the first starting "LootLogic:". Pressing or releasing Shift while the tooltip is shown adds or removes the detail without a new hover: LootLogic reads `IsShiftKeyDown()` and, on the `MODIFIER_STATE_CHANGED` event, sets the tooltip again from its owner (from memory; live check L59, technical findings 12.2). If L59 fails, the detail is shown only by `/ll why`. At most 8 lines, in the order below, each part only when it applies (spec section 13). A long line wraps in the tooltip and still counts as one.

| Part | Lines | Shown when |
|---|---|---|
| Category line | 1 | Always: the tooltip line itself |
| Wants | 1 | Someone's wants match: the winner first ("you" for the current character), then the others in the player's character order |
| Gear | 1 per loadout comparison | The item is gear: the winner's loadouts for a result that goes to another character as an upgrade, the current character's for any other, largest gain first, each with its baseline piece and where it is |
| Runners-up | 1 | Other characters were compared as gear destinations: up to two after the winner |
| Price | 2 | A price was read, including on demand for detail: the price and its net after the cut; then the gain per unit and for the whole holding, and the thresholds. A rejected stale quote and its calculations are marked stale. The lookup does not change the verdict |

When additional comparisons needed only for detail are still loading, the verdict and available detail remain visible and the detail indicates that comparisons are loading. When the parts come to more than 8 lines, the gear lines with the smallest gains are cut and the last one kept ends "(and N more)".

When `/ll why` cannot find the item, it replies "Couldn't find that item. Use /ll why followed by an item link." With no argument and nothing hovered, it replies "Hover an item or give a link."

Examples, hovered on Chamoomile (proportions, not final wording):

```
LootLogic: Zugar (+18% Affliction over Band of Thorns; Boneset +6%)
  Zugar, Affliction: +18% vs Band of Thorns (worn)
  Runners-up: Boneset +6% Protection vs Seal Ring (bank seen 4 d ago); Jujuniper +2% Enhancement vs Copper Ring (worn)

LootLogic: AH (12s 30c each, +8s over vendor after the 5% cut; Auctionator, today)
  Chamoomile, Bear: -4% vs Thick Hide Belt (worn)
  Chamoomile, Cat: -12% vs Ferocious Belt (bank seen 3 d ago)
  Price: 12s 30c each (Auctionator, today), 11s 68c after the 5% cut
  Gain over vendor (3s 68c): +8s each, +8s in all (1 held); needs 1s in all and 10% each

LootLogic: Zugar (wants Trade Goods: Cloth)
  Wanted by: Zugar (Trade Goods: Cloth), then Boneset (Linen Cloth)
```

---

## 6. Stale and missing data

Gear upgrade percentages in reasons and runner-up clauses use one decimal place, omitting a trailing zero: "+3.6%", "+4%". The displayed rounding does not change upgrade eligibility or ranking.

| Condition | Detected by | Effect on results | Tooltip | Contents tab | Characters or Status | Chat |
|---|---|---|---|---|---|---|
| Character not seen for `staleDays` (default 14) | `lastSeen` | Gear routed to it uses its last gear and level; wants unaffected | none | | Seen cell "16 d (old)"; Status roster line | One line at login, once per session, if `notify.staleSnapshot` is on: "LootLogic: Zugar (20 d) and Boneset (16 d) have not been seen for 14 days or more. Gear sent to them is judged on their old data." Lists only characters that can receive gear |
| Character with an assumed spec | loadouts | Ranked by the class's assumed spec | Gear reasons (Equip and a character's gear line) say "(assumed)" | | Checklist TIP | none after the first-login line |
| Bank never seen, or older than `staleDays` | `bank.updatedAt` | never seen: bank pieces missing from baselines; old: bank pieces as last seen | Shift only: "bank not seen" or "bank seen N d ago" | | Checklist info (never seen only) | none |
| Mail recorded, not collected after `staleDays` | `inbound[].sentAt` | Still counted as owned | | | Mail cell "3 (16 d)" | none |
| No price addon | provider detection | Every AH-able unwanted item is Vendor/AH | "LootLogic: Vendor/AH (no price addon)" | Notice | Prices row; checklist TIP | With the first-run line (2.1) |
| Provider found, nothing scanned | AHDB reports no scans; for Auctionator, no item classified this session has a price (its public API cannot tell an empty database from no match; a price over 21 d old counts as a price, so its item shows the old-price reason below, not this one) | Vendor/AH | "LootLogic: Vendor/AH (no AH price yet: scan)" | Notice | Prices row | none |
| Price older than `maxPriceAgeDays` | `ageDays` | Vendor/AH | "LootLogic: Vendor/AH (price 9 d old, max 7; was 1g 2s each (Auctionator))" | Icon hover with the old price | "newest price N d" | none |
| Not in the latest scan (`requireLastScan`) | AHDB `inLastScan` | Vendor/AH | "LootLogic: Vendor/AH (not in the last scan)" | Icon hover | | none |
| Provider error | `pcall` | That provider skipped, the other still used | | | Prices row; Errors | Once per session |
| Adapter failed | `pcall` | No sections or badges from it; the tooltip carries on | | Notice "BetterBags sections are off" | Bags row; checklist NEED | Once per session, at login |
| Bag addon with no adapter (Baganator) | detection | Tooltip line only | | Footer: "Your bags show tooltips only; this tab is the full list." | Bags row, info | none |
| Item data not loaded | item data not available | No result until it loads | none | "3 items still loading." | | none |
| Engine error on an item | `pcall` per item | A classification error gives no category; an error while adding detail keeps the classified category | Classification error: "LootLogic: error on an item, see /ll status." A detail error keeps the category line. | Count | Errors | Once per session |

**Chat lines** (each once per session unless stated; the scan summary comes after each scan and the mail-recorded line after each recorded mail; all start "LootLogic:"):
- Provider error: "<provider> failed (<error>); using <other provider>." or, with no other provider, "<provider> failed (<error>); no prices until it works."
- Adapter failed: "<adapter> sections are off (<error>); tooltips still work."
- Engine error: "error on an item, see /ll status."
- Saved data newer than this version (once, when the addon loads): "saved data is newer than this version and is left unchanged."
- Saved data that could not be upgraded (once, when the addon loads): "saved data could not be upgraded and is left unchanged."
- First run, no price addon: "no price addon found; tradable items nobody wants show as Vendor/AH."
- Last scan ignored (at login, M2): "'Only prices from the latest scan' is on, but Auctionator cannot tell which items were in the last scan, so it is ignored. Use AHDB for this."
- Scan summary: "prices updated: 9 items left Vendor/AH (6 AH, 3 Vendor)."
- Mail recorded (off by default): "mail to Boneset recorded (2 items)."
- Upgrades in mail (at login, once): "2 upgrades are waiting in your mail: [Chestguard] (Cat), [Ring] (Bear). Collect them at a mailbox."

**In M1** (no window, no bag adapter) LootLogic prints the added, first-run, no-price, provider error, engine error, newer-saved-data and could-not-upgrade lines. The last-scan line (with the `requireLastScan` toggle), stale, scan summary, mail-recorded and mail-upgrade lines arrive in M2 with their switches in the Settings tab (`notify.*`, 3.8), and the adapter-failed line arrives with the BetterBags adapter.

**Staleness.** A snapshot changes only when its character logs in, so an idle character's snapshot is correct however old it is, unless that character was played on another PC or with LootLogic off, which LootLogic cannot detect. Tooltips therefore carry no age warning, which would be noise for characters that are simply idle. The login line names characters not seen for `staleDays`, once per session, and leaves out characters that cannot receive gear (other faction or region, or Receives gear off). Every age is on the Characters tab and Status.

---

## 7. Accessibility and scale

**Colour is never the only cue.**
- Every category has a word (section name, tooltip line, Contents row) and a glyph.
- Checklist and Status use text tags ([done], [NEED], [TIP], [info]) as well as colour.
- Greyed roster rows give their reason in text.

**Badge, not border tint.** The item's border already shows quality: green is Uncommon, grey is Poor. A tint by category would clash with it: a green Equip border on a white item would read as Uncommon, and a grey Vendor border would hide a green item's quality. A corner badge carries the category and the border is left to quality. There is no border-tint option.

**Badge design (all untested at real sizes):**
- **Shape plus letter plus colour.** Categories get a square badge (E, A, V, ?). Characters get a round badge with their first letter in class colour. The shape separates "A = AH" from "A = Ajax", so an initial never collides with a category letter.
- **Same initial.** Characters whose display names start with the same letter get that letter plus the first letter that tells them apart from the others in that group, ignoring case and spaces. "Zugar o" and "Zugar u" (the display names of Zugar Sou and Zugar Sun) become "Zo" and "Zu"; "Bob" and "Brin" become "Bo" and "Br". With three, each takes the first letter that differs from all the others (Ann, Abe, Aby give "An", "Ae", "Ay"). A name that is the start of another ("Bo", "Bob") uses its first two letters ("Bo", "Bb"). This positional rule can give two characters the same badge letters. The badge reads the display name, so an override changes it, and the tooltip always carries the full name.
- About 12 UI units on a 37-unit button, font about 9 with outline. Below about 26 units the badge drops to a 3-unit coloured bar along the top edge, with the tooltip as the detail.
- **Position** is a setting, default top-right. The stack count sits bottom-right; Pawn's arrow and several addons' item-level text use the left corners.

**Palettes.** Default: Equip green, AH gold, Vendor grey, Vendor/AH orange, characters in class colour. A colour-blind palette (blue, yellow, grey, magenta) follows the client's colour-blind mode (`GetCVarBool("colorblindMode")`, from memory, untested on Forever) or is chosen in Settings. In both palettes, on the tooltip line, "stays" (category none) is in the tooltip's default text colour, the `nobody` line in that colour dimmed grey and the `error` line in red; the word "error" goes with the red, so colour is not the only cue.

**Scale.** The window's own scale (70% to 150%) sits on the client UI scale. Text uses client font objects. Lists scroll; display names are at most 14 characters, automatic or set by the player. A full "First Last" (up to 25 characters) is used only when one surname letter cannot tell characters with the same first name apart, or when the automatic name would equal another character's override; a number is added ("Foo Bar 2", up to 27) when the full name equals an override too (spec section 6). Where space is tight (buttons, badges) a long one is cut with an ellipsis and the full name shows on hover.

**Localisation.**
- The engine is English-client only (tooltip patterns, spec goal 3). The UI still uses one locale table from the start, so a translation is one added file.
- Type names come from the client, so the Wants tree is localised for free.
- Initials need a UTF-8-aware first-character read; Lua 5.1 `sub(1, 1)` splits a multi-byte letter. Whether Forever names allow accented letters is unknown (letters only per secondary sources).

---

## 8. Live tuning

### 8.1 Only tunable in the live client (after 2026-11-05)

1. Badge size, font, outline and position at BetterBags' and the default bags' icon sizes; overlap with stack counts, item-level text and Pawn's arrow; the small-icon fallback size.
2. Badge and palette colours against quality borders and BetterBags themes; the colour-blind palette and CVar.
3. Where LootLogic's sections land in BetterBags, and whether "Equip" or "Vendor/AH" clash with BetterBags or "Betterbags - Forever" categories (needing a prefix). Extends L17.
4. How quickly sections follow a sale or a mail (the 2 s reprocess debounce), and whether items changing section mid-trip need the hold setting.
5. Window size and default scale at common resolutions and UI scales; Escape to close.
6. Tooltip line length and wrapping beside Auctionator's and AHDB's lines; Shift detail length.
7. Vendor/AH volume in launch week, and whether the quality split should come forward.
8. Chat noise: the scan line, the mail-recorded line and the mail-upgrade line.
9. Mail attachment limit (`ATTACHMENTS_MAX_SEND`, L49). The recipient format is settled: "First Last" (L12).
10. Contents recompute cost with full bags and the bank open (L35).
11. Dropping items onto LootLogic frames; shift-clicking links into its edit boxes.
12. Keybindings (none bound by default), and whether the "add hovered item to wants" popup beats the window in practice.
