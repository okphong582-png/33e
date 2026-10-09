package vn.mizze.androidviet;

/** Capabilities are tied to real backends, never enabled by a UI switch alone. */
final class AndroidGameData {
    static final String STATUS="Đang chờ dữ liệu chức năng";
    static String description(){return BuildConfig.ROOT_EDITION?
        "Root 1.132.1 ARM64: Không nạp đạn, Bắn nhanh và Speed mở khi đã xác minh PlayerAttributes/quyền ghi. Xem kết quả áp dụng trong Thiết lập. Aim/ESP chưa khả dụng.":
        "No Root: APK độc lập chưa có quyền đọc hoặc sửa bộ nhớ Free Fire; chức năng game chưa khả dụng.";}
    static boolean implemented(String key){return BuildConfig.ROOT_EDITION&&(key.equals("ShootNoReload")||key.equals("FastFire")||key.equals("RunSpeed")||key.equals("RunSpeedValue"));}
    boolean available(String key){return implemented(key)&&RootDataSession.featuresReady();}
    boolean canReadPlayers(){return false;}
    boolean canApplyGameFeatures(){return false;}
}
