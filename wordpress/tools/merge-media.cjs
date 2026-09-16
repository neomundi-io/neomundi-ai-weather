// Repeatable, narrowly scoped adaptation after canonical HTML extraction.
const fs=require('fs'),path=require('path'),{JSDOM}=require('jsdom');const theme=path.resolve(__dirname,'../theme/ai-weather');
for(const dir of ['templates','template-parts'])for(const file of fs.readdirSync(path.join(theme,dir)).filter(f=>f.endsWith('.html'))){const dest=path.join(theme,dir,file);let html=fs.readFileSync(dest,'utf8');
 html=html.replace(/<div class="footer-col">\s*<h4([^>]*)>Company<\/h4>[\s\S]*?<\/div>/g,(_,attrs)=>'<div class="footer-col">\n<h4'+attrs+'>Company</h4>\n'+[['NeoMundi.org','https://neomundi.org'],['NeoMundi.io','https://neomundi.io'],['ControlTower API','https://controltower.neomundi.io']].map(([label,url])=>'<a href="'+url+'" target="_blank" rel="noopener noreferrer">'+label+'</a>').join('\n')+'\n</div>');
 html=html.replaceAll('@@PAGE:for-media@@','@@PAGE:how-it-works@@#for-readers');
 if(file==='contact.html'){const doc=new JSDOM(html).window.document;for(const a of doc.querySelectorAll('a[href$="#for-readers"]')){a.textContent='How It Works →';a.setAttribute('data-en','How It Works →');a.setAttribute('data-fr','Comprendre la méthode →');const p=a.previousElementSibling;if(p?.tagName==='P'){const en='How It Works brings together the methodology, context and reusable resources for journalists, researchers and curious readers.',fr='How It Works rassemble la méthode, le contexte et les ressources réutilisables pour les journalistes, chercheurs et curieux.';p.textContent=en;p.setAttribute('data-en',en);p.setAttribute('data-fr',fr);}}html=doc.body.innerHTML;}
 if(file==='how-it-works.html'&&!html.includes('@@READERS@@'))html=html.replace('@@PART:how-it-works-footer@@','@@READERS@@\n@@PART:how-it-works-footer@@');
 fs.writeFileSync(dest,html);
}
