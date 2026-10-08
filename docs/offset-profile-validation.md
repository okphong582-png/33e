# Kiểm tra profile offset

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

Chưa build/link iOS đầy đủ: thiếu make, WSL hoạt động, SDK và toolchain Theos link. Chưa có `.tipa`/`.dylib` MAX mới, chưa dispatch CI, chưa smoke test thiết bị. Native Unity camera/transform storage và hành vi runtime vẫn cần xác nhận; xem [giới hạn native evidence](ffmax-native-evidence.md).
