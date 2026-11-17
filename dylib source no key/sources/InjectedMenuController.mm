#ifdef MIZZE_INJECTED
#import "InjectedMenuController.h"
#import "UIView+SecureView.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"
@interface InjectedMenuController ()
@property(nonatomic,strong) UIView *espView;
@property(nonatomic,strong) UIView *menuView;
@end
@implementation InjectedMenuController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
    ESPSyncFromPrefs();
    self.espView=[[_0xDAB2826 alloc] initWithFrame:self.view.bounds];
    self.menuView=[[_0xB1872A2 alloc] initWithFrame:self.view.bounds];
    for(UIView *view in @[self.espView,self.menuView]){
        view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [view hideViewFromCapture:ESPPrefsBool(@"AnLive",NO)];[self.view addSubview:view];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(restoreLauncherVisibility)
        name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)restoreLauncherVisibility {
    if (self.isViewLoaded && self.view.window &&
        UIApplication.sharedApplication.applicationState==UIApplicationStateActive)
        self.view.alpha=1;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Restore the launcher after the host finishes attaching the controller.
    // Its visibility belongs to the UI lifecycle, not match readiness.
    __weak InjectedMenuController *owner=self;
    dispatch_async(dispatch_get_main_queue(), ^{ [owner restoreLauncherVisibility]; });
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.gameWindow.rootViewController.supportedInterfaceOrientations ?: UIInterfaceOrientationMaskAll;
}
- (BOOL)shouldAutorotate {return self.gameWindow.rootViewController.shouldAutorotate;}
@end
#endif
