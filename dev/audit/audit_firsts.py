import json,glob,os,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
base=os.path.join(ROOT,"AI_WEATHER_RUNNER","results")
dates=[d for d in sorted(os.listdir(base)) if d.startswith("2026-") and not d.endswith(".zip")]
print("date        n   CoreSTOP CoreWARN  stab<=0.35  mv3.1.0  FLAG%  topReasonsFLAG")
for d in dates[-14:]:
    rows=[]
    for f in glob.glob(os.path.join(base,d,"*_results.jsonl")):
        for l in open(f,encoding='utf-8-sig',errors='replace'):
            l=l.strip()
            if l:
                try: rows.append(json.loads(l))
                except Exception: pass
    core_stop=sum(1 for r in rows if 'Core says STOP' in str(r.get('governance_reasons') or ''))
    core_warn=sum(1 for r in rows if 'Core says WARN' in str(r.get('governance_reasons') or ''))
    low=0
    for r in rows:
        try:
            if r.get('stability_score') is not None and float(r['stability_score'])<=0.35: low+=1
        except Exception: pass
    mv=sum(1 for r in rows if r.get('measurement_version')=='3.1.0')
    fl=sum(1 for r in rows if r.get('decision')=='FLAG')
    rc=collections.Counter()
    for r in rows:
        if r.get('decision')=='FLAG':
            gr=str(r.get('governance_reasons') or '')
            rc[gr[:48]]+=1
    top=" ; ".join(f"{v}x {k}" for k,v in rc.most_common(2))
    print(f"{d} {len(rows):4} {core_stop:8} {core_warn:8} {low:10} {mv:8} {100*fl//max(1,len(rows)):5}%  {top}")
