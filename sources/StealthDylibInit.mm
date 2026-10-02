#import <UIKit/UIKit.h>
#import "InjectedLicenseController.h"
#import "InjectedOverlayOwnership.h"
#import "InjectedWindowSelection.h"

@interface MizzeOverlayWindow : UIWindow
@end
@implementation MizzeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

// All state is confined to the main queue. Coalesce window/scene notifications
// so a game loading several scenes never starts parallel retry chains.
static BOOL setupPending = NO;
static NSUInteger setupAttempts = 0;
static const NSUInteger kMaxSetupAttempts = 30;
static void ScheduleInjectedOverlay(NSTimeInterval delay);

static void SetupInjectedOverlayMenu() {
    NSCAssert(NSThread.isMainThread, @"Overlay setup requires the main thread");
    UIApplication *app = UIApplication.sharedApplication;
    if (!app || MizzeOverlayOwner(app)) return;
    if (app.applicationState != UIApplicationStateActive) return;

    UIWindow *gameWindow = MizzeFindGameWindow(app);
    if (!gameWindow) {
        if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(1.0);
        return;
    }

    MizzeOverlayWindow *overlay = nil;
    @try {
        if (@available(iOS 13.0, *)) {
            overlay = gameWindow.windowScene
                ? [[MizzeOverlayWindow alloc] initWithWindowScene:gameWindow.windowScene]
                : [[MizzeOverlayWindow alloc] initWithFrame:gameWindow.frame];
        } else {
            overlay = [[MizzeOverlayWindow alloc] initWithFrame:gameWindow.frame];
        }
        overlay.frame = gameWindow.frame;
        overlay.windowLevel = UIWindowLevelNormal + 1.0;
        overlay.backgroundColor = UIColor.clearColor;
        overlay.userInteractionEnabled = YES;
        if (!MizzeClaimOverlay(app, overlay)) return;

        InjectedLicenseController *root = [InjectedLicenseController new];
        root.gameWindow = gameWindow;
        overlay.rootViewController = root;
        root.view.frame = overlay.bounds;
        overlay.hidden = NO;
        NSLog(@"[Mizze] Overlay ready after host activation");
    } @catch (NSException *exception) {
        overlay.hidden = YES;
        MizzeReleaseOverlay(app, overlay);
        NSLog(@"[Mizze] Overlay setup failed: %@", exception.name);
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
    // Loader callbacks run before UIApplicationMain. Only enqueue here: no
    // UIKit objects, synthetic touches, system hooks, or integrity scans.
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
            // Also covers a dylib loaded after the game's launch notification.
            ScheduleInjectedOverlay(0.25);
        }
    });
}
