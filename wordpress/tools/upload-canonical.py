import hashlib,json,os,pathlib,subprocess
base=pathlib.Path(__file__).resolve().parents[1]
old=json.loads((base/'validation/DEPLOYMENT-INVENTORY.json').read_text());new=json.loads((base/'dist/DEPLOYMENT-INVENTORY.json').read_text())
om={f['path']:f for f in old['files']};nm={f['path']:f for f in new['files']};assert om.keys()==nm.keys() and len(nm)==198
changed=[p for p in nm if nm[p]['sha256']!=om[p]['sha256']]
label=os.environ['AW_PATCH_LABEL'];assert label in ['home-widgets','remaining-pages']
remote='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-repair-return-20260915-214448/incoming-'+label
dirs=set()
for p in changed:
 data=(base/'theme'/p).read_bytes();assert len(data)==nm[p]['bytes'] and hashlib.sha256(data).hexdigest()==nm[p]['sha256']
 for d in pathlib.PurePosixPath(p).parents:
  if str(d)!='.':dirs.add(str(d))
commands=['mkdir "'+remote+'"']+['mkdir "'+remote+'/'+d+'"' for d in sorted(dirs,key=lambda x:(x.count('/'),x))]
commands+=['put "'+(base/'theme'/p).as_posix()+'" "'+remote+'/'+p+'"' for p in changed]
r=subprocess.run(['sftp','-F','NUL','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-P','22','-b','-',os.environ['AW_SSH_USER']+'@'+os.environ['AW_SSH_HOST']],input='\n'.join(commands)+'\n',text=True,capture_output=True)
if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
print(json.dumps({'staged':changed},indent=2))
