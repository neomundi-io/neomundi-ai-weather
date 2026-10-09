import json,glob,os,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
base=os.path.join(ROOT,"AI_WEATHER_RUNNER","results")
def load(d):
    rows=[]
    for f in glob.glob(os.path.join(base,d,"*_results.jsonl")):
        for l in open(f,encoding='utf-8-sig',errors='replace'):
            l=l.strip()
            if l:
                try: rows.append(json.loads(l))
                except Exception: pass
    return rows
for d in ["2026-09-28","2026-09-29","2026-10-02","2026-10-03","2026-10-05","2026-10-08","2026-10-09"]:
    rows=load(d)
    same=0; govnull=0; stabvals=collections.Counter(); reasons=collections.Counter(); ce=collections.Counter()
    for r in rows:
        s=r.get('stability_score'); ss=r.get('stream_stability_score')
        try:
            if s is not None and ss is not None and abs(float(s)-float(ss))<1e-4: same+=1
        except Exception: pass
        if s is None: govnull+=1
        stabvals[None if s is None else round(float(s),4)]+=1
        gr=str(r.get('governance_reasons') or '')
        key=gr.split('--')[-1].strip()[:60] if '--' in gr else gr[:60]
        reasons[key]+=1
        ce[r.get('checks_emitted')]+=1
    print(f"### {d}  n={len(rows)}  stability==stream_stability: {same}  gov stab null: {govnull}")
    print("   top stability values:", stabvals.most_common(4))
    print("   checks_emitted:", dict(ce))
    for k,v in reasons.most_common(4): print(f"   reason[{v:4}] {k}")
