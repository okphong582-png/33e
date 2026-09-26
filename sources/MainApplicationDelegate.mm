#import "MainApplicationDelegate.h"
#import "MainApplication.h"
#import "HomeViewController.h"
#include "KabraxHide.h"
#import "HUDHelper.h"

@implementation MainApplicationDelegate {
    _0xHOMEVC *_0xFFAFD;   // ← ĐỔI TÊN
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];

    // ĐỔI TÊN
    _0xFFAFD = [[_0xHOMEVC alloc] init];

    UINavigationController *_0x35538 =
    [[UINavigationController alloc] initWithRootViewController:_0xFFAFD];

    _0x35538.navigationBarHidden = YES;
    _0x35538.view.userInteractionEnabled = YES;

    self.window.rootViewController = _0x35538;
    [self.window makeKeyAndVisible];

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSUserDefaults standardUserDefaults] synchronize];

        if (self->_0xFFAFD) {
            [self->_0xFFAFD _0xDAH2863];
        }

        self.window.userInteractionEnabled = YES;
    });
}

@end