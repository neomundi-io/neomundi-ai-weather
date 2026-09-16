// Phase 1: generate public markup directly from the user's canonical HTML.
// Never read Gutenberg fields or the public source snapshot for page markup.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{JSDOM}=require('jsdom');
const base=path.resolve(__dirname,'..'),canonical=path.resolve(base,'../..'),theme=path.join(base,'theme/ai-weather');
const pages=['index','widgets','how-it-works','us-station','today','stations','daily-brief','for-media','about','contact'];
const selected=process.argv.includes('--home-widgets')?pages.slice(0,2):pages;
const routes=Object.fromEntries(pages.map(n=>[n,n==='index'?'home':n]));
function urls(s){return s.replace(/\.\.\/(assets|scripts|styles|config|i18n|data|aiweather-capsule|widgets)\//g,'@@RUNTIME@@/$1/').replace(/\.\.\/(weather\.json|index\.html|index_full\.html|core-panel\.html|embed-demo\.html)/g,'@@RUNTIME@@/$1').replace(/\.\/us-station-assets\//g,'@@THEME@@/assets/station/').replace(/https:\/\/weather\.controltowerai\.io\//g,'@@RUNTIME@@/');}
function write(p,s){fs.writeFileSync(path.join(theme,p),s);}
const proof=[];
for(const name of selected){
 const bytes=fs.readFileSync(path.join(canonical,name+'.html')),doc=new JSDOM(bytes.toString('utf8')).window.document,key=routes[name];
 // Resolve only page URLs, leaving the original text and translation attributes intact.
 for(const a of doc.querySelectorAll('a[href]')){const m=/^(index|today|widgets|how-it-works|us-station|stations|daily-brief|for-media|about|contact)\.html(.*)$/.exec(a.getAttribute('href'));if(m)a.setAttribute('href','@@PAGE:'+routes[m[1]]+'@@'+m[2]);}
 for(const [i,s] of [...doc.querySelectorAll('style')].entries()){write('assets/pages/'+key+'-'+i+'.css',s.textContent);s.remove();}
 for(const [i,s] of [...doc.querySelectorAll('script')].entries()){
  const src=s.getAttribute('src');if(!src)write('assets/pages/'+key+'-'+i+'.js.tpl',urls(s.textContent));
  else if(src.startsWith('./us-station-assets/'))write('assets/pages/'+key+'-'+i+'.js.tpl',urls(fs.readFileSync(path.join(canonical,src),'utf8')));
  s.remove();
 }
 const header=doc.querySelector('header.site-header,.station-topbar'),footer=doc.querySelector('footer');
 for(const [part,el] of [['header',header],['footer',footer]])if(el){write('template-parts/'+key+'-'+part+'.html',urls(el.outerHTML));el.replaceWith(doc.createTextNode('@@PART:'+key+'-'+part+'@@'));}
 write('templates/'+key+'.html',urls(doc.body.innerHTML));
 proof.push({page:key,file:name+'.html',sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
}
// Quiz has no standalone redesign page: use its existing dedicated composition,
// with fixed canonical labels and the unchanged public quiz component.
if(!process.argv.includes('--home-widgets')){
 const catalog=require('../theme/ai-weather/inc/catalog.json');let quiz=fs.readFileSync(path.join(theme,'templates/quiz.html'),'utf8');
 for(const f of catalog.quiz.fields)quiz=quiz.replaceAll('@@FIELD:'+f.key+'@@',f.value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;'));
 write('templates/quiz.html',quiz);
}
fs.mkdirSync(path.join(base,'test-results/canonical'),{recursive:true});fs.writeFileSync(path.join(base,'test-results/canonical/source-map.json'),JSON.stringify(proof,null,2));
console.log('Canonical HTML generated:',selected.join(', '));
require('./merge-media.cjs');
