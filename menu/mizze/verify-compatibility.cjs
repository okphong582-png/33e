const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{inspect}=require('../inspect_patch.cjs');
const dir=__dirname,p=inspect(fs.readFileSync(path.join(dir,'dist/Assembly-CSharp-patch.bytes'))),baseline=JSON.parse(fs.readFileSync(path.join(dir,'compatibility-api-baseline.json'),'utf8'));
const additions=JSON.parse(fs.readFileSync(path.join(dir,'old-source-api-additions.json'),'utf8'));
function key(e){return e.owner+'::'+e.name+'('+e.parameters.join('|')+')<'+(e.args||[]).join('|')+'>'}
assert.deepEqual([...p.types].sort(),[...baseline.types.filter(t=>!additions.removedTypes.includes(t)),...additions.types].sort(),'Native type set differs from baseline plus documented native stealth restoration');
assert.deepEqual(p.externMethods.map(key).sort(),[...baseline.externSignatures.filter(t=>!additions.removedExternSignatures.includes(t)),...additions.externSignatures].sort(),'Native method set differs from baseline plus documented native stealth restoration');
assert.deepEqual(p.fields.filter(f=>!f.isNew).map(f=>f.owner+'::'+f.name).sort(),[...baseline.nativeFields,...additions.nativeFields].sort(),'Native field set differs from baseline plus documented native stealth restoration');
assert.deepEqual(p.fixes.map(f=>key(f.method)).sort(),[...baseline.fixes,...additions.fixes].sort(),'Hook set differs from baseline plus documented native stealth restoration');
console.log('PASS: native types, '+p.externMethods.length+' extern methods, '+(baseline.nativeFields.length+additions.nativeFields.length)+' native fields and '+p.fixes.length+' hooks match baseline plus documented native stealth restoration.');
