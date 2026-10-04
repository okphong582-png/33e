# Silent aim thử nghiệm — Free Fire 1.132.1

Cả TIPA và dylib có công tắc **Silent aim (thử nghiệm)**, mặc định tắt. Khi bật,
aim thường không ghi góc camera. Bộ chọn lấy đầu địch còn sống, chưa knock,
khác đội và đang hiện trong viewport, trong khoảng cách hiển thị đã đặt.
Vòng FOV và lựa chọn aim cổ chỉ áp dụng cho aim thường.

Đây là triển khai thử nghiệm có kiểm tra layout, **chưa được xác nhận bằng
phát bắn trên thiết bị**. Không cam kết mọi viên đều trúng đầu. Độ tản,
đường bắn đặc biệt, hotfix và kiểm tra phía server có thể ảnh hưởng kết quả.
Bản TIPA có adapter riêng, mô tả bên dưới. Build thành công không xác nhận
quyền thực thi trong game hay kết quả bắn trên một thiết bị cụ thể.

## Adapter TIPA

TIPA lấy vũ khí bằng đọc bộ nhớ: `Player + 0x740` là `GMOCOOEIFMK`, owner
ở `+0x30`, cờ `+0x148` chọn vũ khí tại `+0xA0` hoặc `+0xA8`. Đường này
được đối chiếu với getter native `0x5AC970C` và kiểm tra fingerprint trước dùng.
TIPA không gọi trực tiếp địa chỉ hàm của game trong process của ứng dụng.

Adapter có callback ARM64 không chứa relocation, chạy tại một vùng nhớ riêng
trong game. Trang code được ghi khi RW, flush cache rồi chuyển RX; trang trạng
thái giữ RW. Nó dùng địa chỉ handler gốc và `mach_absolute_time` của process game;
địa chỉ clock được tìm theo image và kiểm tra byte mã. Snapshot có sequence để
callback bỏ qua ghi dở, hết hạn sau 150 ms. Callback kiểm tra match/local, chủ
vũ khí, handler, class aiming-info, knock và PRI bắn trước khi đổi hướng. HP,
đội, visibility và đầu trong màn hình được kiểm tra lúc TIPA xuất snapshot.
Nếu HUD dừng, snapshot hết hạn và callback trở về handler gốc.

TIPA cần game cho phép chạy code ở vùng nhớ mới. Adapter chỉ đọc
`CS_OPS_STATUS` và yêu cầu `CS_DEBUGGED`, không có `CS_HARD`/`CS_KILL`; nó không
gắn debugger hay thay chính sách ký mã. Các cờ này được định nghĩa trong
[XNU cs_blobs.h](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/cs_blobs.h).
Nếu truy vấn, cấp phát, flush cache, chuyển RX hay tạm dừng để thay slot không
được phép, chẩn đoán báo **iOS không cho cài xử lý phát bắn**. Có quyền đọc/ghi
ESP không đảm bảo có quyền chạy callback. Không tự chuyển sang aim kéo camera.

Tắt Silent bỏ snapshot và hoàn lại slot nếu còn thuộc adapter. Code đã công bố
được giữ đến khi game thoát vì thread có thể đang giữ địa chỉ callback; bật lại
dùng cùng vùng nhớ. HUD khởi động lại có thể nhận lại callback đúng phiên bản
nếu code, magic, handler gốc và clock đều khớp. Không ghi đè hook của dylib hay
thành phần khác; nên kiểm tra từng bản riêng. Callback đang đổi hướng chưa có
đăng ký unwind trong game, nên đường ném exception native chưa được kiểm thử.

## Đường xử lý đã đối chiếu

Metadata của IPA xác định `MDPBNKPCGNG.IONEHPNFAJD()` là method virtual,
không có tham số managed, slot 17, địa chỉ tương đối `0x5C59B94`.
Method này lấy `self + 0x28`, đọc vector hướng của `CGKJLKPMGDJ` tại
`0x40`, rồi gọi các đường physics trực tiếp hoặc thông qua
`EHAANNKDEEL` (`0x5C5A8CC`). Trong mã đã đối chiếu:

| Địa chỉ ARM64 | Nội dung |
| --- | --- |
| `0x5C59CE4` | Lấy aiming-info tại handler + 0x28 |
| `0x5C59CF4`, `0x5C59CF8` | Đọc ba float hướng tại aiming-info + 0x40 |
| `0x6397294`–`0x639729C` | Physics helper lưu direction tại +0x40, origin tại +0x4C |

`HBIBDMMOOOK + 0x80` là bộ xử lý hướng; bộ xử lý giữ lại vũ khí tại
`+0x10`, vũ khí giữ player tại `+0x60`. Adapter lấy vũ khí bằng getter
`Player.GetWeaponOnHand` (`0x5616118`), thay vì coi `Player + 0x690`
là vũ khí. Vị trí slot được tính từ bảng virtual IL2CPP của bản này:
class + `0x138 + 17 * 16`. Chỉ thay con trỏ nếu nó đúng bằng method đã xác định.

Adapter chỉ áp dụng cho class `MDPBNKPCGNG` có layout phù hợp. Nó tạm đổi
vector hướng sang đầu đã chọn trước khi gọi handler gốc, rồi hoàn lại
giá trị nếu aiming-info vẫn là cùng object và vector vẫn là giá trị của
adapter. Nếu game thay object hoặc tự cập nhật vector, adapter giữ kết quả
của game. Không sửa collider, dữ liệu damage hoặc kết quả hit; raycast gốc
vẫn thực hiện kiểm tra va chạm. Không ghi `kAimRotation` hay `kAimRotationAux`.

Trước mỗi lần đổi hướng, adapter kiểm tra trạng thái bắn PRI 21 == 2,
match/local player, chủ vũ khí, HP, knock và visibility. Snapshot mục tiêu
hết hạn sau 150 ms. Tắt công tắc/vô hiệu overlay sẽ bỏ mục tiêu và thử hoàn
lại slot; không ghi đè slot đã bị thành phần khác thay. Counter chẩn đoán
đếm lượt thay vector thành công, không phải số headshot.

## Vì sao không dùng nguyên danh sách offset cũ

Trong IPA đã cung cấp, `Player + 0x770` là AvatarManager, `0x690` là
FollowCamera, `0x700` là Transform. PlayerAttributes ở `0x768`,
ShootNoReload ở `0x111`, FireIntervalScale ở `0x258`. Repo đã sửa các
trường đang dùng; bản này tiếp tục dùng trạng thái bắn PRI đã xác minh.
Ghi riêng góc phụ `0x628` không chứng minh được hướng đạn độc lập camera,
vì getter góc phụ còn có nhánh trả về góc chính `0x614`.

## Kiểm tra

`tests/silent_aim_direction_test.cpp` kiểm tra chọn toàn viewport, loại điểm
ngoài màn hình, vector suy biến/NaN, hết hạn snapshot, lỗi đọc/ghi, thay
object, game tự cập nhật vector và hoàn lại input khi handler ném exception.
Workflow chạy test này với AddressSanitizer và UndefinedBehaviorSanitizer,
rồi build cả dylib lẫn TIPA.

`tests/silent_aim_external_test.cpp` kiểm tra layout trang trạng thái, điều kiện
ký mã và đường lấy vũ khí thường/kết hợp, lỗi đọc và đổi owner.
`tests/silent_aim_remote_test.py` chạy byte code ARM64 bằng Unicorn: giữ ABI,
gọi handler đúng một lần, bỏ snapshot ghi dở/hết hạn, nhả bắn/knock/đổi owner,
loại NaN/Inf, xử lý float lớn, hoàn hướng và giữ kết quả khi game đổi vector/object.
Mô phỏng này không kiểm tra policy Mach trên iOS hay gameplay.

Đối chiếu nguồn native tại máy bằng:

```text
node tools/verify_silent_aim_layout.cjs <UnityFramework> <global-metadata.dat>
```

Script kiểm tra SHA-256, opcode và metadata; game files không được đưa vào repo.
SHA-256 nguồn:

- UnityFramework: `ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8`
- Metadata: `597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d`

Trên thiết bị: bật chẩn đoán và Silent trong từng bản; thử địch ngoài vòng FOV
nhưng trong màn hình, nhả bắn, mất visibility, knock, đổi súng và đổi trận.
Counter chỉ có ý nghĩa kiểm tra adapter được gọi. Cần quan sát riêng góc
camera và kết quả từng phát để xác nhận hiệu quả. Nếu báo chưa hỗ trợ thì
adapter không cài hook; không có fallback kéo camera.
