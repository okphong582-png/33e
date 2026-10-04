#import "HomeViewController.h"
#import "HUDHelper.h"
#import "LicenseSession.h"
#import "../esp/drawing_view/ESPStyle.h"
#import "MizzeTheme.h"

@interface _0xHOMEVC () <UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic, strong) UILabel *eyebrow;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitle;
@property (nonatomic, strong) UILabel *fieldLabel;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UILabel *footer;
@property (nonatomic, strong) UILabel *brand;
@property (nonatomic, strong) UILabel *monogram;
@property (nonatomic, strong) NSArray<UILabel *> *featureLabels;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *submit;
@property (nonatomic, strong) UIButton *start;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) UISwitch *theme;
@property (nonatomic, strong) UILabel *themeLabel;
@property (nonatomic, strong) NSTimer *stateTimer;
@property (nonatomic, assign) BOOL loggedIn;
@property (nonatomic, assign) BOOL starting;
@property (nonatomic, assign) BOOL hadRunningHUD;
@property (nonatomic, assign) BOOL triedSavedKey;
@property (nonatomic, assign) BOOL restoringKey;
@property (nonatomic, assign) NSUInteger requestGeneration;
@property (nonatomic, assign) CGFloat keyboardOverlap;
- (void)waitForHUDStart:(NSInteger)attempt generation:(NSUInteger)generation;
@end

@implementation _0xHOMEVC
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [UILabel new]; label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    [self.card addSubview:label]; return label;
}
- (UIButton *)button:(NSString *)text action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:text forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 13;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:button]; return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.scroll = [UIScrollView new];
    self.scroll.alwaysBounceVertical = NO;
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.scroll];
    self.card = [UIView new]; self.card.layer.cornerRadius = 22; self.card.layer.borderWidth = 0.5;
    [self.scroll addSubview:self.card];
    self.brand = [UILabel new]; self.brand.text = @"mizze /";
    self.brand.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [self.scroll addSubview:self.brand];
    self.monogram = [self label:@"m" size:27 weight:UIFontWeightMedium];
    self.monogram.textAlignment = NSTextAlignmentCenter;
    self.monogram.layer.cornerRadius = 12; self.monogram.clipsToBounds = YES;
    self.eyebrow = [self label:@"FREE FIRE · PERSONAL SPACE" size:9 weight:UIFontWeightMedium];
    self.titleLabel = [self label:@"Tập trung.\nChơi theo ý bạn." size:30 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 2;
    self.subtitle = [self label:@"Một không gian gọn gàng cho những lựa chọn của bạn." size:13 weight:UIFontWeightRegular];
    self.subtitle.numberOfLines = 2;
    self.divider = [UIView new]; [self.card addSubview:self.divider];
    NSMutableArray *features = [NSMutableArray array];
    for (NSString *text in @[@"ESP\nMảnh & dịu", @"FOCUS\nTheo hướng", @"MENU\nTối giản"]) {
        UILabel *label = [self label:text size:11 weight:UIFontWeightMedium];
        label.numberOfLines = 2; label.textAlignment = NSTextAlignmentCenter;
        label.layer.cornerRadius = 10; label.clipsToBounds = YES;
        [features addObject:label];
    }
    self.featureLabels = features;
    self.fieldLabel = [self label:@"KEY TRUY CẬP" size:10 weight:UIFontWeightSemibold];
    self.keyField = [UITextField new]; self.keyField.placeholder = @"Nhập key của bạn";
    self.keyField.secureTextEntry = YES; self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.keyField.textContentType = UITextContentTypePassword; self.keyField.delegate = self;
    self.keyField.returnKeyType = UIReturnKeyGo; self.keyField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.keyField.layer.cornerRadius = 12; self.keyField.layer.borderWidth = 1;
    self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 15, 48)];
    self.keyField.leftViewMode = UITextFieldViewModeAlways;
    self.keyField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.card addSubview:self.keyField];
    self.submit = [self button:@"Đăng nhập" action:@selector(login)];
    self.start = [self button:@"Mở bảng điều khiển" action:@selector(startMenu)];
    self.logoutButton = [self button:@"Đăng xuất" action:@selector(logout)];
    self.status = [self label:@"Kết nối mạng để xác thực key." size:12 weight:UIFontWeightRegular];
    self.status.numberOfLines = 0;
    self.footer = [UILabel new]; self.footer.text = @"Ít nhiễu hơn. Nhiều tập trung hơn.";
    self.footer.font = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium]; self.footer.textAlignment = NSTextAlignmentCenter;
    [self.scroll addSubview:self.footer];
    self.theme = [UISwitch new]; self.theme.on = ESPDarkTheme();
    [self.theme addTarget:self action:@selector(themeChanged) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:self.theme];
    self.themeLabel = [UILabel new]; self.themeLabel.text = @"Giao diện tối";
    self.themeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.scroll addSubview:self.themeLabel];
    UITapGestureRecognizer *dismissKeyboard = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard:)];
    dismissKeyboard.cancelsTouchesInView = NO; dismissKeyboard.delegate = self;
    [self.view addGestureRecognizer:dismissKeyboard];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"wasAuthenticated"];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(licenseBecameInvalid:) name:LicenseSessionDidBecomeUnauthorizedNotification object:nil];
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
    [self applyAppearance]; [self updateControls];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.triedSavedKey) {
        self.triedSavedKey = YES;
        [self restoreSavedKey];
    }
    [self syncHUDState];
    [self.stateTimer invalidate];
    __weak _0xHOMEVC *weakSelf = self;
    self.stateTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        (void)timer; [weakSelf syncHUDState];
    }];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.stateTimer invalidate]; self.stateTimer = nil;
}
- (void)dealloc { [self.stateTimer invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    self.scroll.frame = UIEdgeInsetsInsetRect(self.view.bounds, safe);
    CGFloat availableWidth = self.scroll.bounds.size.width;
    CGFloat w = MAX(220, MIN(420, availableWidth - 36));
    CGFloat h = self.loggedIn ? 472 : 528;
    CGFloat keyboardInset = MAX(0, self.keyboardOverlap - safe.bottom);
    CGFloat usableHeight = self.scroll.bounds.size.height - keyboardInset;
    CGFloat cardY = MAX(76, (usableHeight - h) * 0.5);
    CGFloat cardX = (availableWidth - w) * 0.5;
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0, keyboardInset, 0);
    self.scroll.scrollIndicatorInsets = self.scroll.contentInset;
    self.card.frame = CGRectMake(cardX, cardY, w, h);
    CGFloat inset = w < 300 ? 20 : 28, content = w - inset * 2;
    self.brand.frame = CGRectMake(cardX, 22, 120, 30);
    self.monogram.frame = CGRectMake(inset, 24, 42, 42);
    self.eyebrow.frame = CGRectMake(inset + 54, 34, content - 54, 22);
    self.eyebrow.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.frame = CGRectMake(inset, 84, content, 78);
    self.titleLabel.adjustsFontSizeToFitWidth = YES; self.titleLabel.minimumScaleFactor = 0.7;
    self.subtitle.frame = CGRectMake(inset, 174, content, 42);
    CGFloat tileWidth = (content - 16) / 3;
    for (NSInteger i = 0; i < 3; ++i)
        self.featureLabels[i].frame = CGRectMake(inset + i * (tileWidth + 8), 236, tileWidth, 56);
    self.divider.frame = CGRectMake(inset, 310, content, 0.5);
    self.fieldLabel.frame = CGRectMake(inset, 330, content, 14);
    self.keyField.frame = CGRectMake(inset, 353, content, 48);
    self.submit.frame = CGRectMake(inset, 414, content, 48);
    self.start.frame = CGRectMake(inset, 330, content, 48);
    self.logoutButton.frame = CGRectMake(inset, 386, content, 30);
    self.status.frame = CGRectMake(inset, self.loggedIn ? 424 : 476, content, 40);
    self.theme.frame = CGRectMake(cardX + w - 51, 18, 51, 31);
    self.themeLabel.frame = CGRectMake(self.theme.frame.origin.x - 112, 18, 103, 31);
    self.footer.frame = CGRectMake(cardX, CGRectGetMaxY(self.card.frame) + 20, w, 20);
    self.scroll.contentSize = CGSizeMake(availableWidth, CGRectGetMaxY(self.footer.frame) + 24);
}
- (void)keyboardChanged:(NSNotification *)notification {
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self.view convertRect:screenFrame fromView:nil];
    self.keyboardOverlap = [notification.name isEqualToString:UIKeyboardWillHideNotification] ? 0 : MAX(0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frame));
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    if (self.keyField.isFirstResponder) {
        CGRect field = [self.keyField convertRect:self.keyField.bounds toView:self.scroll];
        [self.scroll scrollRectToVisible:CGRectInset(field, 0, -14) animated:NO];
    }
}
- (void)applyAppearance {
    BOOL dark = ESPDarkTheme();
    self.view.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    self.view.backgroundColor = MizzeBackground();
    self.card.backgroundColor = MizzeSurface();
    self.card.layer.borderColor = MizzeBorder().CGColor;
    UIColor *text = MizzeText(), *muted = MizzeMuted(), *accent = MizzeMint();
    self.brand.textColor = text;
    self.monogram.textColor = accent;
    self.monogram.backgroundColor = [accent colorWithAlphaComponent:0.12];
    for (UILabel *label in self.featureLabels) {
        label.textColor = muted; label.backgroundColor = MizzeRaised();
    }
    self.titleLabel.textColor = self.keyField.textColor = text;
    self.subtitle.textColor = self.status.textColor = self.themeLabel.textColor = muted;
    self.eyebrow.textColor = accent; self.fieldLabel.textColor = muted;
    self.footer.textColor = [UIColor colorWithWhite:dark ? 0.36 : 0.55 alpha:1];
    self.divider.backgroundColor = MizzeBorder();
    self.keyField.backgroundColor = [UIColor colorWithWhite:dark ? 0.037 : 0.978 alpha:1];
    self.keyField.layer.borderColor = [UIColor colorWithWhite:dark ? 0.22 : 0.84 alpha:1].CGColor;
    self.keyField.tintColor = self.theme.onTintColor = accent;
    for (UIButton *button in @[self.submit, self.start]) {
        button.backgroundColor = accent;
        [button setTitleColor:[UIColor colorWithWhite:0.065 alpha:1] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithWhite:0.065 alpha:0.45] forState:UIControlStateDisabled];
    }
    [self.logoutButton setTitleColor:muted forState:UIControlStateNormal];
}
- (void)themeChanged { ESPPrefsSetBool(@"DarkTheme", self.theme.on); [self applyAppearance]; }
- (void)dismissKeyboard:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) [self.view endEditing:YES];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    (void)gestureRecognizer;
    for (UIView *view = touch.view; view; view = view.superview) if ([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (void)updateControls {
    self.keyField.hidden = self.fieldLabel.hidden = self.submit.hidden = self.loggedIn;
    self.start.hidden = self.logoutButton.hidden = !self.loggedIn;
    self.start.enabled = !self.starting;
    [self.submit setTitle:([LicenseSession shared].hasSavedKey ? @"Xác thực / dùng key đã lưu" : @"Xác thực key") forState:UIControlStateNormal];
    self.subtitle.text = self.loggedIn ? [@"Phiên đã xác thực · " stringByAppendingString:[self licenseExpiryDescription]] : @"Nhập key để mở không gian điều khiển của bạn.";
    [self.start setTitle:IsHUDEnabled() ? @"Dừng bảng điều khiển" : @"Mở bảng điều khiển" forState:UIControlStateNormal];
    [self.view setNeedsLayout];
}
- (NSString *)licenseExpiryDescription {
    NSTimeInterval expiry = [LicenseSession shared].expiresAt;
    if (expiry <= 0) return @"Đang kiểm tra lại…";
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"vi_VN"];
    formatter.timeZone = NSTimeZone.localTimeZone;
    formatter.dateFormat = @"dd/MM/yyyy 'lúc' HH:mm:ss z";
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:expiry]];
}
- (void)showLicenseExpiry {
    if (!self.loggedIn || !self.view.window || self.presentedViewController) return;
    NSString *message = [NSString stringWithFormat:@"Key đã được xác thực.\nHạn sử dụng: %@", [self licenseExpiryDescription]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Key hợp lệ" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:NO completion:nil];
}
- (void)syncHUDState {
    if (!self.loggedIn || self.starting) return;
    BOOL running = IsHUDEnabled();
    if (self.hadRunningHUD && !running) self.status.text = HUDLastStatusMessage().length ? HUDLastStatusMessage() : @"Menu đã dừng. Bấm Start menu để mở lại.";
    self.hadRunningHUD = running;
    [self updateControls];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { (void)textField; [self login]; return YES; }
- (void)restoreSavedKey {
    if (self.loggedIn || self.restoringKey || ![LicenseSession shared].hasSavedKey) return;
    self.restoringKey = YES;
    self.submit.enabled = self.keyField.enabled = NO;
    self.status.text = @"Đang xác thực online key đã lưu…";
    const NSUInteger generation = ++self.requestGeneration;
    [[LicenseSession shared] refresh:^(BOOL ok, NSString *message) {
        if (generation != self.requestGeneration) return;
        self.restoringKey = NO;
        self.submit.enabled = self.keyField.enabled = YES;
        self.loggedIn = ok;
        self.status.text = message;
        if (ok) {
            [[LicenseSession shared] monitor];
            self.hadRunningHUD = IsHUDEnabled();
            [self showLicenseExpiry];
        }
        [self updateControls];
    }];
}
- (void)login {
    if (!self.submit.enabled) return;
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!key.length && [LicenseSession shared].hasSavedKey) { [self restoreSavedKey]; return; }
    if (key.length < 8 || key.length > 128) { self.status.text = @"Key cần từ 8 đến 128 ký tự."; return; }
    [self.view endEditing:YES]; self.submit.enabled = NO; self.keyField.enabled = NO;
    self.status.text = @"Đang xác thực key…";
    NSUInteger generation = ++self.requestGeneration;
    [[LicenseSession shared] loginWithKey:key completion:^(BOOL ok, NSString *message) {
        if (generation != self.requestGeneration) return;
        self.submit.enabled = YES; self.keyField.enabled = YES; self.loggedIn = ok; self.status.text = message;
        if (ok) { self.keyField.text = @""; [[LicenseSession shared] monitor]; }
        [self updateControls];
        if (ok) [self showLicenseExpiry];
    }];
}
- (void)startMenu {
    if (self.starting) return;
    if (IsHUDEnabled()) {
        ++self.requestGeneration; StopHUD(); self.hadRunningHUD = NO;
        self.status.text = @"Menu đã dừng."; [self updateControls]; return;
    }
    self.starting = YES; self.status.text = @"Đang kiểm tra phiên…"; [self updateControls];
    NSUInteger generation = ++self.requestGeneration;
    [[LicenseSession shared] refresh:^(BOOL ok, NSString *message) {
        if (generation != self.requestGeneration || !self.loggedIn) return;
        if (!ok) {
            self.starting = NO;
            if (![LicenseSession shared].authorized) self.loggedIn = NO;
            self.status.text = message; [self updateControls]; return;
        }
        NSError *error = nil;
        if (!StartHUD(&error)) {
            self.starting = NO;
            self.status.text = error.localizedDescription ?: @"Không khởi động được menu. Hãy thử lại.";
            [self updateControls]; return;
        }
        self.status.text = @"Đang mở nút menu…";
        [self waitForHUDStart:0 generation:generation];
    }];
}
- (void)waitForHUDStart:(NSInteger)attempt generation:(NSUInteger)generation {
    if (generation != self.requestGeneration || !self.loggedIn || !self.starting) return;
    if (IsHUDEnabled()) {
        self.starting = NO; self.hadRunningHUD = YES;
        self.status.text = @"Menu đang chạy. Chạm nút Mizze để mở.";
        [self updateControls]; return;
    }
    if (attempt >= 200) {
        self.starting = NO;
        NSString *message = HUDLastStatusMessage();
        StopHUD(); self.status.text = message.length ? message : @"Menu chưa sẵn sàng. Hãy bấm Start menu để thử lại.";
        [self updateControls]; return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self waitForHUDStart:attempt + 1 generation:generation];
    });
}
- (void)logout {
    self.restoringKey = NO;
    ++self.requestGeneration; self.starting = NO; self.hadRunningHUD = NO;
    StopHUD(); [[LicenseSession shared] logout];
    self.loggedIn = NO; self.keyField.text = @""; self.status.text = @"Đã đăng xuất.";
    self.submit.enabled = self.keyField.enabled = YES; [self updateControls];
}
- (void)licenseBecameInvalid:(NSNotification *)notification {
    // A parent app can be suspended long enough for its short local lease to
    // expire while the separate HUD process is still refreshing online. Wait
    // for the next foreground refresh before clearing the login screen; hard
    // revocation (deleted, disabled, or expired records) uses another reason.
    if ([notification.userInfo[@"reason"] isEqualToString:@"lease_expired"]) {
        self.status.text = @"Đang chờ kiểm tra lại key khi có mạng…";
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self _0xDAH2863]; });
        }
        return;
    }
    ++self.requestGeneration; self.starting = NO; self.hadRunningHUD = NO;
    self.restoringKey = NO;
    StopHUDWithMessage(notification.userInfo[@"message"] ?: [LicenseSession shared].lastMessage); self.loggedIn = NO;
    self.submit.enabled = self.keyField.enabled = YES;
    self.status.text = notification.userInfo[@"message"] ?: [LicenseSession shared].lastMessage ?: @"Phiên truy cập đã kết thúc. Vui lòng nhập lại key.";
    [self updateControls];
}
- (void)_0xDAH2863 {
    if (!self.isViewLoaded || self.starting || self.restoringKey) return;
    if (!self.loggedIn) { [self restoreSavedKey]; return; }
    NSUInteger generation = self.requestGeneration;
    [[LicenseSession shared] refresh:^(BOOL ok, NSString *message) {
        if (generation != self.requestGeneration) return;
        if (!ok) {
            self.status.text = message;
            // The HUD owns its own online lease. Its monitor handles loss of
            // connectivity; a suspended parent's expired lease is not proof
            // that the HUD's key was revoked.
            if (![LicenseSession shared].authorized) self.loggedIn = NO;
        }
        if (ok) [[LicenseSession shared] monitor];
        [self updateControls];
    }];
}
@end
