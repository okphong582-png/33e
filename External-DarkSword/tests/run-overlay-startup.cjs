// Execute the production overlay implementation against a deterministic remote
// runtime double. No iOS runtime injection is performed by this test.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(__dirname,'build');fs.mkdirSync(out,{recursive:true});
const strip=s=>s.replace(/^#import.*$/gm,'');
const source=fs.readFileSync(path.join(root,'Features/Overlay/RemoteWebViewOverlay.m'),'utf8');
const header=fs.readFileSync(path.join(root,'Features/Overlay/RemoteWebViewOverlay.h'),'utf8');
const fixture=fs.readFileSync(path.join(__dirname,'overlay_startup_fixture.mm'),'utf8');
const [before,after]=fixture.split('// INSERT_PRODUCTION_OVERLAY');
const generated=path.join(out,'overlay-startup.mm'),exe=path.join(out,'overlay-startup');
fs.writeFileSync(generated,before+strip(header)+strip(source)+after);
for(const [command,args] of [['clang++',['-std=c++17','-fobjc-arc','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-Wno-format','-framework','Foundation','-framework','CoreGraphics',generated,'-o',exe]],[exe,[]]]){
 const r=cp.spawnSync(command,args,{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.error)throw r.error;if(r.status)process.exit(r.status);
}
