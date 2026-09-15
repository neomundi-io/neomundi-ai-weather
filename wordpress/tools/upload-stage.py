"""Upload the verified theme to a NEW staging directory with SFTP."""
import hashlib, json, os, pathlib, subprocess, sys
base=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((base/'validation/DEPLOYMENT-INVENTORY.json').read_text())
assert len(manifest['files'])==198
source=base/'theme'
assert hashlib.sha256((base/'dist/ai-weather-0.1.0.zip').read_bytes()).hexdigest()=='5ece3d799483655803d30fc4b66b0839490e7adbaf5bb8ec4833f6e0e9c31004'
for item in manifest['files']:
 data=(source/item['path']).read_bytes()
 assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],item['path']
target='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud/wp-content/themes'
dirs=set()
for item in manifest['files']:
 for d in pathlib.PurePosixPath(item['path']).parents:
  if str(d)!='.':dirs.add(str(d))
lines=['mkdir "'+target+'/'+d+'"' for d in sorted(dirs,key=lambda p:(p.count('/'),p))]
lines+=['put "'+(source/i['path']).as_posix()+'" "'+target+'/'+i['path']+'"' for i in manifest['files']]
cmd=['sftp','-F','NUL','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-P','22','-b','-',os.environ['AW_SSH_USER']+'@'+os.environ['AW_SSH_HOST']]
r=subprocess.run(cmd,input='\n'.join(lines)+'\n',text=True,capture_output=True)
if r.returncode:
 print(r.stdout[-3000:]);print(r.stderr);sys.exit(r.returncode)
print('SFTP: 198 files uploaded into newly created ai-weather directory.')
