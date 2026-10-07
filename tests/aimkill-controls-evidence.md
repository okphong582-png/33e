# AimKill controls and run speed

Evidence is from the supplied Free Fire 1.132.1 ARM64 binary and metadata,
validated with `tools/verify_silent_aim_layout.cjs`. These are static and simulated
checks; TIPA/dylib behavior on a physical device still needs verification.

- `Player.SwapWeapon(int,bool)`, virtual 201, class entry `+0xDC8`, MethodInfo
  `+0xDD0`: Player `0x56B4EB4`, PlayerNetwork `0x5A5C9D4`. The callback first checks
  `Player.get_InSwapWeaponCD` (`0x5636E60`), then passes `true` to complete the
  native swap and keep its network handling. The prior `false` path queues input
  rather than calling manager `0x5ACF75C` directly.
- Weapon manager: local `+0x740`, owner `+0x30`, slot array `+0x88`, array length
  `+0x18`, items `+0x20`. Scan the actual array length, bounded to 67 slots,
  instead of assuming slots 0–2. A holstered firearm may have a null owner;
  the manager must still belong to the local player and a non-null foreign
  weapon owner is rejected. The primary `+0xA0` resolves combined on-hand cases.
  Alternate occupied firearm slots once per second
  while AimKill and automatic swapping are enabled. The game thread rechecks the
  selected entry and owner before calling the verified virtual method, and ends
  its owned firing command first. Invalid inventory or cooldown doesn't block
  automatic firing. A rejected native swap resumes the old weapon's cadence;
  an actual switch clears the old reference and waits for the new publication.
- `PlayerAttributes.GetSpeedByType`, `0x6482A18`, reads the positive run/dash
  override at `+0x3C8` in `0x6482AA0..0x6482AA8`. This value is an absolute speed
  in meters per second, not an aim speed or multiplier. Input range is 0.1–30,
  default 6. A controller retains the original override across setting changes,
  retries failed restores, and rechecks component ownership before each write.
- All native fire-effect and tracer methods are now untouched as well as
  virtual-223. Compatibility callback entries tail-call their native methods
  with all original arguments, even with a presentation bit set. Hiding a whole
  method was not proven to preserve all game state and hotfix work.
  Virtual-223 stays untouched so its native setup, hotfix, reporting and
  hit stages all run with Silent's redirected direction. The prior hit-only
  shortcut omitted preceding native work and has been removed.
- AimKill no longer activates the 2x fire-interval modifier. Saved manual fast
  fire is suspended while AimKill is enabled and restored afterward. Repeated
  automatic commands wait `max(native interval, 0.35 seconds)` and discard
  overshoot to avoid short gaps or catch-up commands. The first shot remains
  immediate after a valid target is available.
- AimKill temporarily activates IsAmmoFree (`PlayerAttributes +0x194`) and
  ShootNoReload (`+0x111`) at the user's request. The reversible controller
  restores their prior values when AimKill is disabled and resumes saved manual
  fast-fire/no-reload choices. This client-side behavior does not prove server
  hit acceptance or server-side unlimited ammo.
- AimKill and Fly are available again. Their menu checkboxes follow Ghost and
  FakeLag: enable shows a floating control and enables the feature; disabling
  removes that control and stops the feature. Tapping a floating control toggles
  only the feature, keeping the button available. The global hide setting hides
  the controls while retaining their current feature state.
- AimKill chooses Silent's target path while enabled, without rewriting the
  user's manual head/neck/Silent type or activation choices. Its active FOV and
  headshot ratio remain adjustable on the Aim page. Fly height remains 1–6 m.
- The target line is rendered from screen center to the current selected enemy,
  clears without a target, and follows selection changes rather than keeping an
  old enemy reference. Advanced aim and individual button controls are collapsed
  initially to keep the menu short.

Validation: ARM64 callback tests on both ELF and Mach-O objects cover timed swaps,
invalid inventory/method/expiry/delta rejection, stop-before-swap ordering, native
ABI preservation, unconditional native effect/tracer forwarding, and 100 full-native
Silent shot dispatches. Cadence checks cover 30/60/120 FPS and slow weapons.
Successful and rejected swap simulations check old-weapon cleanup and resumed
fire. Inventory tests include late slots, holstered weapons, foreign owners and
invalid array lengths. These checks don't verify server-side acceptance of hits while Fly moves
the client's character controller; that specific report remains device-tested
only by the user and needs retesting with the restored full shot pipeline.
`weapon_features_test.cpp` covers decimal speed values, OFF restoration retries,
component ownership, context changes, and writes rejected after a player change.

## Solid-cover gate

Verified native entry points in the supplied 1.132.1 image:

| Method | Offset | Bytes | FNV-1a |
| --- | --- | --- | --- |
| Physics.Raycast(Vector3,Vector3,RaycastHit&,float,int,QueryTriggerInteraction) | 0x8DE4904 | 0x17C | 8B3DCDAE |
| PhysicsScene.Raycast standard helper | 0x8DE4A80 | 0x1F0 | 8956580B |
| RaycastHit.get_collider | 0x8DF0730 | 0xF4 | F884A08C |
| Component.get_transform | 0x8D59C2C | 0x50 | E5B7D25C |
| Transform.IsChildOf | 0x8D6ECE0 | 0x64 | DECACF20 |
| Player.get_RootTransform | 0x56182FC | 0x154 | 8E831156 |

The standard Physics wrapper accepts origin in s0–s2, direction in s3–s5,
distance in s6, a 44-byte RaycastHit output pointer in x0, layer mask in w1,
and trigger policy in w2. It uses `Internal_Raycast_Injected`, not the game's
ExtraMask extension. The signed callback queries the full segment on the weapon
update thread using all solid layers and ignoring triggers. No hit means clear;
a hit passes only when its collider transform belongs to the selected player's
root hierarchy. Missing/destroyed Unity objects, unknown ownership, invalid
coordinates and changed/expired publications fail closed. A missing player root
cache is rejected before entering the native getter that can throw.

At a mixed headshot percentage both head and body paths must be clear. This is
conservative around partial cover. At 0/100 only the selected path is checked.
Cover releases an owned firing command; exposure permits a new command without
manual input. ARM64 tests exercise clear/blocked segments, target/foreign
colliders, missing objects, partial cover, expiry and publication races, resume
after exposure, and preservation of native ABI/cadence/shot dispatch.

Device limitations: a Unity raycast does not detect a collider containing its
origin; physics timing, target hierarchy and native firing behavior require
testing in the actual game. The query currently uses the published camera
origin; it is not proof of server-authoritative visibility or damage.
