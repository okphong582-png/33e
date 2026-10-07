const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const html=fs.readFileSync('firebase/license-key.html','utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
class Element {
  constructor(){this.value='';this.innerHTML='';this.textContent='';this.style={};this.events={};this.dataset={};this.disabled=false;
    const active=new Set();this.classList={add:x=>active.add(x),remove:x=>active.delete(x),contains:x=>active.has(x)};}
  addEventListener(event,fn){this.events[event]=fn;}
  appendChild(){}removeChild(){}select(){}click(){}getAttribute(){return '';}
}
const elements=new Map();function element(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);}
element('customDays').value='30';element('rulesCodeText').textContent=fs.readFileSync('firebase/database.rules.json','utf8');
const store=()=>{const map=new Map();return {getItem:k=>map.get(k)||null,setItem:(k,v)=>map.set(k,v),removeItem:k=>map.delete(k)};};
const sessionStorage=store();sessionStorage.setItem('license_db_secret','test-only-admin-token');
const database=new Map(),writes=[];
const context=vm.createContext({document:{getElementById:element,querySelectorAll:()=>[],createElement:()=>new Element(),body:new Element(),execCommand:()=>true},
  localStorage:store(),sessionStorage,crypto:crypto.webcrypto,TextEncoder,console:{log(){},warn(){}},
  setTimeout:()=>0,setInterval:()=>0,clearInterval(){},confirm:()=>true,navigator:{clipboard:{writeText:async()=>{}}},
  Blob,URL,fetch:async(url,options={})=>{
    const p=new URL(url).pathname,method=options.method||'GET';let status=200;
    if(method!=='GET') {
      writes.push({path:p,method,headers:options.headers,body:options.body ? JSON.parse(options.body) : null});
      if(options.headers?.['if-match']==='null_etag' && database.has(p))status=412;
      else if(method==='PUT')database.set(p,JSON.parse(options.body));
      else if(method==='DELETE')database.delete(p);
      else if(method==='PATCH')database.set(p,{...database.get(p),...JSON.parse(options.body)});
    }
    const data=database.get(p) || null;
    return {ok:status===200,status,json:async()=>data,text:async()=>JSON.stringify(data)};
  }});
vm.runInContext(script,context);
async function settle(){await new Promise(resolve=>setImmediate(resolve));}
const digest=key=>crypto.createHash('sha256').update(key).digest('hex');
(async()=>{
  await settle();
  element('keyInput').value='NEW-DEVICE-TEST';element('noteInput').value='<img src=x onerror=alert(1)>';
  await element('btnSubmitGenerate').events.click();
  const path=`/licensesV3/${digest('NEW-DEVICE-TEST')}.json`;
  assert.equal(database.get(path).protocol,3);assert.equal(database.get(path).enabled,true);
  assert.equal(writes.find(x=>x.path===path).headers['if-match'],'null_etag');
  assert(!writes.some(x=>x.path.startsWith('/licenses/')));
  // Creating an existing V3 key cannot replace or release a machine binding.
  const bound={...database.get(path),binding:{deviceHash:'a'.repeat(64),version:1,claimedAt:1}};database.set(path,bound);
  element('keyInput').value='NEW-DEVICE-TEST';await element('btnSubmitGenerate').events.click();
  assert.deepEqual(database.get(path),bound);
  // A key already usable by the old app is not silently reissued as a new key.
  const legacyHash=digest('LEGACY-KEY-TEST');database.set(`/licenses/${legacyHash}.json`,{enabled:true});
  element('keyInput').value='LEGACY-KEY-TEST';await element('btnSubmitGenerate').events.click();
  assert(!database.has(`/licensesV3/${legacyHash}.json`));
  const v2Hash=digest('EXISTING-V2-KEY');database.set(`/licensesV2/${v2Hash}.json`,{enabled:true});
  element('keyInput').value='EXISTING-V2-KEY';await element('btnSubmitGenerate').events.click();
  assert(!database.has(`/licensesV3/${v2Hash}.json`));
  vm.runInContext(`allLicenses=[{hash:'a'.repeat(64),key:'XSS-KEY',note:'<img src=x onerror=alert(1)>',enabled:true,expiresAt:Date.now()+60000,binding:{deviceHash:'b'.repeat(64)}}];renderTable();`,context);
  assert(element('keysTableBody').innerHTML.includes('&lt;img'));
  assert(!element('keysTableBody').innerHTML.includes('<img src=x'));
  assert(element('keysTableBody').innerHTML.includes('data-reset-device'));
  assert(element('keysTableBody').innerHTML.includes('Đã gắn 1 máy'));
  // Migration preserves the exact hash, expiration, notes and physical binding.
  const migratedHash=digest('KEEP-MY-KEY'),lockedHash=digest('LOCKED-KEY'),expiredHash=digest('EXPIRED-KEY');
  const original={enabled:true,protocol:2,expiresAt:Date.now()+60000,createdAt:12,key:'KEEP-MY-KEY',note:'Keep this note',binding:{deviceHash:'c'.repeat(64),version:1,claimedAt:123}};
  const disabled={enabled:false,expiresAt:Date.now()+60000,key:'LOCKED-KEY'};
  const expired={enabled:true,expiresAt:123,key:'EXPIRED-KEY'};
  database.set('/licenses.json',{[migratedHash]:{...original,expiresAt:1},[lockedHash]:disabled,[expiredHash]:expired});
  database.set('/licensesV2.json',{[migratedHash]:original});
  database.set('/licensesV3.json',{});
  database.set('/.settings/rules.json',{rules:{'.read':false,'.write':false,unrelated:{'.read':true}}});
  const beforeMigration=writes.length;
  await element('btnApplyRules').events.click();
  const migrated=database.get(`/licensesV3/${migratedHash}.json`);
  assert.deepEqual(migrated,{...original,protocol:3});
  assert.deepEqual(database.get(`/licensesV3/${lockedHash}.json`).lock,{until:0,message:'Key đang bị quản trị viên khóa.'});
  assert.equal(database.get(`/licensesV3/${expiredHash}.json`).expiresAt,123);
  assert.equal(database.get('/.settings/rules.json').rules.licensesV2['.read'],false);
  assert.equal(database.get('/.settings/rules.json').rules.unrelated['.read'],true);
  assert(!writes.slice(beforeMigration).some(x=>/^\/licenses(?:V2)?\//.test(x.path)));
  assert.deepEqual(database.get('/licensesV2.json')[migratedHash],original);
  // Rerunning cannot resurrect an unlocked key or replace its newer binding.
  const changed={...migrated,binding:{deviceHash:'d'.repeat(64),version:1,claimedAt:456},note:'Admin edited'};
  database.set(`/licensesV3/${migratedHash}.json`,changed);
  await element('btnApplyRules').events.click();
  assert.deepEqual(database.get(`/licensesV3/${migratedHash}.json`),changed);
  // Abort before rules change when any old record is malformed.
  database.set('/licensesV2.json',{[migratedHash]:{...original,binding:{deviceHash:'broken'}}});
  const rulesWrites=writes.filter(x=>x.path==='/.settings/rules.json').length;
  await element('btnApplyRules').events.click();
  assert.equal(writes.filter(x=>x.path==='/.settings/rules.json').length,rulesWrites);
  assert.equal(vm.runInContext(`lockUntil(2,'minutes',1000)`,context),121000);
  assert.equal(vm.runInContext(`lockUntil(2,'hours',1000)`,context),7201000);
  assert.equal(vm.runInContext(`lockUntil(2,'days',1000)`,context),172801000);
  assert.equal(vm.runInContext(`lockUntil(0,'permanent',1000)`,context),0);
  assert.throws(()=>vm.runInContext(`lockUntil(-1,'minutes',1000)`,context));
  context.lockFixture={hash:migratedHash,...changed};
  vm.runInContext('allLicenses=[lockFixture];openLockModal(lockFixture.hash);',context);
  element('lockMessage').value='<img src=x onerror=alert(1)>';element('lockDuration').value='2';element('lockUnit').value='minutes';
  const lockStarted=Date.now();await element('btnConfirmLock').events.click();
  const locked=database.get(`/licensesV3/${migratedHash}.json`);
  assert.equal(locked.lock.message,'<img src=x onerror=alert(1)>');
  assert(locked.lock.until>=lockStarted+120000&&locked.lock.until<=Date.now()+120000);
  assert.deepEqual(locked.binding,changed.binding);assert.equal(locked.expiresAt,changed.expiresAt);
  assert(!element('keysTableBody').innerHTML.includes('<img src=x'));
  assert(element('keysTableBody').innerHTML.includes('&lt;img'));
  await vm.runInContext('toggleKeyStatus(lockFixture.hash,true)',context);
  const unlocked=database.get(`/licensesV3/${migratedHash}.json`);
  assert.equal(unlocked.lock,null);assert.equal(unlocked.enabled,true);
  assert.deepEqual(unlocked.binding,changed.binding);assert.equal(unlocked.expiresAt,changed.expiresAt);
   assert.equal(context.localStorage.getItem('license_db_secret'),'test-only-admin-token');
   element('cfgDatabaseUrl').value='https://example-default-rtdb.firebaseio.com/';
   element('cfgDatabaseSecret').value=' saved-test-token ';
   element('btnSaveSettings').events.click();await settle();
   assert.equal(context.localStorage.getItem('license_db_secret'),'saved-test-token');
   // A completely fresh browser session reads the saved secret from local storage.
   const reloaded=vm.createContext({...context,sessionStorage:store()});
   vm.runInContext(script,reloaded);await settle();
   assert.equal(vm.runInContext('databaseSecret',reloaded),'saved-test-token');
   assert.equal(vm.runInContext('databaseURL',reloaded),'https://example-default-rtdb.firebaseio.com');
   element('cfgDatabaseSecret').value='';element('btnSaveSettings').events.click();await settle();
   assert.equal(context.localStorage.getItem('license_db_secret'),null);
   assert.equal(reloaded.sessionStorage.getItem('license_db_secret'),null);
   assert.equal(vm.runInContext(`saveSetting({setItem(){throw Error('blocked')}},'token','test')`,reloaded),false);
   console.log('License web: V1/V2 preservation, retry-safe migration, malformed-data abort, lock durations, duplicate protection, binding display, persistent secret and escaped notes passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
