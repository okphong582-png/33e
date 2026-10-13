const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'tests/build');fs.mkdirSync(out,{recursive:true});
const compiler=process.env.CXX||(process.platform==='win32'?'C:/Program Files/Windhawk/Compiler/bin/clang++.exe':'c++');
for(const name of ['freefire_reader_test','overlay_startup_schedule_test']) {
const exe=path.join(out,name+(process.platform==='win32'?'.exe':''));
const args=['-std=c++17','-Wall','-Wextra','-Werror',path.join(__dirname,name+'.cpp'),'-o',exe];
if(process.platform==='win32')args.unshift('--target=x86_64-w64-windows-gnu','-static');
for(const [command,argv]of [[compiler,args],[exe,[]]]){const r=cp.spawnSync(command,argv,{encoding:'utf8',windowsHide:true});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);if(r.error)throw r.error;if(r.status!==0)process.exit(r.status||1);}
}
