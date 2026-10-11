// Validate generated extern descriptors against the supplied declaration dump.
const fs=require('node:fs'),path=require('node:path');const {inspect}=require('../inspect_patch.cjs');
const p=inspect(fs.readFileSync(path.join(__dirname,'dist/Assembly-CSharp-patch.bytes'))),root=process.argv[2];
const aliases={'System.Single':'float','System.Double':'double','System.Boolean':'bool','System.Int32':'int','System.UInt32':'uint','System.Int64':'long','System.Byte':'byte','System.String':'string','System.Char':'char','System.Object':'object','System.Type':'Type'};
function bare(t){return t.split(',')[0].replace(/\+/g,'.');}
function short(t){t=bare(t);if(t.endsWith('&'))return short(t.slice(0,-1))+'&';if(t.endsWith('[]'))return short(t.slice(0,-2))+'[]';return aliases[t]||t.slice(t.lastIndexOf('.')+1);}
const files=new Map(),evidence=[],errors=[];
for(const e of p.externMethods){
 const asm=e.owner.match(/, ([^,]+), Version=/)[1];if(!files.has(asm))files.set(asm,fs.readFileSync(path.join(root,asm+'.dll.cs'),'utf8'));
 const text=files.get(asm),owner=bare(e.owner).replace(/`1.*$/,'<T>'),ns=owner.includes('.')?owner.slice(0,owner.lastIndexOf('.')):'',name=owner.slice(owner.lastIndexOf('.')+1);
 const chunks=text.split('// Namespace: ');let chunk=chunks.find(c=>c.startsWith(ns+'\n')&&new RegExp('(?:class|struct|interface|enum) '+name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?: :| //|\\s*\\n)').test(c));
 // The restored native stealth body uses these exact existing AOT generic types.
 const stealthGeneric=/^System\.Collections\.Generic\.(Dictionary`2(?:\+Enumerator)?|KeyValuePair`2)\[\[System\.UInt32, mscorlib, [^\]]+\],\[COW\.GamePlay\.FHAPNJGMHLM, Assembly-CSharp, [^\]]+\]\], mscorlib, /.exec(e.owner);
 if(stealthGeneric){
  const kind=stealthGeneric[1];
  if(kind==='Dictionary`2+Enumerator')chunk=chunks.find(c=>c.startsWith('\npublic struct Enumerator : IEnumerator<KeyValuePair<TKey, TValue>>')&&c.includes('private Dictionary<TKey, TValue> _dictionary;'));
  else chunk=chunks.find(c=>c.startsWith('System.Collections.Generic\n')&&c.includes((kind==='Dictionary`2'?'public class Dictionary':'public struct KeyValuePair')+'<T1, T2>'));
 }
 if(!chunk){errors.push('Missing owner '+e.owner);continue;}
 const candidates=chunk.split('\n').map(l=>l.trim()).filter(l=>l.includes(' '+e.name+'(')&&l.includes('('));
 const hit=candidates.find(l=>{const ps=l.slice(l.indexOf('(')+1,l.lastIndexOf(')')).trim();const a=ps?ps.split(',').map(q=>q.trim().replace(/\s+\w+(?:\s*=.*)?$/,'').replace(/^(?:ref|out) /,'').replace(/\?$/,'')):[];return a.length===e.parameters.length&&a.every((q,i)=>q===short(e.parameters[i]).replace(/&$/,'')||(q==='object'&&bare(e.parameters[i])==='UnityEngine.Object'));});
 if(!hit){errors.push('Missing signature '+bare(e.owner)+'.'+e.name+'('+e.parameters.map(short).join(',')+') candidates '+candidates.join('; '));continue;}
 evidence.push({assembly:asm,owner:bare(e.owner),runtimeOwner:e.owner,method:e.name,parameters:e.parameters,declaration:hit});
}
for(const f of p.fields.filter(f=>!f.isNew)){
 const asm=f.owner.match(/, ([^,]+), Version=/)[1];if(!files.has(asm))files.set(asm,fs.readFileSync(path.join(root,asm+'.dll.cs'),'utf8'));const text=files.get(asm),owner=bare(f.owner),ns=owner.includes('.')?owner.slice(0,owner.lastIndexOf('.')):'',name=owner.slice(owner.lastIndexOf('.')+1);
 const chunk=text.split('// Namespace: ').find(c=>c.startsWith(ns+'\n')&&new RegExp('(?:class|struct) '+name+'(?: :| //)').test(c));const line=chunk&&chunk.split('\n').find(l=>l.includes(' '+f.name+';'));
 if(!line)errors.push('Missing field '+owner+'.'+f.name);else evidence.push({assembly:asm,owner,field:f.name,declaration:line.trim()});
}
if(errors.length){console.error(errors.join('\n'));process.exit(1);}fs.writeFileSync(path.join(__dirname,'bindings-evidence.json'),JSON.stringify(evidence,null,2)+'\n');console.log('PASS: '+evidence.length+' extern/field declarations match TH iOS dump.');

// Patch targets also need their native IFix IDMAP slot; declaration resolution alone is insufficient.
const game=files.get('Assembly-CSharp')||fs.readFileSync(path.join(root,'Assembly-CSharp.dll.cs'),'utf8');
const mapChunks=game.split('// Namespace: ').filter(c=>c.startsWith('IFix\n')&&/enum IDMAP\d+\b/.test(c.slice(0,500)));
const hooks=p.fixes.map(f=>{const owner=bare(f.method.owner),key=owner.replace(/[.+]/g,'-')+'-'+f.method.name+'0';let slot=null;for(const chunk of mapChunks){const line=chunk.split('\n').find(l=>l.includes(' '+key+' = '));if(line){slot={map:chunk.match(/enum (IDMAP\d+)/)[1],id:Number(line.match(/ = (\d+);/)[1]),declaration:line.trim()};break;}}if(!slot)throw Error('Missing native IFix slot: '+key);const ns=owner.slice(0,owner.lastIndexOf('.')),name=owner.slice(owner.lastIndexOf('.')+1),chunk=game.split('// Namespace: ').find(c=>c.startsWith(ns+'\n')&&new RegExp('class '+name+'(?: :| //)').test(c));const lines=chunk.split('\n'),idx=lines.findIndex(l=>l.includes(' '+f.method.name+'('));if(idx<0)throw Error('Missing patch target declaration: '+owner+'.'+f.method.name);return{owner,method:f.method.name,vmMethod:f.id,...slot,native:lines.slice(Math.max(0,idx-2),idx+1).join('\n').trim()};});
fs.writeFileSync(path.join(__dirname,'hooks-evidence.json'),JSON.stringify({target:'Free Fire TH iOS 1.132.1',deviceVerified:false,hooks},null,2)+'\n');console.log('PASS: '+hooks.length+' patch targets have native IFix IDMAP slots.');
