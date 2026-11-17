// StealthDylibInit.mm — enhanced stealth entry point
// Wire: BypassScanDylibGameInstall (all 7 bypass layers) + hidden gesture menu
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "KabraxHide.h"
#import "UIView+SecureView.h"
#import "InjectedMenuController.h"

// Bypass engine — same translation unit compile via makefile
// bypassscandylibgame.mm is added to iOSViet_FILES
extern "C" {
    BOOL BypassScanIsFreezing(void);
    void BypassInstallGestureMenu(UIWindow *gameWindow);
    void BypassScanDylibGameInstall(void);
}

// ── Overlay window — transparent, click-through except controls ───────────
@interface MizzeOverlayWindow : UIWindow
@end
@implementation MizzeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

// ── Overlay state ─────────────────────────────────────────────────────────
static HUDMainApplicationDelegate *gHUDDelegate  = nil;
static MizzeOverlayWindow         *gHUDWindow     = nil;
static InjectedMenuController     *gMenuController = nil;
static BOOL                        gMenuInitialized = NO;

// ── Hidden gesture: toggle menu via notification ──────────────────────────
static void HandleToggleMenuNotification(NSNotification *note) {
    if (!gMenuController) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        // During a scan window, keep menu hidden regardless of gesture
        if (BypassScanIsFreezing()) return;
        UIView *menuView = gMenuController.view;
        [UIView animateWithDuration:0.18 animations:^{
            menuView.alpha = menuView.alpha > 0.01f ? 0.0f : 1.0f;
        }];
    });
}

// ── Overlay setup ─────────────────────────────────────────────────────────
static void SetupInjectedOverlayMenu() {
    if (gMenuInitialized) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gMenuInitialized) return;
        // Don't set up UI during a scan freeze window
        if (BypassScanIsFreezing()) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{ SetupInjectedOverlayMenu(); });
            return;
        }
        @try {
            UIWindow *targetKeyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *ws = (UIWindowScene *)scene;
                        if (ws.activationState == UISceneActivationStateForegroundActive ||
                            ws.activationState == UISceneActivationStateForegroundInactive) {
                            for (UIWindow *w in ws.windows) {
                                if (w.isKeyWindow) { targetKeyWindow = w; break; }
                            }
                        }
                    }
                    if (targetKeyWindow) break;
                }
            }
            if (!targetKeyWindow) targetKeyWindow = [UIApplication sharedApplication].keyWindow;
            if (!targetKeyWindow) {
                static NSUInteger retries = 0;
                if (++retries <= 20) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                                   dispatch_get_main_queue(), ^{ SetupInjectedOverlayMenu(); });
                }
                return;
            }

            gHUDDelegate = [[HUDMainApplicationDelegate alloc] init];

            MizzeOverlayWindow *hudWin;
            if (@available(iOS 13.0, *)) {
                hudWin = targetKeyWindow.windowScene
                    ? [[MizzeOverlayWindow alloc] initWithWindowScene:targetKeyWindow.windowScene]
                    : [[MizzeOverlayWindow alloc] initWithFrame:targetKeyWindow.bounds];
            } else {
                hudWin = [[MizzeOverlayWindow alloc] initWithFrame:targetKeyWindow.bounds];
            }
            hudWin.frame = targetKeyWindow.frame;
            // Stay below status bar so no visible badge
            hudWin.windowLevel = UIWindowLevelNormal + 0.5;
            hudWin.userInteractionEnabled = YES;
            hudWin.backgroundColor = [UIColor clearColor];
            hudWin.opaque = NO;

            gMenuController = [InjectedMenuController new];
            gMenuController.gameWindow = targetKeyWindow;
            gMenuController.view.backgroundColor = UIColor.clearColor;
            // START HIDDEN — only shown via gesture
            gMenuController.view.alpha = 0.0f;
            hudWin.rootViewController = gMenuController;
            gMenuController.view.frame = hudWin.bounds;

            [gHUDDelegate setValue:hudWin forKey:@"window"];
            gHUDWindow = hudWin;
            gMenuInitialized = YES;
            hudWin.hidden = NO;

            // Install hidden 3-finger gesture on game window
            BypassInstallGestureMenu(targetKeyWindow);

            // Listen for toggle notification fired by gesture
            [[NSNotificationCenter defaultCenter]
                addObserverForName:@"com.iosviet.bypass.togglemenu"
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *n) {
                HandleToggleMenuNotification(n);
            }];

        } @catch (NSException *ex) {
            // Silent fail in stealth mode
        }
    });
}

// ── Constructor ───────────────────────────────────────────────────────────
static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // Layer 1–7 bypass runs immediately, before any UIKit activity
    BypassScanDylibGameInstall();

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidFinishLaunchingNotification
                   object:nil
                    queue:[NSOperationQueue mainQueue]
               usingBlock:^(NSNotification *note) {
        SetupInjectedOverlayMenu();
    }];
    [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                   object:nil
                    queue:[NSOperationQueue mainQueue]
               usingBlock:^(NSNotification *note) {
        SetupInjectedOverlayMenu();
    }];

    // Fallback delayed attach (covers games loaded before notification fires)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SetupInjectedOverlayMenu();
    });
}
