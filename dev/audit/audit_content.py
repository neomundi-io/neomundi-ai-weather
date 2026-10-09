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
for d in ["2026-10-02","2026-10-05","2026-10-08"]:
    rows=[r for r in load(d) if r.get('provider')=='openai']
    print(f"=== {d} openai rows={len(rows)}")
    for r in rows[:4]:
        print(f"  prompt={r.get('prompt_id')} rep={r.get('repetition_index')} dec={r.get('decision')} "
              f"stab={r.get('stability_score')} streamstab={r.get('stream_stability_score')} "
              f"coh={r.get('coherence_score')} sr={r.get('semantic_risk')} fact={r.get('factual_hallucination_score')} "
              f"semins={r.get('semantic_instability_score')} chk={r.get('checks_emitted')} evt={r.get('stream_event_count')} tok={r.get('token_count')}")
        print(f"    resp: {str(r.get('llm_response'))[:110]!r}")
