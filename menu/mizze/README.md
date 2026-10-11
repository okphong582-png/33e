# Mizze — C# IFix menu cho Free Fire TH iOS

Nguồn C# riêng biên dịch bằng Tencent InjectFix, mục tiêu TH iOS **1.132.1**, Assembly-CSharp 0.86.0.518. File xuất: Assembly-CSharp-patch.bytes, artifact Mizze-Assembly-CSharp-patch trong workflow Build CSharp IFix Menu.

## R5 — quay về đường menu trước sửa FL

Bản này phục hồi nguồn khởi tạo/vẽ theo commit471de8a, trước đợt sửa FL/R2. R3/R4 chưa giúp menu hiện trên thiết bị người dùng; nguyên nhân trên máy chưa được xác nhận vì chưa có startup/error log mới.

- GameBindings.cs và CompilerHost.cs khớp hoàn toàn baseline. Sáu hook,194 extern methods và235 khai báo được giữ nguyên. verify-compatibility.cjs kiểm tra tập type, method, native field và hook bằng với baseline; không thêm phụ thuộc runtime.
- Bỏ COW.GcUtil/ManualGCReason, GUI.enabled, Behaviour.enabled và hook COWGameEntry/GameEngine đã thêm ở R2–R4. Trả đường vẽ Mizze về body OnGUI cũ; không vẽ nút trong finally.
- Chỉ giữ sửa vị trí FL: khi bật Nút nổi Fakelag, FL TẮT nằm cạnh Mizze, tự chọn dưới/trên/bên cạnh và giới hạn trong màn hình. Kéo nút không kích hoạt; tắt trong menu ẩn nút. Không thay giao thức mạng.
- Giữ log khởi động giới hạn8 mốc, dùng các API đã có trong baseline: Documents/Mizze-startup.log có dấu R5 compatibility startup, driver-ready, gui-entered và launcher-painted. Mốc vẽ chỉ chứng minh lời gọi vẽ hoàn thành, không xác nhận hình ảnh trên iPhone.
- Không còn thu gom GC native chủ động từ R2. Log thiết bị trước đây đã cho thấy bộ nhớ managed tăng; R5 phục hồi tương thích menu, chưa xác nhận sửa hết văng hay hết tăng bộ nhớ. Không dùng số kiểm tra offline để kết luận trên máy thật.
- Gói Documents gồm đúng Assembly-CSharp-patch.bytes và localConfig.json (testCodePatch=true). Vuốt tắt game hoàn toàn, thay cả hai file rồi mở lại. Mục tiêu TH iOS1.132.1; thiết bị chưa được kiểm chứng.

## Giảm đọc ESP và chặn chạm xuyên menu

Bản này đã qua **2.372 kiểm tra offline** trên bytecode cuối và đối chiếu **235 khai báo** với dump TH iOS. Bài chạy dài đi qua 1.800 bước lấy mẫu trên timeline mô phỏng15phút; đây không phải chơi thật15phút trên iPhone.

- ESP chỉ kiểm tra local actor/xương khi đến lịch lấy mẫu33/66ms, thay vì lặp mỗi Repaint. Local chưa sẵn sàng chờ100ms; hình cũ quá250ms bị xóa. Camera/match/kích thước đổi thì bỏ sample và cache cũ.
- Cache tên/khoảng cách có64 ô, chỉ giữ ID/chuỗi/số. Tên đọc lại tối đa mỗi5s khi cache không va chạm; khoảng cách chỉ tạo chuỗi khi đổi mét nguyên. Xóa cache khi tắt ESP/FOV hoặc rời trận. Kiểm tra IsDead và ID trước HP/xương của đối thủ.
- Vùng nhận chạm dùng camera NGUI sẵn có, một panel vô hình và ba widget/collider theo menu, nút Mizze và nút FL. Khi đóng, collider menu tắt; kéo/đổi kích thước cập nhật vùng nhận chạm. Không tắt toàn bộ đầu vào game. Thao tác IMGUI bắt đầu trong menu được giữ đến lúc nhả; thao tác bắt đầu ngoài menu không kích hoạt nút khi nhả vào trong.
- touch-evidence.json ghi đường raycast native đã khảo sát. Bài kiểm tra xác nhận vị trí collider, đóng/mở, kéo, đổi camera/kích thước và không tạo thêm object sau1.000 lần đồng bộ. Chưa xác nhận thứ tự xử lý chạm hoặc đa chạm trên iPhone thật.
- Khi ESP hoặc fakelag đang bật, mỗi30s ghi **Documents/Mizze-session.log**, giữ12 dòng gần nhất bằng cách ghi đè. Log gồm thời gian, bộ nhớ managed, số lệnh, lỗi, số callback cuối pha fakelag và số lần giữ vị trí; không phải stack crash native. Không ghi file mỗi frame.

## Khôi phục menu trong trận

Các bản trước vẫn văng trên thiết bị người dùng. Chưa có crash stack nên chưa xác định được nguyên nhân native; những thay đổi dưới đây sửa các đường xung đột có thể chứng minh trong mã và bổ sung khả năng ghi lỗi, không phải xác nhận hết văng trên iPhone.

- **Đổi đường đọc ESP**: không gọi GetHeadTF/RootTransform hoặc getter xương có lazy initialization. Native GetHeadTF tăng GetCount; các getter root/xương có thể tìm node rồi ghi cache. ESP nay đọc 11 trường ITransformNode đã có, kiểm tra Transform còn sống và bỏ qua node chưa được game tạo. esp-cache-evidence.json ghi offset đã đối chiếu ARM64. Không tự tạo hoặc ghi cache xương của game. Chưa xác nhận đây là nguyên nhân văng trên thiết bị.
- **Lỗi lấy mẫu được xử lý riêng**: hủy toàn bộ sample dang dở, chờ500ms trước khi đọc lại; ba sample liên tiếp lỗi thì tạm dừng ESP đến khi người dùng bật lại. Bộ đếm này tách với lỗi vẽ. Lỗi vòng ngoài không còn bị nuốt im lặng.
- InjectFix NewFieldInfo giữ giá trị static trong dictionary theo tên trường. package.cjs nay thêm namespace từ SHA256 của nguồn C# vào tên trường mới. Một bản mới không lấy MzInitialized/array/native wrapper của bản trước khi nạp lại trong cùng tiến trình. Regression đặt trạng thái cũ có array sai kích thước trước khi nạp bytecode mới và xác nhận trạng thái được tách. Nạp lại cùng mã nguồn giữ cùng namespace.
- **Bỏ hook Player.IsReallyInStealth**. Tạo driver qua UIModelRole ở sảnh, có đường khôi phục qua NeedRunHighFrame của local player khi patch nạp muộn hoặc driver bị hủy lúc đổi cảnh. Callback khôi phục giữ return gốc, không đọc roster/transform và không đổi trạng thái di chuyển; tối đa một lần thử tạo driver mỗi giây. Driver còn sống thì không Find/AddComponent hoặc đọc thêm player. Chặn MzEnsure lồng nhau và ghi nhận luồng tạo driver; các đường render/aim/silent/vũ khí chỉ chạy trên luồng này. Đây là giảm đường tác động lên vòng cập nhật game, không chứng minh game đã gọi các hook từ luồng khác.
- Getter aiming khi silent tắt chỉ trả record gốc, không gọi các native getter bổ sung. Silent và renderer có guard riêng để callback native không lồng vào chính thao tác đang chạy. OnGUI vẫn có guard và trả lại GUI.color/contentColor/matrix trong finally. Aim/vũ khí chạy tối đa một lần mỗi Time.frameCount dù có nhiều lượt Repaint.
- ESP kiểm tra local player còn sống, local, active và đủ root/head trước khi đọc đối thủ. Chuyển sang observer, chết hoặc thiếu actor thì xóa hình cũ, không đọc skeleton đối thủ.
- **ESP và FOV mặc định tắt khi mở app**; bật trong menu sau khi vào trận. Khi cả hai tắt, renderer trả ngay mà không lấy match/camera/player. Texture vòng chỉ được dựng nếu chức năng tương ứng bật, chuẩn bị trước lúc phát lệnh vẽ.
- Sau ba ngoại lệ managed liên tiếp ở renderer, dừng ESP và hiện trạng thái trong tiêu đề. Chạm Bật ESP để thử lại chủ động. Lỗi getter của một người làm bỏ sample hiện tại; frame đã lỗi không được phát tiếp dưới dạng hình dở. Lỗi đầu tiên ghi stage + exception stack vào **Documents/Mizze-error.log**, chỉ ghi một lần; các frame thành công không ghi đĩa. Tên người chơi giữ dấu tiếng Việt, bỏ control/UTF-16 lỗi và không cắt giữa cặp surrogate.
- Giao diện/ESP không dùng Mesh/Material/Shader/GL/Graphics.DrawMeshNow, font OS hoặc GUIStyle.SetDefaultFont. Không giữ Player/Transform trong bộ đệm hình học. Xương dùng 11 điểm màn hình, chín bone bổ sung mỗi điểm chiếu một lần.
- Giữ lấy mẫu mỗi33ms, dùng66ms nếu sample tốn hơn8ms;192 lệnh, tối đa64 mục,12 người ESP đơn giản hoặc6 người với3D/xương/XYZ, dừng giữa người khi quá4ms. Các giới hạn này hạn chế công việc; chưa đo FPS/độ trễ thật trên iPhone.

**Ngoại lệ native/EXC_BAD_ACCESS, watchdog, jetsam hoặc game chủ động thoát không thể được chặn bằng các catch C# này.** Nếu vẫn thoát về Home: lấy báo cáo Free Fire/UnityFramework tương ứng trong iOS Cài đặt → Quyền riêng tư & Bảo mật → Phân tích & Cải tiến → Dữ liệu phân tích; JetsamEvent nếu không có báo cáo ứng dụng. File .ips và Mizze-error.log nếu tồn tại mới cho biết tầng nào lỗi. Log managed không có nghĩa là đã bắt được crash native.

## Giao diện và sử dụng

1. Giữ file cũ dự phòng. Thay patch trong Documents của đúng game bằng file mới rồi tắt hẳn, mở lại game. Loader của bản game gốc vẫn cần localConfig.json với testCodePatch=true; bytecode chạy sau bước kiểm tra này.
2. Ban đầu chỉ có nút tròn Mizze, kính tối bán trong suốt và viền bạc. Chạm để mở/đóng; kéo nút hoặc thanh tiêu đề để di chuyển. Menu 382×440, nút 80×80 theo kích thước thiết kế, tự scale theo màn hình.
3. KHÓA → Nhập khóa Mizze. Khóa hợp lệ mới cho phép ESP/aim chạy. Backend licensesV4 của repo 33e.
4. Bật ESP hoặc Vòng FOV khi cần; hai công tắc này không tự bật sau khi mở app. ESP có hai trang; AIM có aim đầu khi bắn, silent khi bắn, FOV, line mục tiêu và thanh chỉnh FOV/tầm; MÀU có 18 mẫu và ba thanh RGB cho ESP/FOV/máu, lưu khi chạm mẫu hoặc nhả thanh.

Panel dùng nhiều lớp bóng mềm, viền bạc, phản chiếu chuyển động và tab trắng dạng viên thuốc trượt theo lựa chọn. Nhãn ngắn, chữ chính sáng rõ; nút tròn dùng lòng kính tối72%. Khi mở/đóng, panel trượt nhẹ kết hợp độ đục, công tắc nảy mềm. Đây là hiệu ứng kính bằng GUI và nền ảnh đã làm mềm, không phải blur/refract ảnh game như UIKit Liquid Glass. Không thêm shader/GL/RenderTexture.

GIF **video-ezgif.com-video-to-gif-converter.gif** do người dùng cung cấp có15 frame, chu kỳ2,5s. Bản gốc và metadata nằm trong assets/. MizzeBackgroundData.cs nhúng15 PNG192×222 có góc alpha bo tròn vào chính .bytes: không cần dán GIF riêng. Nạp tối đa một texture mỗi Repaint, cách ít nhất40ms khi menu mở, LoadImage(markNonReadable:true), không mipmap. Sau nạp đủ, chỉ chọn texture đã cache theo timing170/160/170ms; đóng menu dừng clock/decode. Tổng RGBA texture2.557.440byte (~2,44MiB), chưa tính object/string/driver overhead. Lỗi decode hủy allocation dở, dừng retry và dùng nền kính tĩnh. API ImageConversion.LoadImage được đối chiếu với dump; không dùng DrawTextureWithTexCoords vì bản Unity đã strip API đó.

UI chỉ vẽ ở Repaint, lượt chạm vẫn xử lý công tắc/slider/kéo nhưng không vẽ. Cache texture nền, GUIStyle, ma trận scale và chuỗi giá trị slider; chỉ đổi khi cần. Animation dừng ở đích và ngừng cập nhật toggle ẩn khi cửa sổ đã đóng. Tiêu đề25, nội dung20, nhãn nhỏ16, thông báo18; chữ UTF-8 có dấu. Bản trước có nền trắng vì overload bo góc cần explicit color; bản hiện tại truyền tint trực tiếp.

Sáu hook: GameFacade.get_UIModelRole, Player.get_LastAimingInfoFromWeapon, SceneEditBoxSelectTool.OnGUI, NeedRunHighFrame, get_IsBeingCarried và UpdateKnockdownIsInCamera. GFHCADCHHEO để game xử lý gốc. NeedRunHighFrame giữ nguyên biểu thức boolean native rồi thử khôi phục driver chỉ với local player. Không thay thân OnUpdate/PostUpdate hoặc hook stealth. Driver dùng DontDestroyOnLoad; khi bị hủy thì tạo lại mà giữ công tắc/màu/vị trí menu. Lỗi managed khi vẽ panel được cách ly để nút Mizze vẫn có lượt vẽ riêng. Chưa xác nhận hết lỗi trên thiết bị.

## ESP và aim

ESP gồm khung2D/góc/3D, tên tối đa24 ký tự, máu CurHP/MaxHP, khoảng cách, xương, dấu đầu, XYZ và snapline với gốc dưới/giữa/trên. Lọc local/đồng đội/chết/inactive/mất transform/tọa độ không hợp lệ. Box2D là bốn rectangle trực tiếp; đầu nét chồng nửa độ dày để tránh khe. Khung góc và3D loại trừ nhau.

FOV và dấu đầu dùng hai texture RGBA bilinear không mipmap, dựng một lần rồi Apply(false,true). FOV vẽ một quad vuông không xoay; kiểm tra pixel360 góc để xác nhận vòng kín. Bán kính20–min(480,width/2−8,height/2−8), tầm50–500m. Slider/drawing/chọn mục tiêu dùng cùng giới hạn. Texture bị hủy được dựng lại; cấp phát dở được Destroy khi upload báo lỗi.

Aim đầu khi bắn chọn đầu gần tâm trong FOV/tầm, gọi SetAimRotation với LookRotation(head−camera.position). Silent sửa bản ghi native do getter trả về và dùng gốc bắn AimStartPostion; hoàn lại chỉ khi game còn giữ các giá trị do patch đặt. Hai aim loại trừ nhau, mặc định tắt. Kiểm tra logic offline không xác nhận hit/headlock hoặc việc server chấp nhận đường bắn.

## Tab SÚNG — chức năng client thử nghiệm

- **Bắn nhanh**: chọn1,5×/2×/3×; giảm FireIntervalScale từ giá trị gốc. Native của HBIBDMMOOOK nhân hệ số này vào khoảng cách giữa các phát bắn. Không đặt thời gian bằng0; hệ số đầu ra tối thiểu0,05. Giá trị bất thường/NaN bị bỏ qua.
- **Không nạp đạn**: bật PlayerAttributes.IsAmmoFree và ShootNoReload. Hai cờ thuộc hệ thống vũ khí thật; native có đọc ShootNoReload sau get_Attributes. Không gọi FullWeaponAmmo hoặc tự gửi packet.
- Hai chức năng mặc định tắt, chỉ áp dụng cho local player còn sống trong trận với khóa hợp lệ. Khi bật, kiểm tra tối đa10 lần/giây, chỉ ghi khi giá trị thay đổi. Buff native thay đổi tốc độ trở thành mốc mới, không chia lặp giá trị patch đã đặt.
- Tắt từng chức năng, chết, rời trận, đổi component hoặc khóa hết hiệu lực sẽ hoàn lại giá trị đã lưu nếu game vẫn giữ giá trị patch đặt; không ghi đè giá trị mới khác mà native đã thay. Bộ kiểm tra có các tình huống này.
- **Nút nổi Fakelag** trong tab Súng chỉ điều khiển hiển thị nút riêng. Bật trong menu → hiện **FL TẮT**, chưa kích hoạt tác dụng. Chạm nút nổi → **FL BẬT/TẮT**; kéo để đổi vị trí, kéo không đổi tác dụng. Đóng menu vẫn dùng nút; tắt công tắc trong menu sẽ dừng/hoàn vị trí còn thuộc patch, xóa nút và collider để game nhận chạm lại.
- Chọn100/150/250ms; tối đa16 địch, roster32, scan64. Giữ mốc hiển thị client, lưu vị trí mới và hoàn lại ở helper trước pha cập nhật. Chưa có làm trễ packet hoặc xác nhận server.
- **Sửa nguyên nhân không tác dụng của bản7b03d5a**: PostUpdate giữ IsLocalPlayer trongw21, địch nhảy từ0x569CEA4 tới0x569EC20, bỏ qua GFHCADCHHEO ở0x569EC08. Test cũ gọi trực tiếp hook này đã không tái hiện nhánh native. Bản mới dùng UpdateKnockdownIsInCamera tại cuối chung0x569EC60; địch thực hiện MzLagAfter trước return gốc. fakelag-native-flow-evidence.json lưu instruction/RVA/bytes để đối chiếu.
- Giữ hành vi gốc của camera knocked local: trạng thái8, cờ frustum, ID đầy đủ24byte, target lookup và kiểm tra target. Stub và test fixture chứa đủ hai uint, hai byte và ulong tại offset16; test chuyển ID có high64bits khác0 qua VM/native lookup. get_IsBeingCarried giữ return gốc; NeedRunHighFrame giữ bool và khôi phục menu. Không thay thân OnUpdate/PostUpdate hay bảng dispatch IFix chung.
- Bỏ local/đồng đội/chết/knocked/carried/inactive; kiểm tra ID, transform và epoch match/local. Tắt hoặc chỉnh mức giữ thì hoàn vị trí còn thuộc patch và bỏ tham chiếu. Hiệu chỉnh native mới thắng vị trí lưu; mất heartbeat500ms hoặc lỗi managed thì dừng. Dữ liệu/thứ tự cập nhật native ngoài mô hình test vẫn có thể gây văng; chưa xác nhận hết văng hoặc hiệu ứng trên iPhone.
- fakelag-presentation-evidence.json ghi hook/body/callsite và giới hạn thứ tự pha. Bài test gồm vòng đời nút nổi, hit region khi kéo/ẩn, đóng menu, key expiry, chuyển ID24byte, native correction, đổi ID/root/match/local, lỗi ghi, luồng phụ, guard gọi lồng và roster150 mục với all ESP+FOV/16 hold cố định. Pose cùng frame phục vụ truy vấn avatar LateUpdate; pha native lặp trong cùng frame chưa được trace trên thiết bị.


weapons-evidence.json ghi API/offset và điểm đọc native đã đối chiếu. Đây là xác nhận đường client, **chưa xác nhận bắn nhanh/không nạp được máy chủ chấp nhận hoặc hoạt động trong trận thật trên iPhone**. Không kết luận chỉ thay client sẽ vượt kiểm tra server.

## Khóa

protocol4, enabled, expiresAt theo giờ server, lock.until/message, binding.deviceHash/version/claimedAt. Claim dùng if-match:null_etag, phải đọc lại binding khớp mới xác thực. Timeout6s, refresh10s, lease tối đa30s; đổi key hủy request cũ. Test không gửi request đến database thật.

SimpleJSON thiếu field trả JSONLazyCreator Tag=None/IsNull=false: bản hiện tại nhận null/JSONNull/None là thiếu, kiểm tra kiểu dữ liệu trước khi đọc. Vẫn từ chối khóa hết hạn/bị khóa/máy khác và dữ liệu sai kiểu. Hash thiết bị C# dùng SystemInfo khác IDFV/Keychain của menu native33e; khóa đã gắn native cần admin gỡ binding cũ. Chỉ lưu hash key trong PlayerPrefs.

## Kiểm chứng

verify-declarations.cjs đối chiếu extern/field với dump TH cung cấp; bindings-evidence.json ghi khai báo. test.cjs chạy **bytecode cuối** bằng Tencent VM pinned5ba42eb8f63fe37134a3c78690f97d8425e13588 với opcode game. Unity/game/network là doubles offline, không thay thế crash log/thử iPhone.

Regression khôi phục menu gồm nạp patch trong trận trước callback sảnh, bảng return gốc, driver bị hủy, giữ trạng thái UI, 5.000 callback không tạo lại driver, lỗi AddComponent tạm thời và backoff, luồng phụ, lỗi ESP/panel vẫn vẽ nút Mizze, fakelag tắt không ghi vị trí hoặc cấp phát roster. Regression khác gồm GIF15 frame khác nhau/timing/pause/cache/decode fail, ESP cấm getter lazy/read-only node/missing và destroyed bone/sample backoff/circuit breaker, lobby/drag/animation/toggle/palette, trạng thái GUI, lọc và hình học ESP, danh sách150 mục với toàn bộ ESP bật, hủy đối tượng/getter lỗi, resource texture, cập nhật theo lịch, từng xương chỉ chiếu một lần, không dùng Mesh/GL/font-global, bộ đệm cố định, aim/silent, key binding/expiry/races, legacy state isolation, gọi lồng và luồng phụ, local actor chưa sẵn sàng, surrogate tên, circuit breaker và log lỗi. SVG xuất từ lệnh vẽ bytecode; không phải ảnh chụp game.

## Build

Workflow vẫn tạo artifact ESP Box dự phòng. Windows/.NET Framework và Node:

~~~text
node menu/prepare-runtime-test.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/build.cjs <Tencent InjectFix checkout pinned>
node menu/mizze/package.cjs
node menu/mizze/verify-declarations.cjs <TH dump Assembly directory>
node menu/mizze/test.cjs
~~~

Bindings chỉ là khai báo compile, body giả không được đưa vào patch; RuntimeApis.cs chỉ dùng test. CompilerHost.cs chọn sáu fix và helperMz*; package.cjs đổi magic/flag phù hợp game và giữ bytecode do compiler sinh.
