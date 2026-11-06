// Command statweights computes stat weights with WoWSims Forever's own engine (core.StatWeights).
//
// It is the program the LootLogic team runs to produce the weight tables in Data/WeightTables.lua. It imports the sim's
// packages (MIT licensed, copyright (c) 2022 wowsims team, https://github.com/wowsims/forever) and calls their
// exported functions, so it needs a checkout of the sim with the protobuf Go files generated. See README.md. The one
// piece of sim logic it carries is individualSimRequest, below, under the sim's MIT licence.
//
// We run this file as it stands. It is written against one sim commit (recorded in README.md), so a newer sim may need
// small changes. It is not part of the addon.
//
// Input is an IndividualSimSettings in protojson or a full SIML settings file holding talents, rotation, consumables,
// buffs and sometimes gear. The request is built from it the way the sim's own CLI builds a normal run
// (individualSimRequest, which is unexported there, so it is reproduced below).
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/wowsims/forever/sim/core"
	"github.com/wowsims/forever/sim/core/proto"
	"github.com/wowsims/forever/sim/core/stats"
	"github.com/wowsims/forever/sim/siml"
	"google.golang.org/protobuf/encoding/protojson"
	googleProto "google.golang.org/protobuf/proto"

	"github.com/wowsims/forever/sim"
)

func main() {
	sim.RegisterAll() // registers every spec with the sim, as the sim's own CLI does at start-up

	var (
		buildPath    = flag.String("build", "", "IndividualSimSettings protojson (a ui/specs/*/builds/*.build.json)")
		gearPath     = flag.String("gear", "", "EquipmentSpec protojson (a gear_sets/*.gear.json); replaces the build's gear")
		rotationPath = flag.String("rotation", "", "SIML APL rotation; replaces the build's rotation")
		tankDamage   = flag.Float64("tank-damage", 0, "override the first target's minimum base damage")
		statNames    = flag.String("stats", "", "comma list of the sim's Stat names to weigh, e.g. StatSpellDamage,StatHitRating")
		pseudoList   = flag.String("pseudo", "", "comma list of pseudo stats to weigh, e.g. PseudoStatMainHandDps")
		refName      = flag.String("ref", "StatSpellDamage", "the stat every EP is measured against (its EP is 1)")
		bonusList    = flag.String("bonus", "", "bonus stats added to the player, e.g. StatHitRating=-40")
		iterations   = flag.Int("iterations", 5000, "iterations per stat run (ignored in target mode)")
		seed         = flag.Int64("seed", 101, "fixed random seed; the same seed gives the same result")
		epCi         = flag.Float64("epci", 0, "target mode: the 90% interval each EP must reach (0 = off)")
		maxMult      = flag.Int("maxmult", 0, "target mode: cap on the iteration multiplier (0 = none)")
		hps          = flag.Bool("hps", false, "weigh and report HPS instead of DPS")
		outPath      = flag.String("out", "", "write the full result as protojson to this file (default stdout)")
	)
	flag.Parse()

	settings := &proto.IndividualSimSettings{}
	if strings.HasSuffix(*buildPath, ".siml") {
		f, err := siml.ReadFile(*buildPath)
		if err != nil {
			log.Fatal(err)
		}
		for _, w := range f.Warnings {
			fmt.Fprintln(os.Stderr, "warning:", w)
		}
		settings = f.Settings
	} else {
		data, err := os.ReadFile(*buildPath)
		if err != nil {
			log.Fatal(err)
		}
		if err := (protojson.UnmarshalOptions{}).Unmarshal(data, &proto.IndividualSimSettings{}); err != nil {
			fmt.Fprintln(os.Stderr, "warning: JSON requires unknown-field compatibility:", err)
		}
		if err := (protojson.UnmarshalOptions{DiscardUnknown: true}).Unmarshal(data, settings); err != nil {
			log.Fatal(err)
		}
	}
	if settings.Player == nil {
		log.Fatal("build has no player")
	}
	if *rotationPath != "" {
		f, err := siml.ReadFile(*rotationPath)
		if err != nil {
			log.Fatal(err)
		}
		for _, w := range f.Warnings {
			fmt.Fprintln(os.Stderr, "warning:", w)
		}
		settings.Player.Rotation = f.Rotation()
	}
	if settings.Player.Rotation == nil || len(settings.Player.Rotation.PriorityList) == 0 {
		log.Fatal("build has no executable priority rotation")
	}
	if *gearPath != "" {
		g, err := os.ReadFile(*gearPath)
		if err != nil {
			log.Fatal(err)
		}
		settings.Player.Equipment = core.EquipmentSpecFromJsonString(string(g))
	}
	simReq, warnings := individualSimRequest(settings, &proto.SimOptions{Iterations: int32(*iterations), RandomSeed: *seed})
	if *tankDamage > 0 {
		simReq.Encounter.Targets[0].MinBaseDamage = *tankDamage
	}
	for _, w := range warnings {
		fmt.Fprintln(os.Stderr, "warning:", w)
	}

	var statList []proto.Stat
	for _, n := range strings.Split(*statNames, ",") {
		v, ok := proto.Stat_value[strings.TrimSpace(n)]
		if !ok {
			log.Fatalf("unknown stat %q", n)
		}
		statList = append(statList, proto.Stat(v))
	}
	ref, ok := proto.Stat_value[*refName]
	if !ok {
		log.Fatalf("unknown reference stat %q", *refName)
	}
	req := &proto.StatWeightsRequest{
		Player:           simReq.Raid.Parties[0].Players[0],
		RaidBuffs:        simReq.Raid.Buffs,
		PartyBuffs:       simReq.Raid.Parties[0].Buffs,
		Debuffs:          simReq.Raid.Debuffs,
		Encounter:        simReq.Encounter,
		SimOptions:       simReq.SimOptions,
		Tanks:            simReq.Raid.Tanks,
		StatsToWeigh:     statList,
		EpReferenceStat:  proto.Stat(ref),
		HpsReferenceStat: proto.Stat(ref),
	}
	if *bonusList != "" {
		bonus := &proto.UnitStats{Stats: make([]float64, len(proto.Stat_name))}
		for _, kv := range strings.Split(*bonusList, ",") {
			p := strings.SplitN(kv, "=", 2)
			if len(p) != 2 {
				log.Fatalf("bad bonus %q", kv)
			}
			v, ok := proto.Stat_value[p[0]]
			var x float64
			if _, err := fmt.Sscan(p[1], &x); !ok || err != nil {
				log.Fatalf("bad bonus %q", kv)
			}
			bonus.Stats[v] = x
		}
		req.Player.BonusStats = bonus
	}
	for _, n := range strings.Split(*pseudoList, ",") {
		if n == "" {
			continue
		}
		v, ok := proto.PseudoStat_value[n]
		if !ok {
			log.Fatalf("unknown pseudo stat %q", n)
		}
		req.PseudoStatsToWeigh = append(req.PseudoStatsToWeigh, proto.PseudoStat(v))
	}
	if *epCi > 0 {
		req.Target = &proto.StatWeightsTarget{EpCi: *epCi, MaxIterationMultiplier: int32(*maxMult)}
		if *hps {
			req.Target.Metrics = []proto.StatWeightsTargetMetric{proto.StatWeightsTargetMetric_StatWeightsTargetMetricHps}
		}
	}

	start := time.Now()
	res := core.StatWeights(req)
	fmt.Fprintf(os.Stderr, "elapsed %s\n", time.Since(start))
	if res.GetError() != nil {
		log.Fatalf("stat weights failed: %v", res.GetError())
	}

	// The printed +- is the per-iteration standard deviation, not the confidence interval.
	v := res.GetDps()
	if *hps {
		v = res.GetHps()
	}
	if v != nil && v.Weights != nil {
		for _, s := range req.PseudoStatsToWeigh {
			i := int(s)
			fmt.Fprintf(os.Stderr, "%-22s weight %9.4f +-%7.4f   EP %8.4f +-%7.4f\n", s.String(),
				v.Weights.PseudoStats[i], v.WeightsStdev.PseudoStats[i], v.EpValues.PseudoStats[i], v.EpValuesStdev.PseudoStats[i])
		}
		for _, s := range statList {
			i := int(s)
			fmt.Fprintf(os.Stderr, "%-22s weight %9.4f +-%7.4f   EP %8.4f +-%7.4f\n", s.String(),
				v.Weights.Stats[i], v.WeightsStdev.Stats[i], v.EpValues.Stats[i], v.EpValuesStdev.Stats[i])
		}
	}
	out, err := protojson.MarshalOptions{Multiline: true}.Marshal(res)
	if err != nil {
		log.Fatal(err)
	}
	if *outPath != "" {
		if err := os.WriteFile(*outPath, out, 0o644); err != nil {
			log.Fatal(err)
		}
	} else {
		fmt.Println(string(out))
	}
}

// individualSimRequest builds the request the sim's CLI builds for a normal single-player run: the player alone in
// the first party, with the party and raid buffs, debuffs and tanks, against the encounter. A ring enchant needs
// Enchanting, so a player without it is simmed without its ring enchants. Settings with no encounter, or one with no
// target, get the site's default fight: 180 s varied by 5 s, against one default target. This follows the function of
// the same name in the sim's cmd/wowsimcli/cmd/sim_request.go at the commit recorded in README.md.
func individualSimRequest(s *proto.IndividualSimSettings, options *proto.SimOptions) (*proto.RaidSimRequest, []string) {
	var warnings []string
	player := googleProto.Clone(orEmpty(s.GetPlayer())).(*proto.Player)
	if player.Profession1 != proto.Profession_Enchanting && player.Profession2 != proto.Profession_Enchanting {
		for _, slot := range []proto.ItemSlot{proto.ItemSlot_ItemSlotFinger1, proto.ItemSlot_ItemSlotFinger2} {
			if items := player.GetEquipment().GetItems(); int(slot) < len(items) && items[slot] != nil {
				items[slot].Enchant = 0
			}
		}
	}
	raid := core.SinglePlayerRaidProto(player, orEmpty(s.PartyBuffs), orEmpty(s.RaidBuffs), orEmpty(s.Debuffs))
	for len(raid.Parties) < 5 {
		raid.Parties = append(raid.Parties, &proto.Party{})
	}
	raid.Tanks = s.Tanks
	raid.TargetDummies = s.TargetDummies

	encounter := s.Encounter
	switch {
	case encounter == nil:
		encounter = &proto.Encounter{
			Duration:             180,
			DurationVariation:    5,
			ExecuteProportion_20: 0.2,
			ExecuteProportion_35: 0.35,
			Targets:              []*proto.Target{defaultTarget()},
		}
		warnings = append(warnings, "the settings hold no encounter; simmed against one default target")
	case len(encounter.Targets) == 0:
		encounter = googleProto.Clone(encounter).(*proto.Encounter)
		encounter.Targets = []*proto.Target{defaultTarget()}
		warnings = append(warnings, "the encounter has no target; simmed against one default target")
	}
	return &proto.RaidSimRequest{Raid: raid, Encounter: encounter, SimOptions: options, Type: proto.SimType_SimTypeIndividual}, warnings
}

// defaultTarget is the sim's test target with the raid target's id, name, health and block value, as the site gives it.
func defaultTarget() *proto.Target {
	target := core.FreshDefaultTargetConfig()
	target.Id, target.Name = 31146, "Raid Target"
	target.Stats[stats.Health] = 1428900
	target.Stats[stats.BlockValue] = 54
	return target
}

// orEmpty returns m, or an empty message of its type when it is nil.
func orEmpty[M googleProto.Message](m M) M {
	if m.ProtoReflect().IsValid() {
		return m
	}
	return m.ProtoReflect().Type().New().Interface().(M)
}
