// StealthDylibInit.mm — stealth entry point + 7-layer bypass engine
// bypassscandylibgame.mm compiled in the same Theos target
#import <UIKit/UIKit.h>
#import "InjectedLicenseController.h"
#import "InjectedOverlayOwnership.h"
#import "InjectedWindowSelection.h"
#import "InjectedOverlayAttachment.h"
#include "InjectedStartupPolicy.h"
#include "bypassscandylibgame.h"

@interface MizzeOverlayContainer : UIView
@property(nonatomic,weak) UIView *contentView;
@end
@implementation MizzeOverlayContainer
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.contentView) ? nil : hit;
}
@end

// All state is confined to the main queue. Coalesce window/scene notifications
// so a game loading several scenes never starts parallel retry chains.
static BOOL setupPending = NO;
static NSUInteger setupAttempts = 0;
static const NSUInteger kMaxSetupAttempts = 60;
static InjectedStartup::Gate startupGate;
static void ScheduleInjectedOverlay(NSTimeInterval delay);

static void SetupInjectedOverlayMenu() {
    NSCAssert(NSThread.isMainThread, @"Overlay setup requires the main thread");

    // Don't set up during an active game scan window — reschedule 3s later
    if (BypassScanIsFreezing()) {
        ScheduleInjectedOverlay(3.0);
        return;
    }

    UIApplication *app = UIApplication.sharedApplication;
    if (!app || MizzeOverlayOwner(app)) return;
    const NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    UIWindow *gameWindow = MizzeFindGameWindow(app);
    UIViewController *host = gameWindow.rootViewController;
    const BOOL attached = host.isViewLoaded && host.view.window == gameWindow &&
        !host.isBeingPresented && !host.isBeingDismissed && !host.transitionCoordinator;
    if (!startupGate.ready(app.applicationState == UIApplicationStateActive, attached,
        reinterpret_cast<uintptr_t>((__bridge void *)gameWindow), gameWindow.bounds.size.width,
        gameWindow.bounds.size.height, now)) {
        if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(1.0);
        return;
    }

    MizzeOverlayContainer *overlay = nil;
    @try {
        overlay = [[MizzeOverlayContainer alloc] initWithFrame:host.view.bounds];
        overlay.backgroundColor = UIColor.clearColor;
        overlay.userInteractionEnabled = YES;
        if (!MizzeClaimOverlay(app, overlay)) return;

        InjectedLicenseController *root = [InjectedLicenseController new];
        root.gameWindow = gameWindow;
        overlay.contentView=root.view;
        if(!MizzeAttachChildOverlay(host,overlay,root)){
            MizzeReleaseOverlay(app,overlay);
            if(++setupAttempts<kMaxSetupAttempts)ScheduleInjectedOverlay(2.0);
            return;
        }

        // Install hidden 3-finger gesture on game window (bypass layer 7)
        BypassInstallGestureMenu(gameWindow);

        // Listen for gesture toggle notification
        [[NSNotificationCenter defaultCenter]
            addObserverForName:kBypassToggleMenuNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
            if (BypassScanIsFreezing()) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.18 animations:^{
                    overlay.alpha = overlay.alpha > 0.01f ? 0.0f : 1.0f;
                }];
            });
        }];
        // Start hidden — gesture reveals on demand, invisible to screenshot/scan
        overlay.alpha = 0.0f;

    } @catch (NSException *exception) {
        [overlay removeFromSuperview];
        MizzeReleaseOverlay(app, overlay);
        if(++setupAttempts<kMaxSetupAttempts)ScheduleInjectedOverlay(2.0);
    }
}

static void ScheduleInjectedOverlay(NSTimeInterval delay) {
    if (setupPending) return;
    setupPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        setupPending = NO;
        SetupInjectedOverlayMenu();
    });
}

static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // All 7 bypass layers install immediately, before any UIKit activity.
    // This runs in the dyld constructor chain — no UIKit calls here.
    BypassScanDylibGameInstall();

    // Enqueue overlay setup on the main thread after bypass is in place.
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            for (NSNotificationName name in @[UIApplicationDidFinishLaunchingNotification,
                                               UIApplicationDidBecomeActiveNotification,
                                               UIWindowDidBecomeKeyNotification]) {
                [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                usingBlock:^(NSNotification *notification) {
                    setupAttempts = 0;
                    ScheduleInjectedOverlay(0.25);
                }];
            }
            // Cover a dylib loaded after the game's launch notification.
            ScheduleInjectedOverlay(0.25);
        }
    });
}
