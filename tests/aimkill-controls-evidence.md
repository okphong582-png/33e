# AimKill controls and run speed

Evidence is from the supplied Free Fire 1.132.1 ARM64 binary and metadata,
validated with `tools/verify_silent_aim_layout.cjs`. These are static and simulated
checks; TIPA/dylib behavior on a physical device still needs verification.

- `Player.SwapWeapon(int,bool)`, virtual 201, class entry `+0xDC8`, MethodInfo
  `+0xDD0`: Player `0x56B4EB4`, PlayerNetwork `0x5A5C9D4`. The callback passes
  `false` for the force argument, preserving native cooldown and network handling.
- Weapon manager: local `+0x740`, owner `+0x30`, slot array `+0x88`, array length
  `+0x18`, items `+0x20`. Alternate occupied firearm slots 0–2 once per second
  while AimKill and automatic swapping are enabled. The game thread rechecks the
  selected entry and owner before calling the verified virtual method, and ends
  its owned firing command first. Native game conditions may reject a swap.
- `PlayerAttributes.GetSpeedByType`, `0x6482A18`, reads the positive run/dash
  override at `+0x3C8` in `0x6482AA0..0x6482AA8`. This value is an absolute speed
  in meters per second, not an aim speed or multiplier. Input range is 0.1–30,
  default 6. A controller retains the original override across setting changes,
  retries failed restores, and rechecks component ownership before each write.
- Visual suppression has its own publication bit. Losing an aim target stops
  automatic shots without enabling the local fire-effect/tracer dispatch again.
  Remote players, stale publications, knocked players, and OFF use native paths.
  Virtual-223 is now left untouched so its native setup, hotfix, reporting and
  hit stages all run with Silent's redirected direction. The prior hit-only
  shortcut omitted preceding native work and has been removed.
- AimKill no longer activates the 2x fire-interval modifier. Saved manual fast
  fire is suspended while AimKill is enabled and restored afterward. Repeated
  automatic commands wait `max(native interval, 0.35 seconds)` and discard
  overshoot to avoid short gaps or catch-up commands. The first shot remains
  immediate after a valid target is available.
- Each floating-button visibility preference is independent of its feature.
  Enabling a feature initializes visibility only if no preference was saved.
- The target line is rendered from screen center to the current selected enemy,
  clears without a target, and follows selection changes rather than keeping an
  old enemy reference. Advanced aim and individual button controls are collapsed
  initially to keep the menu short.

Validation: ARM64 callback tests on both ELF and Mach-O objects cover timed swaps,
invalid inventory/method/expiry/delta rejection, stop-before-swap ordering, native
ABI preservation, target-independent tracer suppression, and 100 full-native
Silent shot dispatches. Cadence checks cover 30/60/120 FPS and slow weapons.
`weapon_features_test.cpp` covers decimal speed values, OFF restoration retries,
component ownership, context changes, and writes rejected after a player change.
