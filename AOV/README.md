# AOV Menu

Hai sản phẩm độc lập, chỉ có **ESP địch** và **ESP bùa xanh**:

- `AOV-Menu.dylib`: menu trong game Liên Quân VN.
- `AOV-Menu.tipa`: app riêng; mở app → Bật menu nổi → mở Liên Quân → bấm nút A → tự bật các ô ESP.

Menu than đậm/mint, ô chọn X, nút A kéo được. Thanh máu đổi màu theo phần trăm. Không có log che màn hình chơi.

## Build

```sh
cd AOV
make clean package BUILD_KIND=dylib FINALPACKAGE=1 FOR_RELEASE=1
make clean package BUILD_KIND=tipa FINALPACKAGE=1 FOR_RELEASE=1
```

GitHub Actions **Build AOV dylib and TIPA** xuất hai artifact `AOV-dylib` và `AOV-tipa`. Dự án AOV không liên kết mã chức năng của Free Fire. IPA và dump gốc chỉ dùng để đối chiếu tại máy, không tải lên Git.

## Phạm vi tương thích

Profile hiện tại dành cho IPA **com.garena.game.kgvn 1.64.1.7**, UnityFramework ARM64 UUID `E73CE98D-A67A-3FD6-AD83-A16D13984811`. Dữ liệu dump Android giúp nhận diện tên/kiểu, địa chỉ đọc được đối chiếu riêng trên binary iOS. Bản khác UUID sẽ dừng đọc và báo trong menu, cần cập nhật profile.

TIPA cần môi trường cấp quyền task port và cửa sổ HUD (TrollStore/jailbreak thích hợp). Cài được app không đồng nghĩa iOS đã cấp quyền đọc game; nếu thiếu quyền, menu báo rõ. ESP chỉ hiển thị dữ liệu còn có trong bộ nhớ client; không thể tạo vị trí khi server không gửi dữ liệu. Chưa xác nhận trực tiếp trên thiết bị AOV.

Bộ đọc chỉ dùng `mach_vm_read_overwrite`, không ghi bộ nhớ hoặc gọi hàm game. Danh sách được giới hạn 64 tướng/256 quái, kiểm tra sequence của pool handle và version của list. Đọc trên hàng đợi riêng tối đa 30 Hz; không quét bộ nhớ toàn game mỗi khung hình.

## Dữ liệu đối chiếu

Xem [profile-evidence.md](profile-evidence.md). Khi cập nhật AOV, đối chiếu UnityFramework/metadata mới, không thay UUID để ép offset cũ hoạt động.
