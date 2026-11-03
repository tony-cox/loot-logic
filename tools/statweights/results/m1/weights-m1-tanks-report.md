# M1 tank tables: Warrior Protection recipe applied to Druid Bear and Paladin Protection

Warlock Affliction and Shaman Enhancement are unchanged (see `weights-m1-report.md`).

## Recipe and how it was applied

- Source: `ui/specs/warrior/protection/presets.ts` lines 34 to 36: "0.6 x the threat weights (Strength = 1) plus 1.15 x the TMI weights (Stamina = 1) ... ArmorNoMods weighs as Armor, since nothing in the build scales armor."
- Check against the shipped numbers: Stamina 1.15 and Strength 0.62 are exactly what the recipe gives (the other metric contributes about 0.02 to each), so TPS is normalised to Strength and TMI to Stamina.
- Applied exactly: for each stat, `combined = 0.6 * (TPS weight / TPS weight of Strength) + 1.15 * (TMI weight / TMI weight of Stamina)`, computed from the raw saved weights (`combine.py`, output `tanks_combined.txt`). The normalisation is signed: the engine's own EP column takes absolute values and, for TMI, uses Armor as its reference, so it was not used. TMI weights are negative when a stat helps (lower TMI is better), and dividing by the negative Stamina weight makes helpful stats positive.
- Sim, program, seed 101, target 0.05, stat lists and gear: as in `weights-m1-report.md`. Bear is the existing run (`bear.json`, boss damage 6000, Agility reference). Protection was rerun with the Bear encounter (boss damage 6000, armor 3731, same 180 s fight) in `prot6000.build.json`, result `prot6000.json` (reference Strength, 38 s). Everything else in the Protection build is unchanged.
- ArmorNoMods: per the recipe it takes the Armor value (both map to ARMOR; the table uses one number). Measured ArmorNoMods differs for Bear (0.0422 against Armor 0.2031) because Bear scales armor in the build, so the recipe's reason does not strictly hold for Bear; the Armor value is used, as the recipe says. For Protection they agree (0.0355 against 0.0380).

## Intervals

- 90% CI on each ratio from the saved stdevs and sample counts (1.645 * stdev / sqrt(n), including the reference stat's own uncertainty, treating the stat and its reference as independent, which is a conservative simplification). Combined CI = sqrt((0.6 * TPS CI)^2 + (1.15 * TMI CI)^2).
- The program can only drive its iteration targets from DPS (or HPS), not TPS or TMI. The TPS and TMI intervals are therefore whatever the DPS-targeted run gave. They were not tightened. The widest combined intervals: Protection block rating +-0.093, defense +-0.083, parry +-0.077, dodge +-0.075, agility +-0.072; Bear defense +-0.064, dodge +-0.064, agility +-0.053. All other keys are +-0.05 or tighter. If the dodge, parry and defense values matter at that precision, a longer run is needed and the program would have to be extended to target TPS and TMI (not done: the program is committed).
- Death probability was not used.

## Druid Bear (`DRUID:bear`)

TPS EP is against Strength, TMI EP against Stamina. TPS weight of Strength 0.8634, TMI weight of Stamina -0.1622.

| Canonical key | TPS EP | TMI EP | Combined | 90% CI | DPS-only (EP vs Strength) |
|---|---|---|---|---|---|
| STR | 1.0000 | 0 | 0.6000 | 0.0020 | 1.0000 |
| AGI | 0.5209 | 0.1503 | 0.4854 | 0.0530 | 0.5086 |
| STA | -0.0124 | 1.0000 | 1.1426 | 0.0348 | -0.0043 |
| AP (also FeralAP) | 0.4545 | 0 | 0.2727 | 0.0009 | 0.4545 |
| HIT | 1.4376 | -0.0052 | 0.8566 | 0.0180 | 1.4003 |
| CRIT | 0.7763 | 0.0013 | 0.4673 | 0.0200 | 0.7434 |
| HASTE | 0.4976 | 0.0006 | 0.2993 | 0.0260 | 0.4826 |
| EXPERTISE | 1.3644 | -0.0034 | 0.8147 | 0.0181 | 1.3283 |
| DEF | -0.1235 | 0.9370 | 1.0035 | 0.0639 | -0.0844 |
| DODGE | -0.1256 | 0.1165 | 0.0586 | 0.0637 | -0.1086 |
| ARMOR | -0.0028 | 0.1781 | 0.2031 | 0.0074 | 0.0028 |
| BONUSARMOR | -0.0029 | 0.1796 | 0.2048 | 0.0074 | 0.0028 |
| DPS_MH | 6.3636 | 0 | 3.8182 | n/a | 6.3636 |

- Dropped as the sim's stats Forever items do not carry or key: ArmorPenetration (combined 0.1056), PhysicalDamage (1.7882), ArmorNoMods (0.0422, see above). SPELLPIERCING, EXPERTISE handled: EXPERTISE is weighed (0.8147); SPELLPIERCING 0 (not weighed). Percent-based keys: none.
- (The DPS-only column here is the first-run DPS weight divided by the Strength DPS weight (0.5756), for comparison; the first report used Agility as reference.)

## Paladin Protection (`PALADIN:protection`, boss damage 6000)

TPS weight of Strength 0.4055, TMI weight of Stamina -0.3608 (with boss damage 2601 it was -0.1254, so the survival metric scales with boss damage).

| Canonical key | TPS EP | TMI EP | Combined | 90% CI | DPS-only (EP vs Strength, 6000 run) |
|---|---|---|---|---|---|
| STR | 1.0000 | 0.0032 | 0.6037 | 0.0025 | 1.0000 |
| SPDMG (SP = same, HEAL 0) | 1.9596 | 0.0090 | 1.1860 | 0.0041 | 1.1772 |
| AGI | 0.7344 | 0.1342 | 0.5949 | 0.0724 | 0.6164 |
| STA | -0.0090 | 1.0000 | 1.1446 | 0.0222 | -0.0016 |
| AP | 0.4168 | 0 | 0.2501 | 0.0011 | 0.4167 |
| HIT | 3.8356 | 0.0048 | 2.3069 | 0.0477 | 2.6869 |
| CRIT | 1.5022 | 0.0046 | 0.9066 | 0.0423 | 1.1596 |
| HASTE | 0.7980 | -0.0398 | 0.4331 | 0.0554 | 0.8313 |
| EXPERTISE | 2.1087 | 0.0034 | 1.2691 | 0.0471 | 1.6082 |
| DEF | -0.6017 | 0.5741 | 0.2992 | 0.0829 | -0.3910 |
| BLOCK | 1.4588 | 0.0749 | 0.9614 | 0.0927 | 1.0056 |
| BLOCKVALUE | -0.0026 | 0.0694 | 0.0782 | 0.0081 | 0.0043 |
| DODGE | -0.4566 | 0.1030 | -0.1555 | 0.0753 | -0.2964 |
| PARRY | -0.2166 | 0.0766 | -0.0419 | 0.0766 | -0.1056 |
| ARMOR | -0.0014 | 0.0338 | 0.0380 | 0.0010 | 0.0003 |
| BONUSARMOR | -0.0014 | 0.0338 | 0.0380 | 0.0010 | 0.0003 |
| DPS_MH | 5.8357 | 0 | 3.5014 | n/a | 5.8333 |

- Dropped: ArmorPenetration (combined 0.0476), ArmorNoMods (0.0355, folded into ARMOR per the recipe). SPELLPIERCING 0. Percent-based keys: none.
- DPS-only column for Protection has the sign kept from the raw weights (the first report's EPs for defense, dodge, parry were signed the same way).

## Do the tank stats now come out sensibly?

- Stamina: yes. 1.14 on both (the 1.15 TMI term by construction), against about 0 in the DPS-only tables. Strength 0.60 on both.
- Defense: yes. Positive on both (Bear 1.00, Protection 0.30), against negative before. The Protection value is low next to Stamina, and the Warrior preset's 0.22 is the same order of magnitude.
- Armor: yes, small and positive (Bear 0.20, Protection 0.038), against about 0. The Armor weight is per armor point, so it is small by nature.
- Block value: Protection 0.078 (+-0.008), positive and small, against 0 before. Bear has no block.
- Dodge: not cleanly. Bear 0.059 +-0.064 (indistinguishable from 0). Protection -0.156 +-0.075 (negative, about 2 sigma): the threat term is negative (-0.46) and outweighs the TMI term (+0.10).
- Parry: Protection -0.042 +-0.077, indistinguishable from 0, but not positive as a tank would expect. TMI gives +0.077 per point against Stamina, offset by negative threat.
- So dodge and parry are the odd ones, and only on Protection. The pattern is the same as the DPS-only run (dodge, parry and defense lower DPS and threat), and the recipe's 0.6 weight on threat is large enough to cancel the small TMI benefit of dodge and parry. Unverified cause: fewer hits taken means fewer procs or less resource gain, which is also how Holy Shield and similar effects would behave. Hit and expertise (about 0.86 and 0.81 for Bear; 2.31 and 1.27 for Protection) are mostly threat-driven.
- Block rating on Protection is high (0.96): it increases threat in the sim (Holy Shield / block-based procs, unverified), not just survival (TMI EP only 0.075).
- Gear is the dev-only Level 60 placeholder and has not been checked against the defense cap (crit immunity 5.6%, defense floor) the Warrior preset discusses; defense could be worth less once past a cap.
- Hit and expertise cap position was not re-checked beyond the first report's offsets (flat on the DPS metric); on TPS the same gear was used.

## Compared with the DPS-only tables

- The DPS-only tables put no value on Stamina, defense, armor and block value and had negative defense, dodge and parry. The combined tables value Stamina and defense, give armor and block value small positive weights, and keep the offensive stats close to their DPS-only ratios (Bear within about 3 to 15% on hit, crit, haste, expertise; Protection hit 2.31 against 2.69, expertise 1.27 against 1.61).
- Boss damage 6000 versus 2601 on Protection: DPS and TPS weights are nearly identical (DPS EP hit 2.69 against 2.69, stamina TMI weight -0.361 against -0.125). The boss damage matters for the TMI term only.

## Files

`prot6000.build.json`, `prot6000.json`, `prot6000.log`, `combine.py`, `tanks_combined.txt` (full tables including raw TPS and TMI weights and sample counts), plus the earlier files.
