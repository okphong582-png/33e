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
- Đã nối backend ghi dữ liệu cho **Không nạp đạn, Bắn nhanh (2×), Speed**. Nút chỉ mở khi thư viện, class/owner PlayerAttributes, quyền mở bộ nhớ ghi và giá trị dữ liệu khớp. Thay đổi gửi đến helper, ghi đúng trường dữ liệu và đọc lại xác nhận; trạng thái trong Thiết lập phân biệt yêu cầu với kết quả ghi.
- Bắn nhanh giảm FireIntervalScale về 0.5 lần baseline, không nhân dồn mỗi tick. Speed dùng ForceSetRunAndDashSpeed, giới hạn 0.1–30 m/s. Đây là giá trị client, chưa xác nhận tác động thực tế trong game/server.
- Khi tắt chức năng, helper khôi phục baseline nếu trường vẫn giữ giá trị helper đã ghi. Giá trị do game thay đổi được giữ lại. Không ghi khôi phục qua PID tái sử dụng, trận hoặc đối tượng khác. Mất phiên/đóng menu/pipe cha đóng sẽ thử khôi phục tối đa ba lần trước khi helper thoát; không thể bảo đảm khôi phục nếu bị kill ngay, game đã thay đối tượng hoặc quyền ghi bị thu hồi.
- Mỗi lần mở/dừng menu, ba công tắc game trở về tắt. Không tự bật chức năng từ cấu hình của lần chạy trước. No Root không gọi su hoặc backend ghi.

**Aim, ESP, AimKill, Silent, Ghost, FakeLag, Fly và Spin chưa có backend Android và vẫn khóa.** Không bật nút giả. Ba chức năng PlayerAttributes đã có backend thật nhưng cần người dùng thử trên cloudphone để kiểm chứng kết quả trong trận.

Profile trong profiles/free-fire-1.132.1-arm64.json ghi hash binary, lệnh ARM64 và trường dữ liệu. Metadata version 31 sử dụng method stride 40. Mỗi lần ghi kiểm tra lại PID/starttime, match/player, class PlayerAttributes và owner. Không sửa mã thực thi, không tiêm lệnh vào game, không tắt SELinux. IFix/hot patch và logic server có thể làm thay đổi tác dụng dù trường ghi đã được đọc lại. XAPK/APK game/thư viện gốc chỉ giữ tại máy, không đưa lên GitHub.

## Cài và chạy

1. Tải Root hoặc No Root từ Artifacts workflow **Android Viet APK**.
2. Cài APK, nhập key hợp lệ từ hệ thống Firebase hiện có.
3. Bấm Start, cho phép Hiển thị trên ứng dụng khác; quay lại bấm Start.
4. Bản Root: chọn Cho phép trong Magisk/SuperSU. Bản No Root bỏ qua bước này.
5. Chạm m để mở menu; dùng Dừng menu trong Thiết lập hoặc thông báo để tắt.

## Build

JDK 17 + Android SDK 35. Gradle 8.11.1 wrapper có checksum; AGP 8.9.2; min SDK 26 (Android 8), target SDK 35 (Android 15). Không cần Theos/Xcode hoặc root để build.

    ./gradlew :app:assembleRootDebug :app:assembleNoRootDebug
    ./gradlew :app:testRootDebugUnitTest :app:testNoRootDebugUnitTest :app:lintRootDebug :app:lintNoRootDebug

Windows dùng gradlew.bat. local.properties có thể khai báo sdk.dir; file bị gitignore. android.overridePathCheck cho phép thư mục tiếng Việt.

Outputs:
- app/build/outputs/apk/root/debug/app-root-debug.apk
- app/build/outputs/apk/noRoot/debug/app-noRoot-debug.apk

Workflow .github/workflows/android-viet.yml build hai APK, unit test và lint; smoke test giao diện trên emulator Android 15. Smoke test render menu, kiểm tra service overlay tự dừng khi lease hết, helper tuân thủ Root/No Root và từ chối chạy khi chưa có uid 0. Lease của test chỉ gán bằng reflection trong tiến trình instrumentation; APK không có đường bypass key, test không ghi Firebase hoặc giả dữ liệu game. Đường đọc tên đã được người dùng xác nhận trên cloudphone; ba chức năng ghi chưa được xác nhận trong trận.

## Cấu hình key

app/src/main/res/raw/license_config.json dùng cùng database public-client của iOS. Không có service-account/admin secret trong APK. Firebase Rules v4 quyết định quyền đọc từng hash và binding. Không sửa dữ liệu live trong quá trình build/test. Cần key do chủ hệ thống cấp để kiểm chứng kết nối thực tế.
