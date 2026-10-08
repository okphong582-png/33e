# Kiểm tra profile offset

## Kết quả build GitHub Actions

Commit mã `427f5a05c94aefaaeaa9f0ebcd0b23d4dffdbc4b` đã push lên main ngày 08/10/2026:

- [FF thường](https://github.com/okphong582-png/33e/actions/runs/37739762638): tất cả job thành công, có Mizze-tipa, Mizze-dylib, Mizze-aimlag và Mizze-Dopamine theo workflow TH hiện có. Các bước Python/Unicorn TH, license rules và test macOS cũng qua trên CI.
- [FF MAX](https://github.com/okphong582-png/33e/actions/runs/37739762660): hai job tipa/dylib thành công; chỉ có Mizze-MAX-tipa và Mizze-MAX-dylib. Dylib đã qua kiểm tra ARM64, signature staged, dependencies tối thiểu, không +load và đủ protection sections.

CI chứng minh compile/link/package và các test ghi ở workflow; không thay thế smoke test game trên thiết bị. MAX chưa chạy các test Unicorn với field fixture riêng của MAX. Các giới hạn Camera/Transform native vẫn giữ nguyên.

## Kiểm tra cục bộ trước khi push

Đối chiếu ngày 08/10/2026, sau khi nhận IPA MAX:

- Dump TH/MAX: 87/87 danh tính hàm, 68/68 field ghép duy nhất. Scanner tạo lại headers giống snapshot.
- IPA MAX: bundle `com.dts.freefiremax`, version `2.132.1`, build `2019118522`, executable `FreeFireMAX`; UnityFramework ARM64, cryptid=0.
- `verify_max_native.cjs` chạy trên binary/metadata giải nén: đúng SHA-256, 90 fingerprint, 524 word, 47 virtual method và bảng virtual Player/PlayerNetwork qua. Slot 5/26 cùng OnUpdate, 174 PostUpdate.
- `game_profile_test.cjs` qua. MAX compile-time assertions bao phủ 87 method RVA, 7 native RVA, 90 hash và opcode guards.
- CLI scanner tests qua: đúng overload/chữ ký, missing/ambiguous exit 2, header cũ bị vô hiệu hóa; không tự promote dump thành native profile.
- C++ TH/MAX: profile fields, cached offsets, avatar visibility, weapon features, PRI, controller/control, callback binding và external weapon chain đều qua. Test Windows link static; callback binding dùng tên executable không chứa install để tránh UAC filename heuristic.
- Avatar tests: visible 0/1/invalid, class/namespace sai, null/out-of-range; LevelSwingSpider không override visibility. Native SetVisible cả TH/MAX đọc/ghi +0x101.
- Bốn callback ARM64 TH/MAX compile Mach-O/ELF. Các section TH giống từng byte với HEAD trước refactor; offset khác chỉ áp dụng MAX.

Chưa chạy Python/Unicorn: Python hệ thống và bundled lỗi startup `0xC00000FD`, kể cả --version. Không coi test mô phỏng đã qua. Test C++ không thay thế callback chạy thật.

Máy Windows không build/link iOS cục bộ vì thiếu make, WSL hoạt động, SDK và toolchain Theos link. Sau khi push, GitHub Actions đã tạo artifact như ghi ở trên. Chưa smoke test thiết bị; native Unity camera/transform storage và hành vi runtime vẫn cần xác nhận, xem [giới hạn native evidence](ffmax-native-evidence.md).
