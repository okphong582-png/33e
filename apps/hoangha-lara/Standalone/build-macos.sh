#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != Darwin ]]; then
    echo "This build requires macOS and the Apple Xcode toolchain." >&2
    exit 1
fi
mkdir -p "$ROOT/exports"
BUILD_DIR="$(mktemp -d "$ROOT/exports/Hoangha-arm64e-XXXXXX")"
exec > >(tee "$BUILD_DIR/build.log") 2>&1
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
APP="$BUILD_DIR/Payload/Hoangha.app"
mkdir -p "$APP/Frameworks" "$BUILD_DIR/objects"

FLAGS=(-arch arm64e -isysroot "$SDK" -miphoneos-version-min=16.0
       -fobjc-arc -fblocks -fmodules -O1 -Wno-deprecated-declarations
       -fmodules-cache-path="$BUILD_DIR/module-cache"
       -include "$ROOT/Standalone/RequirePAC.h")
for directory in lara lara/classes lara/headers lara/kexploit lara/kexploit/TaskRop lara/kexploit/pe lara/lib/choma; do
    FLAGS+=(-I "$ROOT/$directory")
done
SOURCES=(Standalone/HoanghaApp.m Standalone/HHFreeFireReader.m lara/classes/HoanghaOverlayBridge.m
         lara/kexploit/darksword.m lara/kexploit/offsets.m
         lara/kexploit/utils.m lara/kexploit/persistence.m)
for name in RemoteCall exc pac thread vm findcachedataoff; do
    SOURCES+=("lara/kexploit/TaskRop/$name.m")
done
for name in vnode vfs apfs sbx; do
    SOURCES+=("lara/kexploit/pe/$name.m")
done
OBJECTS=()
xcrun clang --version
for source in "${SOURCES[@]}"; do
    object="$BUILD_DIR/objects/${source//\//-}.o"
    echo "Compiling $source"
    xcrun --sdk iphoneos clang "${FLAGS[@]}" -c "$ROOT/$source" -o "$object"
    OBJECTS+=("$object")
done
xcrun --sdk iphoneos clang++ -arch arm64e -isysroot "$SDK" -miphoneos-version-min=16.0 -std=c++17 -O1 \
    -include "$ROOT/Standalone/RequirePAC.h" -c "$ROOT/Standalone/HHFFProfile.cpp" -o "$BUILD_DIR/objects/HHFFProfile.o"
OBJECTS+=("$BUILD_DIR/objects/HHFFProfile.o")
xcrun --sdk iphoneos clang -arch arm64e -isysroot "$SDK" -miphoneos-version-min=16.0 \
    "${OBJECTS[@]}" -L "$ROOT/lara/lib" -lxpf -lgrabkernel2 -lobjc -lc++ -lz \
    -framework UIKit -framework Foundation -framework CoreFoundation \
    -framework CoreGraphics -framework QuartzCore -framework IOSurface -framework Security -framework AVFAudio \
    -Wl,-rpath,@executable_path/Frameworks -Wl,-dead_strip -o "$APP/Hoangha"

cp "$ROOT/lara/lib/libxpf.dylib" "$APP/Frameworks/"
cp "$ROOT/lara/lib/libgrabkernel2.dylib" "$APP/Frameworks/"
python3 "$ROOT/Standalone/fetch-xs-kernelcache.py" "$APP"
cp "$ROOT/Resources/bubble-logo.png" "$APP/bubble-logo.png"
python3 - "$APP" <<'PY'
from pathlib import Path
import plistlib, sys
app = Path(sys.argv[1])
info = {
    'CFBundleDisplayName': 'Hoangha', 'CFBundleName': 'Hoangha',
    'CFBundleExecutable': 'Hoangha', 'CFBundleIdentifier': 'com.hoangha.lara',
    'CFBundlePackageType': 'APPL', 'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleShortVersionString': '1.5.8', 'CFBundleVersion': '15',
    'CFBundleSupportedPlatforms': ['iPhoneOS'], 'MinimumOSVersion': '16.0',
    'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1, 2],
    'UIRequiredDeviceCapabilities': ['arm64'], 'UIFileSharingEnabled': True,
    'LSSupportsOpeningDocumentsInPlace': True, 'UILaunchScreen': {}, 'UIBackgroundModes': ['audio'],
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
(app / 'PkgInfo').write_bytes(b'APPL????')
PY
for dylib in "$APP"/Frameworks/*.dylib; do
    /usr/bin/codesign --force --sign - "$dylib"
done
/usr/bin/codesign --force --sign - --generate-entitlement-der \
    --entitlements "$ROOT/Config/lara.entitlements" "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
python3 "$ROOT/Standalone/verify-arm64e.py" "$APP/Hoangha" "$BUILD_DIR/architecture.json"
(cd "$BUILD_DIR" && /usr/bin/zip -qry Hoangha-Lara-arm64e.ipa Payload)
echo "Output: $BUILD_DIR/Hoangha-Lara-arm64e.ipa"
