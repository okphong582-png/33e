from pathlib import Path
import hashlib, json, struct, sys

binary_path, report_path = map(Path, sys.argv[1:])
data = binary_path.read_bytes()
magic, cpu, subtype, filetype, commands, command_bytes = struct.unpack_from('<6I', data)
if magic != 0xfeedfacf or cpu != 0x100000c or filetype != 2:
    raise SystemExit('Not a thin ARM64 Mach-O executable.')
if (subtype & 0x00ffffff) != 2:
    raise SystemExit('Rejected: executable is not arm64e; do not distribute this IPA.')
position = 32
signature = None
for _ in range(commands):
    command, size = struct.unpack_from('<II', data, position)
    if size < 8 or position + size > 32 + command_bytes:
        raise SystemExit('Malformed Mach-O load command.')
    if command == 0x1d:
        offset, length = struct.unpack_from('<II', data, position + 8)
        signature = data[offset:offset + length]
    position += size
if signature is None or struct.unpack_from('>I', signature)[0] != 0xfade0cc0:
    raise SystemExit('Missing embedded code signature.')
report = {
    'executable': str(binary_path), 'architecture': 'arm64e',
    'cpuSubtype': hex(subtype), 'sha256': hashlib.sha256(data).hexdigest(),
    'compileGuard': 'RequirePAC.h requires arm64e and ptrauth_calls',
    'physicalIphoneTested': False,
}
with report_path.open('x', encoding='utf8') as stream:
    json.dump(report, stream, indent=2)
print(json.dumps(report, indent=2))
