# Silent aim thử nghiệm — Free Fire 1.132.1

Bản dylib có công tắc **Silent aim (thử nghiệm)**, mặc định tắt. Khi bật,
aim thường không ghi góc camera. Bộ chọn lấy đầu địch còn sống, chưa knock,
khác đội và đang hiện trong viewport, trong khoảng cách hiển thị đã đặt.
Vòng FOV và lựa chọn aim cổ chỉ áp dụng cho aim thường.

Đây là triển khai thử nghiệm có kiểm tra layout, **chưa được xác nhận bằng
phát bắn trên thiết bị**. Không cam kết mọi viên đều trúng đầu. Độ tản,
đường bắn đặc biệt, hotfix và kiểm tra phía server có thể ảnh hưởng kết quả.
Bản TIPA không chạy callback trong process của game nên không có tính năng này.

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

Đối chiếu nguồn native tại máy bằng:

```text
node tools/verify_silent_aim_layout.cjs <UnityFramework> <global-metadata.dat>
```

Script kiểm tra SHA-256, opcode và metadata; game files không được đưa vào repo.
SHA-256 nguồn:

- UnityFramework: `ca84eb7b8e0273f337243f914839104bbce037efb6695c5ed314f992ca903ef8`
- Metadata: `597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d`

Trên thiết bị: bật chẩn đoán và Silent trong dylib; thử địch ngoài vòng FOV
nhưng trong màn hình, nhả bắn, mất visibility, knock, đổi súng và đổi trận.
Counter chỉ có ý nghĩa kiểm tra adapter được gọi. Cần quan sát riêng góc
camera và kết quả từng phát để xác nhận hiệu quả. Nếu báo chưa hỗ trợ thì
adapter không cài hook; không có fallback kéo camera.
