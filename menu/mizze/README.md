# Mizze — C# IFix menu cho Free Fire TH iOS

Nguồn C# riêng biên dịch bằng Tencent InjectFix, mục tiêu TH iOS **1.132.1**, Assembly-CSharp 0.86.0.518. File xuất: Assembly-CSharp-patch.bytes, artifact Mizze-Assembly-CSharp-patch trong workflow Build CSharp IFix Menu.

## Bản sửa renderer sau phản hồi văng

Người dùng báo cả bản Mesh và bản tối ưu giao diện vẫn văng, đồng thời nghi có xung đột. Chưa có crash stack để xác định nguyên nhân. Bản này loại các đường tác động lên trạng thái render/font dùng chung; không coi máy yếu là nguyên nhân đã được chứng minh.

- **Bỏ hoàn toàn Mesh/Material/Shader/GL/Graphics.DrawMeshNow.** ESP chỉ phát lệnh GUI.DrawTexture/GUI.Label; bytecode cuối được kiểm tra không còn descriptor của các API trên.
- **Bỏ tạo font OS và GUIStyle.SetDefaultFont.** Dùng font Unicode sẵn của game với GUIStyle riêng, vẫn giữ cỡ chữ, màu và dấu tiếng Việt. Không sửa font mặc định dùng chung.
- Chặn OnGUI lồng nhau; trả lại GUI.color/contentColor/matrix trong finally. Ảnh hưởng lên native state vẫn cần thử thực tế trên máy.
- Xương dùng bộ đệm cố định 11 điểm màn hình: root/head đã chiếu sẵn, chín xương còn lại mỗi điểm chiếu một lần. Không giữ Player/Transform trong bộ đệm hình học. Mỗi người có mười cạnh xương như trước.
- Hình học được cập nhật mỗi 33 ms (khoảng 30 Hz), dùng 66 ms nếu lượt lấy mẫu tốn hơn 8 ms. Giữa các lần lấy mẫu chỉ vẽ dữ liệu màn hình đã lưu.
- Giới hạn 192 lệnh, duyệt tối đa 64 mục; tối đa 12 người với ESP đơn giản, sáu người nếu bật 3D/xương/XYZ. Dừng lấy mẫu giữa các người khi vượt 4 ms; đây là hạn mức công việc, không phải kết luận về nguyên nhân văng. Người vượt giới hạn không được hiển thị trong lượt đó.
- Chừa đủ 32 lệnh trước khi vẽ một người; nếu getter báo lỗi giữa chừng thì hoàn lại toàn bộ hình của người đó. Đổi match/camera/kích thước màn hình hoặc tắt ESP xóa bộ đệm.

try/catch xử lý ngoại lệ managed; không chặn được mọi lỗi native như EXC_BAD_ACCESS. **Chưa xác nhận hết văng hoặc đo FPS trên iPhone.**

## Giao diện và sử dụng

1. Giữ file cũ dự phòng. Thay patch trong Documents của đúng game bằng file mới rồi tắt hẳn, mở lại game. Loader của bản game gốc vẫn cần localConfig.json với testCodePatch=true; bytecode chạy sau bước kiểm tra này.
2. Ban đầu chỉ có nút tròn Mizze, kính tối bán trong suốt và viền mint. Chạm để mở/đóng; kéo nút hoặc thanh tiêu đề để di chuyển. Menu 382×440, nút 80×80 theo kích thước thiết kế, tự scale theo màn hình.
3. KHÓA → Nhập khóa Mizze. Khóa hợp lệ mới cho phép ESP/aim chạy. Backend licensesV4 của repo 33e.
4. ESP có hai trang; AIM có aim đầu khi bắn, silent khi bắn, FOV, line mục tiêu và thanh chỉnh FOV/tầm; MÀU có 18 mẫu và ba thanh RGB cho ESP/FOV/máu, lưu khi chạm mẫu hoặc nhả thanh.

Panel dùng nền tối60% alpha, viền sáng20% và phản chiếu24%; nút dùng lòng kính58%. Chữ giữ độ đục đầy đủ. Đây là lớp kính bằng GUI, không làm blur ảnh nền game và không thêm shader/GL/RenderTexture.

UI chỉ vẽ ở Repaint, lượt chạm vẫn xử lý công tắc/slider/kéo nhưng không vẽ. Cache texture nền, GUIStyle, ma trận scale và chuỗi giá trị slider; chỉ đổi khi cần. Animation dừng ở đích và ngừng cập nhật toggle ẩn khi cửa sổ đã đóng. Tiêu đề25, nội dung20, nhãn nhỏ16, thông báo18; chữ UTF-8 có dấu. Bản trước có nền trắng vì overload bo góc cần explicit color; bản hiện tại truyền tint trực tiếp.

Bốn hook: GameFacade.get_UIModelRole, Player.IsReallyInStealth, Player.get_LastAimingInfoFromWeapon, SceneEditBoxSelectTool.OnGUI. Giữ return gốc và không hook movement. Driver được tạo sớm từ UIModelRole hoặc fallback stealth, cache và DontDestroyOnLoad. Chưa xác nhận hook sảnh chạy ở mọi giai đoạn trên iPhone.

## ESP và aim

ESP gồm khung2D/góc/3D, tên tối đa24 ký tự, máu CurHP/MaxHP, khoảng cách, xương, dấu đầu, XYZ và snapline với gốc dưới/giữa/trên. Lọc local/đồng đội/chết/inactive/mất transform/tọa độ không hợp lệ. Box2D là bốn rectangle trực tiếp; đầu nét chồng nửa độ dày để tránh khe. Khung góc và3D loại trừ nhau.

FOV và dấu đầu dùng hai texture RGBA bilinear không mipmap, dựng một lần rồi Apply(false,true). FOV vẽ một quad vuông không xoay; kiểm tra pixel360 góc để xác nhận vòng kín. Bán kính20–min(480,width/2−8,height/2−8), tầm50–500m. Slider/drawing/chọn mục tiêu dùng cùng giới hạn. Texture bị hủy được dựng lại; cấp phát dở được Destroy khi upload báo lỗi.

Aim đầu khi bắn chọn đầu gần tâm trong FOV/tầm, gọi SetAimRotation với LookRotation(head−camera.position). Silent sửa bản ghi native do getter trả về và dùng gốc bắn AimStartPostion; hoàn lại chỉ khi game còn giữ các giá trị do patch đặt. Hai aim loại trừ nhau, mặc định tắt. Kiểm tra logic offline không xác nhận hit/headlock hoặc việc server chấp nhận đường bắn.

## Tab SÚNG — chức năng client thử nghiệm

- **Bắn nhanh**: chọn1,5×/2×/3×; giảm FireIntervalScale từ giá trị gốc. Native của HBIBDMMOOOK nhân hệ số này vào khoảng cách giữa các phát bắn. Không đặt thời gian bằng0; hệ số đầu ra tối thiểu0,05. Giá trị bất thường/NaN bị bỏ qua.
- **Không nạp đạn**: bật PlayerAttributes.IsAmmoFree và ShootNoReload. Hai cờ thuộc hệ thống vũ khí thật; native có đọc ShootNoReload sau get_Attributes. Không gọi FullWeaponAmmo hoặc tự gửi packet.
- Hai chức năng mặc định tắt, chỉ áp dụng cho local player còn sống trong trận với khóa hợp lệ. Khi bật, kiểm tra tối đa10 lần/giây, chỉ ghi khi giá trị thay đổi. Buff native thay đổi tốc độ trở thành mốc mới, không chia lặp giá trị patch đã đặt.
- Tắt từng chức năng, chết, rời trận, đổi component hoặc khóa hết hiệu lực sẽ hoàn lại giá trị đã lưu nếu game vẫn giữ giá trị patch đặt; không ghi đè giá trị mới khác mà native đã thay. Bộ kiểm tra có các tình huống này.
- **Fakelag chưa triển khai**: dump chỉ có PacketLossRateForEditorTest, chưa xác minh tác dụng trên release iOS. Menu ghi rõ chưa hỗ trợ; không có toggle giả hoặc thay đổi mạng. Bổ sung fakelag cần xác định đường gửi vị trí có thể gọi/hoàn lại đúng trong phiên bản này.

weapons-evidence.json ghi API/offset và điểm đọc native đã đối chiếu. Đây là xác nhận đường client, **chưa xác nhận bắn nhanh/không nạp được máy chủ chấp nhận hoặc hoạt động trong trận thật trên iPhone**. Không kết luận chỉ thay client sẽ vượt kiểm tra server.

## Khóa

protocol4, enabled, expiresAt theo giờ server, lock.until/message, binding.deviceHash/version/claimedAt. Claim dùng if-match:null_etag, phải đọc lại binding khớp mới xác thực. Timeout6s, refresh10s, lease tối đa30s; đổi key hủy request cũ. Test không gửi request đến database thật.

SimpleJSON thiếu field trả JSONLazyCreator Tag=None/IsNull=false: bản hiện tại nhận null/JSONNull/None là thiếu, kiểm tra kiểu dữ liệu trước khi đọc. Vẫn từ chối khóa hết hạn/bị khóa/máy khác và dữ liệu sai kiểu. Hash thiết bị C# dùng SystemInfo khác IDFV/Keychain của menu native33e; khóa đã gắn native cần admin gỡ binding cũ. Chỉ lưu hash key trong PlayerPrefs.

## Kiểm chứng

verify-declarations.cjs đối chiếu extern/field với dump TH cung cấp; bindings-evidence.json ghi khai báo. test.cjs chạy **bytecode cuối** bằng Tencent VM pinned5ba42eb8f63fe37134a3c78690f97d8425e13588 với opcode game. Unity/game/network là doubles offline, không thay thế crash log/thử iPhone.

Regression gồm lobby/drag/animation/toggle/palette, trạng thái GUI, lọc và hình học ESP, danh sách150 mục với toàn bộ ESP bật, hủy đối tượng/getter lỗi, resource texture, cập nhật theo lịch, từng xương chỉ chiếu một lần, không dùng Mesh/GL/font-global, bộ đệm cố định, aim/silent, key binding/expiry/races. SVG xuất từ lệnh vẽ bytecode; không phải ảnh chụp game.

## Build

Workflow vẫn tạo artifact ESP Box dự phòng. Windows/.NET Framework và Node:

~~~text
node menu/prepare-runtime-test.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/build.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/package.cjs
node menu/mizze/verify-declarations.cjs <TH dump Assembly directory>
node menu/mizze/test.cjs
~~~

Bindings chỉ là khai báo compile, body giả không được đưa vào patch; RuntimeApis.cs chỉ dùng test. CompilerHost.cs chọn bốn fix và helperMz*; package.cjs đổi magic/flag phù hợp game và giữ bytecode do compiler sinh.
