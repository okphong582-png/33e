# Mizze — C# IFix menu cho Free Fire TH iOS

Nguồn C# riêng biên dịch bằng Tencent InjectFix, không sao chép bytecode từ menu tham khảo. Mục tiêu là bản TH iOS **1.132.1**, Assembly-CSharp 0.86.0.518. File xuất: `Assembly-CSharp-patch.bytes` trong artifact **Mizze-Assembly-CSharp-patch** của workflow `Build CSharp IFix Menu`.

## Sử dụng

1. Giữ bản ESP Box trước đó làm bản dự phòng. Thay file patch đang dùng trong thư mục Documents của đúng game bằng file trong artifact Mizze; tắt hẳn và mở lại game.
2. Ban đầu chỉ có nút tròn **Mizze** nền đen, viền mint. Nhấn để mở/đóng, kéo nút để di chuyển. Kéo thanh tiêu đề để di chuyển cửa sổ. Nút, menu và chữ tự tăng theo màn hình.
3. Mở KEY → Nhập key Mizze. Key hợp lệ mới cho phép ESP và aim hoạt động. Key dùng backend licensesV4 của repo 33e.
4. ESP có hai trang. AIM có công tắc aim đầu khi bắn, silent khi bắn, vòng FOV, line tới mục tiêu và hai thanh chỉnh kích cỡ FOV/tầm chọn.

Hook UIModelRole dùng trong UI/sảnh được thêm để khởi tạo sớm, cùng fallback IsReallyInStealth đã được dùng ở bản ESP Box. Chưa xác nhận bằng iPhone rằng hook sảnh chạy ở mọi giai đoạn mở game. Không có thao tác bốn ngón.

## Chức năng đã nối

- ESP: khung 2D, khung góc, khung 3D, tên (`NickName`), thanh máu (`CurHP/MaxHP`), khoảng cách, xương bằng các transform của game, điểm đầu, trục XYZ và snapline. Trang ESP 2 cho đổi gốc line dưới/giữa/trên.
- Aim đầu: khi local player đang bắn, chọn đầu đối thủ gần tâm màn hình nhất trong vòng FOV và tầm cho phép, gọi `Player.SetAimRotation(Quaternion.LookRotation(...), true)`.
- Silent: hook getter `LastAimingInfoFromWeapon`, giữ nguyên object mà game trả về, đổi target/collider/điểm/đường ngắm trong `CGKJLKPMGDJ`. Không gọi SetAimRotation ở chế độ này. Khi ngừng bắn/tắt/khóa key, hoàn lại giá trị chỉ khi game vẫn giữ dữ liệu đã áp dụng.
- Loại người chơi local, đồng đội, đã chết, inactive, thiếu transform; giới hạn 128 mục và bỏ tọa độ không hợp lệ.
- FOV 20–480 pixel; tầm 50–500 m. Hai chế độ aim loại trừ nhau, mặc định tắt. Khung góc và khung 3D cũng loại trừ nhau.
- Nền đen bo tròn, chữ trắng/mint; nút tròn có nhịp nhẹ, toggle và mở/đóng có chuyển động; input của cửa sổ đóng không nhận thao tác trong lúc fade. GUIStyle riêng được cache, không sửa skin của game. Input được đổi về tọa độ menu trước khi vẽ scale.

## Sửa lỗi nền trắng / chữ nhỏ / key báo lỗi

Bản trước truyền màu trắng vào overload bo góc `GUI.DrawTexture`, nên nền thực tế trắng dù đã đặt `GUI.color`. Bản sửa truyền tint trực tiếp, trung hòa GUI.color lúc vẽ nền, dùng font 20 và trả lại GUI.color/contentColor/matrix sau mỗi OnGUI. Kích thước thiết kế gọn còn 382×440 thay vì 382×488, nút 80 thay vì 64; toàn bộ UI phóng theo chiều cao màn hình và giữ trong viewport. Với ảnh 1883×870, scale 1.63125 → menu khoảng 623×718, nút khoảng 130×130, chữ khoảng 33 px. ESP/FOV giữ tọa độ pixel màn hình.

Trong game, field JSON bị thiếu trả `JSONLazyCreator`: `Tag=None (7)` và `IsNull=false`. C# cũ đã coi `lock` bị thiếu là lock không hợp lệ, và tương tự với `binding`. Native của bản cung cấp xác nhận `JSONLazyCreator.get_Tag` tại 0x15c15ac trả 7; `JSONNode.get_IsNull` tại 0x15ba534 trả false. Bản sửa nhận cả null/JSONNull/None là thiếu, kiểm tra object trước khi đọc. Không bỏ kiểm tra key bị khóa, hết hạn hoặc thuộc máy khác. Dữ liệu lock sai thật vẫn bị từ chối với thông báo nêu field lỗi.

Regression test đã tái hiện bản cũ từ chối key hợp lệ khi mock phản ánh JSONLazyCreator, rồi xác nhận bản mới chấp nhận trường lock bị thiếu/null và từ chối lock sai kiểu. Bộ test cũng mô phỏng overload vẽ dùng explicit color để lỗi nền trắng không còn lọt qua kiểm thử.

## Key và tương thích thiết bị

Giao thức protocol=4: enabled, expiresAt theo giờ server, lock.until/message, binding.deviceHash/version/claimedAt. Claim lần đầu dùng PUT với `if-match: null_etag`; phải đọc lại binding khớp thiết bị mới kích hoạt. Request bất đồng bộ, timeout 6 s, xác thực lại sau 10 s, lease tối đa 30 s. Đổi key hủy request cũ. Test không gửi request đến database thật.

**Mã máy của bản C# khác mã Keychain của menu native 33e.** Nếu key đã gắn với menu native, admin phải gỡ binding cũ rồi bạn nhập lại key để gắn bản C#; key hết hạn hoặc bị khóa vẫn bị từ chối. Việc dùng cùng backend không có nghĩa là binding native tự chuyển sang bản này. Chỉ lưu hash key trong PlayerPrefs.

## Kiểm chứng và giới hạn

`verify-declarations.cjs` đối chiếu extern/field với dump TH được cung cấp. `bindings-evidence.json` ghi lại 162 khai báo đó; CI kiểm tra mọi extern sinh ra đều được bao phủ. Đây là kiểm tra tên/chữ ký, không chứng minh mọi generic call có sẵn trong IL2CPP AOT.

`test.cjs` chạy **file bytes cuối** trong interpreter Tencent pinned `5ba42eb8f63fe37134a3c78690f97d8425e13588`, với opcode của game. API Unity/game/network là test double offline. Kiểm tra bao gồm model sảnh, giữ return của game, vòng đời driver, kéo/toggle/animation, hình học ESP và lọc mục tiêu, aim khi bắn/FOV, silent và hoàn lại dữ liệu, khóa/hết hạn/binding/key đổi giữa request. Các SVG preview được ghi từ lệnh vẽ của chính bytecode trong harness, không phải ảnh chụp game.

Người dùng đã gửi ảnh xác nhận bản Mizze trước hiện trong game, đồng thời phát hiện lỗi nền trắng/chữ nhỏ/đọc lock. **Bản sửa mới chưa được chạy trực tiếp trên iPhone**, và chưa xác thực key cụ thể của người dùng với backend thật. Aim đã nối API và có kiểm thử logic, nhưng chưa xác nhận hiệu quả bắn thực tế, việc server chấp nhận hướng bắn, hay tương thích các phiên bản khác. Việc biên dịch thành công không đồng nghĩa tất cả tính năng hoạt động trên thiết bị. Không hỗ trợ Android.

## Build

Workflow vẫn tạo artifact ESP Box dự phòng. Với Windows/.NET Framework và Node:

```text
node menu/prepare-runtime-test.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/build.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/package.cjs
node menu/mizze/test.cjs
```

`GameBindings.cs`, `UnityBindings.cs`, `GuiBindings.cs`, `TextBindings.cs`, `PhysicsBindings.cs`, `NetworkBindings.cs`, `JsonBindings.cs` chỉ chứa khai báo để compiler hiểu API; các body giả này không được đưa vào patch. `RuntimeApis.cs` là API thử nghiệm và không tham gia compile patch. `CompilerHost.cs` chỉ chọn bốn fix và helper Mz*. `package.cjs` đổi container magic/flag của game, giữ nguyên bytecode do compiler sinh.
