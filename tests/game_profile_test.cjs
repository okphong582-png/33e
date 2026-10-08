'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {parseDump, headers} = require('../tools/update_game_offsets.cjs');
const catalog = require('../profiles/offset-catalog.json');
const root = path.resolve(__dirname, '..');
const th = require('../profiles/ffth-1.132.1.json');
const max = require('../profiles/ffmax-2.132.1.json');
const native = require('../profiles/ffmax-native-2.132.1.json');
const {header: nativeHeader} = require('../tools/verify_max_native.cjs');

for (const profile of [th, max]) {
    assert.equal(profile.unresolved.length, 0);
    assert.equal(profile.methods.length, catalog.methods.length);
    assert.equal(profile.fields.length, catalog.fields.length);
    assert.equal(profile.nativeVerified, false);
    for (const method of profile.methods) {
        assert.equal(method.status, 'matched-dump');
        assert(Number.isSafeInteger(method.target) && method.target > 0);
        assert.equal(method.candidates.length, 1, `Ambiguous overload ${method.name}`);
    }
}
for (const record of [...th.methods, ...th.fields]) assert.equal(record.target, record.baseline);
const generated = headers(max);
for (const [file, expected] of [['GameProfileFields.h', generated.fields], ['GameProfileMethods.h', generated.methods]])
    assert.equal(fs.readFileSync(path.join(root, 'esp/Core', file), 'utf8').trim(), expected.trim(), `${file} is stale`);
const player = offset => max.fields.find(f => f.owner === 'COW.GamePlay.Player' && f.baseline === offset).target;
assert.equal(player(0x614), 0x61C);
assert.equal(player(0x768), 0x770);
assert.equal(player(0x1258), 0x1270); // A different delta than earlier Player fields.
const raycast = max.methods.find(m => m.baseline === 0x8DE4904);
assert.equal(raycast.target, 0x8EB0D90); // Exact overload, not the first matching name.
assert.equal(max.methods.find(m => m.baseline === 0x591B898).target, 0x5D4D76C);
const fixture = '// Namespace: Test\npublic class Example // TypeDefIndex: 0\n{\n public static int Field; // 0x0\n private bool Flag; // 0x10\n}\n';
assert.deepEqual(parseDump(fixture).get('Test.Example')[0].fields.map(f => f.offset), [0, 16]);
assert.throws(() => headers({...max, unresolved: [{name: 'missing'}]}), /unresolved/);
assert(max.nativeOnly.some(n => n.baseline === 0xBB46A50));
assert.equal(fs.readFileSync(path.join(root,'esp/Core/MaxNativeVerified.h'),'utf8').trim(),nativeHeader(native).trim());
assert.equal(native.fingerprints.length,90);
assert.equal(native.runtimeVerified,false);
assert.equal(native.executable,'FreeFireMAX');
assert.equal(native.rvas.find(r=>r.th===0xBB46A50).max,0xBE93418);
assert.equal(native.rvas.find(r=>r.th===0xBB4BEC8).max,0xBE988C0);
assert.equal(native.rvas.find(r=>r.th===0x6482AA0).max,0x6523F98);
const known = new Set([...max.methods.map(m=>m.baseline),...native.rvas.map(r=>r.th)]);
const expectedHashes = new Set(native.fingerprints.map(f=>f.thHash));
for(const file of ['AutoFire.mm','GhostMode.mm','PlayerModes.mm','SilentAim.mm','SilentAimExternal.mm','SilentAimWeapon.h','_0xGL2972_.mm','../drawing_view/offset.h']) {
    const text=fs.readFileSync(path.join(root,'esp/Core',file),'utf8');
    for(const m of text.matchAll(/GameOffsets::Rva\((0x[\da-f]+)\)/gi)) assert(known.has(Number(m[1])),`${file}: missing native RVA ${m[1]}`);
    for(const m of text.matchAll(/Fingerprint<(0x[\da-f]+)>\([^\n]*?,\s*(0x[\da-f]+)\)/gi))
        assert(expectedHashes.has(Number(m[2])),`${file}: missing hash ${m[2]}`);
}
console.log(`Profiles: ${max.methods.length} methods, ${max.fields.length} fields, ${native.fingerprints.length} MAX native fingerprints; device tests still required.`);
