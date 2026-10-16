const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const dir=path.join(__dirname,'mizze-original'),current=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-hashes.json'))),contract=JSON.parse(fs.readFileSync(path.join(dir,'esp-compatibility-baseline.json')));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for(const file of current)assert.equal(hash(path.join(dir,file.name)),file.sha256,'Reviewed ESP source changed: '+file.name);
function methods(text){const result=new Map(),re=/public (?:static )?\w+(?:\[\])? (\w+)\([^)]*\)\s*\{/g;let m;while((m=re.exec(text))){let end=re.lastIndex,depth=1;while(depth&&end<text.length){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++;}result.set(m[1],text.slice(m.index,end).replaceAll('\r\n','\n'));re.lastIndex=end;}return result;}
const allowed={'Mizze.cs':['MzFill','MzLine','MzCircle'],'MizzeGameplay.cs':['MzBox3D','MzSampleEsp'],'MizzeRenderer.cs':['MzTrimCommands','MzCommand','MzDrawCommands','MzRender'],'MizzeBatch.cs':['MzBatchInit']};
for(const [file,source] of Object.entries(contract.sources)){const edited=methods(fs.readFileSync(path.join(dir,file),'utf8'));for(const [name,body] of methods(source))if(!(allowed[file]||[]).includes(name))assert.equal(edited.get(name),body,'Protected original method changed: '+file+' '+name);}
const protectedFiles=['GameBindings.cs','build.cjs','package.cjs','MizzeAppearance.cs','MizzeLicense.cs','CompilerHost.cs','GuiBindings.cs','UnityBindings.cs','PhysicsBindings.cs','NetworkBindings.cs','TextBindings.cs','JsonBindings.cs'];
const baseline=JSON.parse(fs.readFileSync(path.join(__dirname,'mizze-original-ui-baseline-hashes.json')));
for(const file of baseline)if(protectedFiles.includes(file.name)){
    if(file.name==='package.cjs'){
        // Only the verified game-native hook lookup flag may differ from the old serializer.
        const text=fs.readFileSync(path.join(dir,file.name),'utf8');
        assert.equal(text.split('bit(true);list(p.fixes').length,2,'Native hook lookup flag missing or repeated');
        const original=text.replace('bit(true);list(p.fixes','bit(false);list(p.fixes');
        assert.equal(crypto.createHash('sha256').update(original).digest('hex'),file.sha256,'Other serializer changes');
    }else assert.equal(hash(path.join(dir,file.name)),file.sha256,'Protected UI/license/compiler source changed: '+file.name);
}
console.log('PASS: reviewed ESP scope; original bootstrap, OnGUI, paint/font/GIF, aim, license and hooks preserved.');
