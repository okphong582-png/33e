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
- Root kiểm tra uid 0 qua su. Khi menu mở, chạy helper app_process đọc /proc/PID/maps và /proc/PID/mem của com.dts.freefireth; kiểm tra ARM64, chữ ký lệnh, số lượng metadata và class trước khi thử đọc chuỗi tên local player mỗi giây. Không tắt SELinux và không ghi bộ nhớ game.
- Helper chỉ sống trong phiên key hợp lệ, dừng khi đóng menu/mất key/pipe cha đóng. Lease helper bị chặn tối đa 30 giây, kể cả tiến trình ứng dụng chết.
- Tab Thiết lập hiển thị trạng thái thật: chờ game, sai profile, chờ trận, bị từ chối đọc hoặc chuỗi tên đọc được. Đây là đường đọc thử nghiệm chưa được xác nhận trên điện thoại có game, không phải ESP/Aim hoàn chỉnh.

**Aim, ESP, AimKill, Silent, FastFire, NoReload, Ghost, FakeLag, Fly, Speed và Spin chưa hoạt động trong cả hai APK.** Các mục có trong menu nhưng bị vô hiệu hóa, không báo bật thành công. Đã phân tích XAPK Free Fire 1.132.1 do người dùng cung cấp; profile ARM64 mới chỉ được kiểm chứng tĩnh. Quyền root vẫn có thể bị SELinux chặn đọc. Không dùng offset iOS/Mach/UnityFramework trên Android. No Root không thể đọc bộ nhớ game khác bằng API thông thường.

Profile trong profiles/free-fire-1.132.1-arm64.json ghi hash binary gốc và bằng chứng getter ARM64. Metadata mang version 31 nhưng method stride 40 (khác công cụ dump chuẩn); không dùng layout iOS. Đường đọc: GameFacade.static_fields → CurrentGame → MatchGame.m_Match → LocalPlayer → NickName. Helper kiểm tra type hierarchy của MatchGame và System.String. Chữ ký runtime là kiểm tra cục bộ, không thay cho xác minh toàn bộ SHA-256. IFix/hot patch có thể đổi hành vi getter.

AndroidGameData.java vẫn trả capability không hỗ trợ Aim/ESP vì chưa có danh sách địch, transform/camera và backend chức năng được kiểm chứng. Không có snapshot game giả hay toggle giả. XAPK, APK game, thư viện gốc và metadata được giữ tại máy, không đưa lên GitHub.

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

Workflow .github/workflows/android-viet.yml build hai APK, unit test và lint; smoke test giao diện trên emulator Android 15. Smoke test render menu, kiểm tra service overlay tự dừng khi lease hết, helper tuân thủ Root/No Root và từ chối chạy khi chưa có uid 0. Lease của test chỉ gán bằng reflection trong tiến trình instrumentation; APK không có đường bypass key, test không ghi Firebase hoặc giả dữ liệu game. Chưa kiểm chứng trên điện thoại có Magisk/game thực tế.

## Cấu hình key

app/src/main/res/raw/license_config.json dùng cùng database public-client của iOS. Không có service-account/admin secret trong APK. Firebase Rules v4 quyết định quyền đọc từng hash và binding. Không sửa dữ liệu live trong quá trình build/test. Cần key do chủ hệ thống cấp để kiểm chứng kết nối thực tế.
