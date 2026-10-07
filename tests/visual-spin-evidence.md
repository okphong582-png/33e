# Local visual spin

The main menu exposes `VisualSpin` (off by default) and `VisualSpinSpeed` in the
Settings tab. Speed is 0.1–3 revolutions/second, default 0.5. Phase uses elapsed
time, wraps at one turn and pauses through long/background timing gaps.

Spin shares the existing PlayerModes callbacks for injected dylib, rootless
Dopamine package and TIPA. The callback applies only after native PostUpdate,
to the local player's cached skeleton-root TransformNode. It requires a live
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
