"""Check the built image for dependencies and load callbacks unsafe in a host app."""
from pathlib import Path
import struct
import sys

from inject_dylib import commands


def verify(path):
    data = Path(path).read_bytes()
    table = commands(data)
    if struct.unpack_from('<I', data, 4)[0] != 0x0100000C or struct.unpack_from('<I', data, 12)[0] != 6:
        raise ValueError('Expected an arm64 dylib')
    for cmd, command, name in table:
        if cmd in (0x24, 0x32):  # LC_VERSION_MIN_IPHONEOS / LC_BUILD_VERSION
            version = struct.unpack_from('<I', command, 8 if cmd == 0x24 else 12)[0]
            if version > (13 << 16):
                raise ValueError('Injected dylib unnecessarily requires newer than iOS 13')
        if name and any(framework in name for framework in
                        ('BackBoardServices.framework', 'GraphicsServices.framework', 'SpringBoardServices.framework')):
            raise ValueError(f'Standalone HUD framework in injected image: {name}')
        if cmd == 0x19:  # LC_SEGMENT_64
            protection, count = struct.unpack_from('<II', command, 60)
            if len(command) < 72 + count * 80:
                raise ValueError('Truncated section table')
            for index in range(count):
                section = command[72 + index * 80:152 + index * 80]
                section_name = section[:16].split(b'\0')[0].decode()
                size = struct.unpack_from('<Q', section, 40)[0]
                flags = struct.unpack_from('<I', section, 64)[0]
                if size and section_name in ('__objc_nlclslist', '__objc_nlcatlist'):
                    raise ValueError('Objective-C +load callback remains in injected dylib')
                if size and flags & 0x80000400 and not protection & 4:
                    raise ValueError(f'Code in non-executable section: {section_name}')
        if cmd == 2:  # LC_SYMTAB
            symoff, count, stroff, strsize = struct.unpack_from('<4I', command, 8)
            if symoff + count * 16 > len(data) or stroff + strsize > len(data):
                raise ValueError('Truncated symbols')
            strings = data[stroff:stroff + strsize]
            forbidden = ('_IOHIDEventCreateDigitizer', '_BKSHIDEvent', '_GSInitialize',
                         '_UIApplicationInitialize', '_posix_spawnattr_set_persona', '_ptrace')
            for index in range(count):
                string_index, kind = struct.unpack_from('<IB', data, symoff + index * 16)
                if kind & 0x0E != 0 or not string_index:
                    continue
                symbol = strings[string_index:].split(b'\0', 1)[0].decode()
                if symbol.startswith(forbidden):
                    raise ValueError(f'Private startup/HUD import: {symbol}')
    if b'TSEventFetcher\0' in data:
        raise ValueError('Synthetic touch loader class remains in injected dylib')
    print('Injected dylib: arm64, no +load, no private HUD imports, executable code sections')


if __name__ == '__main__':
    verify(sys.argv[1])
