// Reuse the same Gutenberg checks against the fresh installation from the ZIP.
const fs=require('fs'),path=require('path'),Module=require('module');
const target=path.join(__dirname,process.argv[2]||'editor-check.cjs');
if(!['editor-check.cjs','editing-roundtrip.cjs','browser-check.cjs'].includes(path.basename(target)))throw Error('Unknown check');
const script=fs.readFileSync(target,'utf8').replaceAll('9400','9401').replaceAll("waitUntil:'networkidle'","waitUntil:'domcontentloaded'");const m=new Module(target,module);m.filename=target;m.paths=module.paths;m._compile(script,target);
