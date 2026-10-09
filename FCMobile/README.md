# FC Mobile VN — experimental shot setting

Target: `com.garena.game.fcmobilevn`, version 27.1.01, executable `FIFAMobile`, ARM64, UUID `d46eb47ff9e83033950b0513ab05f6c0`.

Outputs: `FCMobile-Menu.dylib` for injection, and `FCMobile-Menu.tipa` containing a standalone floating-menu launcher. This is not a repackaged game. TIPA uses privileged process access and the existing private HUD runtime; an ordinary App Store installation cannot grant those privileges.

The checkbox sets **GcShotErrorUser to 0** using its verified data field and marks it changed, matching the native setter. Enable before entering a match, because the confirmed consumer copies this setting into pre-match customization data. The toggle defaults off; turning it off restores the previous setting if the same object still exists. No game code, goalkeeper behavior, collision, network validation, or shot power is patched.

This is an experimental configuration change, **not a verified every-shot-goals implementation**. Static analysis proves the property identity and access path; it does not establish whether every FC Mobile mode honors this customization value. On-device confirmation is still required. The menu says “Đã cập nhật tham số sút” only after reading the changed value back; that message does not mean an in-match goal has been verified.

Build only this folder:

```sh
make clean package BUILD_KIND=dylib FINALPACKAGE=1 FOR_RELEASE=1
make clean package BUILD_KIND=tipa FINALPACKAGE=1 FOR_RELEASE=1
```

The isolated `codex/fc-mobile` branch triggers `fc-mobile.yml` only. Other game workflows remain unchanged.

To test: open FC Mobile VN, enable the setting in the lobby, enter the same training scenario with and without the setting, compare shot spread at the same power/direction, and check that switching off restores the setting. If gameplay does not change, the next step is a live trace of the pre-match customization consumer, not guessing additional offsets.
