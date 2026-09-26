// HUDMainApplicationDelegate.mm - FULL CODE HOÀN CHỈNH

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"

#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"

#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"

#import "../esp/Core/pid.h"
#import "HUDHelper.h"
#import "UIView+SecureView.h"

// FBSOrientationObserver
@interface FBSOrientationObserver : NSObject
- (long long)activeInterfaceOrientation;
- (void)activeInterfaceOrientationWithCompletion:(id)arg1;
- (void)invalidate;
- (void)setHandler:(id)arg1;
- (id)handler;
@end

@interface FBSOrientationUpdate : NSObject
- (unsigned long long)sequenceNumber;
- (long long)rotationDirection;
- (long long)orientation;
- (double)duration;
@end

// Container View Controller với autorotate
@interface HUDAutorotatingContainerViewController : UIViewController
@end

@implementation HUDAutorotatingContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [UIApplication sharedApplication].statusBarOrientation;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        for (UIView *subview in self.view.subviews) {
            subview.frame = self.view.bounds;
        }
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}


@end

static __weak HUDMainApplicationDelegate *_sharedHUDDelegate = nil;

BOOL HUDFloatButtonHandleTouch(CGPoint screenPoint, UITouchPhase phase, NSInteger pointerId) {
    HUDMainApplicationDelegate *d = _sharedHUDDelegate;
    if (!d) return NO;
    return [d handleTouchAtScreenPoint:screenPoint phase:phase pointerId:pointerId];
}

@interface HUDMainApplicationDelegate () {
    SBSAccessibilityWindowHostingController *_windowHostingController;
    dispatch_source_t _gameCheckTimer;
    _0xB1872A2 *_menuView;
    FBSOrientationObserver *_orientationObserver;
    UIInterfaceOrientation _currentOrientation;
}

@property (nonatomic, assign) UIInterfaceOrientation currentOrientation;

@end

@implementation HUDMainApplicationDelegate

- (instancetype)init {
    if (self = [super init]) {}
    return self;
}

- (CGPoint)windowLocalPointFromScreen:(CGPoint)sp {
    return [self.window convertPoint:sp fromCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
}

- (BOOL)handleTouchAtScreenPoint:(CGPoint)screenPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    if (!_menuView || !self.window) return NO;
    CGPoint inWindow = [self.window convertPoint:screenPoint fromCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
    BOOL consumed = [_menuView handleTouchAtWindowPoint:inWindow phase:phase pointerId:pointerId];
    return consumed;
}

- (UIInterfaceOrientation)currentInterfaceOrientation {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.activationState == UISceneActivationStateForegroundActive ||
                    ws.activationState == UISceneActivationStateForegroundInactive) {
                    return ws.interfaceOrientation;
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIInterfaceOrientation sb = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
    if (sb != UIInterfaceOrientationUnknown) {
        return sb;
    }
    UIDeviceOrientation dev = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsLandscape(dev)) {
        return (dev == UIDeviceOrientationLandscapeLeft) ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationLandscapeLeft;
    }
    return UIInterfaceOrientationLandscapeRight;
}

- (void)updateWindowForOrientation:(UIInterfaceOrientation)orientation { 
if (!self.window)

return;
CGRect screenBounds = [UIScreen mainScreen].bounds;
CGRect targetFrame = screenBounds; 
if (UIInterfaceOrientationIsLandscape(orientation)) { 
targetFrame = CGRectMake(0, 0, screenBounds.size.height, screenBounds.size.width); 

} 
[UIView animateWithDuration:0.3 animations:^{ 
self.window.frame = targetFrame;
self.window.bounds = targetFrame;
[self.window.rootViewController.view setNeedsLayout]; 

[self.window.rootViewController.view layoutIfNeeded]; 
}]; 

}


// HUDMainApplicationDelegate.mm - CÁCH FORCE ROTATE BẰNG CÁCH SET WINDOW FRAME TRỰC TIẾP

- (void)forceRotateToOrientation:(UIInterfaceOrientation)orientation
{
    if (!self.window)
        return;

    UIScreen *screen = UIScreen.mainScreen;
    CGRect screenBounds = screen.bounds;

    CGFloat portraitW = MIN(screenBounds.size.width,
                            screenBounds.size.height);

    CGFloat portraitH = MAX(screenBounds.size.width,
                            screenBounds.size.height);

    CGRect targetBounds;

    if (UIInterfaceOrientationIsLandscape(orientation))
    {
        targetBounds =
            CGRectMake(0,0,
                       portraitH,
                       portraitW);
    }
    else
    {
        targetBounds =
            CGRectMake(0,0,
                       portraitW,
                       portraitH);
    }

    CGAffineTransform transform =
        CGAffineTransformIdentity;

    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(-M_PI_2);
            break;

        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(M_PI_2);
            break;

        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(M_PI);
            break;

        default:
            break;
    }

    // reset trước
    self.window.transform = CGAffineTransformIdentity;

    // set bounds mới
    self.window.bounds = targetBounds;

    // luôn center theo màn hình thật
    self.window.center =
        CGPointMake(CGRectGetMidX(screenBounds),
                    CGRectGetMidY(screenBounds));

    // mới rotate
    self.window.transform = transform;

    UIView *root = self.window.rootViewController.view;
    root.frame = self.window.bounds;
    root.bounds = self.window.bounds;

    [root setNeedsLayout];
    [root layoutIfNeeded];

    _currentOrientation = orientation;
}
// Ngoài ra thêm vào HUDMainWindow:
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

// TRONG application:didFinishLaunchingWithOptions: THÊM DÒNG NÀY


// HUDMainApplicationDelegate.mm - CODE HOÀN CHỈNH (ĐÃ XÓA DÒNG GÂY CRASH)

// HUDMainApplicationDelegate.mm - THÊM FORCE ROTATE BẰNG UIDevice

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary <UIApplicationLaunchOptionsKey, id> *)launchOptions {
    
    // KHÔNG dùng setValue:forKey:
    
    // BẮT BUỘC: Cho phép UIDevice gửi notification xoay
   // [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    // Subscribe notification
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
   // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    
    // FBSOrientationObserver
    _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
    __weak __typeof__(self) weakSelf = self;
    [_orientationObserver setHandler:^(FBSOrientationUpdate *update) {
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIInterfaceOrientation newOrientation = (UIInterfaceOrientation)update.orientation;
            [strongSelf forceRotateToOrientation:newOrientation];
        });
    }];
    
    // Container
    HUDAutorotatingContainerViewController *container = [[HUDAutorotatingContainerViewController alloc] init];
    
    // ESP View
    _0xDAB2826 *espView = [[_0xDAB2826 alloc] initWithFrame:CGRectZero];
    espView.translatesAutoresizingMaskIntoConstraints = NO;
    espView.backgroundColor = [UIColor clearColor];
    espView.userInteractionEnabled = NO;
    [espView hideViewFromCapture:ESPPrefsBool(@"AnLive", NO)];
    
    UIView *containerView = container.view;
    [containerView addSubview:espView];
    
    // Menu View
    _0xB1872A2 *menuView = [[_0xB1872A2 alloc] initWithFrame:CGRectZero];
    [menuView hideViewFromCapture:ESPPrefsBool(@"AnLive", NO)];
    menuView.translatesAutoresizingMaskIntoConstraints = NO;
    menuView.userInteractionEnabled = YES;
    __weak __typeof__(self) wself = self;
    menuView.onExitHUDRequested = ^{
        RequestExitHUD();
        (void)wself;
    };
    [containerView addSubview:menuView];
    _menuView = menuView;
    _sharedHUDDelegate = self;
    
    [NSLayoutConstraint activateConstraints:@[
        [espView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [espView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [espView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [espView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        [menuView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [menuView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [menuView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [menuView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    // Tạo Window
    self.window = [[HUDMainWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];



    [self.window setRootViewController:container];
    self.window.backgroundColor = [UIColor clearColor];
    self.window.windowLevel = 10000010.0;
    self.window.hidden = NO;
    [self.window makeKeyAndVisible];
    
    // FORCE ROTATE LẦN ĐẦU
    UIInterfaceOrientation initialOrientation = [self currentInterfaceOrientation];
    [self forceRotateToOrientation:initialOrientation];
    
    [containerView setNeedsLayout];
    [containerView layoutIfNeeded];
    
    espView.frame = containerView.bounds;
    menuView.frame = containerView.bounds;
    
    // Register context
    _windowHostingController = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];
    unsigned int _contextId = [self.window _contextId];
    double windowLevel = [self.window windowLevel];
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:_windowHostingController];
    [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
    [invocation setArgument:&_contextId atIndex:2];
    [invocation setArgument:&windowLevel atIndex:3];
    [invocation invoke];
    
    // Game check timer
        // ===== GAME CHECK TIMER (cho phép chờ tối đa 20s) =====
    static const char *kGameProcessName = "FreeFire";
    __block NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    const NSTimeInterval timeout = 20.0; // 20 giây
    
    dispatch_source_t gameCheckTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (gameCheckTimer) {
        // Timer chạy mỗi 1 giây, bắt đầu ngay lập tức
        dispatch_source_set_timer(gameCheckTimer, DISPATCH_TIME_NOW, (uint64_t)(1.0 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));
        
        __weak __typeof__(self) weakSelf = self;
        dispatch_source_set_event_handler(gameCheckTimer, ^{
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Kiểm tra tiến trình game
            if (GetGameProcesspid((char *)kGameProcessName) != -1) {
                // Đã tìm thấy game → hủy timer, giữ HUD
                dispatch_source_cancel(gameCheckTimer);
                return;
            }
            
            // Chưa thấy game → kiểm tra thời gian đã trôi qua
            NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - startTime;
            if (elapsed >= timeout) {
                // Quá 20 giây → kill HUD
                if (strongSelf->_gameCheckTimer) {
                    dispatch_source_cancel(strongSelf->_gameCheckTimer);
                }
                exit(0);
            }
        });
        
        // Lưu timer vào biến instance để có thể hủy sau
        _gameCheckTimer = gameCheckTimer;
        dispatch_resume(gameCheckTimer);
    }


// [NSTimer scheduledTimerWithTimeInterval:0.5 
                                     //target:self 
                                   ////selector:@selector(checkAndRotate) 
                                   ///userInfo:nil 
                                    //repeats:YES];
    
    return YES;

    
    
}

// HÀM FORCE ROTATE - GỌI KHI CẦN XOAY


@end