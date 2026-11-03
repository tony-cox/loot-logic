import json
SIM='D:/wowsims-forever/ui/specs/'
hm=lambda: {"hps":2200,"cadenceSeconds":0.4,"cadenceVariation":1.2,"absorbFrac":0.02,"burstWindow":6,"inspirationUptime":0.25}
# ---- Bear (from druid/feralbear/spec.ts + presets.ts)
bear_target={"id":31146,"name":"Raid Target","level":63,"mobType":"MobTypeMechanical",
 "stats":None,"minBaseDamage":6000,"damageSpread":0.5,"tankIndex":0,"swingSpeed":2,"parryHaste":True,"canCrush":True}
bear_target.pop("stats")
bear={
 "apiVersion":2,
 "raidBuffs":{"arcaneBrilliance":True,"prayerOfSpirit":True,"giftOfTheWild":True,"prayerOfFortitude":True,"prayerOfShadowProtection":True,"strengthOfEarthTotem":True,"graceOfAirTotem":True,"windfuryTotem":True,"battleShout":1},
 "partyBuffs":{"devotionAura":True,"manaSpringTotem":"TristateEffectRegular","retributionAura":True},
 "debuffs":{"judgementOfLight":True,"judgementOfWisdom":True,"faerieFire":False,"exposeArmor":True,"sunderArmor":True,"vindication":True},
 "tanks":[{"type":"Player","index":0}],
 "player":{
  "apiVersion":2,"name":"Player","race":"RaceTauren","class":"ClassDruid",
  "consumables":{"flaskId":274275,"foodId":21023,"conjuredId":9421,"mhImbueId":18262,"swapMhImbueId":12643,
    "extraIds":[10646,12460,10307,8411],"elixirIds":[9088,250351,250328,250329,13445],"defensivePotId":13455,"offensivePotId":13442},
  "buffs":{"greaterBlessingOfKings":True,"greaterBlessingOfMight":True,"thorns":True},
  "feralBearDruid":{"options":{"classOptions":{},"startingRage":0,"assumeBleedActive":True}},
  "talentsString":"050022-2322030212310212501-055",
  "profession1":"Engineering","profession2":"Enchanting",
  "rotation":json.load(open(SIM+'druid/feralbear/apls/adaptive.apl.json')),
  "reactionTimeMs":250,"distanceFromTarget":25,"healingModel":hm(),
  "equipment":json.load(open(SIM+'druid/feralbear/gear_sets/default.gear.json')),
 }}
bear["encounter"]={"duration":180,"durationVariation":5,"executeProportion20":0.2,"executeProportion35":0.35,"targets":[bear_target]}
json.dump(bear,open('bear.build.json','w'),indent=1)
# ---- Prot (from paladin/protection/presets.ts); no encounter -> program default fight
prot={
 "apiVersion":2,
 "raidBuffs":{"prayerOfSpirit":True,"arcaneBrilliance":True,"giftOfTheWild":True,"prayerOfFortitude":True,"prayerOfShadowProtection":True,"windfuryTotem":True,"graceOfAirTotem":True,"battleShout":1,"leaderOfThePack":True},
 "partyBuffs":{"manaSpringTotem":"TristateEffectRegular"},
 "debuffs":{"judgementOfTheCrusader":True,"curseOfElements":True,"judgementOfWisdom":True,"judgementOfLight":True,"curseOfRecklessness":True,"sunderArmor":True,"faerieFire":True,"exposeArmor":True,"giftOfArthas":True,"demoralizingShout":True,"insectSwarm":True},
 "tanks":[{"type":"Player","index":0}],
 "player":{
  "apiVersion":2,"name":"Player","race":"RaceHuman","class":"ClassPaladin",
  "consumables":{"flaskId":13512,"foodId":13935,"defensivePotId":13455,"conjuredId":12662,"mhImbueId":20749,"explosiveId":18588,
    "extraIds":[10646,12460,10307],
    "elixirIds":[21546,13454,250337,250338,250335,250341,13445,250350,13452]},
  "buffs":{"thorns":True,"greaterBlessingOfKings":True,"greaterBlessingOfWisdom":True,"greaterBlessingOfMight":True},
  "protectionPaladin":{"options":{"classOptions":{}}},
  "talentsString":"050050002-05302102213301531-502",
  "profession1":"Engineering","profession2":"Enchanting",
  "rotation":json.load(open(SIM+'paladin/protection/apls/default.apl.json')),
  "distanceFromTarget":5,"healingModel":hm(),
  "equipment":json.load(open(SIM+'paladin/protection/gear_sets/default.gear.json')),
 }}
json.dump(prot,open('prot.build.json','w'),indent=1)
