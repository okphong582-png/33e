// A small model of the emitted IFix instructions with mocked Unity calls.
// These tests check control flow and stack use, not execution in the real game.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {inspect}=require('./inspect_patch.cjs');
const p=inspect(fs.readFileSync(process.argv[2]||path.join(__dirname,'dist/Assembly-CSharp-patch.bytes')));
const bindings=require('./bindings.json');
assert.deepEqual(p.types,bindings.types);assert.deepEqual(p.externMethods,bindings.externMethods);
assert.deepEqual(p.fields,bindings.fields);assert.deepEqual(p.fixes,bindings.fixes);
assert.equal(p.methods.length,4);assert.equal(p.strings[0],'__33e_menu_driver');
assert.equal(p.externMethods[bindings.originalExternIds.indexOf(54)].name,'get_localScale');
assert.equal(p.externMethods[bindings.originalExternIds.indexOf(54)].owner.split(',')[0],'UnityEngine.Transform');
const expectedAPIs={200:'COW.GamePlay.Player.IsInStealth',201:'COW.GameFacade.CurrentMatch',202:'COW.GamePlay.JMAGGLCNGIG.ILPNGCMEFFI',203:'UnityEngine.Camera.get_main',204:'System.Collections.IList.get_Item',205:'System.Collections.ICollection.get_Count',206:'COW.GamePlay.Player.IsLocalPlayer',207:'COW.GamePlay.Player.get_CurHP',208:'COW.GamePlay.Player.IsLocalTeammate',209:'UnityEngine.GameObject.get_activeInHierarchy',210:'COW.GamePlay.Player.get_RootTransform',211:'COW.GamePlay.Player.GetHeadTF',212:'UnityEngine.Transform.get_position',213:'UnityEngine.Camera.WorldToScreenPoint',214:'UnityEngine.Screen.get_height',215:'UnityEngine.Screen.get_width',216:'System.Single.IsNaN',217:'System.Single.IsInfinity',218:'UnityEngine.GameObject.GetComponent'};
for(const [alias,expected] of Object.entries(expectedAPIs)){const m=p.externMethods[bindings.originalExternIds.indexOf(Number(alias))];assert.equal(m.owner.split(',')[0]+'.'+m.name,expected,'Runtime API binding '+alias);}
for(const method of p.methods){for(const [index,i] of method.instructions.entries()){if([42,62,115,130,132,46,173,165].includes(i.code))assert.ok(index+i.operand>0&&index+i.operand<method.instructions.length,'Branch target in bounds');}}
assert.ok(!p.externMethods.some(m=>/touchCount|GetTouch|SetAimRotation|LockedAiming|UnityWebRequest/.test(m.name)));
const world=new Map();let original=true,stealth=true,baseCalls=0,stealthCalls=0,draw=[],rects=[],event=null,guiColor={r:0.3,g:0.4,b:0.5,a:1},guiMatrix={tag:'initial-matrix'};
let match={players:[]},camera={tag:'camera'};
function object(name){return {name,transform:{localScale:{x:1,y:1,z:1}},component:null};}
function run(id,self){
 const code=p.methods[id].instructions,locals=Array(code[0].operand>>>16).fill(null),stack=[];
 const pop=()=>{assert.ok(stack.length,'Stack underflow');return stack.pop();};
 const deref=v=>v&&v.ref!==undefined?locals[v.ref]:v;
 const returns={0:true,2:true,4:true,7:true,9:true,10:true,11:true,13:true,54:true,57:true,93:true,94:true,95:true,129:true,130:true,131:true,132:true,141:true,142:true,143:true,145:true,146:true,200:true};
 for(let api=201;api<=218;api++)returns[api]=true;
 for(let pc=1,steps=0;pc<code.length;pc++){
  assert.ok(++steps<100000,'Loop did not terminate');const {code:op,operand:n}=code[pc];
  switch(op){
   case 28:assert.equal(n,0);stack.push(self);break;
   case 17:stack.push(null);break;
   case 16:stack.push(p.strings[n]);break;
   case 180:stack.push(n);break;
   case 3:{const b=Buffer.alloc(4);b.writeInt32LE(n);stack.push(b.readFloatLE());break;}
   case 20:{assert.ok(n<locals.length);const v=locals[n];stack.push(v&&typeof v==='object'&&('z' in v||'width' in v||'r' in v)?structuredClone(v):v);break;}
   case 176:assert.ok(n<locals.length);locals[n]=pop();break;
   case 95:assert.ok(n<locals.length);stack.push({ref:n});break;
   case 38:stack.push(deref(pop())[p.fields[n].name]);break;
   case 4:{const value=pop(),target=deref(pop());target[p.fields[n].name]=value;break;}
   case 126:stack.push(p.types[n]);break;
   case 89:break;
   case 52:stack.push(Number(pop()));break;
   case 67:{const b=pop(),a=pop();stack.push(a===b?1:0);break;}
   case 40:{const b=pop(),a=pop();stack.push(a*b);break;}
   case 96:{const b=pop(),a=pop();stack.push(a-b);break;}
   case 174:{const b=pop(),a=pop();stack.push(a+b);break;}
   case 130:case 132:case 46:case 173:{const b=pop(),a=pop();if(op===130?a<b:op===132?a<=b:op===46?a>b:a>=b)pc+=n-1;break;}
   case 142:{const v=pop();stack.push(v&&v.isPlayer?v:null);break;}
   case 151:assert.equal(n,3);run(3,undefined);break;
   case 161:pop();break;
   case 62:if(!pop())pc+=n-1;break;
   case 115:if(pop())pc+=n-1;break;
   case 165:{const b=pop(),a=pop();if(a!==b)pc+=n-1;break;}
   case 42:pc+=n-1;break;
   case 136:{assert.equal(stack.length,n);return n?pop():undefined;}
   case 175:case 106:{
    const count=n>>>16,index=n&65535,old=bindings.originalExternIds[index],m=p.externMethods[index];
    assert.ok(m,'Unknown extern');const args=stack.splice(stack.length-count,count).map(deref);assert.equal(args.length,count);
    let value;
    switch(old){
     case 0:value=args[0]===args[1];break;
     case 2:value=world.get(args[0])||null;break;
     case 4:case 10:value=args[0].transform;break;
     case 7:value=args[0].gameObject;break;
     case 9:value=object(args[0]);world.set(args[0],value);break;
     case 11:value={x:args[0],y:args[1],z:args[2]};break;
     case 12:args[0].localScale=structuredClone(args[1]);break;
     case 13:value={gameObject:args[0]};args[0].component=value;break;
     case 14:args[0].persistent=true;break;
     case 54:value=structuredClone(args[0].localScale);break;
     case 57:baseCalls++;value=original;break;
     case 93:value=event;break;
     case 94:value=args[0].name;break;
     case 95:value=args[0]!==args[1];break;
     case 129:value={x:args[0],y:args[1],width:args[2],height:args[3]};break;
     case 130:value=args[0].mousePosition;break;
     case 131:value=args[0].type;break;
     case 132:{const [r,v]=args;value=v.x>=r.x&&v.x<r.x+r.width&&v.y>=r.y&&v.y<r.y+r.height;break;}
     case 138:args[0].type=12;event.type=12;break;
     case 141:value=structuredClone(guiMatrix);break;
     case 142:value=structuredClone(guiColor);break;
     case 143:value={tag:'identity'};break;
     case 144:guiMatrix=structuredClone(args[0]);break;
     case 145:value={texture:true};break;
     case 146:value={r:args[0],g:args[1],b:args[2],a:args[3]};break;
     case 147:guiColor=structuredClone(args[0]);break;
     case 148:rects.push({rect:structuredClone(args[0]),color:structuredClone(guiColor)});break;
     case 149:draw.push(args[1]);break;
     case 200:stealthCalls++;value=stealth;break;
     case 201:value=match;break;
     case 202:value=args[0].players;break;
     case 203:value=camera;break;
     case 204:value=args[0][args[1]];break;
     case 205:value=args[0].length;break;
     case 206:value=!!args[0].local;break;
     case 207:value=args[0].hp;break;
     case 208:value=!!args[0].teammate;break;
     case 209:value=args[0].active;break;
     case 210:value=args[0].root;break;
     case 211:value=args[0].head;break;
     case 212:value=args[0].position;break;
     case 213:assert.equal(args[0],camera);value=structuredClone(args[1]);break;
     case 214:value=720;break;
     case 215:value=1280;break;
     case 216:value=Number.isNaN(args[0]);break;
     case 217:value=!Number.isFinite(args[0]);break;
     case 218:value=args[0].component;break;
     default:assert.fail('Unexpected extern '+old);
    }
    if(returns[old])stack.push(value);break;
   }
   default:assert.fail('Unsupported opcode '+op);
  }
  assert.ok(stack.length<=(code[0].operand&65535),'Exceeded declared max stack');
 }
 assert.fail('Fell off end');
}
const player={};assert.equal(run(0,player),true);assert.equal(baseCalls,1);
const driver=world.get('__33e_menu_driver');assert.ok(driver.persistent);assert.ok(driver.component);
original=false;assert.equal(run(0,player),false);assert.equal(world.size,1);assert.equal(baseCalls,2);
world.clear();assert.equal(run(2,player),true);const stealthDriver=world.get('__33e_menu_driver');assert.ok(stealthDriver.component);assert.equal(stealthCalls,1);
stealth=false;assert.equal(run(2,player),false);assert.equal(world.size,1);assert.equal(stealthCalls,2);
stealthDriver.component=null;run(2,player);assert.ok(stealthDriver.component,'Restore missing driver component');
const originalColor=structuredClone(guiColor),originalMatrix=structuredClone(guiMatrix);
function frame(type=7,x=0,y=0){event={type,mousePosition:{x,y}};draw=[];rects=[];run(1,driver.component);assert.deepEqual(guiColor,originalColor);assert.deepEqual(guiMatrix,originalMatrix);return draw;}
function boxRects(){return rects.filter(r=>r.color.r<0.1&&r.color.g>0.9).map(r=>r.rect);}
function enemy(options={}){return {isPlayer:true,hp:100,local:false,teammate:false,root:{position:{x:500,y:100,z:10}},head:{position:{x:500,y:300,z:10}},gameObject:{active:true},...options};}
assert.ok(frame().includes('ESP BOX: ON'));
const target=enemy();match.players=[target];const snapshot=JSON.stringify(target);frame();assert.equal(JSON.stringify(target),snapshot,'Rendering must not mutate the player');
assert.deepEqual(boxRects(),[{x:450,y:420,width:100,height:2},{x:450,y:618,width:100,height:2},{x:450,y:420,width:2,height:200},{x:548,y:420,width:2,height:200}]);
frame(1,60,110);assert.equal(driver.transform.localScale.y,0);assert.ok(frame().includes('ESP BOX: OFF'));assert.equal(boxRects().length,0);
frame(1,60,110);assert.equal(driver.transform.localScale.y,1);frame();assert.equal(boxRects().length,4);
frame(0,60,110);assert.equal(driver.transform.localScale.y,1,'MouseDown must not toggle twice');assert.equal(boxRects().length,0,'Draw ESP only on Repaint');
frame(1,800,800);assert.equal(driver.transform.localScale.y,1,'Outside taps ignored');
for(const invalid of [null,{},enemy({local:true}),enemy({teammate:true}),enemy({hp:0}),enemy({head:null}),enemy({root:null}),enemy({gameObject:{active:false}}),enemy({head:{position:{x:500,y:300,z:-1}}}),enemy({head:{position:{x:NaN,y:300,z:10}}}),enemy({head:{position:{x:Infinity,y:300,z:10}}}),enemy({head:{position:{x:500,y:90,z:10}}}),enemy({root:{position:{x:5000,y:100,z:10}},head:{position:{x:5000,y:300,z:10}}})]){match.players=[invalid];frame();assert.equal(boxRects().length,0,'Invalid/non-enemy targets must be skipped');assert.ok(draw.includes('ESP BOX: ON'),'Menu must stay visible');}
match.players=[enemy(),enemy({teammate:true}),enemy()];frame();assert.equal(boxRects().length,8);
match.players=Array.from({length:150},()=>enemy());frame();assert.equal(boxRects().length,128*4,'Bounded list traversal');
for(const missing of ['match','players','camera']){match={players:[enemy()]};camera={tag:'camera'};if(missing==='match')match=null;if(missing==='players')match.players=null;if(missing==='camera')camera=null;frame();assert.equal(boxRects().length,0);assert.ok(draw.includes('ESP BOX: ON'));}
event=null;draw=[];run(1,driver.component);assert.equal(draw.length,0);
event={type:7,mousePosition:{x:0,y:0}};run(1,null);run(1,{gameObject:object('other')});assert.equal(draw.length,0);
console.log('PASS: typed bindings, both bootstrap paths, original getter results, persistent driver, always-visible menu, ESP toggle, exact four-edge geometry, enemy filtering, projection validation, missing-match handling, bounded traversal, no player writes, color/matrix restoration, stack bounds. Mock VM only; device unverified.');
