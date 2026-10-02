#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/task.h>
#import <mach/thread_act.h>
#import <mach/vm_map.h>
#import <pthread.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <dirent.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "KabraxHide.h"
#import "AntiREProtection.h"
#import "UIView+SecureView.h"
#import "InjectedLicenseController.h"
#import "InjectedOverlayOwnership.h"

// ═══════════════════════════════════════════════════════════════
// OVERLAY WINDOW
// ═══════════════════════════════════════════════════════════════
@interface MizzeOverlayWindow : UIWindow
@end
@implementation MizzeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
// Giả vờ là system window để UIKit không expose ra ngoài
+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_isSecure { return YES; }
@end

// ═══════════════════════════════════════════════════════════════
// SUPER STEALTH ENGINE v3
// ═══════════════════════════════════════════════════════════════
namespace SuperStealth {

// ─── Từ khoá cần ẩn ────────────────────────────────────────────
static const char* kKillwords[] = {
    "iOSViet", "iosviet", "Bugchi", "bugchi",
    "libsubsystem", "TweakInject", "TweakLoader",
    "MobileSubstrate", "substitute", "libhooker",
    "CydiaSubstrate", "ellekit", "ElleKit",
    "Dopamine", "dopamine", "palera1n", "unc0ver",
    nullptr
};

static bool ShouldHide(const char* s) {
    if (!s) return false;
    for (int i = 0; kKillwords[i]; ++i)
        if (strcasestr(s, kKillwords[i])) return true;
    return false;
}

// ═══════════════════════════════════════════════════════════════
// LAYER 1: DYLD IMAGE TABLE MANIPULATION
// ═══════════════════════════════════════════════════════════════

// Xoá entry thật khỏi dyld_all_image_infos
static void Layer1_HideFromAllImageInfos() {
    task_dyld_info_data_t dinfo;
    mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_DYLD_INFO,
                  (task_info_t)&dinfo, &cnt) != KERN_SUCCESS) return;

    auto* all = (struct dyld_all_image_infos*)(uintptr_t)dinfo.all_image_info_addr;
    if (!all || !all->infoArray || all->infoArrayCount == 0) return;

    uint32_t N = all->infoArrayCount;
    size_t bytes = N * sizeof(dyld_image_info);
    dyld_image_info* tmp = (dyld_image_info*)malloc(bytes);
    if (!tmp) return;
    memcpy(tmp, all->infoArray, bytes);

    uint32_t keep = 0;
    for (uint32_t i = 0; i < N; ++i) {
        if (!ShouldHide(all->infoArray[i].imageFilePath))
            tmp[keep++] = all->infoArray[i];
    }

    if (keep < N) {
        vm_protect(mach_task_self(), (vm_address_t)all->infoArray,
                   bytes, false, VM_PROT_READ|VM_PROT_WRITE);
        memcpy((void*)all->infoArray, tmp, keep * sizeof(dyld_image_info));
        all->infoArrayCount = keep;
        vm_protect(mach_task_self(), (vm_address_t)all->infoArray,
                   bytes, false, VM_PROT_READ);
    }
    free(tmp);
}

// ═══════════════════════════════════════════════════════════════
// LAYER 2: FUNCTION HOOKS (8 hàm)
// ═══════════════════════════════════════════════════════════════
typedef const char*  (*fn_dyld_img_name_t)(uint32_t);
typedef uint32_t     (*fn_dyld_img_count_t)(void);
typedef int          (*fn_sysctl_t)(int*,u_int,void*,size_t*,void*,size_t);
typedef FILE*        (*fn_fopen_t)(const char*, const char*);
typedef int          (*fn_stat_t)(const char*, struct stat*);
typedef int          (*fn_access_t)(const char*, int);
typedef DIR*         (*fn_opendir_t)(const char*);
typedef void*        (*fn_dlopen_t)(const char*, int);

static fn_dyld_img_name_t   _orig_img_name    = nullptr;
static fn_dyld_img_count_t  _orig_img_count   = nullptr;
static fn_sysctl_t          _orig_sysctl      = nullptr;
static fn_fopen_t           _orig_fopen       = nullptr;
static fn_stat_t            _orig_stat        = nullptr;
static fn_access_t          _orig_access      = nullptr;
static fn_opendir_t         _orig_opendir     = nullptr;
static fn_dlopen_t          _orig_dlopen      = nullptr;

static uint32_t _hiddenImageCount = 0;

// Hook: _dyld_get_image_name
__attribute__((visibility("hidden")))
static const char* h_img_name(uint32_t idx) {
    const char* n = _orig_img_name ? _orig_img_name(idx) : nullptr;
    return ShouldHide(n) ? nullptr : n;
}

// Hook: _dyld_image_count
__attribute__((visibility("hidden")))
static uint32_t h_img_count(void) {
    uint32_t r = _orig_img_count ? _orig_img_count() : _dyld_image_count();
    return r > _hiddenImageCount ? r - _hiddenImageCount : r;
}

// Hook: sysctl — xoá P_TRACED
__attribute__((visibility("hidden")))
static int h_sysctl(int* nm, u_int nlen, void* oldp, size_t* olen,
                    void* newp, size_t nlen2) {
    int r = _orig_sysctl ? _orig_sysctl(nm,nlen,oldp,olen,newp,nlen2)
                         : ::sysctl(nm,nlen,oldp,olen,newp,nlen2);
    if (nlen>=4 && nm[0]==CTL_KERN && nm[1]==KERN_PROC &&
        nm[2]==KERN_PROC_PID && oldp && olen && *olen>=sizeof(kinfo_proc)) {
        ((kinfo_proc*)oldp)->kp_proc.p_flag &= ~P_TRACED;
    }
    return r;
}

// Hook: fopen — chặn jailbreak path
static bool _IsBadPath(const char* p) {
    if (!p) return false;
    static const char* bad[] = {
        "/var/jb","/usr/lib/TweakInject","/usr/lib/TweakLoader",
        "/Library/MobileSubstrate","/usr/lib/substitute",
        "/usr/lib/libhooker","/usr/lib/ellekit",
        "/var/mobile/Library/Preferences/com.iosviet",
        nullptr
    };
    for (int i = 0; bad[i]; ++i)
        if (strstr(p, bad[i])) return true;
    return ShouldHide(p);
}

__attribute__((visibility("hidden")))
static FILE* h_fopen(const char* path, const char* mode) {
    if (_IsBadPath(path)) return nullptr;
    return _orig_fopen ? _orig_fopen(path,mode) : fopen(path,mode);
}

__attribute__((visibility("hidden")))
static int h_stat(const char* path, struct stat* st) {
    if (_IsBadPath(path)) { errno = ENOENT; return -1; }
    return _orig_stat ? _orig_stat(path,st) : ::stat(path,st);
}

__attribute__((visibility("hidden")))
static int h_access(const char* path, int mode) {
    if (_IsBadPath(path)) { errno = ENOENT; return -1; }
    return _orig_access ? _orig_access(path,mode) : ::access(path,mode);
}

__attribute__((visibility("hidden")))
static DIR* h_opendir(const char* path) {
    if (_IsBadPath(path)) { errno = ENOENT; return nullptr; }
    return _orig_opendir ? _orig_opendir(path) : opendir(path);
}

// Hook: dlopen — chặn load tweak khác vào scan ta
__attribute__((visibility("hidden")))
static void* h_dlopen(const char* path, int flags) {
    if (ShouldHide(path)) return nullptr;
    return _orig_dlopen ? _orig_dlopen(path,flags) : dlopen(path,flags);
}

// ─── Apply hooks qua MSHookFunction ────────────────────────────
static void Layer2_ApplyHooks() {
    typedef void (*MSHookFn_t)(void*,void*,void**);
    MSHookFn_t MSHook = (MSHookFn_t)dlsym(RTLD_DEFAULT,"MSHookFunction");
    if (!MSHook) return; // không có Substrate thì thôi

    struct { const char* sym; void* hook; void** orig; } hooks[] = {
        {"_dyld_get_image_name", (void*)h_img_name,  (void**)&_orig_img_name  },
        {"_dyld_image_count",    (void*)h_img_count,  (void**)&_orig_img_count  },
        {"sysctl",               (void*)h_sysctl,     (void**)&_orig_sysctl     },
        {"fopen",                (void*)h_fopen,      (void**)&_orig_fopen      },
        {"stat",                 (void*)h_stat,       (void**)&_orig_stat       },
        {"access",               (void*)h_access,     (void**)&_orig_access     },
        {"opendir",              (void*)h_opendir,    (void**)&_orig_opendir    },
        {"dlopen",               (void*)h_dlopen,     (void**)&_orig_dlopen     },
        {nullptr,nullptr,nullptr}
    };
    for (int i = 0; hooks[i].sym; ++i) {
        void* fn = dlsym(RTLD_DEFAULT, hooks[i].sym);
        if (fn) MSHook(fn, hooks[i].hook, hooks[i].orig);
        else    *hooks[i].orig = fn;
    }
}

// Đếm image cần ẩn
static void Layer2_CountHidden() {
    uint32_t total = _dyld_image_count(), h = 0;
    for (uint32_t i = 0; i < total; ++i)
        if (ShouldHide(_dyld_get_image_name(i))) ++h;
    _hiddenImageCount = h;
}

// ═══════════════════════════════════════════════════════════════
// LAYER 3: MACH-O HEADER OBFUSCATION
// ═══════════════════════════════════════════════════════════════
static void Layer3_ObfuscateMachO() {
    Dl_info di;
    if (!dladdr((void*)Layer3_ObfuscateMachO, &di) || !di.dli_fbase) return;
    const mach_header* mh = (const mach_header*)di.dli_fbase;
    bool is64 = (mh->magic == MH_MAGIC_64);
    uint32_t sz = is64 ? sizeof(mach_header_64) : sizeof(mach_header);
    const uint8_t* p = (const uint8_t*)mh + sz;

    for (uint32_t i = 0; i < mh->ncmds; ++i) {
        const load_command* lc = (const load_command*)p;
        if (lc->cmd == LC_ID_DYLIB) {
            dylib_command* dc = (dylib_command*)p;
            char* name = (char*)p + dc->dylib.name.offset;
            uintptr_t pg = (uintptr_t)name & ~(uintptr_t)4095;
            vm_protect(mach_task_self(), pg, 4096, false,
                       VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
            // Đổi tên thành system dylib vô hại
            const char* fake = "/usr/lib/libSystem.B.dylib";
            strlcpy(name, fake, strlen(name)+1);
            vm_protect(mach_task_self(), pg, 4096, false, VM_PROT_READ);
            break;
        }
        p += lc->cmdsize;
    }
}

// ═══════════════════════════════════════════════════════════════
// LAYER 4: THREAD NAME OBFUSCATION
// Đổi tên thread của chúng ta thành tên hệ thống để không bị nhận ra
// ═══════════════════════════════════════════════════════════════
static void Layer4_HideThreads() {
    // Lấy tất cả thread của process
    thread_act_array_t threads;
    mach_msg_type_number_t count;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS) return;

    // Thread của anti-cheat scanner sẽ thấy tên giống system thread
    // Đổi tên thread hiện tại thành "com.apple.network"
    pthread_setname_np("com.apple.network.monitor");

    for (mach_msg_type_number_t i = 0; i < count; ++i)
        mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  count * sizeof(thread_act_t));
}

// ═══════════════════════════════════════════════════════════════
// LAYER 5: UIAPPLICATION.WINDOWS HIDE
// Anti-cheat enumerate UIApplication.windows để tìm overlay
// ═══════════════════════════════════════════════════════════════
static UIWindow* _ourWindow = nil;

static void Layer5_HideWindowFromUI(UIWindow* window) {
    _ourWindow = window;
    // Swizzle [UIApplication windows] để lọc window của ta ra
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = [UIApplication class];
        SEL orig = @selector(windows);
        SEL swiz = @selector(_stealth_windows);

        Method origM = class_getInstanceMethod(cls, orig);
        IMP origIMP  = method_getImplementation(origM);

        IMP newIMP = imp_implementationWithBlock(^NSArray*(UIApplication* self) {
            // Gọi original
            NSArray* wins = ((NSArray*(*)(id,SEL))origIMP)(self, orig);
            // Lọc bỏ window của ta
            NSMutableArray* filtered = [NSMutableArray array];
            for (UIWindow* w in wins) {
                // Ẩn overlay window của ta
                if (w == _ourWindow) continue;
                if ([NSStringFromClass([w class])
                     rangeOfString:@"Mizze"].location != NSNotFound) continue;
                [filtered addObject:w];
            }
            return [filtered copy];
        });

        method_setImplementation(origM, newIMP);
    });
}

// Swizzle [UIApplication connectedScenes] tương tự
static void Layer5_HideWindowScenes() {
    if (@available(iOS 13.0, *)) {
        Class cls = [UIApplication class];
        SEL orig = @selector(connectedScenes);
        Method origM = class_getInstanceMethod(cls, orig);
        if (!origM) return;
        IMP origIMP = method_getImplementation(origM);

        IMP newIMP = imp_implementationWithBlock(^NSSet*(UIApplication* app) {
            NSSet* scenes = ((NSSet*(*)(id,SEL))origIMP)(app, orig);
            return scenes; // pass-through (scene level che khó hơn, bỏ qua)
        });
        (void)newIMP; // không cần swizzle scenes, chỉ windows là đủ
    }
}

// ═══════════════════════════════════════════════════════════════
// LAYER 6: MEMORY READ JITTER
// Thêm random delay vào vòng đọc memory để tránh pattern detection
// ═══════════════════════════════════════════════════════════════
static uint32_t _jitterSeed = 0;

// Gọi từ render loop mỗi frame để tính nextRenderDelay có jitter
double SuperStealthNextRenderDelay(double baseInterval) {
    // LCG random: tạo jitter ±20% của base interval
    _jitterSeed = _jitterSeed * 1664525u + 1013904223u;
    double jitter = ((double)(_jitterSeed & 0xFFFF) / 65535.0 - 0.5) * 0.4;
    double delay = baseInterval * (1.0 + jitter);
    // Clamp: không dưới 50ms, không trên 500ms
    if (delay < 0.050) delay = 0.050;
    if (delay > 0.500) delay = 0.500;
    return delay;
}

// ═══════════════════════════════════════════════════════════════
// LAYER 7: OBJECTIVE-C RUNTIME HIDE
// objc_copyImageNames() expose tên tất cả image có ObjC classes
// ═══════════════════════════════════════════════════════════════
static void Layer7_HideObjCImage() {
    // Không thể dễ dàng hook objc runtime ở level này
    // Thay vào đó: đổi tên class để trông như class hệ thống
    // Class của chúng ta đã có tên obfuscated (MizzeOverlayWindow, etc.)
    // Thêm prefix giả tạo để trông như UIKit internal
    // (Đây là best-effort, không thể xoá khỏi ObjC image list)
}

// ═══════════════════════════════════════════════════════════════
// LAYER 8: ANTI-SCREENSHOT / SCREEN RECORDING DETECTION
// Một số anti-cheat check xem screen có bị record không
// Ta fake UIScreen.isCaptured = NO bằng swizzle
// ═══════════════════════════════════════════════════════════════
static void Layer8_AntiScreenshotDetection() {
    if (@available(iOS 11.0, *)) {
        Class screenCls = [UIScreen class];
        SEL sel = @selector(isCaptured);
        Method m = class_getInstanceMethod(screenCls, sel);
        if (m) {
            method_setImplementation(m, imp_implementationWithBlock(
                ^BOOL(UIScreen* s) { return NO; }
            ));
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// LAYER 9: PT_DENY_ATTACH + EXCEPTION PORT CLEAR
// ═══════════════════════════════════════════════════════════════
static void Layer9_HardenProcess() {
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif
    // ptrace self-attach
    typedef int (*ptrace_t)(int,pid_t,caddr_t,int);
    ptrace_t pt = (ptrace_t)dlsym(RTLD_DEFAULT, "ptrace");
    if (pt) pt(PT_DENY_ATTACH, 0, nullptr, 0);

    // Xoá exception ports để debugger không attach được
    task_set_exception_ports(
        mach_task_self(),
        EXC_MASK_ALL, MACH_PORT_NULL,
        EXCEPTION_DEFAULT, THREAD_STATE_NONE
    );
}

// ═══════════════════════════════════════════════════════════════
// MASTER INIT
// ═══════════════════════════════════════════════════════════════
static bool _initialized = false;

void Init(UIWindow* overlayWindow = nullptr) {
    if (_initialized) return;
    _initialized = true;

    // Layer thứ tự quan trọng:
    Layer9_HardenProcess();       // Block debugger trước tiên
    Layer2_CountHidden();         // Đếm image cần ẩn
    Layer1_HideFromAllImageInfos(); // Xoá khỏi dyld table
    Layer3_ObfuscateMachO();      // Fake LC_ID_DYLIB name
    Layer2_ApplyHooks();          // Hook 8 system functions
    Layer4_HideThreads();         // Obfuscate thread names
    Layer8_AntiScreenshotDetection(); // Fake isCaptured = NO

    if (overlayWindow) {
        Layer5_HideWindowFromUI(overlayWindow);
    }
}

void InitWindow(UIWindow* window) {
    _ourWindow = window;
    Layer5_HideWindowFromUI(window);
}

// Re-hide sau khi game có thể đã re-scan
void PeriodicRehide() {
    Layer2_CountHidden();
    Layer1_HideFromAllImageInfos();
    Layer9_HardenProcess();
}

} // namespace SuperStealth

// ═══════════════════════════════════════════════════════════════
// OVERLAY SETUP
// ═══════════════════════════════════════════════════════════════
static void SetupInjectedOverlayMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = UIApplication.sharedApplication;
        if (MizzeOverlayOwner(app)) return;
        MizzeOverlayWindow *hudWindow = nil;
        @try {
            UIWindow *targetKeyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] &&
                        (scene.activationState == UISceneActivationStateForegroundActive ||
                         scene.activationState == UISceneActivationStateForegroundInactive)) {
                        UIWindowScene *ws = (UIWindowScene *)scene;
                        for (UIWindow *w in ws.windows) {
                            if (w.isKeyWindow) { targetKeyWindow = w; break; }
                        }
                    }
                }
            }
            if (!targetKeyWindow)
                targetKeyWindow = [UIApplication sharedApplication].keyWindow;
            if (!targetKeyWindow) {
                static NSUInteger retries = 0;
                if (++retries <= 15)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                                   dispatch_get_main_queue(),
                                   ^{ SetupInjectedOverlayMenu(); });
                return;
            }

            CGRect screenFrame = targetKeyWindow.bounds;
            if (@available(iOS 13.0, *)) {
                hudWindow = targetKeyWindow.windowScene
                    ? [[MizzeOverlayWindow alloc] initWithWindowScene:targetKeyWindow.windowScene]
                    : [[MizzeOverlayWindow alloc] initWithFrame:screenFrame];
            } else {
                hudWindow = [[MizzeOverlayWindow alloc] initWithFrame:screenFrame];
            }
            hudWindow.frame          = targetKeyWindow.frame;
            hudWindow.windowLevel    = UIWindowLevelNormal + 1.0; // level tự nhiên hơn
            hudWindow.userInteractionEnabled = YES;
            hudWindow.backgroundColor = [UIColor clearColor];

            if (!MizzeClaimOverlay(app, hudWindow)) return;

            // Ẩn window khỏi UIApplication.windows
            SuperStealth::InitWindow(hudWindow);

            InjectedLicenseController *root = [InjectedLicenseController new];
            root.gameWindow = targetKeyWindow;
            root.view.backgroundColor = UIColor.clearColor;
            hudWindow.rootViewController = root;
            root.view.frame = hudWindow.bounds;
            hudWindow.hidden = NO;

        } @catch (NSException *ex) {
            if (hudWindow) { hudWindow.hidden = YES; MizzeReleaseOverlay(app, hudWindow); }
        }
    });
}

// ═══════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════
static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // Init stealth ngay lập tức — trước tất cả
    SuperStealth::Init();

    // Init obfuscation pipeline
    ANTI_RE_INIT();

    // Re-hide định kỳ: 5s, 15s, 60s
    auto scheduleRehide = [](double delay) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            SuperStealth::PeriodicRehide();
            ANTI_RE_CHECK();
        });
    };
    scheduleRehide(5.0);
    scheduleRehide(15.0);
    scheduleRehide(60.0);

    // Setup UI
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification* _) { SetupInjectedOverlayMenu(); }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ SetupInjectedOverlayMenu(); });
}
