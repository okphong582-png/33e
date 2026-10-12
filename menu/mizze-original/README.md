# Mizze — bản source cũ, nền GIF kính

Bản này phát triển trực tiếp từ 24 file source cũ ở commit 6b9053afadef350ae9a27e4b5a5d5b55f39f200f.
Không dùng kiến trúc R2–R9 hoặc thay đổi thư mục menu/mizze, menu/mizze-oldbase.

- Giữ nguyên bốn hook và cơ chế tạo __mizze_driver cũ.
- Nền GIF thật: video-ezgif.com-video-to-gif-converter.gif, 15 khung 192×222, chu kỳ 2,5 giây.
- Nạp tối đa một khung mỗi 40 ms khi mở menu, tái sử dụng texture, giải phóng chuỗi mã hóa sau khi nạp. Dừng đồng hồ nền khi đóng. Lỗi ảnh vẫn giữ menu.
- Giao diện kính tối, viền sáng, tab viên thuốc trượt, công tắc có chuyển động; tiếng Việt có dấu.
- Tab Tốc độ: chạy ×1,25/×1,5/×2; bắn ×1,5/×2/×3. Mặc định tắt.
- Chạy ghi ForceSetRunAndDashSpeed từ tốc độ Run thực tế × hệ số. Native GetSpeedByType đọc trực tiếp trường này cho Run/Dash.
- Bắn ghi FireIntervalScale từ giá trị gốc / hệ số. Không thay đổi số đạn hay bỏ nạp.
- Khôi phục khi tắt, chết, rời trận, đổi thuộc tính người chơi hoặc khóa hết hiệu lực. Không ghi đè thay đổi mới của game khi khôi phục.
- Giữ hệ thống khóa và bốn hook cũ. Tối ưu phần vẽ ESP trên cùng nhánh source cũ.

Dùng Assembly-CSharp-patch.bytes với localConfig.json hiện có của bản cũ.
Chưa xác minh trên iPhone thật. Máy chủ có thể giới hạn tốc độ, và kết quả test giả lập không bảo đảm game không văng.

Build từ thư mục repo:
node menu/mizze-original/build.cjs .ifix-runtime
node menu/mizze-original/package.cjs
node menu/mizze-original/test.cjs

mizze-original-baseline-hashes.json giữ dấu vân tay bản cũ nguyên trạng.
mizze-original-hashes.json kiểm tra chính xác phiên bản hiện tại.

## ESP và bộ nhớ

- Một buffer mesh cố định cho nét đặc; bỏ bản sao lệnh Rect/Matrix cho từng đường.
- Khung 3D chiếu 8 góc duy nhất; xương chiếu 9 khớp bổ sung, dùng lại đầu/chân; XYZ dùng lại gốc.
- Cache cố định 501 chữ khoảng cách và tối đa 16 tên/người chơi; xóa tham chiếu khi tắt, đổi cảnh, rời trận hoặc hết khóa.
- Lấy mẫu mỗi 50 ms (20 Hz) khi tối đa 8 người; trên 8 người dùng 66,7 ms (15 Hz), tự lùi 100 ms khi một mẫu tốn hơn 8 ms; vẽ mesh đã cache mỗi Repaint.
- Khi tắt cả ESP và FOV, bỏ công việc camera/material.
- Gộp đổi màu native của menu; giữ màu shader tường minh và khôi phục GUI của game.
- Đo managed heap tối đa 1 lần/giây từ callback cũ, trên thread GUI và ngoài OnGUI.
- Thu gom qua COW.GcUtil.Collect(MemoryUtilCollect), giữ chính sách GC gốc của game. Chỉ chạy khi có áp lực, nghỉ ít nhất 8 giây; lỗi/thu hồi ít nghỉ 30 giây.
- Nếu sau thu gom RAM vẫn trên 1 GiB, hoặc hai lần trên 768 MiB, tạm dừng ESP/aim và giải phóng nền GIF. Nút/menu vẫn hiện; dưới 384 MiB thì phục hồi.
- Đây là managed heap toàn game, không phải tổng RAM tiến trình. Thu gom có thể gây khựng; không sửa được mọi leak native hay đối tượng game vẫn sống.

Có phép đo trước/sau trong memory-allocation-evidence.json; đây là IFix VM trên máy tính với game/Unity giả lập, không phải số đo iPhone.
