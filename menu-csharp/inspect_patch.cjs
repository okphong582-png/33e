// Read-only IFix inspection. This never loads or executes the supplied bytecode.
// Format reference: Tencent/InjectFix FileVirtualMachineBuilder.cs (MIT).
const fs=require('node:fs'),crypto=require('node:crypto');
function inspect(buffer){
 let offset=0;
 function take(n){if(!Number.isSafeInteger(n)||n<0||offset+n>buffer.length)throw Error('Truncated data at '+offset);const p=offset;offset+=n;return p;}
 const i32=()=>buffer.readInt32LE(take(4));
 const bool=()=>{const v=buffer[take(1)];if(v>1)throw Error('Invalid boolean');return !!v;};
 function count(){const n=i32();if(n<0||n>buffer.length)throw Error('Invalid count at '+(offset-4));return n;}
 function string(){let n=0,shift=0;for(let j=0;j<5;j++){const v=buffer[take(1)];n+=(v&127)*2**shift;if(!(v&128)){const p=take(n);return buffer.subarray(p,p+n).toString('utf8');}shift+=7;}throw Error('Invalid string length');}
 const magic=buffer.readBigUInt64LE(take(8)).toString(16);
 const bridge=string(),types=Array.from({length:count()},string);
 const type=()=>{const id=i32();if(id<0||id>=types.length)throw Error('Invalid type index '+id);return types[id];};
 const methods=Array.from({length:count()},()=>{
  const start=offset,instructions=Array.from({length:count()},()=>({offset:offset,code:i32(),operand:i32()}));
  const handlers=Array.from({length:count()},()=>Array.from({length:6},i32));return {start,instructions,handlers};
 });
 function method(){const generic=bool(),owner=type(),name=string();
  const args=generic?Array.from({length:count()},type):[];
  const parameterIsGeneric=[];
  const parameters=Array.from({length:count()},()=>{const match=generic&&bool();parameterIsGeneric.push(match);return match?string():type();});
  return {generic,owner,name,args,parameters,parameterIsGeneric};
 }
 const externMethods=Array.from({length:count()},method),strings=Array.from({length:count()},string);
 const fields=Array.from({length:count()},()=>{const isNew=bool(),owner=type(),name=string();return isNew?{isNew,owner,name,type:type(),method:i32()}:{isNew,owner,name};});
 const statics=Array.from({length:count()},()=>({type:type(),constructor:i32()}));
 const closures=Array.from({length:count()},()=>{
  const fields=Array.from({length:count()},i32),constructor=i32(),parameters=i32(),interfaces=count();
  if(interfaces)throw Error('Interface slots require interface metadata; stopped at '+offset);
  return {fields,constructor,parameters,vtable:Array.from({length:count()},i32)};
 });
 const wrappers=string(),assembly=string();
 // Supplied game variant has a single flag byte before the fix table.
 // This flag's meaning is unverified; retain it instead of naming it.
 let fixTableFlag=null;
 const possibleCount=buffer.readInt32LE(offset);
 if(possibleCount<0||possibleCount>methods.length){fixTableFlag=bool()?1:0;}
 const fixes=Array.from({length:count()},()=>({method:method(),id:i32()}));
 const newClasses=offset<buffer.length?Array.from({length:count()},string):[];
 if(offset!==buffer.length)throw Error('Unparsed trailing data at '+offset);
 return {sha256:crypto.createHash('sha256').update(buffer).digest('hex'),size:buffer.length,magic,bridge,types,methods,externMethods,strings,fields,statics,closures,wrappers,assembly,fixTableFlag,fixes,newClasses};
}
module.exports={inspect};
if(require.main===module){
 const result=inspect(fs.readFileSync(process.argv[2]));
 if(process.argv[3])fs.writeFileSync(process.argv[3],JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({sha256:result.sha256,size:result.size,magic:result.magic,types:result.types.length,methods:result.methods.length,externMethods:result.externMethods.length,strings:result.strings.length,fields:result.fields.length,statics:result.statics.length,fixes:result.fixes,newClasses:result.newClasses},null,2));
 console.log('GUI / filesystem methods:',JSON.stringify(result.externMethods.map((m,id)=>({id,...m})).filter(m=>/GUI|Application|File|Path|Directory/.test(m.owner)),null,2));
}
