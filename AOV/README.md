# AOV Menu

Hai sản phẩm độc lập, có **ESP địch** và **ESP quái** (toàn bộ quái sống trong danh sách MonsterActors):

- `AOV-Menu.dylib`: menu trong game Liên Quân VN.
- `AOV-Menu.tipa`: app riêng; mở app → Bật menu nổi → mở Liên Quân → bấm nút A → tự bật các ô ESP.

Menu than đậm/mint, ô chọn X, nút A kéo được. ESP hiển thị chữ **Địch** / **Quái**, không ghi số phần trăm; thanh máu vẫn đổi màu theo lượng máu. Dây từ giữa phía trên màn hình tới địch/quái, kèm ba trục XYZ xoay theo camera giống bản FF. Dây đi cùng ô ESP tương ứng. Không có log che màn hình chơi.

### Bản 1.3: cảm ứng game và menu

- Cửa sổ TIPA luôn xuyên cảm ứng (`_ignoresHitTest=YES`, `_usesWindowServerHitTesting=NO`, `userInteractionEnabled=NO`). ESP không giữ chạm của game; menu nhận chạm qua callback HID riêng.
- Ưu tiên tọa độ và trạng thái từng ngón từ IOHID thay vì vị trí tổng hợp của cả bàn tay. Giữ joystick và bấm menu bằng ngón khác không còn hủy thao tác menu. Khi thiếu API IOHID, dùng AX cho chạm một ngón.
- Dylib chỉ nhận chạm trong đúng nút A, nút đóng và các ô chọn; nền menu và vùng ESP không nhận chạm. Animation mở menu chỉ đổi độ mờ để vùng bấm không di chuyển.
- Kiểm tra hồi quy gồm hai ngón xen kẽ, nhả ngón joystick trước ngón menu, gói nhả trùng và hủy ngón. Cần kiểm tra thao tác trực tiếp trên thiết bị.

### Bản 1.2: cửa sổ TIPA và menu

- Bổ sung quyền `com.apple.springboard.accessibility-window-hosting` và truy cập dịch vụ AXSpringBoardServer cho HUD.
- Chờ tối đa 2 giây để UIKit cấp context cửa sổ, có bước tạo HUD dự phòng nếu plugin không gọi delegate khởi chạy.
- App hiển thị tiến trình khởi chạy và báo nếu HUD thoát; mỗi phiên có mã riêng để không lấy nhầm thông báo từ lần bật cũ. “Đã đăng ký menu” chỉ xác nhận lời gọi đăng ký cửa sổ đã chạy, cần kiểm tra hiển thị trực tiếp trên máy.
- Ô X thật, hàng cao 64 pt, nút A 52 pt, nền than/mint có chiều sâu và animation ngắn; tôn trọng Reduce Motion.
- Nhấn, kéo và hủy chạm được xử lý riêng. TIPA dùng một đường kích hoạt nút để tránh nhấn hai lần. Sau mất gói nhả tay, lần nhấn mới có thể khôi phục sau 3 giây.

Trên thiết bị, kiểm tra: Bật menu nổi → thấy nút A → mở/đóng menu → kéo A → bật/tắt từng ô → giữ joystick và bấm menu → xoay máy → tắt và bật lại HUD. Chưa có kết quả kiểm tra bản 1.3 trực tiếp trên iPhone.

## Build

```sh
cd AOV
make clean package BUILD_KIND=dylib FINALPACKAGE=1 FOR_RELEASE=1
make clean package BUILD_KIND=tipa FINALPACKAGE=1 FOR_RELEASE=1
```

GitHub Actions **Build AOV dylib and TIPA** xuất hai artifact `AOV-dylib` và `AOV-tipa`. Dự án AOV không liên kết mã chức năng của Free Fire. IPA và dump gốc chỉ dùng để đối chiếu tại máy, không tải lên Git.

## Phạm vi tương thích

Profile hiện tại dành cho IPA **com.garena.game.kgvn 1.64.1.7** trong thư mục đầu vào (CFBundleShortVersionString thực tế **1.64.11768577**), UnityFramework ARM64 UUID `E73CE98D-A67A-3FD6-AD83-A16D13984811`. Dữ liệu dump Android giúp nhận diện tên/kiểu, địa chỉ đọc được đối chiếu riêng trên binary iOS. Bản khác UUID sẽ dừng đọc và báo trong menu, cần cập nhật profile.

TIPA cần môi trường cấp quyền task port và cửa sổ HUD (TrollStore/jailbreak thích hợp). Cài được app không đồng nghĩa iOS đã cấp quyền đọc game; nếu thiếu quyền, menu báo rõ. ESP chỉ hiển thị dữ liệu còn có trong bộ nhớ client; không thể tạo vị trí khi server không gửi dữ liệu. Chưa xác nhận trực tiếp trên thiết bị AOV.

Bộ đọc chỉ dùng `vm_read_overwrite` với địa chỉ ARM64 64-bit, không ghi bộ nhớ hoặc gọi hàm game. Danh sách được giới hạn 64 tướng/256 quái, kiểm tra sequence của pool handle và version của list. Đọc trên hàng đợi riêng tối đa 30 Hz; không quét bộ nhớ toàn game mỗi khung hình.

## Dữ liệu đối chiếu

Xem [profile-evidence.md](profile-evidence.md). Khi cập nhật AOV, đối chiếu UnityFramework/metadata mới, không thay UUID để ép offset cũ hoạt động.
