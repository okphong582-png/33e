# Bản source cũ — đối chiếu file ESP ngày 16/10/2026

Giữ nguyên mã C# chạy trong game của bản source cũ đã sửa (giao diện, GIF, key,
ESP, aim, khởi tạo driver và OnGUI). Chỉ đổi byte cờ ánh xạ hook trong bộ đóng gói
từ 0 sang 1, giống file Assembly-CSharp-patch.bytes được cung cấp mới.

Trong UnityFramework TH 1.132.1 có SHA-256
ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8:

- OptimizeLoad đọc cờ ngay trước bảng fix tại RVA 0x876849C.
- Cờ 1 gọi delegate GetPositionIndex để tìm slot native (0x876854C–0x876856C).
- Cờ 0 đi qua getMapId và các kiểu IFix.IDMAP (0x8768570–0x8768588).
- GetPositionIndex tại 0x6B5FA2C chuyển tới 0xA122338, trả slot từ metadata của
  method; trả -1 nếu không có slot.

File tham khảo 41.245 byte, SHA-256
d42edd548e3fc03aead603d07aa33231462c9b5aadf1440336628466d5ea22be,
có 31 thân hàm, 23 hook. ESP của nó nằm ở Player.IsReallyInStealth, tạo
LineRenderer gắn vào transform của từng player, cập nhật tối đa một lần mỗi frame.
File đó không có OnGUI/menu/nút nổi và không đọc/ghi localConfig.json. Không chép
các thay đổi cửa hàng/aim assist của file tham khảo vào Mizze.

## Giới hạn về localConfig.json

Đổi cờ ánh xạ hook không bật bộ nạp Documents. Trên game gốc được đối chiếu,
StartLauncher gọi get_TestCodePatch tại 0x50913CC, kiểm tra kết quả tại
0x50913D0 rồi mới gọi LoadTestPatch tại 0x50913E4. LoadTestPatch mới ghép
persistentDataPath với Assembly-CSharp-patch.bytes và đọc file.

Nếu cờ testCodePatch của game chưa bật, chỉ đổi file bytes không đủ để đi qua
bước này. Game cũng có đường nạp patch qua ResourceManager/asset bundle và
ResHotUpdater; chưa có bằng chứng đường đó tự đọc file Documents này khi không
có cấu hình. Không ghi bản này là bản chắc chắn bỏ được localConfig.json.

Thử bản bytes mới trên cùng game đang nạp được file tham khảo. Với game gốc cần
loader test, vẫn giữ localConfig.json hiện có. Chưa thử trên iPhone; kiểm thử VM
offline xác minh bytecode/menu, không chạy GetPositionIndex native của iOS.
