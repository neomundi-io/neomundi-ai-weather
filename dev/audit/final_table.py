import json,glob,os,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
res=os.path.join(ROOT,"AI_WEATHER_RUNNER","results")
iop=os.path.join(ROOT,"aiweather-capsule","interoperability")
hist=os.path.join(ROOT,"data","history")
dates=[d for d in sorted(os.listdir(res)) if d.startswith("2026-") and not d.endswith(".zip")][-11:]
rowsfmt="| {d} | {exp} | {recv} | {err} | {valid} | {cov100} | {mv} | {flagpct}% | {score} | {cond} | {states} |"
print("| Date | Attendu | Reçu | ERROR | Valides | API cov=1.0 | measurement_version | FLAG | global_score | Condition | Longitudinal |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for d in dates:
    rows=[]
    for f in glob.glob(os.path.join(res,d,"*_results.jsonl")):
        for l in open(f,encoding='utf-8-sig',errors='replace'):
            l=l.strip()
            if l:
                try: rows.append(json.loads(l))
                except Exception: pass
    h=json.load(open(os.path.join(hist,d+".json"),encoding='utf-8-sig'))
    exp=h['panel_summary']['total_expected_observations']
    err=sum(1 for r in rows if r.get('decision')=='ERROR' or str(r.get('error') or '').strip())
    valid=sum(1 for r in rows if str(r.get('decision') or '').strip() and r.get('decision')!='ERROR')
    fl=sum(1 for r in rows if r.get('decision')=='FLAG')
    mv=collections.Counter(r.get('measurement_version') for r in rows if r.get('measurement_version') and r['measurement_version'][0].isdigit())
    full=0; tot=0
    for f in glob.glob(os.path.join(iop,d,"*.json")):
        try: o=json.load(open(f,encoding='utf-8-sig'))
        except Exception: continue
        tot+=1
        if o['observation'].get('measurement_coverage')==1.0: full+=1
    st=collections.Counter((s['longitudinal'].get('current_longitudinal_state') or {}).get('state') for s in h['systems'])
    states=" ".join(f"{k.replace('attention_','a_')}:{v}" for k,v in sorted(st.items(),key=lambda x:-x[1]))
    print(rowsfmt.format(d=d,exp=exp,recv=len(rows),err=err,valid=valid,
        cov100=f"{full}/{tot}", mv=",".join(sorted(mv)), flagpct=round(100*fl/max(1,len(rows))),
        score=h['global_score'], cond=h['global_condition'], states=states))
