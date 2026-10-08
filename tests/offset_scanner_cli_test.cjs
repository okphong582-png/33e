'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const {spawnSync}=require('node:child_process');
const catalog=require('../profiles/offset-catalog.json');
const root=path.resolve(__dirname,'..');
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'ff-offset-scanner-'));
const dump=path.join(temporary,'dump'),output=path.join(temporary,'candidates');
fs.mkdirSync(dump);
const owners=new Map();
for(const f of catalog.fields) {
    const fields=owners.get(f.owner)||[];fields.push(f);owners.set(f.owner,fields);
}
const fixture=[];
let typeIndex=0;
for(const [owner,fields] of owners) {
    const split=owner.lastIndexOf('.');
    fixture.push(`// Namespace: ${owner.slice(0,split)}`,
        `public class ${owner.slice(split+1)} // TypeDefIndex: ${typeIndex++}`, '{');
    for(const f of fields) fixture.push(` ${f.declaration} ${f.name}; // 0x${f.baseline.toString(16)}`);
    fixture.push('}');
}
fs.writeFileSync(path.join(dump,'dump.cs'),fixture.join('\n'));
const methods=catalog.methods.map(m=>({Name:m.name,Signature:m.signature,TypeSignature:m.typeSignature,Address:m.baseline}));
const writeScript=list=>fs.writeFileSync(path.join(dump,'script.json'),JSON.stringify({ScriptMethod:list}));
const scan=variant=>spawnSync(process.execPath,[path.join(root,'tools/update_game_offsets.cjs'),
    '--dump',dump,'--variant',variant,'--out',output],{encoding:'utf8'});
writeScript(methods);
assert.equal(scan('max').status,0);
assert(fs.readFileSync(path.join(output,'GameProfileMethods.h'),'utf8').includes('constexpr uint64_t DumpRva'));
writeScript(methods.slice(1));
assert.equal(scan('max').status,2);
assert(fs.readFileSync(path.join(output,'GameProfileMethods.h'),'utf8').startsWith('#error'));
assert.equal(JSON.parse(fs.readFileSync(path.join(output,'offset-report.json'))).unresolved.length,1);
// A repeated name with a different signature must not select the wrong overload.
writeScript([...methods,{...methods[0],Signature:'different overload',Address:123}]);
assert.equal(scan('max').status,0);
// Exact identity at multiple RVAs is ambiguous and invalidates candidates.
writeScript([...methods,{...methods[0],Address:methods[0].Address+4}]);
assert.equal(scan('max').status,2);
writeScript(methods);assert.equal(scan('max').status,0);
assert.equal(scan('th').status,0);
assert(fs.readFileSync(path.join(output,'GameProfileFields.h'),'utf8').startsWith('#error'));
console.log('Offset scanner CLI: overload matching, missing/ambiguous matches and stale candidate rejection passed.');
// Keep this uniquely named fixture directory for inspection; no recursive delete.
