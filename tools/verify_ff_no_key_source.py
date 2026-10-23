import argparse, hashlib, json, pathlib, re, struct
root=pathlib.Path(__file__).resolve().parents[1]
folder=root/'dylib source no key'
parser=argparse.ArgumentParser();parser.add_argument('--binary');args=parser.parse_args()
blocked=['LicenseSession','InjectedLicenseController','MizzeDefaultLicenseDatabaseURL','firebaseio','firebasedatabase','OffsetClientToken','X-Client-Token','workers.dev','LicenseLockView']
manifest=json.loads((folder/'source-manifest.json').read_text())
for item in manifest['files']:
    p=folder/item['path'];assert p.is_file(),item['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],item['path']
for p in folder.rglob('*'):
    if p.suffix.lower() in ['.h','.m','.mm','.cpp','.inc','.plist']:
        s=p.read_text(encoding='utf-8-sig',errors='replace')
        assert not any(term in s for term in blocked),str(p)
assert not (folder/'firebase').exists()
assert not (folder/'sources/InjectedProtection.mm').exists()
assert not (folder/'esp/Core/_0xNW2872_.mm').exists()
if args.binary:
    b=(root/args.binary).read_bytes();assert len(b)>32
    magic,cpu,subtype,filetype=struct.unpack_from('<IIII',b)
    assert magic==0xfeedfacf and cpu==0x100000c and filetype==6
    for term in blocked:
        assert term.encode() not in b and term.encode('utf-16le') not in b,term
    pos=32;dependencies=[]
    for _ in range(struct.unpack_from('<I',b,16)[0]):
        cmd,size=struct.unpack_from('<II',b,pos);assert size>=8 and pos+size<=len(b)
        if cmd in [0xc,0x80000018]:
            at=pos+struct.unpack_from('<I',b,pos+8)[0]
            dep=b[at:b.index(0,at)].decode();dependencies.append(dep)
            assert dep.startswith('/System/Library/') or dep.startswith('/usr/lib/'),dep
            assert not any(x in dep for x in ['BackBoardServices','GraphicsServices','SpringBoardServices']),dep
        pos+=size
    assert dependencies
    print('Verified ARM64 Mach-O dylib, system dependencies and no authentication markers:',len(b),'bytes')
else: print('Verified source manifest and absence of authentication/server credential dependencies')
