# Native profile evidence — FC Mobile VN 27.1.01

Source supplied locally: `com.garena.game.fcmobilevn_27.1.01_und3fined.ipa`. Executable SHA-256: `9fda6922a81ebbfe052a84bc0fee41a0d804577b2c414c28bb82538ae129180e`. Native ARM64 Mach-O with `cryptid=0`, preferred base `0x100000000`. Addresses below are unslid VAs; runtime offsets subtract the preferred base and add the matched image address.

| Meaning | VA / field | Evidence |
|---|---|---|
| Settings manager global | `0x10a25d478` | Getter at `0x101e85678`: ADRP + LDR + RET |
| User 0 settings object | manager `+0x48` | Getter at `0x101e85120`: indexed slot `0x48 + user*8`; named property getter passes user 0 |
| Property name | `0x104e2e741` | ASCII `GcShotErrorUser` |
| Named property getter | `0x1028a2378` | Branch for property name reaches `0x1028a2fc0`, LDRB from settings `+0x1ce` |
| Named property setter | `0x1028a4ea8` | Branch at `0x1028a5ec0`; STRB value at `+0x1ce`, dirty byte 1 at `+0x1cf` |
| Pre-match consumer | `0x102875e8c` | Gets same manager/user object; at `0x102876000` loads `+0x1ce` into customization stack `+0x56`; dispatches customization message `0x04188149` |
| Serialized shot error multiplier | struct `+0x2a0` | Serializer `0x1022215e8`, string `mCustomizationShotErrorUserMod`; **not used for writes: live root unverified** |
| Serialized shot speed multiplier | struct `+0x2b8` | Serializer `0x102221660`, string `mCustomizationShotSpeedUserMod`; **not modified** |

The AimKill trial uses the Lua flag `lxSetOpenGoalShootingLogic`, which maps to component 123 (`GameplayLogicOverrideManager`), byte 0. The named setter and a shot-evaluation consumer are traced below. They identify a distinct native shooting-logic flag, but do not prove guaranteed goal targeting. Another nearby flag `+0x326` is `lxEnforceDinkedPass`, not a generic accuracy bypass; it remains excluded.

## Active ball and camera

| Meaning | VA / field | Evidence |
|---|---|---|
| Component registry | `0x10a263b60` | `lxGetBallPos` callback `0x10268a55c` |
| Scene and component table | registry `+0`, `+8` | Named Lua callbacks resolve native components through this table |
| GameData component | ID 34, table `+ID*32+0x20` → wrapper `+8` | Component getter `0x102053c10`; runtime accessor `0x1026b3588` loads ball array at `GameData+0x38` |
| Active ball index | scene `+0x226d8` | `lxGetActiveBall` callback `0x10268c5f8` |
| Ball published history | ball `+0x90` → writer `+0x230` | `lxGetBallPos` and `lxGetBallSpeed` callbacks use this path |
| Current frame and position | history `+0x9610`; slot `(frame%600)*64+0x10` | Position load at `0x10268a5c8..0x10268a604` |
| Camera manager | `0x10a2bf528` | Constructor `0x102a5cff0`; native world projection `0x1029844e8..0x102984638` |
| Active camera | index at manager `+0x40`; camera at manager `+index*8` | Index getter `0x1008dcee0`, camera getter `0x102a5cfdc` |
| Camera type | vtable `0x10529d148` | RTTI `N15RenderFramework6CameraE`, typeinfo `0x10529d160` |
| Projection and view | camera `+8` → storage; projection `+0`, view `+0x40` | Getters `0x102a5bedc`, `0x102a5bee4`; native projection uses column-major multiplication and negative camera Z in front |

The ball line validates pointers, matrix values and camera type, then rechecks scene/ball/history/camera identity and the history frame before publishing a sample. The 12-slot upper bound is a conservative limit from the action-ball pool, not a claim that every scene has 12 active balls; an unreadable indexed ball entry is rejected. Mock-memory tests cover projection, quarter-turn camera rotation, translated cameras, invalid values, missing reads and concurrent root/frame replacement.

## AimKill trial — native Open Goal flag

| Meaning | VA / field | Evidence |
|---|---|---|
| Component ID 123 | getter `0x102054180` | `MOV W9,#0x7b`, writes component ID |
| Named Lua setter | `0x10269a7c8` | `lxSetOpenGoalShootingLogic` resolves registry table, wrapper `+0x20` then object `+8`; normalizes the input to boolean and stores byte 0 at `0x10269a818` |
| Native shot evaluation | `0x102512974` | String `Shot::OpenGoal` passed to evaluator `0x10234d1dc`; after success, `0x102512a30` loads the component flag and branches on bit 0 to the path setting evaluation bit `0x20000` |
| Constructor defaults | `0x1023c7c90` | Stores mode enum at `+0xc4`; byte 0 is `mode != 4` at `0x1023c7cac`. Thus the flag may already be enabled in normal play. |

Writes are limited to this single boolean and are read back. Already-enabled flags are reported without taking write ownership. Restoration retains pending state during missing-pointer/denied-read intervals, respects externally changed values and never writes into a replaced component or after its mode enum changes. Tests cover these cases and changing roots/modes between read and write. The runtime profile still requires the exact image UUID. No automatic shot or every-goal guarantee is claimed.

## Physical redirection — still unverified

`lxLaunchBall` (`0x10268d3dc` wrapper → `0x10268ce50`) constructs simulation messages through `0x1021bb898`, which dispatches via a component virtual method. `lxSetBallPos` likewise constructs a physics command via `0x1021bac90`. These are not equivalent to changing the published position/velocity history. `mGoalXPos`/`mGoalZPos` have serialization at `0x102222f34`/`0x102222f48`, but the live root and which goal belongs to the opponent have not been verified. No writes to these unverified objects and no direct native simulation calls are included.

UUID checking prevents the profile being used on another binary, including another regional build. No Unity or Free Fire/AOV offsets are reused. Game-memory writes remain limited to the identified two-byte shot setting and the Open Goal boolean. Replaced objects are never used for restoration. The automated tests cover denied writes, repeated updates, disabling, transient missing pointers, object replacement, external setting changes, and malformed field values. Gameplay remains untested on device.
