const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const config=JSON.parse(fs.readFileSync(path.join(__dirname,'localConfig.json'),'utf8'));if(config.testCodePatch!==true)throw Error('Missing Documents patch-loading gate');
const dir=__dirname,out=path.join(dir,'build'),csc=path.join(process.env.WINDIR||'C:/Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
function run(exe,args){const r=cp.spawnSync(exe,args,{cwd:out,encoding:'utf8'});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.status!==0)throw Error('Test failed '+path.basename(exe));}
const core=path.join(dir,'../runtime-test');
run(csc,['/nologo','/codepage:65001','/unsafe','/optimize+','/nowarn:0169','/target:exe','/out:'+path.join(out,'MizzeRuntimeTest.exe'),'/reference:System.Web.Extensions.dll',...fs.readdirSync(core).filter(n=>n.endsWith('.cs')).map(n=>path.join(core,n)),path.join(dir,'RuntimeApis.cs'),path.join(dir,'RuntimeTest.cs')]);
run(path.join(out,'MizzeRuntimeTest.exe'),[path.join(dir,'dist/Assembly-CSharp-patch.bytes'),path.join(dir,'dist/methods.tsv')]);
const assert=require('node:assert/strict'),{inspect}=require('../inspect_patch.cjs');const p=inspect(fs.readFileSync(path.join(dir,'dist/Assembly-CSharp-patch.bytes')));
assert.deepEqual(p.fixes.map(f=>f.method.name).sort(),['get_UIModelRole','IsReallyInStealth','get_LastAimingInfoFromWeapon','OnGUI'].sort());
for(const e of p.externMethods)if(/UnityEngine\.(Mesh|Material|Shader|GL|Graphics|Font),/.test(e.owner)||/^(UICamera|UIWidget|UIPanel),/.test(e.owner)||e.name==='SetDefaultFont')throw Error('New render/touch/font dependency '+e.owner);
assert(p.fields.filter(f=>f.isNew).every(f=>f.name.startsWith('Mz')));
console.log('PASS: exactly four original hooks; old field descriptors; no mesh/global font/NGUI/FL hook dependencies.');

run(process.execPath,[path.join(dir,'verify-legacy-base.cjs')]);

const evidence=JSON.parse(fs.readFileSync(path.join(dir,'bindings-evidence.json'),'utf8'));for(const e of p.externMethods)if(!evidence.some(v=>v.method===e.name&&v.runtimeOwner===e.owner&&JSON.stringify(v.parameters)===JSON.stringify(e.parameters)))throw Error('Unverified extern '+e.owner+'.'+e.name);const hooks=JSON.parse(fs.readFileSync(path.join(dir,'hooks-evidence.json'),'utf8')).hooks;assert.equal(hooks.length,4);for(const f of p.fixes)assert(hooks.some(h=>h.owner===f.method.owner.split(',')[0]&&h.method===f.method.name&&h.vmMethod===f.id&&Number.isInteger(h.id)));console.log('PASS: every old-base extern and four native IDMAP hooks have dump evidence.');
