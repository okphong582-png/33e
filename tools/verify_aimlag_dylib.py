"""Validate the standalone Aimlag artifact without requiring main-app sections."""
from pathlib import Path
import struct
import sys
from inject_dylib import commands


def verify(path):
    data = Path(path).read_bytes()
    if struct.unpack_from('<I', data, 4)[0] != 0x0100000C or struct.unpack_from('<I', data, 12)[0] != 6:
        raise ValueError('Expected an arm64 dylib')
    sections = set()
    for cmd, command, name in commands(data):
        if name and any(item in name for item in ('BackBoardServices.framework', 'GraphicsServices.framework', 'SpringBoardServices.framework')):
            raise ValueError(f'Private HUD dependency: {name}')
        if cmd == 0x19:
            count = struct.unpack_from('<I', command, 64)[0]
            for index in range(count):
                section = command[72 + index * 80:152 + index * 80]
                section_name = section[:16].split(b'\0')[0].decode()
                size = struct.unpack_from('<Q', section, 40)[0]
                if size:
                    sections.add(section_name)
                if size and section_name in ('__objc_nlclslist', '__objc_nlcatlist'):
                    raise ValueError('Unexpected Objective-C +load callback')
    if '__playermodes' not in sections:
        raise ValueError('Player modes callback missing')
    if sections.intersection({'__silent', '__autofire', '__ghost'}):
        raise ValueError('Main aim/Ghost callbacks included in standalone target')
    for forbidden in (b'ESPMenuController', b'SilentAimController', b'AimKill', b'GhostModeUpdate'):
        if forbidden in data:
            raise ValueError(f'Unexpected main feature: {forbidden!r}')
    if b'AimlagController' not in data:
        raise ValueError('Standalone floating control missing')
    print('Aimlag dylib: arm64, standalone control and player modes, no main aim/Ghost callbacks or private HUD dependencies')


if __name__ == '__main__':
    verify(sys.argv[1])
