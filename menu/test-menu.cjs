// A small model of the emitted IFix instructions with mocked Unity calls.
// These tests check control flow and stack use, not execution in the real game.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {inspect}=require('./inspect_patch.cjs');
const p=inspect(fs.readFileSync(process.argv[2]||path.join(__dirname,'dist/Assembly-CSharp-patch.bytes')));
const bindings=require('./bindings.json');
assert.deepEqual(p.types,bindings.types);assert.deepEqual(p.externMethods,bindings.externMethods);
assert.deepEqual(p.fields,bindings.fields);assert.deepEqual(p.fixes,bindings.fixes);
assert.equal(p.methods.length,2);assert.equal(p.strings[0],'__33e_menu_driver');
const world=new Map();let original=true,baseCalls=0,draw=[],event=null,guiColor={r:0.3,g:0.4,b:0.5,a:1};
function object(name){return {name,transform:{localScale:{x:1,y:1,z:1}},component:null};}
function run(id,self){
 const code=p.methods[id].instructions,locals=Array(code[0].operand>>>16).fill(null),stack=[];
 const pop=()=>{assert.ok(stack.length,'Stack underflow');return stack.pop();};
 const deref=v=>v&&v.ref!==undefined?locals[v.ref]:v;
 const returns={0:true,2:true,4:true,7:true,9:true,10:true,11:true,13:true,54:true,57:true,93:true,94:true,95:true,129:true,130:true,131:true,132:true,141:true,142:true,143:true,145:true,146:true};
 for(let pc=1,steps=0;pc<code.length;pc++){
  assert.ok(++steps<2000,'Loop did not terminate');const {code:op,operand:n}=code[pc];
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
     case 142:value=structuredClone(guiColor);break;
     case 145:value={texture:true};break;
     case 146:value={r:args[0],g:args[1],b:args[2],a:args[3]};break;
     case 147:guiColor=structuredClone(args[0]);break;
     case 148:break;
     case 149:draw.push(args[1]);break;
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
const originalColor=structuredClone(guiColor);
function frame(type=7,x=0,y=0){event={type,mousePosition:{x,y}};draw=[];run(1,driver.component);assert.deepEqual(guiColor,originalColor);return draw;}
assert.ok(frame().includes('IFix menu loaded'));assert.ok(frame().includes('DEMO: OFF'));
frame(1,60,200);assert.equal(driver.transform.localScale.y,1);assert.ok(frame().includes('DEMO: ON'));
frame(1,60,200);assert.equal(driver.transform.localScale.y,0);
frame(1,320,45);assert.equal(driver.transform.localScale.x,1);assert.ok(frame().includes('MENU 33e - OPEN'));
frame(1,60,45);assert.equal(driver.transform.localScale.x,0);assert.ok(frame().includes('IFix menu loaded'));
frame(0,60,200);assert.equal(driver.transform.localScale.y,0,'MouseDown must not toggle twice');
frame(1,800,800);assert.equal(driver.transform.localScale.y,0,'Outside taps ignored');
event=null;draw=[];run(1,driver.component);assert.equal(draw.length,0);
event={type:7,mousePosition:{x:0,y:0}};run(1,null);run(1,{gameObject:object('other')});assert.equal(draw.length,0);
console.log('PASS: binary bindings, original getter result, single persistent driver, render, hide/open, demo toggle, outside taps, null event, color restoration, stack bounds. Mock VM only; device unverified.');
