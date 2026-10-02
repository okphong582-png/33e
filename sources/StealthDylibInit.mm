#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/loader.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/mman.h>
#import <mach/mach.h>
#import <mach/task.h>
#import <mach/vm_map.h>
#import <pthread.h>
#import <string.h>

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

@interface MizzeOverlayWindow : UIWindow
@end
@implementation MizzeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

// ═══════════════════════════════════════════════════════════════
// STEALTH ENGINE — ẨN DYLIB KHỎI ANTI-CHEAT
// ═══════════════════════════════════════════════════════════════
namespace StealthAntiCheat {

// ─── Danh sách từ khoá cần ẩn ─────────────────────────────────
static const char* kHideKeywords[] = {
    "iOSViet", "libiosviet", "Bugchi", "bugchi",
    "libsubsystem", "TweakInject", "TweakLoader",
    "CydiaSubstrate", "substitute", "libhooker",
    nullptr
};

static bool _NameShouldHide(const char* name) {
    if (!name) return false;
    for (int i = 0; kHideKeywords[i]; ++i) {
        if (strcasestr(name, kHideKeywords[i])) return true;
    }
    return false;
}

// ─── [1] Ẩn khỏi dyld all_image_infos (kỹ thuật thật) ─────────
// dyld lưu danh sách image trong cấu trúc dyld_all_image_infos
// Xóa entry của mình ra khỏi danh sách này → anti-cheat không thấy
static void _HideFromAllImageInfos() {
    task_dyld_info_data_t info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_DYLD_INFO,
                                 (task_info_t)&info, &count);
    if (kr != KERN_SUCCESS || !info.all_image_info_addr) return;

    struct dyld_all_image_infos* all =
        (struct dyld_all_image_infos*)(uintptr_t)info.all_image_info_addr;

    if (!all || all->infoArrayCount == 0 || !all->infoArray) return;

    // Tìm và xóa entry của dylib chúng ta
    uint32_t origCount = all->infoArrayCount;
    uint32_t writeIdx  = 0;

    // Tạo bản sao tạm (malloc để tránh lỗi khi modify in-place)
    size_t bytes = origCount * sizeof(dyld_image_info);
    dyld_image_info* tmp = (dyld_image_info*)malloc(bytes);
    if (!tmp) return;
    memcpy(tmp, all->infoArray, bytes);

    for (uint32_t i = 0; i < origCount; ++i) {
        const char* fname = all->infoArray[i].imageFilePath;
        if (_NameShouldHide(fname)) continue; // xóa entry này
        tmp[writeIdx++] = all->infoArray[i];
    }

    if (writeIdx < origCount) {
        // Ghi đè infoArray bằng bản đã lọc
        // Tháo write-protection nếu cần
        vm_protect(mach_task_self(), (vm_address_t)all->infoArray,
                   bytes, false, VM_PROT_READ | VM_PROT_WRITE);
        memcpy((void*)all->infoArray, tmp, writeIdx * sizeof(dyld_image_info));
        // Cập nhật count
        all->infoArrayCount = writeIdx;
        vm_protect(mach_task_self(), (vm_address_t)all->infoArray,
                   bytes, false, VM_PROT_READ);
    }
    free(tmp);
}

// ─── [2] Hook _dyld_get_image_name để trả về nil cho dylib ta ──
// Anti-cheat thường gọi _dyld_image_count() + _dyld_get_image_name()
// để liệt kê tất cả library → chặn tại đây
typedef const char* (*dyld_get_image_name_t)(uint32_t);
static dyld_get_image_name_t _orig_dyld_get_image_name = nullptr;

__attribute__((visibility("hidden")))
static const char* _hooked_dyld_get_image_name(uint32_t index) {
    const char* name = _orig_dyld_get_image_name
                     ? _orig_dyld_get_image_name(index)
                     : _dyld_get_image_name(index);
    if (_NameShouldHide(name)) return nullptr; // ẩn
    return name;
}

// ─── [3] Hook _dyld_image_count để giảm count ──────────────────
typedef uint32_t (*dyld_image_count_t)(void);
static dyld_image_count_t _orig_dyld_image_count = nullptr;
static uint32_t _hidden_image_count = 0; // số image cần ẩn

__attribute__((visibility("hidden")))
static uint32_t _hooked_dyld_image_count(void) {
    uint32_t real = _orig_dyld_image_count
                  ? _orig_dyld_image_count()
                  : _dyld_image_count();
    return (real > _hidden_image_count) ? (real - _hidden_image_count) : real;
}

// ─── [4] Hook sysctl để xóa P_TRACED flag ──────────────────────
typedef int (*sysctl_t)(int*, u_int, void*, size_t*, void*, size_t);
static sysctl_t _orig_sysctl = nullptr;

__attribute__((visibility("hidden")))
static int _hooked_sysctl(int* name, u_int namelen, void* oldp,
                          size_t* oldlenp, void* newp, size_t newlen) {
    int ret = _orig_sysctl
            ? _orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen)
            : ::sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    // Xóa P_TRACED flag để chống debug detection
    if (namelen >= 4 && name[0] == CTL_KERN && name[1] == KERN_PROC &&
        name[2] == KERN_PROC_PID && oldp && oldlenp &&
        *oldlenp >= sizeof(struct kinfo_proc)) {
        struct kinfo_proc* kp = (struct kinfo_proc*)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED;
    }
    return ret;
}

// ─── [5] Áp dụng hooks qua fishhook hoặc direct vtable patch ───
// Dùng MSHookFunction nếu có, fallback về direct pointer swap
static void _ApplyFunctionHooks() {
    // Lấy địa chỉ thật của các hàm cần hook
    void* fn_getname = (void*)dlsym(RTLD_DEFAULT, "_dyld_get_image_name");
    void* fn_count   = (void*)dlsym(RTLD_DEFAULT, "_dyld_image_count");
    void* fn_sysctl  = (void*)dlsym(RTLD_DEFAULT, "sysctl");

    // Cố gắng dùng MSHookFunction (Cydia Substrate)
    typedef void (*MSHookFunction_t)(void*, void*, void**);
    MSHookFunction_t MSHookFn = (MSHookFunction_t)
        dlsym(RTLD_DEFAULT, "MSHookFunction");

    if (MSHookFn) {
        if (fn_getname)
            MSHookFn(fn_getname, (void*)_hooked_dyld_get_image_name,
                     (void**)&_orig_dyld_get_image_name);
        if (fn_count)
            MSHookFn(fn_count, (void*)_hooked_dyld_image_count,
                     (void**)&_orig_dyld_image_count);
        if (fn_sysctl)
            MSHookFn(fn_sysctl, (void*)_hooked_sysctl,
                     (void**)&_orig_sysctl);
    } else {
        // Fallback: lưu originals để hooked version gọi lại
        _orig_dyld_get_image_name = (dyld_get_image_name_t)fn_getname;
        _orig_dyld_image_count    = (dyld_image_count_t)fn_count;
        _orig_sysctl              = (sysctl_t)fn_sysctl;
    }
}

// ─── [6] Đếm số image cần ẩn (để giảm count) ──────────────────
static void _CountHiddenImages() {
    uint32_t total = _dyld_image_count();
    uint32_t hidden = 0;
    for (uint32_t i = 0; i < total; ++i) {
        const char* n = _dyld_get_image_name(i);
        if (_NameShouldHide(n)) ++hidden;
    }
    _hidden_image_count = hidden;
}

// ─── [7] Xóa LC_ID_DYLIB name trong Mach-O header của mình ─────
// Đổi tên dylib trong load command thành tên hệ thống vô hại
static void _ObfuscateMachOHeader() {
    // Tìm header của chính mình qua dladdr
    Dl_info info;
    if (!dladdr((void*)_ObfuscateMachOHeader, &info)) return;
    const struct mach_header* mh = (const struct mach_header*)info.dli_fbase;
    if (!mh) return;

    bool is64 = (mh->magic == MH_MAGIC_64);
    uint32_t offset = is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
    const uint8_t* cmds = (const uint8_t*)mh + offset;

    for (uint32_t i = 0; i < mh->ncmds; ++i) {
        const struct load_command* lc = (const struct load_command*)cmds;
        if (lc->cmd == LC_ID_DYLIB) {
            struct dylib_command* dc = (struct dylib_command*)cmds;
            char* namePtr = (char*)cmds + dc->dylib.name.offset;
            // Tháo write-protection
            uintptr_t pageAddr = (uintptr_t)namePtr & ~(uintptr_t)(4096 - 1);
            vm_protect(mach_task_self(), pageAddr, 4096, false,
                       VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            // Đổi tên thành tên giả vô hại
            const char* fakeName = "/usr/lib/libnetwork.dylib";
            strlcpy(namePtr, fakeName, strlen(namePtr) + 1);
            vm_protect(mach_task_self(), pageAddr, 4096, false, VM_PROT_READ);
            break;
        }
        cmds += lc->cmdsize;
    }
}

// ─── [8] Anti-jailbreak detection bypass ──────────────────────
// Một số anti-cheat kiểm tra /var/jb, /usr/lib/TweakInject...
// Chặn fopen/access cho các path nguy hiểm
typedef FILE* (*fopen_t)(const char*, const char*);
static fopen_t _orig_fopen = nullptr;

static const char* kSuspiciousPaths[] = {
    "/var/jb", "/usr/lib/TweakInject", "/usr/lib/TweakLoader",
    "/Library/MobileSubstrate", "/usr/lib/substitute",
    "/usr/lib/libhooker", nullptr
};

static bool _IsSuspiciousPath(const char* path) {
    if (!path) return false;
    for (int i = 0; kSuspiciousPaths[i]; ++i)
        if (strstr(path, kSuspiciousPaths[i])) return true;
    return false;
}

__attribute__((visibility("hidden")))
static FILE* _hooked_fopen(const char* path, const char* mode) {
    if (_IsSuspiciousPath(path)) return nullptr; // giả vờ không tìm thấy
    return _orig_fopen ? _orig_fopen(path, mode) : fopen(path, mode);
}

// ─── API chính ─────────────────────────────────────────────────
__attribute__((noinline))
static void ApplyStealthProtections() {
    // Đếm trước khi hook
    _CountHiddenImages();
    // Xóa khỏi dyld image list nội bộ
    _HideFromAllImageInfos();
    // Obfuscate Mach-O header
    _ObfuscateMachOHeader();
    // Hook các hàm truy vấn
    _ApplyFunctionHooks();

    // Hook fopen để ẩn jailbreak paths
    void* fn_fopen = (void*)dlsym(RTLD_DEFAULT, "fopen");
    typedef void (*MSHookFunction_t)(void*, void*, void**);
    MSHookFunction_t MSHookFn = (MSHookFunction_t)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (MSHookFn && fn_fopen)
        MSHookFn(fn_fopen, (void*)_hooked_fopen, (void**)&_orig_fopen);
    else
        _orig_fopen = (fopen_t)fn_fopen;

    // PT_DENY_ATTACH tự block debugger
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif
    typedef int (*ptrace_t)(int, pid_t, caddr_t, int);
    ptrace_t pt = (ptrace_t)dlsym(RTLD_DEFAULT, "ptrace");
    if (pt) pt(PT_DENY_ATTACH, 0, nullptr, 0);
}

} // namespace StealthAntiCheat

// ═══════════════════════════════════════════════════════════════
// OVERLAY WINDOW SETUP
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
                                   dispatch_get_main_queue(), ^{ SetupInjectedOverlayMenu(); });
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
            hudWindow.frame = targetKeyWindow.frame;
            hudWindow.windowLevel = UIWindowLevelStatusBar + 100.0;
            hudWindow.userInteractionEnabled = YES;
            hudWindow.backgroundColor = [UIColor clearColor];

            if (!MizzeClaimOverlay(app, hudWindow)) return;

            InjectedLicenseController *root = [InjectedLicenseController new];
            root.gameWindow = targetKeyWindow;
            root.view.backgroundColor = UIColor.clearColor;
            hudWindow.rootViewController = root;
            root.view.frame = hudWindow.bounds;
            hudWindow.hidden = NO;

        } @catch (NSException *ex) {
            hudWindow.hidden = YES;
            MizzeReleaseOverlay(app, hudWindow);
        }
    });
}

// ═══════════════════════════════════════════════════════════════
// ENTRY POINT — chạy sớm nhất có thể
// ═══════════════════════════════════════════════════════════════
static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // 1. Ẩn dylib khỏi anti-cheat TRƯỚC MỌI THỨ KHÁC
    StealthAntiCheat::ApplyStealthProtections();

    // 2. Khởi tạo pipeline obfuscation
    ANTI_RE_INIT();

    // 3. Kiểm tra định kỳ (mỗi 30 giây, không quá thường xuyên để tránh overhead)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // Re-hide sau khi dyld có thể đã reload
        StealthAntiCheat::_HideFromAllImageInfos();
        ANTI_RE_CHECK();

        // Tiếp tục check định kỳ
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            StealthAntiCheat::_HideFromAllImageInfos();
        });
    });

    // 4. Khởi tạo overlay UI
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
        SetupInjectedOverlayMenu();
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SetupInjectedOverlayMenu();
    });
}
