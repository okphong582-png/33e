# Ghost Mode: experimental client implementation

Both TIPA and dylib expose an opt-in Ghost switch under Settings. A verified
match-update callback captures the local player's position. Two serializers
temporarily substitute that anchor and frozen pose, zero velocity and movement
axes, call the original serializer once, then restore every modified numeric
field. A mint cube marks the captured position locally. Disabling requests one
`Entity.set_Position` call on the next eligible match update.

This is a client prototype, not verified all-mode server behavior. The supplied
binary's matching match/message classes are supported without a mode filter;
other paths fail closed. Opponent visibility and authoritative return behavior
need a device test with a second observer.

These observations come from read-only disassembly of the supplied Free Fire
1.132.1 UnityFramework and its global-metadata.dat. Addresses are module-relative
and must be checked against the running binary before use. IFix can replace the
compiled paths at runtime; identifying a native method is not proof it is used
by a current live match.

## Outgoing position

- `EPPMGCJDEDC.EJCPAFDIOKB`, `0x613E2F4`, virtual slot 6, invokes
  `AGDFODEDCCP`, `0x613CB84`, for the autonomous local player.
- The on-foot branch checks `Player.get_WaitForForceSync` before sending.
  The cached outer request is at `match + 0x660`, type `message.DCAOPGIKAFE`,
  confirmed from the constructor's decoded pooled-message generic arguments.
- At `0x613D804` it calls `Player.GetSyncStatePos`, `0x57C0B2C`, then
  `LMCBHLCPAJD.DJNIOABIFCA`, `0x3715AC4`, to encode a position. The
  nested state `message.IFHJKHPIJPC` is `request + 0x18`; its encoded position reference is at
  `state + 0x18`. The nested message also contains pose, velocity, rotation,
  firing and movement state; freezing the whole message would freeze unrelated
  state and identifiers. Ghost writes only the position's three int32 components,
  the velocity's three int16 components (`+0x12/+0x14/+0x16`), and the nested
  state/pose bytes (`+0x38/+0x39`). The root's channel/tick and nested player ID,
  rotation and remaining flags are preserved.
- The position encoder writes three numeric components to the encoded object
  at `+0x14`, `+0x18`, `+0x1C`. It quantizes floats by 1000 with rounding.
  Modifying heap references requires the game's GC write barrier; copying
  numeric payload temporarily would avoid replacing those references.
- The outer `DCAOPGIKAFE.Serialize`, `0x276A4D4`, virtual slot 6, is intercepted
  only for the exact cached local request. Serializers call no Unity APIs.
  Nested classes and vector references must match the controller's snapshot.
  Scalar backups live on the stack, avoiding new pooled objects or GC reference
  writes. Serialization exceptions and simultaneous use of those mutable pooled
  objects remain runtime concerns; the busy guard bypasses overlapping calls.
- The send call is `GameFacade.Send`, `0x5926D78`, at `0x613DEB8`, with
  message code `0x7D1`. Other movement states have distinct message branches.
- A mode-setting byte at `+0xA24` enables an additional input/axis request
  cached at `match + 0x668`, `message.GKKODHEIJAL`. Its `Serialize`,
  `0x276B3CC`, virtual slot 6, writes a nested `message.CJLFOJMIOEA`.
  The four full vectors at nested `+0x18/+0x20/+0x28/+0x30` are backed up,
  zeroed only during serialization, and restored, including aliased vectors.

## Incoming correction and return

- `PlayerNetwork.PushPlayerSyncedPosition`, `0x5A487F8`, is an incoming
  interpolation update, not the local outgoing position path.
- `PlayerNetwork.SyncStateWithServer`, `0x5A52EE8`, handles authoritative
  correction. The local branch acknowledges force sync and updates the Unity
  transform through `Transform.set_position`, `0x8D6C2B4`, at `0x5A53680`.
  Its collision-adjustment helper `FLGOOGNLADH`, `0x5A4281C`, can adjust the
  supplied position before this write.
- `Entity.set_Position`, `0x6B49E10`, changes the entity transform. That alone
  does not prove a consistent return of all physics/interpolation state or
  server acceptance. Ghost calls it only in `EPPMGCJDEDC.EJCPAFDIOKB`, not from
  the overlay or a serialization callback; physics/interpolation correction can
  still move the player afterward.
- `Player.IPhysicalCharacter.APICCTTeleport`, `0x562BBD0`, virtual slot 83,
  is a no-op in the unpatched compiled path, including PlayerNetwork's slot.
  It cannot be used as a proven generic teleport implementation.
- `Player.get_PhysicalCCT`, `0x56268C4`, returns `player + 0x268`.
  `PhysicalCCT.ForceSetPosition`, `0x646B648`, writes its position and transform,
  but its availability on standard players across modes is unverified.

## Built-in ghost state

`SendEnterAliveJSGhost` / `SendExitAliveJSGhost` send game-mode requests.
`EnterAliveJSGhost`, `0x5778644`, changes ghost state, movement attributes,
visibility and weapon-related behavior. It is not evidence of a generic,
all-mode frozen-position feature and must not be called as a substitute.

## Guards and validation

The original match update and each original serializer always run once. Exact
native code fingerprints, writable virtual slots, packet identity and class
checks precede installation. Callbacks use a shared signed 16 KiB RX page and a
separate private RW state page for both packaging modes.

Odd/torn snapshots, expired 300 ms leases, replaced owners and knocked players
bypass substitution. A changed match or dead player discards the anchor rather
than returning a replacement entity. Force sync, vehicles, catapults, cannons,
chairs, parachuting, strops, seesaws and moving platforms pause Ghost and return
until eligible; resuming the same epoch reuses its original anchor. Background,
license invalidation and overlay removal cancel without teleporting an old
context. A fresh enable epoch cannot revive an anchor from a cancellation.

`tests/ghost_remote_test.py` executes the actual ELF and Mach-O ARM64 callbacks
in Unicorn, checking preserved ABI, quantization, reversible scalar writes,
aliased vectors, pause/resume, single return, stale-owner guards and command
races. Both release packages compile this callback and controller.

## Remaining device evidence

Establish the actual outgoing path and IFix behavior for each requested mode,
verify serializer thread and pooled message lifetime, resolve the matching
physics return path, and compare the local and opponent views in a controlled
device run. CI can verify callback ABI and reversible packet writes; it cannot
verify what a game server accepts or what another player sees.
