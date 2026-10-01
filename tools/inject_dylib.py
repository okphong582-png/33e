#!/usr/bin/env python3
"""Inject one overlay image; normalize legacy aliases without changing ordinals."""
import argparse
import copy
import os
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import struct
import tempfile
import zipfile

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
LOAD_COMMANDS = (0x0C, 0x80000018, 0x8000001F, 0x80000023)
DEFAULT_INSTALL_NAME = '@executable_path/Frameworks/libsubsystem.dylib'
OVERLAY_ALIASES = {'Monite.dylib', 'libsubsystem.dylib', 'iOSViet.dylib'}


def commands(data):
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != MH_MAGIC_64:
        raise ValueError('Expected a thin 64-bit Mach-O')
    count, size = struct.unpack_from('<II', data, 16)
    end, pos = 32 + size, 32
    if end > len(data):
        raise ValueError('Truncated load command table')
    result = []
    for _ in range(count):
        if pos + 8 > end:
            raise ValueError('Truncated load command')
        cmd, length = struct.unpack_from('<II', data, pos)
        if length < 8 or length % 8 or pos + length > end:
            raise ValueError('Invalid load command size')
        command = data[pos:pos + length]
        name = None
        if cmd in LOAD_COMMANDS:
            if length < 24:
                raise ValueError('Truncated dylib command')
            offset = struct.unpack_from('<I', command, 8)[0]
            if not 24 <= offset < length or b'\0' not in command[offset:]:
                raise ValueError('Invalid dylib name')
            name = command[offset:].split(b'\0', 1)[0].decode('utf-8')
        result.append((cmd, command, name))
        pos += length
    if pos != end:
        raise ValueError('Invalid load command table size')
    return result


def is_overlay(name, install_name):
    if name == install_name:
        return True
    return (PurePosixPath(install_name).name == 'libsubsystem.dylib'
            and name.startswith(('@executable_path/', '@loader_path/', '@rpath/'))
            and PurePosixPath(name).name in OVERLAY_ALIASES)


def dylib_command(cmd, name, original=None):
    encoded = name.encode('utf-8') + b'\0'
    size = (24 + len(encoded) + 7) // 8 * 8
    versions = struct.unpack_from('<III', original, 12) if original else (2, 0x10000, 0x10000)
    return (struct.pack('<6I', cmd, size, 24, *versions) + encoded).ljust(size, b'\0')


def patch_macho_64(data, dylib_path):
    table = commands(data)
    old_end = 32 + struct.unpack_from('<I', data, 20)[0]
    updated = []
    found = False
    for cmd, command, name in table:
        if name is not None and is_overlay(name, dylib_path):
            # Keep every dependency slot: removing one would shift Mach-O
            # library ordinals used by existing symbol bindings. dyld loads
            # the same canonical image once even if multiple slots name it.
            command = dylib_command(cmd, dylib_path, command)
            found = True
        updated.append(command)
    if not found:
        updated.append(dylib_command(0x0C, dylib_path))
    payload = b''.join(updated)
    new_end = 32 + len(payload)
    if new_end > len(data) or (new_end > old_end and any(data[old_end:new_end])):
        raise ValueError('Not enough zero header padding for injection')
    result = bytearray(data)
    result[32:max(old_end, new_end)] = payload.ljust(max(old_end, new_end) - 32, b'\0')
    struct.pack_into('<II', result, 16, len(updated), len(payload))
    return bytes(result)


def patch_binary(data, install_name):
    if len(data) < 8:
        raise ValueError('Truncated executable')
    magic = struct.unpack_from('>I', data)[0]
    if magic not in (FAT_MAGIC, FAT_CIGAM):
        return patch_macho_64(data, install_name)
    endian = '>' if magic == FAT_MAGIC else '<'
    count = struct.unpack_from(endian + 'I', data, 4)[0]
    if 8 + count * 20 > len(data):
        raise ValueError('Truncated universal architecture table')
    result = bytearray(data)
    patched = False
    for index in range(count):
        cpu, subtype, offset, size, align = struct.unpack_from(endian + '5I', data, 8 + index * 20)
        if cpu != 0x0100000C:
            continue
        if offset < 8 + count * 20 or offset + size > len(data):
            raise ValueError('Invalid arm64 slice bounds')
        result[offset:offset + size] = patch_macho_64(data[offset:offset + size], install_name)
        patched = True
    if not patched:
        raise ValueError('No arm64 slice found')
    return bytes(result)


def inject_ipa(ipa_path, dylib_file_path, output_ipa_path, dylib_install_name=DEFAULT_INSTALL_NAME):
    prefix = '@executable_path/'
    if not dylib_install_name.startswith(prefix):
        raise ValueError('IPA install path must use @executable_path/')
    relative = PurePosixPath(dylib_install_name[len(prefix):])
    if relative.is_absolute() or '..' in relative.parts or len(relative.parts) != 2 or relative.parts[0] != 'Frameworks':
        raise ValueError('Install path must be a file directly in Frameworks/')
    library = Path(dylib_file_path).read_bytes()
    commands(library)
    if struct.unpack_from('<I', library, 4)[0] != 0x0100000C or struct.unpack_from('<I', library, 12)[0] != 6:
        raise ValueError('Library must be an arm64 MH_DYLIB')
    output_path = Path(output_ipa_path).resolve()
    if output_path == Path(ipa_path).resolve():
        raise ValueError('Use a separate output IPA to preserve the original')
    output_path.parent.mkdir(parents=True, exist_ok=True)
    resources = Path(__file__).resolve().parents[1] / 'layout' / 'Resources'
    temp_name = None
    try:
        with zipfile.ZipFile(ipa_path) as source:
            names = source.namelist()
            if len(names) != len(set(names)):
                raise ValueError('Duplicate entries in input IPA')
            roots = [n[:-len('Info.plist')] for n in names
                     if n.startswith('Payload/') and n.endswith('.app/Info.plist') and n.count('/') == 2]
            if len(roots) != 1:
                raise ValueError('Expected one app in Payload')
            root = roots[0]
            info = plistlib.loads(source.read(root + 'Info.plist'))
            executable = root + info['CFBundleExecutable']
            main = patch_binary(source.read(executable), dylib_install_name)
            target = root + str(relative)
            replacements = {executable: main, target: library}
            if resources.is_dir():
                replacements.update({root + p.name: p.read_bytes() for p in resources.iterdir()
                                     if p.is_file() and p.name != 'Info.plist' and root + p.name != executable})
            obsolete = ({root + 'Frameworks/' + n for n in OVERLAY_ALIASES} - {target}
                        if relative.name == 'libsubsystem.dylib' else set())
            fd, temp_name = tempfile.mkstemp(prefix='mizze-inject-', suffix='.ipa', dir=output_path.parent)
            os.close(fd)
            with zipfile.ZipFile(temp_name, 'w', compression=zipfile.ZIP_DEFLATED, allowZip64=True) as output:
                output.comment = source.comment
                for item in source.infolist():
                    if item.filename in obsolete:
                        continue
                    with output.open(copy.copy(item), 'w', force_zip64=True) as dst:
                        if item.filename in replacements:
                            dst.write(replacements.pop(item.filename))
                        else:
                            with source.open(item) as src:
                                shutil.copyfileobj(src, dst, 1024 * 1024)
                for name, content in replacements.items():
                    output.writestr(name, content)
        os.replace(temp_name, output_path)
        temp_name = None
    finally:
        if temp_name:
            Path(temp_name).unlink(missing_ok=True)
    print(f'[SUCCESS] One overlay image injected: {output_path}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input_ipa')
    parser.add_argument('library')
    parser.add_argument('output_ipa')
    parser.add_argument('install_name', nargs='?', default=DEFAULT_INSTALL_NAME)
    args = parser.parse_args()
    inject_ipa(args.input_ipa, args.library, args.output_ipa, args.install_name)
