# Phân tích Assembly-CSharp-patch.bytes

Đầu vào: file trong workspace do người dùng cung cấp; chỉ đọc tĩnh.
Kích thước **112.164 byte**.
SHA-256: `765b52f8bc66ce86d1bdd446afb317c1bf0a59c5b5938769e432b2ecc0720e17`.

## Định dạng

Đây là bytecode IFix, không phải PE/DLL C# hay thư viện Mach-O.
Magic UInt64 little endian: `0x66a319b20db4a2cb`.
Bridge: `IFix.ILFixInterfaceBridge, Assembly-CSharp, Version=0.86.0.518`.
Đọc đủ tới cuối file: 72 kiểu, 7 thân hàm, 173 hàm ngoài, 150 chuỗi,
26 trường có sẵn, 0 trường static VM, 0 class mới và 6 hàm bị thay thế.
Bản này có một byte cờ `0` trước bảng fix; ý nghĩa cờ chưa được xác minh.

Các opcode đã đối chiếu với thứ tự trường enum `IFix.Core.Code` trong metadata
game 1.132.1 có SHA-256
`597e77fc1dd15bac9ff75215bd328d60c6d205f5fc4a7e32cec1b37d3cc2ea5d`.
Ví dụ: `StackSpace=57`, `Ldstr=16`, `CallExtern=175`, `Stloc=176`, `Ldc_I4=180`.
Thứ tự khác nguồn IFix công khai. Những record phụ cho hằng số/branch table
không được coi là opcode riêng.

## Cách tạo và hiện menu

| Hàm bị vá | ID thân hàm |
|---|---:|
| Player.get_LastAimingInfoFromWeapon | 0 |
| Player.get_IsMovableEntity | 1 |
| Player.IsReallyInStealth | 3 |
| PlayerNetwork.OnUpdate(float, float) | 4 |
| PlayerAttributes.GetScatterRate | 5 |
| SceneEditBoxSelectTool.OnGUI | 6 |

Thân hàm 1 gọi getter gốc `<>iFixBaseProxy_get_IsMovableEntity`, rồi tìm
`GameObject.Find("__esp_driver")`. Nếu thiếu, nó tạo GameObject, thêm component
`SceneEditBoxSelectTool` và gọi `DontDestroyOnLoad` (instruction 14–62).
Các thân hàm khác cũng chứa đường tạo driver. Đây là cơ chế khởi tạo khi các
hàm game được gọi, không phải constructor tự chạy chỉ vì file tồn tại.

Thân hàm 6 có 10.152 instruction. Nó kiểm tra `Event.current`, tên GameObject
phải là `__esp_driver`, rồi xử lý IMGUI. Các lời gọi vẽ đã xác nhận gồm
`GUI.get_matrix`, `GUI.set_matrix`, `GUI.set_color`, `GUI.DrawTexture`, `GUI.Label`.
Phần input dùng `Event.get_mousePosition`, `Rect.Contains`, `Event.Use` và delta.
Trạng thái được chứa trong các field sẵn có của SceneEditBoxSelectTool và
transform của driver. File cũng chứa phần vẽ ESP, đọc máu/đội/địch, tìm mục tiêu,
và các thay đổi gameplay riêng; nó không chỉ là giao diện.

## Documents: điều đã biết và chưa biết

File tham chiếu `Application.persistentDataPath`, `dataPath`, `streamingAssetsPath`,
`File.Exists`, `File.ReadAllText`, `Directory.GetDirectories`, cùng các chuỗi
`/Documents`, `/../Documents` và đường dẫn container iOS. Những lời gọi này nằm
trong **thân OnGUI đã nạp**, có liên quan tới luồng đọc token/cấu hình của mẫu.
Chúng không chứng minh bộ nạp game sẽ đọc chính bản vá từ Documents.

File không chứa callback của bộ nạp bản vá. Cần kiểm tra loader trong app/game
hoặc thử thực tế để xác nhận tên file, vị trí, thời điểm nạp và kiểm tra tương thích.
Chưa thực thi file mẫu hoặc thay file trong Documents của game.

## Nối với backend hiện có

Giao diện mới gọi hợp đồng `IMenuBackend`; adapter native đọc/ghi `ESPPrefs`,
gọi `ESPSyncFromPrefs`. Backend hiện có tiếp tục đọc dữ liệu game và xử lý chức
năng. Không gọi các setter gameplay hoặc danh sách địch của bytecode mẫu.
Phần native adapter cần cùng tiến trình; TIPA cần giao tiếp giữa hai tiến trình.
Hiện source và adapter là vật liệu tích hợp, chưa phải bản vá chạy được.

Tham khảo cấu trúc loader gốc:
[Tencent InjectFix FileVirtualMachineBuilder.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Builder/FileVirtualMachineBuilder.cs),
[Instruction.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Core/Instruction.cs),
[Quick start](https://github.com/Tencent/InjectFix/blob/master/Doc/quick_start_en.md).
