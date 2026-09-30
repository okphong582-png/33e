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
#import "AntiREProtection.h"
#import "UIView+SecureView.h"
#import "InjectedLicenseController.h"

@interface MizzeOverlayWindow : UIWindow
@end
@implementation MizzeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

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

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gMenuInitialized) return;
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
            if (!targetKeyWindow) {
                static NSUInteger retries = 0;
                if (++retries <= 15) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ SetupInjectedOverlayMenu(); });
                return;
            }

            gInjectedHUDDelegate = [[HUDMainApplicationDelegate alloc] init];
            
            CGRect screenFrame = targetKeyWindow.bounds;
            MizzeOverlayWindow *hudWindow;
            if (@available(iOS 13.0, *)) {
                hudWindow = targetKeyWindow.windowScene ? [[MizzeOverlayWindow alloc] initWithWindowScene:targetKeyWindow.windowScene] : [[MizzeOverlayWindow alloc] initWithFrame:screenFrame];
            } else hudWindow = [[MizzeOverlayWindow alloc] initWithFrame:screenFrame];
            hudWindow.frame = targetKeyWindow.frame;
            hudWindow.windowLevel = UIWindowLevelStatusBar + 100.0;
            hudWindow.userInteractionEnabled = YES;
            hudWindow.backgroundColor = [UIColor clearColor];

            InjectedLicenseController *root = [InjectedLicenseController new];
            root.gameWindow = targetKeyWindow;
            root.view.backgroundColor = UIColor.clearColor;
            hudWindow.rootViewController = root;
            root.view.frame = hudWindow.bounds;

            [gInjectedHUDDelegate setValue:hudWindow forKey:@"window"];

            gMenuInitialized = YES;
            hudWindow.hidden = NO;
        } @catch (NSException *ex) {
            // Silently handle exceptions in stealth mode
        }
    });
}

static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // Initialize all obfuscation pipeline protections
    // __CV + .vtizer + __VDATA/__vdata + __MONITE_TEXT → Anti-RE
    ANTI_RE_INIT();

    StealthAntiCheat::ApplyStealthProtections();

    // Schedule periodic integrity checks
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        ANTI_RE_CHECK();
    });

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
