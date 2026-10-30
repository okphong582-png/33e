#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
STAGE=$(mktemp -d /tmp/mizze-menu.XXXXXX)
cp -R MenuSource/. "$STAGE/"
make -C "$STAGE" clean package GAME_VARIANT=th FINALPACKAGE=1 FOR_RELEASE=1
mkdir -p build-menu
cp "$STAGE/packages/Mizze.dylib" build-menu/Mizze.dylib
python3 - <<'PY'
import hashlib,json,pathlib,struct,zipfile
r=pathlib.Path('.');data=(r/'build-menu/Mizze.dylib').read_bytes()
magic,cpu,subtype,kind=struct.unpack_from('<IIII',data)
assert magic==0xfeedfacf and cpu==0x100000c and kind==6,'Expected ARM64 iOS dylib'
with zipfile.ZipFile('build-menu/MizzePayload.zip','w',zipfile.ZIP_DEFLATED) as z:
    item=zipfile.ZipInfo('Mizze.dylib',(2026,10,30,0,0,0));item.external_attr=0o100755<<16
    z.writestr(item,data,compress_type=zipfile.ZIP_DEFLATED)
identity={'version':'Mizze-Reference-ESP-1','dylibSha256':hashlib.sha256(data).hexdigest(),
          'zipSha256':hashlib.sha256(pathlib.Path('build-menu/MizzePayload.zip').read_bytes()).hexdigest(),
          'normalOverlayEntry':True,'game':'com.dts.freefireth'}
pathlib.Path('build-menu/MizzePayload.json').write_text(json.dumps(identity,indent=2))
print(json.dumps(identity))
PY
