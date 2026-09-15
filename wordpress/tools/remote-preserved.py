import hashlib,json,pathlib,tarfile
root=pathlib.Path.cwd()
assert root.name=='neomundi.cloud' and root.resolve()==root
backup=root.parents[1]/'aw-return-20260915-201008'
prefixes=['neomundi.cloud/wp-content/themes/','neomundi.cloud/wp-content/plugins/','neomundi.cloud/wp-content/uploads/']
counts=dict.fromkeys(prefixes,0);mismatches=[]
with tarfile.open(backup/'site-before.tar.gz','r:gz') as archive:
 for entry in archive:
  prefix=next((p for p in prefixes if entry.name.startswith(p)),None)
  if not prefix or not entry.isfile():continue
  target=root.parent/entry.name
  expected=hashlib.sha256(archive.extractfile(entry).read()).hexdigest()
  if not target.is_file() or target.stat().st_size!=entry.size:
   mismatches.append(entry.name);continue
  with target.open('rb') as f:actual=hashlib.sha256(f.read()).hexdigest()
  if expected!=actual:mismatches.append(entry.name)
  counts[prefix]+=1
print(json.dumps({'verified_unchanged':counts,'mismatches':mismatches},indent=2))
raise SystemExit(bool(mismatches))
