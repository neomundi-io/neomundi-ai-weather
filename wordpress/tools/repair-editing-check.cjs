const fs=require('fs'),Module=require('module'),path=require('path');
const file=path.resolve(__dirname,'editing-roundtrip.cjs');
const script=fs.readFileSync(file,'utf8').replaceAll('9400','9402').replaceAll("waitUntil:'networkidle'","waitUntil:'domcontentloaded'");
const m=new Module(file,module);m.filename=file;m.paths=module.paths;m._compile(script,file);
