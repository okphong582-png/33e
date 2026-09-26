#import "HomeViewController.h"
#import "HUDHelper.h"
#import "LicenseSession.h"
#import "../esp/drawing_view/ESPStyle.h"

@interface _0xHOMEVC () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *submit;
@property (nonatomic, strong) UIButton *start;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) UISwitch *theme;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, assign) BOOL loggedIn;
@end
@implementation _0xHOMEVC
- (UIButton *)button:(NSString *)text action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:text forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 12;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:button]; return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.card = [UIView new]; self.card.layer.cornerRadius = 22; self.card.layer.borderWidth = 0.5;
    [self.view addSubview:self.card];
    self.titleLabel = [UILabel new]; self.titleLabel.text = @"HOANGHA";
    self.titleLabel.font = [UIFont systemFontOfSize:29 weight:UIFontWeightSemibold];
    [self.card addSubview:self.titleLabel];
    self.subtitle = [UILabel new]; self.subtitle.text = @"Đăng nhập bằng key của bạn";
    self.subtitle.font = [UIFont systemFontOfSize:13]; [self.card addSubview:self.subtitle];
    self.keyField = [UITextField new]; self.keyField.placeholder = @"Nhập key truy cập";
    self.keyField.secureTextEntry = YES; self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.keyField.textContentType = UITextContentTypePassword; self.keyField.delegate = self;
    self.keyField.returnKeyType = UIReturnKeyGo; self.keyField.font = [UIFont systemFontOfSize:14];
    self.keyField.layer.cornerRadius = 10; self.keyField.layer.borderWidth = 0.5;
    self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.keyField.leftViewMode = UITextFieldViewModeAlways; [self.card addSubview:self.keyField];
    self.submit = [self button:@"Đăng nhập" action:@selector(login)];
    self.start = [self button:@"Start menu" action:@selector(startMenu)];
    self.logoutButton = [self button:@"Đăng xuất" action:@selector(logout)];
    self.status = [UILabel new]; self.status.numberOfLines = 0;
    self.status.font = [UIFont systemFontOfSize:12]; [self.card addSubview:self.status];
    self.theme = [UISwitch new]; self.theme.on = ESPDarkTheme();
    [self.theme addTarget:self action:@selector(themeChanged) forControlEvents:UIControlEventValueChanged]; [self.view addSubview:self.theme];
    self.themeLabel = [UILabel new]; self.themeLabel.text = @"Giao diện tối";
    self.themeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]; [self.view addSubview:self.themeLabel];
    self.loggedIn = NO;
    // Remove the old client-side bypass; this value is never consulted for authorization.
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"wasAuthenticated"];
    [self applyAppearance]; [self updateControls];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = MIN(360, self.view.bounds.size.width - 40), h = 350;
    CGFloat y = MAX(self.view.safeAreaInsets.top + 64, (self.view.bounds.size.height - h) / 2);
    self.card.frame = CGRectMake((self.view.bounds.size.width - w) / 2, y, w, h);
    self.titleLabel.frame = CGRectMake(24, 28, w - 48, 40);
    self.subtitle.frame = CGRectMake(24, 74, w - 48, 24);
    self.keyField.frame = CGRectMake(24, 122, w - 48, 48);
    self.submit.frame = CGRectMake(24, 186, w - 48, 48);
    self.start.frame = CGRectMake(24, 122, w - 48, 48);
    self.logoutButton.frame = CGRectMake(24, 184, w - 48, 44);
    self.status.frame = CGRectMake(24, 249, w - 48, 74);
    self.theme.frame = CGRectMake(self.view.bounds.size.width - 72, self.view.safeAreaInsets.top + 16, 51, 31);
    self.themeLabel.frame = CGRectMake(self.theme.frame.origin.x - 106, self.theme.frame.origin.y, 100, 31);
}
- (void)applyAppearance {
    BOOL dark = ESPDarkTheme();
    if (@available(iOS 13.0, *)) self.view.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    self.view.backgroundColor = [UIColor colorWithWhite:dark ? 0.025 : 0.96 alpha:1];
    self.card.backgroundColor = [UIColor colorWithWhite:dark ? 0.065 : 1 alpha:1];
    self.card.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.2].CGColor;
    UIColor *text = [UIColor colorWithWhite:dark ? 0.95 : 0.1 alpha:1];
    UIColor *muted = [UIColor colorWithWhite:dark ? 0.6 : 0.4 alpha:1];
    self.titleLabel.textColor = self.keyField.textColor = text;
    self.subtitle.textColor = self.status.textColor = self.themeLabel.textColor = muted;
    self.keyField.backgroundColor = [UIColor colorWithWhite:dark ? 0.04 : 0.97 alpha:1];
    self.keyField.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.3].CGColor;
    UIColor *accent = [UIColor colorWithRed:0.19 green:0.43 blue:0.83 alpha:1];
    for (UIButton *b in @[self.submit, self.start]) { b.backgroundColor = accent; [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    [self.logoutButton setTitleColor:muted forState:UIControlStateNormal];
}
- (void)themeChanged { ESPPrefsSetBool(@"DarkTheme", self.theme.on); [self applyAppearance]; }
- (void)updateControls {
    self.keyField.hidden = self.submit.hidden = self.loggedIn;
    self.start.hidden = self.logoutButton.hidden = !self.loggedIn;
    self.subtitle.text = self.loggedIn ? @"Phiên truy cập đã xác thực" : @"Đăng nhập bằng key của bạn";
    [self.start setTitle:IsHUDEnabled() ? @"Dừng menu" : @"Start menu" forState:UIControlStateNormal];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self login]; return YES; }
- (void)login {
    if (!self.submit.enabled) return;
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (key.length < 8 || key.length > 128) { self.status.text = @"Nhập key hợp lệ."; return; }
    [self.view endEditing:YES]; self.keyField.text = @"";
    self.submit.enabled = NO; self.status.text = @"Đang xác thực…";
    [[LicenseSession shared] loginWithKey:key completion:^(BOOL ok, NSString *message) {
        self.submit.enabled = YES; self.loggedIn = ok; self.status.text = message;
        if (ok) [[LicenseSession shared] monitor];
        [self updateControls];
    }];
}
- (void)startMenu {
    if (IsHUDEnabled()) { _0xFFFADK2(NO); [self updateControls]; return; }
    self.start.enabled = NO; self.status.text = @"Đang kiểm tra phiên…";
    [[LicenseSession shared] refresh:^(BOOL ok, NSString *message) {
        self.start.enabled = YES;
        if (ok) { _0xFFFADK2(YES); self.status.text = @"Menu đã khởi động. Mở game để sử dụng."; }
        else { self.loggedIn = NO; self.status.text = message; }
        [self updateControls];
    }];
}
- (void)logout {
    _0xFFFADK2(NO); [[LicenseSession shared] logout];
    self.loggedIn = NO; self.status.text = @"Đã đăng xuất."; [self updateControls];
}
- (void)_0xDAH2863 {
    if (!self.isViewLoaded || !self.loggedIn) return;
    [[LicenseSession shared] refresh:^(BOOL ok, NSString *message) {
        if (!ok) { self.loggedIn = NO; self.status.text = message; _0xFFFADK2(NO); }
        [self updateControls];
    }];
}
@end
