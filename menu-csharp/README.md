# Menu C# độc lập trong một file .bytes

Yêu cầu: chỉ một `Assembly-CSharp-patch.bytes` đặt trong Documents game.
Menu, trạng thái cài đặt, đọc dữ liệu và xử lý chức năng phải nằm trong bytecode
IFix của file này. Dùng runtime Unity/IFix đã có trong game; không cần backend
dylib/TIPA, cầu nối native, P/Invoke, file cấu hình giao tiếp hay tiến trình khác.

Phương án cầu nối ở commit trước đã được bỏ. Thư mục hiện chứa bộ đọc, giải mã,
ghi lại định dạng IFix và bằng chứng phân tích. **Chưa có payload mới đã chuyển
đủ logic của menu chính vào IFix**, và chưa có kiểm thử trên thiết bị.

## Công cụ

- `inspect_patch.cjs`: đọc toàn bộ cấu trúc bytecode, không thực thi.
- `decode_patch.cjs`: xuất instruction của 7 hàm trong mẫu, dùng đúng metadata
  đã kiểm tra của game 1.132.1.
- `write_patch.cjs`: tạo file `.bytes` từ cấu trúc JSON; giữ magic, wrapper,
  bảng type/method/field, byte cờ và bảng fix của định dạng đã đọc.
- `PATCH_ANALYSIS.md`: cách tạo `__esp_driver`, gọi OnGUI và giới hạn bằng chứng.

```text
node menu-csharp/inspect_patch.cjs Assembly-CSharp-patch.bytes structure.json
node menu-csharp/write_patch.cjs structure.json output.bytes
node menu-csharp/decode_patch.cjs Assembly-CSharp-patch.bytes global-metadata.dat disassembly
```

Đọc rồi ghi lại mẫu đã kiểm tra cho kết quả giống đầu vào từng byte. Đây là kiểm
tra khả năng đóng gói, không phải đã chuyển logic gameplay sang bản mới. Đổi tên
hoặc chép nguyên mẫu không được tính là hoàn thành menu dùng logic của dự án.

## Phần cần chuyển

Phần đọc game của dự án phải chuyển thành lời gọi getter/field tương ứng trong
game và instruction IFix: trận, nhân vật, đội/máu, vị trí, chiếu lên màn hình,
lọc mục tiêu và trạng thái cài đặt. Cần chuyển tiếp từng chức năng muốn giữ;
không thể nhét mã C++/ARM64 của dylib vào `.bytes` rồi gọi nó trực tiếp.
Giữ host/bootstrap hiện có trong game và kiểm tra bộ nạp Documents trên thiết bị.
Ba target build hiện tại vẫn độc lập với công việc này.
