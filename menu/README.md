# Menu C# / IFix (thử nghiệm)

Mã C# trong thư mục này **sinh bytecode IFix thực**, không đổi tên DLL thành
`.bytes`. Đầu ra: `dist/Assembly-CSharp-patch.bytes` và `SHA256SUMS.txt`.
Đây là bộ phát bytecode cho menu cụ thể, không phải trình biên dịch C# tổng quát.

## Trạng thái chức năng

- Mở giao diện mặc định khi driver được tạo.
- Nút HIDE thu gọn, nút OPEN mở lại.
- Công tắc DEMO đổi trạng thái giao diện. **Chưa gắn chức năng gameplay.**
- Cần danh sách chức năng và phiên bản game từ người dùng để triển khai tiếp.

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

`Bindings.cs` và `bindings.json` chỉ chứa bảng tham chiếu cần dùng, trích từ
mẫu 1.132.1 SHA256
`765b52f8bc66ce86d1bdd446afb317c1bf0a59c5b5938769e432b2ecc0720e17`.
Không sao chép phần gameplay của mẫu. Hai fix là `Player.get_IsMovableEntity`
(gọi getter gốc, tạo driver một lần) và `SceneEditBoxSelectTool.OnGUI` (vẽ menu).
Trạng thái UI nằm ở localScale của GameObject riêng `__33e_menu_driver`.

## Dùng trong game: điều kiện bắt buộc

Chưa xác nhận trên thiết bị. Chỉ chép file vào Documents **không bảo đảm** game
sẽ nạp. App phải có loader IFix đọc đúng file và runtime/bridge tương thích;
getter bootstrap phải được gọi trước khi có menu. Do đó chưa bảo đảm menu xuất
hiện ngay ở màn hình khởi động. Không dùng bản này thay cho bản vá cần thiết khác
của game mà chưa sao lưu. Không suy ra tương thích Free Fire MAX/bản khác từ mẫu.

`test-menu.cjs` mô phỏng các instruction được phát và lời gọi Unity để kiểm tra
nhánh, stack, tạo driver, trả kết quả getter gốc, mở/ẩn và công tắc demo. Kiểm thử
này không kiểm tra IL2CPP stripping, bridge dispatch, lifecycle component, loader,
touch thực tế hoặc việc thực thi trên điện thoại.

Tham khảo định dạng VM:
[Tencent InjectFix VirtualMachine.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Core/VirtualMachine.cs)
và [FileVirtualMachineBuilder.cs](https://github.com/Tencent/InjectFix/blob/master/Source/VSProj/Src/Builder/FileVirtualMachineBuilder.cs).
