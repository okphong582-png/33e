# Offset FF thường / Free Fire MAX và cập nhật OB

Đã đối chiếu FF thường `1.132.1` và MAX `2.132.1` trong `33e-git`: 87 hàm, 68 field từ dump. IPA MAX bổ sung 90 fingerprint, 524 instruction word và 47 danh tính virtual method. Xem [bảng dump](offset-comparison-2.132.1.md), [native evidence](ffmax-native-evidence.md). Đây là kiểm chứng tĩnh, chưa xác nhận chạy trên thiết bị.

## Dò khi OB mới cập nhật

Chạy từ `33e-git`, đổi đường dẫn sang thư mục dump mới:

```sh
node tools/update_game_offsets.cjs --dump "../FF-dumper-th_1.132.1" --variant th --out "packages/offset-candidates/th"
node tools/update_game_offsets.cjs --dump "../FF-dumper-max_2.132.1" --variant max --out "packages/offset-candidates/max"
```

Công cụ ghép hàm bằng `Name + Signature + TypeSignature`, field bằng owner/tên/khai báo, xuất JSON/Markdown có dòng bằng chứng và SHA-256. Không chọn overload đầu tiên hoặc cộng delta chung. Missing/ambiguous trả exit code 2, không tạo header mới; header cũ trong thư mục ứng viên được đánh dấu `#error` để không dùng nhầm.

MAX xuất cặp header TH/MAX khi toàn bộ danh tính ghép được. TH chỉ xuất báo cáo, không được cài header TH vào nhánh MAX. Không tự ghi đè `esp/Core`. Nếu obfuscation đổi tên, tìm lại getter/semantics trong dump và disassembly rồi cập nhật catalog sau khi xem xét.

Quy trình nâng OB:

1. Đối chiếu cả hai dump, cập nhật mốc TH và bảng đôi; phân biệt owner và ABI/overload.
2. Lấy native ARM64 decrypted, metadata, Info.plist đúng OB; dò lại globals, block trong hàm, IL2CPP/vtable và field inherited. Vị trí tương đối trong hàm không cố định.
3. Kiểm tra semantics trước khi tính hash mới; cập nhật native manifest/header và tests. Không tái dùng native profile 2.132.1 cho OB khác, không tạo stub trả nguyên địa chỉ/hash TH.
4. Chạy scanner/tests C++/assembly, build/link iOS; smoke test đúng process/bundle, ESP, weapon, OFF/restore, đổi trận/chết/knock và thoát game.

Hai snapshot JSON từ dump giữ `nativeVerified: false`. Native MAX nằm riêng ở `profiles/ffmax-native-2.132.1.json`, có hash binary/metadata và `runtimeVerified: false`.

## Kiểm tra binary MAX đã cung cấp

Giải nén ra thư mục riêng:

```text
Payload/FreeFireMAX.app/Frameworks/UnityFramework.framework/UnityFramework
Payload/FreeFireMAX.app/Data/Managed/Metadata/global-metadata.dat
```

```sh
node tools/verify_max_native.cjs "/path/to/UnityFramework" "/path/to/global-metadata.dat"
node tests/game_profile_test.cjs
```

Verifier chỉ đọc file, từ chối SHA-256 khác và kiểm tra fingerprint/opcode/global/metadata slots. Nó không tự dò offsets cho binary mới hoặc chứng minh runtime. `tools/native_arm64_dump.cpp` là helper ARM64/Capstone cho Windows, không phải scanner OB tự động.

## Build MAX: chỉ TIPA và dylib

Workflow [build-max.yml](../.github/workflows/build-max.yml) chạy khi push main/master hoặc workflow_dispatch, có matrix đúng `tipa`, `dylib`. Không Aimlag riêng, không inject IPA game, không Dopamine/DEB. MAX dùng `PACKAGE_FORMAT=none`; Theos stage/sign, after-package xuất artifact yêu cầu.

```sh
make clean package GAME_VARIANT=max BUILD_KIND=tipa
make clean package GAME_VARIANT=max BUILD_KIND=dylib
```

Đầu ra: `packages/max/Mizze-MAX.tipa`, `packages/max/Mizze-MAX.dylib`. Process đúng IPA là **FreeFireMAX**, bundle `com.dts.freefiremax`. Dylib từ chối bundle TH; profile TH giữ `FreeFire`/`com.dts.freefireth`.

TIPA dùng bundle identifier HUD hiện có, cài MAX thay HUD TH, chưa hỗ trợ cài hai HUD song song. Dylib giữ install name `@rpath/libsubsystem.dylib` cho contract injector hiện có; tên artifact là `Mizze-MAX.dylib`.

Máy Windows này thiếu make/iOS SDK/toolchain Theos link hoàn chỉnh. Sau khi push commit `427f5a0`, [CI FF thường](https://github.com/okphong582-png/33e/actions/runs/37739762638) và [CI MAX](https://github.com/okphong582-png/33e/actions/runs/37739762660) đều thành công, đã có TIPA/dylib trong Artifacts. Chưa chạy thử trên thiết bị; xem [báo cáo kiểm tra](offset-profile-validation.md).
