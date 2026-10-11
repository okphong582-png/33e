# Mizze — C# IFix menu cho Free Fire TH iOS

Nguồn C# riêng biên dịch bằng Tencent InjectFix, mục tiêu TH iOS **1.132.1**, Assembly-CSharp 0.86.0.518. File xuất: Assembly-CSharp-patch.bytes, artifact Mizze-Assembly-CSharp-patch trong workflow Build CSharp IFix Menu.

## R9 đầy đủ — callback vẽ từ source cũ

Bản nền cũ bốn hook nằm ở menu/mizze-oldbase; bản này là biến thể đầy đủ giữ bảy hook và touch shield/FL. Không được dán hai file bytes từ hai biến thể cùng lúc. OnGUI được chuyển từ callback của source cũ và thêm phần gọi các mô-đun đã có.

legacy-baseline/ lưu bản sao nguyên trạng source cũ cùng hash. MzEnsure lấy lại chuỗi Find → tạo GameObject → GetComponent/AddComponent → DontDestroyOnLoad → gán driver của bản đó. Giữ khởi tạo mảng trước AddComponent, mở rộng15 thành18 công tắc cho các mục đã thêm. Không chặn khởi tạo theo clock hoặc thread; OnGUI nhận driver theo Event/tên như cũ và không gọi lại bootstrap. Chỉ giữ bảo vệ callback lồng để tránh vẽ trùng và hoàn trạng thái GUI khi lỗi.

package.cjs xuất đúng tên trường Mz… theo serializer cũ, bỏ namespace theo hash của các bản mới. Vì vậy **phải tắt hẳn tiến trình game trước khi thay file**, không nạp nóng giữa các phiên bản. Đây là khôi phục tương thích, chưa có bằng chứng rằng đổi tên trường là nguyên nhân duy nhất gây mất menu. verify-legacy-base.cjs kiểm tra baseline không đổi và trình tự khởi tạo/tên trường cuối.

Chuyển giao diện glass/GIF, bảng màu, các mục ESP/aim/vũ khí, nút FL và vùng chặn chạm từ R7; giữ kiểm soát RAM bên dưới. Logic real-stealth giữ biểu thức native đã đối chiếu, tránh hoàn lại shortcut IsInStealth của source cũ. Không thêm hook so với R7. Chưa xác nhận nạp/hiện menu trên iPhone.

### Bộ nhớ

Phép đo 300 Repaint trên Tencent VM/.NET: nhiều ESP cấp phát khoảng129 MB ở R6, nhưng chênh bộ nhớ giữ lại sau full GC bằng0 trong fixture. Không có bằng chứng từ phép đo này rằng một collection của patch giữ lại ngày càng nhiều object. IFix reflection/boxing tạo nhiều rác tạm; native game có đường tắt auto-GC trong trận. Chưa xác nhận chế độ này đang bật trên máy người dùng.

- Giảm Matrix4x4/GUI.color/native call trong lúc dựng command; gom lần đổi màu liên tiếp, giữ array192 cố định. allocation-baseline-r6.json và memory-allocation-evidence.json ghi phép đo trước/sau, không phải RAM iPhone.
- MzMemoryPulse đo mỗi giây từ callback cũ, sau khi menu đã vào OnGUI. **Không gọi GC trong OnGUI, render, silent, lag hoặc khởi tạo component**. ESP vẫn lấy mẫu33/66ms;30s chỉ là lịch ghi session log.
- Heap managed từ256 MiB và tăng48 MiB so với mốc sau GC thì gọi **COW.GcUtil.Collect(MemoryUtilCollect=13)** đã có trong game. Lần đo đầu ở heap cao cũng được xử lý. Native collector bật GC tạm thời nếu cần rồi trả lại chế độ game; memory-native-flow-evidence.json ghi RVA/calls. Không gọi trực tiếp GC.Collect hay ép auto-GC bật vĩnh viễn.
- Cooldown ít nhất4s sau khi thu hồi được rác. Nếu thu hồi dưới16 MiB, chờ30s, tránh full GC liên tục trên bộ nhớ còn sống. Chỉ đây là khoảng nghỉ GC, không phải lịch ESP. Chưa đo thời gian khựng GC trên iPhone.
- Nếu sau GC vẫn từ768 MiB và thu hồi dưới16 MiB: hoàn trạng thái aim/vũ khí/FL còn thuộc patch, xóa lệnh/nhãn, hủy texture nền/vòng của patch rồi tạm dừng các tác vụ nặng. **Nút Mizze và menu vẫn vẽ**, trạng thái báo Giảm tải · Bộ nhớ cao. Dưới512 MiB tự tiếp tục và cho nền động tải lại; không xóa công tắc người dùng. Đây là cơ chế giảm rủi ro, không đảm bảo chống jetsam do phần khác của game.
- Session log R9 thêm gcCount/gcPeak/gcBefore/gcAfter/gcFreed/gcFaults/memPaused. Các giá trị là heap managed toàn tiến trình, không gồm đầy đủ GPU/native RSS.
- Phát lại900 bước1s với tốc độ tăng7.506.272 byte/s từ log: fixture mô phỏng thu hồi rác giữ đỉnh dưới280 MiB. **Không phải chơi thật15 phút và không phải giới hạn RAM cam kết trên iPhone.**

Gói Documents gồm Assembly-CSharp-patch.bytes và localConfig.json testCodePatch=true. Tắt hẳn game trước khi thay cả hai. Mục tiêu TH iOS1.132.1; chưa xác nhận hiện menu/hết văng trên thiết bị.

## Giảm đọc ESP và chặn chạm xuyên menu

Bản này đã qua **2.444 kiểm tra offline** trên bytecode cuối và đối chiếu **242 khai báo** với dump TH iOS. Bài chạy dài đi qua 1.800 bước lấy mẫu trên timeline mô phỏng15phút; đây không phải chơi thật15phút trên iPhone.

- ESP chỉ kiểm tra local actor/xương khi đến lịch lấy mẫu33/66ms, thay vì lặp mỗi Repaint. Local chưa sẵn sàng chờ100ms; hình cũ quá250ms bị xóa. Camera/match/kích thước đổi thì bỏ sample và cache cũ.
- Cache tên/khoảng cách có64 ô, chỉ giữ ID/chuỗi/số. Tên đọc lại tối đa mỗi5s khi cache không va chạm; khoảng cách chỉ tạo chuỗi khi đổi mét nguyên. Xóa cache khi tắt ESP/FOV hoặc rời trận. Kiểm tra IsDead và ID trước HP/xương của đối thủ.
- Vùng nhận chạm dùng camera NGUI sẵn có, một panel vô hình và ba widget/collider theo menu, nút Mizze và nút FL. Khi đóng, collider menu tắt; kéo/đổi kích thước cập nhật vùng nhận chạm. Không tắt toàn bộ đầu vào game. Thao tác IMGUI bắt đầu trong menu được giữ đến lúc nhả; thao tác bắt đầu ngoài menu không kích hoạt nút khi nhả vào trong.
- touch-evidence.json ghi đường raycast native đã khảo sát. Bài kiểm tra xác nhận vị trí collider, đóng/mở, kéo, đổi camera/kích thước và không tạo thêm object sau1.000 lần đồng bộ. Chưa xác nhận thứ tự xử lý chạm hoặc đa chạm trên iPhone thật.
- Khi ESP hoặc fakelag đang bật, mỗi30s ghi **Documents/Mizze-session.log**, giữ12 dòng gần nhất bằng cách ghi đè. Log gồm thời gian, bộ nhớ managed, số lệnh, lỗi, số callback cuối pha fakelag và số lần giữ vị trí; không phải stack crash native. Không ghi file mỗi frame.

## Khôi phục menu trong trận

Các bản trước vẫn văng trên thiết bị người dùng. Chưa có crash stack nên chưa xác định được nguyên nhân native; những thay đổi dưới đây sửa các đường xung đột có thể chứng minh trong mã và bổ sung khả năng ghi lỗi, không phải xác nhận hết văng trên iPhone.

- **Đổi đường đọc ESP**: không gọi GetHeadTF/RootTransform hoặc getter xương có lazy initialization. Native GetHeadTF tăng GetCount; các getter root/xương có thể tìm node rồi ghi cache. ESP nay đọc 11 trường ITransformNode đã có, kiểm tra Transform còn sống và bỏ qua node chưa được game tạo. esp-cache-evidence.json ghi offset đã đối chiếu ARM64. Không tự tạo hoặc ghi cache xương của game. Chưa xác nhận đây là nguyên nhân văng trên thiết bị.
- **Lỗi lấy mẫu được xử lý riêng**: hủy toàn bộ sample dang dở, chờ500ms trước khi đọc lại; ba sample liên tiếp lỗi thì tạm dừng ESP đến khi người dùng bật lại. Bộ đếm này tách với lỗi vẽ. Lỗi vòng ngoài không còn bị nuốt im lặng.
- InjectFix NewFieldInfo giữ trạng thái theo tên trường. R9 trở về tên trường của source cũ, nên chỉ thay bytes khi game đã thoát hoàn toàn; bản này không hỗ trợ nạp nóng trên trạng thái của bản khác.
- **R8 giữ Player.IsReallyInStealth theo source cũ, giữ biểu thức gốc đã đối chiếu native**. Tạo driver qua UIModelRole ở sảnh, có đường khôi phục qua NeedRunHighFrame của local player khi patch nạp muộn hoặc driver bị hủy lúc đổi cảnh. Callback khôi phục giữ return gốc, không đọc roster/transform và không đổi trạng thái di chuyển; tối đa một lần thử tạo driver mỗi giây. Driver còn sống thì không Find/AddComponent hoặc đọc thêm player. Chặn MzEnsure lồng nhau; callback OnGUI hợp lệ xác định thread vẽ, các đường render/aim/silent/vũ khí chỉ chạy trên thread đã xác nhận. Đây là giảm đường tác động lên vòng cập nhật game, không chứng minh game đã gọi các hook từ luồng khác.
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

Bảy hook: Player.IsReallyInStealth, GameFacade.get_UIModelRole, Player.get_LastAimingInfoFromWeapon, SceneEditBoxSelectTool.OnGUI, NeedRunHighFrame, get_IsBeingCarried và UpdateKnockdownIsInCamera. GFHCADCHHEO để game xử lý gốc. NeedRunHighFrame giữ nguyên biểu thức boolean native rồi thử khôi phục driver chỉ với local player. Không thay thân OnUpdate/PostUpdate ; hook stealth giữ kiểm tra dictionary native. Driver dùng DontDestroyOnLoad; khi bị hủy thì tạo lại mà giữ công tắc/màu/vị trí menu. Lỗi managed khi vẽ panel được cách ly để nút Mizze vẫn có lượt vẽ riêng. Chưa xác nhận hết lỗi trên thiết bị.

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

Bindings chỉ là khai báo compile, body giả không được đưa vào patch; RuntimeApis.cs chỉ dùng test. CompilerHost.cs chọn bảy fix và helperMz*; package.cjs đổi magic/flag phù hợp game và giữ bytecode do compiler sinh.
