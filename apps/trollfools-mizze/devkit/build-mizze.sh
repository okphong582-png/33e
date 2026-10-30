#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
test -f build-menu/MizzePayload.zip
test -f build-menu/MizzePayload.json
cp build-menu/MizzePayload.zip TrollFools/MizzePayload.zip
swiftc TrollFools/MizzeToggleState.swift Tests/MizzeToggleTests.swift -o build/mizze-toggle-tests
./build/mizze-toggle-tests | tee build/mizze-tests.log
sips -s format png -z 1024 1024 TrollFools/MizzeLogo.jpg --out TrollFools/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
xcodebuild -project TrollFools.xcodeproj -scheme TrollFools -configuration Release \
  -sdk iphoneos -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | tee build/xcodebuild.log
APP="build/DerivedData/Build/Products/Release-iphoneos/TrollFools.app"
test -f "$APP/MizzePayload.zip"
test -f "$APP/TrollFools"
/usr/bin/plutil -replace CFBundleDisplayName -string Mizze "$APP/Info.plist"
for localized in "$APP"/*.lproj/InfoPlist.strings; do
  if [ -f "$localized" ]; then
    /usr/bin/plutil -replace CFBundleDisplayName -string Mizze "$localized"
  fi
done
chmod +x "$APP/TrollFools"
for name in chown cp cp-15 ct_bypass insert_dylib mkdir mv mv-15 rm install_name_tool optool ldid; do
  test -f "$APP/$name"; chmod +x "$APP/$name"
done
for name in libcrypto.3.dylib libintl.8.dylib libiosexec.1.dylib libxar.1.dylib; do
  test -f "$APP/$name"
done
PAYLOAD_HASH=$(python3 -c 'import json;print(json.load(open("build-menu/MizzePayload.json"))["zipSha256"])')
/usr/libexec/PlistBuddy -c "Add :MizzePayloadSHA256 string $PAYLOAD_HASH" "$APP/Info.plist"
python3 - "$APP" <<'PY'
import hashlib,pathlib,plistlib,sys,zipfile
app=pathlib.Path(sys.argv[1])
import json
identity=json.loads(pathlib.Path('build-menu/MizzePayload.json').read_text())
assert hashlib.sha256((app/'MizzePayload.zip').read_bytes()).hexdigest()==identity['zipSha256']
with zipfile.ZipFile(app/'MizzePayload.zip') as packed:
    assert packed.namelist()==['Mizze.dylib']
    assert hashlib.sha256(packed.read('Mizze.dylib')).hexdigest()==identity['dylibSha256']
assert plistlib.loads((app/'Info.plist').read_bytes())['CFBundleDisplayName']=='Mizze'
assert plistlib.loads((app/'Info.plist').read_bytes())['MizzePayloadSHA256']==identity['zipSha256']
print('Bundled payload SHA256 and app display name verified')
PY
ldid -STrollFools/TrollFools.entitlements "$APP/TrollFools"
python3 devkit/verify-package.py "$APP"
mkdir -p build/Package/Payload
ditto "$APP" build/Package/Payload/TrollFools.app
(cd build/Package && zip -qry ../Mizze-Toggle.tipa Payload)
cp build/Mizze-Toggle.tipa build/Mizze-Toggle.ipa
shasum -a 256 build/Mizze-Toggle.tipa > build/Mizze-Toggle.sha256
