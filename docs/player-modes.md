# Experimental local player presentation modes

TIPA and dylib share a signed ARM64 OnUpdate wrapper. It supports the
supplied Free Fire 1.132.1 `Player.OnUpdate` and `PlayerNetwork.OnUpdate` native
implementations after full code fingerprints. Class slots with other callbacks
are rejected. Neither mode intercepts incoming packets, freezes network state,
changes gravity/collision configuration, or skips the original player update.

The supplied metadata places `IEntityTicker` at interface offset 4. Its OnUpdate
method 1 occupies class vtable entry 5 (`0x188`), while ordinary Player.OnUpdate
also occupies entry 26 (`0x2D8`). The original implementation patched only entry
26, leaving interface calls untouched. Both entries now point to the same
callback/state; both original pointers must match before installing. Failed
second-slot writes roll back the first without overwriting another hook.

## Burrow

The local player's root transform is lowered 0.45 m after the normal update.
On the next update, the wrapper restores its last normal position before the
game runs movement/physics/animation, then applies one offset to the new normal
position. Disabling leaves the normal update's current position, preserving
horizontal movement rather than teleporting to an old activation point.
If an outside horizontal update carries the applied Y unchanged, the callback
restores only its owned height offset while keeping the newly moved X/Z. This
prevents repeated downward offsets when movement occurs between callbacks.

This is a shallow root-transform prototype. It does not replace the game's
physical controller. Live collision/grounding, camera behavior, correction
timing and server acceptance still need device testing. The emulator proves
that the wrapper does not subtract height repeatedly across its own updates;
it cannot prove that every native physics path always keeps a player grounded.
The feature pauses for vehicles, parachuting and pending force sync.

## Aimlag

The HUD publishes only enemy entities from the current match, excluding the
local player, teammates, dead and knocked entities. Scoping starts an epoch;
each enemy captures its displayed root position on its first eligible update.
Before later updates, the wrapper restores the latest normal position, runs the
original update, saves the newly interpolated position, and reapplies the
captured visual position. Releasing scope discards the override after running
the normal update. Animation, health and incoming interpolation continue.

This changes client transforms; it does not freeze an opponent on the server
or on another player's device. Seeing a frozen target does not establish that
the server will accept shots at that displayed position.

## Ownership and verification

Callbacks hold at most 64 entity entries in a private RW page, with separate
data for each supported class's original callback. A shared signed 16 KiB RX
page contains no runtime relocations. The HUD writes only input snapshots;
game callbacks exclusively own their output rows. Finite/nonzero position checks,
native match/local ownership, health, knock, an even publication sequence and
a 250 ms lease precede application. A changed/dead owner discards old state.
An incoming transform change is not overwritten with the previous saved normal
position. Entity.UniqueID distinguishes recycled pointers, including replacement
entities spawning nearby. Small external interpolation/fixed updates keep the
scoped anchor without restoring stale normal data. Movement more than 4 m from
the latest saved normal position starts a fresh anchor. OFF/expired leases allow
the next eligible entity update to restore a held override.

`tests/player_modes_remote_test.py` emulates the actual Mach-O and ELF callback,
including 100 local motion updates, continually advancing enemy interpolation,
scope release/re-entry, simultaneous roles, corrections, fixed capacity, stale
owners, unsupported movement, publication races and preserved ARM64 ABI.
It also executes interface-slot dispatch and interleaved external transform
updates, reproducing the two failures missed by directly calling the wrapper.
`tests/player_modes_install_test.cpp` checks paired installation, no per-frame
rewrites, rejected conflicting hooks, rollback and preserved MethodInfo pointers.

The HUD samples native ticks/application counts and held rows at 5 Hz. Installing
a slot alone no longer claims an effect: stopped ticks show "chờ nhịp game";
Aimlag shows whether scoping/eligible enemies are available. Diagnostic mode
includes counts and a failing code offset. Failure messages identify fingerprint,
clock lookup, mapping and callback-write stages. Unsupported enemy classes do
not cancel supported enemies or an installed local Burrow callback.

## Quick controls

Each enabled AimKill, Ghost or Burrow menu row exposes one draggable glass-style
control with a label below it. Tapping OFF keeps that quick control visible so
it can be re-enabled; disabling its row in the menu hides the quick control.
Positions persist and are clamped to the screen after rotation. Native UIKit
and the standalone HUD's routed multi-touch path use the same control actions.
