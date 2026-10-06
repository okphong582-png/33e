// Serialize the inspected IFix layout. No code is executed and no DLL is linked.
const fs=require('node:fs');
function encode(patch){
 const chunks=[];
 const byte=v=>chunks.push(Buffer.from([v]));
 function i32(value){const b=Buffer.alloc(4);b.writeInt32LE(value);chunks.push(b);}
 function string(value){const b=Buffer.from(value,'utf8');let n=b.length;do{byte((n&127)|(n>=128?128:0));n=Math.floor(n/128);}while(n);chunks.push(b);}
 function array(values,write){i32(values.length);values.forEach(write);}
 if(new Set(patch.types).size!==patch.types.length)throw Error('Duplicate types need explicit indexes');
 function type(value){const index=patch.types.indexOf(value);if(index<0)throw Error('Missing type '+value);i32(index);}
 function method(value){byte(value.generic?1:0);type(value.owner);string(value.name);
  if(value.generic)array(value.args,type);
  array(value.parameters,(item,index)=>{const match=value.parameterIsGeneric[index];if(value.generic)byte(match?1:0);if(match)string(item);else type(item);});
 }
 const magic=Buffer.alloc(8);magic.writeBigUInt64LE(BigInt('0x'+patch.magic));chunks.push(magic);
 string(patch.bridge);array(patch.types,string);
 array(patch.methods,value=>{array(value.instructions,i=>{i32(i.code);i32(i.operand);});array(value.handlers,h=>{if(h.length!==6)throw Error('Invalid handler');h.forEach(i32);});});
 array(patch.externMethods,method);array(patch.strings,string);
 array(patch.fields,value=>{byte(value.isNew?1:0);type(value.owner);string(value.name);if(value.isNew){type(value.type);i32(value.method);}});
 array(patch.statics,value=>{type(value.type);i32(value.constructor);});
 array(patch.closures,value=>{array(value.fields,i32);i32(value.constructor);i32(value.parameters);i32(0);array(value.vtable,i32);});
 string(patch.wrappers);string(patch.assembly);
 if(patch.fixTableFlag!==null)byte(patch.fixTableFlag);
 array(patch.fixes,value=>{method(value.method);i32(value.id);});array(patch.newClasses,string);
 return Buffer.concat(chunks);
}
module.exports={encode};
if(require.main===module){
 const [input,output]=process.argv.slice(2);
 if(!input||!output)throw Error('Usage: node write_patch.cjs structure.json output.bytes');
 const patch=JSON.parse(fs.readFileSync(input,'utf8')),bytes=encode(patch);
 const {inspect}=require('./inspect_patch.cjs');inspect(bytes);
 fs.writeFileSync(output,bytes);console.log('Wrote '+bytes.length+' bytes; structural validation passed, game execution unverified.');
}
