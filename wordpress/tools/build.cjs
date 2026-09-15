const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {JSDOM}=require('jsdom');
const base=path.resolve(__dirname,'..'),src=path.join(base,'source-public'),out=path.join(base,'theme/ai-weather');
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
function write(rel,s){const f=path.join(out,rel);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,s);}
function copyDir(dir,rel){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())copyDir(f,rel+'/'+e.name);else if(!e.name.endsWith('.md'))write(rel+'/'+e.name,fs.readFileSync(f));}}
const pages=['index','today','how-it-works','stations','widgets','daily-brief','for-media','about','contact','us-station'];
const routes=Object.fromEntries(pages.map(p=>[p,p==='index'?'home':p]));
function urls(s){
 s=s.replace(/(?:\.\.\/)(assets|scripts|styles|config|i18n|data|aiweather-capsule|widgets)\//g,'@@RUNTIME@@/$1/').replace(/\.\.\/(weather\.json|index\.html|index_full\.html|core-panel\.html|embed-demo\.html)/g,'@@RUNTIME@@/$1');
 s=s.replace(/\.\/us-station-assets\//g,'@@THEME@@/assets/station/');
 s=s.replace(/https:\/\/weather\.controltowerai\.io\//g,'@@RUNTIME@@/');
 return s;
}
// Explicit public allowlist. No recursive copy of repository or runner.
for(const d of ['assets','styles','scripts','config','i18n','data','aiweather-capsule','widgets'])copyDir(path.join(src,d),'runtime/'+d);
for(const f of fs.readdirSync(src).filter(f=>f.endsWith('.html')||['weather.json','manifest.json','service-worker.js','icons-192.png','icons-512.png'].includes(f)))write('runtime/'+f,fs.readFileSync(path.join(src,f)));
write('runtime/LICENSE.md',fs.readFileSync(path.resolve(base,'../LICENSE')));
// The current hero widget is physically truncated mid-script. Restore only the
// missing tail from its last complete Git revision, preserving newer date logic.
const heroPath=path.join(out,'runtime/weather-home-1180.html');
if(!fs.readFileSync(heroPath,'utf8').includes('</html>')){
 let tail=fs.readFileSync(path.join(__dirname,'restored-home-tail.txt'),'utf8');
 tail=tail.replace('<div class="legend">${legendHtml}</div>','<div class="measured-date">${measuredDateText}</div>\n                <div class="legend">${legendHtml}</div>');
 fs.appendFileSync(heroPath,tail);
}
const stationDir=path.join(src,'controltowerai-wordpress-redesign/us-station-assets');
for(const f of fs.readdirSync(stationDir)){
 if(f.endsWith('.css'))write('assets/station/'+f,fs.readFileSync(path.join(stationDir,f)));
 // JavaScript is generated as URL-resolved script templates below. Remove only
 // redundant copies in this build-owned output directory, never source files.
 if(f.endsWith('.js')){const redundant=path.join(out,'assets/station',f);if(fs.existsSync(redundant))fs.unlinkSync(redundant);}
}
// Historic aliases remain functional; preserve query strings and semantic formats.
// topbar.html and sidebar.html restored from the last Git revisions before their deletion.
const schemas={}, shared={key:'shared',title:'Navigation et pied de page',fields:[]};
const sharedMap=new Map();
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const token=(k)=>'@@FIELD:'+k+'@@';
for(const name of pages){
 const doc=new JSDOM(fs.readFileSync(path.join(src,'controltowerai-wordpress-redesign',name+'.html'),'utf8')).window.document;
 const schema={key:routes[name],title:doc.title,description:doc.querySelector('meta[name=description]')?.content||'',bodyAttrs:[...doc.body.attributes].map(a=>[a.name,a.value]),fields:[],scripts:[],styles:[]};
 const add=(kind,value,label,scope,lang='')=>{
  const list=scope==='shared'?shared.fields:schema.fields;
  const identity=kind+'|'+lang+'|'+value;
  if(scope==='shared'&&sharedMap.has(identity))return sharedMap.get(identity);
  const key=(scope==='shared'?'shared':schema.key)+'-'+sha(identity+'|'+(scope==='shared'?'':list.length)).slice(0,12);
  list.push({key,kind,value,label:label.slice(0,110),lang});if(scope==='shared')sharedMap.set(identity,key);return key;
 };
 schema.seoTitle=add('text',schema.title,'SEO — titre','page');
 schema.seoDescription=add('text',schema.description,'SEO — description','page');
 // Keep dynamic measurement nodes and technical controls entirely owned by code.
 const protectedSelector='script,style,svg,canvas,iframe,code,pre,select,option,#wall-native,#history-content,#lang-menu,.us-observatory,.preview-wrap,.format-grid,.theme-grid';
 const dynamicIds=/^(stat-|obs-|hero-state|hist-|preview-|copy-|lang-|nav-toggle|wall-|modal-|machine-|city-|qz-)/;
 const nodes=[...doc.body.querySelectorAll('*')];
 for(const el of nodes){
  if(el.closest(protectedSelector)||dynamicIds.test(el.id))continue;
  const scope=el.closest('header.site-header,footer,.station-topbar')?'shared':'page';
  const section=el.closest('section')?.id||el.closest('section')?.className||scope;
  const label=section+' — '+el.tagName.toLowerCase()+' — '+el.textContent.trim().slice(0,55);
  const translations=[...el.attributes].filter(a=>/^data-(en|fr|es)$/.test(a.name));
  if(translations.length){
   for(const attr of translations){const lang=attr.name.slice(5);const key=add(/^H[1-6]$/.test(el.tagName)?'heading':'text',attr.value,label,scope,lang);el.setAttribute(attr.name,token(key));if(lang==='en')el.innerHTML=token(key);}
  }else if(el.childNodes.length&&[...el.childNodes].every(n=>n.nodeType===3)&&el.textContent.trim()&&/^(H[1-6]|P|SPAN|STRONG|EM|SMALL|LABEL|A|BUTTON|LI|SUMMARY|DT|DD)$/.test(el.tagName)){
   el.innerHTML=token(add(/^H[1-6]$/.test(el.tagName)?'heading':'text',el.textContent,label,scope));
  }
  if(el.tagName==='A'&&el.hasAttribute('href')&&!el.getAttribute('href').startsWith('javascript:')){
   let value=el.getAttribute('href');if(!value.includes('@@')){
    const m=/^(index|today|how-it-works|stations|widgets|daily-brief|for-media|about|contact|us-station)\.html(.*)$/.exec(value);
    value=m?'@@PAGE:'+routes[m[1]]+'@@'+m[2]:urls(value);
    el.setAttribute('href',token(add('url',value,'Lien — '+label,scope)));
   }
  }
  if(el.tagName==='IMG'){
   el.setAttribute('src',token(add('image',urls(el.getAttribute('src')||''),'Image — '+(el.alt||label),scope)));
   if(el.hasAttribute('alt'))el.setAttribute('alt',token(add('text',el.alt,'Alternative image — '+label,scope)));
  }
  for(const attr of [...el.attributes].filter(a=>/^(placeholder|data-(en|fr|es)-placeholder)$/.test(a.name)))el.setAttribute(attr.name,token(add('text',attr.value,'Champ — '+label,scope)));
  // Mixed prose (paragraphs with links/emphasis, brand text) keeps its original tags.
  for(const node of [...el.childNodes])if(node.nodeType===3&&node.textContent.trim()&&!node.textContent.includes('@@FIELD:')&&/^(H[1-6]|P|SPAN|STRONG|EM|SMALL|LABEL|A|BUTTON|LI|SUMMARY|DT|DD)$/.test(el.tagName))node.textContent=token(add('text',node.textContent,label+' — fragment',scope));
 }
 // Extract original styles and script order; no scripts are saved in post_content.
 for(const [i,el] of [...doc.querySelectorAll('style')].entries()){const rel='assets/pages/'+schema.key+'-'+i+'.css';write(rel,el.textContent);schema.styles.push(rel);el.remove();}
 for(const el of [...doc.querySelectorAll('link[rel=stylesheet]')])schema.styles.push(urls(el.getAttribute('href')));
 for(const [i,el] of [...doc.querySelectorAll('script')].entries()){
  if(el.src){
   const ref=el.getAttribute('src');
   if(ref.startsWith('./us-station-assets/')){const rel='assets/pages/'+schema.key+'-'+i+'.js.tpl';write(rel,urls(fs.readFileSync(path.join(src,'controltowerai-wordpress-redesign',ref),'utf8')));schema.scripts.push({file:rel});}
   else schema.scripts.push({src:urls(ref)});
  }
  else {const rel='assets/pages/'+schema.key+'-'+i+'.js.tpl';write(rel,urls(el.textContent));schema.scripts.push({file:rel});}
  el.remove();
 }
 const header=doc.body.querySelector('header.site-header,.station-topbar');
 const footer=doc.body.querySelector('footer');
 for(const [kind,el] of [['header',header],['footer',footer]])if(el){write('template-parts/'+schema.key+'-'+kind+'.html',urls(el.outerHTML));el.replaceWith(doc.createTextNode('@@PART:'+schema.key+'-'+kind+'@@'));}
 write('templates/'+schema.key+'.html',urls(doc.body.innerHTML));schemas[schema.key]=schema;
}
// Dedicated quiz destination uses exactly the same public widget as Home/Today.
const home=schemas.home;const quiz={...home,key:'quiz',title:'Spot the Drift · AI Weather',description:'Seven questions about AI behavior.',fields:[],scripts:home.scripts,styles:home.styles};
quiz.seoTitle='quiz-title';quiz.seoDescription='quiz-description';quiz.fields=[{key:'quiz-title',kind:'text',value:quiz.title,label:'SEO — titre'},{key:'quiz-description',kind:'text',value:quiz.description,label:'SEO — description'},{key:'quiz-heading',kind:'text',value:'Spot the Drift',label:'Titre de la page'}];
write('templates/quiz.html','@@PART:home-header@@<main class="wrap" style="padding-top:120px;padding-bottom:60px"><h1>@@FIELD:quiz-heading@@</h1><div class="quiz-frame"><iframe id="iframe-quiz-daily" data-src="@@RUNTIME@@/widgets/quiz-public/daily.html" src="@@RUNTIME@@/widgets/quiz-public/daily.html?theme=dark&amp;lang=en" title="Spot the Drift" scrolling="no"></iframe></div></main>@@PART:home-footer@@');schemas.quiz=quiz;
schemas.shared=shared;
write('inc/catalog.json',JSON.stringify(schemas,null,2)+'\n');
// Standalone assets retain measurement and telemetry code. A bridge only localizes CTA navigation.
write('runtime/scripts/site-bridge.js',`(function(){var q=new URLSearchParams(location.search),s=q.get('site');if(!s)return;try{var u=new URL(s);if(u.origin!==location.origin)return;}catch(e){return;}function fix(){document.querySelectorAll('a[href]').forEach(function(a){var h=a.getAttribute('href');if(h==='https://controltowerai.io/'||h==='https://controltowerai.io/ai-weather/')a.href=s+(h.endsWith('/ai-weather/')?'today/':'');});}new MutationObserver(fix).observe(document.documentElement,{childList:true,subtree:true});fix();})();`);
for(const f of fs.readdirSync(path.join(out,'runtime')).filter(f=>f.endsWith('.html'))){const dest=path.join(out,'runtime',f);fs.writeFileSync(dest,fs.readFileSync(dest,'utf8').replace('</body>','<script src="./scripts/site-bridge.js"></script></body>'));}
// Empty registered handle for inline page scripts, and bridge for same-origin iframe configuration.
write('assets/page.js','/* Page scripts are enqueued from versioned, code-owned templates. */\n');
console.log('Generated',Object.keys(schemas).length-1,'pages;',Object.values(schemas).reduce((n,s)=>n+s.fields.length,0),'editable fields');
