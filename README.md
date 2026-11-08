# LootLogic

## Description

A shared, standalone WoW: Forever addon for people who play alts. It sorts every bag item into a destination and fills those categories in the player's bag addon. Each bag item gets one answer. A bag addon shows it as a section; the tooltip line and `/ll why` give it with the reason. The answers are:

- sell to vendor
- list on the AH
- mail to a named character
- equip (an upgrade for the current character's worn loadout)
- vendor/AH (unwanted items where the choice of vendor or auction house is the player's call: no usable price)
- no category (everything else stays where it is, and the tooltip says why: quest items, set pieces, gear the character may wear later, and so on)

A character can have several loadouts (a name plus a spec, such as Bear and Cat for a druid). Gear kept as the best piece for a loadout that is not currently worn gets no category: it stays in the bags, and its tooltip says why, so it is never offered for sale. A better piece for a loadout that is not worn becomes a winner at the levels where it is best. The older piece stays while it wins at any level in the look-ahead window for any scored loadout; otherwise it is judged like any other item.

## High level scope

LootLogic is read-only: it never sells, mails, lists on the AH, deletes or moves items. Characters can mark specific items as wants: a want says that an item should go to that character. A character's wants are set by item class and subclass (for example all cloth), with per-item include and exclude. Gear ranking is built in and works per loadout. Sellable, tradable items nobody wants and the gear rules leave alone, with no usable price, always go to Vendor/AH (greys and bound items go to Vendor, or stay when they have no vendor value; any other item with no vendor value is still Vendor/AH), since the vendor-or-auction call is the player's. Price data comes from optional providers; bag integration starts with BetterBags, with tooltip and overlay fallbacks.

## Design

| File | What it holds |
|---|---|
| [`docs/COMMANDS.md`](docs/COMMANDS.md) | Commands and workflows implemented in the current development build |
| [`docs/spec.md`](docs/spec.md) | The full v1 specification: decisions, data model, classification algorithm, gear ranking and loadouts, price providers (Auctionator, AHDB), bag adapters (BetterBags first), UI, tests, live-client checks, build plan, risks |
| [`docs/ux.md`](docs/ux.md) | UX and workflow design: journey, first run, layouts, Wants editor, Contents tab, stale-data feedback, accessibility |
| [`docs/technical-findings.md`](docs/technical-findings.md) | What is known about the Forever client's APIs and other addons, the file layout, events, tests and the live-client checks (section numbers match the spec) |
| [`docs/sim-learnings.md`](docs/sim-learnings.md) | What the team has learned about how WoWSims Forever works and what moves its results |
| [`tools/statweights/`](tools/statweights/) | The Go program that computes stat weights with the sim (a development tool, not shipped with the addon) |
| [`docs/TESTING.md`](docs/TESTING.md) | In-game test checklists per milestone, each with the rule that says when the milestone passes |
| [`docs/style.md`](docs/style.md) | The Lua style guide and tooling for the addon code |
| [`docs/decisions.md`](docs/decisions.md) | The decision log: open and answered decisions, with dates |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Rules for writing docs and code comments, and for researching and using other addons' code |
| [`AGENTS.md`](AGENTS.md) | Working notes for coding agents (Claude Code and Codex): the workflow, the decisions rules and the build agents, which are defined in [`agents/`](agents/) |

## Licence

MIT, see [`LICENSE`](LICENSE). Third-party material and its licences: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Status

Implementation has started. The first version (v1) is fully scoped in the spec, version 1.1 is partly scoped, and a list of possible further additions follows it (spec sections 22 and 23). v1 is built in five milestones, M0 to M4 (spec section 19). M0, the offline engine (saved data, prices, roster, scoring and classification, built and tested with a stubbed client), is implemented, passes its offline checks and is merged. M1 (probe and tooltip) is under way: its first two stages, `/ll probe` and `/ll debug`, are built and merged. Live-client checks are under way on Forever build 1.60.1.70790; results are recorded in `docs/technical-findings.md` section 18. The addon code is in `LootLogic/` and its tests in `tests/`. The project is private until the addon is well tested.
