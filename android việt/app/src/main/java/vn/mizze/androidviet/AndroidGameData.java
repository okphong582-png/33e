package vn.mizze.androidviet;

import java.util.Set;
/** Menu availability follows fresh data from the root helper. */
final class AndroidGameData {
    static final String STATUS="Đang chờ dữ liệu chức năng";
    static final Set<String> ESP_KEYS=Set.of("ESPEnabled","CleanESP","Name","Health","Line","TracerLine","Box","Skeleton","HeadRedDot","Dis","Box3D","ESPMaxDistance","HealthYellowPercent","HealthRedPercent","BalancedRender");
    static final Set<String> SILENT_KEYS=Set.of("SilentAim","SilentFovSize","SilentMaxDistance");
    static final Set<String> AIM_KEYS=Set.of("AimHead","AimNeck","AimbotFire","AimbotScope","AimHipAlways","AimFireAndScope");
    static final Set<String> AIM_VISUAL_KEYS=Set.of("ShowFov","FovSize","AimTargetLine");
    static final Set<String> ACTIVE_KEYS=Set.of("SilentAim","ShootNoReload","FastFire","RunSpeed","ESPEnabled","AimHead","AimNeck","AimbotFire","AimbotScope","AimHipAlways","AimFireAndScope","AimTargetLine","ShowFov","TracerLine");
    static String description(){return BuildConfig.ROOT_EDITION?
        "Root 1.132.1 ARM64: ESP/Aim mở khi đọc được danh sách người chơi, xương và camera. Súng/Speed cần PlayerAttributes và quyền ghi. Xem trạng thái thật trong Thiết lập. AimKill, Ghost, FakeLag, Fly và Spin chưa có backend Android.":
        "No Root: APK độc lập chưa có quyền đọc hoặc sửa bộ nhớ Free Fire; chức năng game chưa khả dụng.";}
    static boolean attribute(String key){return key.equals("ShootNoReload")||key.equals("FastFire")||key.equals("RunSpeed")||key.equals("RunSpeedValue");}
    static boolean implemented(String key){return BuildConfig.ROOT_EDITION&&(attribute(key)||ESP_KEYS.contains(key)||AIM_KEYS.contains(key)||AIM_VISUAL_KEYS.contains(key)||SILENT_KEYS.contains(key));}
    static boolean configurableAim(String key){return BuildConfig.ROOT_EDITION&&(AIM_KEYS.contains(key)||AIM_VISUAL_KEYS.contains(key)||SILENT_KEYS.contains(key));}
    boolean available(String key){return BuildConfig.ROOT_EDITION&&(SILENT_KEYS.contains(key)?RootDataSession.silentReady():attribute(key)?RootDataSession.featuresReady():ESP_KEYS.contains(key)||AIM_VISUAL_KEYS.contains(key)?RootDataSession.playersReady():AIM_KEYS.contains(key)&&RootDataSession.aimReady());}
    boolean canReadPlayers(){return RootDataSession.playersReady();}
    boolean canApplyGameFeatures(){return RootDataSession.capabilityMask()!=0;}
}
