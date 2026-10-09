import json,glob,os,sys,collections
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
base=os.path.join(ROOT,"aiweather-capsule","interoperability")
dates=sorted(os.listdir(base))
print(f"{'date':12} {'files':>5} {'mver':>22} {'status':>28} {'cov':>22} {'sysid':>20}")
for d in dates[-20:]:
    files=glob.glob(os.path.join(base,d,"*.json"))
    mv=collections.Counter(); st=collections.Counter(); cov=collections.Counter(); sid=collections.Counter(); nv=collections.Counter()
    for f in files:
        try:
            o=json.load(open(f,encoding='utf-8-sig'))
        except Exception as e:
            st['PARSE_ERR']+=1; continue
        mv[o.get('provenance',{}).get('measurement_version')]+=1
        nv[o.get('provenance',{}).get('normalizer_version')]+=1
        ob=o.get('observation',{})
        st[ob.get('measurement_status')]+=1
        cov[ob.get('measurement_coverage')]+=1
        sid[o.get('identity',{}).get('system_id')]+=1
    fmt=lambda c:",".join(f"{k}:{v}" for k,v in sorted(c.items(),key=lambda x:str(x[0])))
    print(f"{d:12} {len(files):>5} {fmt(mv):>22} {fmt(st):>28} {fmt(cov):>22} {fmt(sid):>20} norm={fmt(nv)}")
