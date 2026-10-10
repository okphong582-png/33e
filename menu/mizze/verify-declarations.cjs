// Validate generated extern descriptors against the supplied declaration dump.
const fs=require('node:fs'),path=require('node:path');const {inspect}=require('../inspect_patch.cjs');
const p=inspect(fs.readFileSync(path.join(__dirname,'dist/Assembly-CSharp-patch.bytes'))),root=process.argv[2];
const aliases={'System.Single':'float','System.Double':'double','System.Boolean':'bool','System.Int32':'int','System.Int64':'long','System.Byte':'byte','System.String':'string','System.Char':'char','System.Object':'object','System.Type':'Type'};
function bare(t){return t.split(',')[0].replace(/\+/g,'.');}
function short(t){t=bare(t);if(t.endsWith('&'))return short(t.slice(0,-1))+'&';if(t.endsWith('[]'))return short(t.slice(0,-2))+'[]';return aliases[t]||t.slice(t.lastIndexOf('.')+1);}
const files=new Map(),evidence=[],errors=[];
for(const e of p.externMethods){
 const asm=e.owner.match(/, ([^,]+), Version=/)[1];if(!files.has(asm))files.set(asm,fs.readFileSync(path.join(root,asm+'.dll.cs'),'utf8'));
 const text=files.get(asm),owner=bare(e.owner).replace(/`1.*$/,'<T>'),ns=owner.slice(0,owner.lastIndexOf('.')),name=owner.slice(owner.lastIndexOf('.')+1);
 const chunks=text.split('// Namespace: ');const chunk=chunks.find(c=>c.startsWith(ns+'\n')&&new RegExp('(?:class|struct|interface|enum) '+name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?: :| //|\\s*\\n)').test(c));
 // Nested types do not appear as extern owners in this patch.
 if(!chunk){errors.push('Missing owner '+e.owner);continue;}
 const candidates=chunk.split('\n').map(l=>l.trim()).filter(l=>l.includes(' '+e.name+'(')&&l.includes('('));
 const hit=candidates.find(l=>{const ps=l.slice(l.indexOf('(')+1,l.lastIndexOf(')')).trim();const a=ps?ps.split(',').map(q=>q.trim().replace(/\s+\w+(?:\s*=.*)?$/,'').replace(/^(?:ref|out) /,'').replace(/\?$/,'')):[];return a.length===e.parameters.length&&a.every((q,i)=>q===short(e.parameters[i]).replace(/&$/,'')||(q==='object'&&bare(e.parameters[i])==='UnityEngine.Object'));});
 if(!hit){errors.push('Missing signature '+bare(e.owner)+'.'+e.name+'('+e.parameters.map(short).join(',')+') candidates '+candidates.join('; '));continue;}
 evidence.push({assembly:asm,owner:bare(e.owner),method:e.name,parameters:e.parameters,declaration:hit});
}
for(const f of p.fields.filter(f=>!f.isNew)){
 const asm=f.owner.match(/, ([^,]+), Version=/)[1];if(!files.has(asm))files.set(asm,fs.readFileSync(path.join(root,asm+'.dll.cs'),'utf8'));const text=files.get(asm),owner=bare(f.owner),ns=owner.slice(0,owner.lastIndexOf('.')),name=owner.slice(owner.lastIndexOf('.')+1);
 const chunk=text.split('// Namespace: ').find(c=>c.startsWith(ns+'\n')&&new RegExp('(?:class|struct) '+name+'(?: :| //)').test(c));const line=chunk&&chunk.split('\n').find(l=>l.includes(' '+f.name+';'));
 if(!line)errors.push('Missing field '+owner+'.'+f.name);else evidence.push({assembly:asm,owner,field:f.name,declaration:line.trim()});
}
if(errors.length){console.error(errors.join('\n'));process.exit(1);}fs.writeFileSync(path.join(__dirname,'bindings-evidence.json'),JSON.stringify(evidence,null,2)+'\n');console.log('PASS: '+evidence.length+' extern/field declarations match TH iOS dump.');
