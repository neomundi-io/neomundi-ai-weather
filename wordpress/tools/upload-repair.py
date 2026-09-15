import hashlib,json,os,pathlib,subprocess
base=pathlib.Path(__file__).resolve().parents[1]
old=json.loads((base/'validation/DEPLOYMENT-INVENTORY-0.1.0.json').read_text())
new=json.loads((base/'dist/DEPLOYMENT-INVENTORY.json').read_text())
oldmap={f['path']:f for f in old['files']};newmap={f['path']:f for f in new['files']}
assert oldmap.keys()==newmap.keys() and len(newmap)==198
changed=[p for p in newmap if newmap[p]['sha256']!=oldmap[p]['sha256']]
assert set(changed)=={'ai-weather/inc/content.php','ai-weather/index.php','ai-weather/functions.php','ai-weather/style.css'},changed
for p in changed:
 data=(base/'theme'/p).read_bytes();assert len(data)==newmap[p]['bytes'] and hashlib.sha256(data).hexdigest()==newmap[p]['sha256']
remote='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-repair-return-20260915-205808/incoming'
dirs={'ai-weather','ai-weather/inc'}
commands=['mkdir "'+remote+'"']+['mkdir "'+remote+'/'+d+'"' for d in sorted(dirs,key=len)]
commands+=['put "'+(base/'theme'/p).as_posix()+'" "'+remote+'/'+p+'"' for p in changed]
cmd=['sftp','-F','NUL','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-P','22','-b','-',os.environ['AW_SSH_USER']+'@'+os.environ['AW_SSH_HOST']]
r=subprocess.run(cmd,input='\n'.join(commands)+'\n',text=True,capture_output=True)
if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
print('Four verified files staged privately; public theme not yet replaced.')
