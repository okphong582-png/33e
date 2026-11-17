# Free Fire dylib source no key

## Free Fire VN 1.134.1

Build riêng bằng `make package GAME_VARIANT=vn FINALPACKAGE=1 FOR_RELEASE=1`.
Profile VN xác nhận bundle `com.garena.ffvn` và UUID của UnityFramework build
2019121262 trước khi đọc dữ liệu. Các field ESP/AIM đối chiếu theo metadata.
Silent xác nhận RVA, hai slot vtable và fingerprint ARM64 trước khi gắn hook.
Các chế độ native chưa đối chiếu đủ (AutoFire, Ghost, các chế độ lag, Fly, Spin,
Speed, NoReload, FastFire) bị tắt cho VN. Cần kiểm tra hành vi trên iPhone.

Gói VN dùng install name `@rpath/Mizze.framework/Mizze`. Đặt binary trong
`Frameworks/Mizze.framework` và thêm liên kết từ UnityFramework theo cấu trúc
IPA INTE​​X. Ký lại IPA hoàn chỉnh trước khi cài.

## Bản cập nhật mới nhất — kính gọn / Silent TH — 07/11/2026

Source hiện có menu kính, hai tab ESP/AIM, aim Đầu/Cổ/Silent và thanh FOV.
ESP 2D trắng; line chỉ khi địch trước camera và trong màn hình. Tên/khoảng cách
trắng; số địch đỏ với bóng đen, không ô nền. Các chức năng ngoài menu rút gọn
được tắt khi đọc settings cũ. Loader chờ đúng UnityFramework; Silent dùng
registry vtable theo lớp và slot, kiểm fingerprint TH và giữ original khi OFF.

Runtime mới và báo cáo ở:
`iOSViet1/exports/Mizze-Loader-Hook-Core-20261107-145502/release-final`.
Build/test C++ đã đạt; chưa kiểm thử trên iPhone. Source app TrollFools hai nút
được xuất cùng bản này nhưng chưa có IPA/TIPA vì thao tác đẩy CI bị hệ thống chặn.
Các mục dưới đây là lịch sử, không mô tả menu rút gọn hiện tại.


## Bootstrap theo phân tích TIPA PHUONGIOS — 07/11/2026

Đối chiếu tĩnh `PHUONGIOS_FF_MAX_Patch_AimTest40_v1.6.3.tipa`, giải mã payload
và xác minh SHA-256 với manifest. Tham khảo cách gom sự kiện khởi động, dùng
generation để loại callback retry cũ, kiểm tra app active và thử gắn UI có giới hạn.
Mizze dùng `InjectedBootstrapPolicy.h` cho phần quản lý này; constructor chỉ
chuyển sang main queue, đăng ký lifecycle một lần và gắn menu sau khi cửa sổ
ổn định. Xuống nền sẽ hủy lượt thử; khi active lại sẽ bắt đầu lượt mới. Giữ
giới hạn 60 lần thử và khoảng ổn định 0,75 giây đang có của Mizze.

Không chuyển chức năng, license/key, offset MAX hoặc các module bảo vệ của mẫu.
Makefile vẫn dùng InjectedDylibInit.mm và profile TH/MAX chọn như trước.
Runtime mới xuất riêng trong `iOSViet1/exports/Mizze-Startup-Logic-20261107-144123`;
các binary và báo cáo build lịch sử trong `packages` giữ nguyên.
Chi tiết bằng chứng, kiểm thử và giới hạn nằm trong báo cáo tại thư mục xuất.

Source được xuất từ 33e-git. Đây là menu Free Fire, không phải Honor.

- Bỏ màn nhập key, phiên xác thực, thông báo khóa và endpoint Firebase.
- Không kèm web quản lý key, Database Secret, token hoặc tài khoản.
- Menu khởi tạo trực tiếp sau khi host sẵn sàng, giữ cơ chế chờ startup và quản lý overlay gốc.
- Bỏ dịch vụ offset từ xa; GameFacade.static_fields dùng 0xB8 theo Il2CppClass_1 trong dump 1.132.1. Không có yêu cầu mạng lấy offset.
- Không kèm TIPA, IPA game, dump, SDK hay dylib build sẵn.

## Build

Cần Theos và iPhoneOS SDK16.5 trên macOS/Linux. Đặt THEOS phù hợp máy.

```sh
make clean package FINALPACKAGE=1 FOR_RELEASE=1
# Free Fire MAX với profile hiện có:
make clean package GAME_VARIANT=max FINALPACKAGE=1 FOR_RELEASE=1
```

Kết quả: packages/Mizze.dylib. Source hỗ trợ profile game có sẵn; cập nhật OB cần xác minh lại offset.
Đã kiểm tra source và gói ZIP; không khẳng định chạy trên OB mới hay mọi thiết bị.

## Build thường, không bypass / anti-detect — 02/11/2026

Makefile hiện dùng `sources/InjectedDylibInit.mm`, khởi tạo UIKit trên main queue,
gắn overlay vào cửa sổ game đã sẵn sàng và hiện logo Mizze ngay tại sảnh.
`StealthDylibInit.mm`, `bypassscandylibgame.mm`, `AntiDetectEngine.mm` và
`fishhook.mm` không nằm trong danh sách biên dịch. Các file cũ vẫn còn trong
thư mục nguồn để đối chiếu; không được liên kết vào binary mới.

Bản build mới nằm trong `iOSViet1/exports/Mizze-NoKey-Plain-20261102-234934`.
Giữ đầy đủ 4 trang menu native hiện có: ESP, AIM, MÀU, CÀI ĐẶT. Logo nhúng
trong dylib; chạm logo để mở menu. Không thêm bước nhập key.
Các file runtime cũ trong `packages` chưa bị thay thế.

Đã kiểm tra ARM64 Mach-O, constructor/menu classes, thư viện hệ thống,
226 page hash của chữ ký ad-hoc và không còn symbol của các module bị loại.
Chưa kiểm thử nạp bằng TrollFools trên iPhone thật; không bảo đảm tương thích
100% với mọi iOS, phiên bản game hay bản TrollFools.
Chi tiết thay đổi và SHA-256 nằm trong source-manifest.json.

## ESP theo ảnh / TrollFools Mizze

Line/FOV xanh trắng nhạt, xương xanh lá đơn giản; đã bỏ mục và phần vẽ Trục XYZ. Tab màu có chọn riêng khung, FOV, line và xương. Nút preset trong ESP khôi phục kiểu theo ảnh.

Build dùng `sources/InjectedDylibInit.mm` để khởi tạo overlay thông thường. Gói TIPA đã tích hợp đúng dylib mới; xem `packages/Mizze-reference-esp-build.json`. Chưa thử trên iPhone vật lý.

## Menu proxy Mizze / logo ở sảnh — 02/11/2026

Menu ngang đen xám, điểm nhấn trắng bạc, thanh tab biểu tượng bên trái và ESP hai cột trên màn hình ngang. Giữ các tab/chức năng native hiện có. Logo Mizze được nhúng trong dylib, mở menu được ngay khi cửa sổ game đã sẵn sàng ở sảnh; không phụ thuộc ESPMatchReady. Khi app xuống nền, menu đóng và trở lại nút logo khi app hoạt động. Nút chức năng phụ vẫn theo trạng thái trận.

Chỉ thay đổi source giao diện; không thay thế runtime trong packages. Makefile và các tệp khởi tạo hiện có giữ nguyên. Controller phục hồi nút logo sau khi được gắn vào cửa sổ và khi ứng dụng hoạt động trở lại. Giao diện co lại một cột trên màn hình hẹp, tôn trọng safe area. Không cần thêm ảnh vào bundle của game.
