#!/usr/bin/env bash
# inject_ff_ipa.sh — Stealth dylib injection into Free Fire IPA
# Usage: ./scripts/inject_ff_ipa.sh <input.ipa> <dylib.dylib> [output.ipa]
# Produces an IPA indistinguishable from an App Store download.
# Requirements: ldid, insert_dylib (or insert_dylib_nosign), zip/unzip, python3

set -euo pipefail

INPUT_IPA="${1:?Usage: $0 <input.ipa> <dylib.dylib> [output.ipa]}"
INPUT_DYLIB="${2:?Usage: $0 <input.ipa> <dylib.dylib> [output.ipa]}"
OUTPUT_IPA="${3:-injected_$(basename "$INPUT_IPA")}"

# ── Stealth embed path — looks like Apple private framework, not a cheat ──
STEALTH_FRAMEWORK_NAME="CoreSpeechKit"
STEALTH_INSTALL_NAME="@rpath/${STEALTH_FRAMEWORK_NAME}.framework/${STEALTH_FRAMEWORK_NAME}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "[*] Unpacking IPA..."
cp "$INPUT_IPA" "$WORK_DIR/app.ipa"
unzip -q "$WORK_DIR/app.ipa" -d "$WORK_DIR/payload"

PAYLOAD_DIR="$WORK_DIR/payload/Payload"
APP_BUNDLE="$(ls "$PAYLOAD_DIR"/*.app | head -1)"
APP_NAME="$(basename "$APP_BUNDLE" .app)"

echo "[*] Target: $APP_NAME.app"

# ── Embed dylib as private framework (stealth path) ───────────────────────
FRAMEWORKS_DIR="$APP_BUNDLE/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

FRAMEWORK_BUNDLE="$FRAMEWORKS_DIR/${STEALTH_FRAMEWORK_NAME}.framework"
mkdir -p "$FRAMEWORK_BUNDLE"

# Copy dylib into framework bundle with stealth name
cp "$INPUT_DYLIB" "$FRAMEWORK_BUNDLE/${STEALTH_FRAMEWORK_NAME}"

# Minimal Info.plist so it looks like a real framework
python3 - <<EOF
import plistlib, os
info = {
    'CFBundleExecutable': '${STEALTH_FRAMEWORK_NAME}',
    'CFBundleIdentifier': 'com.apple.corespeechkit',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': '${STEALTH_FRAMEWORK_NAME}',
    'CFBundlePackageType': 'FMWK',
    'CFBundleVersion': '1.0',
    'CFBundleShortVersionString': '1.0',
    'MinimumOSVersion': '13.0',
    'CFBundleSupportedPlatforms': ['iPhoneOS'],
    'DTPlatformName': 'iphoneos',
}
with open('${FRAMEWORK_BUNDLE}/Info.plist', 'wb') as f:
    plistlib.dump(info, f)
print('[*] Framework Info.plist written')
EOF

# ── Patch main executable: add LC_LOAD_DYLIB pointing at stealth path ─────
MAIN_EXEC="$APP_BUNDLE/$APP_NAME"

echo "[*] Patching main binary with stealth LC_LOAD_DYLIB..."

# insert_dylib is the standard tool for this
if command -v insert_dylib &>/dev/null; then
    insert_dylib \
        --strip-codesig \
        --all-yes \
        "$STEALTH_INSTALL_NAME" \
        "$MAIN_EXEC" \
        "$MAIN_EXEC"
else
    # Fallback: python3 Mach-O LC_LOAD_DYLIB patcher (no external tools needed)
    python3 - "$MAIN_EXEC" "$STEALTH_INSTALL_NAME" <<'PYEOF'
import sys, struct, os

binary_path = sys.argv[1]
dylib_path  = sys.argv[2].encode() + b'\x00'

with open(binary_path, 'r+b') as f:
    data = bytearray(f.read())

def patch_arch(data, offset, le):
    endian = '<' if le else '>'
    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = \
        struct.unpack_from(endian + 'IIIIIII', data, offset)

    is64 = magic in (0xFEEDFACF, 0xCFFAEDFE)
    hdr_sz = 32 if is64 else 28
    cmd_off = offset + hdr_sz

    # Build LC_LOAD_DYLIB command
    LC_LOAD_DYLIB = 0xC
    name_offset = 24  # sizeof(dylib_command)
    path_bytes = dylib_path
    # pad to 8-byte alignment
    raw_size = name_offset + len(path_bytes)
    cmd_size = (raw_size + 7) & ~7
    pad = cmd_size - raw_size
    dylib_cmd = struct.pack(endian + 'IIIII',
        LC_LOAD_DYLIB,      # cmd
        cmd_size,           # cmdsize
        name_offset,        # name.offset
        2,                  # timestamp (2 = built-in)
        0x00000000,         # current_version
    )
    dylib_cmd += struct.pack(endian + 'I', 0x00000000)  # compatibility_version
    dylib_cmd += path_bytes + b'\x00' * pad

    # Inject after existing commands
    insert_at = cmd_off + sizeofcmds
    data[insert_at:insert_at] = dylib_cmd

    # Update ncmds and sizeofcmds in header
    struct.pack_into(endian + 'II', data, offset + 16, ncmds + 1, sizeofcmds + cmd_size)
    return data

def patch(data):
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic == 0xBEBAFECA:  # FAT binary
        narch = struct.unpack_from('>I', data, 4)[0]
        for i in range(narch):
            off, size = struct.unpack_from('>II', data, 8 + i*20)[0:2]
            m = struct.unpack_from('<I', data, off)[0]
            le = m in (0xCEFAEDFE, 0xCFFAEDFE)
            data = patch_arch(data, off, le)
    elif magic in (0xFEEDFACE, 0xFEEDFACF):  # LE
        data = patch_arch(data, 0, True)
    elif magic in (0xCEFAEDFE, 0xCFFAEDFE):  # BE
        data = patch_arch(data, 0, False)
    return data

data = patch(data)
with open(binary_path, 'wb') as f:
    f.write(data)
print('[*] LC_LOAD_DYLIB patched into binary')
PYEOF
fi

# ── Fake App Store receipt (game sees receipt = legit download) ────────────
echo "[*] Writing fake App Store receipt..."
RECEIPT_PATH="$APP_BUNDLE/_MASReceipt"
mkdir -p "$RECEIPT_PATH"

python3 - "$RECEIPT_PATH/receipt" <<'PYEOF'
import sys, struct

# Minimal ASN.1 DER — iTunes Receipt container
# Real receipt is much larger but presence alone satisfies many checks
def der_len(n):
    if n < 0x80:
        return bytes([n])
    elif n < 0x100:
        return bytes([0x81, n])
    else:
        return bytes([0x82, (n >> 8) & 0xFF, n & 0xFF])

def der_seq(content):
    return b'\x30' + der_len(len(content)) + content

def der_set(content):
    return b'\x31' + der_len(len(content)) + content

def der_int(value):
    v = value.to_bytes((value.bit_length() + 8) // 8, 'big')
    return b'\x02' + der_len(len(v)) + v

def der_utf8(s):
    b = s.encode()
    return b'\x0c' + der_len(len(b)) + b

def der_ia5(s):
    b = s.encode('ascii')
    return b'\x16' + der_len(len(b)) + b

def der_octet(b):
    return b'\x04' + der_len(len(b)) + b

def attr(type_id, version, value_der):
    return der_seq(der_int(type_id) + der_int(version) + der_octet(value_der))

# Receipt attributes (partial — enough to pass simple checks)
bundle_id     = attr(2,  1, der_utf8("com.dts.freefireth"))
app_version   = attr(3,  1, der_utf8("1.0"))
opaque_value  = attr(4,  1, der_octet(b'\x00' * 20))
sha1_hash     = attr(5,  1, der_octet(b'\x00' * 20))
orig_version  = attr(19, 1, der_utf8("1.0"))

payload = der_set(bundle_id + app_version + opaque_value + sha1_hash + orig_version)

# PKCS#7 ContentInfo stub wrapping the SET
pkcs7_oid = b'\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x07\x01'  # OID 1.2.840.113549.1.7.1
content   = b'\xa0' + der_len(len(payload) + 4) + b'\x04\x82' + struct.pack('>H', len(payload)) + payload
receipt   = der_seq(pkcs7_oid + content)

with open(sys.argv[1], 'wb') as f:
    f.write(receipt)
print('[*] Fake receipt written')
PYEOF

# ── Remove code signature directory so ldid can re-sign cleanly ───────────
echo "[*] Stripping existing code signature..."
rm -rf "$APP_BUNDLE/_CodeSignature"

# Also strip framework signatures
for fw in "$FRAMEWORKS_DIR"/*.framework; do
    rm -rf "$fw/_CodeSignature"
done

# ── Re-sign with ldid ─────────────────────────────────────────────────────
echo "[*] Re-signing with ldid (ad-hoc)..."

# Sign framework dylib first
ldid -S "$FRAMEWORK_BUNDLE/${STEALTH_FRAMEWORK_NAME}"

# Sign main binary with entitlements preserved where possible
# Generate minimal entitlements matching Free Fire's known profile
ENTITLEMENTS_FILE="$WORK_DIR/entitlements.xml"
cat > "$ENTITLEMENTS_FILE" <<'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>*</string>
    <key>get-task-allow</key>
    <true/>
    <key>platform-application</key>
    <true/>
    <key>com.apple.private.security.no-sandbox</key>
    <true/>
    <key>com.apple.private.security.storage.AppDataContainers</key>
    <true/>
</dict>
</plist>
ENTEOF

ldid -S"$ENTITLEMENTS_FILE" "$MAIN_EXEC"

# ── Patch Info.plist — remove any injection-revealing keys ────────────────
echo "[*] Cleaning Info.plist..."
INFO_PLIST="$APP_BUNDLE/Info.plist"

python3 - "$INFO_PLIST" <<'PYEOF'
import sys, plistlib

path = sys.argv[1]
try:
    with open(path, 'rb') as f:
        info = plistlib.load(f)
except Exception as e:
    print(f'[!] plist read error: {e}')
    sys.exit(0)

# Remove keys that reveal sideloading or modification
for key in ['SignerIdentity', 'AmIAnAppStoreBuild', 'iTunesArtworkURL',
            'NSAppleMusicUsageDescription']:
    info.pop(key, None)

# Ensure it looks like a legitimate signed build
info.setdefault('LSApplicationQueriesSchemes', [])

with open(path, 'wb') as f:
    plistlib.dump(info, f)
print('[*] Info.plist cleaned')
PYEOF

# ── Repack IPA ────────────────────────────────────────────────────────────
echo "[*] Repacking IPA..."
pushd "$WORK_DIR/payload" > /dev/null
zip -qr "$WORK_DIR/output.ipa" Payload/
popd > /dev/null

cp "$WORK_DIR/output.ipa" "$OUTPUT_IPA"

echo ""
echo "[+] Done → $OUTPUT_IPA"
echo "    Dylib embedded as: ${STEALTH_FRAMEWORK_NAME}.framework/${STEALTH_FRAMEWORK_NAME}"
echo "    Install name:      $STEALTH_INSTALL_NAME"
echo "    Fake receipt:      _MASReceipt/receipt"
echo "    Signed:            ldid ad-hoc"
