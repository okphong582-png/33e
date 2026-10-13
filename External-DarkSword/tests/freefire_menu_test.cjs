const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'../Resources/overlay_menu.html'),'utf8'),script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script);
function node(){const classes=new Set();return{style:{},textContent:'',value:'',classList:{toggle(k,v){if(v)classes.add(k);else classes.delete(k);},add(k){classes.add(k);},remove(k){classes.delete(k);},contains(k){return classes.has(k);}}};}
const title=node(),cameraTab=node(),cameraPanel=node(),espTab=node(),espPanel=node(),slider=node(),cameraValue=node(),espTitle=node();
const keys=['espEnabled','hackMapEnabled','showsLine','showsBox','showsHealth','showsName','showsDistance'];
const switches=keys.map(key=>{const b=node(),row=node();b.dataset={key};row.querySelector=()=>espTitle;b.closest=()=>row;return b;});
const selectors={'.title':title,'[data-tab="camera"]':cameraTab,'[data-panel="camera"]':cameraPanel,'[data-tab="esp"]':espTab,'[data-panel="esp"]':espPanel,'[data-key="espEnabled"]':switches[0]};
const document={querySelector:s=>selectors[s],querySelectorAll:s=>s==='.switch[data-key]'?switches:[cameraTab,cameraPanel,espTab,espPanel],getElementById:id=>id==='cameraHeight'?slider:cameraValue};
const body=script.slice(script.indexOf('      function renderState() {'),script.indexOf('      function renderLayout() {'));
const context={state:{game:'freefire',espEnabled:true},document};vm.createContext(context);vm.runInContext(body,context);
cameraTab.classList.add('active');context.renderState();
assert.equal(title.textContent,'Mizze');assert.equal(switches[0].closest().style.display,'');for(const b of switches.slice(1))assert.equal(b.closest().style.display,'none');
assert.equal(cameraTab.style.display,'none');assert.equal(cameraPanel.style.display,'none');assert(espPanel.classList.contains('active'));assert.equal(espTitle.textContent,'ESP Box');
context.state={game:'aov',espEnabled:false,showsLine:true};context.renderState();assert.equal(title.textContent,'Mizze');assert.equal(cameraTab.style.display,'');for(const b of switches)assert.equal(b.closest().style.display,'');
assert.match(script,/game: state\.game \|\| "aov"/);
assert.match(script,/message\.game = overlayGame/);
const apply=script.slice(script.indexOf('      function applyPayload(raw) {'),script.indexOf('      function connect() {'));
const isolated={overlayGame:'freefire',state:{},layout:{},renderState(){},renderLayout(){}};vm.createContext(isolated);vm.runInContext(apply,isolated);
isolated.applyPayload(JSON.stringify({type:'state',state:{game:'aov',espEnabled:true}}));assert.equal(isolated.state.espEnabled,undefined);
isolated.applyPayload(JSON.stringify({type:'state',state:{game:'freefire',espEnabled:true}}));assert.equal(isolated.state.espEnabled,true);
isolated.applyPayload(JSON.stringify({type:'overlayLayout',game:'aov',layout:{screenWidth:999}}));assert.equal(isolated.layout.screenWidth,undefined);
for(const file of ['overlay_esp.html','overlay_fab.html']) {
    const source=fs.readFileSync(path.join(__dirname,'../Resources',file),'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];new vm.Script(source);assert.match(source,/message\.game = overlayGame/);
    if(file==='overlay_esp.html') {
        const handler=source.slice(source.indexOf('        socket.onmessage = function (event) {'),source.indexOf('        socket.onclose = function () {'));
        const esp={overlayGame:'freefire',entities:[1],socket:{}};vm.createContext(esp);vm.runInContext(handler,esp);
        esp.socket.onmessage({data:JSON.stringify({type:'targets',game:'aov',targets:[2]})});assert.equal(esp.entities.length,0);
        esp.socket.onmessage({data:JSON.stringify({type:'targets',game:'freefire',targets:[3]})});assert.deepEqual(Array.from(esp.entities),[3]);
    }
}
console.log('PASS: three overlay scripts parse; FF has one ESP toggle; camera/AoV controls restore; state, layout, targets and input are scoped by game.');
