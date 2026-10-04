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
Fast fire halves the current valid interval scale, with a positive minimum of
`0.05`. Disabling restores the saved value only while the same verified owner
and last written value remain current. Failed restores are retried; a changed
owner is discarded without writing through stale pointers.

The fixture verifies these guards and restore behavior. It cannot establish
on-device behavior or whether server rules accept the changed firing rate.
