#ifdef MIZZE_INJECTED
#import "InjectedLicenseController.h"
#import "LicenseSession.h"
#import "UIView+SecureView.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"

@interface InjectedLicenseController ()
@property(nonatomic,strong) UIButton *loginButton;
@property(nonatomic,strong) UIView *espView;
@property(nonatomic,strong) UIView *menuView;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,assign) BOOL started;
@property(nonatomic,copy) NSString *message;
@end

@implementation InjectedLicenseController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.message = @"Nhập key để mở menu Mizze.";
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"Mizze · Nhập key" forState:UIControlStateNormal];
    self.loginButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.55 blue:0.23 alpha:0.95];
    [self.loginButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.loginButton.layer.cornerRadius = 18;
    [self.loginButton addTarget:self action:@selector(prompt) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(revoked:) name:LicenseSessionDidBecomeUnauthorizedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground:) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.loginButton.frame = CGRectMake(self.view.safeAreaInsets.left + 12, self.view.safeAreaInsets.top + 16, 164, 38);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.started) return;
    self.started = YES;
    if ([LicenseSession shared].hasSavedKey) [self verify:nil];
    else [self prompt];
}
- (void)restoreGameFocus {
    if (self.view.window.isKeyWindow) [self.gameWindow makeKeyWindow];
}
- (void)prompt {
    if (self.busy || self.presentedViewController || !self.view.window || [LicenseSession shared].authorized) return;
    [self.view.window makeKeyWindow];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mizze · Xác thực key" message:self.message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Nhập key"; field.secureTextEntry = YES;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    __weak InjectedLicenseController *weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Để sau" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [weakSelf restoreGameFocus];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xác thực" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = weakAlert.textFields.firstObject.text ?: @"";
        [weakSelf restoreGameFocus];
        // Finish dismissal before a fast validation error can present again.
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf verify:key]; });
    }]];
    [self presentViewController:alert animated:NO completion:nil];
}
- (void)verify:(NSString *)key {
    if (self.busy) return;
    self.busy = YES; self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"Đang xác thực…" forState:UIControlStateNormal];
    __weak InjectedLicenseController *weakSelf = self;
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *message) {
        InjectedLicenseController *owner = weakSelf;
        if (!owner) return;
        owner.busy = NO; owner.loginButton.enabled = YES; owner.message = message;
        [owner.loginButton setTitle:@"Mizze · Nhập key" forState:UIControlStateNormal];
        if (ok) { [owner unlock]; }
        else if (![LicenseSession shared].authorized) { [owner lock]; [owner prompt]; }
    };
    if (key) [[LicenseSession shared] loginWithKey:key completion:done];
    else [[LicenseSession shared] refresh:done];
}
- (void)unlock {
    if (![LicenseSession shared].authorized) return;
    [[LicenseSession shared] monitor];
    self.loginButton.hidden = YES;
    if (self.menuView) return;
    ESPSyncFromPrefs();
    self.espView = [[_0xDAB2826 alloc] initWithFrame:self.view.bounds];
    self.menuView = [[_0xB1872A2 alloc] initWithFrame:self.view.bounds];
    for (UIView *view in @[self.espView, self.menuView]) {
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [view hideViewFromCapture:ESPPrefsBool(@"AnLive", NO)];
        [self.view addSubview:view];
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"dd/MM/yyyy HH:mm:ss";
    NSString *expiry = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[LicenseSession shared].expiresAt]];
    UIAlertController *notice = [UIAlertController alertControllerWithTitle:@"Key hợp lệ" message:[@"Hạn sử dụng: " stringByAppendingString:expiry] preferredStyle:UIAlertControllerStyleAlert];
    [notice addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleDefault handler:nil]];
    if (!self.presentedViewController) [self presentViewController:notice animated:NO completion:nil];
}
- (void)lock {
    [(_0xB1872A2 *)self.menuView hideMenu];
    [self.espView removeFromSuperview]; self.espView = nil;
    [self.menuView removeFromSuperview]; self.menuView = nil;
    self.loginButton.hidden = NO;
}
- (void)revoked:(NSNotification *)notification {
    self.message = notification.userInfo[@"message"] ?: [LicenseSession shared].lastMessage;
    [self lock];
    [self dismissViewControllerAnimated:NO completion:^{ [self prompt]; }];
}
- (void)foreground:(NSNotification *)notification {
    if (![LicenseSession shared].authorized) [self lock];
    if ([LicenseSession shared].hasSavedKey) [self verify:nil];
    else [self prompt];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
#endif
