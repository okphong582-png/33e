# Local visual spin

The main menu exposes `VisualSpin` (off by default) and `VisualSpinSpeed` in the
Settings tab. Speed is 0.1–3 revolutions/second, default 0.5. Phase uses elapsed
time, wraps at one turn and pauses through long/background timing gaps.

Spin shares the existing PlayerModes callbacks for injected dylib, rootless
Dopamine package and TIPA. The callback applies after native MatchGame.OnLateUpdate,
to the local player's BoneRoot TransformNode. The earlier Root (+0x6C8) can be
the entity root and incorrectly reject a valid character; BoneRoot (+0x6D0) is
resolved with the native getter so lazy caches are initialized. It requires a live
Unity native object, a distinct physical root and a successful `IsChildOf(root)`.
It never writes aim rotations, the entity/physics root, camera or packet fields.
Before the next native Update/PostUpdate it restores the owned visual rotation,
tolerating Unity quaternion normalization. Native animation changes win over
stale saved rotations. Disabling, expired publication and context changes stop
new applications; restoration also runs while disabled. Identity checks prevent
restoring a saved pose into a recycled player or replaced avatar.

Static layout verified against the supplied 1.132.1 files (the existing verifier
records both SHA-256 hashes):

- Player.get_RootTransform at 0x56182FC uses cached TransformNode at +0x6C8.
- Player.get_BoneRootTransform at 0x5639C90 uses the distinct cache at +0x6D0.
- TransformNode.get_transform at 0x6B4964C reads its managed Transform at +0x10.
- Entity.get_CachedTransform at 0x6B49C14 caches the physical Transform at +0x58.
- Unity local rotation getter 0x8D6C788, setter 0x8D6C860 and IsChildOf 0x8D6ECE0
  have independent runtime code fingerprints; unsupported images fail closed.

Tests execute the shipped ARM64 callback in both ELF and Mach-O form. They cover
render phase, restoration before originals, child-only writes, independent
Fly/FakeLag behavior, release, expired lease, invalid model, dead/knocked player,
torn publication and recycled identity. C++ tests compare speed at 30/60 FPS.
These tests establish the implemented data path; the visible in-game result and
remote-client appearance have not been tested on two physical devices.

Aimlag/FakeLag additionally retain the entire BoneRoot subtree, up to 128 nodes,
including each local rotation and position. Collection happens once per hold;
each native Update/PostUpdate receives the latest saved normal pose and original
Animator speed/enabled state. The held pose is reapplied afterwards; speed=0 and
enabled=false prevent Mecanim/IK evaluation between callbacks. Entity health,
weapons and incoming position updates still execute. Release preserves the native
Animator state, including a previously disabled Animator or custom playback speed.
Changed identities, replaced avatars, reparented nodes, invalid native pointers,
NaN pose values, cycles, oversized hierarchies and torn input prevent pose writes.
Private RW pose storage is separately sized; the shared signed code stays RX.
Physical-device animation ordering remains unverified.

## Final-frame spin regression

Spin no longer applies at Player.PostUpdate: the supplied game still has a
separate native late chain. MatchGame.OnLateUpdate occupies virtual slot 18;
BaseGameManager.LateUpdate calls that entry at 0x6B32BB0. The base implementation
0x5A9A654 invokes its late delegate before returning. Six supplied game-mode
overrides retain that slot and call the base implementation. Each accepted
native entry is fingerprinted before binding.

The signed late callback has its own immutable native-original pointer and a
link to the local Player callback's state. It runs the native late chain first,
then applies visual yaw; the next Player.OnUpdate restores the owned yaw before
gameplay runs. Old callback mappings remain alive for in-flight game calls.
BoneRoot must be a live child distinct from the physical root; missing or
unsupported rigs produce a short status inside the menu, never a play-screen log.

The ARM64 regression now executes a separate late mapping and simulates a native
late animation that resets the model rotation. It checks the final displayed
rotation, native restoration, independent originals, guards and saved registers.
This is emulator/static evidence; visibility on a physical iPhone remains unverified.

## Horizontal turn

The user demonstrated a vertical roll rather than a horizontal turn. Spin now
reads the visual rig's world rotation and premultiplies it by world-up yaw.
Unity Transform.get_rotation (0x8D6C5B4) and set_rotation (0x8D6C68C) are separately
fingerprinted; their native icall names confirm world-space quaternion access.
The original and displayed LOCAL quaternions are still retained for restoration,
so movement of the parent between frames is preserved. No physical-root rotation
is changed. Tests use three tilted imported parent orientations and six angles
through a full turn, checking the displayed up vector and local restoration.
