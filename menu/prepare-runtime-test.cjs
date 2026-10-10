// Keep upstream interpreter code unchanged except for the game's enum numbering.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(process.argv[2]),out=path.join(__dirname,'runtime-test');
assert.equal(cp.execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),'5ba42eb8f63fe37134a3c78690f97d8425e13588','Pinned upstream interpreter');
fs.mkdirSync(out,{recursive:true});
const ops=require('./game-opcodes.json');
for(const name of fs.readdirSync(path.join(root,'Source/VSProj/Src/Core')).filter(n=>n.endsWith('.cs'))){
 let source=fs.readFileSync(path.join(root,'Source/VSProj/Src/Core',name),'utf8');
 if(name==='Instruction.cs')source=source.replace(/public enum Code\s*\{[\s\S]*?\n\s*\}/,'public enum Code\n{\n'+Object.entries(ops).map(([n,v])=>'    '+n+' = '+v+',').join('\n')+'\n}');
 fs.writeFileSync(path.join(out,name),source);
}
console.log('Prepared pinned Tencent IFix interpreter with game opcode numbers.');
