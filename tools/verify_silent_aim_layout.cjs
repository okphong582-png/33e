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
// Unity's standard raycast, solid-hit ownership, and target hierarchy getters.
assert.equal(fingerprint(0x8DE4904,0x17C),0x8B3DCDAE);
assert.equal(fingerprint(0x8DE4A80,0x1F0),0x8956580B);
assert.equal(fingerprint(0x8DF0730,0xF4),0xF884A08C);
assert.equal(fingerprint(0x8D59C2C,0x50),0xE5B7D25C);
assert.equal(fingerprint(0x8D6ECE0,0x64),0xDECACF20);
assert.equal(fingerprint(0x56182FC,0x154),0x8E831156);
// Local visual spin: separate skeleton child and Unity local quaternion access.
assert.equal(fingerprint(0x6B4964C,0x8),0x80D43BE2);
assert.equal(fingerprint(0x6B49C14,0xF0),0x990FC153);
assert.equal(fingerprint(0x8D6C788,0x60),0xAE8A72F8);
assert.equal(fingerprint(0x5639C90,0x154),0x3D4AF30F);
assert.equal(fingerprint(0x8D6C38C,0x64),0xDB814CED);
assert.equal(fingerprint(0x8D6C454,0x74),0x61044F36);
assert.equal(fingerprint(0x8D6E900,0x50),0x178B2DA7);
assert.equal(fingerprint(0x8D6EEB0,0x64),0x54800249);
assert.equal(fingerprint(0x8D58C18,0x50),0x3655F88D);
assert.equal(fingerprint(0x8D58C68,0x64),0x43B62F71);
assert.equal(fingerprint(0x8CDCAF4,0x50),0xD78D78BD);
assert.equal(fingerprint(0x8CDCB44,0x64),0x154D9667);
assert.equal(fingerprint(0x8D6C860,0x78),0xD1FEABDC);
assert.equal(fingerprint(0x8D6C5B4,0x60),0x6881CEE5);
assert.equal(fingerprint(0x8D6C68C,0x74),0x54F82A6C);
// Final presentation: GameEntry -> BaseGameManager -> virtual slot 18.
words(0x6B32BB0,[0xF9412D02,0xF9413101,0xAA1303E0]);
assert.equal(fingerprint(0x5A9A654,0x78),0x01F24198);
for(const [address,hash] of [[0x635594C,0xFB5E72CE],[0x63706CC,0x3010A312],
    [0x63733EC,0x2EFCAE4E],[0x6374918,0x482878B5],[0x66E0A24,0x19ABE41A],[0x66F031C,0xCDA7586C]])
    assert.equal(fingerprint(address,0x54),hash);
assert.equal(fingerprint(0x5AC970C, 0xA0), 0x93FD3984);
assert.equal(fingerprint(0x5C59B94, 0x16C), 0xDFE8FAC6);
// Native weapon input: begin/end methods, and the two allowed player updates.
assert.equal(fingerprint(0x5C179E8, 0x5A8), 0x9AD8096C);
// IsAmmoFree is a separate byte from ShootNoReload. The native shot skips
// the subtraction/set-ammo branch when this byte is true.
words(0x6483C7C,[0x39465000,0xD65F03C0,0x39065001,0xD65F03C0]);
words(0x5C17DB0,[0x39465008,0x37000A88]);
assert.equal(fingerprint(0x56AC3A8,0x1E8),0x1EE7E697);
// Separate visual dispatch and hit-processing branches; lazy visual TypeInfo.
assert.equal(fingerprint(0x5C76890,0x26B0),0x6D340948);
assert.equal(fingerprint(0xA11121C,0x18),0x2FC932FA);
assert.equal(fingerprint(0x5C1E910,0x30),0xC285FA0E);
assert.equal(fingerprint(0x5C22FA8,0x30C),0x76159E8D);
assert.equal(fingerprint(0x5C23B54,0x1B08),0xF0BC2099);
assert.equal(fingerprint(0x5C222EC, 0x1E4), 0xA2F105A1);
words(0x6482AA0,[0xBD43CA80,0x1E202008,0x5400036C]);
assert.equal(fingerprint(0x56B4EB4,0x5F8),0x40924917);
assert.equal(fingerprint(0x5A5C9D4,0x100),0x538C5B13);
assert.equal(fingerprint(0x5636E60,0xC0),0x8C40F08F);
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
let visualFound = false;
const inputMethods = new Set();
for (let p = types; p < types+typeBytes; p += 88) {
    if (string(metadata.readUInt32LE(p)) === 'NGMILJIELKA') {
        assert.equal(string(metadata.readUInt32LE(p+4)), 'COW.GamePlay');
        const start = metadata.readUInt32LE(p+36), count = metadata.readUInt16LE(p+64);
        for(let j=start;j<start+count;++j) {
            const q=methods+j*40;
            if(string(metadata.readUInt32LE(q)) !== 'JCCIMHDAPDB') continue;
            assert.equal(metadata.readUInt16LE(q+36),5);
            assert.equal(metadata.readUInt16LE(q+38),5);
            assert(metadata.readUInt16LE(q+32)&0x40);
            visualFound=true;
        }
    }
    if (string(metadata.readUInt32LE(p)) === 'HBIBDMMOOOK') {
        const start = metadata.readUInt32LE(p+36), count = metadata.readUInt16LE(p+64);
        for (let j = start; j < start+count; ++j) {
            const q = methods+j*40, name = string(metadata.readUInt32LE(q));
            if(name==='CIHHEOKFADJ') {
                assert.equal(metadata.readUInt16LE(q+36),223);
                assert.equal(metadata.readUInt16LE(q+38),3);
            }
            if(name==='LHNJLFOINDO') assert.equal(metadata.readUInt16LE(q+38),1);
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
assert(visualFound,'Expected separate virtual shot presentation');
assert.equal(inputMethods.size, 2, 'Expected native weapon input pair');
console.log('1.132.1 static shot-input layout verified; runtime hits remain unverified.');
