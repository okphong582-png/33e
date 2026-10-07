"""Reject stale/modified packaged images and unavailable injected dependencies."""
import hashlib
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from inject_dylib import dylib_command
from verify_injected_dylib import verify_dependencies, verify_signature


def rejected(callback):
    try:
        callback()
    except ValueError:
        return
    raise AssertionError('Unsafe artifact accepted')


verify_dependencies([(0x0C, b'', '/System/Library/Frameworks/UIKit.framework/UIKit'),
                     (0x0D, dylib_command(0x0D, '@rpath/libsubsystem.dylib'), None)])
for name in ('/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate',
             '/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit'):
    rejected(lambda: verify_dependencies([(0x0C, b'', name)]))
rejected(lambda: verify_dependencies([(0x0D, dylib_command(0x0D, '/Library/MobileSubstrate/iOSViet.dylib'), None)]))

# A small SHA-256 CodeDirectory with one signed page and no special slots.
payload = b'fixture signed executable bytes'
directory = bytearray(44 + 32)
struct.pack_into('>9I', directory, 0, 0xFADE0C02, len(directory), 0x20001, 2, 44, 0, 0, 1, len(payload))
directory[36:40] = bytes([32, 2, 0, 12])
directory[44:] = hashlib.sha256(payload).digest()
blob = struct.pack('>5I', 0xFADE0CC0, 20 + len(directory), 1, 0, 20) + directory
command = struct.pack('<4I', 0x1D, 16, len(payload), len(blob))
table = [(0x1D, command, None)]
verify_signature(payload + blob, table)
rejected(lambda: verify_signature(b'X' + payload[1:] + blob, table))
rejected(lambda: verify_signature(payload + blob[:-1], table))
rejected(lambda: verify_signature(payload, []))
malformed = bytearray(blob)
struct.pack_into('>I', malformed, 16, len(blob) + 1)
rejected(lambda: verify_signature(payload + malformed, table))
print('Injected artifact dependency and signed page corruption checks: passed')
