const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{inspect}=require('../inspect_patch.cjs');
const dir=__dirname,p=inspect(fs.readFileSync(path.join(dir,'dist/Assembly-CSharp-patch.bytes'))),baseline=JSON.parse(fs.readFileSync(path.join(dir,'compatibility-api-baseline.json'),'utf8'));
function key(e){return e.owner+'::'+e.name+'('+e.parameters.join('|')+')<'+(e.args||[]).join('|')+'>'}
assert.deepEqual([...p.types].sort(),[...baseline.types].sort(),'Native type set differs from pre-R2 baseline');
assert.deepEqual(p.externMethods.map(key).sort(),baseline.externSignatures,'Native method set differs from pre-R2 baseline');
assert.deepEqual(p.fields.filter(f=>!f.isNew).map(f=>f.owner+'::'+f.name).sort(),baseline.nativeFields,'Native field set differs from pre-R2 baseline');
assert.deepEqual(p.fixes.map(f=>key(f.method)).sort(),baseline.fixes,'Hook set differs from pre-R2 baseline');
console.log('PASS: native types, '+p.externMethods.length+' extern methods, '+baseline.nativeFields.length+' native fields and '+p.fixes.length+' hooks equal pre-R2 baseline; no added runtime dependencies.');
