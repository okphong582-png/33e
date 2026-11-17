from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json
import plistlib
import struct

root = Path(__file__).resolve().parent
applications = list((root / '.theos/_').rglob('MizzeFFVN.app'))
applications = [app for app in applications if (app / 'MizzeFFVN').is_file()]
if not applications:
    raise SystemExit('Built application not found')
app = max(applications, key=lambda item: (item / 'MizzeFFVN').stat().st_mtime_ns)
binary = (app / 'MizzeFFVN').read_bytes()
assert struct.unpack_from('<II', binary) == (0xfeedfacf, 0x100000c)
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.mizze.ffvn.kernel'
assert info['CFBundleExecutable'] == 'MizzeFFVN'
for symbol in (b'jbdInitPPLRW', b'proc_find', b'proc_task', b'kread_ptr', b'kread64', b'vreadbuf'):
    assert symbol in binary, symbol
assert bytes.fromhex('e50b0e3ad931385b9e4c9ffde6d1b923') in binary
output = root / 'packages'
output.mkdir(exist_ok=True)
package = output / 'Mizze-FFVN-1.134.1-Kernel.tipa'
with ZipFile(package, 'x', ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob('*')):
        if path.is_file():
            archive.write(path, 'Payload/MizzeFFVN.app/' + path.relative_to(app).as_posix())
with ZipFile(package) as archive:
    assert archive.testzip() is None
    assert archive.read('Payload/MizzeFFVN.app/MizzeFFVN') == binary
report = dict(sha256=hashlib.sha256(package.read_bytes()).hexdigest(),
              backend='libjailbreak proc_find/proc_task/vreadbuf',
              game='Free Fire VN 1.134.1 build 2019121262',
              unityUuid='e50b0e3a-d931-385b-9e4c-9ffde6d1b923',
              deviceVerified=False)
(output / 'verification.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
