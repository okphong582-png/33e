package vn.mizze.androidviet;

/** Platform capability boundary. A rooted process map is not a decoded player snapshot. */
final class AndroidGameData {
    static final String STATUS = "Chưa có dữ liệu game";
    static String description() {
        return BuildConfig.ROOT_EDITION ?
            "Bản Root xin quyền Magisk/SuperSU. Chưa có profile dữ liệu Free Fire Android đã xác minh; Aim/ESP và chức năng game chưa khả dụng." :
            "Máy chưa root: APK độc lập không thể đọc hoặc sửa bộ nhớ Free Fire. Các chức năng game hiện chưa khả dụng.";
    }
    boolean canReadPlayers() { return false; }
    boolean canApplyGameFeatures() { return false; }
    // No iOS offsets, Mach ports, fabricated snapshots or successful no-op game toggles.
}
