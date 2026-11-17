// Ordinary no-key entry point. UI initialization runs on the main queue.
#import <UIKit/UIKit.h>
#import "InjectedMenuController.h"
#import "InjectedOverlayOwnership.h"
#import "InjectedWindowSelection.h"
#import "InjectedOverlayAttachment.h"
#include "InjectedStartupPolicy.h"
#include "InjectedBootstrapPolicy.h"

@interface MizzeOverlayContainer : UIView
@property(nonatomic,weak) UIView *contentView;
@end
@implementation MizzeOverlayContainer
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.contentView) ? nil : hit;
}
@end

// Lifecycle events coalesce into one kick; each kick gets a fresh generation.
// A queued retry from an older activation cannot alter the new retry chain.
// All UIKit and bootstrap state stays on the main queue.
static BOOL kickPending = NO;
static const unsigned kMaxSetupAttempts = 60;
static InjectedStartup::Bootstrap bootstrap;
static InjectedStartup::Gate startupGate;
static void ScheduleInjectedOverlay(NSTimeInterval delay);

static void SetupInjectedOverlayMenu() {
    NSCAssert(NSThread.isMainThread, @"Overlay setup requires the main thread");

    UIApplication *app = UIApplication.sharedApplication;
    if (app && MizzeOverlayOwner(app)) {
        bootstrap.cancel();
        return;
    }
    const NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    UIWindow *gameWindow = MizzeFindGameWindow(app);
    UIViewController *host = gameWindow.rootViewController;
    const BOOL attached = host.isViewLoaded && host.view.window == gameWindow &&
        !host.isBeingPresented && !host.isBeingDismissed && !host.transitionCoordinator;
    if (!startupGate.ready(app.applicationState == UIApplicationStateActive, attached,
        reinterpret_cast<uintptr_t>((__bridge void *)gameWindow), gameWindow.bounds.size.width,
        gameWindow.bounds.size.height, now)) {
        ScheduleInjectedOverlay(1.0);
        return;
    }

    MizzeOverlayContainer *overlay = nil;
    @try {
        overlay = [[MizzeOverlayContainer alloc] initWithFrame:host.view.bounds];
        overlay.backgroundColor = UIColor.clearColor;
        overlay.userInteractionEnabled = YES;
        if (!MizzeClaimOverlay(app, overlay)) {
            bootstrap.cancel();
            return;
        }

        InjectedMenuController *root = [InjectedMenuController new];
        root.gameWindow = gameWindow;
        overlay.contentView=root.view;
        if(!MizzeAttachChildOverlay(host,overlay,root)){
            MizzeReleaseOverlay(app,overlay);
            ScheduleInjectedOverlay(2.0);
            return;
        }

        // The launcher is visible as soon as the host is ready, including the lobby.
        overlay.alpha = 1.0f;
        bootstrap.cancel();
        NSLog(@"[Mizze] Overlay ready after host activation");
    } @catch (NSException *exception) {
        [overlay removeFromSuperview];
        MizzeReleaseOverlay(app, overlay);
        ScheduleInjectedOverlay(2.0);
        NSLog(@"[Mizze] Overlay setup failed: %@", exception.name);
    }
}

static void ScheduleInjectedOverlay(NSTimeInterval delay) {
    InjectedStartup::Bootstrap::Generation ticket;
    if (!bootstrap.schedule(ticket)) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (!bootstrap.beginAttempt(ticket)) return;
            SetupInjectedOverlayMenu();
        }
    });
}

static void ScheduleInjectedBootstrapKick() {
    NSCAssert(NSThread.isMainThread, @"Bootstrap requires the main thread");
    if (kickPending) return;
    kickPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            kickPending = NO;
            UIApplication *app = UIApplication.sharedApplication;
            startupGate.reset();
            if (!app || app.applicationState != UIApplicationStateActive || MizzeOverlayOwner(app)) {
                bootstrap.cancel();
                return;
            }
            bootstrap.restart(kMaxSetupAttempts);
            ScheduleInjectedOverlay(0);
        }
    });
}

static void StartOverlayLifecycle() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        for (NSNotificationName name in @[UIApplicationDidFinishLaunchingNotification,
                                           UIApplicationDidBecomeActiveNotification,
                                           UIWindowDidBecomeKeyNotification,
                                           UIWindowDidBecomeVisibleNotification,
                                           UISceneDidActivateNotification]) {
            [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *notification) {
                ScheduleInjectedBootstrapKick();
            }];
        }
        for (NSNotificationName name in @[UIApplicationWillResignActiveNotification,
                                           UIApplicationDidEnterBackgroundNotification]) {
            [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *notification) {
                bootstrap.cancel();
                startupGate.reset();
            }];
        }
        ScheduleInjectedBootstrapKick();
    });
}

#ifdef MIZZE_GAME_VN
static void ExportVnFileInfo() {
    NSBundle *bundle = NSBundle.mainBundle;
    if (![bundle.bundleIdentifier isEqualToString:@"com.garena.ffvn"] ||
        ![[bundle objectForInfoDictionaryKey:@"UIFileSharingEnabled"] boolValue] ||
        ![[bundle objectForInfoDictionaryKey:@"LSSupportsOpeningDocumentsInPlace"] boolValue]) return;

    NSFileManager *files = NSFileManager.defaultManager;
    NSError *error = nil;
    NSURL *documents = [files URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask
                           appropriateForURL:nil create:YES error:&error];
    if (!documents) {
        NSLog(@"[Mizze] Documents directory unavailable: %@", error.localizedDescription);
        return;
    }
    NSURL *folder = [documents URLByAppendingPathComponent:@"Mizze" isDirectory:YES];
    if (![files createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"[Mizze] Unable to create fileinfo export folder: %@", error.localizedDescription);
        return;
    }
    NSURL *source = [bundle.bundleURL URLByAppendingPathComponent:@"Data/Raw/ios/fileinfo"];
    NSURL *output = [folder URLByAppendingPathComponent:@"fileinfo" isDirectory:NO];
    if ([files fileExistsAtPath:output.path]) return;
    if (![files copyItemAtURL:source toURL:output error:&error]) {
        NSLog(@"[Mizze] Unable to export iOS fileinfo: %@", error.localizedDescription);
    }
}
#endif

static void __attribute__((constructor)) MizzeDylibEntryPoint() {
    auto start = ^{
        @autoreleasepool { StartOverlayLifecycle(); }
    };
#ifdef MIZZE_GAME_VN
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            @autoreleasepool { ExportVnFileInfo(); }
        });
    });
    // Keep this experiment's UIKit work outside the 35-second startup
    // interval observed in both VN watchdog reports.
    const int64_t delay = 45LL * NSEC_PER_SEC;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), start);
#else
    dispatch_async(dispatch_get_main_queue(), start);
#endif
}
