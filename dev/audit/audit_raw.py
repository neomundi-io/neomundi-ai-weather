import json,glob,os,collections,statistics as st
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
base=os.path.join(ROOT,"AI_WEATHER_RUNNER","results")
dates=[d for d in sorted(os.listdir(base)) if d.startswith("2026-")]
def num(v):
    try:
        f=float(v); return f
    except Exception: return None
print(f"{'date':11}{'rows':>5}{'mver':>18}{'dec ALLOW/FLAG/ERR/other':>28}{'err':>5}{'nullCoh':>8}{'nullSR':>7}{'medG':>8}{'medGfin':>8}{'medStab':>8}{'promptv':>8}{'temp':>6}")
for d in dates:
    rows=[]
    for f in glob.glob(os.path.join(base,d,"*_results.jsonl")):
        for l in open(f,encoding='utf-8-sig',errors='replace'):
            l=l.strip()
            if not l: continue
            try: rows.append(json.loads(l))
            except Exception: pass
    mv=collections.Counter(); dec=collections.Counter(); pv=collections.Counter(); tm=collections.Counter()
    err=0; nc=0; ns=0; g=[]; gf=[]; sb=[]
    for r in rows:
        mv[r.get('measurement_version')]+=1
        dec[str(r.get('decision'))]+=1
        pv[str(r.get('prompt_version'))]+=1
        tm[str(r.get('temperature_mode'))]+=1
        if str(r.get('error') or '').strip(): err+=1
        if r.get('coherence_score') in (None,'',): nc+=1
        if r.get('semantic_risk') in (None,'',): ns+=1
        for key,acc in (('g_score',g),('g_final',gf),('stability_score',sb)):
            v=num(r.get(key))
            if v is not None: acc.append(v)
    f2=lambda x: f"{st.median(x):.4f}" if x else "-"
    decs=f"{dec.get('ALLOW',0)}/{dec.get('FLAG',0)}/{dec.get('ERROR',0)}/{sum(v for k,v in dec.items() if k not in ('ALLOW','FLAG','ERROR'))}"
    fmt=lambda c:",".join(f"{k}:{v}" for k,v in sorted(c.items(),key=lambda x:str(x[0])))
    print(f"{d:11}{len(rows):>5}{fmt(mv):>18}{decs:>28}{err:>5}{nc:>8}{ns:>7}{f2(g):>8}{f2(gf):>8}{f2(sb):>8}{fmt(pv):>8}{fmt(tm):>6}")
