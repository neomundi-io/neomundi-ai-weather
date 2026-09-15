const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto'),vm=require('vm');
const root=path.resolve(__dirname,'..'),theme=path.join(root,'theme/ai-weather');
const rules=require('../EXCLUSIONS.json');const files=[];
function walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);assert(!e.isSymbolicLink(),'Symlink forbidden');if(e.isDirectory())walk(p);else files.push(p);}}walk(theme);
const inventory=[];
for(const p of files){const rel=path.relative(theme,p).replaceAll('\\','/');for(const pattern of rules.forbiddenPathPatterns)assert(!new RegExp(pattern,'i').test(rel),'Forbidden file: '+rel);assert(rules.allowedExtensions.includes(path.extname(p)),'Unknown file type '+rel);const bytes=fs.readFileSync(p);inventory.push({path:'ai-weather/'+rel,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
 if(!/\.(png|ico)$/.test(rel)){const text=bytes.toString('utf8');assert(!/-----BEGIN [^-]*PRIVATE KEY-----|\bsk-[A-Za-z0-9_-]{24,}|\bgh[pousr]_[A-Za-z0-9]{30,}|\bAKIA[A-Z0-9]{16}\b/.test(text),'Credential pattern: '+rel);assert(!/https?:\/\/(localhost|127\.0\.0\.1)|C:\\\\Users\\\\/.test(text),'Local path/url: '+rel);if(rel.endsWith('.json'))JSON.parse(text.replace(/^\uFEFF/,''));if(rel.endsWith('.js')||rel.endsWith('.js.tpl'))new vm.Script(text,{filename:rel});}
}
const catalog=require('../theme/ai-weather/inc/catalog.json');assert.equal(Object.keys(catalog).length,12);const keys=new Set();for(const schema of Object.values(catalog))for(const f of schema.fields){assert(!keys.has(f.key),'Duplicate field');keys.add(f.key);}
if(fs.readFileSync(path.join(theme,'style.css'),'utf8').includes('Version: 0.2.0')){
 for(const file of files.filter(f=>/[/\\](templates|template-parts)[/\\]/.test(f)))assert(!fs.readFileSync(file,'utf8').includes('@@FIELD:'),'Editorial placeholder in canonical public template: '+file);
 assert(!fs.readFileSync(path.join(theme,'index.php'),'utf8').includes('the_content('),'Public template must not output Gutenberg content');
}
const {JSDOM}=require('jsdom');for(const p of files.filter(p=>p.endsWith('.html')&&p.includes(path.sep+'runtime'+path.sep))){const html=fs.readFileSync(p,'utf8');assert(html.includes('</html>'),'Truncated HTML '+p);const d=new JSDOM(html).window.document;for(const script of d.querySelectorAll('script:not([src])'))new vm.Script(script.textContent,{filename:p});}
for(const p of files.filter(p=>p.endsWith('.html')&&!p.includes(path.sep+'runtime'+path.sep))){const text=fs.readFileSync(p,'utf8');for(const m of text.matchAll(/@@FIELD:([^@]+)@@/g))assert(keys.has(m[1]),'Unknown field '+m[1]);assert(!/<script[\s>]/i.test(text),'Script in editable template');}
for(const f of ['widget-telemetry.js','quiz-telemetry.js'])assert(fs.readFileSync(path.join(theme,'runtime/scripts',f)).equals(fs.readFileSync(path.join(root,'source-public/scripts',f))),'Telemetry changed');
assert(fs.readFileSync(path.join(theme,'runtime/widgets/quiz-public/daily.html')).equals(fs.readFileSync(path.join(root,'source-public/widgets/quiz-public/daily.html'))),'Public quiz changed');
for(const f of ['weather.json','data/current.json','data/capsule-index.json'])assert(fs.readFileSync(path.join(theme,'runtime',f)).equals(fs.readFileSync(path.join(root,'source-public',f))),'Measurement data changed');
const manifest=JSON.parse(fs.readFileSync(path.join(theme,'runtime/data/capsule-index.json')));for(const e of manifest.capsules)assert(fs.existsSync(path.resolve(theme,'runtime/data',e.path)),'Missing capsule '+e.path);
const sw=fs.readFileSync(path.join(theme,'runtime/service-worker.js'),'utf8');for(const m of sw.matchAll(/"(\.\/[^"?]+)"/g))assert(fs.existsSync(path.join(theme,'runtime',m[1])),'Missing service worker dependency '+m[1]);
const version=fs.readFileSync(path.join(theme,'style.css'),'utf8').match(/^Version:\s*(\S+)/m)[1];
fs.mkdirSync(path.join(root,'dist'),{recursive:true});inventory.sort((a,b)=>a.path.localeCompare(b.path));fs.writeFileSync(path.join(root,'dist/DEPLOYMENT-INVENTORY.json'),JSON.stringify({theme:'ai-weather',version,files:inventory,totalBytes:inventory.reduce((n,f)=>n+f.bytes,0)},null,2)+'\n');
console.log('PASS:',inventory.length,'allowlisted files; secrets/local URLs absent; scripts parse; telemetry + quiz + public measurements unchanged; all capsule/cache dependencies present.');
