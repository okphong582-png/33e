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
  const path=`/licensesV2/${digest('NEW-DEVICE-TEST')}.json`;
  assert.equal(database.get(path).protocol,2);assert.equal(database.get(path).enabled,true);
  assert.equal(writes.find(x=>x.path===path).headers['if-match'],'null_etag');
  assert(!writes.some(x=>x.path.startsWith('/licenses/')));
  // Creating an existing V2 key cannot replace or release a machine binding.
  const bound={...database.get(path),binding:{deviceHash:'a'.repeat(64),version:1,claimedAt:1}};database.set(path,bound);
  element('keyInput').value='NEW-DEVICE-TEST';await element('btnSubmitGenerate').events.click();
  assert.deepEqual(database.get(path),bound);
  // A key already usable by the old app is not silently reissued as a new key.
  const legacyHash=digest('LEGACY-KEY-TEST');database.set(`/licenses/${legacyHash}.json`,{enabled:true});
  element('keyInput').value='LEGACY-KEY-TEST';await element('btnSubmitGenerate').events.click();
  assert(!database.has(`/licensesV2/${legacyHash}.json`));
  vm.runInContext(`allLicenses=[{hash:'a'.repeat(64),key:'XSS-KEY',note:'<img src=x onerror=alert(1)>',enabled:true,expiresAt:Date.now()+60000,binding:{deviceHash:'b'.repeat(64)}}];renderTable();`,context);
  assert(element('keysTableBody').innerHTML.includes('&lt;img'));
  assert(!element('keysTableBody').innerHTML.includes('<img src=x'));
  assert(element('keysTableBody').innerHTML.includes('data-reset-device'));
  assert(element('keysTableBody').innerHTML.includes('Đã gắn 1 máy'));
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
  console.log('License web: new-only keys, duplicate protection, legacy separation, binding display and escaped notes passed.');
})().catch(error=>{console.error(error);process.exitCode=1;});
