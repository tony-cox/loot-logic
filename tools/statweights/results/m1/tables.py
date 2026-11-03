import json,math
names=["STR","AGI","STA","INT","HEAL","SPDMG","ARCANE","FIRE","FROST","HOLY","NATURE","SHADOW","SPIERCE","SPI","AP","RAP","FERALAP","HIT","CRIT","HASTE","ARPEN","EXPERT","DEF","BLOCK","BLOCKVAL","DODGE","PARRY","ARMOR","BONUSARMOR","HEALTH","MANA","MP5","R1","R2","R3","R4","R5","PHYSDMG","ARMORNOMODS"]
for f,ref in [("warlock",5),("shaman",14),("bear",1),("prot",0)]:
    d=json.load(open(f+".json"));m=d['dps'];sc=d['sampleCounts']
    print("##",f,"ref",names[ref])
    rw=m['weights']['stats'][ref]
    rows=[]
    for i,(w,sd) in enumerate(zip(m['weights']['stats'],m['weightsStdev']['stats'])):
        n=sc['stats'][i]
        if n:
            ci=1.645*sd/math.sqrt(n)
            rows.append((names[i],w,ci,w/rw,ci/abs(rw),n))
    for i,(w,sd) in enumerate(zip(m['weights']['pseudoStats'],m['weightsStdev']['pseudoStats'])):
        n=sc['pseudoStats'][i]
        if n and i==0:
            ci=1.645*sd/math.sqrt(n); rows.append(("DPS_MH",w,ci,w/rw,ci/abs(rw),n))
    print("stat | raw w DPS/pt | raw 90% CI | signed EP | EP 90% CI | samples")
    for r in rows: print("%s | %.4f | +-%.4f | %.4f | +-%.4f | %d"%r)
