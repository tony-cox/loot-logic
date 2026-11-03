# Third-party notices

LootLogic is licensed under the MIT License (see `LICENSE`).

## Included material

| Material | Used for | Licence |
|---|---|---|
| WoWSims Forever (https://github.com/wowsims/forever) | Stat weights in `Data/WeightTables.lua` that the team computed by running the sim's stat weights engine, with the sim's stat names mapped to LootLogic's keys, on the sim's shipped builds and gear; the exceptions are the Druid Bear and Paladin Protection tables, whose builds the team assembled by hand and which combine the sim's threat and survival weights by a formula recorded in the file. The weights are per rating point (EP scale) and, apart from that combination, are used as the sim gives them. The sim commit and inputs of each table are recorded in the file. No sim code or preset file is shipped. The program that runs the sim, `tools/statweights/`, is the team's own code apart from one reproduced function, `individualSimRequest` (about 40 lines, from `cmd/wowsimcli/cmd/sim_request.go`, kept under the sim's MIT licence); it otherwise imports the sim's packages and calls their exported functions, and is a development tool, not part of the addon. | MIT, `LICENSES/WoWSims-MIT.txt` |

Item, spell and class IDs, the class training levels in `Data/`, and any weight table recorded as the team's own are the team's own work. No other third-party code or data is included.

## Interoperability

LootLogic calls the public APIs of other addons at run time, or reads their global tables, when the player has them installed. None of their code is shipped. The addons it works with are:

- Auctionator and AuctionDB (AHDB): prices
- BetterBags: bag sections
- BagBrother, Bagnon and Bagnonium (formerly Combuctor): bag rules
- ArkInventory: a rule function
- EllesmereUI Bags: item overlay
- Outfitter Forever: gear set membership

Baganator is not called; its tooltips show the LootLogic line through the game tooltip.

Licences of these addons, as checked on 2026-10-31: Auctionator, all rights reserved; AuctionDB, LGPLv3 (GPLv3 licence text); BetterBags, MIT; BagBrother, Bagnon and Bagnonium, all rights reserved; ArkInventory, no licence published; EllesmereUI, custom, all rights reserved; Outfitter Forever, MIT.

World of Warcraft is a trademark of Blizzard Entertainment, Inc. LootLogic is not affiliated with or endorsed by Blizzard Entertainment.
