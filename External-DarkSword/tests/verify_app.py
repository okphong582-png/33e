import sys, zipfile, plistlib
from pathlib import PurePosixPath
file = sys.argv[1]
with zipfile.ZipFile(file) as z:
    bad = z.testzip()
    if bad:
        raise RuntimeError('Bad ZIP CRC: ' + bad)
    names = z.namelist()
    plists = [n for n in names if n.startswith('Payload/') and n.endswith('.app/Info.plist') and n.count('/') == 2]
    if len(plists) != 1:
        raise RuntimeError('Expected exactly one app')
    prefix = str(PurePosixPath(plists[0]).parent) + '/'
    info = plistlib.loads(z.read(plists[0]))
    exe = info['CFBundleExecutable']
    binary = z.read(prefix + exe)
    if binary[:4] != bytes.fromhex('cffaedfe'):
        raise RuntimeError('Expected ARM64 Mach-O app executable')
    if b'FreeFireManager' not in binary:
        raise RuntimeError('FF manager missing from linked app')
    for name in ['overlay_menu.html', 'overlay_fab.html', 'overlay_esp.html', 'Frameworks/libxpf.dylib', 'Frameworks/libgrabkernel2.dylib']:
        if prefix + name not in names:
            raise RuntimeError('Missing resource: ' + name)
    menu = z.read(prefix + 'overlay_menu.html').decode('utf8')
    if 'freefire' not in menu or 'ESP Box' not in menu:
        raise RuntimeError('Wrong menu resource')
    print('PASS linked app / resources / ZIP:', info.get('CFBundleIdentifier'), exe, info.get('MinimumOSVersion'))
