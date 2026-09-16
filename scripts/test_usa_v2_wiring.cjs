const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),context={window:{}};
vm.runInNewContext(fs.readFileSync(path.join(root,'scripts/weather-data.js'),'utf8'),context);
const api=context.window.NMData,html=fs.readFileSync(path.join(root,'weather-bar-us-320.html'),'utf8');
// Execute the actual cell template expression, not a mirrored rendering rule.
const cell=html.match(/<a class="cell is-\$\{([^}]+)\}"/);
assert(cell,'USA cell template found');
const render=vm.compileFunction('return '+cell[1],['system','displayCondition']);
const cases=[['standard','clear'],['attention_accrue','watch'],['attention_renforcee','unsettled'],['attention_critique','alert'],['insufficient_data','insufficient'],['baseline_window','insufficient']];
let count=0;
for(const [state,expected] of cases)for(const daily of ['clear','watch','unsettled','alert']){
 const system={condition:daily,longitudinal:{current_longitudinal_state:{state}}};
 const display=api.getDisplayCondition(system,'2026-09-17');
 assert.equal(display,expected);assert.equal(render(system,display),expected);
 assert(html.includes('.cell.is-'+expected),'CSS exists for '+expected);count++;
}
for(const condition of ['clear','watch','unsettled','alert']){
 const system={condition};assert.equal(render(system,api.getDisplayCondition(system)),condition);count++;
}
console.log('PASS: '+count+' USA longitudinal/legacy rendering cases.');
