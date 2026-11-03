# WoWSims Forever: what the team has learned about the sim

A running record of how the sim works and what moves its results, for anyone producing or reading LootLogic weights. It is general knowledge about the sim, not a record of the weights themselves (those go in `Data/WeightTables.lua` with their inputs, technical findings 14.1). Add to it as trials teach something.

Confidence labels: **observed** (run by the team), **source-read** (read in the sim code), **third-party** (reported by the sim's own community, not checked), **unverified**.

Sim: WoWSims Forever, commit `3e41c53f` (2026-11-01), built locally. Findings from 2026-11-02.

## 1. Running the sim headless

- **Observed:** `wowsimcli` has no stat-weights command. The engine is `core.StatWeights` (`sim/core/statweight.go`). The recipe that works end to end: load a spec's build file into the sim's `IndividualSimSettings`, turn it into a sim request the way `wowsimcli` does for a normal run, copy the player, buffs, debuffs and encounter into a `StatWeightsRequest`, list the stats to weigh and the reference stat, optionally set the target (section 2), and call `core.StatWeights`. The sim ships no ready-made command for this, so we wrote a short Go program, kept in this repo as `tools/statweights/` (see its README). It builds against a sim checkout and has been checked to give byte-identical results to the first, in-checkout version.
- **Source-read:** a spec's build file (`ui/specs/<class>/<spec>/builds/*.build.json`) holds talents, rotation, consumables and buffs. Some specs' builds also hold gear (Shaman Enhancement does), others keep gear in a separate `gear_sets/*.gear.json` (Warlock does). A build with no encounter is simmed against the CLI's default fight: 180 s, 5 s variation, one target.
- **Observed:** a run takes seconds to a couple of minutes. Warlock Affliction at a 0.05 target took 8 s. Shaman Enhancement with 12 stats and a 0.05 target took 80 to 110 s.
- **Observed:** results repeat exactly for the same seed. Iteration `i` runs at seed `RandomSeed + i`, so a longer run extends a shorter one (source-read). Different seeds differ within the stated interval.

## 2. How the stat weights engine works

- **Source-read:** a baseline run plus, for each weighed stat, a run with the stat raised (and, for most, lowered). Runs are paired iteration by iteration, which cancels most of the fight's randomness.
- **Source-read:** each weight is DPS per stat point. The engine also returns the same weights for HPS, threat per second (TPS), damage taken per second (DTPS), TMI and death probability (section 8 has a tank run, section 9 the tank tables). EP is a weight divided by the reference stat's weight, so the reference stat is always 1. DPS specs use spell power or attack power as the reference; Hunters need ranged attack power (section 8). Ratings come out per rating point; only percentage pseudo-stats are rescaled.
- **Observed:** the `+-` printed beside each weight is the per-iteration standard deviation, not the confidence interval. The 90% interval is `1.645 * stdev / sqrt(n)`, where `n` is the stat's paired sample count (`sampleCounts` in the output).
- **Source-read, observed:** target mode (`StatWeightsTarget`) runs a 1000-iteration probe, then up to three top-up passes that add iterations per stat until its EP interval reaches the target or the cap (`MaxIterationMultiplier` times the probe). The request's own iteration count is ignored in target mode.
- **Observed:** stats need very different sample counts. In the Enhancement run at a 0.05 target, Strength, spell damage and armor penetration needed 1000 samples, spell piercing 2172, intellect 11022, agility 63734, crit 85728, haste 244460, expertise 253858 and hit 300007. Hit, haste and expertise are the expensive ones. A fixed iteration count for all stats wastes time on cheap stats and under-samples these.
- **Observed:** a plain 5000-iteration run (no target) leaves hit, haste, expertise and intellect with intervals of one EP point or more, which is too loose to use. Use target mode.

## 3. What moves the result

- **Level is fixed.** **Source-read:** `CharacterLevel = 60` is a constant in `sim/core/constants.go`. The sim cannot run another level without a code change. Level bands, if ever wanted, cannot come from this sim as it stands.
- **Hit and the cap.** **Observed:** gear that is at or over the hit cap makes hit look cheap. Shaman Enhancement on its Testing gear (8.2% hit, cap 8%): hit EP 4.29 as shipped, 8.11 with 40 hit rating removed, 7.76 with 80 removed. Below the cap the value is flat (about 8); at the cap it drops. The other eleven stats moved by under 0.1 EP across the three runs (agility 1.58 to 1.68, spell damage 2.37 to 2.46). Weights for hit must say where the gear sits relative to the cap.
- **Talents and gear.** **Third-party (sim Discord, 2026-11-02):** presets are reasonable, but weights depend on the other gear equipped and, above all, on talents. Examples given: intellect is worth little for a Retribution Paladin before the "cotl" talent (as written in the reply, not expanded) and similarly for Enhancement; percentage-based stats (crit, agility) are worth less than flat ones (Strength, spell power) early on, because a percentage of a small number is small. This matches how the engine works but the team has not yet tested it by varying the talent string or gear.
- **Fight.** **Source-read:** duration, variation, target count and the rotation all feed the result. A 180 s single-target fight is the default. **Unverified:** how much the weights move with fight length or target count has not been tested.
- **Consumables, buffs, debuffs** come from the build file. Weights change with them. Record the build when recording weights.

## 4. Preset weights against our own run (Shaman Enhancement)

Preset: `PreBiSEpWeights` in `ui/specs/shaman/enhancement/presets.ts`, stated to be measured on the Testing gear with the Standard talents over three minutes, hit measured with 40 rating removed. Our run: the same build, same hit offset, target mode at 0.05. **Observed.**

| Stat | Preset EP | Computed EP | Note |
|---|---|---|---|
| Strength | 2.2 | 2.20 | match |
| Main hand DPS | 14.18 | 13.99 | match |
| Haste rating | 2.81 | 2.88 | match |
| Armor penetration | 0.37 | 0.31 | close |
| Nature damage | 0.72 | 0.84 | close |
| Expertise rating | 3.5 | 4.11 | 17% higher |
| Agility | 1.32 | 1.63 | 24% higher |
| Intellect | 1.99 | 2.49 | 25% higher |
| Crit rating | 2.42 | 3.47 | 43% higher |
| Hit rating | 5.2 | 8.11 | 56% higher |
| Spell damage | 1.27 | 2.42 | 1.9 times |
| Spell piercing | 2.52 | 5.94 | 2.4 times |

- The match on Strength and main hand DPS means the pipeline, build and gear agree with whatever produced the preset.
- The hit offset does not explain the gaps: the other stats barely move with it (section 3).
- **Observed: the preset reproduces at the commit that wrote it.** The preset's weights were last written in `07fec950bb` (2026-10-17, "Measure Elemental and Enhancement EP weights on the Testing gear"). Running the same method on that commit (Testing build, 40 hit rating removed, target 0.05) gives: Strength 2.20, MH DPS 14.23, hit 5.23, crit 2.43, spell damage 1.27, spell piercing 2.53, intellect 1.95, agility 1.30, expertise 3.51, armor penetration 0.37, nature damage 0.71, haste 2.96. Every value is within about 0.05 of the preset except haste (2.96 against 2.81). So the presets are honest sim output, and the method here matches the one that made them.
- So the gaps in the table above come from changes to the sim or its data between 2026-10-17 and 2026-11-01, not from a method difference. The sim is updated often from the official source and database, so the latest build is taken as the most correct and the cause of each change is not chased. **Lesson:** a preset is a snapshot of the sim at its commit, and it goes stale as the sim and its data change, even when the method is sound.
- Talents: the build's talent string is `053303102-053030031005102251-03` today; whether it was the same on 2026-10-17 has not been checked.

## 5. Warlock Affliction (first computed table)

Build `sm_ruin`, gear set `preraid`, target 0.05, reference spell power. **Observed**, intervals not yet computed.

Spell power 1.00, shadow damage 0.90, fire damage 0.10, hit 0.95, crit 0.80, haste 0.50, spell piercing 0.96, intellect 0.28, spirit 0.12, MP5 0.22, stamina 0.

The sim reports spell damage and each school's damage as separate stats. Whether a school's weight is additional to spell damage (as the SP mapping in technical findings 14.1 assumes) is **unverified** here.

## 6. Healers (Priest Holy and Discipline trial)

**Observed, 2026-11-02, sim `3e41c53f`.** A trial of the healer route, not a table.

- **There is no shipped healer rotation or build.** The Priest healer folder holds only a `preraid` gear set and presets; the sim's own test calls the spec "a gear planner, it has no healing rotation". The heal spells (Greater Heal, Flash Heal, Renew, Prayer of Healing, Prayer of Mending, Holy Nova, Power Word: Shield, Penance) are registered, so a rotation can be written by us, but the shipped materials give none.
- **The engine works for healing.** With a hand-written one-line rotation (Greater Heal rank 5 on cooldown), the Holy and Discipline talent strings, the healer gear set and a 180 s fight, the stat weights run with the HPS metric and the healing power reference. A run takes about a second, repeats across seeds (Holy intellect EP 5.07 and 5.06) and reaches a tight interval.
- **The numbers depend on the rotation we write.** Spamming Greater Heal runs out of mana, so mana stats dominate: intellect, spirit and MP5 come out at about 4 to 7 times healing power (Holy: intellect 5.07, spirit 4.58, crit 1.07, haste 0.16, MP5 6.60; Discipline: intellect 4.03, spirit 3.77, crit 0.99, haste 0.26, MP5 6.35). The sim's hand-set Holy preset has intellect 0.35, spirit 0.3, crit 0.3, haste 0.5, MP5 0.6. The two are not comparable, because the trial rotation is a placeholder.
- **Unknowns for a real healer table:** how much to heal and whom (the player heals itself; no incoming damage was modelled, so how overhealing counts in HPS is unverified), the spell mix (single target, raid, with or without Renew, Prayer of Mending, Penance), and the fight's length and mana pressure. Healer weights are mostly these choices, which is the "play style" dependence the research flagged.
- **So a computed healer table needs a rotation the team writes and defends**, so the Priest healer tables are written by hand until the sim ships a healer rotation (spec 8.2).

## 7. Practical notes

- **Observed:** a past commit of the sim builds in a git worktree (`git worktree add <dir> <commit>`), then `protoc` for the generated files and `go build`. Older commits may lack helpers that the stat weights program calls, so it can need a small adaptation there. The worktree leaves the main checkout untouched.
- Build: the sim is Go. `go build -tags with_db` builds with its item and spell database; the protobuf Go files are generated with `protoc` first and are not in the sim's git, so the program needs a checkout, not a module download. No `make` is needed. Setup and a sample command: `tools/statweights/README.md`.
- Inputs the stat weights program needs: the build file, an optional gear set that replaces the build's gear, the stats to weigh, the reference stat, bonus stats (used for the hit offset in section 3), the pseudo stats to weigh (main hand DPS for Enhancement), a fixed seed and the target interval.
- Generated sim data is not committed. Keep results next to the inputs (build, gear, offsets, seed, target) when recording a table.
- Open: whether weights move with talents the way the community describes.

## 8. Alpha specs: smoke test (Hunter, Paladin Protection)

**Observed, 2026-11-02, sim `3e41c53f`.** Both run to completion with the stat weights program, so neither is blocked. The numbers below are a check that they run, not tables (loose intervals, short runs).

- **Hunter** (BM, MM, SV builds). The builds are `.siml` files, not JSON; the sim's `siml parse -json <file>` prints the settings as the JSON the program reads. The EP reference has to be ranged attack power: with attack power as the reference every EP came out 0, because the Hunter's damage does not respond to plain attack power (Strength and attack power also weigh 0). Rough EP against ranged attack power: agility 2.5 to 2.8, intellect 2.5 to 2.9, crit 1.8 to 3.0, haste 1.5 to 1.8, armor penetration 0.15 to 0.17. Hit is 3.6 for BM, 2.1 for MM and 0 for SV (the SV gear is over the hit cap, which fits section 3).
- **Paladin Protection** has no build file. Its folder holds a gear set, a rotation and the preset talents, buffs and consumables in `presets.ts`, so a build was assembled by hand from those. It runs, against the sim's default one-target fight. Rough EP against attack power: Strength 2.4, spell damage 2.8, hit 5.5, expertise 3.8, crit 2.4, haste 2.2, intellect 2.1, agility 1.8; stamina, defense and healing power weigh 0. **Tanks:** the engine does not only measure damage. Each run also gives threat per second (TPS), damage taken per second (DTPS), a TMI metric (a survival score for how spiky the damage taken is) and a death probability. The program prints only the DPS table (the HPS table with `-hps`); the others are in the JSON it writes. TPS comes out for any build. DTPS and TMI are 0 unless the build names the player as a tank (`"tanks":[{"type":"Player","index":0}]`), so the build above had no survival numbers until that was added. With it, on the default one-target fight, DTPS weights (negative means less damage taken, per point): defense rating -0.81, agility -0.36, armor -0.033; TMI weight: stamina -0.19, defense -0.12. TPS EP against attack power: hit 7.5, expertise 4.7, strength 3.3 (versus DPS EP hit 5.5, expertise 3.8). The death probability weights were all 0 in this short run. Turning these into one table is a judgement the engine does not make (how much threat is worth against survival), and a single-target default fight with no tank healing is a thin model of tanking. The team's tank tables use the recipe of the sim's own Warrior Protection weights, with a boss and a healing model from the presets (section 9).

## 9. Tank tables (Druid Bear, Paladin Protection)

**2026-11-02, sim `3e41c53f`.** How the team turns the engine's threat and survival results into one table for a tank spec. The rule and the inputs each table records are in technical findings 14.1; the numbers go in `Data/WeightTables.lua`.

- **The recipe.** **Source-read:** the sim's Warrior Protection presets (`ui/specs/warrior/protection/presets.ts`, lines 34 to 36) say how their weights are measured: "0.6 x the threat weights (Strength = 1) plus 1.15 x the TMI weights (Stamina = 1)", on each gear set, with ArmorNoMods weighed as Armor "since nothing in the build scales armor". The preset's own Stamina and Strength values are what the recipe gives (the other term adds about 0.02 to each), so the threat weights are divided by Strength's threat weight and the TMI weights by Stamina's TMI weight. The team's Druid Bear and Paladin Protection tables use the same recipe, so a table values a tank in a group.
- **Signs.** **Source-read, observed:** the engine's own EP column is an absolute value, and for TMI it uses Armor as the reference, so the combination is worked from the raw weights in the JSON instead. A stat that helps survival has a negative TMI weight (a lower TMI is better), and dividing by Stamina's negative TMI weight makes it positive.
- **Inputs.** **Observed:** neither spec ships a build file, so each build is assembled from its spec's presets (talents, rotation, the dev-only level 60 placeholder gear, race, consumables, buffs and debuffs, healing model), with the player named as the tank. Both tanks face the same boss: one level 63 target with minimum base damage 6000 (the Bear presets' Mount Hyjal value) and armor 3731, over 180 s with 5 s variation. Target mode at 0.05, seed 101, each spec's own `epStats` plus main hand DPS. The run's EP reference stat only scales the printed EP; the combination uses raw weights, so it does not depend on it.
- **Boss damage moves survival only.** **Observed:** on Protection, raising boss damage from the program's default (2601) to 6000 left the DPS and threat weights nearly unchanged and made Stamina's TMI weight about three times larger. Boss damage is therefore one of a tank table's inputs, and both tanks use the same value.
- **Dodge and parry.** **Observed:** on Protection both come out below 0 (dodge by about two of its intervals, parry within its interval): the threat term is negative (an attack dodged or parried gives no threat; the mechanism is unverified) and outweighs the small TMI term. Bear's dodge is about 0, within its interval. The tables keep them as measured (spec 8.2).
- **Armor.** **Observed:** for Protection the Armor and ArmorNoMods weights agree. For Bear the ArmorNoMods weight is much lower, because the Bear build scales armor, so the recipe's reason does not hold there; the table takes the Armor weight all the same, as the recipe says. Which of the two fits an item's armor in bear form is unverified.
- **Precision.** **Observed:** the program sets its iteration targets from DPS (or HPS) only, so the threat and TMI terms keep whatever precision the DPS-targeted run reached. Most combined values are within 0.05 at 90%; agility, defense, dodge, parry and block rating are the loosest, up to about 0.09. A tighter result needs the program to target threat and TMI, which it does not yet do. Death probability is not used.
- **Solo play.** The recipe weighs threat, which a tank levelling alone needs less than survival. Survival-only tables, from the same runs' TMI or DTPS results, are a later addition (spec section 23).
