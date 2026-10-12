const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const dir=path.join(__dirname,'mizze-original'),current=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-hashes.json'))),baseline=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-baseline-hashes.json'))),contract=JSON.parse(fs.readFileSync(path.join(dir,'ui-compatibility-baseline.json')));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for(const file of current)assert.equal(hash(path.join(dir,file.name)),file.sha256,'Reviewed UI source changed: '+file.name);
const allowed=['Mizze.cs','MizzeAppearance.cs','RuntimeTest.cs','test.cjs'];
for(const file of baseline)if(!allowed.includes(file.name))assert.equal(hash(path.join(dir,file.name)),file.sha256,'Non-UI source changed: '+file.name);
function methods(text){const result=new Map(),re=/public (?:static )?\w+(?:\[\])? (\w+)\([^)]*\)\s*\{/g;let m;while((m=re.exec(text))){let end=re.lastIndex,depth=1;while(depth&&end<text.length){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++;}result.set(m[1],text.slice(m.index,end));re.lastIndex=end;}return result;}
for(const [file,original] of Object.entries(contract.originalSources)){const edited=methods(fs.readFileSync(path.join(dir,file),'utf8')),allowedMethods=file==='Mizze.cs'?['MzPanel','MzToggle']:['MzFontInit','MzTitle'];for(const [name,body] of methods(original))if(!allowedMethods.includes(name))assert.equal(edited.get(name),body,'Non-UI method changed: '+name);}
console.log('PASS: reviewed UI source; original bootstrap, OnGUI, gameplay, key, bindings and rendering preserved.');
