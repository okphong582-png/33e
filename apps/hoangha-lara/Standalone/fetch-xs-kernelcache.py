"""Fetch only the pinned kernelcache member from Apple's IPSW using HTTP ranges."""
from pathlib import Path
import hashlib, json, struct, sys, urllib.request, zlib

URL = 'https://updates.cdn-apple.com/2025SpringFCS/fullrestores/082-45658/0CEE897C-AD56-4422-BD70-FA3CB060E23C/iPhone11,2,iPhone11,4,iPhone11,6_18.5_22F76_Restore.ipsw'
OFFSET = 8829236891
COMPRESSED_SIZE = 18918844
SIZE = 18928562
CRC32 = 1567292259
SHA256 = '406b5f62fd2357a8365c8b99f8c1d766a38f0dbe405dee94023f835c324c22b3'
MEMBER = 'kernelcache.release.iphone11'

def read_range(start, length):
    request = urllib.request.Request(URL, headers={'Range': f'bytes={start}-{start + length - 1}'})
    with urllib.request.urlopen(request, timeout=90) as response:
        if response.status != 206:
            raise RuntimeError('Apple CDN did not honor the range; refusing full IPSW download')
        data = response.read(length + 1)
        if len(data) != length:
            raise RuntimeError('Unexpected range length')
        return data

output = Path(sys.argv[1])
header = read_range(OFFSET, 30)
assert header[:4] == b'PK\x03\x04'
assert struct.unpack_from('<H', header, 8)[0] == 8
name_length, extra_length = struct.unpack_from('<HH', header, 26)
assert read_range(OFFSET + 30, name_length).decode() == MEMBER
compressed = read_range(OFFSET + 30 + name_length + extra_length, COMPRESSED_SIZE)
kernel = zlib.decompress(compressed, -15)
assert len(kernel) == SIZE and zlib.crc32(kernel) == CRC32
assert hashlib.sha256(kernel).hexdigest() == SHA256
with (output / 'kernelcache-iPhone11,2-22F76').open('xb') as stream:
    stream.write(kernel)
evidence = {'device': 'iPhone11,2', 'version': '18.5', 'build': '22F76',
            'source': URL, 'member': MEMBER, 'sha256': SHA256,
            'validation': 'matches Apple BuildManifest SHA-384; build fetch also checks ZIP CRC and pinned SHA-256'}
with (output / 'kernelcache-source.json').open('x') as stream:
    json.dump(evidence, stream, indent=2)
print(f'Bundled Apple kernelcache: {SIZE} bytes, SHA-256 verified')
