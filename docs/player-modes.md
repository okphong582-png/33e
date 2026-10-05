# Experimental local player presentation modes

TIPA and dylib share signed ARM64 OnUpdate/PostUpdate wrappers. They support the
supplied Free Fire 1.132.1 `Player.OnUpdate` and `PlayerNetwork.OnUpdate` native
implementations after full code fingerprints. Class slots with other callbacks
are rejected. Neither mode intercepts incoming packets, freezes network state,
changes gravity/collision configuration, or skips the original player update.

The supplied metadata places `IEntityTicker` at interface offset 4. Its OnUpdate
method 1 occupies class vtable entry 5 (`0x188`), while ordinary Player.OnUpdate
also occupies entry 26 (`0x2D8`). The original implementation patched only entry
26, leaving interface calls untouched. Both entries now point to the same
callback/state; both original pointers must match before installing. Failed
later-slot writes roll back previous entries without overwriting another hook.

The supplied Player and PlayerNetwork vtables also contain `Player.PostUpdate`
at entry 174 (`0xC18`), native body `0x569C1E4`, size `0x2BAC`, FNV-1a
`0x458F369A`. Match update implementations `0x5BA4414`, `0x5C83250`,
`0x5C87950` and `0x5C8DFB0` dispatch through this entry. This late method runs
high-frame/avatar presentation after the early update, so an OnUpdate-only
override can be overwritten before display. A separate entry at callback +16
calls the verified PostUpdate original and reuses the SAME anchor/state page.
Each phase runs its own original exactly once. Local PostUpdate bypasses visual
enforcement so Burrow retains its existing timing. All three pointers are
preflighted together, including the distinct PostUpdate original/callback;
any failed pointer write rolls back preceding owned writes.

## Burrow

The local player's root transform is lowered 2 m by default after the normal
update. The menu's depth control ranges from 1 to 2.25 m. Both controller and
native callback reject non-finite or unbounded depths.
On the next update, the wrapper restores its last normal position before the
game runs movement/physics/animation, then applies one offset to the new normal
position. Disabling leaves the normal update's current position, preserving
horizontal movement rather than teleporting to an old activation point.
If an outside horizontal update carries the applied Y unchanged, the callback
restores only its owned height offset while keeping the newly moved X/Z. This
prevents repeated downward offsets when movement occurs between callbacks.

This is a root-transform prototype. It does not replace the game's
physical controller. Live collision/grounding, camera behavior, correction
timing and server acceptance still need device testing. The emulator proves
that the wrapper does not subtract height repeatedly across its own updates;
it cannot prove that every native physics path always keeps a player grounded.
The feature pauses for vehicles, parachuting and pending force sync.

## Aimlag and FakeLag

The HUD publishes only enemy entities from the current match, excluding the
local player, teammates, dead and knocked entities. Aimlag requires scoping;
FakeLag holds enemies while enabled without requiring scoping. A hold starts an epoch;
each enemy captures its displayed root position on its first eligible update.
Before later updates, the wrapper restores the latest normal position, runs the
original update, saves the newly interpolated position, and reapplies the
captured visual position after both OnUpdate and PostUpdate. Aimlag tolerates false scope samples for 180 ms;
an actual scope release ends the hold after that grace. Turning off FakeLag
releases unless scoped Aimlag still owns the hold. Burrow/depth changes and
switching between Aimlag/FakeLag during the same active hold preserve its epoch.
Animation, health and incoming interpolation continue.

This changes client transforms; it does not freeze an opponent on the server
or on another player's device. Seeing a frozen target does not establish that
the server will accept shots at that displayed position.

## Ownership and verification

Callbacks hold at most 64 entity entries in a private RW page, with separate
data for each supported class's original callback. A shared signed 16 KiB RX
page contains no runtime relocations. The HUD writes only input snapshots;
game callbacks exclusively own their output rows. Finite/nonzero position checks,
native match/local ownership, health, knock, an even publication sequence and
a one-second lease precede application. A changed/dead owner discards old state.
An incoming transform change is not overwritten with the previous saved normal
position. Entity.UniqueID distinguishes recycled pointers, including replacement
entities spawning nearby. Small external interpolation/fixed updates keep the
anchor without restoring stale normal data. Distance alone does not release the
same entity, including large native force sync/teleports. Special movement and
force-sync guards apply only to local Burrow; enemy simulation continues normally
while held visually. OFF/expired leases allow
the next eligible entity update to restore a held override.

`tests/player_modes_remote_test.py` emulates the actual Mach-O and ELF callback,
including 100 local motion updates, continually advancing enemy interpolation,
scope release/re-entry, simultaneous roles, corrections, fixed capacity, stale
owners, unsupported movement, publication races and preserved ARM64 ABI.
It also executes interface-slot dispatch and interleaved external transform
updates, reproducing the two failures missed by directly calling the wrapper.
`tests/player_modes_install_test.cpp` checks paired installation, no per-frame
rewrites, rejected conflicting hooks, rollback and preserved MethodInfo pointers.

The lease is 1 s to tolerate brief host-frame stalls; lifecycle/permission/context
cancellation still publishes OFF immediately. Concurrent/odd input publication
skips applying a torn snapshot and retains the anchor for the next complete
publication, instead of permanently dropping it. It may expose a normal position
for that deferred frame; it does not prevent all client render-stage overwrites.
`tests/player_modes_control_test.cpp` checks sustained scope with noisy samples,
FakeLag without scope, overlapping holds, independent local switches, scope
release and depth bounds. ARM64 tests check publication races after capture,
200 large outside movements, special movement and latest-position release.

The HUD samples native ticks/application counts and held rows at 5 Hz. Installing
a slot alone no longer claims an effect: stopped ticks show "chờ nhịp game";
Aimlag shows whether scoping/eligible enemies are available. Diagnostic mode
includes early/late phase counts and a failing code offset. A hold is reported
only while late-phase ticks advance; installed pointers alone show "chờ nhịp
hiển thị". Failure messages identify fingerprint,
clock lookup, mapping and callback-write stages. Unsupported enemy classes do
not cancel supported enemies or an installed local Burrow callback.

The late-phase regression first runs the old unwrapped PostUpdate to reproduce
the moving visual, then executes real slot-174 dispatch for 120 running/jumping
frames. Tests check the shared anchor, latest release/re-enable, separate original
dispatch, guarded publication, unchanged local Burrow and unlisted teammates.
This does not lock skeletal animation or establish device render order for every
game mode/IFix replacement; those still require an iPhone test.

## Quick controls

Each enabled AimKill, Ghost, Burrow or FakeLag menu row exposes one draggable glass-style
control with a label below it. Tapping OFF keeps that quick control visible so
it can be re-enabled; disabling its row in the menu hides the quick control.
Positions persist and are clamped to the screen after rotation. Default placement
uses another column when four controls do not fit vertically, preventing overlap
on short landscape screens. Native UIKit
and the standalone HUD's routed multi-touch path use the same control actions.
