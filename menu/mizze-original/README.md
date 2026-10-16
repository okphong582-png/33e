> Cập nhật 16/10/2026: bản source cũ giữ nguyên giao diện và chức năng; bộ đóng gói chuyển sang ánh xạ hook native giống file ESP mới được cung cấp. Xem REFERENCE-LOADER.md. Thay đổi này không tự bật loader Documents và chưa được thử trên iPhone.

# Mizze — C# IFix menu cho Free Fire TH iOS

Nguồn C# riêng biên dịch bằng Tencent InjectFix, không sao chép bytecode từ menu tham khảo. Mục tiêu là bản TH iOS **1.132.1**, Assembly-CSharp 0.86.0.518. File xuất: `Assembly-CSharp-patch.bytes` trong artifact **Mizze-Assembly-CSharp-patch** của workflow `Build CSharp IFix Menu`.

## Sử dụng

1. Giữ bản ESP Box trước đó làm bản dự phòng. Thay file patch đang dùng trong thư mục Documents của đúng game bằng file trong artifact Mizze; tắt hẳn và mở lại game.
2. Ban đầu chỉ có nút tròn **Mizze** nền đen, viền mint. Nhấn để mở/đóng, kéo nút để di chuyển. Kéo thanh tiêu đề để di chuyển cửa sổ. Nút, menu và chữ tự tăng theo màn hình.
3. Mở KHÓA → Nhập khóa Mizze. Key hợp lệ mới cho phép ESP và aim hoạt động. Key dùng backend licensesV4 của repo 33e.
4. ESP có hai trang. AIM có công tắc aim đầu khi bắn, silent khi bắn, vòng FOV, line tới mục tiêu và hai thanh chỉnh kích cỡ FOV/tầm chọn.

Hook UIModelRole dùng trong UI/sảnh được thêm để khởi tạo sớm, cùng fallback IsReallyInStealth đã được dùng ở bản ESP Box. Chưa xác nhận bằng iPhone rằng hook sảnh chạy ở mọi giai đoạn mở game. Không có thao tác bốn ngón.

## Chức năng đã nối

- ESP: khung 2D, khung góc, khung 3D, tên (`NickName`), thanh máu (`CurHP/MaxHP`), khoảng cách, xương bằng các transform của game, điểm đầu, trục XYZ và snapline. Trang ESP 2 cho đổi gốc line dưới/giữa/trên.
- Aim đầu: khi local player đang bắn, chọn đầu đối thủ gần tâm màn hình nhất trong vòng FOV và tầm cho phép, gọi `Player.SetAimRotation(Quaternion.LookRotation(...), true)`.
- Silent: hook getter `LastAimingInfoFromWeapon`, giữ nguyên object mà game trả về, đổi target/collider/điểm/đường ngắm trong `CGKJLKPMGDJ`. Không gọi SetAimRotation ở chế độ này. Khi ngừng bắn/tắt/khóa key, hoàn lại giá trị chỉ khi game vẫn giữ dữ liệu đã áp dụng.
- Loại người chơi local, đồng đội, đã chết, inactive, thiếu transform; duyệt tối đa 128 mục, lưu hình học tối đa 16 người đang thấy trong bộ đệm 512 lệnh, bỏ tọa độ không hợp lệ.
- FOV 20–480 pixel, giới hạn theo màn hình để vòng không bị cắt; tầm 50–500 m. Hai chế độ aim loại trừ nhau, mặc định tắt. Khung góc và khung 3D cũng loại trừ nhau.
- Nền đen bo tròn, chữ trắng/mint; nút tròn có nhịp nhẹ, toggle và mở/đóng có chuyển động; input của cửa sổ đóng không nhận thao tác trong lúc fade. GUIStyle riêng được cache, không sửa skin của game. Input được đổi về tọa độ menu trước khi vẽ scale.

## Tối ưu phần giao diện menu

- Chỉ vẽ ở sự kiện Repaint; lượt nhận chạm vẫn xử lý kéo, công tắc và thanh trượt, nhưng không gọi vẽ hoặc đổi font. Bỏ qua lượt Layout/MouseMove không cần thiết.
- Giữ texture trắng dùng cho nền bo góc, ma trận scale và chuỗi giá trị thanh trượt để dùng lại; chỉ cập nhật scale hoặc chữ khi giá trị thay đổi.
- Animation kết thúc chính xác ở đích. Khi menu đã đóng, ngừng cập nhật animation của các công tắc ẩn; nút Mizze vẫn giữ nhịp nhẹ.
- Kiểm thử thực thi file bytecode cuối xác nhận lượt chạm không vẽ, 120 lượt vẽ cùng kích thước không tạo lại ma trận/chuỗi thanh trượt và không gọi lại getter texture trắng cho từng nền. Kiểm tra kéo, palette, nhập khóa và đổi hướng màn hình vẫn nằm trong bộ regression.

Đây là giảm công việc của giao diện; chưa đo FPS hoặc độ trễ trên iPhone thực tế.

## Sửa lỗi nền trắng / chữ nhỏ / key báo lỗi

Bản trước truyền màu trắng vào overload bo góc `GUI.DrawTexture`, nên nền thực tế trắng dù đã đặt `GUI.color`. Bản sửa truyền tint trực tiếp, trung hòa GUI.color lúc vẽ nền, dùng font 20 và trả lại GUI.color/contentColor/matrix sau mỗi OnGUI. Kích thước thiết kế gọn còn 382×440 thay vì 382×488, nút 80 thay vì 64; toàn bộ UI phóng theo chiều cao màn hình và giữ trong viewport. Với ảnh 1883×870, scale 1.63125 → menu khoảng 623×718, nút khoảng 130×130, chữ khoảng 33 px. ESP/FOV giữ tọa độ pixel màn hình.

Trong game, field JSON bị thiếu trả `JSONLazyCreator`: `Tag=None (7)` và `IsNull=false`. C# cũ đã coi `lock` bị thiếu là lock không hợp lệ, và tương tự với `binding`. Native của bản cung cấp xác nhận `JSONLazyCreator.get_Tag` tại 0x15c15ac trả 7; `JSONNode.get_IsNull` tại 0x15ba534 trả false. Bản sửa nhận cả null/JSONNull/None là thiếu, kiểm tra object trước khi đọc. Không bỏ kiểm tra key bị khóa, hết hạn hoặc thuộc máy khác. Dữ liệu lock sai thật vẫn bị từ chối với thông báo nêu field lỗi.

Regression test đã tái hiện bản cũ từ chối key hợp lệ khi mock phản ánh JSONLazyCreator, rồi xác nhận bản mới chấp nhận trường lock bị thiếu/null và từ chối lock sai kiểu. Bộ test cũng mô phỏng overload vẽ dùng explicit color để lỗi nền trắng không còn lọt qua kiểm thử.

## Renderer gom mesh và bỏ file JSON bằng bản IPA riêng

Bản 1702b3d vẫn bị người dùng báo văng khi nhiều ESP bật. Bản này qua **933 kiểm tra bytecode offline**, gồm shader không có, GPU draw/SetPass lỗi, hồi phục có thời gian chờ, bộ đệm tái sử dụng và đếm riêng các thao tác native GUI. Bản mới gom khung, xương, đường nối, trục XYZ và thanh máu thành một Mesh dùng vertex color: một DrawMeshNow mỗi Repaint thay cho hàng trăm DrawTexture/GUI.matrix. Dữ liệu đỉnh/màu/chỉ số dùng bộ đệm cố định, mesh upload khi mẫu ESP thay đổi. Tên và khoảng cách vẫn dùng GUI.Label; dấu đầu/FOV vẫn dùng hai texture cache. Loop bỏ qua nét đã gom trước mọi thao tác GUI.color/matrix/texture lookup. Mock có bộ đếm native operation tách khỏi các quad giả dùng để xuất preview.

Material dùng Hidden/Internal-Colored, alpha blending, Cull Off, ZWrite Off, ZTest Always. Nếu shader không có hoặc SetPass/draw lỗi, giải phóng mesh/material, khôi phục GL stack trong finally, thử lại sau 5 giây; fallback giảm xuống tối đa ba người và 96 nét. Không khẳng định shader này có sẵn trên mọi bản game: tình trạng thực tế phải xác nhận trên thiết bị. Mọi tính năng ESP vẫn có toggle; giới hạn số người là để giữ tải có giới hạn.

**Với app đang cài, file bytes vẫn cần loader được bật.** File localConfig.json cung cấp chỉ chứa testCodePatch=true. Native get_TestCodePatch tại RVA 0x507c3e0 đọc m_LocalConfig (static offset 0x130), rồi testCodePatch (offset 0x3FC). StartLauncher gọi getter tại 0x50913cc và bỏ qua đường test patch nếu false. Vì kiểm tra diễn ra trước khi đọc bytecode, sửa file bytes không thể tự kích hoạt loader.

Đã tạo riêng biến thể IPA từ đúng IPA TH 1.132.1 do người dùng cung cấp: thay đúng 8 byte đầu getter thành ARM64 mov w0,#1; ret. Công cụ native-loader.cjs kiểm tra SHA256 toàn UnityFramework và bytes cũ trước khi sửa, tạo file mới, đọc lại framework để xác minh. IPA gốc giữ nguyên. Bản IPA mới cần **ký lại** trước khi cài, sau đó dán Assembly-CSharp-patch.bytes vào Documents như cũ; không cần localConfig.json trong biến thể đó. Chưa cài/thử trên iPhone, chưa ký bởi công cụ này. Không áp dụng thay đổi native cho phiên bản khác.

Kiểm tra archive riêng xác nhận 3.286 entry còn lại giữ nguyên compressed data; chỉ 8 byte native đổi. Tên entry dùng dấu slash chuẩn ZIP thay vì backslash của archive gốc. IPA khoảng 994 MB được giao tại workspace, không commit binary game vào GitHub. Source công cụ và bằng chứng loader được commit; GitHub vẫn build artifact bytes như trước.

## Sửa đường vẽ đông địch và lệch hướng ngắm

Renderer mới dùng bộ đệm cố định 512 lệnh (Rect/Color/Matrix/string/Texture), không giữ Player/Transform trong bộ đệm. Vị trí được đọc khoảng 13 lần/giây, giảm xuống khoảng 8 lần/giây nếu lượt đọc tốn hơn 25 ms; các Repaint ở giữa chỉ vẽ dữ liệu đã chiếu. Giới hạn tối đa 16 người nhìn thấy và dừng lượt lấy mẫu sau khoảng 12 ms giữa các người; người vượt giới hạn sẽ không được vẽ trong lượt đó. Đổi match/camera/kích thước màn hình xóa bộ đệm; tắt ESP xóa lệnh ngay. Đây là đánh đổi độ cập nhật theo chuyển động (khoảng 75–120 ms cộng thời gian lấy mẫu) để giảm số lần gọi game/native.

Bản cũ có thể hết hạn mức giữa các nét, khiến một hình bị cắt dở. Bản mới chừa đủ chỗ trước khi bắt đầu một người; nếu getter của người đó báo lỗi giữa chừng, toàn bộ lệnh vừa thêm được hoàn lại. Box 2D dùng bốn rectangle trực tiếp, không TRS/Quaternion/GUI.matrix cho từng cạnh. Đầu nét chồng nửa độ dày, giúp đường nối/3D/xương không lộ khe tại điểm chung. Khung liền là mặc định; tùy chọn khung góc vẫn cố ý chừa trống giữa cạnh.

FOV và đánh dấu đầu dùng hai texture RGBA không mipmap, lọc bilinear, dựng một lần rồi Apply(false,true) để bỏ bộ đệm CPU trên thiết bị. FOV mỗi khung hình là một quad vuông không xoay, không còn 48 đoạn. Bán kính tối đa lấy min(480, chiều rộng/2−8, chiều cao/2−8); thanh chỉnh và vùng chọn aim dùng cùng giới hạn, tránh vòng vượt màn hình rồi nhìn như bị cắt. Kiểm tra 360 góc trên pixel texture xác nhận đường tròn kín. Texture bị Unity hủy được tạo lại; texture tạo dở bị Destroy nếu upload lỗi.

Aim đầu khi bắn tính LookRotation(head − camera.position), thay cho head − AimStartPostion. Gốc AimStartPostion trong game phụ thuộc trạng thái nhân vật; dùng nó để điều khiển góc nhìn có thể gây parallax khi camera lệch vai. Regression test đặt camera và gốc bắn lệch hai bên để phân biệt hai đường. Silent vẫn dùng gốc bắn vì nó sửa bản ghi đường đạn, không điều khiển camera. Chưa đo độ lệch thực tế trên iPhone nên đây là sửa cách tính, chưa phải xác nhận ghim đầu trong game.

Bộ kiểm tra có 2.400 lượt dense ESP với 150 mục (1.200 ép lấy mẫu và 1.200 Repaint theo lịch), kiểm tra không tạo/upload texture mỗi khung hình, số lần chiếu giảm, bộ đệm hữu hạn, lỗi getter muộn được rollback và texture bị hủy/upload lỗi. Mock chạy interpreter Tencent thật với bytecode cuối; **không chứng minh hết crash native/EXC_BAD_ACCESS hoặc OOM trên iPhone**. Người dùng báo bản 685e6f7 vẫn văng; chưa có crash stack để xác định nguyên nhân native.

## Giảm tải ESP và giao diện màu

Đã bỏ Find/GetComponent/DontDestroyOnLoad lặp lại trên mỗi lần đọc getter: driver được giữ lại và chỉ tạo lại khi Unity báo đã bị hủy. Aim tắt không còn lấy local player trên mỗi lần Repaint. ESP đọc camera position một lần, giữ root/head transform trong phạm vi một người của một khung hình, đọc HP một lần và xử lý lỗi từng người thay vì hủy cả lượt vẽ. Kiểm tra danh sách thu nhỏ; lưu hình học tối đa 16 người đang thấy trong bộ đệm 512 lệnh, vòng đánh dấu đầu dùng texture. Thanh máu dùng DrawTexture đơn giản, không gọi shader bo góc. Đây là giảm tải và phòng lỗi đã xác định trong code; chưa có crash log hoặc phép thử iPhone để kết luận đã loại bỏ nguyên nhân văng native.

Tab **MÀU** có 18 mẫu và ba thanh RGB, chỉnh độc lập màu ESP (khung/tên/khoảng cách/xương/đầu/đường nối), FOV và thanh máu. Trục XYZ giữ màu nhận biết từng trục. Màu được lưu PlayerPrefs khi nhả thanh hoặc chạm mẫu. Toàn bộ nhãn/thông báo menu đã có dấu; compiler dùng UTF-8. Tiêu đề 25, nội dung 20, nhãn nhỏ 16, thông báo 18; chuyển tab có gạch chạy, toggle có hiệu ứng nảy, màu đang chọn và nút tròn có nhịp sáng.

Font OS ưu tiên Avenir Next, Helvetica Neue, Arial, được tạo một lần. Nếu không tải được thì dùng font sẵn của game. Menu tạm đặt font khi vẽ và hoàn lại font của game trong finally. API [CreateDynamicFontFromOSFont](https://docs.unity3d.com/2022.3/Documentation/ScriptReference/Font.CreateDynamicFontFromOSFont.html) chọn font có trên máy và có ký tự cần vẽ; hình xem trước offline dùng Arial, chưa xác nhận font cụ thể trên iPhone. API GUIStyle.font đã bị strip trong dump này nên không gọi setter không tồn tại.

Bản này qua kiểm tra trên bytecode cuối, gồm 1.200 khung hình liên tiếp với 150 mục, toàn bộ ESP bật, GC cưỡng bức, đối tượng bị hủy, getter HP ném lỗi, bảng màu/RGB/lưu màu, font hoàn lại và UTF-8 trong bytecode. Các API vẫn là mock; 1.200 khung hình kiểm thử không tương đương thời lượng chơi thật trên iPhone.

## Key và tương thích thiết bị

Giao thức protocol=4: enabled, expiresAt theo giờ server, lock.until/message, binding.deviceHash/version/claimedAt. Claim lần đầu dùng PUT với `if-match: null_etag`; phải đọc lại binding khớp thiết bị mới kích hoạt. Request bất đồng bộ, timeout 6 s, xác thực lại sau 10 s, lease tối đa 30 s. Đổi key hủy request cũ. Test không gửi request đến database thật.

**Mã máy của bản C# khác mã Keychain của menu native 33e.** Nếu key đã gắn với menu native, admin phải gỡ binding cũ rồi bạn nhập lại key để gắn bản C#; key hết hạn hoặc bị khóa vẫn bị từ chối. Việc dùng cùng backend không có nghĩa là binding native tự chuyển sang bản này. Chỉ lưu hash key trong PlayerPrefs.

## Kiểm chứng và giới hạn

`verify-declarations.cjs` đối chiếu extern/field với dump TH được cung cấp. `bindings-evidence.json` ghi lại 195 khai báo đó; CI kiểm tra mọi extern sinh ra đều được bao phủ. Đây là kiểm tra tên/chữ ký, không chứng minh mọi generic call có sẵn trong IL2CPP AOT.

`test.cjs` chạy **file bytes cuối** trong interpreter Tencent pinned `5ba42eb8f63fe37134a3c78690f97d8425e13588`, với opcode của game. API Unity/game/network là test double offline. Kiểm tra bao gồm model sảnh, giữ return của game, vòng đời driver, kéo/toggle/animation, hình học ESP và lọc mục tiêu, aim khi bắn/FOV, silent và hoàn lại dữ liệu, khóa/hết hạn/binding/key đổi giữa request. Các SVG preview được ghi từ lệnh vẽ của chính bytecode trong harness; quad mesh được mock chuyển về hình học từ vertex thực tế đã upload, không phải ảnh chụp game.

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
