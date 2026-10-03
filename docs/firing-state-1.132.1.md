# Firing state in the supplied Free Fire 1.132.1 IPA

The previous reader treated `Player + 0x770` as a boolean. The supplied
IPA's metadata identifies that field as `AvatarManager GGJOLDEEIEN`.
Reading its lowest address byte explains the zero or varying values between
matches; it does not represent firing.

The relevant native getter is `COW.GamePlay.Player.get_IsFiringFromPRI`,
metadata method token `0x06033f43`, at UnityFramework-relative address
`0x57a9a5c`. Its ordinary path reads the player's PRI object at `0x70`,
requests value index `21`, then returns whether that value equals `2`.

| Address | Instruction word | Meaning |
| --- | --- | --- |
| `0x57a9ad0` | `0xf9403a73` | `ldr x19, [x19, #0x70]` |
| `0x57a9b58` | `0x528002a1` | `mov w1, #21` |
| `0x57a9b60` | `0x7100081f` | `cmp w0, #2` |
| `0x57a9b64` | `0x1a9f17e0` | `cset w0, eq` |

Inputs were extracted locally from the supplied IPA. SHA-256:

- UnityFramework: `ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8`
- global-metadata.dat: `597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d`

Metadata field layouts were inspected with the official
[Il2CppDumper](https://github.com/Perfare/Il2CppDumper). Method tokens and native
instructions were checked directly against the supplied files.

`GamePRI::TryUInt16` uses the existing bounded PRI pointer chain, checks every
read, and leaves output untouched on failure. Firing uses the verified state
comparison; unavailable data never activates aim. `get_FiringByte` retains its
normalized `0/1/-1` compatibility contract. Diagnostics show normalized firing
separately from the raw PRI value. Tests cover burst/release transitions,
changing AvatarManager pointers, invalid PRI states, failed reads and the
existing HP/scope layout. Device validation is still needed for runtime patches
or a different game build.
