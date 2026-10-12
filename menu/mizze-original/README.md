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
- Không thay đổi hệ thống khóa hoặc ESP/aim cũ.

Dùng Assembly-CSharp-patch.bytes với localConfig.json hiện có của bản cũ.
Chưa xác minh trên iPhone thật. Máy chủ có thể giới hạn tốc độ, và kết quả test giả lập không bảo đảm game không văng.

Build từ thư mục repo:
node menu/mizze-original/build.cjs .ifix-runtime
node menu/mizze-original/package.cjs
node menu/mizze-original/test.cjs

mizze-original-baseline-hashes.json giữ dấu vân tay bản cũ nguyên trạng.
mizze-original-hashes.json kiểm tra chính xác phiên bản hiện tại.
