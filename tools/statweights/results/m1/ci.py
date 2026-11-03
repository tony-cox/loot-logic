import json,sys,math
names=["Strength","Agility","Stamina","Intellect","HealingPower","SpellDamage","ArcaneDamage","FireDamage","FrostDamage","HolyDamage","NatureDamage","ShadowDamage","SpellPiercing","Spirit","AttackPower","RangedAttackPower","FeralAttackPower","HitRating","CritRating","HasteRating","ArmorPenetration","ExpertiseRating","DefenseRating","BlockRating","BlockValue","DodgeRating","ParryRating","Armor","BonusArmor"]
f=sys.argv[1]; metric=sys.argv[2] if len(sys.argv)>2 else 'dps'
d=json.load(open(f))
sc=d['sampleCounts']
if len(sys.argv)<3: print("sampleCounts keys:",list(sc.keys()) if isinstance(sc,dict) else sc)
m=d[metric]
for i,(w,sd,ep,esd) in enumerate(zip(m['weights']['stats'],m['weightsStdev']['stats'],m['epValues']['stats'],m['epValuesStdev']['stats'])):
    if w or sd:
        n=None
        if isinstance(sc,dict):
            s=sc.get('stats'); n=s[i] if s else None
        print(i,names[i] if i<len(names) else i,"w=%.4f ep=%.4f n=%s"%(w,ep,n), "ci90_ep=%s"%(("%.4f"%(1.645*esd/math.sqrt(n))) if n else '?'))
for i,(w,esd,ep) in enumerate(zip(m['weights']['pseudoStats'],m['epValuesStdev']['pseudoStats'],m['epValues']['pseudoStats'])):
    if w:
        s=sc.get('pseudoStats'); n=s[i] if s else None
        print("pseudo",i,"w=%.4f ep=%.4f n=%s"%(w,ep,n),"ci90_ep=%s"%(("%.4f"%(1.645*esd/math.sqrt(n))) if n else '?'))
