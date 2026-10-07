const assert=require('node:assert/strict');
const fs=require('node:fs');
const host=process.env.FIREBASE_DATABASE_EMULATOR_HOST;
assert(host,'Run through the Firebase Database emulator; never point this test at production.');
const base=`http://${host}/`,namespace='demo-mizze-device';
assert(['localhost','127.0.0.1','[::1]'].includes(new URL(base).hostname),'Only a local emulator is allowed.');
const hash='a'.repeat(64),deviceA='b'.repeat(64),deviceB='c'.repeat(64);
async function request(path,method='GET',body,admin=false,conditional=false) {
  const url=new URL(path+'.json',base);url.searchParams.set('ns',namespace);
  const headers={'Content-Type':'application/json'};
  if(admin)headers.Authorization='Bearer owner'; // Emulator-only administrator.
  if(conditional)headers['if-match']='null_etag';
  return fetch(url,{method,headers,body:body===undefined ? undefined : JSON.stringify(body)});
}
function binding(deviceHash){return {deviceHash,version:1,claimedAt:{'.sv':'timestamp'}};}
function denied(response){assert([401,403].includes(response.status),`Expected denial, got ${response.status}`);}
(async()=>{
  // Explicitly load the canonical rules into the namespace used by this test.
  // Firebase CLI versions differ in their default database namespace suffix.
  const rules=JSON.parse(fs.readFileSync('firebase/database.rules.json','utf8'));
  const applied=await request('.settings/rules','PUT',rules,true);
  assert(applied.ok,`Rules did not compile: ${await applied.text()}`);
  assert((await request('','DELETE',undefined,true)).ok);
  const path=`licensesV2/${hash}`;
  const license={enabled:true,expiresAt:Date.now()+3600000,protocol:2};
  denied(await request(path,'PUT',license));
  assert((await request(path,'PUT',license,true)).ok);
  denied(await request('licensesV2'));
  const legacy=await request(`licenses/${hash}`);assert(legacy.ok);assert.equal(await legacy.json(),null);
  // Two physical-device IDs attempting first activation simultaneously.
  const contenders=await Promise.all([deviceA,deviceB].map(id=>request(path+'/binding','PUT',binding(id),false,true)));
  assert.equal(contenders.filter(r=>r.ok).length,1);
  assert(contenders.some(r=>[401,403,412].includes(r.status)));
  const first=await (await request(path)).json();assert([deviceA,deviceB].includes(first.binding.deviceHash));
  denied(await request(path+'/binding','PUT',binding(deviceA)));
  denied(await request(path+'/binding','DELETE'));
  denied(await request(path,'PATCH',{enabled:false}));
  denied(await request(path,'PATCH',{expiresAt:Date.now()+7200000}));
  assert.deepEqual(await (await request(path)).json(),first);
  // Only an administrator can release a binding; malformed/expired claims fail.
  assert((await request(path+'/binding','DELETE',undefined,true)).ok);
  denied(await request(path+'/binding','PUT',binding('invalid'),false,true));
  denied(await request(path+'/binding','PUT',{...binding(deviceA),extra:true},false,true));
  assert((await request(path,'PATCH',{enabled:false},true)).ok);
  denied(await request(path+'/binding','PUT',binding(deviceA),false,true));
  assert((await request(path,'PATCH',{enabled:true,expiresAt:Date.now()-60000},true)).ok);
  denied(await request(path+'/binding','PUT',binding(deviceA),false,true));
  assert((await request(path,'PATCH',{expiresAt:Date.now()+3600000},true)).ok);
  assert((await request(path+'/binding','PUT',binding(deviceB),false,true)).ok);
  assert.equal((await (await request(path)).json()).binding.deviceHash,deviceB);
  console.log('Firebase V2 rules: one concurrent winner, immutable binding, denied public administration, expired/disabled denial and legacy isolation passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
