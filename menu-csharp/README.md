# Menu C# dùng backend Mizze

Thư mục mới phục vụ việc chuyển giao diện sang C#. Hiện có **source và phân tích
bản vá**, chưa có `Assembly-CSharp-patch.bytes` mới có thể dán vào game để chạy.
Ba target dylib/TIPA/Aimlag hiện tại vẫn dùng giao diện hiện tại.

## Các file

- `Menu.cs`: giao diện Unity IMGUI nền than + mint, tab Aim / ESP / Khác,
  ô bật tắt `[X]`, kéo thanh tiêu đề để di chuyển. Giao diện chỉ gọi `IMenuBackend`.
- `NativeBackend.cs`: hợp đồng backend và adapter P/Invoke cho cùng tiến trình.
- `NativeBridge.mm`: adapter **chưa đưa vào target build**, chuyển cài đặt tới
  `ESPPrefs` và `ESPSyncFromPrefs`, giữ các ràng buộc AimKill/Silent và khung 3D.
  Việc đọc máu, địch, vị trí, xử lý aim/ESP vẫn thuộc backend hiện có.
- `inspect_patch.cjs`: đọc cấu trúc bản vá, không nạp/chạy bytecode.
- `decode_patch.cjs`: xuất instruction của 7 hàm; yêu cầu đúng metadata đã đối chiếu.
- `PATCH_ANALYSIS.md`: bằng chứng và giới hạn của kết quả phân tích.

Đọc file: `node menu-csharp/inspect_patch.cjs Assembly-CSharp-patch.bytes report.json`.
Đường dẫn đầu vào cần trỏ tới file người dùng cung cấp.
Giải mã: `node menu-csharp/decode_patch.cjs patch.bytes global-metadata.dat output-directory`.

## Điều kiện để đóng gói thành bản vá Documents

1. Cần source/build IFix tương ứng với `Assembly-CSharp 0.86.0.518`, các wrapper,
   IDMAP và thứ tự opcode của game; không dùng trực tiếp builder IFix mặc định.
2. Host/bootstrap phải nối tới callback đã có trong game. `Menu.cs` là component
   Unity thông thường; copy source này hoặc đổi đuôi DLL sang `.bytes` không tạo
   ra bản vá hợp lệ. Không giả định IFix hỗ trợ mọi class/PInvoke mới trên IL2CPP.
3. Adapter P/Invoke chỉ áp dụng khi backend nằm trong **cùng tiến trình game** và
   runtime cho phép gọi các export. Backend dylib phải link `NativeBridge.mm` rồi
   kiểm tra export/runtime binding. Một mình `.bytes` không mang theo backend.
4. TIPA ở tiến trình khác cần adapter giao tiếp riêng; `__Internal` trong game
   không gọi được export ở app TIPA. Adapter này chưa được triển khai.
5. Cần xác minh bộ nạp game thực sự đọc file ở Documents, thử chuyển cảnh,
   mở/đóng menu và việc đổi cài đặt trên thiết bị. Chưa có kiểm thử thiết bị.

Source C# được tách khỏi gameplay của file mẫu. Không mang phần ESP riêng, sửa
thuộc tính sát thương hoặc luồng token của mẫu vào backend Mizze.
