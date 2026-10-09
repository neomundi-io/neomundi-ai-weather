// Harness minimal : DOM stub + weather.json reel, pour verifier que
// protocol-volume.js remplit bien chaque cle avec la valeur mesuree.
const fs = require('fs');
const keys = ['longitudinal','daily','total','systems','panel-total'];
const nodes = keys.map(k => ({ _k:k, textContent:'FALLBACK',
  getAttribute(a){ return a==='data-awv2-vol' ? this._k : null; } }));
global.document = { querySelectorAll: () => { const a = nodes.slice(); a.length = nodes.length; return a; } };
global.window = {};
const data = JSON.parse(fs.readFileSync('weather.json','utf8').replace(/^\uFEFF/,''));
global.fetch = (url) => { console.log('  fetch ->', url); return Promise.resolve({ ok:true, json:()=>Promise.resolve(data) }); };
eval(fs.readFileSync('ai-weather-v2/assets/js/protocol-volume.js','utf8'));
setTimeout(() => {
  let bad = 0;
  const expect = { longitudinal:'7', daily:'3', total:'10', systems:'12', 'panel-total':'120' };
  nodes.forEach(n => {
    const ok = n.textContent === expect[n._k];
    if (!ok) bad++;
    console.log(`  ${ok?'[OK]  ':'[FAIL]'} ${n._k} = ${n.textContent} (attendu ${expect[n._k]})`);
  });
  console.log(bad ? `  ${bad} ecart(s)` : '  tous les denominateurs derivent de la mesure publiee');
  process.exit(bad ? 1 : 0);
}, 50);
