"""Check the built image for dependencies and load callbacks unsafe in a host app."""
from pathlib import Path
import hashlib
import struct
import sys

from inject_dylib import commands, LOAD_COMMANDS


SAFE_DEPENDENCIES = {
    '/usr/lib/libobjc.A.dylib', '/usr/lib/libSystem.B.dylib', '/usr/lib/libc++.1.dylib',
    *('/System/Library/Frameworks/{0}.framework/{0}'.format(name)
      for name in ('Foundation', 'CoreFoundation', 'CoreGraphics', 'QuartzCore', 'UIKit', 'Security')),
}


def verify_dependencies(table):
    for cmd, command, name in table:
        if cmd in LOAD_COMMANDS and name not in SAFE_DEPENDENCIES:
            raise ValueError(f'Unexpected injected dependency: {name}')
        if cmd == 0x0D:  # LC_ID_DYLIB
            offset = struct.unpack_from('<I', command, 8)[0]
            if command[offset:].split(b'\0', 1)[0] != b'@rpath/libsubsystem.dylib':
                raise ValueError('Injected dylib retains a jailbreak-only install name')


def verify_signature(data, table):
    signatures = [command for cmd, command, _ in table if cmd == 0x1D]
    if len(signatures) != 1:
        raise ValueError('Expected one staged code signature')
    start, size = struct.unpack_from('<II', signatures[0], 8)
    if start + size > len(data) or size < 12:
        raise ValueError('Truncated code signature')
    blob = data[start:start + size]
    magic, length, count = struct.unpack_from('>III', blob)
    if magic != 0xFADE0CC0 or not 12 + count * 8 <= length <= size:
        raise ValueError('Malformed signature superblob')
    directories = 0
    for index in range(count):
        offset = struct.unpack_from('>I', blob, 16 + index * 8)[0]
        if offset + 8 > length:
            raise ValueError('Invalid signature entry')
        entry_magic, entry_length = struct.unpack_from('>II', blob, offset)
        if entry_length < 8 or offset + entry_length > length:
            raise ValueError('Truncated signature entry')
        if entry_magic != 0xFADE0C02:
            continue
        directory = blob[offset:offset + entry_length]
        if len(directory) < 44:
            raise ValueError('Truncated CodeDirectory')
        hash_offset = struct.unpack_from('>I', directory, 16)[0]
        slots, limit = struct.unpack_from('>II', directory, 28)
        hash_size, hash_type, _, page_bits = directory[36:40]
        algorithm = {1: 'sha1', 2: 'sha256', 3: 'sha256', 4: 'sha384'}.get(hash_type)
        if (not algorithm or page_bits > 20 or not page_bits or not hash_size or
                hash_size > hashlib.new(algorithm).digest_size or limit != start or
                slots != (limit + (1 << page_bits) - 1) // (1 << page_bits) or
                hash_offset < 44 or hash_offset + slots * hash_size > len(directory)):
            raise ValueError('Unsupported or invalid code hash layout')
        page_size = 1 << page_bits
        for page in range(slots):
            digest = hashlib.new(algorithm, data[page * page_size:min((page + 1) * page_size, limit)]).digest()[:hash_size]
            expected = directory[hash_offset + page * hash_size:hash_offset + (page + 1) * hash_size]
            if digest != expected:
                raise ValueError(f'Staged code signature mismatch on page {page}')
        directories += 1
    if not directories:
        raise ValueError('CodeDirectory missing from staged signature')


def verify(path):
    data = Path(path).read_bytes()
    table = commands(data)
    verify_dependencies(table)
    verify_signature(data, table)
    required_sections = {('__TEXT', name) for name in ('__cv_text', '__vtizer', '__vd_text', '__mt_text')}
    required_sections.add(('__DATA', '__vdata'))
    found_sections = set()
    initializer_count = 0
    if (struct.unpack_from('<I', data, 4)[0] != 0x0100000C or
            struct.unpack_from('<I', data, 8)[0] & 0x00FFFFFF != 0 or
            struct.unpack_from('<I', data, 12)[0] != 6):
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
                segment_name = section[16:32].split(b'\0')[0].decode()
                size = struct.unpack_from('<Q', section, 40)[0]
                if size:
                    found_sections.add((segment_name, section_name))
                if section_name == '__mod_init_func':
                    if size % 8:
                        raise ValueError('Invalid initializer pointer table')
                    initializer_count += size // 8
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
    missing = required_sections - found_sections
    if missing:
        raise ValueError(f'Own-code protection sections missing: {sorted(missing)}')
    if b'https://appchatai-313e3-default-rtdb.firebaseio.com' in data:
        raise ValueError('Injected default database URL stored as plain literal')
    if b'TSEventFetcher\0' in data:
        raise ValueError('Synthetic touch loader class remains in injected dylib')
    print(f'Injected dylib: arm64, verified staged signature, minimal dependencies, {initializer_count} loader initializers, no +load, all five protection sections present')


if __name__ == '__main__':
    verify(sys.argv[1])
