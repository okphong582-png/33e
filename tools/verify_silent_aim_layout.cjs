// Static evidence only. No game files are uploaded or modified.
// node tools/verify_silent_aim_layout.cjs UnityFramework global-metadata.dat
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const [nativePath, metadataPath] = process.argv.slice(2);
if (!nativePath || !metadataPath) throw Error('Pass UnityFramework and global-metadata.dat');
const native = fs.readFileSync(nativePath), metadata = fs.readFileSync(metadataPath);
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
assert.equal(sha(native), 'ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8');
assert.equal(sha(metadata), '597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d');
assert.equal(native.readUInt32LE(0), 0xfeedfacf);
const segments = [];
for (let i = 0, p = 32; i < native.readUInt32LE(16); ++i) {
    const command = native.readUInt32LE(p), size = native.readUInt32LE(p + 4);
    if (command === 0x19) segments.push({vm: Number(native.readBigUInt64LE(p+24)),
        file: Number(native.readBigUInt64LE(p+40)), size: Number(native.readBigUInt64LE(p+48))});
    p += size;
}
function word(address) {
    const s = segments.find(s => address >= s.vm && address + 4 <= s.vm + s.size);
    assert(s, 'Instruction must map to a file-backed segment');
    return native.readUInt32LE(s.file + address - s.vm);
}
function words(address, expected) { expected.forEach((w, i) => assert.equal(word(address+i*4), w)); }
function fingerprint(address, length) {
    let hash = 0x811c9dc5;
    for (let i = 0; i < length; i += 4) {
        const w = word(address+i);
        for (let j = 0; j < 4; ++j) hash = Math.imul(hash ^ ((w >>> (j*8)) & 255), 0x01000193) >>> 0;
    }
    return hash;
}
assert.equal(fingerprint(0x5616118, 0xCC), 0xC5E012EE);
assert.equal(fingerprint(0x5AC970C, 0xA0), 0x93FD3984);
assert.equal(fingerprint(0x5C59B94, 0x16C), 0xDFE8FAC6);
// Native weapon input: begin/end methods, and the two allowed player updates.
assert.equal(fingerprint(0x5C179E8, 0x5A8), 0x9AD8096C);
assert.equal(fingerprint(0x5C222EC, 0x1E4), 0xA2F105A1);
assert.equal(fingerprint(0x5660700, 0x100), 0xC902032E);
assert.equal(fingerprint(0x5A4BEC0, 0x100), 0x4B4A9AE9);
// Weapon input calls Player.StartFiring / Player.StopFire, then its own
// native state transitions. Do not substitute a direct write to firing PRI.
words(0x5C17C78, [0xF9469D09, 0xF946A102, 0xAA1403E0, 0xAA1303E1, 0xD63F0120]);
words(0x5C223C8, [0xF946B509, 0xF946B902, 0xAA1403E0, 0xAA1303E1, 0xD63F0120]);
words(0x5616118, [0xA9BE4FF4, 0xA9017BFD, 0x910043FD, 0xAA0003F3]);
// Player +0x740 -> manager; flag +0x148 selects +0xA0 or +0xA8.
words(0x561617C, [0xF943A260]);
words(0x5AC9780, [0xF9405260]);
words(0x5AC9790, [0x39452268, 0x3607FF68, 0xF9405660]);
words(0x5C59B94, [0xD10343FF, 0x6D033BEF, 0x6D0433ED, 0x6D052BEB]);
// Handler reads its aiming-info reference, then the direction triplet at +0x40.
words(0x5C59CE4, [0xF8428E88]);
words(0x5C59CF4, [0x2D482909, 0xBD40490B]);
// The physics helper stores direction at +0x40 and origin at +0x4C.
words(0x6397294, [0x2D08328D, 0x2D092A8B, 0x2D0A2289]);
assert.equal(metadata.readUInt32LE(0), 0xfab11baf);
assert.equal(metadata.readUInt32LE(4), 31);
const strings = metadata.readUInt32LE(24), methods = metadata.readUInt32LE(48);
const types = metadata.readUInt32LE(160), typeBytes = metadata.readUInt32LE(164);
const string = i => { const start = strings+i; return metadata.subarray(start, metadata.indexOf(0,start)).toString(); };
let found = false;
const inputMethods = new Set();
for (let p = types; p < types+typeBytes; p += 88) {
    if (string(metadata.readUInt32LE(p)) === 'HBIBDMMOOOK') {
        const start = metadata.readUInt32LE(p+36), count = metadata.readUInt16LE(p+64);
        for (let j = start; j < start+count; ++j) {
            const q = methods+j*40, name = string(metadata.readUInt32LE(q));
            const slot = name === 'ALJMFCJMDCF' ? 182 : (name === 'NFFJEBKJCAK' ? 213 : -1);
            if (slot < 0) continue;
            assert.equal(metadata.readUInt16LE(q+36), slot);
            assert.equal(metadata.readUInt16LE(q+38), 0);
            assert(metadata.readUInt16LE(q+32) & 0x40);
            inputMethods.add(name);
        }
    }
    if (string(metadata.readUInt32LE(p)) !== 'MDPBNKPCGNG') continue;
    const start = metadata.readUInt32LE(p+36), count = metadata.readUInt16LE(p+64);
    for (let j = start; j < start+count; ++j) {
        const q = methods+j*40;
        if (string(metadata.readUInt32LE(q)) !== 'IONEHPNFAJD') continue;
        assert.equal(metadata.readUInt16LE(q+36), 17);
        assert.equal(metadata.readUInt16LE(q+38), 0);
        assert(metadata.readUInt16LE(q+32) & 0x40, 'Handler must be virtual');
        found = true;
    }
}
assert(found, 'Expected native handler metadata');
assert.equal(inputMethods.size, 2, 'Expected native weapon input pair');
console.log('1.132.1 static shot-input layout verified; runtime hits remain unverified.');
