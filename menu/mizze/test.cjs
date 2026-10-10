const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const dir=__dirname,out=path.join(dir,'build'),csc=path.join(process.env.WINDIR||'C:/Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
function run(exe,args){const r=cp.spawnSync(exe,args,{cwd:out,encoding:'utf8'});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.status!==0)throw Error('Test failed '+path.basename(exe));}
const core=path.join(dir,'../runtime-test');
run(csc,['/nologo','/codepage:65001','/unsafe','/optimize+','/nowarn:0169','/target:exe','/out:'+path.join(out,'MizzeRuntimeTest.exe'),'/reference:System.Web.Extensions.dll',...fs.readdirSync(core).filter(n=>n.endsWith('.cs')).map(n=>path.join(core,n)),path.join(dir,'RuntimeApis.cs'),path.join(dir,'RuntimeTest.cs')]);
run(path.join(out,'MizzeRuntimeTest.exe'),[path.join(dir,'dist/Assembly-CSharp-patch.bytes'),path.join(dir,'dist/methods.tsv')]);
const {inspect}=require('../inspect_patch.cjs');const p=inspect(fs.readFileSync(path.join(dir,'dist/Assembly-CSharp-patch.bytes')));const evidence=JSON.parse(fs.readFileSync(path.join(dir,'bindings-evidence.json')));
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'dist/manifest.json')));
if(!/^Mizze_[0-9a-f]{16}_$/.test(manifest.stateNamespace)||p.fields.some(f=>f.isNew&&!f.name.startsWith(manifest.stateNamespace)))throw Error('Unscoped or mixed new fields');
if(p.fixes.length!==3||p.fixes.some(f=>f.method.name==='IsReallyInStealth'))throw Error('Unexpected stealth hook');
console.log('PASS: every VM-owned field is isolated by source revision; no stealth hook.');
const blocked=['UnityEngine.Mesh','UnityEngine.Material','UnityEngine.Shader','UnityEngine.GL','UnityEngine.Graphics','UnityEngine.Font'];
for(const e of p.externMethods)if(blocked.includes(e.owner.split(',')[0])||(e.owner.split(',')[0]==='UnityEngine.GUIStyle'&&e.name==='SetDefaultFont'))throw Error('Unsafe shared renderer/font API in final patch: '+e.owner+'.'+e.name);
console.log('PASS: final bytes contain no Mesh/Material/Shader/GL/Graphics/OS-font/default-font native calls.');
for(const e of p.externMethods)if(!evidence.some(v=>v.method===e.name&&v.owner===e.owner.split(',')[0].replace(/\+/g,'.')&&JSON.stringify(v.parameters)===JSON.stringify(e.parameters)))throw Error('New unverified extern '+e.owner+'.'+e.name);
console.log('PASS: all generated extern descriptors are covered by checked TH iOS declarations.');
