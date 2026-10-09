import json,glob,os,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
base=os.path.join(ROOT,"AI_WEATHER_RUNNER","results")
dates=[d for d in sorted(os.listdir(base)) if d.startswith("2026-") and not d.endswith(".zip")][-11:]
print(f"{'date':11}{'rows':>5}{'dupReqId':>9}{'dupSlot':>8}{'models':>7}{'promptIdsD':>11}{'promptIdsL':>11}{'tempNot0.7':>11}{'provMiss':>9}{'nullDec':>8}")
allmodels={}
for d in dates:
    rows=[]
    for f in glob.glob(os.path.join(base,d,"*_results.jsonl")):
        for l in open(f,encoding='utf-8-sig',errors='replace'):
            l=l.strip()
            if l:
                try: rows.append(json.loads(l))
                except Exception: pass
    rid=collections.Counter(r.get('request_id') for r in rows)
    dup_rid=sum(v-1 for v in rid.values() if v>1)
    slot=collections.Counter((r.get('provider'),r.get('prompt_id'),r.get('repetition_index')) for r in rows)
    dup_slot=sum(v-1 for v in slot.values() if v>1)
    models={}
    for r in rows: models[r.get('provider')]=r.get('requested_model')
    allmodels[d]=models
    pid_d=len({r.get('prompt_id') for r in rows if str(r.get('prompt_id','')).startswith('daily')})
    pid_l=len({r.get('prompt_id') for r in rows if str(r.get('prompt_id','')).startswith('longitudinal')})
    tnot=sum(1 for r in rows if r.get('temperature_requested') not in (0.7,None))
    provmiss=sum(1 for r in rows if not r.get('measurement_version'))
    nulldec=sum(1 for r in rows if not str(r.get('decision') or '').strip())
    print(f"{d:11}{len(rows):>5}{dup_rid:>9}{dup_slot:>8}{len(models):>7}{pid_d:>11}{pid_l:>11}{tnot:>11}{provmiss:>9}{nulldec:>8}")
print("\n=== requested_model per provider, changes across the window ===")
provs=sorted({p for m in allmodels.values() for p in m})
for p in provs:
    seq=[(d,allmodels[d].get(p)) for d in dates]
    vals=[v for _,v in seq]
    uniq=[]
    for v in vals:
        if not uniq or uniq[-1]!=v: uniq.append(v)
    flag="  <-- CHANGED" if len(uniq)>1 else ""
    print(f"  {str(p):12} {' -> '.join(str(u) for u in uniq)}{flag}")
