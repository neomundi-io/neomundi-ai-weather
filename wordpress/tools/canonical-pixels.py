"""Read-only screenshot comparison; never rewrites images."""
import json,pathlib
from PIL import Image,ImageChops
base=pathlib.Path(__file__).resolve().parents[1]/'test-results'
results=[]
for folder in ['canonical-first-live','canonical-rest-live']:
 report=json.loads((base/folder/'comparison.json').read_text())
 for pair in report['pairs']:
  name=f"{pair['page']}-{pair['width']}"
  with Image.open(base/folder/(name+'-source.png')) as a, Image.open(base/folder/(name+'-wordpress.png')) as b:
   row={'page':pair['page'],'width':pair['width'],'reference_size':a.size,'wordpress_size':b.size}
   if a.size==b.size:
    diff=ImageChops.difference(a.convert('RGB'),b.convert('RGB'))
    changed=sum(max(p)>20 for p in diff.getdata())
    row.update(changed_pixels_over_20=changed,changed_percent=round(100*changed/(a.width*a.height),4))
    if pair['page']=='us-station':
     rect=pair['source']['styles']['.us-observatory'][0]
     outside=sum(max(pixel)>20 for i,pixel in enumerate(diff.getdata()) if not(rect['x']<=i%a.width<rect['x']+rect['width'] and rect['y']<=i//a.width<rect['y']+rect['height']))
     row['changed_pixels_outside_animation']=outside
   elif pair['page']!='widgets' and a.height==b.height:
    # Compare the common mobile viewport below its intentionally adapted header.
    diff=ImageChops.difference(a.convert('RGB').crop((0,69,390,a.height)),b.convert('RGB').crop((0,69,390,b.height)))
    row['changed_pixels_below_mobile_header']=sum(max(p)>20 for p in diff.getdata())
   results.append(row)
(base/'canonical-pixels.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
