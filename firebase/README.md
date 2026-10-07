# Key V3: giữ key hiện có, mỗi key gắn một thiết bị

Web `license-key.html` tạo key tại `licensesV3/<SHA-256>`, với `protocol: 3`.
Rules chặn truy cập công khai tới `licenses` và `licensesV2`, nên app cũ không
dùng được các nhánh đó. Bản mới tiếp tục dùng cùng mã key sau khi chuyển dữ liệu.

Mở **Cài đặt**, nhập token quản trị hiện có, sau đó **Rules → Áp dụng Rules**.
Đóng app cũ trong lúc chuyển. Web tải bản sao dữ liệu key và Rules, chuyển key
V1/V2 sang V3, rồi mới áp dụng Rules. Mã key, hash, hạn dùng, ghi chú và binding
được giữ. Key bị khóa chuyển thành khóa vĩnh viễn; key hết hạn vẫn hết hạn.
V2 được ưu tiên nếu trùng hash với V1. Dữ liệu gốc không bị xóa. Chạy lại không
ghi đè key V3 đã có; dữ liệu nguồn lỗi sẽ dừng trước bước áp dụng Rules.
Cập nhật đè app cùng bundle ID để giữ key đã lưu; bản mới vẫn cần xác thực online.
Secret được lưu trong localStorage khi bấm Lưu, không nằm trong HTML/app/dylib;
để trống rồi lưu để xóa. Sửa Rules trên máy không tự cập nhật Firebase đang chạy.
Không deploy Rules bằng CLI hoặc dán thủ công trước khi chuyển key.

Khi đăng nhập lần đầu, app gửi yêu cầu có điều kiện `if-match: null_etag` để tạo
`binding`. Firebase chỉ nhận một máy thắng nếu có nhiều máy kích hoạt cùng lúc.
App đọc lại bản ghi và đối chiếu mã máy trước khi cấp phiên. Rules chặn khách
ghi đè, xóa khóa máy, tự tạo key, bật key hoặc gia hạn key.

Web hiển thị **Đã gắn 1 máy** và mã máy rút gọn. **Gỡ máy** dành cho quản trị
viên; đóng app cũ trước khi gỡ rồi đăng nhập trên máy mới. Phiên đang chạy kiểm
tra lại mỗi 8 giây và không tự chiếm lại khóa đã gỡ.

Khi khóa key, nhập lời nhắn và thời gian theo phút/giờ/ngày hoặc vĩnh viễn.
Client giữ key và binding trong lúc khóa, ẩn menu và hiển thị lời nhắn. Hết thời
gian khóa sẽ kiểm tra online lại; admin bấm mở sẽ xóa `lock` ngay, giữ nguyên
hạn dùng và binding. Client theo dõi thay đổi qua SSE rồi đọc HTTPS lại trước khi
khôi phục quyền; mất mạng không được coi là mở khóa. Có kiểm tra mỗi 8 giây làm
dự phòng khi SSE ngắt. Xem [Firebase streaming](https://firebase.google.com/docs/database/rest/retrieve-data#section-rest-streaming).

Mã máy là SHA-256 của `identifierForVendor`, lưu thêm trong Keychain với
`AfterFirstUnlockThisDeviceOnly`, không đồng bộ iCloud. Không dùng tên máy,
địa chỉ IP hoặc một mã ngẫu nhiên chung. IDFV phụ thuộc vendor/cách ký app;
gỡ toàn bộ app của vendor hoặc đổi cách ký có thể cần quản trị viên gỡ máy.
Đây là khóa cho client bình thường, không phải chứng thực phần cứng chống một
client đã bị sửa mã. Xem [Apple IDFV](https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor)
và [Firebase conditional writes](https://firebase.google.com/docs/database/rest/save-data#section-conditional-requests).

Kiểm tra: `tests/license_restore_test.mm` chạy lớp xác thực thật với các phản hồi
mạng giả lập; `tests/license_database_rules_test.cjs` chạy Rules thật trong
Firebase Database Emulator, gồm hai máy tranh kích hoạt, ghi đè/xóa trái phép,
key hết hạn/bị khóa và cách ly nhánh cũ.
