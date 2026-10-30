#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc TrollFools/MizzeToggleState.swift Tests/MizzeToggleTests.swift -o build/mizze-toggle-tests
./build/mizze-toggle-tests | tee build/mizze-tests.log
sips -s format png -z 1024 1024 TrollFools/MizzeLogo.jpg --out TrollFools/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
xcodebuild -project TrollFools.xcodeproj -scheme TrollFools -configuration Release \
  -sdk iphoneos -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | tee build/xcodebuild.log
APP="build/DerivedData/Build/Products/Release-iphoneos/TrollFools.app"
test -f "$APP/MizzePayload.zip"
test -f "$APP/TrollFools"
chmod +x "$APP/TrollFools"
for name in chown cp cp-15 ct_bypass insert_dylib mkdir mv mv-15 rm; do
  test -f "$APP/$name"; chmod +x "$APP/$name"
done
python3 - "$APP" <<'PY'
import hashlib,pathlib,plistlib,sys,zipfile
app=pathlib.Path(sys.argv[1])
assert hashlib.sha256((app/'MizzePayload.zip').read_bytes()).hexdigest()=='f53124a0e6a3f282d04220c14d3511ab755efb21ef1acd4a0a27efbe4f0e5188'
with zipfile.ZipFile(app/'MizzePayload.zip') as packed:
    assert packed.namelist()==['Mizze.dylib']
    assert hashlib.sha256(packed.read('Mizze.dylib')).hexdigest()=='8aae828d9c254747b30f924d4d484a18065907c5000941f6725a5f1bc64a8380'
assert plistlib.loads((app/'Info.plist').read_bytes())['CFBundleDisplayName']=='Mizze'
print('Bundled payload SHA256 and app display name verified')
PY
ldid -STrollFools/TrollFools.entitlements "$APP/TrollFools"
mkdir -p build/Package/Payload
ditto "$APP" build/Package/Payload/TrollFools.app
(cd build/Package && zip -qry ../Mizze-Toggle.tipa Payload)
cp build/Mizze-Toggle.tipa build/Mizze-Toggle.ipa
shasum -a 256 build/Mizze-Toggle.tipa > build/Mizze-Toggle.sha256
