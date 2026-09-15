const fs=require('fs'),path=require('path'),assert=require('assert/strict');let pw;
for(const f of fs.readdirSync(path.join(process.env.LOCALAPPDATA,'ms-playwright/.links'))){try{pw=require(fs.readFileSync(path.join(process.env.LOCALAPPDATA,'ms-playwright/.links',f),'utf8').trim());break;}catch{}}
const base='https://neomundi.cloud',root=path.resolve(__dirname,'..');
(async()=>{
const b=await pw.chromium.launch({headless:true}),c=await b.newContext({viewport:{width:390,height:844}}),p=await c.newPage(),results={languages:[],links:[],mobileMenu:false,marketing:[]};
await c.route('**/*',r=>['controltowerai.io','www.controltowerai.io','weather.controltowerai.io','localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname)?r.abort():r.continue());
try{
await p.goto(base+'/',{waitUntil:'domcontentloaded'});await p.locator('#nav-toggle').click();assert(await p.locator('#mobile-nav').evaluate(el=>el.classList.contains('open')));
await p.locator('#mobile-nav a[href="'+base+'/today/"]').click();await p.waitForURL(base+'/today/');results.mobileMenu=true;
await p.waitForFunction(()=>document.querySelectorAll('#wall-native [role=listitem]').length===12);
for(const lang of require('../source-public/config/languages.json').available){await p.locator('#lang-button').click();await p.locator('.lang-option[data-lang="'+lang.code+'"]').click();await p.waitForTimeout(400);const state=await p.evaluate(()=>({cards:document.querySelectorAll('#wall-native [role=listitem]').length,historyVisible:!document.querySelector('#history-content').hidden,direction:document.querySelector('#history-content').getAttribute('dir')}));assert.equal(state.cards,12);assert(state.historyVisible);if(lang.code==='ar')assert.equal(state.direction,'rtl');results.languages.push({lang:lang.code,...state});}
const links=new Set();
for(const key of ['','today','how-it-works','stations','widgets','quiz','daily-brief','for-media','about','contact','us-station']){
 await p.goto(base+'/'+key+(key?'/':''),{waitUntil:'domcontentloaded'});
 for(const url of await p.locator('a[href]').evaluateAll(els=>els.map(e=>e.href))){try{const u=new URL(url);if(u.origin===locationOrigin()&&!u.pathname.includes('wp-admin')&&!u.pathname.includes('wp-login')){u.hash='';links.add(u.href);}}catch{}}
 if(key==='')for(const lang of ['en','fr','es']){await p.locator('#lang-button').click();await p.locator('.lang-option[data-lang="'+lang+'"]').click();results.marketing.push({lang,h1:await p.locator('h1').innerText()});}
}
for(const url of links){const r=await c.request.get(url,{maxRedirects:0,timeout:30000});results.links.push({url,status:r.status(),redirect:r.headers().location});}
console.log(JSON.stringify({mobileMenu:results.mobileMenu,languages:results.languages.length,links:results.links.length,badLinks:results.links.filter(x=>x.status>=400),redirects:results.links.filter(x=>x.status>=300&&x.status<400)},null,2));
}finally{fs.writeFileSync(path.join(root,'test-results/live/navigation.json'),JSON.stringify(results,null,2));await b.close();}
function locationOrigin(){return base;}
})().catch(e=>{console.error(e);process.exitCode=1;});
