# Key V2: mỗi key gắn một thiết bị

Web `license-key.html` tạo key tại `licensesV2/<SHA-256>`, với `protocol: 2`.
Bản dylib/TIPA cũ chỉ đọc `licenses`, nên không sử dụng được key mới. Các bản
sau cần tiếp tục dùng giao thức V2 để giữ tương thích.

Mở **Cài đặt**, nhập token quản trị hiện có, sau đó **Rules → Áp dụng Rules**.
Web tải bản sao Rules hiện tại trước khi cập nhật và giữ các nhánh dữ liệu khác.
Token chỉ lưu trong phiên trình duyệt, không nằm trong HTML hoặc app/dylib.
Nếu dùng Firebase CLI: `firebase deploy --only database --project appchatai-313e3`.
Sửa file Rules trên máy không tự cập nhật Firebase đang chạy.

Khi đăng nhập lần đầu, app gửi yêu cầu có điều kiện `if-match: null_etag` để tạo
`binding`. Firebase chỉ nhận một máy thắng nếu có nhiều máy kích hoạt cùng lúc.
App đọc lại bản ghi và đối chiếu mã máy trước khi cấp phiên. Rules chặn khách
ghi đè, xóa khóa máy, tự tạo key, bật key hoặc gia hạn key.

Web hiển thị **Đã gắn 1 máy** và mã máy rút gọn. **Gỡ máy** dành cho quản trị
viên; đóng app cũ trước khi gỡ rồi đăng nhập trên máy mới. Phiên cũ kiểm tra lại
mỗi 8 giây và không tự chiếm lại khóa đã gỡ. **Key bản cũ → Chuyển bản mới**
giữ hạn dùng/ghi chú, tạo bản V2 rồi khóa bản cũ. Không ghi đè key V2 đã tồn tại.

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
