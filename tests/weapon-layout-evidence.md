# Weapon settings for Free Fire 1.132.1

These offsets were checked against the supplied IPA's `global-metadata.dat`
(metadata version 31) and decrypted `UnityFramework`, rather than copied from
an earlier game version.

| Field | Owner | Offset | Type |
| --- | --- | --- | --- |
| `IODLOCEJIOK` | `COW.GamePlay.Player` (TypeDef 31767) | `0x768` | `PlayerAttributes` reference |
| `BDOEGBMMEOK` | `COW.GamePlay.PlayerAttributes` (TypeDef 34482) | `0x20` | owning `Player` reference |
| `ShootNoReload` | `PlayerAttributes` | `0x111` | `bool` (one byte) |
| `CILIDJHLLJA` / `FireIntervalScale` | `PlayerAttributes` | `0x258` | `float` |

`get_FireIntervalScale`, token `0x0603C070`, address `0x64877D8`,
contains `0xBD425A60` (`ldr s0, [x19, #0x258]`). Its corresponding setter
at `0x6487830` contains `0xBD025A68` (`str s8, [x19, #0x258]`).
Addresses are image-relative before ASLR.

The supplied `0xD9` falls inside an unrelated float at `0xD8`;
`0x208` refers to another float (`NKEPNFFMCLI`). Neither is used for writes.
Likewise, `Player + 0x700` is a `Transform`, not `PlayerAttributes`.

The controller validates the class name, namespace and owning player, then
rechecks the current task/match/player before writes. Both toggles default off.
Fast fire halves the valid interval scale captured before activation, with a
positive minimum of `0.05`. That baseline is not recalculated from a patched
value. OFF is applied immediately for each switch and retried until readback
confirms restoration, including rounded or cached values. Values which no
longer carry the effect (no-reload already false, or interval at/above its
baseline) are preserved. A replacement component in the same match can retain
the baseline when it demonstrably inherited the last written fields. No writes
are made through the previous owner; a different task discards the old state.

The fixture verifies these guards and restore behavior. It cannot establish
on-device behavior or whether server rules accept the changed firing rate.

## Automatic shot cadence

`HBIBDMMOOOK.ALJMFCJMDCF()` at `0x5C179E8` (virtual 182) sends a shot
event. Calling it once does not install a held trigger in the weapon's firing
state machine. Player PRI21 equal to 2 therefore cannot be used to assume
that subsequent automatic shots will be produced by `Weapon.Update`.

In `POFKDNELDJL.IPFONNHEKFA(float,float)` at `0x5BA3F30`, the game accumulates
dt at state offset `0x24`. At `0x5BA4054..0x5BA40A4` it obtains the weapon,
calls `HBIBDMMOOOK.LDKCJEMDAMC()` at `0x5BF3B0C`, compares accumulated time
with that returned interval, and dispatches virtual 182 when due. The
interval getter multiplies the weapon interval by the player's current
interval modifiers, including the skill and weapon-type modifiers.

AutoFire repeats only its own shot requests using that verified getter and
the original callback's dt. It leaves existing manual fire unclaimed, emits
at most one request per callback, and drops accumulated time on release.
Both the getter's full `0x210` bytes and the above `0x50` call-site bytes are
fingerprinted before installing the callback. The ARM64 emulation tests
check repeated fast/slow gun requests, manual ownership, expiration, and
preservation of the float callback ABI; actual projectiles need device testing.
