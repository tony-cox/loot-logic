# M1 stat weights (WoWSims Forever sim)

## Common inputs

- Sim: wowsims/forever commit `3e41c53fafe13bbce337e2784061edf2c5a5b97f` (2026-11-01), checkout `D:\wowsims-forever`, clean apart from an untracked `cmd/wowsimcli/cmd/statweights_local.go` that the build does not use. Program: `tools/statweights` (committed `main.go`, unmodified), `go build -tags with_db`, Go 1.27.3.
- Method: `core.StatWeights` in target mode, `-epci 0.05 -maxmult 3000` (every EP to a 90% interval of 0.05, or the cap), seed 101 (program default), default fight (180 s, 5 s variation, one target) unless stated. The iteration count is ignored in target mode (1000-iteration probe, then top-ups); per-stat sample counts are in `tables.txt`.
- Intervals: 90% CI = 1.645 * stdev / sqrt(n), n from `sampleCounts` (`ci.py`, `tables.py`). Every EP interval is 0.05 or tighter in the tables below.
- EP = weight / reference weight. The engine reports EP as an absolute value (source-read, `statweight.go`), so the sign is lost there. The EPs below are signed (weight / reference weight).
- Files in this folder: `*.json` raw protojson results, `*.log`, `bear.build.json`, `prot.build.json`, `mkbuilds.py`, `ci.py`, `tables.py`, `tables.txt`, `tank_tables.txt`, `cap_*.json`.

## Warlock Affliction (`WARLOCK:affliction`)

- Inputs: build `ui/specs/warlock/dps/builds/sm_ruin.build.json` (talents `2550002013520105--0550205003`), gear `ui/specs/warlock/dps/gear_sets/preraid.gear.json`, target 0.05, reference StatSpellDamage, no bonus stats. Run time 8.4 s.
- Raw (DPS per point; signed EP vs spell damage; EP 90% CI):

| Stat | Weight | EP | CI |
|---|---|---|---|
| SpellDamage | 0.6467 | 1.0000 | 0.0033 |
| ShadowDamage | 0.5828 | 0.9012 | 0.0033 |
| FireDamage | 0.0639 | 0.0988 | 0.0003 |
| HitRating | 0.6151 | 0.9511 | 0.0491 |
| CritRating | 0.5164 | 0.7985 | 0.0493 |
| HasteRating | 0.3240 | 0.5009 | 0.0486 |
| SpellPiercing | 0.6199 | 0.9585 | 0.0211 |
| Intellect | 0.1796 | 0.2778 | 0.0483 |
| Spirit | 0.0745 | 0.1152 | 0.0494 |
| MP5 | 0.1438 | 0.2223 | 0.0500 |
| Stamina | 0 | 0 | 0 |

- Canonical (EP scale, spell damage = 1): `SP 1.0000` (SpellDamage 1.0 + HealingPower 0, not weighed), `SPDMG 1.0000`, `SP_SHADOW 0.9012`, `SP_FIRE 0.0988`, `HIT 0.9511`, `CRIT 0.7985`, `HASTE 0.5009`, `SPELLPIERCING 0.9585`, `INT 0.2778`, `SPI 0.1152`, `MP5 0.2223`, `STA 0`, `EXPERTISE 0` (not weighed). Matches the earlier trial in sim-learnings section 5.
- Hit cap check: with 40 hit rating removed, hit weight 0.6424 against 0.6151 (EP CI about 0.1): no cap effect visible.
- Open (already in sim-learnings): whether school weights are additional to spell damage is unverified.

## Shaman Enhancement (`SHAMAN:enhancement`)

- Inputs: build `ui/specs/shaman/enhancement/builds/testing.build.json` (carries its own gear; talents `053303102-053030031005102251-03`), bonus `StatHitRating=-40` (gear below the 8% cap), target 0.05, reference StatAttackPower, MH DPS weighed. Run time 103 s. This is the README example command.

| Stat | Weight | EP | CI |
|---|---|---|---|
| Strength | 0.2846 | 2.2000 | 0.0085 |
| Agility | 0.2110 | 1.6311 | 0.0491 |
| Intellect | 0.3216 | 2.4863 | 0.0500 |
| AttackPower | 0.1293 | 1.0000 | 0.0039 |
| HitRating | 1.0488 | 8.1082 | 0.0500 |
| CritRating | 0.4488 | 3.4698 | 0.0493 |
| HasteRating | 0.3727 | 2.8814 | 0.0500 |
| ExpertiseRating | 0.5311 | 4.1063 | 0.0500 |
| ArmorPenetration | 0.0401 | 0.3097 | 0.0013 |
| SpellDamage | 0.3131 | 2.4209 | 0.0069 |
| NatureDamage | 0.1093 | 0.8447 | 0.0044 |
| SpellPiercing | 0.7683 | 5.9399 | 0.0499 |
| MH DPS | 1.8099 | 13.9924 | 0.0499 |

- Canonical: `STR 2.2000, AGI 1.6311, INT 2.4863, AP 1.0000, HIT 8.1082, CRIT 3.4698, HASTE 2.8814, EXPERTISE 4.1063, SPDMG 2.4209, SP 2.4209 (+ HealingPower 0), SP_NATURE 0.8447, SPELLPIERCING 5.9399, DPS_MH 13.9924`. Dropped: ArmorPenetration. Not weighed, so absent: STA, SPI, MP5, DEF.
- Reproduces the sim-learnings section 4 run. The hit weight is the below-the-cap value (about 8); at the cap it drops (sim-learnings section 3), so the table must say it assumes gear below the cap.

## Druid Bear (`DRUID:bear`)

- Inputs: build hand-assembled (`bear.build.json`) from `ui/specs/druid/feralbear/spec.ts` and `presets.ts` defaults: Bear talents `050022-2322030212310212501-055`, adaptive APL, `Level60Gear` (`gear_sets/default.gear.json`, a dev-only placeholder), preset consumables, buffs, debuffs and party buffs, Tauren, boss `minBaseDamage` 6000 (the Mount Hyjal preset) with armor 3731, `tanks = [Player 0]`, reaction 250 ms, distance 25, preset healing model. No bonus stats. Target 0.05, reference StatAgility (the spec's `epReferenceStat`), the 16 `epStats` plus MH DPS. Run time 25 s.

| Stat | Weight | EP | CI |
|---|---|---|---|
| Strength | 0.5756 | 1.9665 | 0.0046 |
| Agility | 0.2927 | 1.0000 | 0.0498 |
| Stamina | -0.0025 | -0.0085 | 0.0476 |
| AttackPower | 0.2616 | 0.8939 | 0.0021 |
| FeralAttackPower | 0.2616 | 0.8939 | 0.0021 |
| HitRating | 0.8061 | 2.7542 | 0.0472 |
| CritRating | 0.4279 | 1.4619 | 0.0500 |
| HasteRating | 0.2778 | 0.9493 | 0.0495 |
| ExpertiseRating | 0.7646 | 2.6123 | 0.0477 |
| ArmorPenetration | 0.1013 | 0.3462 | 0.0009 |
| DefenseRating | -0.0486 | -0.1661 | 0.0498 |
| DodgeRating | -0.0625 | -0.2134 | 0.0496 |
| Armor | 0.0016 | 0.0055 | 0.0087 |
| BonusArmor | 0.0016 | 0.0055 | 0.0087 |
| ArmorNoMods | -0.0006 | -0.0020 | 0.0043 |
| PhysicalDamage | 1.6990 | 5.8048 | 0.0491 |
| MH DPS | 3.6628 | 12.5142 | 0.0291 |

- Canonical (DPS metric only): `STR 1.9665, AGI 1.0000, STA -0.0085 (noise), AP 0.8939, HIT 2.7542, CRIT 1.4619, HASTE 0.9493, EXPERTISE 2.6123, DEF -0.1661, DODGE -0.2134, ARMOR 0.0055, BONUSARMOR 0.0055, DPS_MH 12.5142`; `SPELLPIERCING 0`. Dropped: ArmorPenetration, PhysicalDamage. StatArmor and StatArmorNoMods both map to ARMOR (0.0055 vs -0.0020); StatArmor was used.
- Tank metrics (`bear.json`, `tank_tables.txt`), EP vs Armor, DTPS: Defense 7.70, Dodge 4.12, Agility 3.14, Stamina 0.31. TMI: Stamina 5.61, Defense 5.26, Agility 0.84, Dodge 0.65. TPS EP vs Agility follows DPS (Strength 1.92, hit 2.76, expertise 2.62).
- Hit and expertise offset check (-40 hit, -20 expertise): hit 0.798 and 0.810, expertise 0.766 and 0.776, against 0.806 and 0.765 baseline: flat.
- The sim's `BearEp` preset adds calibrated DTPS and TMI value (stamina 0.97, defense 0.95, hit 0.77 on its own scale), so it is not comparable to these DPS-only numbers.

## Paladin Protection (`PALADIN:protection`)

- Inputs: build hand-assembled (`prot.build.json`) from `ui/specs/paladin/protection/presets.ts`: talents `050050002-05302102213301531-502`, `default.apl.json`, `default.gear.json` (dev-only placeholder), preset consumables, buffs and debuffs, Human, `tanks = [Player 0]`, preset healing model, no encounter (program default one-target fight, boss damage 2601, armor 3731). No bonus stats. Target 0.05, reference StatStrength (the spec's `epReferenceStat`), the 18 `epStats` plus MH DPS. Run time 41 s.

| Stat | Weight | EP | CI |
|---|---|---|---|
| Strength | 0.2532 | 1.0000 | 0.0033 |
| SpellDamage | 0.2980 | 1.1769 | 0.0021 |
| Agility | 0.1535 | 0.6061 | 0.0485 |
| Stamina | 0.0008 | 0.0032 | 0.0137 |
| AttackPower | 0.1055 | 0.4167 | 0.0014 |
| HitRating | 0.6819 | 2.6934 | 0.0499 |
| CritRating | 0.2906 | 1.1476 | 0.0469 |
| HasteRating | 0.2133 | 0.8426 | 0.0500 |
| ExpertiseRating | 0.4059 | 1.6033 | 0.0489 |
| ArmorPenetration | 0.0242 | 0.0954 | 0.0004 |
| DefenseRating | -0.0988 | -0.3903 | 0.0500 |
| BlockRating | 0.2529 | 0.9990 | 0.0499 |
| BlockValue | 0 | 0 | 0 |
| DodgeRating | -0.0786 | -0.3103 | 0.0489 |
| ParryRating | -0.0312 | -0.1231 | 0.0495 |
| Armor, BonusArmor, ArmorNoMods | 0 | 0 | 0 |
| MH DPS | 1.4769 | 5.8333 | 0.0190 |

- Canonical (DPS metric only): `STR 1.0000, SPDMG 1.1769, SP 1.1769 (+ HealingPower 0), AGI 0.6061, STA 0.0032, AP 0.4167, HIT 2.6934, CRIT 1.1476, HASTE 0.8426, EXPERTISE 1.6033, DEF -0.3903, BLOCK 0.9990, BLOCKVALUE 0, DODGE -0.3103, PARRY -0.1231, ARMOR 0, BONUSARMOR 0, DPS_MH 5.8333`; `SPELLPIERCING 0`. Dropped: ArmorPenetration.
- Tank metrics (`prot.json`, `tank_tables.txt`), EP vs Armor, DTPS: Defense 28.6, Dodge 15.2, Agility 12.5, Parry 12.2, Block value 11.7, Block rating 3.7. TMI: Stamina 27.6, Defense 18.4, Block value 6.5, Dodge 5.2. TPS EP vs Strength: SpellDamage 1.96, hit 3.83, expertise 2.09, block rating 1.43.
- Hit and expertise offset check: hit 0.693 and expertise 0.409 (offsets) against 0.682 and 0.406: flat.

## Percent-based keys

None for any of the four. The sim's rating weights are per rating point, so `percent = {}` in every table (technical findings 14.1).

## Anomalies and choices the docs did not settle

1. **Tank specs (Bear, Protection): the DPS table puts no value on survival.** Stamina, armor and block value are about 0, and defense, dodge and parry are significantly negative (Bear defense -0.049 +-0.015, dodge -0.063 +-0.015; Protection defense -0.099 +-0.013, dodge -0.079 +-0.012, parry -0.031 +-0.013 DPS per point). Unverified hypothesis: fewer hits taken means less rage or fewer proc triggers. Used alone, these tables would rank defensive gear as worthless or harmful. The engine also returns TPS, DTPS, TMI and death probability weights; the docs do not say how to combine them (sim-learnings section 8 leaves it open). They were not combined. The tables above are the DPS metric, the others are in the JSON. Death probability weights were not examined, and the program prints only DPS.
2. **Bear and Protection builds are hand-assembled** (no shipped build file) from each spec's defaults and presets, on the sim's dev-only Level 60 placeholder gear. Bear uses the preset's Hyjal boss damage (6000), Protection the default fight (2601), so tank numbers are not comparable between the two. `tanks` was added so DTPS and TMI are non-zero. Reference stats are each spec's own `epReferenceStat`; raw weights do not depend on the reference, only the EP scale does. DiscardUnknown is on in the program, so build keys were checked by hand against the protos.
3. **Engine EP is an absolute value**: negative weights print as positive EPs. Use the signed values here; do not copy EpValues from the JSON for those keys.
4. **Intervals:** target mode covers DPS only. TPS, DTPS and TMI come from the same runs and have looser intervals (DTPS and TMI EP CIs of 0.1 to 1.5 for defence-type stats). The `+-` printed by the program is a per-iteration stdev, not the CI.
5. **Bear AP:** StatAttackPower and StatFeralAttackPower have identical weights (0.2616); the single `AP` key takes that value.
6. **One seed (101) per spec**; not repeated with a second seed.
7. **Cap position:** hit and expertise offset checks for Bear, Protection and Warlock were flat within noise; the Shaman run uses the documented -40 hit offset. Expertise cap (6.5%) for Shaman was not checked.
8. Nothing in the repo was edited; the program was built unmodified into this folder.
