"""Replace one already-loaded dylib without changing the game's plist or executable."""
import argparse
import copy
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import struct
import tempfile
import zipfile


def commands(data):
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != 0xFEEDFACF:
        raise ValueError('Expected a thin 64-bit Mach-O')
    count, size = struct.unpack_from('<II', data, 16)
    end, pos = 32 + size, 32
    if end > len(data):
        raise ValueError('Truncated load commands')
    for _ in range(count):
        if pos + 8 > end:
            raise ValueError('Truncated command')
        cmd, length = struct.unpack_from('<II', data, pos)
        if length < 8 or pos + length > end:
            raise ValueError('Invalid load command')
        yield cmd, data[pos:pos + length]
        pos += length
    if pos != end:
        raise ValueError('Invalid command table size')


def replace(ipa, library, entry):
    ipa, library = Path(ipa).resolve(strict=True), Path(library).resolve(strict=True)
    backup = ipa.with_name(ipa.name + '.original-backup')
    if backup.exists():
        raise FileExistsError(f'Backup already exists; preserve it before retrying: {backup}')
    payload = library.read_bytes()
    list(commands(payload))
    if struct.unpack_from('<I', payload, 4)[0] != 0x0100000C:
        raise ValueError('Replacement must be arm64')
    if struct.unpack_from('<I', payload, 12)[0] != 6:
        raise ValueError('Replacement must be MH_DYLIB')
    with zipfile.ZipFile(ipa) as source:
        names = source.namelist()
        if len(names) != len(set(names)) or names.count(entry) != 1:
            raise ValueError('Missing target or duplicate archive entries')
        root = entry.split('.app/', 1)[0] + '.app/'
        info = plistlib.loads(source.read(root + 'Info.plist'))
        executable = root + info['CFBundleExecutable']
        old_main = source.read(executable)
        install = '@executable_path/' + entry[len(root):]
        matches = 0
        for cmd, command in commands(old_main):
            if cmd in (12, 0x80000018):
                offset = struct.unpack_from('<I', command, 8)[0]
                name = command[offset:].split(b'\0', 1)[0].decode()
                matches += name == install
        if matches != 1:
            raise ValueError('Expected exactly one existing load command for target dylib')
        fd, temp_name = tempfile.mkstemp(prefix=ipa.stem + '-', suffix='.ipa.tmp', dir=ipa.parent)
        os.close(fd)
        temp = Path(temp_name)
        try:
            with zipfile.ZipFile(temp, 'w', allowZip64=True) as output:
                output.comment = source.comment
                for item in source.infolist():
                    with output.open(copy.copy(item), 'w', force_zip64=True) as dst:
                        if item.filename == entry:
                            dst.write(payload)
                        else:
                            with source.open(item) as src:
                                shutil.copyfileobj(src, dst, 1024 * 1024)
            with zipfile.ZipFile(temp) as result:
                bad = result.testzip()
                if bad:
                    raise ValueError(f'Corrupt output entry: {bad}')
                if result.read(entry) != payload or result.read(executable) != old_main:
                    raise ValueError('Replacement verification failed')
                if result.read(root + 'Info.plist') != source.read(root + 'Info.plist'):
                    raise ValueError('Game metadata changed unexpectedly')
            # Never discard the original. A failed replacement leaves it recoverable.
            with backup.open('xb') as dst, ipa.open('rb') as src:
                shutil.copyfileobj(src, dst, 1024 * 1024)
        except BaseException:
            temp.unlink(missing_ok=True)
            raise
    os.replace(temp, ipa)
    print(f'Replaced: {ipa}\nBackup: {backup}\nEntry: {entry}')
    print('Dylib SHA256:', hashlib.sha256(payload).hexdigest())
    print('The modified app requires re-signing before installation.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa')
    parser.add_argument('library')
    parser.add_argument('--entry', required=True)
    args = parser.parse_args()
    replace(args.ipa, args.library, args.entry)
