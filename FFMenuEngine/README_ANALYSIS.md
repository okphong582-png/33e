# BÁO CÁO PHÂN TÍCH VÀ THIẾT KẾ MENU FF LARA (iOS 17.0 - 18.7.1 & 26.0 - 26.0.1)

Thư mục phân tích & mã nguồn: `lara-main/FFMenuEngine/`

---

## 1. PHÂN TÍCH KIẾN TRÚC LARA-MAIN & DARKSWORD EXPLOIT

Lara khai thác lỗ hổng kernel socket UAF (**DarkSword Engine**) nhằm đạt được quyền đọc/ghi bộ nhớ Kernel (**Kernel Read/Write - kread64 / kwrite64**) trực tiếp trên các phiên bản iOS từ **17.0 đến 18.7.1** và **26.0 đến 26.0.1** (trừ chip A19/M5 có MIE/MTE).

### Các thành phần chính trong Lara:
1. **`darksword.m`**: Thiết lập primitive kernel socket leak, tìm kiếm Kernel Base, Kernel Slide, `t1sz_boot`, và định vị cấu trúc `our_proc`, `our_task`.
2. **`offsets.m`**: Chứa offset động của kernel theo từng phiên bản iOS cho các trường trong `proc_t`, `task`, `inpcb`, `socket`, v.v.
3. **`lara.swift`**: Điểm khởi chạy ứng dụng SwiftUI, gọi `init_offsets()`, `offsets_init()`, và `ds_run()`.

---

## 2. SO SÁNH PHƯƠNG PHÁP ĐỌC DỮ LIỆU: TIPA vs LARA (DARKSWORD)

| Tiêu chí | TIPA (TrollStore / Jailbreak) | LARA (DarkSword Exploit) |
| :--- | :--- | :--- |
| **Cơ chế hoạt động** | Sử dụng Entitlement `get-task-allow` hoặc `task_for_pid-allow` được cấp trực tiếp qua TrollStore TrustCache. | Khai thác lỗ hổng Kernel (Socket UAF) để lấy **Kernel Read/Write Primitive** (`ds_kread64` / `ds_kwrite64`). |
| **Yêu cầu iOS** | iOS 14.0 - 16.6.1 (TrollStore 1/2). | **iOS 17.0 - 18.7.1 & iOS 26.0 - 26.0.1** |
| **Cách đọc bộ nhớ** | Gọi trực tiếp hàm Mach API chuẩn: `task_for_pid()` lấy `task_port`, sau đó gọi `mach_vm_read_overwrite()`. | 1. Duyệt danh sách `proc_t` trong Kernel (`p_list.le_next`).<br>2. Tìm PID & `vm_map` của process mục tiêu (Free Fire).<br>3. Đọc dữ liệu qua `ds_kreadbuf()` từ Kernel Map / Physical Page Translation hoặc patch `task_port` / `p_csflags` vào IPC Table. |
| **Khả năng bị vá** | Bị Apple vá hoàn toàn trên iOS 17.0+. | Hoạt động được trên các phiên bản iOS 17-18 chưa vá DarkSword. |

---

## 3. PHƯƠNG PHÁP HIỂN THỊ ESP MỚI TRÊN MÀN HÌNH (OVERLAY ENGINE)

Trên iOS 17+, việc hiển thị ESP mà không cần Inject Dylib trực tiếp vào game được thực hiện thông qua **Standalone Invisible Overlay Window**:

### Cơ chế hoạt động:
1. **Window Layer Cực Cao**:
   - Tạo `UIWindow` tùy chỉnh với `windowLevel = UIWindowLevelStatusBar + 1000.0`.
   - Thiết lập `backgroundColor = clearColor` và `opaque = NO`.

2. **Xử lý Cảm ứng Xuyên Màn hình (Click-through / Touch Passthrough)**:
   - Ghi đè hàm `hitTest:withEvent:` trong `LaraESPOverlayWindow`:
   - Nếu vị trí chạm trùng với Menu Button hoặc Bảng điều khiển -> Trả về `UIView` để người dùng thao tác menu.
   - Nếu vị trí chạm vào vùng trống ESP -> Trả về `nil` để sự kiện cảm ứng truyền thẳng xuống game Free Fire bên dưới.

3. **Vòng lặp Vẽ Tốc độ cao (CADisplayLink)**:
   - Sử dụng `CADisplayLink` đồng bộ với tần số quét của màn hình (60Hz / 120Hz ProMotion trên iPhone Pro).
   - Đọc dữ liệu tọa độ 3D của nhân vật từ bộ nhớ game qua `LaraMemoryReader`.
   - Tính toán chiếu 3D sang 2D (**WorldToScreen Transformation**) thông qua View-Projection Matrix của Camera.
   - Vẽ khung 2D Box, Snapline, Thanh máu (Health Bar), Khoảng cách (Distance), FOV Circle & Crosshair bằng `CoreGraphics` / Metal.

---

## 4. CẤU TRÚC MÃ NGUỒN TRONG THƯ MỤC `FFMenuEngine`

- **`LaraMemoryReader.h` & `LaraMemoryReader.mm`**: Động cơ đọc bộ nhớ cross-process qua DarkSword Kernel primitives.
- **`LaraESPOverlayWindow.h` & `LaraESPOverlayWindow.mm`**: Cửa sổ Overlay hiển thị ESP xuyên màn hình.
- **`FFMenuController.h` & `FFMenuController.mm`**: Bảng menu cấu hình bật/tắt các tính năng ESP (Glassmorphic UI).
- **`LaraFFBridge.h` & `LaraFFBridge.mm`**: Cầu nối tích hợp giữa Lara Swift UI và FF Engine.

---

## 5. HƯỚNG DẪN TÍCH HỢP VÀ BUILD IPA

1. **Thêm thư mục `FFMenuEngine` vào dự án `lara.xcodeproj`**.
2. **Khởi chạy Engine từ `lara.swift` hoặc `ContentView.swift`**:
   ```swift
   import Foundation

   // Gọi khi ứng dụng lara khởi chạy thành công exploit
   LaraFFBridge.shared().startFFEngine()
   ```
3. **Build tệp IPA**:
   Sử dụng kịch bản build có sẵn trong `lara-main`:
   ```bash
   cd lara-main
   ./ipabuild.sh
   ```
