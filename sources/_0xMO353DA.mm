#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPStyle.h"
#import <objc/runtime.h>
#import "UIView+SecureView.h"

@interface _0xDEADBEEE () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIVisualEffectView *glass;
@property (nonatomic, strong) CAGradientLayer *shine;
@property (nonatomic, strong) NSArray<UIButton *> *navButtons;
@property (nonatomic, assign) CGFloat builtWidth;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSMutableArray<UIControl *> *controls;
@property (nonatomic, strong) UILabel *swatch;
@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger colorTarget;
@property (nonatomic, assign) NSInteger pointer;
@property (nonatomic, assign) CGPoint began;
@property (nonatomic, assign) CGPoint panelOrigin;
@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) BOOL dragging;
@property (nonatomic, assign) BOOL scrolling;
@property (nonatomic, strong) UIControl *activeControl;
@end

@implementation _0xDEADBEEE
- (UIColor *)textColor { return ESPDarkTheme() ? [UIColor colorWithWhite:0.94 alpha:1] : [UIColor colorWithWhite:0.08 alpha:1]; }
- (UIColor *)mutedColor { return ESPDarkTheme() ? [UIColor colorWithWhite:0.55 alpha:1] : [UIColor colorWithWhite:0.45 alpha:1]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.pointer = -1;
    self.controls = [NSMutableArray array];
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(24, 20, 440, 360)];
    self.panel.layer.cornerRadius = 24;
    self.panel.layer.borderWidth = 1;
    self.panel.clipsToBounds = YES;
    [self.view addSubview:self.panel];
    self.glass = [[UIVisualEffectView alloc] initWithEffect:nil];
    self.glass.userInteractionEnabled = NO;
    [self.panel addSubview:self.glass];
    self.shine = [CAGradientLayer layer];
    self.shine.startPoint = CGPointMake(0, 0);
    self.shine.endPoint = CGPointMake(1, 1);
    [self.glass.contentView.layer addSublayer:self.shine];
    self.header = [[UIView alloc] initWithFrame:CGRectZero];
    [self.panel addSubview:self.header];
    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectMake(18, 11, 220, 23)];
    brand.text = @"Mizze – Free Fire";
    brand.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    brand.adjustsFontSizeToFitWidth = YES; brand.minimumScaleFactor = 0.7;
    brand.tag = 10;
    [self.header addSubview:brand];
    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 35, 220, 14)];
    caption.text = @"CONTROL CENTER";
    caption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    caption.tag = 11;
    [self.header addSubview:caption];
    UILabel *logo = [self label:@"M" frame:CGRectMake(14, 14, 42, 42) size:27];
    logo.tag = 13; logo.textAlignment = NSTextAlignmentCenter;
    logo.layer.cornerRadius = 13; logo.layer.borderWidth = 1;
    logo.layer.borderColor = [UIColor colorWithRed:0.53 green:0.79 blue:1 alpha:0.6].CGColor;
    logo.textColor = [UIColor colorWithRed:0.65 green:0.92 blue:1 alpha:1];
    [self.header addSubview:logo];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(268, 10, 32, 36);
    close.tag = 12;
    close.layer.cornerRadius = 12; close.layer.borderWidth = 0.7;
    close.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightMedium];
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];
    NSMutableArray *navigation = [NSMutableArray array];
    NSArray *symbols = @[@"scope", @"eye", @"paintpalette", @"slider.horizontal.3"];
    NSArray *names = @[@"Aim", @"ESP", @"Màu", @"Giao diện"];
    for (NSInteger i = 0; i < 4; ++i) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = 200 + i; button.accessibilityLabel = names[i];
        [button setImage:[UIImage systemImageNamed:symbols[i]] forState:UIControlStateNormal];
        button.layer.cornerRadius = 14; button.layer.borderWidth = 0.8;
        [button addTarget:self action:@selector(changePage:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:button]; [navigation addObject:button];
    }
    self.navButtons = navigation;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHeader:)];
    pan.delegate = self; [self.header addGestureRecognizer:pan];
    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.showsVerticalScrollIndicator = YES;
    self.scroll.bounces = NO;
    [self.panel addSubview:self.scroll];
    [self buildPage];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat screenW = self.view.bounds.size.width;
    CGFloat screenH = self.view.bounds.size.height;
    if (screenW <= 0) screenW = 320.0f;
    if (screenH <= 0) screenH = 480.0f;

    CGFloat w = MIN(440.0f, MAX(200.0f, screenW - 16.0f));
    CGFloat h = MIN(500.0f, MAX(250.0f, screenH - 16.0f));
    CGRect f = self.panel.frame;
    f.size = CGSizeMake(w, h);
    f.origin.x = MAX(8.0f, MIN(f.origin.x, screenW - w - 8.0f));
    f.origin.y = MAX(8.0f, MIN(f.origin.y, screenH - h - 8.0f));
    self.panel.frame = f;
    self.glass.frame = self.panel.bounds; self.shine.frame = self.panel.bounds;
    self.header.frame = CGRectMake(0, 0, w, 76);
    [self.header viewWithTag:10].frame = CGRectMake(68, 16, MAX(10, w - 132), 24);
    [self.header viewWithTag:11].frame = CGRectMake(68, 43, MAX(10, w - 132), 16);
    
    UIView *closeBtn = [self.header viewWithTag:12];
    if (closeBtn) closeBtn.frame = CGRectMake(MAX(0.0f, w - 54.0f), 16, 38, 40);
    CGFloat navStep = MIN(62, MAX(40, (h - 92) / 4));
    for (NSInteger i = 0; i < 4; ++i)
        self.navButtons[i].frame = CGRectMake(13, 84 + i * navStep, 44, MIN(48, navStep - 5));
    self.scroll.frame = CGRectMake(68, 82, MAX(10, w - 80), MAX(10, h - 94));
    if (fabs(self.builtWidth - self.scroll.bounds.size.width) > 0.5) [self buildPage];
}
- (void)closeMenu { if (self.onCloseBlock) self.onCloseBlock(); }
- (void)changePage:(UIButton *)sender {
    self.page = sender.tag - 200;
    [self buildPage];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != self.header; view = view.superview)
        if ([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (void)dragHeader:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) self.panelOrigin = self.panel.frame.origin;
    CGPoint delta = [pan translationInView:self.view];
    CGRect frame = self.panel.frame;
    frame.origin = CGPointMake(self.panelOrigin.x + delta.x, self.panelOrigin.y + delta.y);
    self.panel.frame = frame; [self viewDidLayoutSubviews];
}
- (CGFloat)contentWidth { return self.scroll.bounds.size.width > 10 ? self.scroll.bounds.size.width : 360; }
- (NSString *)colorPrefix {
    NSArray *prefixes = @[@"BoxColor", @"LineColor", @"FovColor"];
    NSInteger idx = MAX(0, MIN((NSInteger)prefixes.count - 1, self.colorTarget));
    return prefixes[idx];
}
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text; label.textColor = [self textColor];
    label.font = [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    return label;
}
- (CGFloat)toggle:(NSString *)title key:(NSString *)key fallback:(BOOL)fallback y:(CGFloat)y {
    CGFloat width = [self contentWidth];
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 50)];
    row.backgroundColor = ESPDarkTheme() ? [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.06f] : [UIColor colorWithWhite:0 alpha:0.03f];
    row.layer.cornerRadius = 15;
    row.layer.borderWidth = 0.8f;
    row.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25f].CGColor;
    UILabel *titleLabel = [self label:title frame:CGRectMake(14, 0, MAX(10, width - 80), 50) size:14];
    titleLabel.adjustsFontSizeToFitWidth = YES; titleLabel.minimumScaleFactor = 0.75;
    [row addSubview:titleLabel];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(width - 59, 9, 51, 31)];
    sw.transform = CGAffineTransformMakeScale(0.82, 0.82);
    sw.onTintColor = [UIColor colorWithRed:0.22 green:0.83 blue:0.43 alpha:1];
    sw.on = ESPPrefsBool(key, fallback);
    objc_setAssociatedObject(sw, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw]; [self.controls addObject:sw]; [self.scroll addSubview:row];
    return y + 60;
}
- (CGFloat)slider:(NSString *)title key:(NSString *)key min:(float)minimum max:(float)maximum fallback:(float)fallback y:(CGFloat)y {
    CGFloat width = [self contentWidth];
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 76)];
    row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    row.layer.cornerRadius = 15; row.layer.borderWidth = 0.8;
    row.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    UILabel *label = [self label:title frame:CGRectMake(14, 8, width - 28, 20) size:12];
    [row addSubview:label];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(14, 36, width - 28, 30)];
    slider.minimumValue = minimum; slider.maximumValue = maximum;
    slider.value = ESPPrefsFloat(key, fallback);
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.22 green:0.83 blue:0.43 alpha:1];
    objc_setAssociatedObject(slider, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(slider, "label", label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, "title", title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:slider]; [self.controls addObject:slider]; [self.scroll addSubview:row];
    [self updateSliderLabel:slider];
    return y + 86;
}
- (CGFloat)note:(NSString *)text y:(CGFloat)y {
    UILabel *label = [self label:text frame:CGRectMake(8, y, [self contentWidth] - 16, 44) size:11];
    label.textColor = [self mutedColor]; label.numberOfLines = 0;
    [self.scroll addSubview:label]; return y + 48;
}
- (void)buildPage {
    for (UIView *v in self.scroll.subviews) [v removeFromSuperview];
    [self.controls removeAllObjects]; self.swatch = nil;
    self.builtWidth = [self contentWidth];
    self.panel.backgroundColor = UIColor.clearColor;
    self.glass.effect = [UIBlurEffect effectWithStyle:ESPDarkTheme() ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight];
    self.shine.colors = @[(__bridge id)[UIColor colorWithWhite:1 alpha:0.16].CGColor,
                         (__bridge id)[UIColor colorWithRed:0.15 green:0.12 blue:0.23 alpha:0.10].CGColor,
                         (__bridge id)[UIColor colorWithWhite:1 alpha:0.05].CGColor];
    self.panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.42].CGColor;
    ((UILabel *)[self.header viewWithTag:10]).textColor = [self textColor];
    ((UILabel *)[self.header viewWithTag:11]).textColor = [self mutedColor];
    [(UIButton *)[self.header viewWithTag:12] setTitleColor:[self mutedColor] forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) self.panel.overrideUserInterfaceStyle = ESPDarkTheme() ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    for (NSInteger i = 0; i < 4; ++i) {
        UIButton *button = self.navButtons[i];
        button.tintColor = [self textColor];
        button.backgroundColor = [UIColor colorWithWhite:1 alpha:i == self.page ? 0.18 : 0.04];
        button.layer.borderColor = [UIColor colorWithWhite:1 alpha:i == self.page ? 0.65 : 0.2].CGColor;
        button.accessibilityValue = i == self.page ? @"Đang chọn" : @"";
    }
    UIView *section = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [self contentWidth], 64)];
    section.layer.cornerRadius = 16; section.layer.borderWidth = 0.8;
    section.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    NSArray *titles = @[@"AIM", @"HIỂN THỊ ESP", @"MÀU SẮC", @"GIAO DIỆN & GHI HÌNH"];
    [section addSubview:[self label:titles[self.page] frame:CGRectMake(14, 8, [self contentWidth] - 28, 22) size:13]];
    UILabel *summary = [self label:@"Lựa chọn được lưu tự động." frame:CGRectMake(14, 33, [self contentWidth] - 28, 20) size:11];
    summary.textColor = [self mutedColor]; [section addSubview:summary]; [self.scroll addSubview:section];
    CGFloat y = 74;
    if (self.page == 0) {
        y = [self toggle:@"Aim không mở ngắm" key:@"AimbotFire" fallback:YES y:y];
        UISegmentedControl *mode = [[UISegmentedControl alloc] initWithItems:@[@"Chỉ khi bắn", @"Luôn trong FOV"]];
        mode.frame = CGRectMake(8, y, [self contentWidth] - 16, 34);
        mode.tag = 102;
        mode.selectedSegmentIndex = ESPPrefsBool(@"AimHipAlways", NO) ? 1 : 0;
        [mode addTarget:self action:@selector(aimModeChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:mode]; [self.controls addObject:mode]; y += 44;
        y = [self note:@"Chỉ khi bắn: bắt đầu ghim khi bắn, ngừng khi nhả bắn. Luôn: ghim khi mục tiêu trong FOV." y:y];
        y = [self toggle:@"Aim khi mở ngắm" key:@"AimbotScope" fallback:YES y:y];
        y = [self toggle:@"Aim cổ" key:@"AimNeck" fallback:NO y:y];
        y = [self toggle:@"Hiện vòng FOV" key:@"ShowFov" fallback:YES y:y];
        y = [self slider:@"Kích thước FOV" key:@"FovSize" min:5 max:150 fallback:40 y:y + 6];
        y = [self note:@"Chỉ aim khi điểm ngắm nằm trong vòng. Ẩn vòng vẫn giữ giới hạn FOV." y:y];
        y = [self note:@"Aim cổ lấy điểm sát dưới đầu. Tắt để aim đầu." y:y];
        y = [self toggle:@"Chẩn đoán aim" key:@"AimDiagnostics" fallback:NO y:y];
    } else if (self.page == 1) {
        y = [self toggle:@"Tên người chơi" key:@"Name" fallback:YES y:y];
        y = [self toggle:@"Thanh máu" key:@"Health" fallback:YES y:y];
        y = [self toggle:@"Đường nối" key:@"Line" fallback:NO y:y];
        y = [self toggle:@"Khung người chơi" key:@"Box" fallback:YES y:y];
        y = [self toggle:@"Xương người chơi" key:@"Skeleton" fallback:NO y:y];
        y = [self toggle:@"Điểm đánh dấu đầu" key:@"HeadRedDot" fallback:YES y:y];
        y = [self toggle:@"Khoảng cách" key:@"Dis" fallback:YES y:y];
        UILabel *boxLabel = [self label:@"Kiểu khung" frame:CGRectMake(8, y + 4, [self contentWidth] - 16, 20) size:12];
        [self.scroll addSubview:boxLabel];
        UISegmentedControl *boxStyle = [[UISegmentedControl alloc] initWithItems:@[@"2D", @"3D"]];
        boxStyle.frame = CGRectMake(8, y + 28, [self contentWidth] - 16, 30);
        boxStyle.tag = 101;
        boxStyle.selectedSegmentIndex = ESPPrefsBool(@"Box3D", YES) ? 1 : 0;
        [boxStyle addTarget:self action:@selector(boxStyleChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:boxStyle]; [self.controls addObject:boxStyle];
        y += 70;
    } else if (self.page == 2) {
        UISegmentedControl *target = [[UISegmentedControl alloc] initWithItems:@[@"Box", @"Line", @"FOV"]];
        target.frame = CGRectMake(8, y, [self contentWidth] - 16, 30); target.selectedSegmentIndex = self.colorTarget;
        [target addTarget:self action:@selector(colorTargetChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:target]; [self.controls addObject:target];
        self.swatch = [self label:@"" frame:CGRectMake(8, y + 42, [self contentWidth] - 16, 38) size:12];
        self.swatch.textAlignment = NSTextAlignmentCenter; self.swatch.layer.cornerRadius = 9; self.swatch.clipsToBounds = YES;
        [self.scroll addSubview:self.swatch]; y += 92;
        NSString *prefix = [self colorPrefix];
        float defaults[3] = {0.72f, 0.91f, 1}; if(self.colorTarget == 2) defaults[0] = defaults[1] = 1;
        NSArray *names = @[@"Đỏ", @"Lục", @"Lam"], *suffixes = @[@"R", @"G", @"B"];
        for (int i = 0; i < 3; ++i) y = [self slider:names[i] key:[prefix stringByAppendingString:suffixes[i]] min:0 max:1 fallback:defaults[i] y:y];
        [self updateSwatch];
    } else {
        y = [self toggle:@"Ẩn khi chụp / quay" key:@"AnLive" fallback:NO y:y];
        y = [self note:@"Áp dụng cho menu, nút nổi và ESP. Hãy thử ảnh/video trên iOS của bạn trước khi live." y:y];
        y = [self toggle:@"Giao diện tối" key:@"DarkTheme" fallback:YES y:y];
        y = [self toggle:@"ESP ổn định (30 FPS)" key:@"BalancedRender" fallback:YES y:y];
        y = [self note:@"Bật để giảm tải khi chơi lâu. Tắt để vẽ ESP ở 60 FPS." y:y];
        y = [self note:@"Kéo thanh tiêu đề để di chuyển menu. Các lựa chọn được lưu tự động." y:y];
    }
    self.scroll.contentSize = CGSizeMake([self contentWidth], y + 8);
    self.scroll.contentOffset = CGPointZero;
}
- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    ESPPrefsSetBool(key, sender.on); ESPSyncFromPrefs();
    if ([key isEqualToString:@"AnLive"] && ![UIView applyCaptureProtectionToRegisteredViews:sender.on]) {
        sender.on = NO; ESPPrefsSetBool(key, NO);
        [UIView applyCaptureProtectionToRegisteredViews:NO];
        [self note:@"iOS này không hỗ trợ cơ chế ẩn hiện tại." y:self.scroll.contentSize.height];
        self.scroll.contentSize = CGSizeMake([self contentWidth], self.scroll.contentSize.height + 48);
    }
    if ([key isEqualToString:@"DarkTheme"]) [self buildPage];
}
- (void)colorTargetChanged:(UISegmentedControl *)sender {
    self.colorTarget = sender.selectedSegmentIndex; [self buildPage];
}
- (void)boxStyleChanged:(UISegmentedControl *)sender {
    ESPPrefsSetBool(@"Box3D", sender.selectedSegmentIndex == 1);
    ESPSyncFromPrefs();
}
- (void)aimModeChanged:(UISegmentedControl *)sender {
    ESPPrefsSetBool(@"AimHipAlways", sender.selectedSegmentIndex == 1);
    ESPSyncFromPrefs();
}
- (void)updateSliderLabel:(UISlider *)sender {
    UILabel *label = objc_getAssociatedObject(sender, "label");
    NSString *key = objc_getAssociatedObject(sender, "key"), *title = objc_getAssociatedObject(sender, "title");
    label.text = [key isEqualToString:@"FovSize"] ? [NSString stringWithFormat:@"%@   %.0f%%", title, sender.value] : [NSString stringWithFormat:@"%@   %.0f", title, sender.value * 255];
}
- (void)sliderChanged:(UISlider *)sender {
    ESPPrefsSetFloat(objc_getAssociatedObject(sender, "key"), sender.value);
    ESPSyncFromPrefs(); [self updateSliderLabel:sender]; [self updateSwatch];
}
- (void)updateSwatch {
    if (!self.swatch) return;
    NSString *prefix = [self colorPrefix];
    if (!prefix) return;
    UIColor *color = ESPColor(prefix, self.colorTarget == 2 ? 1 : 0.72, self.colorTarget == 2 ? 1 : 0.91, 1);
    if (!color) return;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        self.swatch.backgroundColor = color;
        self.swatch.textColor = (r * 0.299 + g * 0.587 + b * 0.114) > 0.6 ? UIColor.blackColor : UIColor.whiteColor;
        self.swatch.text = [NSString stringWithFormat:@"#%02X%02X%02X", (int)round(r * 255), (int)round(g * 255), (int)round(b * 255)];
    }
}
- (void)setSlider:(UISlider *)slider point:(CGPoint)point {
    CGPoint p = [slider convertPoint:point fromView:self.view];
    CGFloat ratio = MAX(0, MIN(1, (p.x - 14) / MAX(1, slider.bounds.size.width - 28)));
    slider.value = slider.minimumValue + ratio * (slider.maximumValue - slider.minimumValue);
    [self sliderChanged:slider];
}
// The system-wide HUD receives forwarded touches, so controls also route here.
- (BOOL)_0xF010:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    if (phase == UITouchPhaseBegan) {
        if (!CGRectContainsPoint(self.panel.frame, point)) return NO;
        if (self.pointer != -1) return YES;
        self.pointer = pointerId; self.began = point; self.panelOrigin = self.panel.frame.origin;
        self.scrollOrigin = self.scroll.contentOffset.y; self.scrolling = NO; self.activeControl = nil;
        CGPoint local = [self.panel convertPoint:point fromView:self.view];
        self.dragging = local.y < 76 && local.x < self.panel.bounds.size.width - 58;
        if (self.dragging) return YES;
        NSMutableArray *fixed = [NSMutableArray array];
        [fixed addObjectsFromArray:self.navButtons];
        UIView *closeBtn = [self.header viewWithTag:12];
        if ([closeBtn isKindOfClass:[UIControl class]]) [fixed addObject:closeBtn];
        for (UIControl *c in fixed) if (CGRectContainsPoint(c.bounds, [c convertPoint:point fromView:self.view])) self.activeControl = c;
        if (CGRectContainsPoint(self.scroll.bounds, [self.scroll convertPoint:point fromView:self.view])) {
            for (UIControl *c in self.controls) {
                CGRect hit = c.bounds;
                if ([c isKindOfClass:UISwitch.class]) hit = CGRectMake(-MAX(0, [self contentWidth] - 65), -8, [self contentWidth], 48);
                if (CGRectContainsPoint(hit, [c convertPoint:point fromView:self.view])) { self.activeControl = c; break; }
            }
        }
        if ([self.activeControl isKindOfClass:UISlider.class]) [self setSlider:(UISlider *)self.activeControl point:point];
        return YES;
    }
    if (self.pointer != pointerId) return NO;
    CGFloat dx = point.x - self.began.x, dy = point.y - self.began.y;
    if (phase == UITouchPhaseMoved) {
        if (self.dragging) {
            CGRect f = self.panel.frame; f.origin = CGPointMake(self.panelOrigin.x + dx, self.panelOrigin.y + dy); self.panel.frame = f;
            [self viewDidLayoutSubviews];
        } else if ([self.activeControl isKindOfClass:UISlider.class]) {
            [self setSlider:(UISlider *)self.activeControl point:point];
        } else if (fabs(dy) > 7 || self.scrolling) {
            self.scrolling = YES;
            CGFloat maxY = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
            self.scroll.contentOffset = CGPointMake(0, MAX(0, MIN(maxY, self.scrollOrigin - dy)));
        }
        return YES;
    }
    if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        UIControl *control = self.activeControl;
        BOOL activate = phase == UITouchPhaseEnded && !self.dragging && !self.scrolling && fabs(dx) < 24 && fabs(dy) < 24;
        self.pointer = -1; self.activeControl = nil;
        if (activate && [control isKindOfClass:UISwitch.class]) {
            UISwitch *sw = (UISwitch *)control; [sw setOn:!sw.on animated:NO]; [self toggleChanged:sw];
        } else if (activate && [control isKindOfClass:UISegmentedControl.class]) {
            UISegmentedControl *seg = (UISegmentedControl *)control;
            CGPoint p = [seg convertPoint:point fromView:self.view];
            seg.selectedSegmentIndex = MAX(0, MIN(seg.numberOfSegments - 1, (NSInteger)(p.x / (seg.bounds.size.width / seg.numberOfSegments))));
            if (seg.tag == 101) [self boxStyleChanged:seg];
            else if (seg.tag == 102) [self aimModeChanged:seg];
            else [self colorTargetChanged:seg];
        } else if (activate && [control isKindOfClass:UIButton.class]) {
            if (control.tag >= 200 && control.tag < 204) [self changePage:(UIButton *)control];
            else [self closeMenu];
        }
        return YES;
    }
    return YES;
}
@end
