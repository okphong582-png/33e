# Menu C# ESP Box cho Free Fire TH iOS

Mã C# trong thư mục này **sinh bytecode IFix thực**, không đổi tên DLL thành
`.bytes`. Đầu ra: `dist/Assembly-CSharp-patch.bytes` và `SHA256SUMS.txt`.
Đây là bộ phát bytecode cho menu cụ thể, không phải trình biên dịch C# tổng quát.

## Chức năng

- Menu riêng luôn hiện trong trận khi driver được tạo. Không có điều kiện
  chạm 4 ngón, nút đóng hoặc cơ chế ẩn.
- Một công tắc **ESP BOX**, mặc định bật. Tắt chỉ dừng vẽ khung, menu vẫn hiện.
- Đọc danh sách nhân vật từ match, loại bản thân, đồng đội, người chết và
  GameObject không hoạt động. Lấy vị trí đầu/root và chiếu bằng camera game.
- Vẽ khung xanh cyan gồm 4 cạnh. Không vẽ điểm sau camera, NaN/Infinity,
  khung đảo chiều/quá lớn hoặc nằm hoàn toàn ngoài màn hình.
- Chỉ đọc thông tin nhân vật, không ghi vị trí, máu, vũ khí hay góc ngắm.

Mã nguồn C# tự sinh toàn bộ thân hàm IFix mới. File mẫu chỉ dùng để đối chiếu
metadata và cơ chế bootstrap; không đưa file mẫu/thân hàm menu cũ vào build,
không sửa binary của tác giả khác. Những chức năng khác của repo nằm ngoài
phạm vi bản này theo yêu cầu mới nhất.

## Build

GitHub → Actions → **Build CSharp IFix Menu**. Tải artifact
`Assembly-CSharp-patch-menu` sau khi job xanh. Workflow cũng chạy khi đẩy
thay đổi trong `menu/`. Không cần Unity Editor hoặc khóa ký iOS để sinh bytecode.

Build cục bộ trên Windows (.NET Framework 4.x):

```bat
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /warnaserror+ /optimize+ /out:menu\MenuBuilder.exe menu\Program.cs menu\Bindings.cs
menu\MenuBuilder.exe menu\dist
node menu/test-menu.cjs
```

`Bindings.cs` và `bindings.json` chứa bảng tham chiếu game 1.132.1, đối chiếu với
mẫu cũ SHA256
`765b52f8bc66ce86d1bdd446afb317c1bf0a59c5b5938769e432b2ecc0720e17`.
và mẫu mới do người dùng cung cấp SHA256
`bbf79061f89b7a54b495cb9760b164b1725266821f20f6d37aae77a9b9c98ec7`.
Các lời gọi ESP đọc tên/kiểu tham số từ bảng extern; không sao chép bytecode
gameplay của mẫu. Ba fix là `Player.get_IsMovableEntity`,
`Player.IsReallyInStealth` (hai đường tạo driver, giữ kết quả getter gốc),
và `SceneEditBoxSelectTool.OnGUI`. Hàm VM thứ tư tự viết xử lý ESP Box.
Trạng thái bật/tắt nằm ở `localScale.y` của GameObject riêng `__33e_menu_driver`.
Bootstrap khôi phục component nếu bị mất, không tạo nhiều driver.

`Program.cs`: `Bootstrap` tạo driver; `Menu` vẽ công tắc luôn hiện; `Boxes`
lọc/chiếu nhân vật; `BoxRect` vẽ 4 cạnh. Tham số độ dày là 2 pixel, tỉ lệ
chiều rộng/chiều cao là 0,5, giới hạn danh sách 128 nhân vật mỗi frame.

## Dùng trong game: điều kiện bắt buộc

Chưa xác nhận trên thiết bị. Dùng trên Free Fire TH iOS có loader IFix đọc
`Assembly-CSharp-patch.bytes` từ Documents như bản mẫu người dùng đã thử.
Sao lưu bản đang dùng, thay file bằng đầu ra build, thoát hẳn rồi mở lại game
và vào trận. Getter bootstrap phải được gọi trước khi có menu. Mục tiêu là
hiện trong trận; chưa bảo đảm ở sảnh. Không suy ra tương thích Android/MAX
hoặc phiên bản khác từ dữ liệu 1.132.1. Build/test thành công chưa xác nhận
bridge, loader và thực thi trên iPhone.

`test-menu.cjs` chạy các instruction đã sinh với Unity/game giả lập: hai đường
bootstrap, trả kết quả getter gốc, menu luôn hiện, bật/tắt, hình học 4 cạnh,
lọc mục tiêu, dữ liệu không hữu hạn, điểm sau camera, thiếu trận/camera,
giới hạn vòng lặp, không ghi player và khôi phục GUI color/matrix. Kiểm thử này
không kiểm tra IL2CPP stripping, bridge dispatch, lifecycle component, loader,
touch thực tế hoặc việc thực thi trên điện thoại.

Tham khảo định dạng VM:
[Tencent InjectFix VirtualMachine.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Core/VirtualMachine.cs)
và [FileVirtualMachineBuilder.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Builder/FileVirtualMachineBuilder.cs).
