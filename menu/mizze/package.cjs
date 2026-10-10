// Convert the pinned upstream serializer's container to the supplied game variant.
// Instructions and helper methods are entirely compiled from this directory's C#.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {inspect}=require('../inspect_patch.cjs');
const dir=__dirname;
const sourceFiles=fs.readdirSync(dir).filter(n=>n.endsWith('.cs')&&!['CompilerHost.cs','RuntimeApis.cs','RuntimeTest.cs'].includes(n)).sort();
const sourceHash=crypto.createHash('sha256');for(const name of sourceFiles){sourceHash.update(name+'\0');sourceHash.update(fs.readFileSync(path.join(dir,name),'utf8').replace(/\r\n/g,'\n'));}
const stateNamespace='Mizze_'+sourceHash.digest('hex').slice(0,16)+'_';
const p=inspect(fs.readFileSync(path.join(dir,'build/upstream.bytes'))),parts=[];
function i(n){const b=Buffer.alloc(4);b.writeInt32LE(n);parts.push(b);}function bit(v){parts.push(Buffer.from([v?1:0]));}
function s(v){const b=Buffer.from(v);let n=b.length;while(n>=128){parts.push(Buffer.from([(n&127)|128]));n>>>=7;}parts.push(Buffer.from([n]),b);}
function list(a,f){i(a.length);a.forEach(f);}function t(v){const n=p.types.indexOf(v);if(n<0)throw Error('Unknown type '+v);i(n);}
function method(m){bit(m.generic);t(m.owner);s(m.name);if(m.generic)list(m.args,t);list(m.parameters,(v,index)=>{if(m.generic)bit(m.parameterIsGeneric[index]);if(m.generic&&m.parameterIsGeneric[index])s(v);else t(v);});}
if(p.closures.length||p.statics.length||p.newClasses.length)throw Error('Unexpected closure/static/class metadata');
const magic=Buffer.alloc(8);magic.writeBigUInt64LE(0x66a319b20db4a2cbn);parts.push(magic);s(p.bridge);list(p.types,s);
list(p.methods,m=>{list(m.instructions,x=>{i(x.code);i(x.operand);});list(m.handlers,h=>h.forEach(i));});
list(p.externMethods,method);list(p.strings,s);list(p.fields,f=>{bit(f.isNew);t(f.owner);s(f.isNew?stateNamespace+f.name:f.name);if(f.isNew){t(f.type);i(f.method);}});
i(0);i(0);s(p.wrappers);s(p.assembly);bit(false);list(p.fixes,f=>{method(f.method);i(f.id);});i(0);
const bytes=Buffer.concat(parts),result=inspect(bytes),out=path.join(dir,'dist');fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'Assembly-CSharp-patch.bytes'),bytes);fs.writeFileSync(path.join(out,'SHA256SUMS.txt'),result.sha256+'  Assembly-CSharp-patch.bytes\n');
fs.copyFileSync(path.join(dir,'build/methods.tsv'),path.join(out,'methods.tsv'));
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({size:result.size,sha256:result.sha256,magic:result.magic,methods:result.methods.length,externMethods:result.externMethods.length,newFields:result.fields.filter(f=>f.isNew).length,fixes:result.fixes,source:'menu/mizze/*.cs',stateNamespace,target:'Free Fire TH iOS 1.132.1',deviceVerified:false},null,2)+'\n');
console.log('Packaged Mizze: '+result.size+' bytes; SHA256 '+result.sha256);
