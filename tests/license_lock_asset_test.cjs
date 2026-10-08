const fs=require('node:fs'),assert=require('node:assert/strict');
const source=fs.readFileSync('sources/LicenseLockImage.inc','utf8');
const parts=[...source.matchAll(/@"([A-Za-z0-9+/=]+)"/g)].map(x=>x[1]);
const embedded=Buffer.from(parts.join(''),'base64');
const original=fs.readFileSync('firebase/assets/license-lock.jpg');
assert(original.length>0&&original.length<1024*1024);
assert.equal(embedded.compare(original),0,'The dylib/TIPA image must match the administrator preview');
assert.equal(embedded.readUInt16BE(0),0xffd8);
console.log('Lock artwork: embedded client image matches the original JPEG and web preview.');
