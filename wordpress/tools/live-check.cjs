const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'test-results','live');fs.mkdirSync(out,{recursive:true});
let pw;for(const f of fs.readdirSync(path.join(process.env.LOCALAPPDATA,'ms-playwright/.links'))){try{pw=require(fs.readFileSync(path.join(process.env.LOCALAPPDATA,'ms-playwright/.links',f),'utf8').trim());break;}catch{}}
const base='https://neomundi.cloud',runtime=base+'/wp-content/themes/ai-weather/runtime/';
(async()=>{
 const browser=await pw.chromium.launch({headless:true});
 const c=await browser.newContext({viewport:{width:1440,height:1000}});
 const report={started:new Date().toISOString(),pages:[],resources:[],failures:[],console:[],errors:[],telemetry:[],quizzes:[]};let current='';
 await c.route('**/*',r=>{const u=new URL(r.request().url());if(['controltowerai.io','www.controltowerai.io','weather.controltowerai.io','localhost','127.0.0.1'].includes(u.hostname))return r.abort('blockedbyclient');return r.continue();});
 c.on('request',r=>{if(r.url().includes('api.controltowerai.io'))report.telemetry.push({event:'request',page:current,url:r.url(),method:r.method(),body:r.postData()});});
 c.on('response',async r=>{const u=r.url();if(u.includes('api.controltowerai.io'))report.telemetry.push({event:'response',page:current,url:u,status:r.status(),headers:await r.allHeaders()});if(r.status()>=400)report.resources.push({page:current,url:u,status:r.status()});});
 c.on('requestfailed',r=>report.failures.push({page:current,url:r.url(),error:r.failure()?.errorText}));
 const p=await c.newPage();p.on('pageerror',e=>report.errors.push({page:current,message:e.message}));p.on('console',m=>{if(['error','warning'].includes(m.type()))report.console.push({page:current,type:m.type(),text:m.text()});});
 const save=()=>fs.writeFileSync(path.join(out,'live.json'),JSON.stringify(report,null,2));
 try{
 for(const mobile of [false,true]){
 await p.setViewportSize(mobile?{width:390,height:844}:{width:1440,height:1000});
 for(const key of ['','today','how-it-works','stations','widgets','quiz','daily-brief','for-media','about','contact','us-station']){
 current=(key||'home')+(mobile?' mobile':' desktop');
 const r=await p.goto(base+'/'+key+(key?'/':''),{waitUntil:'domcontentloaded',timeout:60000});await p.waitForTimeout(2500);
 const item=await p.evaluate(()=>({title:document.title,h1:[...document.querySelectorAll('h1')].map(x=>x.innerText),overflow:document.documentElement.scrollWidth>innerWidth+1,description:document.querySelector('meta[name=description]')?.content,robots:document.querySelector('meta[name=robots]')?.content,unresolved:document.documentElement.innerHTML.includes('@@FIELD:'),localLinks:[...document.querySelectorAll('[href],[src]')].map(x=>x.getAttribute('href')||x.getAttribute('src')).filter(x=>/localhost|127\.0\.0\.1/.test(x)),cards:document.querySelectorAll('#wall-native [role=listitem]').length,historyHidden:document.querySelector('#history-content')?.hidden}));
 report.pages.push({page:current,status:r.status(),url:p.url(),...item});
 if(['','today','widgets','quiz','us-station'].includes(key))await p.screenshot({path:path.join(out,(key||'home')+(mobile?'-mobile':'-desktop')+'.png'),fullPage:true});
 console.log(current,r.status(),p.url(),'overflow='+item.overflow);save();
 }
 }
 for(const file of fs.readdirSync(path.join(root,'theme/ai-weather/runtime')).filter(x=>x.endsWith('.html'))){
 current='runtime/'+file;const r=await p.goto(runtime+file+'?site='+encodeURIComponent(base+'/'),{referer:base+'/',waitUntil:'domcontentloaded',timeout:60000});await p.waitForTimeout(1700);
 report.pages.push({page:current,status:r.status(),loading:/^\s*Loading[….]*\s*$/i.test(await p.locator('body').innerText())});console.log(current,r.status());save();
 }
 for(const lang of ['en','fr','es']){
 current='quiz-complete-'+lang;await p.goto(runtime+'widgets/quiz-public/daily.html?lang='+lang,{waitUntil:'domcontentloaded'});
 await p.locator('#qz-start').click();for(let i=0;i<7;i++){await p.locator('.qz-screen.active .qz-option').first().click();await p.locator('.qz-screen.active .qz-next').click();}
 report.quizzes.push({lang,completed:await p.locator('[data-screen=final]').isVisible()});save();console.log(current,'completed');
 }
 }finally{save();await browser.close();}
 console.log(JSON.stringify({pages:report.pages.length,errors:report.errors,quizzes:report.quizzes,telemetryResponses:report.telemetry.filter(x=>x.event==='response').map(x=>x.status),resourceErrors:report.resources.length,failedRequests:report.failures.length},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
