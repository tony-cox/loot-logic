# Commands in the current build

This guide describes the commands in the current development build. It is not the complete v1 command reference: later window and setup commands such as `/ll types`, `/ll contents` and `/ll wants` are not implemented yet. The planned v1 syntax is in [spec section 13](spec.md#13-in-game-ui). Update this guide as commands are added or changed.

Commands that act on the hovered item read what is under the mouse when you press Enter. If no item can be read, supply an item link or ID.

## Getting started

Enter commands in game chat. `/lootlogic` is an alias for `/ll`. Square brackets below mean optional; angle brackets mark values to replace. Command words, character names, loadout names, specs and types are case-insensitive.

Character names may contain spaces. LootLogic takes the longest matching roster name; quotes are also accepted, for example `"Boneset H"`. LootLogic's roster is local to each computer: log in on each character with LootLogic enabled on that computer before configuring it there.

The addon compartment entry (the minimap tray menu) does the same as bare `/ll` in this build: it prints the command list and then the checklist. At the first login on an account, a Welcome dialog offers [Show commands], which prints the same command list.

## Help and diagnostics

| Syntax | Action |
|---|---|
| `/ll help` | Print the current command list and the local-computer reminder. |
| `/ll` | Print the command list, then the setup checklist (the same lines as the first part of `/ll status`). |
| `/ll status` | Print the setup checklist, then the status block: the price providers, a `Tooltip: active` row, how long ago each character was last seen (newest first, `(old)` at `staleDays` days or more) and the session's error count with the last 5 errors, newest first. It changes nothing and also works in a read-only session. |
| `/ll why` | Explain the hovered item, if available. |
| `/ll why <item link>` | Explain the linked item. Shift-click an item into chat to insert a link. |
| `/ll why <item ID>` | Explain the first matching bag stack, or evaluate a link built from the ID if none is in the bags. |
| `/ll why <itemID:suffixID>` | Explain the first matching roll in the bags, or evaluate a link built from the key. Example: `/ll why 12345:-17`. |
| `/ll probe` | Run the automatic client checks and list the manual checks. Words after `probe` are ignored. |
| `/ll debug on` or `/ll debug off` | Enable or disable debug logging. |
| `/ll refresh` | Clear classification caches, start a bags pass and, when the bank is open, a bank pass; refresh an eligible shown tooltip. |
| `/ll perf` | Show the latest completed full classification's scope, item count and elapsed time, or say that none has completed. |

The checklist has seven lines, each tagged `[done]`, `[TIP]` or `[info]`: this character, the roster, specs, wants, prices, bags and the bank. A `[TIP]` on specs names the command that keeps the assumed spec. Wants are checked for characters this one can send to. There is no count and no "Setup complete" line in this build.

## Reading the tooltip

Hover a bag item and LootLogic adds one line to the game tooltip: its answer and the reason, for example `LootLogic: Vendor (AH gain below threshold; sells for 13c each)`. The answer is one of Equip, AH, Vendor, Vendor/AH, stays, or a character's name (mail it to them). `stays` means to keep the item; the reason explains why (a quest item, gear kept for another loadout, and so on). Hold Shift over the item to add the detail lines (who wants it, the gear comparison for each loadout, the price and the gain). `/ll why` prints the same detail in chat. There is no bag section or badge in this build: the tooltip line is the only display.

## Debug log and saved data

`/ll debug on` starts the debug log: each line reads `[hh:mm:ss] <area>: text` in the computer's local time, is echoed to chat with the prefix `LootLogic debug:` and is kept in the saved data. It keeps the newest 300 lines and drops older ones, so read it soon after the event you care about. The setting persists across reloads and logouts until `/ll debug off`. Game events that LootLogic watches (bank, mail, merchant, auction house, logout and so on) are logged with their arguments.

The saved data is the file `WTF/Account/<account>/SavedVariables/LootLogic.lua` (the global `LootLogicDB`). The client writes it on logout or `/reload`, not while playing, so reload before reading it. It holds `debug.log` (the debug lines) and `debug.probe` (one entry per `/ll probe` run, keyed by the run's time in epoch seconds as text, each with the `status` and `value` of every check). `/ll probe` runs the automatic client checks and prints each as a PASS, FAIL or SKIP line, then lists the checks that need doing by hand.

## Character order and gear

```text
/ll order
/ll order <name> [<name> ...]
/ll gear <name> on|off
```

`/ll order` shows the priority order. Given names, it puts those characters first in that order and leaves the others in their previous relative order. An unknown or ambiguous name leaves the order unchanged. The gear switch controls whether a character receives gear recommendations; it does not erase wants.

```text
/ll order Zugar "Boneset H"
/ll gear Zugar off
```

## Loadouts

```text
/ll loadout [<loadout> <spec> [worn]] [--character <name>|--all]
/ll loadout <loadout> remove [--character <name>]
/ll loadout <loadout> armor best|any|default [--character <name>]
```

With no positional arguments, list the current character's loadouts. For edits, supply a loadout name; quote it if needed. `worn` makes the loadout the worn one. Make another loadout worn before removing the worn one. `armor default` makes the loadout follow the global armour rule. To confirm an assumed spec, set the loadout to that same spec; the listing shows the command.

```text
/ll loadout Affliction Affliction worn --character Zugar
/ll loadout "Tank set" Bear worn --character Chamoomile
/ll loadout "Tank set" armor any --character Chamoomile
/ll loadout "Tank set" armor default --character Chamoomile
/ll loadout "Old set" remove --character Chamoomile
```

The current build has six spec weight tables: Druid **Bear** and **Restoration**, Shaman **Enhancement**, Paladin **Protection** and **Retribution**, and Warlock **Affliction**. Other classes can use wants and prices, but have no spec table in this build; their equippable gear stays with the `nospec` reason.

## Wants

```text
/ll want [<type or item> [on|off|clear]] [--character <name>|--all]
```

With no positional arguments, list the current character's wants. Both commands accept a final `--character <name>` to list or edit another known character; quote names with spaces. A final `--all` lists every character in priority order, including characters with no entries; it cannot be combined with edits or `--character`. Loadout listings include the spec, worn and assumed status, and armour rule. Wants listings include types, minimum qualities and item includes and excludes.

The default is `on`. A type can be a client class name, a full `Class: Subclass` name, a unique short subclass name, numeric `class:subclass`, or `class:*` for a whole class. An ambiguous short name lists its matches. A bare number is an item ID, not a class. An item can also be given as a link.

```text
/ll want Trade Goods: Cloth --character Zugar
/ll want 7:5 --character Zugar
/ll want Armor --character Zugar
/ll want 4:* --character Zugar
/ll want 2589 on --character Zugar
```

For a **type**, `off` and `clear` both remove the type want. For an **item**, `on` includes it even if its type is off, `off` excludes it even if its type is on, and `clear` removes the item-specific rule. Wants can be saved for a character that cannot receive from the current character; the reply explains the restriction. If the client type-name API is missing or fails, resolving a type reports that names are unavailable and changes nothing.

```text
/ll want 2589 off --character Zugar
/ll want 2589 clear --character Zugar
/ll want Trade Goods: Cloth clear --character Zugar
```

## Protection

```text
/ll protect [global] [<item link>|<item ID>|<itemID:suffixID>]
```

Without an item argument, LootLogic tries the hovered item. Without `global`, the current character's protect list is used. A plain item ID protects every roll; a link with a nonzero random suffix or an `itemID:suffixID` protects that roll. Repeating the same command removes the protection. If every roll is protected, toggling one roll leaves protection unchanged and gives the command to remove the every-roll entry.

```text
/ll protect
/ll protect 12345
/ll protect 12345:-17
/ll protect global 12345
```

## Reset

```text
/ll reset
/ll reset <character>
/ll reset all
/ll reset confirm
```

The first command previews the reset; `/ll reset confirm` applies that preview within 30 seconds. Exactly 30 seconds is valid. A new valid preview replaces the previous one; invalid commands leave it pending.

- `/ll reset` resets settings and window settings, preserving the first-run completion flag.
- `/ll reset <character>` clears that character's wants and protect list, resets gear receiving to its default, and replaces loadouts with one default worn loadout. It preserves the display name, imported-set membership, identity and snapshots.
- `/ll reset all` clears saved data, including the roster, while retaining the first-run completion flag. It registers the current character again and captures available live gear, proficiency and bags and imported sets before reclassification. It captures the bank only while open; inbox data is captured by the normal mail events.

Unquoted `all` and `confirm` are reserved. Quote a character with either name to select it.

## Basic workflows

**Set up a cloth recipient.** The first command changes priority, the second requests cloth, and the third excludes a specific item even if its type is wanted.

```text
/ll order Zugar Chamoomile
/ll want Trade Goods: Cloth on --character Zugar
/ll want 2589 off --character Zugar
```

**Choose a worn spec and enable gear receiving.**

```text
/ll loadout "Bear tank" Bear worn --character Chamoomile
/ll gear Chamoomile on
```

**Protect an item and inspect its explanation.** Repeat the protect command to remove the protection.

```text
/ll protect global 12345
/ll why 12345
```

**Reset one character's setup.** Read the preview before confirming.

```text
/ll reset Zugar
/ll reset confirm
```
