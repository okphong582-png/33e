"""Check the actual rootless package before publishing it for Dopamine."""
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

from verify_injected_dylib import verify


def verify_package(path):
    path = Path(path).resolve()
    architecture = subprocess.check_output(['dpkg-deb', '--field', str(path), 'Architecture'], text=True).strip()
    if architecture != 'iphoneos-arm64':
        raise ValueError(f'Wrong rootless package architecture: {architecture}')
    dependencies = subprocess.check_output(['dpkg-deb', '--field', str(path), 'Depends'], text=True)
    if 'mobilesubstrate' not in dependencies:
        raise ValueError('Tweak loader dependency missing')
    with tempfile.TemporaryDirectory() as directory:
        subprocess.run(['dpkg-deb', '--extract', str(path), directory], check=True)
        root = Path(directory)
        for file in root.rglob('*'):
            if file.is_file() and not file.relative_to(root).as_posix().startswith('var/jb/'):
                raise ValueError(f'Unprefixed rootless payload: {file.relative_to(root)}')
        tweak = root / 'var/jb/Library/MobileSubstrate/DynamicLibraries/iOSViet'
        verify(tweak.with_suffix('.dylib'))
        config = plistlib.loads(tweak.with_suffix('.plist').read_bytes())
        if config != {'Filter': {'Bundles': ['com.dts.freefireth', 'com.dts.freefiremax']}}:
            raise ValueError('Unexpected process filter')
        if not (root / 'var/jb/Library/Application Support/iOSViet/AuthConfig.plist').is_file():
            raise ValueError('Rootless resource directory missing')
    print('Dopamine package: rootless paths, correct architecture, narrow filter and signed overlay verified')


if __name__ == '__main__':
    for package in sys.argv[1:]:
        verify_package(package)
