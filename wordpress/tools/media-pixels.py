"""Compare screenshots without altering image artifacts."""
import json,pathlib
from PIL import Image,ImageChops
base=pathlib.Path(__file__).resolve().parents[1]/'test-results'
rows=[]
layout_file=base/'media-after/layout.json'
layouts={f"{r['slug']}-{r['width']}.png":r for r in json.loads(layout_file.read_text())} if layout_file.exists() else {}
for f in (base/'media-after').glob('*.png'):
 old=base/'media-before'/f.name
 if not old.exists():continue
 with Image.open(old) as a, Image.open(f) as b:
  w,h=min(a.width,b.width),min(a.height,b.height)
  diff=ImageChops.difference(a.convert('RGB').crop((0,0,w,h)),b.convert('RGB').crop((0,0,w,h)))
  changed=[i for i,p in enumerate(diff.getdata()) if max(p)>20]
  row={'image':f.name,'before':a.size,'after':b.size,'first_changed_row':min(changed)//w if changed else None,'changed_pixels':len(changed)}
  layout=layouts.get(f.name)
  if layout and not f.name.startswith('contact-'):
   cutoff=int((layout['block'] or layout['footer'] or {'y':h})['y'])
   anim=layout['animation']
   unexpected=[i for i in changed if i//w<cutoff and not(anim and anim['x']<=i%w<anim['x']+anim['width'] and anim['y']<=i//w<anim['y']+anim['height'])]
   row['unchanged_area_bottom']=cutoff
   row['changed_pixels_outside_authorized_areas_and_animation']=len(unexpected)
   assert not unexpected, f'Unexpected visual change: {f.name}: {len(unexpected)} pixels'
  rows.append(row)
(base/'media-after/pixels.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
