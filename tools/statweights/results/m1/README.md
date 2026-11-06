# M1 weight runs

The original runs behind the four M0 weight tables (Warlock Affliction, Shaman Enhancement, Druid Bear, Paladin Protection), made on 2026-11-02 with the program in the parent folder against WoWSims Forever commit `3e41c53f` (MIT, copyright (c) 2022 wowsims team). The current M1 tables and their sources are recorded in `../m1-refresh/`. The tables are unverified in game.

| File | What |
|---|---|
| `weights-m1-report.md` | The first report: inputs, raw weights and intervals for all four specs, and the choices the docs did not settle |
| `weights-m1-tanks-report.md` | The tank tables for Druid Bear and Paladin Protection after the Warrior Protection recipe (technical findings 14.1) |
| `tanks_combined.txt` | The combined tank weights, as the recipe gives them |
| `tables.txt`, `tank_tables.txt` | The DPS-only weights, and the threat and survival weights, as the program printed them |
| `warlock.json`, `shaman.json`, `bear.json`, `prot6000.json` | The program's raw output for each run |
| `bear.build.json`, `prot6000.build.json` | The two builds assembled by hand, because the sim ships no build file for Bear or Protection |
| `combine.py`, `ci.py`, `tables.py`, `mkbuilds.py` | The helper scripts that built the tables, intervals and builds from the raw output |

The Warlock build (`sm_ruin`) and the Shaman build (`testing`) are the sim's own, so no build file is kept for them. The reports record every input.
