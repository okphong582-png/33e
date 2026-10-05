# Ghost Mode: verified client paths and unresolved runtime behavior

Status: investigation only. No Ghost switch or networking hook is enabled in
either package. The requested behavior is a frozen position seen by opponents,
continued local movement, and a return to the captured position on disable, in
every mode. A screen marker alone does not implement that behavior.

These observations come from read-only disassembly of the supplied Free Fire
1.132.1 UnityFramework and its global-metadata.dat. Addresses are module-relative
and must be checked against the running binary before use. IFix can replace the
compiled paths at runtime; identifying a native method is not proof it is used
by a current live match.

## Outgoing position

- `EPPMGCJDEDC.EJCPAFDIOKB`, `0x613E2F4`, virtual slot 6, invokes
  `AGDFODEDCCP`, `0x613CB84`, for the autonomous local player.
- The on-foot branch checks `Player.get_WaitForForceSync` before sending.
  The cached outer request is at `match + 0x660`, type `message.MGOOHLKKFEM`.
- At `0x613D804` it calls `Player.GetSyncStatePos`, `0x57C0B2C`, then
  `LMCBHLCPAJD.DJNIOABIFCA`, `0x3715AC4`, to encode a position. The
  nested state is `request + 0x18`; its encoded position reference is at
  `state + 0x18`. The nested message also contains pose, velocity, rotation,
  firing and movement state; freezing the whole message would freeze unrelated
  state and identifiers.
- The position encoder writes three numeric components to the encoded object
  at `+0x14`, `+0x18`, `+0x1C`. It quantizes floats by 1000 with rounding.
  Modifying heap references requires the game's GC write barrier; copying
  numeric payload temporarily would avoid replacing those references.
- The outer `MGOOHLKKFEM.Serialize`, `0x2574790`, virtual slot 6, serializes
  the nested objects at `+0x18` and `+0x20`. It is a candidate interception
  point, but the ownership, pooling lifetime and serialization thread must be
  established on the device before calling any Unity APIs there.
- The send call is `GameFacade.Send`, `0x5926D78`, at `0x613DEB8`, with
  message code `0x7D1`. Other movement states have distinct message branches.
- A mode-setting byte at `+0xA24` enables an additional input/axis request
  cached at `match + 0x668`. Freezing only position is therefore insufficient
  evidence of frozen server movement in every mode.

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
  server acceptance. A return callback needs a verified game-thread context.
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

## Remaining evidence needed

Establish the actual outgoing path and IFix behavior for each requested mode,
verify serializer thread and pooled message lifetime, resolve the matching
physics return path, and compare the local and opponent views in a controlled
device run. CI can verify callback ABI and reversible packet writes; it cannot
verify what a game server accepts or what another player sees.
