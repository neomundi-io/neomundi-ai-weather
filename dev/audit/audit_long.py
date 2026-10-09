import json,glob,os,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
def L(f): return json.load(open(f,encoding='utf-8-sig'))
files=sorted(glob.glob(os.path.join(ROOT,"data","history","*.json")))[-11:]
print("date        states(longitudinal)                                        baseline windows")
for f in files:
    d=L(f); st=collections.Counter(); bw=collections.Counter(); dev=[]
    for s in d['systems']:
        lg=s.get('longitudinal') or {}
        cs=lg.get('current_longitudinal_state') or {}
        st[cs.get('state')]+=1
        b=lg.get('baseline') or {}
        bw[f"{b.get('window_start')}->{b.get('window_end')}({b.get('status')})"]+=1
        if lg.get('deviation_index') is not None: dev.append(lg['deviation_index'])
    dev.sort()
    med=dev[len(dev)//2] if dev else None
    print(f"{os.path.basename(f)[:-5]}  {dict(st)}  med_dev={med}  {dict(bw)}")
print()
print("=== per-system longitudinal state, last day ===")
d=L(files[-1])
for s in d['systems']:
    lg=s['longitudinal']; cs=lg.get('current_longitudinal_state') or {}
    print(f"  {s['id']:12} {s['model_display']:12} score={lg.get('score'):>4} dev={lg.get('deviation_index')} state={cs.get('state')} "
          f"baseline_med={(lg.get('baseline') or {}).get('median')} mad={(lg.get('baseline') or {}).get('mad')} "
          f"events={len(lg.get('detected_events') or [])} identity={(lg.get('system_identity') or {}).get('identity_status')}")
