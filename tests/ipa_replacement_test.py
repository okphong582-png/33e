import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('replace_ipa', Path(__file__).parents[1] / 'tools/replace_ipa_dylib.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def macho(filetype, command=b''):
    return struct.pack('<8I', 0xFEEDFACF, 0x0100000C, 0, filetype, int(bool(command)), len(command), 0, 0) + command


class ReplacementTest(unittest.TestCase):
    def test_replaces_only_library_and_preserves_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ipa, lib = root / 'game.ipa', root / 'new.dylib'
            entry = 'Payload/Game.app/Frameworks/Monite.dylib'
            name = b'@executable_path/Frameworks/Monite.dylib\0'
            size = (24 + len(name) + 7) // 8 * 8
            cmd = struct.pack('<6I', 0x80000018, size, 24, 0, 0, 0) + name
            binary = macho(2, cmd.ljust(size, b'\0'))
            info = plistlib.dumps({'CFBundleExecutable': 'Game', 'CFBundleIdentifier': 'test.original'})
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/Game.app/Info.plist', info)
                archive.writestr('Payload/Game.app/Game', binary)
                archive.writestr(entry, b'old library')
                archive.writestr('Payload/Game.app/asset.dat', b'unchanged')
            original = ipa.read_bytes()
            lib.write_bytes(macho(6))
            with self.assertRaises(ValueError):
                module.replace(ipa, lib, entry + '.missing')
            self.assertEqual(ipa.read_bytes(), original)
            module.replace(ipa, lib, entry)
            self.assertEqual(Path(str(ipa) + '.original-backup').read_bytes(), original)
            with zipfile.ZipFile(ipa) as archive:
                self.assertEqual(archive.read(entry), lib.read_bytes())
                self.assertEqual(archive.read('Payload/Game.app/Game'), binary)
                self.assertEqual(archive.read('Payload/Game.app/Info.plist'), info)
                self.assertEqual(archive.read('Payload/Game.app/asset.dat'), b'unchanged')
            with self.assertRaises(FileExistsError):
                module.replace(ipa, lib, entry)


if __name__ == '__main__':
    unittest.main()
