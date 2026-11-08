# statweights

The program the LootLogic team runs to compute stat weights with WoWSims Forever's own engine (`core.StatWeights`). The computed weight tables in `Data/WeightTables.lua` come from it; the Restoration Druid table is team judgement. It is a development tool, not part of the addon, and it is not shipped with it.

It imports the sim's packages (MIT licensed, copyright (c) 2022 wowsims team, https://github.com/wowsims/forever) and calls their exported functions. One function is reproduced from the sim: `individualSimRequest`, which the sim keeps unexported in `cmd/wowsimcli/cmd/sim_request.go`, so the program carries its logic (about 40 lines) with the sim's MIT notice kept in `LICENSES/WoWSims-MIT.txt`. Nothing else is copied.

The program was updated against sim commit `16e85426c43340f73f4f6ddc84938d4385890ea8`. It is not kept in step with the sim, so a newer sim may need changes. Feedback from people who know the sim well is welcome: in particular on how the request is built, on target mode, and on the hit offset (`-bonus`) approach described in `docs/sim-learnings.md`.

## Setup

1. Check out the sim at the commit you want to compute against, and generate its protobuf Go files (the sim's `.gitignore` excludes them, so a module download of the sim does not compile). From the sim checkout, with `protoc` and `protoc-gen-go` installed:

   ```
   protoc --proto_path=./proto --go_opt=Mgoogle/protobuf/descriptor.proto=google.golang.org/protobuf/types/descriptorpb --go_out=./sim/core ./proto/*.proto
   ```

   (The exact command is the one in the sim's own Makefile, which this team does not use; check it if the line above fails.)

2. Point `go.mod` at the checkout. The `replace` line holds a relative path; change it to where your checkout is.

3. Build, with the `with_db` tag so the item database is embedded:

   ```
   go build -tags with_db -o statweights .
   ```

## Run

Run it from the sim checkout, so the build and gear paths resolve. Example, Shaman Enhancement on the sim's Testing build, with 40 hit rating removed so the gear sits below the hit cap, until every EP is within 0.05 at 90%:

```
statweights -build ui/specs/shaman/enhancement/builds/testing.build.json \
  -stats StatStrength,StatAgility,StatIntellect,StatAttackPower,StatHitRating,StatCritRating,StatHasteRating,StatExpertiseRating,StatArmorPenetration,StatSpellDamage,StatNatureDamage,StatSpellPiercing \
  -pseudo PseudoStatMainHandDps -ref StatAttackPower -bonus StatHitRating=-40 \
  -epci 0.05 -maxmult 3000 -out enh.json
```

Weights and EP print to stderr. The `+-` beside each is the per-iteration standard deviation, not the confidence interval. The full result is written as protojson to `-out`.

For a spec that keeps its gear in a separate file, add `-gear ui/specs/<class>/<spec>/gear_sets/<name>.gear.json`. Run `statweights -h` for every flag.

`-build` also accepts a full SIML settings file, resolving its `use` lines with the sim's parser. A file using a simple or auto rotation needs an executable APL supplied with `-rotation path.apl.siml`; the wrapper rejects a missing priority list. `-tank-damage` overrides the first target's minimum base damage. Legacy JSON builds discard unknown proto fields; check their effective settings when changing sim versions.

## Record the inputs

Every table computed with it records the sim commit, the build file, the gear set, the bonus stats, the seed and the target, so the numbers can be reproduced. The same seed gives the same result.
