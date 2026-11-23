from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parent.parent
gif = root / 'app/layout/Resources/Mizze-Antiban-Eye-Slow.gif'
assert hashlib.sha256(gif.read_bytes()).hexdigest() == '1d98523ecd1ae8a9b45a7d528361caadd3bf56102e8906593b3f9f76eb381c0c'
s = (root / 'esp/esp/esp.mm').read_text(encoding='utf-8')
start = s.index('    CGMutablePathRef aNumBGPath = CGPathCreateMutable();')
end = s.index('\nQuaternion GetRotationToLocation(', start)
body = s[start:end]
# The only return after acquiring these four CF resources is after all releases.
# All lobby/loading/dictionary/local-player/matrix failure returns precede acquisition.
returns = [m.start() for m in re.finditer(r'\breturn stats;', body)]
assert len(returns) == 1
for name in ['aNumBGPath', 'aNumGPath', 'aNumOPath', 'aNumRPath']:
    assert s.count(f'CGMutablePathRef {name}') == 1
    assert s.count(f'CGPathRelease({name});') == 1
    assert body.index(f'CGPathRelease({name});') < returns[0]
menu = (root / 'esp/esp/menu.mm').read_text(encoding='utf-8')
assert 'CADisplayLink' not in menu
assert '__weak MenuView *weakSelf' in menu
assert 'FloatAimBtn' not in menu and 'AimPos' not in menu
panel = (root / 'app/sources/ModMenuViewController.mm').read_text(encoding='utf-8')
aim = panel.split('} else if (tab == MenuTabAimbot) {', 1)[1].split('} else if (tab == MenuTabOther) {', 1)[0]
assert 'AimSilent' in aim and 'AimPos' not in aim and 'AimMaster' not in aim
print('PASS: exact GIF bytes, all counter paths released on every return, weak menu lifetime, Silent-only controls')
