// Verify that restoring the original source reproduces its original patch exactly.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const dir=path.join(__dirname,'mizze-original/dist'),data=fs.readFileSync(path.join(dir,'Assembly-CSharp-patch.bytes'));
const expected='381851f75838863ae972fff7165e447e72caed8bb7afea727620e8b086e2b6e9',actual=crypto.createHash('sha256').update(data).digest('hex');
assert.equal(actual,expected,'Untouched-source patch differs from original build');assert.equal(data.length,72484);
const report={edition:'Original untouched 24-file source',baselineCommit:'6b9053afadef350ae9a27e4b5a5d5b55f39f200f',sha256:actual,size:data.length,byteIdenticalToOriginalBuild:true,deviceVerified:false};
fs.writeFileSync(path.join(dir,'restore-verification.json'),JSON.stringify(report,null,2)+'\n');console.log('PASS: restored patch is byte-for-byte identical to original build '+actual);
