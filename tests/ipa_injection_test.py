import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('inject', Path(__file__).parents[1] / 'tools/inject_dylib.py')
inject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inject)


def macho(commands=(), filetype=2, padding=512):
    table = b''.join(commands)
    return struct.pack('<8I', 0xFEEDFACF, 0x0100000C, 0, filetype, len(commands), len(table), 0, 0) + table + bytes(padding) + b'GAME-DATA'


class InjectionTest(unittest.TestCase):
    def test_two_aliases_become_one_image_without_shifting_ordinals(self):
        system = inject.dylib_command(12, '/usr/lib/libSystem.B.dylib')
        legacy = inject.dylib_command(0x80000018, '@executable_path/Frameworks/Monite.dylib')
        current = inject.dylib_command(12, inject.DEFAULT_INSTALL_NAME)
        binary = macho([system, legacy, current])
        result = inject.patch_binary(binary, inject.DEFAULT_INSTALL_NAME)
        table = inject.commands(result)
        self.assertEqual(len(table), 3)
        self.assertEqual(table[0][1], system)
        self.assertEqual([row[0] for row in table], [12, 0x80000018, 12])
        self.assertEqual([row[2] for row in table[1:]], [inject.DEFAULT_INSTALL_NAME] * 2)
        self.assertEqual(len(result), len(binary))
        self.assertEqual(result[-9:], b'GAME-DATA')
        self.assertEqual(inject.patch_binary(result, inject.DEFAULT_INSTALL_NAME), result)

    def test_clean_injection_is_idempotent(self):
        binary = macho()
        result = inject.patch_binary(binary, inject.DEFAULT_INSTALL_NAME)
        self.assertEqual(len(inject.commands(result)), 1)
        self.assertEqual(inject.patch_binary(result, inject.DEFAULT_INSTALL_NAME), result)

    def test_no_space_and_malformed_commands_fail(self):
        with self.assertRaises(ValueError):
            inject.patch_binary(macho(padding=0), inject.DEFAULT_INSTALL_NAME)
        with self.assertRaises(ValueError):
            inject.patch_binary(macho([struct.pack('<II', 12, 0)]), inject.DEFAULT_INSTALL_NAME)

    def test_fat_arm64_slice_uses_first_arch_entry(self):
        arm = macho()
        other = b'other-architecture'
        offset = 4096
        table = struct.pack('>2I', 0xCAFEBABE, 2)
        table += struct.pack('>5I', 0x0100000C, 0, offset, len(arm), 12)
        table += struct.pack('>5I', 7, 0, offset + len(arm), len(other), 0)
        fat = table.ljust(offset, b'\0') + arm + other
        result = inject.patch_binary(fat, inject.DEFAULT_INSTALL_NAME)
        self.assertEqual(result[:offset], fat[:offset])
        self.assertEqual(result[-len(other):], other)
        self.assertEqual(len(result), len(fat))
        self.assertEqual(len(inject.commands(result[offset:offset + len(arm)])), 1)

    def test_ipa_removes_legacy_copy_preserves_original_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, library, output = root / 'input.ipa', root / 'new.dylib', root / 'output.ipa'
            app = 'Payload/Game.app/'
            legacy = inject.dylib_command(0x80000018, '@executable_path/Frameworks/Monite.dylib')
            current = inject.dylib_command(12, inject.DEFAULT_INSTALL_NAME)
            binary = macho([legacy, current])
            info = plistlib.dumps({'CFBundleExecutable': 'RealGame'}, fmt=plistlib.FMT_BINARY)
            with zipfile.ZipFile(source, 'w') as archive:
                archive.writestr(app + 'Info.plist', info)
                archive.writestr(app + 'RealGame', binary)
                archive.writestr(app + 'Frameworks/Monite.dylib', b'old')
                archive.writestr(app + 'Frameworks/libsubsystem.dylib', b'old')
                archive.writestr(app + 'Frameworks/unrelated.dylib', b'keep')
                archive.writestr(app + 'asset.dat', b'keep')
            original = source.read_bytes()
            library.write_bytes(macho(filetype=6))
            inject.inject_ipa(source, library, output)
            self.assertEqual(source.read_bytes(), original)
            with zipfile.ZipFile(output) as archive:
                self.assertIsNone(archive.testzip())
                self.assertNotIn(app + 'Frameworks/Monite.dylib', archive.namelist())
                self.assertEqual(archive.read(app + 'Frameworks/libsubsystem.dylib'), library.read_bytes())
                self.assertEqual(archive.read(app + 'Frameworks/unrelated.dylib'), b'keep')
                self.assertEqual(archive.read(app + 'asset.dat'), b'keep')
                self.assertEqual(archive.read(app + 'Info.plist'), info)
            second = root / 'second.ipa'
            inject.inject_ipa(output, library, second)
            with zipfile.ZipFile(output) as first, zipfile.ZipFile(second) as last:
                self.assertEqual(first.read(app + 'RealGame'), last.read(app + 'RealGame'))
                self.assertEqual(first.namelist(), last.namelist())
            with self.assertRaises(ValueError):
                inject.inject_ipa(source, library, source)


if __name__ == '__main__':
    unittest.main()
