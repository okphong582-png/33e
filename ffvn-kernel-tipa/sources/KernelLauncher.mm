#import <UIKit/UIKit.h>
#import "MainApplication.h"
#import "MainApplicationDelegate.h"
#import "HUDHelper.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)identifier;
@end

@interface KernelLauncher : UIViewController
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, strong) NSTimer *timer;
@end

@implementation MainApplication
@end

@implementation KernelLauncher
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1];
    UILabel *title = [UILabel new];
    title.text = @"Mizze FFVN";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:30];
    UILabel *version = [UILabel new];
    version.text = @"Free Fire VN 1.134.1 · Dopamine kernel";
    version.textColor = UIColor.lightGrayColor;
    version.font = [UIFont systemFontOfSize:14];
    version.numberOfLines = 0;
    self.status = [UILabel new];
    self.status.textColor = UIColor.whiteColor;
    self.status.font = [UIFont systemFontOfSize:15];
    self.status.numberOfLines = 0;
    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem];
    [start setTitle:@"Start" forState:UIControlStateNormal];
    start.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [start addTarget:self action:@selector(startHUD) forControlEvents:UIControlEventTouchUpInside];
    UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem];
    [stop setTitle:@"Stop" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stopHUD) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, version, start, stop, self.status]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-28],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshStatus) userInfo:nil repeats:YES];
    [self refreshStatus];
}
- (void)startHUD {
    if (IsHUDEnabled()) { [self refreshStatus]; return; }
    NSError *error = nil;
    if (!StartHUD(&error)) { self.status.text = error.localizedDescription; return; }
    [self refreshStatus];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if ([workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        id workspace = [workspaceClass defaultWorkspace];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)])
            [workspace openApplicationWithBundleID:@"com.garena.ffvn"];
    }
}
- (void)stopHUD { StopHUD(); [self refreshStatus]; }
- (void)refreshStatus {
    self.status.text = HUDLastStatusMessage() ?: @"Bấm Start để mở menu.";
}
- (void)dealloc { [self.timer invalidate]; }
@end

@implementation MainApplicationDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [KernelLauncher new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
