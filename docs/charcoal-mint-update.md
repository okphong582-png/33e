# ESP và giao diện than đậm + mint

Menu chuyển sang panel matte, bốn tab ngang Focus / ESP / Màu sắc / Thiết lập,
header nhỏ để kéo, các hàng điều khiển gọn và một nút áp dụng preset tối giản.
App TIPA có màn hình mới với hero, ba ô thông tin, trạng thái phiên và nút mở/dừng
bảng điều khiển. Nút nổi là chữ `m` mint trên nền than. Luồng xác thực key giữ nguyên.

Preset bật khung góc 2D, tên, máu và khoảng cách; tắt 3D, xương, đường nối và chấm
đỏ trên đầu. Các tính năng đó vẫn có thể bật riêng. Khung góc mảnh 0,75 pt, đường
nối 0,5 pt với opacity thấp, FOV 0,65 pt. Màu máu và chữ dịu hơn. Đường nối chỉ
vẽ tới đầu trong màn hình; không còn đường đảo ra mép khi địch ở sau camera.
Khung 2D dùng hai phép chiếu thay cho tám góc 3D. Khoảng cách 151–500 m không còn
bị bỏ qua hoặc ghi nhầm 150 m.

CADisplayLink điều khiển nhịp vẽ 60 FPS mặc định hoặc 30 FPS tiết kiệm pin.
Bỏ timer ngẫu nhiên thứ hai vốn làm hụt display tick. Đây là mức yêu cầu, không
cam kết FPS thực trên mọi máy. Tùy chọn cũ được giữ; nút preset áp dụng bố cục
ESP tối giản và màu mint cho người đã có cấu hình cũ.

Silent Aim chọn trong vòng riêng, mặc định 18% cạnh ngắn và tầm 100 m. Hướng tâm
ngắm chiếm 75% điểm, khoảng cách 25%; giữ mục tiêu chỉ có hysteresis nhỏ.
Địch ngoài hướng, sau camera, quá tầm, không nhìn thấy, cùng đội hoặc knock
không đủ điều kiện. Tầm Silent độc lập tầm ESP.

## Tự bắn thử nghiệm

Mặc định tắt. Bật công tắc sẽ bật Silent Aim. Chỉ xuất lệnh khi adapter Silent đã
chấp nhận mục tiêu và cùng mục tiêu tồn tại ít nhất 180 ms. Công tắc dùng cặp
input của vũ khí `HBIBDMMOOOK.ALJMFCJMDCF()` (virtual 182, `0x5C179E8`) và
`NFFJEBKJCAK()` (virtual 213, `0x5C222EC`). Mã native đã đối chiếu gọi
`Player.StartFiring` / `Player.StopFire` và chuyển trạng thái súng của game.
Không ghi PRI để giả trạng thái bắn, không thêm damage hoặc bỏ va chạm.

Callback chạy trong OnUpdate của player, giữ hai tham số float và MethodInfo,
rồi gọi update gốc đúng một lần. Cả TIPA và dylib dùng trang RX đã ký ánh xạ
kế trang trạng thái RW. Chỉ nhận hai update đã fingerprint: Player (`0x5660700`)
và PlayerNetwork (`0x5A4BEC0`). Hai slot input của súng phải trỏ đúng cặp đã
đối chiếu. Súng ghi đè input, hotfix hoặc hook khác sẽ báo chưa hỗ trợ.

Snapshot hết hạn sau 100 ms; mất target, tắt tính năng, knock hoặc sai match
sẽ nhả lần giữ do adapter tạo trên tick kế tiếp. Sau đổi súng, callback không
dereference súng cũ. Bắn tay có sẵn trước khi adapter giữ sẽ không bị nhận là
lần giữ của adapter. Callback được giữ đến khi game thoát để vẫn nhả được sau
khi HUD dừng; khởi động lại HUD chỉ nhận lại code và trạng thái cùng phiên bản.

Chẩn đoán đếm **lệnh bắt đầu input**, không phải số viên đạn hoặc hit. Test
Unicorn kiểm tra start/stop, timeout, mất mục tiêu, ownership, mã input đổi,
khóa reentrancy, ABI float và update gốc. Build và mô phỏng không xác nhận
hiệu quả bắn trong trận trên iPhone. Đường exception native trong callback
input chưa được kiểm thử trên game.

Kiểm tra trên thiết bị: bật Chẩn đoán aim, Silent và Tự bắn; đưa địch vào vòng,
đợi 180 ms; thử quay hướng, mất visibility, nhả công tắc, đổi súng và đổi trận.
Quan sát riêng đạn thực, rate/reload gốc và counter. Thử từng bản TIPA/dylib riêng.
