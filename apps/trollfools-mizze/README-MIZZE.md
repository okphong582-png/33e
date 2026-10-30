# Mizze Toggle — TrollFools fork

Trang mở đầu chỉ dành cho `com.dts.freefireth`, có một nút Bật/Tắt. Bật tiêm tài nguyên `Mizze.dylib` đi kèm; Tắt gọi `ejectAll(shouldDesist: true)` của TrollFools để gỡ các dylib/plugin mà cơ chế gỡ của TrollFools nhận diện, kể cả plugin lưu. Không xóa cả thư mục Frameworks hoặc các framework gốc của game.

Trạng thái được kiểm tra từ file và đường nạp thực tế khi mở/quay lại app. Thao tác chạy trên hàng đợi nối tiếp, khóa nút trong lúc xử lý, và kiểm tra lại trước khi báo thành công. Không có cờ “đã bật” giả trong UserDefaults và không tự tiêm khi vừa mở app. Bật dùng weak reference; không lưu plugin để tự tái tiêm. Nếu IPA đã sửa sẵn mà không có bản backup Mach-O của TrollFools thì thao tác gỡ có thể bị từ chối; app hiển thị lỗi, không báo đã gỡ xong.

Payload chính là `Menu Mizze.dylib` được dùng trong IPA trước, SHA256 `8aae828d9c254747b30f924d4d484a18065907c5000941f6725a5f1bc64a8380`. Đây không phải Assembly-CSharp-patch.bytes R14.54. Đổi payload phải cập nhật hash trong backend và kiểm tra bundle lại.

Build trên macOS với Xcode và `ldid`:

```sh
brew install ldid
bash devkit/build-mizze.sh
```

Đầu ra `build/Mizze-Toggle.tipa` dành cho môi trường TrollStore tương thích, không phải IPA ký phân phối App Store. Việc đổi giao diện không cấp thêm quyền iOS hoặc mở rộng các phiên bản iOS TrollFools hỗ trợ. Chưa thử tiêm/gỡ trên iPhone thật; kiểm thử coordinator dùng backend giả, build CI kiểm tra nguồn và tài nguyên đi kèm.

Nguồn gốc: TrollFools-main.zip người dùng cung cấp. Bộ helper thiếu trong ZIP được lấy nguyên bản từ release công khai chính thức Lessica/TrollFools v4.4-257; xem UPSTREAM-TOOLS.json. Giữ nguyên bản quyền và LICENSE của dự án gốc. Không thêm cơ chế che giấu dylib hay qua mặt quét.
