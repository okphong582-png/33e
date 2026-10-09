# FC Mobile VN — ball line and experimental shot assistance

Target: `com.garena.game.fcmobilevn`, version 27.1.01, executable `FIFAMobile`, ARM64, UUID `d46eb47ff9e83033950b0513ab05f6c0`.

Outputs: `FCMobile-Menu.dylib` for injection, and `FCMobile-Menu.tipa` containing a standalone floating-menu launcher. This is not a repackaged game. TIPA uses privileged process access and the existing private HUD runtime; an ordinary App Store installation cannot grant those privileges.

The checkbox sets **GcShotErrorUser to 0** using its verified data field and marks it changed, matching the native setter. Enable before entering a match, because the confirmed consumer copies this setting into pre-match customization data. The toggle defaults off; turning it off restores the previous setting if the same object still exists. No game code, goalkeeper behavior, collision, network validation, or shot power is patched.

**ESP line bóng** is an independent checkbox, initially off. It draws a mint line from screen center to the active ball, using the game's native camera view/projection matrices. The reader runs on a serial worker queue, at up to 30 Hz while the line is enabled and 4 Hz otherwise. Missing data, off-screen/behind-camera balls, changed scenes, replaced ball histories or changed cameras clear the line. Drawing never receives touches; only menu controls do. Status text remains inside the menu. The ball reader performs no game-memory writes.

Version 0.4 fixes the reader's dependence on the Lua practice scene. It first resolves the regular gameplay component table and reads ball 0, as native regular-match consumers do. The Lua scene/selected practice ball remains a fallback. Component counts/identities are checked before accepting the main table. ESP now reports separate failures for the data source, ball, position history, camera, projection and concurrent replacement; enabling the Open Goal trial no longer hides ESP status. Both TIPA and dylib share this implementation. This correction is tested with mock memory including a regular match with no Lua scene; actual device behavior is still to be checked.

This is an experimental configuration change, **not a verified every-shot-goals implementation**. Static analysis proves the property identity and access path; it does not establish whether every FC Mobile mode honors this customization value. On-device confirmation is still required. The menu says “Đã cập nhật tham số sút” only after reading the changed value back; that message does not mean an in-match goal has been verified.

**AimKill thử nghiệm** is now a separate, initially-off checkbox. It enables the game's native `OpenGoalShootingLogic` flag, matching the named Lua setter. It does not automatically enable the shot-error checkbox or shoot for you. The native shot evaluation reads this flag, but an effect on ball targeting in every game mode has not been demonstrated. When the game already has this flag enabled, the menu explicitly reports “Game đã bật sẵn logic Open Goal” and performs no writes. Otherwise it reports the applied flag only after readback, and disabling restores the original value if the same object and mode still exist. Status text does not report a confirmed goal.

**This trial does not redirect every ball into the goal regardless of direction/position.** The identified ball position history is a published state buffer, not a confirmed physics command target. Native `lxLaunchBall` builds and dispatches simulation messages; direct edits to the history buffer cannot establish a real shot or an accepted goal. Opponent-goal selection, shot ownership/timing and live simulation message handling still need verification. No such writes or simulation calls are included.

Build only this folder:

```sh
make clean package BUILD_KIND=dylib FINALPACKAGE=1 FOR_RELEASE=1
make clean package BUILD_KIND=tipa FINALPACKAGE=1 FOR_RELEASE=1
```

The isolated `codex/fc-mobile` branch triggers `fc-mobile.yml` only. Other game workflows remain unchanged.

To test: open FC Mobile VN and enter a match, enable ESP line bóng, rotate/change the camera and verify the line follows the ball. Switch it off and confirm the line disappears while game touches still work. Ball projection is tested with mock memory and several camera poses; real device rendering remains unverified.

For the shot setting, enable it in the lobby, enter the same training scenario with and without it, compare shot spread at the same power/direction, and check that switching off restores the setting. If gameplay does not change, the next step is a live trace of the pre-match customization consumer, not guessing additional offsets.

For AimKill, compare shots in the same training scenario with the checkbox off/on, leaving the shot-error checkbox unchanged. Note whether the menu reports an actual flag change or a flag already enabled by the game. The latter is not evidence of a new gameplay effect. The native constructor already enables this flag in modes whose enum differs from 4; its ability to improve a normal match is therefore particularly uncertain.
