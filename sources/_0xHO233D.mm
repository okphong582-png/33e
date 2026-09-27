#import "HomeViewController.h"
#import "HUDHelper.h"
#import "LicenseSession.h"
#import "../esp/drawing_view/ESPStyle.h"

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
    self.card = [UIView new]; self.card.layer.cornerRadius = 24; self.card.layer.borderWidth = 1;
    [self.scroll addSubview:self.card];
    self.eyebrow = [self label:@"P E R S O N A L   A C C E S S" size:10 weight:UIFontWeightSemibold];
    self.titleLabel = [self label:@"HOANGHA" size:32 weight:UIFontWeightBold];
    self.subtitle = [self label:@"Nhập key để mở bảng điều khiển của bạn." size:13 weight:UIFontWeightRegular];
    self.subtitle.numberOfLines = 2;
    self.divider = [UIView new]; [self.card addSubview:self.divider];
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
    self.start = [self button:@"Start menu" action:@selector(startMenu)];
    self.logoutButton = [self button:@"Đăng xuất" action:@selector(logout)];
    self.status = [self label:@"Kết nối mạng để xác thực key." size:12 weight:UIFontWeightRegular];
    self.status.numberOfLines = 0;
    self.footer = [UILabel new]; self.footer.text = @"HOANGHA  /  CONTROL CENTER";
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
    [self syncHUDState];
    __weak typeof(self) weakSelf = self;
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
    CGFloat h = self.loggedIn ? 344 : 400;
    CGFloat keyboardInset = MAX(0, self.keyboardOverlap - safe.bottom);
    CGFloat usableHeight = self.scroll.bounds.size.height - keyboardInset;
    CGFloat cardY = MAX(78, (usableHeight - h) * 0.5);
    CGFloat cardX = (availableWidth - w) * 0.5;
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0, keyboardInset, 0);
    self.scroll.scrollIndicatorInsets = self.scroll.contentInset;
    self.card.frame = CGRectMake(cardX, cardY, w, h);
    CGFloat inset = w < 300 ? 20 : 28, content = w - inset * 2;
    self.eyebrow.frame = CGRectMake(inset, 27, content, 15);
    self.titleLabel.frame = CGRectMake(inset, 51, content, 41);
    self.subtitle.frame = CGRectMake(inset, 104, content, 36);
    self.divider.frame = CGRectMake(inset, 155, content, 1);
    self.fieldLabel.frame = CGRectMake(inset, 174, content, 14);
    self.keyField.frame = CGRectMake(inset, 197, content, 50);
    self.submit.frame = CGRectMake(inset, 261, content, 50);
    self.start.frame = CGRectMake(inset, 180, content, 50);
    self.logoutButton.frame = CGRectMake(inset, 239, content, 40);
    self.status.frame = CGRectMake(inset, self.loggedIn ? 290 : 326, content, self.loggedIn ? 38 : 50);
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
    self.view.backgroundColor = [UIColor colorWithWhite:dark ? 0.025 : 0.955 alpha:1];
    self.card.backgroundColor = [UIColor colorWithWhite:dark ? 0.066 : 1 alpha:1];
    self.card.layer.borderColor = [UIColor colorWithWhite:dark ? 0.16 : 0.875 alpha:1].CGColor;
    UIColor *text = [UIColor colorWithWhite:dark ? 0.96 : 0.1 alpha:1];
    UIColor *muted = [UIColor colorWithWhite:dark ? 0.61 : 0.43 alpha:1];
    UIColor *accent = [UIColor colorWithRed:0.30 green:0.53 blue:0.96 alpha:1];
    self.titleLabel.textColor = self.keyField.textColor = text;
    self.subtitle.textColor = self.status.textColor = self.themeLabel.textColor = muted;
    self.eyebrow.textColor = accent; self.fieldLabel.textColor = muted;
    self.footer.textColor = [UIColor colorWithWhite:dark ? 0.36 : 0.55 alpha:1];
    self.divider.backgroundColor = [UIColor colorWithWhite:dark ? 0.15 : 0.91 alpha:1];
    self.keyField.backgroundColor = [UIColor colorWithWhite:dark ? 0.037 : 0.978 alpha:1];
    self.keyField.layer.borderColor = [UIColor colorWithWhite:dark ? 0.22 : 0.84 alpha:1].CGColor;
    self.keyField.tintColor = self.theme.onTintColor = accent;
    for (UIButton *button in @[self.submit, self.start]) {
        button.backgroundColor = accent;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithWhite:1 alpha:0.5] forState:UIControlStateDisabled];
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
    self.subtitle.text = self.loggedIn ? @"Key đã xác thực. Mở menu khi bạn sẵn sàng." : @"Nhập key để mở bảng điều khiển của bạn.";
    [self.start setTitle:IsHUDEnabled() ? @"Stop menu" : @"Start menu" forState:UIControlStateNormal];
    [self.view setNeedsLayout];
}
- (void)syncHUDState {
    if (!self.loggedIn || self.starting) return;
    BOOL running = IsHUDEnabled();
    if (self.hadRunningHUD && !running) self.status.text = HUDLastStatusMessage().length ? HUDLastStatusMessage() : @"Menu đã dừng. Bấm Start menu để mở lại.";
    self.hadRunningHUD = running;
    [self updateControls];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { (void)textField; [self login]; return YES; }
- (void)login {
    if (!self.submit.enabled) return;
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (key.length < 8 || key.length > 128) { self.status.text = @"Key cần từ 8 đến 128 ký tự."; return; }
    [self.view endEditing:YES]; self.submit.enabled = NO; self.keyField.enabled = NO;
    self.status.text = @"Đang xác thực key…";
    NSUInteger generation = ++self.requestGeneration;
    [[LicenseSession shared] loginWithKey:key completion:^(BOOL ok, NSString *message) {
        if (generation != self.requestGeneration) return;
        self.submit.enabled = YES; self.keyField.enabled = YES; self.loggedIn = ok; self.status.text = message;
        if (ok) { self.keyField.text = @""; [[LicenseSession shared] monitor]; }
        [self updateControls];
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
        self.status.text = @"Menu đang chạy. Chạm nút GIF nổi để mở.";
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
    StopHUD(); self.loggedIn = NO;
    self.submit.enabled = self.keyField.enabled = YES;
    self.status.text = notification.userInfo[@"message"] ?: [LicenseSession shared].lastMessage ?: @"Phiên truy cập đã kết thúc. Vui lòng nhập lại key.";
    [self updateControls];
}
- (void)_0xDAH2863 {
    if (!self.isViewLoaded || !self.loggedIn || self.starting) return;
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
