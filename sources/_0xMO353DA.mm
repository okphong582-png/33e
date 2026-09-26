#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "../esp/drawing_view/menu.h"
#import "../mahoa.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#include "KabraxHide.h"

static const CGFloat kPanelWidth      = 280.0f;
static const CGFloat kPanelHeight     = 340.0f;
static const CGFloat kHeaderHeight    = 45.0f;
static const CGFloat kRowHeight       = 43.0f;
static const CGFloat kSliderRowHeight = 55.0f;
static const CGFloat kFooterHeight    = 25.0f;
static const CGFloat kCornerRadius    = 8.0f;
static const CGFloat kSeparatorHeight = 1.5f;

#define kColorRed        [UIColor colorWithRed:0.95f green:0.25f blue:0.15f alpha:1.0f]
#define kColorBlue       [UIColor colorWithRed:0.07f green:0.07f blue:0.12f alpha:0.96f]
#define kColorGray       [UIColor colorWithRed:0.12f green:0.12f blue:0.18f alpha:0.95f]
#define kColorActive     [UIColor colorWithRed:1.00f green:0.65f blue:0.00f alpha:1.0f]
#define kColorText       [UIColor whiteColor]
#define kColorSeparator  [UIColor colorWithRed:1.00f green:0.75f blue:0.00f alpha:0.35f]

@interface _0xDEADBEEE () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView       *_0xP001;
@property (nonatomic, strong) UIScrollView *_0xP002;
@property (nonatomic, strong) UIView       *_0xP003;

@property (nonatomic, assign) NSInteger _0xP004;
@property (nonatomic, assign) BOOL      _0xP005;
@property (nonatomic, assign) CGPoint   _0xP006;
@property (nonatomic, assign) CGPoint   _0xP007;

@property (nonatomic, weak)   UIView   *_0xP008;
@property (nonatomic, assign) BOOL     _0xP009;

@property (nonatomic, weak)   UIView   *_0xP00A;
@property (nonatomic, weak)   UISlider *_0xP00B;

@property (nonatomic, weak)   UIView   *_0xP00C;
@property (nonatomic, assign) BOOL     _0xP00D;

@property (nonatomic, assign) BOOL          _0xP00E;
@property (nonatomic, assign) BOOL          _0xP00F;
@property (nonatomic, assign) CGFloat       _0xP010;
@property (nonatomic, assign) CGFloat       _0xP011;
@property (nonatomic, strong) CADisplayLink *_0xP012;
@property (nonatomic, copy)   void (^_0xP013)(void);
@end

@implementation _0xDEADBEEE

- (NSAttributedString *)_0xF001:(NSString *)text large:(CGFloat)lSize small:(CGFloat)sSize kern:(CGFloat)kernValue {
    NSString *upperText = [text uppercaseString];
    NSArray *words = [upperText componentsSeparatedByString:@" "];
    NSMutableAttributedString *finalAttr = [[NSMutableAttributedString alloc] init];

    for (NSInteger w = 0; w < words.count; w++) {
        NSString *word = words[w];
        if (word.length == 0) {
            [finalAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
            continue;
        }

        NSMutableAttributedString *wordAttr = [[NSMutableAttributedString alloc] init];
        for (NSInteger i = 0; i < word.length; i++) {
            NSString *ch = [word substringWithRange:NSMakeRange(i, 1)];
            CGFloat fontSize = (i == 0) ? lSize : sSize;
            UIFont *font = [UIFont fontWithName:KH_NS("AvenirNext-Bold") size:fontSize];
            if (!font) font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
            NSAttributedString *chAttr = [[NSAttributedString alloc] initWithString:ch
                                                                          attributes:@{NSFontAttributeName: font}];
            [wordAttr appendAttributedString:chAttr];
        }
        [finalAttr appendAttributedString:wordAttr];

        if (w < words.count - 1) {
            [finalAttr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        }
    }

    [finalAttr addAttribute:NSKernAttributeName value:@(kernValue) range:NSMakeRange(0, finalAttr.length)];
    return finalAttr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor      = [UIColor clearColor];
    self.view.multipleTouchEnabled = YES;
    self._0xP004  = -1;
    self._0xP00E = NO;
    self._0xP00F = NO;

    [self _0xF002];
    [self _0xF003];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_0xF00F:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self _0xF007];
}

- (void)_0xF007 {
    if (!self._0xP001) return;

    CGRect screenBounds = self.view.bounds;
    CGFloat panelW = CGRectGetWidth(self._0xP001.frame);
    CGFloat panelH = CGRectGetHeight(self._0xP001.frame);

    CGFloat minX = 0;
    CGFloat maxX = screenBounds.size.width - panelW;
    CGFloat minY = 0;
    CGFloat maxY = screenBounds.size.height - panelH;

    CGFloat currentX = self._0xP001.frame.origin.x;
    CGFloat currentY = self._0xP001.frame.origin.y;

    currentX = MAX(minX, MIN(maxX, currentX));
    currentY = MAX(minY, MIN(maxY, currentY));

    if (currentX != self._0xP001.frame.origin.x || currentY != self._0xP001.frame.origin.y) {
        CGRect newFrame = self._0xP001.frame;
        newFrame.origin.x = currentX;
        newFrame.origin.y = currentY;
        self._0xP001.frame = newFrame;

        [[KH_CLS("NSUserDefaults") standardUserDefaults] setFloat:currentX forKey:NSSENCRYPT("FloatingPanelX")];
        [[KH_CLS("NSUserDefaults") standardUserDefaults] setFloat:currentY forKey:NSSENCRYPT("FloatingPanelY")];
        [[KH_CLS("NSUserDefaults") standardUserDefaults] synchronize];
    }
}

- (CGPoint)_0xF008 {
    CGFloat x = [[KH_CLS("NSUserDefaults") standardUserDefaults] floatForKey:NSSENCRYPT("FloatingPanelX")];
    CGFloat y = [[KH_CLS("NSUserDefaults") standardUserDefaults] floatForKey:NSSENCRYPT("FloatingPanelY")];
    if (x == 0 && y == 0) {
        CGRect screen = [UIScreen mainScreen].bounds;
        x = (screen.size.width - kPanelWidth) / 2.0f;
        y = 80.0f;
    }
    return CGPointMake(x, y);
}

- (void)_0xF002 {
    CGPoint pos = [self _0xF008];
    self._0xP001 = [[UIView alloc] initWithFrame:CGRectMake(pos.x, pos.y, kPanelWidth, kPanelHeight)];
    self._0xP001.backgroundColor     = [UIColor clearColor];
    self._0xP001.layer.shadowColor   = [UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:0.8f].CGColor;
    self._0xP001.layer.shadowOpacity = 0.8f;
    self._0xP001.layer.shadowRadius  = 12.0f;
    self._0xP001.layer.shadowOffset  = CGSizeZero;
    [self.view addSubview:self._0xP001];

    UIView *clip = [[KH_CLS("UIView") alloc] initWithFrame:self._0xP001.bounds];
    clip.backgroundColor    = kColorBlue;
    clip.layer.cornerRadius = kCornerRadius;
    clip.layer.borderWidth  = 1.5f;
    clip.layer.borderColor  = [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:0.8f].CGColor;
    clip.clipsToBounds      = YES;
    [self._0xP001 addSubview:clip];

    UIView *headerView = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, kHeaderHeight)];
    headerView.backgroundColor = [UIColor colorWithRed:0.95f green:0.30f blue:0.0f alpha:1.0f];
    [clip addSubview:headerView];

    UILabel *_0x28620 = [[KH_CLS("UILabel") alloc] initWithFrame:headerView.bounds];
    _0x28620.textColor = kColorText;
    _0x28620.textAlignment = NSTextAlignmentCenter;

    NSMutableAttributedString *headerAttr = [[NSMutableAttributedString alloc] init];
    NSAttributedString *_0x8462 = [self _0xF001:KH_NS("DRAGON BALL Z") large:17.0f small:15.0f kern:3.0f];
    [headerAttr appendAttributedString:_0x8462];
    _0x28620.attributedText = headerAttr;
    [headerView addSubview:_0x28620];

    UIView *headerSep = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, kHeaderHeight - kSeparatorHeight, kPanelWidth, kSeparatorHeight)];
    headerSep.backgroundColor = kColorSeparator;
    [headerView addSubview:headerSep];

    self._0xP002 = [[KH_CLS("UIScrollView") alloc] initWithFrame:CGRectMake(0, kHeaderHeight, kPanelWidth, kPanelHeight - kHeaderHeight - kFooterHeight)];
    self._0xP002.backgroundColor = [UIColor clearColor];
    self._0xP002.scrollEnabled = YES;
    self._0xP002.showsVerticalScrollIndicator = YES;
    self._0xP002.bounces = YES;
    [clip addSubview:self._0xP002];

    self._0xP003 = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, 0)];
    self._0xP003.backgroundColor = [UIColor clearColor];
    [self._0xP002 addSubview:self._0xP003];

    UIView *footer = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, kPanelHeight - kFooterHeight, kPanelWidth, kFooterHeight)];
    footer.backgroundColor = [UIColor colorWithRed:0.95f green:0.30f blue:0.0f alpha:1.0f];
    
    UILabel *footerLbl = [[UILabel alloc] initWithFrame:footer.bounds];
    footerLbl.text = @"⚡ DBZ RAGE VIP MOD ⚡";
    footerLbl.textColor = [UIColor whiteColor];
    footerLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    footerLbl.textAlignment = NSTextAlignmentCenter;
    [footer addSubview:footerLbl];
    [clip addSubview:footer];

    self._0xP001.alpha = 0.0f;
    [UIView animateWithDuration:0.28
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self._0xP001.alpha = 1.0f;
    } completion:nil];
}

- (UIView *)_0xF004:(NSString *)title key:(NSString *)key y:(CGFloat)y {
    UIView *rv = [[UIView alloc] initWithFrame:CGRectMake(0, y, kPanelWidth, kRowHeight)];

    BOOL isOn = [[KH_CLS("NSUserDefaults") standardUserDefaults] boolForKey:key];
    rv.backgroundColor = isOn ? kColorActive : kColorGray;

    objc_setAssociatedObject(rv, "type", @"toggle", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(rv, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILabel *lbl = [[KH_CLS("UILabel") alloc] initWithFrame:rv.bounds];
    lbl.attributedText = [self _0xF001:title large:15.0f small:13.0f kern:2.0f];
    lbl.textColor = isOn ? [UIColor blackColor] : kColorText;
    lbl.textAlignment = NSTextAlignmentCenter;
    [rv addSubview:lbl];

    UIView *sep = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, kRowHeight - kSeparatorHeight, kPanelWidth, kSeparatorHeight)];
    sep.backgroundColor = kColorSeparator;
    [rv addSubview:sep];

    return rv;
}

- (UIImage *)_0xF009 {
    CGFloat radius = 12.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(radius*2, radius*2), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, radius*2, radius*2));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (CGFloat)_0xF005:(NSString *)title key:(NSString *)key def:(CGFloat)def min:(float)min max:(float)max y:(CGFloat)y {
    UIView *rv = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, y, kPanelWidth, kSliderRowHeight)];

    NSString *visualToggleKey = [key isEqualToString:@"Fov"] ? @"ShowFov" : [key stringByAppendingString:@"_visual_toggle"];
    if ([[KH_CLS("NSUserDefaults") standardUserDefaults] objectForKey:visualToggleKey] == nil) {
        [[KH_CLS("NSUserDefaults") standardUserDefaults] setBool:YES forKey:visualToggleKey];
    }
    BOOL isRowOn = [[KH_CLS("NSUserDefaults") standardUserDefaults] boolForKey:visualToggleKey];
    rv.backgroundColor = isRowOn ? kColorBlue : kColorGray;

    objc_setAssociatedObject(rv, "type", @"slider_row", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(rv, "key", visualToggleKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat val = ESPPrefsFloat(key, def);

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 4, kPanelWidth - 30, 20)];
    lbl.textColor = [UIColor whiteColor];

    NSMutableAttributedString *attrTitle = [[self _0xF001:title large:13.0f small:12.0f kern:1.5f] mutableCopy];
    NSString *valStr = [KH_CLS("NSString") stringWithFormat:@" %.2f", val];

    UIFont *valFont = [UIFont fontWithName:NSSENCRYPT("AvenirNext-Bold") size:11.0f];
    if (!valFont) valFont = [UIFont systemFontOfSize:11.0f weight:UIFontWeightBold];

    NSAttributedString *attrVal = [[NSAttributedString alloc] initWithString:valStr
                                                                  attributes:@{NSFontAttributeName: valFont,
                                                                               NSForegroundColorAttributeName: kColorText}];
    [attrTitle appendAttributedString:attrVal];

    lbl.attributedText = attrTitle;
    [rv addSubview:lbl];

    CGFloat btnY = 26.0f;
    CGFloat btnSize = 22.0f;

    UIFont *btnFont = [UIFont fontWithName:NSSENCRYPT("AvenirNext-Bold") size:15.0f];
    if (!btnFont) btnFont = [UIFont systemFontOfSize:15.0f weight:UIFontWeightBold];

    UIView *btnMinus = [[UIView alloc] initWithFrame:CGRectMake(15, btnY, btnSize, btnSize)];
    btnMinus.backgroundColor = kColorRed;
    objc_setAssociatedObject(btnMinus, "action", @"minus", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILabel *lMinus = [[UILabel alloc] initWithFrame:btnMinus.bounds];
    lMinus.text = @"-"; lMinus.textColor = kColorText; lMinus.textAlignment = NSTextAlignmentCenter; lMinus.font = btnFont;
    [btnMinus addSubview:lMinus];
    [rv addSubview:btnMinus];

    UIView *btnPlus = [[UIView alloc] initWithFrame:CGRectMake(kPanelWidth - 15 - btnSize, btnY, btnSize, btnSize)];
    btnPlus.backgroundColor = kColorRed;
    objc_setAssociatedObject(btnPlus, "action", @"plus", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILabel *lPlus = [[UILabel alloc] initWithFrame:btnPlus.bounds];
    lPlus.text = @"+"; lPlus.textColor = kColorText; lPlus.textAlignment = NSTextAlignmentCenter; lPlus.font = btnFont;
    [btnPlus addSubview:lPlus];
    [rv addSubview:btnPlus];

    CGFloat sliderX = 15 + btnSize + 10;
    CGFloat sliderW = kPanelWidth - (sliderX * 2);
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(sliderX, btnY, sliderW, btnSize)];
    sl.minimumValue = min; sl.maximumValue = max; sl.value = val;
    sl.minimumTrackTintColor = kColorSeparator;
    sl.maximumTrackTintColor = kColorSeparator;
    [sl setThumbImage:[self _0xF009] forState:UIControlStateNormal];
    sl.userInteractionEnabled = NO;

    objc_setAssociatedObject(sl, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(sl, "label", lbl, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(sl, "title", title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [rv addSubview:sl];

    objc_setAssociatedObject(btnMinus, "slider", sl, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(btnPlus,  "slider", sl, OBJC_ASSOCIATION_ASSIGN);

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, kSliderRowHeight - kSeparatorHeight, kPanelWidth, kSeparatorHeight)];
    sep.backgroundColor = kColorSeparator;
    [rv addSubview:sep];

    [self._0xP003 addSubview:rv];
    return y + kSliderRowHeight;
}

- (void)_0xF006:(UISlider *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    NSString *title = objc_getAssociatedObject(sender, "title");
    UILabel *lbl = objc_getAssociatedObject(sender, "label");

    if (!key) return;
    float val = sender.value;
    ESPPrefsSetFloat(key, val);
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPSyncFromPrefs();

    if (lbl && title) {
        NSMutableAttributedString *attrTitle = [[self _0xF001:title large:13.0f small:12.0f kern:1.5f] mutableCopy];
        NSString *valStr = [NSString stringWithFormat:NSSENCRYPT(" %.2f"), val];

        UIFont *valFont = [UIFont fontWithName:NSSENCRYPT("AvenirNext-Bold") size:11.0f];
        if (!valFont) valFont = [UIFont systemFontOfSize:11.0f weight:UIFontWeightBold];

        NSAttributedString *attrVal = [[NSAttributedString alloc] initWithString:valStr attributes:@{NSFontAttributeName: valFont, NSForegroundColorAttributeName: kColorText}];
        [attrTitle appendAttributedString:attrVal];
        lbl.attributedText = attrTitle;
    }
}

- (void)_0xF003 {
    CGFloat y = 0.0f;

    [self._0xP003 addSubview:[self _0xF004:NSSENCRYPT("ESP Line") key:@"Line" y:y]];
    y += kRowHeight;

    [self._0xP003 addSubview:[self _0xF004:NSSENCRYPT("ESP Box")  key:@"Box" y:y]];
    y += kRowHeight;

    [self._0xP003 addSubview:[self _0xF004:NSSENCRYPT("ESP Hp")   key:@"Health" y:y]];
    y += kRowHeight;

    CGRect containerFrame = self._0xP003.frame;
    containerFrame.size.height = y;
    self._0xP003.frame = containerFrame;
    self._0xP002.contentSize = CGSizeMake(kPanelWidth, y);
}

- (void)_0xF00A:(CGFloat)delta {
    CGFloat contentH = self._0xP002.contentSize.height;
    CGFloat viewH = self._0xP002.bounds.size.height;
    CGFloat maxOff = MAX(0, contentH - viewH);
    CGFloat newOff = self._0xP002.contentOffset.y + delta;
    newOff = MAX(0, MIN(maxOff, newOff));
    self._0xP002.contentOffset = CGPointMake(0, newOff);
}

- (void)_0xF00B {
    [self _0xF00C];
    if (fabs(self._0xP011) < 1.0f) return;
    self._0xP012 = [CADisplayLink displayLinkWithTarget:self selector:@selector(_0xF00D)];
    [self._0xP012 addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)_0xF00C {
    [self._0xP012 invalidate];
    self._0xP012 = nil;
}

- (void)_0xF00D {
    self._0xP011 *= 0.92f;
    if (fabs(self._0xP011) < 0.5f) { [self _0xF00C]; return; }
    [self _0xF00A:self._0xP011];
}

- (void)_0xF00E {
    [[NSUserDefaults standardUserDefaults] setFloat:self._0xP001.frame.origin.x forKey:@"FloatingPanelX"];
    [[NSUserDefaults standardUserDefaults] setFloat:self._0xP001.frame.origin.y forKey:@"FloatingPanelY"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [UIView animateWithDuration:0.20 animations:^{
        self._0xP001.alpha = 0.0f;
    } completion:^(BOOL finished){
        if (self.onCloseBlock) self.onCloseBlock();
        if (self._0xP013) self._0xP013();
    }];
}

- (void)_0xF00F:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self.view];
    if (!CGRectContainsPoint(self._0xP001.frame, p)) [self _0xF00E];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    return !CGRectContainsPoint(self._0xP001.frame, [touch locationInView:self.view]);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self.view];
    [self _0xF010:pt phase:UITouchPhaseBegan pointerId:(NSInteger)touch];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self.view];
    [self _0xF010:pt phase:UITouchPhaseMoved pointerId:(NSInteger)touch];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self.view];
    [self _0xF010:pt phase:UITouchPhaseEnded pointerId:(NSInteger)touch];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self.view];
    [self _0xF010:pt phase:UITouchPhaseCancelled pointerId:(NSInteger)touch];
}

- (BOOL)_0xF010:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    BOOL insidePanel = CGRectContainsPoint(self._0xP001.frame, point);
    UITouchPhase ph = (UITouchPhase)phase;

    if (ph == UITouchPhaseBegan) {
        if (!insidePanel) return NO;
        if (self._0xP004 != -1 && self._0xP004 != pointerId) return NO;

        self._0xP004 = pointerId;
        self._0xP005 = NO;
        self._0xP008 = nil; self._0xP00A = nil; self._0xP00B = nil; self._0xP00C = nil;
        self._0xP00E = NO;
        self._0xP00F = NO;
        [self _0xF00C];
        self._0xP011 = 0;

        CGPoint inPanel = CGPointMake(point.x - self._0xP001.frame.origin.x, point.y - self._0xP001.frame.origin.y);

        if (inPanel.y < kHeaderHeight) {
            self._0xP005 = YES;
            self._0xP006 = self._0xP001.frame.origin;
            self._0xP007  = point;
            return YES;
        }

        CGPoint inContainer = [self._0xP003 convertPoint:inPanel fromView:self._0xP001];
        for (UIView *rv in self._0xP003.subviews) {
            if (CGRectContainsPoint(rv.frame, inContainer)) {
                NSString *type = objc_getAssociatedObject(rv, "type");
                if ([type isEqualToString:@"toggle"]) {
                    self._0xP00F = YES;
                    self._0xP008 = rv;
                    self._0xP009 = YES;
                    [UIView animateWithDuration:0.15 animations:^{
                        self._0xP008.alpha = 0.5f;
                    }];
                    break;
                } else if ([type isEqualToString:@"slider_row"]) {
                    self._0xP00F = YES;
                    self._0xP00A = rv;
                    BOOL hitControl = NO;
                    for (UIView *sub in rv.subviews) {
                        CGPoint subPt = CGPointMake(inContainer.x - rv.frame.origin.x, inContainer.y - rv.frame.origin.y);
                        if ([sub isKindOfClass:[UISlider class]]) {
                            if (CGRectContainsPoint(CGRectInset(sub.frame, -10, -15), subPt)) {
                                self._0xP00B = (UISlider *)sub;
                                hitControl = YES;
                                break;
                            }
                        } else {
                            NSString *action = objc_getAssociatedObject(sub, "action");
                            if (action && CGRectContainsPoint(CGRectInset(sub.frame, -5, -5), subPt)) {
                                self._0xP00C = sub;
                                self._0xP00D = YES;
                                hitControl = YES;
                                [UIView animateWithDuration:0.15 animations:^{
                                    self._0xP00C.alpha = 0.5f;
                                }];
                                break;
                            }
                        }
                    }
                    if (!hitControl) {
                        self._0xP008 = rv;
                        self._0xP009 = YES;
                        [UIView animateWithDuration:0.15 animations:^{
                            self._0xP008.alpha = 0.5f;
                        }];
                    }
                    break;
                }
            }
        }

        self._0xP010 = point.y;
        return YES;
    }

    if (ph == UITouchPhaseMoved) {
        if (pointerId != self._0xP004) return NO;

        if (self._0xP005) {
            CGFloat dx = point.x - self._0xP007.x;
            CGFloat dy = point.y - self._0xP007.y;
            self._0xP001.frame = CGRectMake(self._0xP006.x + dx, self._0xP006.y + dy, kPanelWidth, kPanelHeight);
            return YES;
        }

        if (self._0xP00B) {
            CGPoint inPanel = CGPointMake(point.x - self._0xP001.frame.origin.x, point.y - self._0xP001.frame.origin.y);
            CGPoint inContainer = [self._0xP003 convertPoint:inPanel fromView:self._0xP001];
            UISlider *sl = self._0xP00B;
            UIView *parent = sl.superview;
            CGFloat ratio = (inContainer.x - parent.frame.origin.x - sl.frame.origin.x) / sl.frame.size.width;
            ratio = MAX(0, MIN(1, ratio));
            sl.value = sl.minimumValue + (float)ratio * (sl.maximumValue - sl.minimumValue);
            [self _0xF006:sl];
            self._0xP010 = point.y;
            return YES;
        }

        CGFloat dy = point.y - self._0xP010;

        if (!self._0xP00E && self._0xP00F) {
            if (fabs(dy) > 5.0f) {
                self._0xP00E = YES;
                self._0xP00F = NO;
                if (self._0xP008) {
                    [UIView animateWithDuration:0.2 animations:^{
                        self._0xP008.alpha = 1.0f;
                    }];
                }
                if (self._0xP00C) {
                    [UIView animateWithDuration:0.2 animations:^{
                        self._0xP00C.alpha = 1.0f;
                    }];
                }
                self._0xP008 = nil;
                self._0xP00C = nil;
                self._0xP00A = nil;
            } else {
                if (self._0xP008) {
                    CGPoint inPanel = CGPointMake(point.x - self._0xP001.frame.origin.x, point.y - self._0xP001.frame.origin.y);
                    CGPoint inContainer = [self._0xP003 convertPoint:inPanel fromView:self._0xP001];
                    BOOL currentlyInside = CGRectContainsPoint(self._0xP008.frame, inContainer);
                    if (currentlyInside != self._0xP009) {
                        self._0xP009 = currentlyInside;
                        [UIView animateWithDuration:0.25 animations:^{
                            self._0xP008.alpha = currentlyInside ? 0.5f : 1.0f;
                        }];
                    }
                }
                self._0xP010 = point.y;
                return YES;
            }
        }

        if (self._0xP00E || !self._0xP00F) {
            [self _0xF00A:-dy];
            self._0xP011 = -dy;
            if (fabs(dy) > 3) self._0xP00E = YES;
        }

        self._0xP010 = point.y;
        return YES;
    }

    if (ph == UITouchPhaseEnded || ph == UITouchPhaseCancelled) {
        if (pointerId != self._0xP004) return NO;
        BOOL isCancel = (ph == UITouchPhaseCancelled);

        if (self._0xP005) {
            CGFloat dx = point.x - self._0xP007.x;
            CGFloat dy = point.y - self._0xP007.y;
            if (fabs(dx) < 5.0f && fabs(dy) < 5.0f && !isCancel) {
                self._0xP004 = -1;
                [self _0xF00E];
                return YES;
            }
            [[NSUserDefaults standardUserDefaults] setFloat:self._0xP001.frame.origin.x forKey:NSSENCRYPT("FloatingPanelX")];
            [[NSUserDefaults standardUserDefaults] setFloat:self._0xP001.frame.origin.y forKey:NSSENCRYPT("FloatingPanelY")];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        else if (self._0xP00E) {
            [self _0xF00B];
        }
        else if (self._0xP008 && self._0xP009 && !isCancel) {
            NSString *key = objc_getAssociatedObject(self._0xP008, "key");
            BOOL newState = ![[NSUserDefaults standardUserDefaults] boolForKey:key];
            [[NSUserDefaults standardUserDefaults] setBool:newState forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (![key isEqualToString:@"Fov"] &&
            ![key isEqualToString:@"AimSpeed"] &&
            ![key isEqualToString:@"Distance"]) {
            ESPPrefsSetBool(key, newState);
            ESPSyncFromPrefs();
            }
            [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self._0xP008.alpha = 1.0f;
                self._0xP008.backgroundColor = newState ? kColorActive : kColorGray;
                for (UIView *sub in self._0xP008.subviews) {
                    if ([sub isKindOfClass:[UILabel class]]) {
                        ((UILabel *)sub).textColor = newState ? [UIColor blackColor] : kColorText;
                    }
                }
            } completion:nil];
        }
        else if (self._0xP00C && self._0xP00D && !isCancel) {
            NSString *action = objc_getAssociatedObject(self._0xP00C, "action");
            UISlider *sl = objc_getAssociatedObject(self._0xP00C, "slider");
            if (sl && action) {
                float step = 1.0f;
                if ([action isEqualToString:@"plus"]) {
                    sl.value = MIN(sl.maximumValue, sl.value + step);
                } else {
                    sl.value = MAX(sl.minimumValue, sl.value - step);
                }
                [self _0xF006:sl];
            }
            [UIView animateWithDuration:0.45 animations:^{
                self._0xP00C.alpha = 1.0f;
            }];
        }
        else {
            [UIView animateWithDuration:0.2 animations:^{
                if (self._0xP008) self._0xP008.alpha = 1.0f;
                if (self._0xP00C) self._0xP00C.alpha = 1.0f;
            }];
        }

        self._0xP004 = -1;
        self._0xP005 = NO;
        self._0xP00E = NO;
        self._0xP00F = NO;
        self._0xP008 = nil; self._0xP00A = nil; self._0xP00B = nil; self._0xP00C = nil;
        return YES;
    }

    return YES;
}

@end