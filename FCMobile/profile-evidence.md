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

The optional-looking Lua flag `lxSetOpenGoalShootingLogic` maps to component 123 (`GameplayLogicOverrideManager`), byte 0. Its consumers include shot evaluation, but a name alone does not prove guaranteed goal targeting. It is deliberately excluded from this implementation. Another nearby flag `+0x326` is `lxEnforceDinkedPass`, not a generic accuracy bypass; it is also excluded.

UUID checking prevents the profile being used on another binary, including another regional build. No Unity or Free Fire/AOV offsets are reused. Runtime access is limited to the identified two-byte setting. A replaced settings object is never used for restoration. The automated tests cover denied writes, repeated updates, disabling, transient missing pointers, object replacement, external setting changes, and malformed field values. Gameplay remains untested on device.
