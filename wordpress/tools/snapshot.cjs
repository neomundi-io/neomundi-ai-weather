const fs=require('fs'),path=require('path'),crypto=require('crypto');
const source=path.resolve(__dirname,'../../../..');
const dest=path.resolve(__dirname,'../source-public');
const files=[];
function add(rel){const p=path.join(source,rel);if(fs.statSync(p).isDirectory()){for(const e of fs.readdirSync(p))add(rel+'/'+e);}else files.push(rel);}
for(const rel of ['assets','styles','scripts/weather-data.js','scripts/i18n.js','scripts/themes.js','scripts/widget-telemetry.js','scripts/quiz-telemetry.js','config/languages.json','config/panels.json','config/wording.json','i18n','weather.json','data','aiweather-capsule/latest.json','aiweather-capsule/capsules','widgets/quiz-public/daily.html','index.html','index_full.html','core-panel.html','provider-widget.html','widget.html','embed-demo.html','manifest.json','service-worker.js','icons-192.png','icons-512.png'])add(rel);
for(const rel of fs.readdirSync(source).filter(f=>/^weather-.*\.html$/.test(f)))add(rel);
for(const rel of fs.readdirSync(path.join(source,'controltowerai-wordpress-redesign')).filter(f=>f.endsWith('.html')&&!f.startsWith('Free ')))add('controltowerai-wordpress-redesign/'+rel);
add('controltowerai-wordpress-redesign/us-station-assets');
if(fs.existsSync(dest))throw Error('Snapshot already exists; never silently overwrite the baseline');
const inventory=[];
for(const rel of files){const bytes=fs.readFileSync(path.join(source,rel));const target=path.join(dest,rel);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);inventory.push({path:rel,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});}
fs.writeFileSync(path.resolve(__dirname,'../SOURCE-INVENTORY.json'),JSON.stringify({commit:'843847171588f0dd2fdd62074a6f997dfc2dfe45',note:'Includes explicitly selected uncommitted working files; see hashes.',files:inventory},null,2)+'\n');
console.log('Preserved',files.length,'public source files');
