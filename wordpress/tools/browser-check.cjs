const fs=require('fs'),path=require('path'),http=require('http'),assert=require('assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'test-results');fs.mkdirSync(out,{recursive:true});
function playwright(){const links=path.join(process.env.LOCALAPPDATA,'ms-playwright/.links');for(const f of fs.readdirSync(links)){try{return require(fs.readFileSync(path.join(links,f),'utf8').trim());}catch{}}throw Error('Playwright absent');}
const pw=playwright();
(async()=>{
 const browser=await pw.chromium.launch({headless:true});const context=await browser.newContext({viewport:{width:1440,height:1000}});
 await context.addCookies([{name:'playground_auto_login_already_happened',value:'1',url:'http://127.0.0.1:9400'}]);
 const blocked=[];await context.route('**/*',route=>{const u=new URL(route.request().url());if(['127.0.0.1','localhost'].includes(u.hostname))return route.continue();blocked.push({host:u.hostname,method:route.request().method()});return route.abort('blockedbyclient');});
 const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const results=[];
 for(const key of ['','today','how-it-works','stations','widgets','daily-brief','for-media','about','contact','us-station','quiz']){
  const start=errors.length;const response=await page.goto('http://127.0.0.1:9400/'+key+(key?'/':''),{waitUntil:'networkidle',timeout:60000});await page.waitForTimeout(500);
  results.push({page:key||'home',status:response.status(),title:await page.title(),unresolved:(await page.content()).includes('@@FIELD:'),h1:await page.locator('h1').allTextContents(),errors:errors.slice(start),horizontalOverflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1)});console.log('Checked',key||'home');
  if(['','today','widgets','us-station'].includes(key))await page.screenshot({path:path.join(out,(key||'home')+'-desktop.png'),fullPage:true});
 }
 await page.setViewportSize({width:390,height:844});
 for(const key of ['','today','how-it-works','stations','widgets','us-station','quiz']){await page.goto('http://127.0.0.1:9400/'+key+(key?'/':''),{waitUntil:'networkidle'});await page.screenshot({path:path.join(out,(key||'home')+'-mobile.png'),fullPage:true});results.push({page:key||'home',mobile:true,horizontalOverflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1)});}
 fs.writeFileSync(path.join(out,'browser.json'),JSON.stringify({results,blocked},null,2));console.log(JSON.stringify({results,blockedHosts:[...new Set(blocked.map(x=>x.host))]},null,2));await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
