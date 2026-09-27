#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPStyle.h"
#import <objc/runtime.h>

@interface _0xDEADBEEE ()
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UISegmentedControl *tabs;
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
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(24, 20, 310, 360)];
    self.panel.layer.cornerRadius = 20;
    self.panel.layer.borderWidth = 1.2f;
    self.panel.clipsToBounds = YES;
    [self.view addSubview:self.panel];
    self.header = [[UIView alloc] initWithFrame:CGRectZero];
    [self.panel addSubview:self.header];
    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectMake(18, 11, 220, 23)];
    brand.text = @"HOANGHA VIP";
    brand.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    brand.tag = 10;
    [self.header addSubview:brand];
    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 35, 220, 14)];
    caption.text = @"BẢNG ĐIỀU KHIỂN ESP & AIMBOT";
    caption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    caption.tag = 11;
    [self.header addSubview:caption];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(268, 10, 32, 36);
    close.tag = 12;
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightMedium];
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];
    self.tabs = [[UISegmentedControl alloc] initWithItems:@[@"🎯 Aim", @"👁️ ESP", @"🎨 Màu", @"⚙️ Khác"]];
    self.tabs.selectedSegmentIndex = 0;
    [self.tabs addTarget:self action:@selector(changeTab:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:self.tabs];
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

    CGFloat w = MIN(310.0f, MAX(200.0f, screenW - 16.0f));
    CGFloat h = MIN(500.0f, MAX(250.0f, screenH - 16.0f));
    CGRect f = self.panel.frame;
    f.size = CGSizeMake(w, h);
    f.origin.x = MAX(8.0f, MIN(f.origin.x, screenW - w - 8.0f));
    f.origin.y = MAX(8.0f, MIN(f.origin.y, screenH - h - 8.0f));
    self.panel.frame = f;
    self.header.frame = CGRectMake(0, 0, w, 58);
    
    UIView *closeBtn = [self.header viewWithTag:12];
    if (closeBtn) closeBtn.frame = CGRectMake(MAX(0.0f, w - 42.0f), 10, 32, 36);
    self.tabs.frame = CGRectMake(12, 62, MAX(10.0f, w - 24.0f), 30);
    self.scroll.frame = CGRectMake(0, 104, w, MAX(10.0f, h - 112.0f));
}
- (void)closeMenu { if (self.onCloseBlock) self.onCloseBlock(); }
- (void)changeTab:(UISegmentedControl *)sender {
    self.page = sender.selectedSegmentIndex;
    [self buildPage];
}
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
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(12, y, 286, 48)];
    row.backgroundColor = ESPDarkTheme() ? [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.06f] : [UIColor colorWithWhite:0 alpha:0.03f];
    row.layer.cornerRadius = 12;
    row.layer.borderWidth = 0.5f;
    row.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08f].CGColor;
    [row addSubview:[self label:title frame:CGRectMake(14, 0, 210, 48) size:13]];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(226, 9, 51, 31)];
    sw.transform = CGAffineTransformMakeScale(0.82, 0.82);
    sw.onTintColor = [UIColor colorWithRed:0.0f green:0.75f blue:1.0f alpha:1.0f];
    sw.on = ESPPrefsBool(key, fallback);
    objc_setAssociatedObject(sw, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw]; [self.controls addObject:sw]; [self.scroll addSubview:row];
    return y + 54;
}
- (CGFloat)slider:(NSString *)title key:(NSString *)key min:(float)minimum max:(float)maximum fallback:(float)fallback y:(CGFloat)y {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(18, y, 274, 66)];
    UILabel *label = [self label:title frame:CGRectMake(0, 0, 274, 20) size:12];
    [row addSubview:label];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 25, 274, 30)];
    slider.minimumValue = minimum; slider.maximumValue = maximum;
    slider.value = ESPPrefsFloat(key, fallback);
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.0f green:0.75f blue:1.0f alpha:1.0f];
    objc_setAssociatedObject(slider, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(slider, "label", label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, "title", title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:slider]; [self.controls addObject:slider]; [self.scroll addSubview:row];
    [self updateSliderLabel:slider];
    return y + 70;
}
- (CGFloat)note:(NSString *)text y:(CGFloat)y {
    UILabel *label = [self label:text frame:CGRectMake(20, y, 270, 44) size:11];
    label.textColor = [self mutedColor]; label.numberOfLines = 0;
    [self.scroll addSubview:label]; return y + 48;
}
- (void)buildPage {
    for (UIView *v in self.scroll.subviews) [v removeFromSuperview];
    [self.controls removeAllObjects]; self.swatch = nil;
    self.panel.backgroundColor = ESPDarkTheme() ? [UIColor colorWithRed:0.07f green:0.09f blue:0.15f alpha:0.96f] : [UIColor colorWithWhite:0.98 alpha:0.98];
    self.panel.layer.borderColor = [UIColor colorWithRed:0.0f green:0.85f blue:1.0f alpha:0.35f].CGColor;
    ((UILabel *)[self.header viewWithTag:10]).textColor = ESPDarkTheme() ? [UIColor colorWithRed:0.0f green:0.95f blue:1.0f alpha:1.0f] : [self textColor];
    ((UILabel *)[self.header viewWithTag:11]).textColor = [self mutedColor];
    [(UIButton *)[self.header viewWithTag:12] setTitleColor:[self mutedColor] forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) self.panel.overrideUserInterfaceStyle = ESPDarkTheme() ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    CGFloat y = 0;
    if (self.page == 0) {
        y = [self toggle:@"Aim khi bắn" key:@"AimbotFire" fallback:YES y:y];
        y = [self toggle:@"Aim khi mở ngắm" key:@"AimbotScope" fallback:YES y:y];
        y = [self toggle:@"Aim cổ" key:@"AimNeck" fallback:NO y:y];
        y = [self toggle:@"Hiện vòng FOV" key:@"ShowFov" fallback:YES y:y];
        y = [self slider:@"Kích thước FOV" key:@"FovSize" min:5 max:150 fallback:40 y:y + 6];
        y = [self note:@"Chỉ aim khi điểm ngắm nằm trong vòng. Ẩn vòng vẫn giữ giới hạn FOV." y:y];
        y = [self note:@"Aim cổ dùng vị trí ước tính giữa đầu và vai. Tắt để aim đầu." y:y];
        y = [self toggle:@"Chẩn đoán aim" key:@"AimDiagnostics" fallback:NO y:y];
    } else if (self.page == 1) {
        y = [self toggle:@"Tên người chơi" key:@"Name" fallback:YES y:y];
        y = [self toggle:@"Thanh máu" key:@"Health" fallback:YES y:y];
        y = [self toggle:@"Đường nối" key:@"Line" fallback:NO y:y];
        y = [self toggle:@"Khung người chơi" key:@"Box" fallback:YES y:y];
        y = [self toggle:@"Điểm đánh dấu đầu" key:@"HeadRedDot" fallback:YES y:y];
        y = [self toggle:@"Khoảng cách" key:@"Dis" fallback:YES y:y];
        UILabel *boxLabel = [self label:@"Kiểu khung" frame:CGRectMake(18, y + 4, 274, 20) size:12];
        [self.scroll addSubview:boxLabel];
        UISegmentedControl *boxStyle = [[UISegmentedControl alloc] initWithItems:@[@"2D", @"3D"]];
        boxStyle.frame = CGRectMake(18, y + 28, 274, 30);
        boxStyle.tag = 101;
        boxStyle.selectedSegmentIndex = ESPPrefsBool(@"Box3D", YES) ? 1 : 0;
        [boxStyle addTarget:self action:@selector(boxStyleChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:boxStyle]; [self.controls addObject:boxStyle];
        y += 70;
    } else if (self.page == 2) {
        UISegmentedControl *target = [[UISegmentedControl alloc] initWithItems:@[@"Box", @"Line", @"FOV"]];
        target.frame = CGRectMake(18, 0, 274, 30); target.selectedSegmentIndex = self.colorTarget;
        [target addTarget:self action:@selector(colorTargetChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:target]; [self.controls addObject:target];
        self.swatch = [self label:@"" frame:CGRectMake(18, 42, 274, 38) size:12];
        self.swatch.textAlignment = NSTextAlignmentCenter; self.swatch.layer.cornerRadius = 9; self.swatch.clipsToBounds = YES;
        [self.scroll addSubview:self.swatch]; y = 92;
        NSString *prefix = [self colorPrefix];
        float defaults[3] = {0.72f, 0.91f, 1}; if(self.colorTarget == 2) defaults[0] = defaults[1] = 1;
        NSArray *names = @[@"Đỏ", @"Lục", @"Lam"], *suffixes = @[@"R", @"G", @"B"];
        for (int i = 0; i < 3; ++i) y = [self slider:names[i] key:[prefix stringByAppendingString:suffixes[i]] min:0 max:1 fallback:defaults[i] y:y];
        [self updateSwatch];
    } else {
        y = [self toggle:@"Giao diện tối" key:@"DarkTheme" fallback:YES y:y];
        y = [self toggle:@"ESP ổn định (30 FPS)" key:@"BalancedRender" fallback:YES y:y];
        y = [self note:@"Bật để giảm tải khi chơi lâu. Tắt để vẽ ESP ở 60 FPS." y:y];
        y = [self note:@"Kéo thanh tiêu đề để di chuyển menu. Các lựa chọn được lưu tự động." y:y];
    }
    self.scroll.contentSize = CGSizeMake(310, y + 8);
    self.scroll.contentOffset = CGPointZero;
}
- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    ESPPrefsSetBool(key, sender.on); ESPSyncFromPrefs();
    if ([key isEqualToString:@"DarkTheme"]) [self buildPage];
}
- (void)colorTargetChanged:(UISegmentedControl *)sender {
    self.colorTarget = sender.selectedSegmentIndex; [self buildPage];
}
- (void)boxStyleChanged:(UISegmentedControl *)sender {
    ESPPrefsSetBool(@"Box3D", sender.selectedSegmentIndex == 1);
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
        self.dragging = local.y < 58 && local.x < self.panel.bounds.size.width - 46;
        if (self.dragging) return YES;
        NSMutableArray *fixed = [NSMutableArray array];
        if (self.tabs) [fixed addObject:self.tabs];
        UIView *closeBtn = [self.header viewWithTag:12];
        if ([closeBtn isKindOfClass:[UIControl class]]) [fixed addObject:closeBtn];
        for (UIControl *c in fixed) if (CGRectContainsPoint(c.bounds, [c convertPoint:point fromView:self.view])) self.activeControl = c;
        if (CGRectContainsPoint(self.scroll.bounds, [self.scroll convertPoint:point fromView:self.view])) {
            for (UIControl *c in self.controls) {
                CGRect hit = c.bounds;
                if ([c isKindOfClass:UISwitch.class]) hit = CGRectMake(-220, -8, 280, 48);
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
            if (seg == self.tabs) [self changeTab:seg];
            else if (seg.tag == 101) [self boxStyleChanged:seg];
            else [self colorTargetChanged:seg];
        } else if (activate && [control isKindOfClass:UIButton.class]) [self closeMenu];
        return YES;
    }
    return YES;
}
@end
