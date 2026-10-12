const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(process.argv[2]),dir=__dirname,out=path.join(dir,'build');fs.mkdirSync(out,{recursive:true});
const csc=path.join(process.env.WINDIR||'C:/Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
function run(exe,args){const r=cp.spawnSync(exe,args,{encoding:'utf8',cwd:out});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.status!==0)throw Error('Build failed: '+path.basename(exe));}
function compile(name,sources,refs=[],extra=[]){run(csc,['/nologo','/codepage:65001','/optimize+','/unsafe','/target:library','/out:'+path.join(out,name),...refs.map(r=>'/reference:'+path.join(out,r)),...extra,...sources]);}
const core=path.join(dir,'../runtime-test');if(!fs.existsSync(core))throw Error('Run prepare-runtime-test.cjs first');
// Full core needed by translator, including bridge and patch-loading metadata.
compile('IFix.Core.dll',fs.readdirSync(core).filter(n=>n.endsWith('.cs')).map(n=>path.join(core,n)).concat([path.join(root,'Source/VSProj/Src/Builder/FileVirtualMachineBuilder.cs')]),[],['/nowarn:0169']);
for(const name of ['Mono.Cecil.dll','Mono.Cecil.Mdb.dll','Mono.Cecil.Pdb.dll'])fs.copyFileSync(path.join(root,'Source/VSProj/ThirdParty',name),path.join(out,name));
run(csc,['/nologo','/codepage:65001','/optimize+','/unsafe','/target:exe','/out:'+path.join(out,'CompilerHost.exe'),'/reference:'+path.join(out,'Mono.Cecil.dll'),'/reference:'+path.join(out,'Mono.Cecil.Mdb.dll'),'/reference:'+path.join(out,'Mono.Cecil.Pdb.dll'),path.join(dir,'CompilerHost.cs'),path.join(core,'Instruction.cs'),path.join(root,'Source/VSProj/Src/Version.cs'),...fs.readdirSync(path.join(root,'Source/VSProj/Src/Tools')).filter(n=>n.endsWith('.cs')&&n!=='CSFix.cs').map(n=>path.join(root,'Source/VSProj/Src/Tools',n))]);
compile('UnityEngine.CoreModule.dll',[path.join(dir,'UnityBindings.cs')]);
compile('UnityEngine.ImageConversionModule.dll',[path.join(dir,'ImageBindings.cs')],['UnityEngine.CoreModule.dll']);
compile('UnityEngine.TextRenderingModule.dll',[path.join(dir,'TextBindings.cs')]);
compile('UnityEngine.IMGUIModule.dll',[path.join(dir,'GuiBindings.cs')],['UnityEngine.CoreModule.dll','UnityEngine.TextRenderingModule.dll']);
compile('UnityEngine.PhysicsModule.dll',[path.join(dir,'PhysicsBindings.cs')],['UnityEngine.CoreModule.dll']);
compile('UnityEngine.UnityWebRequestModule.dll',[path.join(dir,'NetworkBindings.cs')],['UnityEngine.CoreModule.dll']);
compile('Assembly-CSharp.dll',['GameBindings.cs','JsonBindings.cs','Mizze.cs','MizzeGameplay.cs','MizzeLicense.cs','MizzeAppearance.cs','MizzeRenderer.cs','MizzeBatch.cs','MizzeGlass.cs','MizzeBackgroundData.cs','MizzeExtras.cs','MizzeEspBuffers.cs','MizzeMemory.cs'].map(n=>path.join(dir,n)),['UnityEngine.CoreModule.dll','UnityEngine.IMGUIModule.dll','UnityEngine.TextRenderingModule.dll','UnityEngine.PhysicsModule.dll','UnityEngine.UnityWebRequestModule.dll','UnityEngine.ImageConversionModule.dll']);
run(path.join(out,'CompilerHost.exe'),[path.join(out,'Assembly-CSharp.dll'),path.join(out,'IFix.Core.dll'),path.join(out,'upstream.bytes')]);
console.log('Translated CSharp source into upstream IFix bytes.');
