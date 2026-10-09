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
- Root thực sự kiểm tra uid 0 và đọc /proc/PID/maps của com.dts.freefireth để chẩn đoán libil2cpp.so. Không tắt SELinux. Đây chỉ là bản đồ thư viện, chưa phải dữ liệu người chơi.

**Aim, ESP, AimKill, Silent, FastFire, NoReload, Ghost, FakeLag, Fly, Speed và Spin chưa hoạt động trong cả hai APK.** Các mục có trong menu nhưng bị vô hiệu hóa, không báo bật thành công. Workspace chưa có APK/libil2cpp.so/global-metadata.dat hoặc profile Android đã xác minh, chưa có số phiên bản game Android. Quyền root riêng lẻ không cung cấp layout dữ liệu. Không dùng offset iOS/Mach/UnityFramework trên Android. No Root không thể đọc bộ nhớ game khác bằng API thông thường.

Muốn triển khai phần game cần đúng binary Android và profile đã kiểm chứng, cùng backend native chạy với quyền phù hợp. AndroidGameData.java hiện trả capability không hỗ trợ. Không có snapshot game giả hay toggle giả.

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

Workflow .github/workflows/android-viet.yml build hai APK, unit test và lint; smoke test giao diện trên emulator Android 15. Smoke test render menu và kiểm tra service overlay tự dừng khi lease hết. Lease của test chỉ gán bằng reflection trong tiến trình instrumentation; APK không có đường bypass key, test không ghi Firebase hoặc giả dữ liệu game. Chưa kiểm chứng trên điện thoại có Magisk/game thực tế.

## Cấu hình key

app/src/main/res/raw/license_config.json dùng cùng database public-client của iOS. Không có service-account/admin secret trong APK. Firebase Rules v4 quyết định quyền đọc từng hash và binding. Không sửa dữ liệu live trong quá trình build/test. Cần key do chủ hệ thống cấp để kiểm chứng kết nối thực tế.
