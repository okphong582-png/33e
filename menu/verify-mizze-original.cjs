const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const dir=path.join(__dirname,'mizze-original'),current=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-hashes.json'),'utf8')),baseline=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-baseline-hashes.json'),'utf8'));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for(const f of current)assert.equal(hash(path.join(dir,f.name)),f.sha256,'Reviewed old-source file changed: '+f.name);
for(const name of ['CompilerHost.cs','MizzeLicense.cs','native-loader.cjs'])assert.equal(hash(path.join(dir,name)),baseline.find(f=>f.name===name).sha256,'Original lifecycle/gameplay component changed: '+name);
console.log('PASS: '+current.length+' reviewed files match; original four-hook compiler, license and native loader preserved.');
