# Free Fire trong External-DarkSword

Đã thêm lựa chọn **Free Fire** bên cạnh Liên Quân, dùng process `FreeFire` và bundle `com.dts.freefireth`. Nhánh Free Fire hiện chỉ có **ESP khung địch**, mặc định tắt. Cài đặt ESP của hai game lưu riêng.

Mở app, hoàn tất bước khởi tạo sẵn có, vào Trò chơi → Free Fire. App mở game và kết nối bằng `RemoteCall` hiện có. Bật **ESP — khung địch** trong app hoặc công tắc **ESP Box** ở menu nổi. Menu/nút nổi dùng `RemoteWebViewOverlay` của source này: WebView trong suốt gắn vào cửa sổ game và nhận khung qua WebSocket nội bộ.

ESP chỉ đọc dữ liệu trận, đội, máu và transform; không thêm aim, tốc độ, bắn nhanh hoặc ghi field gameplay. Không dùng `Assembly-CSharp-patch.bytes` hay `localConfig.json`. Hạ tầng RemoteCall/khởi tạo và UI overlay vẫn là cơ chế có sẵn của source, không phải overlay hệ thống độc lập.

## Bản game được đối chiếu

- Free Fire TH iOS **1.132.1**.
- UnityFramework UUID **C8DE7371-CBA7-3E7A-9E09-30B8E1B89073**.
- SHA-256 binary dùng phân tích: **ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8**.
- Bộ đọc kiểm tra UUID Mach-O trước khi dùng offset. MAX và bản OB khác bị từ chối; không tự áp offset cũ.
- `GameFacade` typeinfo RVA `0xBB46A50`, class statics `+0xB8`: đã đối chiếu lệnh ARM64 của `CurrentMatch` tại `0x591B898` trong binary iOS. Các chuỗi đọc trận/camera, Dictionary<byte,Player>, PRI HP và transform kế thừa profile FF của source `33e-git/esp`, không phải profile AOV.
- Team ID: PlayerID tại player `+0x408`, TeamID `+8`. HP: PRI pool `+0x70`, pool entries `+0x10`, slot 0 `+0x20`, value `+0x18`. Bone đầu `+0x6A0`, cổ chân trái `+0x6D8`; transform node `+0x10`.

Đây là bằng chứng tĩnh và profile hiện có, chưa phải kiểm chứng đầy đủ runtime trên iPhone. Không kèm game gốc trong source này.

## Giới hạn và vòng đời

Đọc tối đa **20 Hz**, mảng cố định 256 entry/32 địch. Bỏ người chơi cùng đội, đã chết, trùng ID, tọa độ lỗi hoặc sau camera. Kiểm tra lại trận/người chơi/dictionary version sau khi lấy mẫu; dữ liệu đổi hoặc đọc lỗi thì xóa khung cũ. Chuỗi transform có giới hạn độ sâu và phát hiện vòng lặp.

Khi chuyển game, dừng reader trước khi hủy RemoteCall. State, target, layout và thông điệp từ WebView có mã game để tránh menu Liên Quân tác động vào Free Fire. Các file **Core/** và **Features/Games/AoV/** giữ nguyên.

## Kiểm tra và build

~~~sh
node tests/run-freefire.cjs
node tests/freefire_menu_test.cjs
~~~

Test C++ dùng compiler qua biến `CXX`; Windows mặc định compiler Windhawk đang có trên máy này, Linux/macOS mặc định `c++`. Tests dùng bộ nhớ giả để kiểm tra logic đọc, không đọc game đang chạy.

Build app trên môi trường Theos/iOS SDK đúng cấu hình có sẵn:

~~~sh
make clean package
~~~

`Makefile` và bridging header đã thêm `FreeFireManager.mm`/`.h`. Target dùng SDK Xcode hiện có và iOS tối thiểu 17.0, phù hợp các nhánh iOS mà kiểm tra hỗ trợ sẵn có cho phép. Máy Windows không có môi trường link iOS; workflow **Build External DarkSword FF ESP** chạy build trên macOS, kiểm tra package rồi xuất IPA/TIPA. Xem kết quả của run để biết đã build thành công hay chưa.

Chưa xác nhận menu/ESP hiển thị trên iPhone. Khi thử thiết bị cần kiểm tra: chọn game → nút nổi → bật/tắt ESP → vào/thoát trận → đổi Liên Quân/Free Fire → ngắt kết nối.
