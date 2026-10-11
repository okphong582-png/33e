# Mizze R9 — nền source cũ, bốn hook

Build từ bản sao thư mục source cũ trong menu/mizze-oldbase. CompilerHost.cs giữ nguyên bốn hook: UIModelRole, IsReallyInStealth, LastAimingInfoFromWeapon, OnGUI. Callback vẽ và kéo nút/menu lấy từ Mizze.cs cũ, sau đó ghép glass/GIF, bảng màu, key, các mục ESP/aim và vũ khí. legacy-baseline lưu source nguyên trạng và hash. Không sửa thư mục source cũ của người dùng.

Gói Documents gồm Assembly-CSharp-patch.bytes và localConfig.json. **Tắt hẳn game trước khi thay cả hai**, rồi mở lại. Không nạp nóng, không dán bytes của hai biến thể cùng lúc. Target TH iOS1.132.1. Chưa kiểm chứng trên iPhone.

Có ESP khung/góc/3D/tên/máu/khoảng cách/xương/đầu/trục/line, aim đầu khi bắn, silent khi bắn, FOV/tầm, bảng màu, key backend33e, glass/GIF và bắn nhanh/không nạp đạn ở phía client. Server chấp nhận chưa được kiểm chứng. Bản nền cũ này **không có Fakelag và NGUI touch shield**: chúng cần hook/phụ thuộc mới. Không đặt toggle FL giả. Bản đầy đủ trong menu/mizze vẫn giữ FL thử nghiệm và touch shield, dùng cùng callback vẽ từ nền cũ.

Bootstrap giữ state trước AddComponent, chuỗi Find/create/GetComponent/AddComponent/DontDestroy/assign nguyên bản, không chốt clock/thread trước tạo driver. OnGUI không gọi lại bootstrap. Tên trường Mz giữ cách serializer cũ. Real-stealth dùng predicate native đã đối chiếu thay cho shortcut IsInStealth cũ.

Renderer dùng192 command, cache64 nhãn, không Mesh/Shader/Font toàn cục. Lấy mẫu ESP33/66ms, không đọc xương mỗi Repaint; hết context bỏ cache. VòngFOV dùng texture tái sử dụng. Bộ nhớ đo mỗi giây từ hai hook cũ, chỉ sau GUI đầu tiên; thu gom bằng COW.GcUtil.Collect ngoài GUI. Từ256MiB và tăng48MiB thì collect; cooldown4s hoặc30s nếu thu hồi dưới16MiB. Nếu sauGC vẫn768MiB và thu hồi ít, bỏ texture nền/vòng và tạm dừng việc nặng, giữ menu; dưới512MiB tiếp tục. Log30s không phải lịch cập nhật ESP.

IMGUI nhận/Use thao tác bắt đầu bên trong menu; ngoài menu vẫn nhận chạm. Vì bản này không tạo collider NGUI, chưa xác nhận chặn chạm game hoàn toàn trên iPhone.

Offline test chạy bytecode trên Tencent VM và game/Unity doubles; đối chiếu khai báo dumpTH. Đây không phải test thiết bị, không đảm bảo hết crash native/jetsam.

Kết quả:1.882 kiểm tra offline,210 khai báo dumpTH,4slotnative. memory-allocation-evidence.json ghi phép đo300Repaint trên VM, không phải số liệu iPhone.
