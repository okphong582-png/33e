# Android Việt — Free Fire thường

Ứng dụng Android native, giao diện dựa trên bản Mizze TIPA: nhập key → Start → menu nổi Aim / ESP / Màu sắc / Thiết lập. Màu mint, theme tối/sáng, ô kiểm dấu chéo và nhãn tiếng Việt được chuyển sang Android.

## Hai APK

| Bản | App ID | Quyền root |
|---|---|---|
| Root | vn.mizze.androidviet.root | Start xin quyền bằng su qua Magisk/SuperSU. Từ chối hoặc hết 60 giây thì không mở menu. |
| No Root | vn.mizze.androidviet.noroot | Không gọi su; dùng quyền Hiển thị trên ứng dụng khác. |

Hai bản cài cùng lúc được. ANDROID_ID phụ thuộc thiết bị, user và khóa ký; cùng khóa ký trên cùng máy có thể dùng chung key đã gắn. Đổi khóa ký có thể cần admin gỡ binding. Đây là APK debug ký để cài thử, chưa phải release có khóa ký ổn định.

## Phạm vi hoạt động thực tế

- Nhập key qua Firebase protocol v4; hash SHA-256 sau trim/uppercase, không lưu key thô.
- Ràng buộc máy nguyên tử bằng if-match: null_etag; chỉ đăng nhập chủ động được nhận binding mới.
- Định danh Android dựa trên ANDROID_ID, namespace khác iOS. Key đã gắn với iPhone cần admin gỡ máy hoặc cấp key khác.
- Kiểm tra khóa/hết hạn/xóa/disabled/binding mismatch; dùng Date HTTPS và đồng hồ monotonic, lease tối đa 30 giây, polling mỗi 8 giây. Không nhận lease từ PUT, không lưu lease qua restart. Chưa có SSE tức thì như iOS.
- Start yêu cầu quyền overlay; menu kéo được, thu gọn bằng ×, mở bằng m, xử lý xoay màn hình và dừng từ thông báo. Mất quyền hoặc hết phiên thì dừng. Theme và FLAG_SECURE áp dụng cho cửa sổ ứng dụng.
- Root kiểm tra uid 0 và dùng helper app_process đọc /proc/PID/maps, /proc/PID/mem của com.dts.freefireth. Người dùng đã xác nhận tên đọc được đúng trên cloudphone root.
- Đã nối backend ghi dữ liệu cho **Không nạp đạn, Bắn nhanh (2×), Speed**. Nút chỉ mở khi thư viện, class/owner PlayerAttributes, quyền mở bộ nhớ ghi và giá trị dữ liệu khớp. Thay đổi gửi đến helper, ghi đúng trường dữ liệu và đọc lại xác nhận; helper phân biệt yêu cầu với kết quả ghi; log kỹ thuật được giữ nội bộ, không hiện trong menu.
- Bắn nhanh giảm FireIntervalScale về 0.5 lần baseline, không nhân dồn mỗi tick. Speed dùng ForceSetRunAndDashSpeed, giới hạn 0.1–30 m/s. Đây là giá trị client, chưa xác nhận tác động thực tế trong game/server.
- Khi tắt chức năng, helper khôi phục baseline nếu trường vẫn giữ giá trị helper đã ghi. Giá trị do game thay đổi được giữ lại. Không ghi khôi phục qua PID tái sử dụng, trận hoặc đối tượng khác. Mất phiên/đóng menu/pipe cha đóng sẽ thử khôi phục tối đa ba lần trước khi helper thoát; không thể bảo đảm khôi phục nếu bị kill ngay, game đã thay đối tượng hoặc quyền ghi bị thu hồi.
- Mỗi lần mở menu, chờ backend hợp lệ rồi tự bật một lần: súng/Speed, ESP và Aim đầu khi bắn hoặc ngắm. Có công tắc Tự bật khi vào trận để tắt hành vi này. Tắt thủ công trong phiên được giữ nguyên, không bị ép bật lại mỗi frame. Aim đầu/cổ là hai lựa chọn loại trừ nhau; mặc định tự bật Aim đầu. Khi dừng menu, công tắc áp dụng trở về tắt. No Root không gọi su hoặc backend ghi.

- Đã nối bộ đọc **ESP** thật: Match dictionary → Player → TransformData và PRI, cùng camera Unity. Vẽ tên, HP, khoảng cách, xương, điểm đầu, khung 2D/3D, trục XYZ; hỗ trợ màu và preset tối giản. Chỉ vẽ frame còn mới dưới 500 ms, không dùng dữ liệu mô phỏng trong app.
- **Aim đầu/cổ** chọn mục tiêu trong FOV, loại nhân vật local/đồng đội/HP bằng 0; điều kiện bắn, ngắm, luôn luôn hoặc fire + scope. Ghi Quaternion +0x614 khi chế độ getter/setter, rotation cũ, quyền ghi và match còn khớp. Aim cổ dùng cùng ước lượng iOS: tối đa 10 cm dưới đầu thật. Tắt Aim ngừng ghi, không khôi phục góc nhìn cũ.
- Mỗi lần ghi Aim kiểm tra cấu hình không bị thay, frame dưới 300 ms và lease còn hạn; thay PID/starttime/trận/nhân vật/dictionary sẽ bỏ frame. Lớp vẽ không nhận chạm, alpha cửa sổ 0.75, mất phiên thì bị tháo cùng menu.

**Silent, AimKill, Aimlag, Ghost, FakeLag, Fly và Spin chưa có backend Android và vẫn khóa.** Không thể xác nhận mọi chức năng hoạt động 100% chỉ từ Local Name. ESP/Aim và ba trường PlayerAttributes có backend bộ nhớ thật nhưng chưa được thử trong trận trên cloudphone; IFix hoặc cập nhật game có thể làm dữ liệu/chế độ khác. Các xương tay dựa trên field Android phù hợp rig iOS, vẫn cần xác nhận trực tiếp.

Profile trong profiles/free-fire-1.132.1-arm64.json ghi hash binary, lệnh ARM64 và trường dữ liệu. Metadata version 31 sử dụng method stride 40. Mỗi lần ghi kiểm tra lại PID/starttime, match/player, class PlayerAttributes và owner. Không sửa mã thực thi, không tiêm lệnh vào game, không tắt SELinux. IFix/hot patch và logic server có thể làm thay đổi tác dụng dù trường ghi đã được đọc lại. XAPK/APK game/thư viện gốc chỉ giữ tại máy, không đưa lên GitHub.

## Cài và chạy

1. Tải Root hoặc No Root từ Artifacts workflow **Android Viet APK**.
2. Cài APK, nhập key hợp lệ từ hệ thống Firebase hiện có.
3. Bấm Start, cho phép Hiển thị trên ứng dụng khác; quay lại bấm Start.
4. Bản Root: chọn Cho phép trong Magisk/SuperSU. Bản No Root bỏ qua bước này.
5. Mở Free Fire thường 1.132.1 ARM64 và vào trận. Menu không hiện log kỹ thuật theo yêu cầu. ESP/Aim mở khi camera/xương/PRI khớp; bật ESP hoặc preset, rồi chọn các mục muốn vẽ. Aim đầu/cổ cần chọn thêm điều kiện kích hoạt.
6. Chạm m để mở menu; dùng Dừng menu trong Thiết lập hoặc thông báo để tắt.

## Build

JDK 17 + Android SDK 35. Gradle 8.11.1 wrapper có checksum; AGP 8.9.2; min SDK 26 (Android 8), target SDK 35 (Android 15). Không cần Theos/Xcode hoặc root để build.

    ./gradlew :app:assembleRootDebug :app:assembleNoRootDebug
    ./gradlew :app:testRootDebugUnitTest :app:testNoRootDebugUnitTest :app:lintRootDebug :app:lintNoRootDebug

Windows dùng gradlew.bat. local.properties có thể khai báo sdk.dir; file bị gitignore. android.overridePathCheck cho phép thư mục tiếng Việt.

Outputs:
- app/build/outputs/apk/root/debug/app-root-debug.apk
- app/build/outputs/apk/noRoot/debug/app-noRoot-debug.apk

Workflow .github/workflows/android-viet.yml build hai APK, unit test và lint; smoke test giao diện trên emulator Android 15. Smoke test render menu, kiểm tra service overlay tự dừng khi lease hết, helper tuân thủ Root/No Root và từ chối chạy khi chưa có uid 0. Lease của test chỉ gán bằng reflection trong tiến trình instrumentation; APK không có đường bypass key, test không ghi Firebase hoặc giả dữ liệu game. Đường đọc tên đã được người dùng xác nhận trên cloudphone; ESP/Aim và các chức năng ghi chưa được xác nhận trong trận. Unit test thêm phép chiếu, LookRotation, TRS và vòng lặp/giới hạn traversal; smoke test thêm capability frame còn mới/quá hạn và surface vẽ/xóa đúng. Frame dùng trong test là fixture gắn bằng reflection, không có trong ứng dụng sản xuất.

## Cấu hình key

app/src/main/res/raw/license_config.json dùng cùng database public-client của iOS. Không có service-account/admin secret trong APK. Firebase Rules v4 quyết định quyền đọc từng hash và binding. Không sửa dữ liệu live trong quá trình build/test. Cần key do chủ hệ thống cấp để kiểm chứng kết nối thực tế.

Sửa lỗi cloudphone “Unknown transform node”: bộ đọc nhận đủ ba lớp ITransformNode trong metadata Android, gồm BFOONIGAIFK (getter 0x70D847C), TransformNode namespace rỗng (0x3793898) và GCommon.TransformNode (0x8251764). Xác minh lệnh getter +0x10/ret trước khi theo con trỏ; tên/namespace khác hoặc code đã đổi vẫn bị từ chối.

ESP có Đường nối tới người chơi riêng với Trục XYZ; preset tối giản cũng bật đường nối. Tự bật chỉ áp dụng backend đã có dữ liệu hợp lệ, không mở giả Silent/AimKill/Aimlag hoặc chức năng chưa có backend.

### ESP synchronization and auxiliary Aim update

The root reader reuses its process memory channel, searches mappings by address, caches immutable metadata labels and reads optional ESP shapes only when selected. Mapping refresh is bounded to 2 seconds; PID/start identity still guards writes. Sampling targets a 33 ms cycle instead of sleeping 50 ms after every read. Rendering skips unchanged frames and caches projected points. Rotation sends viewport configuration immediately, rejects earlier viewport generations and clears samples older than 250 ms. This is an optimization, not a measured FPS guarantee on the cloudphone.

Silent Aim uses local auxiliary quaternion +0x628, independently of normal camera aim +0x614. Availability requires the local-player marker, valid quaternion and verified Android getter/reset/weapon consumer instructions. While Silent is selected, normal aim writes are suspended; auxiliary writes require firing, a fresh target and the chosen head/neck point. On stopping the trigger or switching off, restore follows the game's reset semantics only if the last written quaternion remains unchanged. The game's own reset can race external writes; Silent effectiveness must still be checked on the actual ARM64 game. Silent headshot percentage, AutoConfig and AimKill remain unavailable. Automatic Aim now selects head and firing only; neck is selectable. Technical status stays out of the menu.
