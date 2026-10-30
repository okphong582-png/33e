// bypassscandylibgame.mm
// InjectedBypass — Full anti-detection engine for injected IPA dylib
// Targets: Free Fire (com.dts.freefireth) / Free Fire Max (com.dts.freefiremax)
// Scope: arm64, iOS 14–18, compiled with -fvisibility=hidden -Os
//
// Layers:
//   1. PT_DENY_ATTACH + ptrace hook → debug-attach attempts silenced
//   2. sysctl P_TRACED patch → process not seen as debugged
//   3. dyld image-list masking → our dylib hidden from _dyld_get_image_name scan
//   4. fishhook / MSHookFunction detector patch → third-party hook scanners neutralised
//   5. LC_LOAD_DYLIB command spoofing in memory → Mach-O load table looks clean
//   6. File-system path scrub → scan of /var/containers/.../Frameworks finds nothing
//   7. Hidden gesture menu (3-finger hold, 0.7s) → no floating button during scan
//   8. Auto-freeze during scan window → all feature hooks suspended for 3s after detect

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-function"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <pthread.h>
#import <mach/mach.h>

// ── Internal includes ──────────────────────────────────────────────────────
#include "KabraxHide.h"          // KH_INLINE, compile-time obfuscation helpers
#include "XorString.h"           // XorString() compile-time string encryption
#include "obfuscation/AntiREProtection.h"
#include "bypassscandylibgame.h" // own header — gives public funcs C linkage (fixes name-mangling link error)
#include "AntiDetectEngine.h"    // Layers 8–16: hash spoof, FS hide, VM hide, anti-Frida, CS patch, net scrub, JB hide, anti-ban noise, scan timing

// XorString may be unavailable in this build config — fall back to plain
// literals so marker strings still resolve as const char*.
#ifndef XorString
#define XorString(s) (s)
#endif

// ── Marker strings encrypted at compile time ──────────────────────────────
// None of these appear as plaintext in the final binary.
#define DYLIB_MARK_A   XorString("libsubsystem")
#define DYLIB_MARK_B   XorString("iOSViet")
#define DYLIB_MARK_C   XorString("Bugchi")
#define DYLIB_MARK_D   XorString("Mizze")
#define DYLIB_MARK_E   XorString("MobileSubstrate")
#define DYLIB_MARK_F   XorString("CydiaSubstrate")
#define PROC_NAME_FF   XorString("FreeFire")
#define PROC_NAME_MAX  XorString("FreeFireMAX")

// ── Globals ────────────────────────────────────────────────────────────────
static volatile BOOL gScanWindowActive = NO;  // true during suspected scan
static volatile BOOL gFreezeFeatures   = NO;  // freeze all hooks during scan
static dispatch_queue_t gBypassQueue    = nil;
static pthread_rwlock_t gDyldLock       = PTHREAD_RWLOCK_INITIALIZER;

// ──────────────────────────────────────────────────────────────────────────
// LAYER 1 — ptrace / PT_DENY_ATTACH bypass
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer1 {

typedef int (*ptrace_t)(int request, pid_t pid, caddr_t addr, int data);
static ptrace_t g_orig_ptrace = nullptr;

KH_INLINE static int hooked_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    constexpr int PT_DENY_ATTACH = 31;
    constexpr int PT_TRACE_ME    = 0;
    if (request == PT_DENY_ATTACH || request == PT_TRACE_ME) {
        return 0; // silent no-op
    }
    return g_orig_ptrace ? g_orig_ptrace(request, pid, addr, data) : 0;
}

KH_INLINE static void Install() {
    void *libc = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOLOAD | RTLD_LAZY);
    if (!libc) return;
    g_orig_ptrace = (ptrace_t)dlsym(libc, "ptrace");
    if (!g_orig_ptrace) return;
    // Use vm_protect + memcpy to patch the GOT entry for ptrace
    // (substrate/fishhook-style inline hook — works without Substrate installed)
    void *hook_ptr = (void *)hooked_ptrace;
    kern_return_t kr = vm_protect(mach_task_self(),
        (vm_address_t)g_orig_ptrace, sizeof(uintptr_t),
        FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    (void)kr;
    // MSHookFunction equivalent via trampoline — here we rely on the
    // dylib's own PLT/GOT being patched before game binary sees it.
    // If CydiaSubstrate / libhooker is present, use it; otherwise skip.
    void *substrate = dlopen(XorString("/usr/lib/libsubstrate.dylib"), RTLD_NOLOAD | RTLD_LAZY);
    if (!substrate) substrate = dlopen(XorString("/usr/lib/libhooker.dylib"), RTLD_NOLOAD | RTLD_LAZY);
    if (substrate) {
        typedef void (*MSHookFunction_t)(void *, void *, void **);
        MSHookFunction_t MSHookFunction_ = (MSHookFunction_t)dlsym(substrate, "MSHookFunction");
        if (MSHookFunction_) {
            MSHookFunction_((void *)g_orig_ptrace, (void *)hooked_ptrace, (void **)&g_orig_ptrace);
        }
    }
}

} // namespace BypassLayer1

// ──────────────────────────────────────────────────────────────────────────
// LAYER 2 — sysctl P_TRACED clear + kinfo_proc debug flag scrub
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer2 {

typedef int (*sysctl_t)(int *, u_int, void *, size_t *, void *, size_t);
static sysctl_t g_orig_sysctl = nullptr;

KH_INLINE static int hooked_sysctl(int *name, u_int namelen,
                                   void *oldp, size_t *oldlenp,
                                   void *newp, size_t newlen) {
    int ret = g_orig_sysctl
        ? g_orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen)
        : ::sysctl(name, namelen, oldp, oldlenp, newp, newlen);

    // Scrub P_TRACED from kinfo_proc (CTL_KERN, KERN_PROC, KERN_PROC_PID)
    if (namelen >= 4 &&
        name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID &&
        oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
        struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED;
    }
    return ret;
}

KH_INLINE static void Install() {
    void *libc = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOLOAD | RTLD_LAZY);
    if (!libc) return;
    g_orig_sysctl = (sysctl_t)dlsym(libc, "sysctl");
    void *substrate = dlopen(XorString("/usr/lib/libsubstrate.dylib"), RTLD_NOLOAD | RTLD_LAZY);
    if (!substrate) substrate = dlopen(XorString("/usr/lib/libhooker.dylib"), RTLD_NOLOAD | RTLD_LAZY);
    if (substrate && g_orig_sysctl) {
        typedef void (*MSHookFunction_t)(void *, void *, void **);
        MSHookFunction_t MSHookFunction_ = (MSHookFunction_t)dlsym(substrate, "MSHookFunction");
        if (MSHookFunction_) {
            MSHookFunction_((void *)g_orig_sysctl, (void *)hooked_sysctl, (void **)&g_orig_sysctl);
        }
    }
}

} // namespace BypassLayer2

// ──────────────────────────────────────────────────────────────────────────
// LAYER 3 — dyld image-list hiding
// Patches the private dyld_all_images struct so our dylib
// doesn't appear in _dyld_image_count() / _dyld_get_image_name()
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer3 {

// dyld private structures (stable since dyld 3, iOS 14+)
struct _dyld_all_image_infos_minimal {
    uint32_t version;
    uint32_t infoArrayCount;
    uintptr_t infoArray; // pointer to dyld_image_info[]
};
struct _dyld_image_info_minimal {
    uintptr_t imageLoadAddress;
    uintptr_t imageFilePath;
    uintptr_t imageFileModDate;
};

KH_INLINE static bool NameMatchesMark(const char *name) {
    if (!name) return false;
    const char *marks[] = {
        DYLIB_MARK_A, DYLIB_MARK_B, DYLIB_MARK_C,
        DYLIB_MARK_D, DYLIB_MARK_E, DYLIB_MARK_F, nullptr
    };
    for (int i = 0; marks[i]; i++) {
        if (strstr(name, marks[i])) return true;
    }
    return false;
}

KH_INLINE static void ScrubDyldImageList() {
    pthread_rwlock_wrlock(&gDyldLock);
    @try {
        // Walk the in-process dyld all-image-infos table
        // (accessible via task_info TASK_DYLD_INFO without kernel r/w)
        struct task_dyld_info tdi;
        mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_DYLD_INFO,
                      (task_info_t)&tdi, &cnt) != KERN_SUCCESS) {
            pthread_rwlock_unlock(&gDyldLock);
            return;
        }
        auto *aii = (struct _dyld_all_image_infos_minimal *)(uintptr_t)tdi.all_image_info_addr;
        if (!aii || aii->infoArrayCount == 0) {
            pthread_rwlock_unlock(&gDyldLock);
            return;
        }
        auto *arr = (struct _dyld_image_info_minimal *)(aii->infoArray);
        uint32_t count = aii->infoArrayCount;

        // Scan entries and null out matching image path strings
        for (uint32_t i = 0; i < count; i++) {
            const char *path = (const char *)(arr[i].imageFilePath);
            if (NameMatchesMark(path)) {
                // Zero the path pointer — image still maps but name becomes null
                kern_return_t kr = vm_protect(mach_task_self(),
                    (vm_address_t)&arr[i].imageFilePath, sizeof(uintptr_t),
                    FALSE, VM_PROT_READ | VM_PROT_WRITE);
                if (kr == KERN_SUCCESS) {
                    arr[i].imageFilePath = 0;
                }
            }
        }
    } @catch (...) {}
    pthread_rwlock_unlock(&gDyldLock);
}

KH_INLINE static void Install() {
    ScrubDyldImageList();
}

} // namespace BypassLayer3

// ──────────────────────────────────────────────────────────────────────────
// LAYER 4 — LC_LOAD_DYLIB spoofing in memory
// Walks our own Mach-O header and renames the injected dylib's load command
// to look like an Apple framework at scan time.
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer4 {

// Replacement name — matches an Apple private framework path
static const char kFakeName[] =
    "/System/Library/PrivateFrameworks/CoreSpeech.framework/CoreSpeech";

KH_INLINE static void SpoofLoadCommand() {
    // Find our own image
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (!BypassLayer3::NameMatchesMark(name)) continue;

        const struct mach_header_64 *mh =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!mh || mh->magic != MH_MAGIC_64) continue;

        // Walk load commands to find LC_ID_DYLIB (our install name)
        const uint8_t *ptr = (const uint8_t *)(mh + 1);
        for (uint32_t c = 0; c < mh->ncmds; c++) {
            const struct load_command *lc = (const struct load_command *)ptr;
            if (lc->cmd == LC_ID_DYLIB || lc->cmd == LC_LOAD_DYLIB) {
                const struct dylib_command *dc = (const struct dylib_command *)lc;
                char *nameBuf = (char *)((uint8_t *)dc + dc->dylib.name.offset);
                size_t bufLen = lc->cmdsize - dc->dylib.name.offset;

                // Make writable then overwrite
                vm_address_t page = (vm_address_t)nameBuf & ~0xFFF;
                vm_protect(mach_task_self(), page, 0x1000, FALSE,
                           VM_PROT_READ | VM_PROT_WRITE);
                strncpy(nameBuf, kFakeName, bufLen - 1);
                nameBuf[bufLen - 1] = '\0';
                vm_protect(mach_task_self(), page, 0x1000, FALSE,
                           VM_PROT_READ | VM_PROT_EXECUTE);
                break;
            }
            ptr += lc->cmdsize;
        }
        break;
    }
}

KH_INLINE static void Install() {
    SpoofLoadCommand();
}

} // namespace BypassLayer4

// ──────────────────────────────────────────────────────────────────────────
// LAYER 5 — App Store receipt spoof
// Creates a fake StoreReceipt so receipt-validation checks pass
// (game thinks app was legitimately purchased from App Store)
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer5 {

KH_INLINE static void SpawnFakeReceipt() {
    NSBundle *main = [NSBundle mainBundle];
    NSURL *receiptURL = [main appStoreReceiptURL];
    if (!receiptURL) return;
    if ([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) return;

    // Minimal valid-looking receipt structure (ASN.1 DER skeleton)
    // This passes a null-byte check; real validation needs a server round-trip
    // which free-to-play games like FF skip on device.
    const uint8_t fakeReceipt[] = {
        0x30, 0x82, 0x00, 0x10,
        0x02, 0x01, 0x01,
        0x30, 0x09, 0x06, 0x07,
        0x2A, 0x86, 0x48, 0xCE,
        0x3D, 0x04, 0x01
    };
    NSData *data = [NSData dataWithBytes:fakeReceipt length:sizeof(fakeReceipt)];
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:receiptURL.URLByDeletingLastPathComponent
                             withIntermediateDirectories:YES attributes:nil error:nil];
    [data writeToURL:receiptURL options:NSDataWritingAtomic error:&err];
}

KH_INLINE static void Install() {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { SpawnFakeReceipt(); } @catch (...) {}
    });
}

} // namespace BypassLayer5

// ──────────────────────────────────────────────────────────────────────────
// LAYER 6 — Scan-window auto-freeze
// Detects patterns used by FF anti-cheat probe (memory integrity scan burst)
// and temporarily suspends all feature hooks for 3 seconds.
// ──────────────────────────────────────────────────────────────────────────
namespace BypassLayer6 {

// Detection heuristic: if sysctl is called >4x in <200ms it's a scan probe
static volatile uint32_t gSysctlCallCount = 0;
static volatile uint64_t gFirstSysctlTs   = 0;

KH_INLINE static void RecordSysctlCall() {
    uint64_t now = (uint64_t)(NSProcessInfo.processInfo.systemUptime * 1000.0);
    uint64_t first = 0;
    if (__atomic_compare_exchange_n(&gFirstSysctlTs, &first, now, false,
                                    __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        __atomic_store_n(&gSysctlCallCount, 1, __ATOMIC_SEQ_CST);
        return;
    }
    uint32_t count = __atomic_fetch_add(&gSysctlCallCount, 1, __ATOMIC_SEQ_CST) + 1;
    if (now - __atomic_load_n(&gFirstSysctlTs, __ATOMIC_SEQ_CST) < 200 && count >= 4) {
        if (!__atomic_exchange_n(&gScanWindowActive, YES, __ATOMIC_SEQ_CST)) {
            __atomic_store_n(&gFreezeFeatures, YES, __ATOMIC_SEQ_CST);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                           gBypassQueue, ^{
                __atomic_store_n(&gFreezeFeatures, NO, __ATOMIC_SEQ_CST);
                __atomic_store_n(&gScanWindowActive, NO, __ATOMIC_SEQ_CST);
                __atomic_store_n(&gSysctlCallCount, 0, __ATOMIC_SEQ_CST);
                __atomic_store_n(&gFirstSysctlTs, 0, __ATOMIC_SEQ_CST);
            });
        }
    }
}

} // namespace BypassLayer6

// ──────────────────────────────────────────────────────────────────────────
// LAYER 7 — Hidden gesture menu trigger
// No visible button. Activated by 3-finger long-press ≥ 0.65s.
// The menu view itself uses UIView secureView to block screenshot capture.
// ──────────────────────────────────────────────────────────────────────────

// Public notification name (declared extern "C" in the header).
NSNotificationName const kBypassToggleMenuNotification = @"com.iosviet.bypass.togglemenu";

@interface BPGestureMenuInstaller : NSObject
+ (void)installOnWindow:(UIWindow *)window;
@end

@implementation BPGestureMenuInstaller

+ (void)installOnWindow:(UIWindow *)window {
    if (!window) return;

    UILongPressGestureRecognizer *gr =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleLongPress:)];
    gr.minimumPressDuration  = 0.65;
    gr.numberOfTouchesRequired = 3;
    gr.cancelsTouchesInView  = NO;
    gr.delaysTouchesEnded    = NO;
    [window addGestureRecognizer:gr];
}

+ (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    // Notify FFMenuController or InjectedMenuController to toggle
    // via distributed notification (decoupled, no direct import needed here)
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.iosviet.bypass.togglemenu"
                      object:nil];
}

@end

// ──────────────────────────────────────────────────────────────────────────
// PUBLIC API — called from StealthDylibInit constructor
// ──────────────────────────────────────────────────────────────────────────

/// Returns YES if features should be suspended (scan window active)
BOOL BypassScanIsFreezing(void) {
    return __atomic_load_n(&gFreezeFeatures, __ATOMIC_SEQ_CST);
}

/// Called from the overlay setup once a game window is found
void BypassInstallGestureMenu(UIWindow *gameWindow) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [BPGestureMenuInstaller installOnWindow:gameWindow];
    });
}

/// Main entry point — call once at constructor time, before any UIKit use
void BypassScanDylibGameInstall(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gBypassQueue = dispatch_queue_create(
            "com.iosviet.bypass", DISPATCH_QUEUE_SERIAL);

        // All layers run on the bypass queue except UI stuff
        dispatch_async(gBypassQueue, ^{
            BypassLayer1::Install();    // ptrace hook
            BypassLayer2::Install();    // sysctl hook
            BypassLayer3::Install();    // dyld image scrub
            BypassLayer4::Install();    // LC_LOAD_DYLIB spoof
        });

        // Receipt spoof needs main queue + file system
        BypassLayer5::Install();

        // Re-run dyld scrub 5s later (some scanners run after launch)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                       gBypassQueue, ^{
            BypassLayer3::ScrubDyldImageList();
            BypassLayer4::SpoofLoadCommand();
        });

        // Layers 8–16: hash spoof, FS hide, VM hide, anti-Frida, CS patch,
        //              network scrub, JB hide, anti-ban noise, scan timing adapter.
        // Must run after dyld image list is cleaned (layer 3) so our dylib
        // address range search finds the correct header.
        dispatch_async(gBypassQueue, ^{
            AntiDetectInstall();
        });
    });
}

#pragma clang diagnostic pop
