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
assert 'AimSilent' in aim and 'AimPos' in aim and 'ShowFovCircle' in aim and 'FovSize' in aim and 'AimMaster' not in aim
print('PASS: exact GIF bytes, all counter paths released on every return, weak menu lifetime, Silent-only controls')

assert "CADisplayLink" not in panel and "__weak ModMenuViewController *weakSelf" in panel

hud = (root / "esp/hud/HUDMainApplicationDelegate.mm").read_text(encoding="utf-8")
assert "ESP_View *espView" not in hud and "kHUDExitThreshold" not in hud

# Silent must use the selected target's live LOS, and must not inherit the
# distance slider's app-side cull in collection, selection, sticky hold or validation.
assert 'AimTargetVisibleStrictForSilent' not in s
assert 'useLocalDistance && !useSilent && tempDisForAim > maxPossibleDistance' in s
assert '(!useSilent && s.dis > aimDistance)' in s
assert '(useSilent || ld <= aimDistance + 5.f)' in s
assert '(!useSilent && d > aimDistance + 5.0f)' in s
assert 'GameClearLosToEnemy(myPawnObject, bestTarget, silentBone)' in s
print('PASS: Silent no app-side distance cap; live LOS when wall aim is off')

game = (root / 'app/sources/GameViewController.mm').read_text(encoding='utf-8')
boot = (root / 'app/KernelBoot.m').read_text(encoding='utf-8')
host = (root / 'esp/hud/DirectOverlay.mm').read_text(encoding='utf-8')
assert 'Click to activate menu' in game and 'pushViewController:menu' in game
assert 'SetHUDEnabled(YES)' not in game.split('- (void)startHUDForRequest:', 1)[1]
assert boot.index('boot_start_hud_menu();') > boot.index('boot_start_esp_host();')
assert 'MenuView *menuView' not in host
assert 'self.secureCanvas != self' in menu and 'menuButtonTapped:' in menu
assert 'silentFireWindow ? 6 : 1' in s
assert 'sleep_for(std::chrono::milliseconds(hasTarget ? 2 : 12))' in s
print('PASS: menu activation is reachable; HUD follows boot; Silent worker is paced')

assert 'AimCoverHitBlocksTarget(rc.hasCollider' in s
assert 'sample.hasCollider = isVaildPtr(ReadAddr<uint64_t>(info + 0x20))' in s
print('PASS: weapon endpoint only blocks aim when a collider is reported')
