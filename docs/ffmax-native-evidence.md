# Bằng chứng native Free Fire MAX 2.132.1

Nguồn: `com.dts.freefiremax_2.132.1_und3fined.ipa` do người dùng cung cấp. IPA chỉ được đọc/giải nén, không chỉnh sửa hay upload.

- Bundle: `com.dts.freefiremax`; version `2.132.1`; build `2019118522`
- Executable: `FreeFireMAX` (đúng chữ hoa)
- UnityFramework: ARM64 Mach-O, magic `0xFEEDFACF`, cryptid `0`
- UnityFramework SHA-256: `4c8ed1c97a9f5f67da158647b99f2e68779a75011eb82a78827b4e2b98e69023`
- Metadata: IL2CPP version 31; SHA-256: `9b17e9c8a3266b6f06ac53957702ed98661ee6b8d1fbd78ec2baae1984243125`

## Native-only RVA được dò riêng

RVA tương đối với UnityFramework, không phải địa chỉ tuyệt đối đã ASLR:

| Điểm dùng | TH 1.132.1 | MAX 2.132.1 | Bằng chứng |
|---|---:|---:|---|
| GameFacade TypeInfo | `0xBB46A50` | `0xBE93418` | CurrentMatch MAX `0x5D4D76C`, ADRP/ADD tại `+0x18/+0x1C`, static fields `+0xB8`, CurrentMatchGame `+8`, match `+0x90` |
| Tracer TypeInfo | `0xBB4BEC8` | `0xBE988C0` | NGMILJIELKA .cctor MAX `0x5D01328`, ADRP/ADD tại `+0x28/+0x2C`, lazy metadata initializer và static fields |
| Metadata initializer | `0xA11121C` | `0xA383BC0` | Call target độc lập ở CurrentMatch và tracer .cctor, fingerprint `0x18` byte |
| Player.PostUpdate block | `0x569C434` | `0x57342C4` | Manager `+0x748`, getter `0x5B4BC74`, virtual update `+0x2F8/+0x300`, hai float s0/s1 |
| Fire interval / shot block | `0x5BA4054` | `0x5C3EDEC` | POFKDNELDJL.IPFONNHEKFA, interval `0x5C77024`, FCMP, slot-182 `+0xC98/+0xCA0` |
| Shot presentation block | `0x5C1E910` | `0x5CA2B2C` | CHBHFOIAMDE, LDP tại `+0x188`, x0..x5 và s0 trước BLR |
| GetSpeedByType block | `0x6482AA0` | `0x6523F98` | LDR s0 `[x20,+0x3C8]`, FCMP 0, B.GT; ba opcode guard giữ nguyên |

Các block được đối chiếu instruction/call flow trong đúng method, không suy ra bằng delta chung. Fingerprint giữ cùng độ dài guard consumer TH, không tuyên bố toàn bộ thân hàm dài bằng nhau.

## Layout và ABI

`profiles/ffmax-native-2.132.1.json` chứa 90 fingerprint, 524 opcode với disassembly đã xem và 47 danh tính virtual method. `tools/verify_max_native.cjs` kiểm tra SHA, byte/code, global và metadata. `MaxNativeVerified.h` cung cấp bảng MAX; unknown RVA/hash/word trả 0, không fallback TH.

Slot theo MAX metadata: weapon update 28 (hai float), begin 182, stop 213, presentation 223; tracer 5; aiming handler 17; match/packet 6; late update 18. Player/PlayerNetwork slot 5 và 26 cùng OnUpdate, slot 174 PostUpdate. Slot swap 201 vẫn là overload hai tham số. Il2CppClass static fields `+0xB8`, vtable base `+0x138` được xác nhận qua native dispatch.

Player.GetWeaponOnHand MAX `0x56ADAFC` đọc manager `+0x748`. Getter manager `0x5B4BC74` dùng cờ `+0x148`, weapon `+0xA0/+0xA8`; owner manager `+0x30`, owner weapon inherited `+0x60` giống hai dump. Handler `0x5CDEC38` đọc aiming-info `+0x28`, owner inherited `+0x10`, direction `+0x40/+0x48`. Native get_IsFiringFromPRI MAX `0x5842490` đọc pool `+0x70`, gọi index 21 và so giá trị 2.

Ghost packet `+0x660/+0x668` thuộc subclass **EPPMGCJDEDC**, không phải trực tiếp JMAGGLCNGIG. Constructor `0x61446D4` ghi hai pooled packet, send path `0x6142858` đọc lại. Giữ packet layout vì field owner/type và serializer signatures khớp.

Controller `Player +0x4D8` TH thành `+0x4E0` MAX; đã sửa resolver và assembly. PhysicalCCT flag `+0x260`, reference `+0x268` không đổi nhưng cũng dùng macro đôi.

## Alias sai / không hoạt động

- `kWeaponOnHand +0x690` TH là FollowCamera, không dùng trong đường weapon hiện tại (đi qua manager). `kWeaponCostAmmo +0x7B9` cũng chỉ là alias cũ không có consumer, chưa xác minh nghĩa ammo.
- `kPlayerIDStruct +0x2D0` là dictionary. Đường ID hiện tại dùng BEADLMGGGGL `+0x408` TH / `+0x410` MAX.
- Visibility `+0xA50/+0xA58` là LevelSwingSpider. Đã bỏ đường đọc cờ `+0x10` sai owner ở cả TH/MAX. Thay bằng AvatarManager `+0x770/+0x778` -> avatar `+0x138`, kiểm tra class/namespace UmaAvatarSimple, byte `+0x101`. Native SetVisible cả hai binary đọc/ghi byte này. Đây là renderer visibility, không chứng minh line-of-sight.
- Knock `+0x1258/+0x1270` có tên IsKnockedDownBleed trong dump. Semantics toggle hiện có giữ nguyên; cần test trạng thái knock thực tế.

## Chưa xác nhận

Chỉ kiểm chứng tĩnh đúng binary cung cấp. Chưa smoke test callback, quyền task/memory mapping, rig/bone semantics, restore OFF, hotfix dispatch runtime hoặc toàn bộ chế độ trận.

Native Unity Camera matrices `+0x80/+0xC0` và Transform hierarchy storage `+0x38/+0x40` không được chứng minh chỉ từ dump managed/fingerprint wrapper. Các vị trí này giữ như TH hiện có và cần kiểm tra trên thiết bị MAX trước phát hành. `fieldAudit` phân loại raw owner/inheritance cũ; không gọi alias chưa xác minh là offset đúng.

Profile chỉ dành cho MAX `2.132.1`; OB mới bắt buộc dò lại. Không đưa binary/metadata game vào repo/artifact menu.
