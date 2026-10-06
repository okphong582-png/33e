// Decode the supplied game variant only. Static analysis, never VM execution.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {inspect}=require('./inspect_patch.cjs');
const [input,metadata,output]=process.argv.slice(2);
if(!input||!metadata||!output)throw Error('Usage: node decode_patch.cjs patch.bytes global-metadata.dat output-directory');
const data=fs.readFileSync(metadata);
const sha=crypto.createHash('sha256').update(data).digest('hex');
if(sha!=='597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d')throw Error('Opcode order verified only against supplied 1.132.1 metadata');
const patch=inspect(fs.readFileSync(input));
if(patch.sha256!=='765b52f8bc66ce86d1bdd446afb317c1bf0a59c5b5938769e432b2ecc0720e17')throw Error('Disassembly verified only against the supplied patch; inspect_patch supports structural inspection of other inputs');
const strings=data.readUInt32LE(24),fields=data.readUInt32LE(96),types=data.readUInt32LE(160),length=data.readUInt32LE(164);
const text=i=>{const start=strings+i;return data.subarray(start,data.indexOf(0,start)).toString('utf8');};
let names=[];
for(let p=types;p<types+length;p+=88){
 if(text(data.readUInt32LE(p))!=='Code'||text(data.readUInt32LE(p+4))!=='IFix.Core')continue;
 const start=data.readUInt32LE(p+32),count=data.readUInt16LE(p+68);
 for(let i=start+1;i<start+count;i++)names.push(text(data.readUInt32LE(fields+i*12)));
}
if(names[57]!=='StackSpace'||names[175]!=='CallExtern'||names[180]!=='Ldc_I4')throw Error('Unexpected opcode definition');
fs.mkdirSync(output,{recursive:true});
const short=t=>t.split(',')[0];
for(let id=0;id<patch.methods.length;id++){
 const lines=patch.methods[id].instructions.map((i,index)=>{
  const code=names[i.code]||'DATA';let note='';
  if(['CallExtern','Callvirt','Newobj'].includes(code)){
   const method=patch.externMethods[i.operand&65535];
   if(!method)throw Error('Unknown external method');
   note=short(method.owner)+'.'+method.name+'('+method.parameters.map(short).join(', ')+')';
  }
  if(code==='Ldstr')note=JSON.stringify(patch.strings[i.operand]);
  if(['Ldfld','Stfld','Ldflda','Ldsfld','Stsfld'].includes(code))note=JSON.stringify(patch.fields[i.operand]);
  return index+': '+code+' '+i.operand+(note?' // '+note:'');
 });
 fs.writeFileSync(path.join(output,'method-'+id+'.il'),lines.join('\n')+'\n');
}
fs.writeFileSync(path.join(output,'structure.json'),JSON.stringify(patch,null,2)+'\n');
console.log('Decoded all '+patch.methods.length+' methods; supplied patch and metadata SHA-256 verified. DATA records are not independent opcodes.');
