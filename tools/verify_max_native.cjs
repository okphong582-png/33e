#!/usr/bin/env node
'use strict';
// Read-only verification. Dump matching is not evidence for a new native image.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const profile = require('../profiles/ffmax-native-2.132.1.json');
const hex = n => '0x' + n.toString(16).toUpperCase();

function header(p) {
    const out = ['#pragma once', '#include <cstdint>',
        '// Static native evidence from com.dts.freefiremax 2.132.1, build 2019118522.',
        '// Generated from profiles/ffmax-native-2.132.1.json; never reuse for another OB.',
        '// Device behavior, permissions and native Unity object storage remain untested.',
        'namespace MaxNative {'];
    for (const [name, type, rows] of [
        ['Rva', 'uint64_t', p.rvas.map(x => ({th:x.th, max:x.max, comment:x.label}))],
        ['ExpectedHash', 'uint32_t', p.fingerprints.map(x => ({th:x.thHash, max:x.maxHash}))],
        ['ExpectedWord', 'uint32_t', p.words],
    ]) {
        assert.equal(new Set(rows.map(x => x.th)).size, rows.length, `Duplicate ${name} key`);
        out.push(`constexpr ${type} ${name}(${type} th) {`, '    switch (th) {');
        for (const x of rows) out.push(`        case ${hex(x.th)}: return ${hex(x.max)};${x.comment ? ' // '+x.comment : ''}`);
        out.push('        default: return 0;', '    }', '}');
    }
    return [...out, '}', ''].join('\n');
}

function verify(native, metadata) {
    const sha = b => crypto.createHash('sha256').update(b).digest('hex');
    assert.equal(sha(native), profile.nativeSha256, 'Different UnityFramework: review the OB native profile');
    assert.equal(sha(metadata), profile.metadataSha256, 'Different global-metadata.dat');
    assert.equal(native.readUInt32LE(0), 0xfeedfacf);
    assert.equal(native.readUInt32LE(4), 0x100000c, 'Expected ARM64');
    const segments = [];
    for (let i=0, p=32; i<native.readUInt32LE(16); ++i) {
        const command=native.readUInt32LE(p), size=native.readUInt32LE(p+4);
        assert(size>=8 && p+size<=native.length);
        if (command===0x19) segments.push({vm:Number(native.readBigUInt64LE(p+24)),
            file:Number(native.readBigUInt64LE(p+40)), size:Number(native.readBigUInt64LE(p+48))});
        if (command===0x2c) assert.equal(native.readUInt32LE(p+16),0,'Encrypted native image');
        p+=size;
    }
    const bytes = (rva, length) => {
        const s=segments.find(s => rva>=s.vm && rva+length<=s.vm+s.size);
        assert(s, `Unmapped native range ${hex(rva)}`);
        return native.subarray(s.file+rva-s.vm, s.file+rva-s.vm+length);
    };
    const word = rva => bytes(rva,4).readUInt32LE(0);
    const fnv = b => { let h=0x811c9dc5; for(const v of b) h=Math.imul(h^v,0x01000193)>>>0; return h; };
    for(const f of profile.fingerprints) assert.equal(fnv(bytes(f.max,f.length)),f.maxHash,hex(f.max));
    for(const i of profile.instructionChecks) assert.equal(word(i.rva),i.word,`${hex(i.rva)} ${i.instruction}`);
    for(const g of profile.globalReferences) {
        const a=word(g.adrp), b=word(g.add);
        assert.equal((a&0x9f000000)>>>0,0x90000000);
        assert.equal((b&0xffc00000)>>>0,0x91000000);
        assert.equal(a&31,(b>>>5)&31);
        let imm=((a>>>29)&3)|(((a>>>5)&0x7ffff)<<2);
        if(imm&(1<<20)) imm-=1<<21;
        assert.equal(Math.floor(g.adrp/4096)*4096+imm*4096+((b>>>10)&4095),g.target);
    }
    assert.equal(metadata.readUInt32LE(0),0xfab11baf);
    assert.equal(metadata.readUInt32LE(4),31);
    const strings=metadata.readUInt32LE(24), methods=metadata.readUInt32LE(48);
    const types=metadata.readUInt32LE(160), typeBytes=metadata.readUInt32LE(164);
    const string=i => { const s=strings+i; return metadata.subarray(s,metadata.indexOf(0,s)).toString(); };
    const owners=new Map();
    for(let p=types;p<types+typeBytes;p+=88) {
        const name=[string(metadata.readUInt32LE(p+4)),string(metadata.readUInt32LE(p))].filter(Boolean).join('.');
        owners.set(name,p);
    }
    for(const v of profile.virtualMethods) {
        const p=owners.get(v.owner); assert(p, v.owner);
        const start=metadata.readUInt32LE(p+36), count=metadata.readUInt16LE(p+64);
        const found=[];
        for(let j=start;j<start+count;++j) {
            const q=methods+j*40;
            if(string(metadata.readUInt32LE(q))===v.name && metadata.readUInt16LE(q+38)===v.params) found.push(q);
        }
        assert.equal(found.length,1, `${v.owner}.${v.name}`);
        assert.equal(metadata.readUInt16LE(found[0]+36),v.slot);
        assert.equal(metadata.readUInt16LE(found[0]+32),v.flags);
    }
    for(const v of profile.virtualTables) {
        const p=owners.get(v.owner); assert(p,v.owner);
        const start=metadata.readUInt32LE(p+56), count=metadata.readUInt16LE(p+74);
        for(const s of v.slots) {
            assert(s.slot<count);
            const encoded=metadata.readUInt32LE(metadata.readUInt32LE(144)+(start+s.slot)*4);
            assert.equal(encoded>>>29,3,'Expected method definition vtable entry');
            const q=methods+((encoded&0x1fffffff)>>>1)*40;
            assert.equal(string(metadata.readUInt32LE(q)),s.name);
        }
    }
    return {fingerprints:profile.fingerprints.length, instructions:profile.instructionChecks.length,
        virtualMethods:profile.virtualMethods.length, runtimeVerified:false};
}

module.exports={header,verify};
if(require.main===module) {
    try {
        const [nativePath,metadataPath]=process.argv.slice(2);
        if(!nativePath || !metadataPath) throw Error('Usage: node tools/verify_max_native.cjs UnityFramework global-metadata.dat');
        console.log(JSON.stringify(verify(fs.readFileSync(nativePath),fs.readFileSync(metadataPath)),null,2));
    } catch(error) { console.error(error.message); process.exitCode=1; }
}
