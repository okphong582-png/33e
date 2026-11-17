"""Build the one-method VN startup payload using the supplied INTEX compiler sources."""
from pathlib import Path
import hashlib
import json
import os
import struct
import subprocess
import sys
from zipfile import ZipFile

HERE = Path(__file__).resolve().parent
COMPILER_PREFIX = 'work/intex-hotfix/toolchain/Source/VSProj/'
MENU_PREFIX = 'work/intex-th-merge/menu/'


def build(archive, out):
    out.mkdir(exist_ok=False, parents=True)
    with ZipFile(archive) as z:
        for name in z.namelist():
            if name.startswith(COMPILER_PREFIX):
                relative = name[len(COMPILER_PREFIX):]
                category = 'compiler'
            elif name.startswith(MENU_PREFIX + 'runtime-test/') and name.endswith('.cs'):
                relative = name[len(MENU_PREFIX + 'runtime-test/'):]
                category = 'runtime'
            elif name == MENU_PREFIX + 'inspect_patch.cjs':
                relative = 'inspect_patch.cjs'
                category = 'tools'
            else:
                continue
            dest = (out / category / relative).resolve()
            assert dest.is_relative_to(out)
            if not name.endswith('/'):
                dest.parent.mkdir(exist_ok=True, parents=True)
                dest.write_bytes(z.read(name))

    csc = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    vendor = out/'compiler'
    runtime = out/'runtime'
    third_party = vendor/'ThirdParty'
    sources = vendor/'Src'
    for name in ('Mono.Cecil.dll', 'Mono.Cecil.Mdb.dll', 'Mono.Cecil.Pdb.dll'):
        (out/name).write_bytes((third_party/name).read_bytes())

    def compile_cs(name, inputs, references=()):
        output = out/name
        flags = ['/nologo', '/codepage:65001', '/optimize+', '/unsafe', '/nowarn:0169']
        command = [str(csc), *flags, '/target:' + ('exe' if output.suffix == '.exe' else 'library'),
                   '/out:' + str(output), *('/reference:' + str(out/ref) for ref in references)]
        subprocess.run([*command, *map(str, inputs)], check=True, cwd=out)

    compile_cs('IFix.Core.dll', [*sorted(runtime.glob('*.cs')), sources/'Builder/FileVirtualMachineBuilder.cs'])
    compile_cs('StartupCompiler.exe', [HERE/'StartupCompiler.cs', runtime/'Instruction.cs', sources/'Version.cs',
               *(p for p in sorted((sources/'Tools').glob('*.cs')) if p.name != 'CSFix.cs')],
               ['Mono.Cecil.dll', 'Mono.Cecil.Mdb.dll', 'Mono.Cecil.Pdb.dll'])
    compile_cs('UnityEngine.CoreModule.dll', [HERE/'UnityStartupBindings.cs'])
    compile_cs('Assembly-CSharp.dll', [HERE/'MizzeStartup.cs'], ['UnityEngine.CoreModule.dll'])
    upstream = out/'upstream.bytes'
    result = subprocess.run([str(out/'StartupCompiler.exe'), str(out/'Assembly-CSharp.dll'),
                    str(out/'IFix.Core.dll'), str(upstream)], cwd=out, check=True,
                    capture_output=True, text=True, errors='replace')
    print(result.stdout + result.stderr)
    assert not any(x in (result.stdout + result.stderr).lower() for x in ('not support il','not implement il'))

    def inspect(patch):
        js = "const [tool,file]=process.argv.slice(1);console.log(JSON.stringify(require(tool).inspect(require('fs').readFileSync(file))));"
        return json.loads(subprocess.check_output(['node','-e',js,str(out/'tools/inspect_patch.cjs'),str(patch)]))

    original = inspect(upstream)
    data = upstream.read_bytes()
    assert original['magic'] == '49e85d573d'
    assert not original['fields'] and not original['statics'] and not original['newClasses']
    fix, = original['fixes']
    method = fix['method']
    assert method['owner'].split(',')[0] == 'COW.COWGameEntry' and method['name']=='Update' and not method['parameters']
    assert original['fixTableFlag'] is None
    # The VN container stores one flag byte after the assembly name.
    assembly = original['assembly'].encode()
    pos = data.rindex(assembly) + len(assembly)
    assert struct.unpack_from('<i',data,pos)[0]==1
    payload = struct.pack('<Q', 0x66a319b20db4a2cb) + data[8:pos] + b'\x01' + data[pos:]
    path = out/'Assembly-CSharp-patch.bytes'
    path.write_bytes(payload)
    baked = inspect(path)
    assert baked['magic']=='66a319b20db4a2cb' and baked['fixTableFlag']==1 and baked['fixes']==original['fixes']
    assert baked['methods']==original['methods'] and baked['externMethods']==original['externMethods']
    report = {'sha256':hashlib.sha256(payload).hexdigest(),'size':len(payload),
              'sourceSha256':{name:hashlib.sha256((HERE/name).read_bytes()).hexdigest()
                              for name in ('MizzeStartup.cs','UnityStartupBindings.cs','StartupCompiler.cs')},
              'target':'Free Fire VN 1.134.1','fixes':baked['fixes'],
              'externMethods':baked['externMethods'],'deviceVerified':False}
    (out/'payload-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f"IFix startup payload: {report['size']} bytes, SHA-256 {report['sha256']}")


if __name__ == '__main__':
    build(Path(sys.argv[1]).resolve(strict=True), Path(sys.argv[2]).resolve())
