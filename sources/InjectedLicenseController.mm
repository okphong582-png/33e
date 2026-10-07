#ifdef MIZZE_INJECTED
#import "InjectedLicenseController.h"
#import "LicenseSession.h"
#import "InjectedProtection.h"
#import "UIView+SecureView.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/menu.h"
#import "../esp/drawing_view/ESPPrefs.h"

@interface InjectedLicenseController () <UITextFieldDelegate>
@property(nonatomic,strong) UIButton *loginButton;
@property(nonatomic,strong) UIView *keyPanel;
@property(nonatomic,strong) UITextField *keyField;
@property(nonatomic,strong) UILabel *keyStatus;
@property(nonatomic,strong) UIButton *submitButton;
@property(nonatomic,strong) UIButton *closeButton;
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
    self.loginButton.backgroundColor = [UIColor colorWithWhite:.065 alpha:.98];
    [self.loginButton setTitleColor:[UIColor colorWithRed:.35 green:.9 blue:.73 alpha:1] forState:UIControlStateNormal];
    self.loginButton.layer.cornerRadius = 18;
    [self.loginButton addTarget:self action:@selector(prompt) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(revoked:) name:LicenseSessionDidBecomeUnauthorizedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground:) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.loginButton.frame = CGRectMake(self.view.safeAreaInsets.left + 12, self.view.safeAreaInsets.top + 16, 164, 38);
    const CGRect bounds=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    const CGFloat width=MIN(320,MAX(0,bounds.size.width-24));
    self.keyPanel.frame=CGRectMake(CGRectGetMidX(bounds)-width*.5,CGRectGetMidY(bounds)-106,width,212);
    self.keyStatus.frame=CGRectMake(16,14,MAX(0,width-66),54);
    self.closeButton.frame=CGRectMake(MAX(0,width-42),4,38,38);
    self.keyField.frame=CGRectMake(16,76,MAX(0,width-32),44);
    self.submitButton.frame=CGRectMake(16,136,MAX(0,width-32),44);
}
// Match the Unity host's orientation mask. A portrait-only overlay becoming
// key over a landscape-only host can cause UIApplication's rotation exception.
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.gameWindow.rootViewController.supportedInterfaceOrientations ?: UIInterfaceOrientationMaskAll;
}
- (BOOL)shouldAutorotate { return self.gameWindow.rootViewController.shouldAutorotate; }
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
    if (self.busy || !self.view.window || [LicenseSession shared].authorized ||
        UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
    // Inline UI avoids presenting a second controller and changing the key
    // window while Unity is loading/rotating. Keyboard focus is user initiated.
    if (!self.keyPanel) {
        self.keyPanel=[UIView new];
        self.keyPanel.backgroundColor=[UIColor colorWithWhite:0.065 alpha:0.98];
        self.keyPanel.layer.cornerRadius=20;
        self.keyPanel.layer.borderWidth=0.7;
        self.keyPanel.layer.borderColor=[UIColor colorWithRed:.35 green:.9 blue:.73 alpha:.6].CGColor;
        self.keyStatus=[UILabel new];self.keyStatus.numberOfLines=2;
        self.keyStatus.textColor=UIColor.whiteColor;
        self.keyStatus.font=[UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        self.keyField=[UITextField new];self.keyField.delegate=self;
        self.keyField.placeholder=@"Nhập key";self.keyField.secureTextEntry=YES;
        self.keyField.textColor=UIColor.whiteColor;
        self.keyField.backgroundColor=[UIColor colorWithWhite:.15 alpha:1];
        self.keyField.layer.cornerRadius=10;
        UIView *padding=[[UIView alloc] initWithFrame:CGRectMake(0,0,12,44)];
        self.keyField.leftView=padding;self.keyField.leftViewMode=UITextFieldViewModeAlways;
        self.keyField.autocorrectionType=UITextAutocorrectionTypeNo;
        self.keyField.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters;
        self.keyField.returnKeyType=UIReturnKeyDone;
        self.submitButton=[UIButton buttonWithType:UIButtonTypeSystem];
        self.closeButton=[UIButton buttonWithType:UIButtonTypeSystem];
        [self.closeButton setTitle:@"×" forState:UIControlStateNormal];
        [self.closeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.closeButton.titleLabel.font=[UIFont systemFontOfSize:24 weight:UIFontWeightRegular];
        [self.closeButton addTarget:self action:@selector(closeKeyPanel) forControlEvents:UIControlEventTouchUpInside];
        self.submitButton.backgroundColor=[UIColor colorWithRed:.35 green:.9 blue:.73 alpha:1];
        self.submitButton.layer.cornerRadius=10;
        [self.submitButton setTitleColor:[UIColor colorWithWhite:.06 alpha:1] forState:UIControlStateNormal];
        [self.submitButton setTitle:@"Xác thực" forState:UIControlStateNormal];
        [self.submitButton addTarget:self action:@selector(submitKey) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *part in @[self.keyStatus,self.keyField,self.submitButton,self.closeButton]) [self.keyPanel addSubview:part];
        [self.view addSubview:self.keyPanel];
    }
    self.keyStatus.text=self.message;self.keyPanel.hidden=NO;
    [self.view setNeedsLayout];
}
- (BOOL)textFieldShouldBeginEditing:(UITextField *)field {
    [self.view.window makeKeyWindow];return YES;
}
- (void)closeKeyPanel {
    [self.view endEditing:YES];self.keyPanel.hidden=YES;[self restoreGameFocus];
}
- (BOOL)textFieldShouldReturn:(UITextField *)field { [self submitKey];return NO; }
- (void)submitKey {
    if(self.busy)return;
    NSString *key=self.keyField.text ?: @"";
    [self.view endEditing:YES];[self restoreGameFocus];[self verify:key];
}
- (void)verify:(NSString *)key {
    if (self.busy) return;
    self.busy = YES; self.loginButton.enabled = NO;self.submitButton.enabled=NO;
    [self.loginButton setTitle:@"Đang xác thực…" forState:UIControlStateNormal];
    __weak InjectedLicenseController *weakSelf = self;
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *message) {
        InjectedLicenseController *owner = weakSelf;
        if (!owner) return;
        owner.busy = NO; owner.loginButton.enabled = YES;owner.submitButton.enabled=YES; owner.message = message;
        [owner.loginButton setTitle:@"Mizze · Nhập key" forState:UIControlStateNormal];
        if (ok) { [owner unlock]; }
        else if (![LicenseSession shared].authorized) { [owner lock]; [owner prompt]; }
    };
    if (key) [[LicenseSession shared] loginWithKey:key completion:done];
    else [[LicenseSession shared] refresh:done];
}
- (void)unlock {
    if (![LicenseSession shared].authorized) return;
    MizzeStartOwnCodeProtection();
    [[LicenseSession shared] monitor];
    self.loginButton.hidden = YES;
    self.keyPanel.hidden=YES;self.keyField.text=@"";
    if (self.menuView) return;
    ESPSyncFromPrefs();
    self.espView = [[_0xDAB2826 alloc] initWithFrame:self.view.bounds];
    self.menuView = [[_0xB1872A2 alloc] initWithFrame:self.view.bounds];
    for (UIView *view in @[self.espView, self.menuView]) {
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [view hideViewFromCapture:ESPPrefsBool(@"AnLive", NO)];
        [self.view addSubview:view];
    }
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
    [self.view endEditing:YES];[self restoreGameFocus];[self prompt];
}
- (void)foreground:(NSNotification *)notification {
    if (![LicenseSession shared].authorized) [self lock];
    if ([LicenseSession shared].hasSavedKey) [self verify:nil];
    else [self prompt];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
#endif
