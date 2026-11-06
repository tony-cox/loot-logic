# Commands in the current build

This guide describes the commands implemented through **M1 stage 5**, the current development build. It is not the complete v1 command reference: M1's `/ll status` and checklist, and later window and setup commands such as `/ll types`, `/ll contents` and `/ll wants`, are not implemented yet. The planned v1 syntax is in [spec section 13](spec.md#13-in-game-ui). Update this guide as commands are added or changed.

The commands below have offline test coverage. Live-client checks are still under way (see [technical findings section 18](technical-findings.md#18-live-client-checks-first-sessions-after-2026-11-05)); in particular, using a hovered item after typing is unverified (L46). If hover is unavailable, supply an item link or ID.

## Getting started

Enter commands in game chat. `/lootlogic` is an alias for `/ll`. Square brackets below mean optional; angle brackets mark values to replace. Command words, character names, loadout names, specs and types are case-insensitive.

Character names may contain spaces. LootLogic takes the longest matching roster name; quotes are also accepted, for example `"Boneset H"`. LootLogic's roster is local to each computer: log in on each character with LootLogic enabled on that computer before configuring it there.

## Help and diagnostics

| Syntax | Action |
|---|---|
| `/ll` or `/ll help` | Print the current command list and the local-computer reminder. |
| `/ll why` | Explain the hovered item, if available. |
| `/ll why <item link>` | Explain the linked item. Shift-click an item into chat to insert a link. |
| `/ll why <item ID>` | Explain the first matching bag stack, or evaluate a link built from the ID if none is in the bags. |
| `/ll why <itemID:suffixID>` | Explain the first matching roll in the bags, or evaluate a link built from the key. Example: `/ll why 12345:-17`. |
| `/ll probe` | Run the automatic client checks and list the manual checks. Words after `probe` are ignored. |
| `/ll debug on` or `/ll debug off` | Enable or disable debug logging. |
| `/ll refresh` | Clear classification caches, start a bags pass and, when the bank is open, a bank pass; refresh an eligible shown tooltip. |
| `/ll perf` | Show the latest completed full classification's scope, item count and elapsed time, or say that none has completed. |

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
/ll loadout <character> <loadout> <spec> [worn]
/ll loadout <character> <loadout> remove
/ll loadout <character> <loadout> armor best|any|default
```

The loadout name is required; quote it if needed. `worn` makes the loadout the worn one. Make another loadout worn before removing the worn one. `armor default` makes the loadout follow the global armour rule.

```text
/ll loadout Zugar Affliction Affliction worn
/ll loadout Chamoomile "Tank set" Bear worn
/ll loadout Chamoomile "Tank set" armor any
/ll loadout Chamoomile "Tank set" armor default
/ll loadout Chamoomile "Old set" remove
```

The current build has six spec weight tables: Druid **Bear** and **Restoration**, Shaman **Enhancement**, Paladin **Protection** and **Retribution**, and Warlock **Affliction**. Other classes can use wants and prices, but have no spec table in this build; their equippable gear stays with the `nospec` reason.

## Wants

```text
/ll want <character> <type or item> [on|off|clear]
```

The default is `on`. A type can be a client class name, a full `Class: Subclass` name, a unique short subclass name, numeric `class:subclass`, or `class:*` for a whole class. An ambiguous short name lists its matches. A bare number is an item ID, not a class. An item can also be given as a link.

```text
/ll want Zugar Trade Goods: Cloth
/ll want Zugar 7:5
/ll want Zugar Armor
/ll want Zugar 4:*
/ll want Zugar 2589 on
```

For a **type**, `off` and `clear` both remove the type want. For an **item**, `on` includes it even if its type is off, `off` excludes it even if its type is on, and `clear` removes the item-specific rule. Wants can be saved for a character that cannot receive from the current character; the reply explains the restriction. If the client type-name API is missing or fails, resolving a type reports that names are unavailable and changes nothing.

```text
/ll want Zugar 2589 off
/ll want Zugar 2589 clear
/ll want Zugar Trade Goods: Cloth clear
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
/ll want Zugar Trade Goods: Cloth on
/ll want Zugar 2589 off
```

**Choose a worn spec and enable gear receiving.**

```text
/ll loadout Chamoomile "Bear tank" Bear worn
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
