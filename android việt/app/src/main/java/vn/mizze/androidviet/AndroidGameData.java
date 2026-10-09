package vn.mizze.androidviet;

/** Platform capability boundary. A rooted process map is not a decoded player snapshot. */
final class AndroidGameData {
    static final String STATUS = "Chưa có dữ liệu game";
    static String description() {
        return BuildConfig.ROOT_EDITION ?
            "Root: bộ đọc tên thử nghiệm cho Free Fire 1.132.1 ARM64. Xem trạng thái trong Thiết lập. Aim/ESP và chức năng game chưa khả dụng." :
            "Máy chưa root: APK độc lập không thể đọc hoặc sửa bộ nhớ Free Fire. Các chức năng game hiện chưa khả dụng.";
    }
    boolean canReadPlayers() { return false; }
    boolean canApplyGameFeatures() { return false; }
    // No iOS offsets, Mach ports, fabricated snapshots or successful no-op game toggles.
}
