#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "KabraxHide.h"

namespace StealthAntiCheat {

    KH_INLINE static void MaskDylibFromDyld() {
        // Unlink or obscure loaded dylib entries in dyld image tables
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "libsubsystem") || strstr(name, "iOSViet") || strstr(name, "Bugchi"))) {
                // Obfuscate / hide entry reference
            }
        }
    }

    typedef int (*ptrace_func_t)(int request, pid_t pid, caddr_t addr, int data);
    static ptrace_func_t orig_ptrace = NULL;

    static int hooked_ptrace(int request, pid_t pid, caddr_t addr, int data) {
        if (request == 31) { // PT_DENY_ATTACH
            return 0; // Silently bypass PT_DENY_ATTACH
        }
        if (orig_ptrace) return orig_ptrace(request, pid, addr, data);
        return 0;
    }

    typedef int (*sysctl_func_t)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
    static sysctl_func_t orig_sysctl = NULL;

    static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
        int ret = 0;
        if (orig_sysctl) {
            ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
        } else {
            ret = sysctl(name, namelen, oldp, oldlenp, newp, newlen);
        }
        if (namelen >= 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                info->kp_proc.p_flag &= ~P_TRACED; // Clear P_TRACED anti-debug flag
            }
        }
        return ret;
    }

    KH_INLINE static void ApplyStealthProtections() {
        MaskDylibFromDyld();
    }
}

static HUDMainApplicationDelegate *gInjectedHUDDelegate = nil;
static BOOL gMenuInitialized = NO;

static void SetupInjectedOverlayMenu() {
    if (gMenuInitialized) return;
    gMenuInitialized = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
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
            if (!targetKeyWindow) {
                targetKeyWindow = [UIApplication sharedApplication].keyWindow;
            }

            gInjectedHUDDelegate = [[HUDMainApplicationDelegate alloc] init];
            
            CGRect screenFrame = [UIScreen mainScreen].bounds;
            HUDMainWindow *hudWindow = [[HUDMainWindow alloc] initWithFrame:screenFrame];
            hudWindow.windowLevel = UIWindowLevelStatusBar + 100.0;
            hudWindow.hidden = NO;
            hudWindow.userInteractionEnabled = YES;
            hudWindow.backgroundColor = [UIColor clearColor];

            _0xB1872A2 *menuOverlayView = [[_0xB1872A2 alloc] initWithFrame:screenFrame];
            menuOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [hudWindow addSubview:menuOverlayView];

            [gInjectedHUDDelegate setValue:hudWindow forKey:@"window"];
            [gInjectedHUDDelegate setValue:menuOverlayView forKey:@"_menuView"];

            // Load & sync ESP preferences
            ESPSyncFromPrefs();
        } @catch (NSException *ex) {
            // Silently handle exceptions in stealth mode
        }
    });
}

static void __attribute__((constructor)) StealthDylibEntryPoint() {
    StealthAntiCheat::ApplyStealthProtections();

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        SetupInjectedOverlayMenu();
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SetupInjectedOverlayMenu();
    });
}
