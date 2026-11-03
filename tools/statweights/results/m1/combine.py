import json,math
names=["STR","AGI","STA","INT","HEAL","SPDMG","ARCANE","FIRE","FROST","HOLY","NATURE","SHADOW","SPIERCE","SPI","AP","RAP","FERALAP","HIT","CRIT","HASTE","ARPEN","EXPERT","DEF","BLOCK","BLOCKVAL","DODGE","PARRY","ARMOR","BONUSARMOR","HEALTH","MANA","MP5","R1","R2","R3","R4","R5","PHYSDMG","ARMORNOMODS"]
def rel(m,sc,i,ref):
    w=m['weights']['stats'][i]; sd=m['weightsStdev']['stats'][i]; n=sc['stats'][i]
    rw=m['weights']['stats'][ref]; rsd=m['weightsStdev']['stats'][ref]; rn=sc['stats'][ref]
    r=w/rw
    s=1.645*math.sqrt((sd/math.sqrt(n)/rw)**2+(w*rsd/math.sqrt(rn)/rw**2)**2)
    return r,s
out=[]
for f in ["bear","prot6000"]:
    d=json.load(open(f+".json")); sc=d['sampleCounts']
    out.append("## %s  combined = 0.6*TPS(vs STR) + 1.15*TMI(vs STA)"%f)
    out.append("stat | TPS EP(STR=1) +-CI | TMI EP(STA=1) +-CI | combined +-CI | DPS EP(own ref) [raw w] ")
    for i in list(range(0,39)):
        if i in (2,0) or sc['stats'][i]:
            if not sc['stats'][i]: continue
            tw=d['tps']['weights']['stats'][i]; mw=d['tmi']['weights']['stats'][i]
            if tw==0 and mw==0: 
                out.append("%s | 0 | 0 | 0 | -"%names[i]); continue
            t,ts=rel(d['tps'],sc,i,0) if tw!=0 else (0,0)
            m,ms=rel(d['tmi'],sc,i,2) if mw!=0 else (0,0)
            out.append("%s | %.4f +-%.4f | %.4f +-%.4f | %.4f +-%.4f | tps_w=%.4f tmi_w=%.4f n=%d"%(names[i],t,ts,m,ms,0.6*t+1.15*m,math.hypot(0.6*ts,1.15*ms),tw,mw,sc['stats'][i]))
    # pseudo MH dps
    tw=d['tps']['weights']['pseudoStats'][0]; mw=d['tmi']['weights']['pseudoStats'][0]
    t=tw/d['tps']['weights']['stats'][0]; m=(mw/d['tmi']['weights']['stats'][2])
    out.append("DPS_MH | %.4f | %.4f | %.4f"%(t,m,0.6*t+1.15*m))
print("\n".join(out))
