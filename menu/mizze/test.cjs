const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const config=JSON.parse(fs.readFileSync(path.join(__dirname,'localConfig.json'),'utf8'));if(config.testCodePatch!==true)throw Error('Missing Documents patch-loading gate');
const dir=__dirname,out=path.join(dir,'build'),csc=path.join(process.env.WINDIR||'C:/Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
function run(exe,args){const r=cp.spawnSync(exe,args,{cwd:out,encoding:'utf8'});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.status!==0)throw Error('Test failed '+path.basename(exe));}
const core=path.join(dir,'../runtime-test');
run(csc,['/nologo','/codepage:65001','/unsafe','/optimize+','/nowarn:0169','/target:exe','/out:'+path.join(out,'MizzeRuntimeTest.exe'),'/reference:System.Web.Extensions.dll',...fs.readdirSync(core).filter(n=>n.endsWith('.cs')).map(n=>path.join(core,n)),path.join(dir,'RuntimeApis.cs'),path.join(dir,'RuntimeTest.cs')]);
run(path.join(out,'MizzeRuntimeTest.exe'),[path.join(dir,'dist/Assembly-CSharp-patch.bytes'),path.join(dir,'dist/methods.tsv')]);
const {inspect}=require('../inspect_patch.cjs');const p=inspect(fs.readFileSync(path.join(dir,'dist/Assembly-CSharp-patch.bytes')));const evidence=JSON.parse(fs.readFileSync(path.join(dir,'bindings-evidence.json')));
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'dist/manifest.json')));
if(manifest.stateMode!=='legacy-field-names'||manifest.stateNamespace!==''||p.fields.some(f=>f.isNew&&!f.name.startsWith('Mz')))throw Error('Old-source field format not preserved');
const expectedFixes=['get_UIModelRole','get_LastAimingInfoFromWeapon','OnGUI','IsReallyInStealth','NeedRunHighFrame','get_IsBeingCarried','UpdateKnockdownIsInCamera'].sort();
if(JSON.stringify(p.fixes.map(f=>f.method.name).sort())!==JSON.stringify(expectedFixes))throw Error('Unexpected patch hook');
if(p.fields.some(f=>!f.isNew&&f.name==='wrapperArray')||p.externMethods.some(e=>/MUDPSession|UDPSession|WrappersManagerImpl/.test(e.owner)))throw Error('Lag must not mutate transport or shared IFix dispatch');
console.log('PASS: VM fields use the working old-source names; process restart is required when replacing bytes.');
const blocked=['UnityEngine.Mesh','UnityEngine.Material','UnityEngine.Shader','UnityEngine.GL','UnityEngine.Graphics','UnityEngine.Font'];
for(const e of p.externMethods)if(blocked.includes(e.owner.split(',')[0])||(e.owner.split(',')[0]==='UnityEngine.GUIStyle'&&e.name==='SetDefaultFont'))throw Error('Unsafe shared renderer/font API in final patch: '+e.owner+'.'+e.name);
console.log('PASS: final bytes contain no Mesh/Material/Shader/GL/Graphics/OS-font/default-font native calls.');
for(const e of p.externMethods)if(!evidence.some(v=>v.method===e.name&&v.runtimeOwner===e.owner&&JSON.stringify(v.parameters)===JSON.stringify(e.parameters)))throw Error('New unverified extern '+e.owner+'.'+e.name);
console.log('PASS: all generated extern descriptors are covered by checked TH iOS declarations.');

const hooks=JSON.parse(fs.readFileSync(path.join(dir,'hooks-evidence.json'),'utf8')).hooks;
if(hooks.length!==p.fixes.length||p.fixes.some(f=>!hooks.some(h=>h.owner===f.method.owner.split(',')[0]&&h.method===f.method.name&&h.vmMethod===f.id&&Number.isInteger(h.id))))throw Error('Patch target lacks matching native IDMAP evidence');
if(p.types.some(t=>/^(COW\.COWGameEntry|GCommon\.GameEngine|UnityEngine\.Behaviour|UnityEngine\.MonoBehaviour),/.test(t))||p.externMethods.some(e=>e.owner.startsWith('UnityEngine.GUI,')&&/^(get|set)_enabled$/.test(e.name)))throw Error('R2-R4 runtime dependency reintroduced');
console.log('PASS: old-source recovery retains seven verified hooks; no Behaviour/entry/GUI.enabled dependencies.');

run(process.execPath,[path.join(dir,'verify-compatibility.cjs')]);

const sourceReview=JSON.parse(fs.readFileSync(path.join(dir,'old-source-review.json'),'utf8'));
for(const hook of sourceReview.oldHooks){const [owner,name]=hook.split('.');if(!p.fixes.some(f=>f.method.owner.split(',')[0].endsWith('.'+owner)&&f.method.name===name))throw Error('Old source hook missing: '+hook);}
console.log('PASS: all four entry points recorded from actual source cũ are restored.');

if(p.externMethods.some(e=>/^System\.Collections\.Generic\.(Dictionary|KeyValuePair)/.test(e.owner)))throw Error('New AOT generic enumeration extern introduced');
const collectors=p.externMethods.filter(e=>e.owner.startsWith('COW.GcUtil,'));if(collectors.length!==1||collectors[0].name!=='Collect'||collectors[0].parameters[0].split(',')[0]!=='ManualGCReason')throw Error('Unexpected collector dependency');
console.log('PASS: only existing native game collector is used; no generic Dictionary/Enumerator/KeyValuePair externs.');

run(process.execPath,[path.join(dir,'verify-legacy-base.cjs')]);
