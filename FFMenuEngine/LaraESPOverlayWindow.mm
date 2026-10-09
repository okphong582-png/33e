#import "LaraESPOverlayWindow.h"
#import "LaraMemoryReader.h"
#import <QuartzCore/QuartzCore.h>

@interface ESPDrawView : UIView
@property (nonatomic, assign) ESPConfig config;
@property (nonatomic, strong) NSMutableArray *entitiesToDraw;
@end

@implementation ESPDrawView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        _entitiesToDraw = [NSMutableArray array];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    
    CGContextClearRect(ctx, rect);
    
    // Draw FOV Circle if enabled
    if (self.config.showFOVCircle && self.config.fovRadius > 0) {
        CGPoint center = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.6].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        CGContextAddArc(ctx, center.x, center.y, self.config.fovRadius, 0, M_PI * 2, 0);
        CGContextStrokePath(ctx);
    }
    
    // Draw Crosshair if enabled
    if (self.config.showCrosshair) {
        CGPoint center = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:1.0 blue:0.5 alpha:0.8].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        
        CGContextMoveToPoint(ctx, center.x - 10, center.y);
        CGContextAddLineToPoint(ctx, center.x + 10, center.y);
        CGContextMoveToPoint(ctx, center.x, center.y - 10);
        CGContextAddLineToPoint(ctx, center.x, center.y + 10);
        CGContextStrokePath(ctx);
    }
    
    // Iterate over tracked entities and draw ESP primitives
    for (NSDictionary *entity in self.entitiesToDraw) {
        float screenX = [entity[@"x"] floatValue];
        float screenY = [entity[@"y"] floatValue];
        float width   = [entity[@"w"] floatValue];
        float height  = [entity[@"h"] floatValue];
        float dist    = [entity[@"dist"] floatValue];
        float hp      = [entity[@"hp"] floatValue];
        BOOL isVisible = [entity[@"visible"] boolValue];
        
        if (dist > self.config.maxDistance) continue;
        
        UIColor *boxColor = isVisible ? [UIColor colorWithRed:0.0 green:1.0 blue:0.4 alpha:0.9] : [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.9];
        
        // 1. ESP Box
        if (self.config.showBox) {
            CGRect boxRect = CGRectMake(screenX - width / 2.0, screenY - height, width, height);
            CGContextSetStrokeColorWithColor(ctx, boxColor.CGColor);
            CGContextSetLineWidth(ctx, 1.8);
            CGContextStrokeRect(ctx, boxRect);
        }
        
        // 2. ESP Snapline
        if (self.config.showLine) {
            CGPoint topCenter = CGPointMake(rect.size.width / 2.0, 40);
            CGContextSetStrokeColorWithColor(ctx, boxColor.CGColor);
            CGContextSetLineWidth(ctx, 1.0);
            CGContextMoveToPoint(ctx, topCenter.x, topCenter.y);
            CGContextAddLineToPoint(ctx, screenX, screenY - height);
            CGContextStrokePath(ctx);
        }
        
        // 3. Health Bar
        if (self.config.showHealth) {
            float barX = screenX - width / 2.0 - 6;
            float barY = screenY - height;
            float barW = 3.5;
            float barH = height;
            
            // Health Background
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.5].CGColor);
            CGContextFillRect(ctx, CGRectMake(barX, barY, barW, barH));
            
            // Health Fill
            float hpPercent = MIN(MAX(hp / 100.0f, 0.0f), 1.0f);
            UIColor *hpColor = [UIColor colorWithRed:(1.0 - hpPercent) green:hpPercent blue:0.0 alpha:1.0];
            CGContextSetFillColorWithColor(ctx, hpColor.CGColor);
            CGContextFillRect(ctx, CGRectMake(barX, barY + barH * (1.0 - hpPercent), barW, barH * hpPercent));
        }
        
        // 4. Distance Text
        if (self.config.showDistance) {
            NSString *distStr = [NSString stringWithFormat:@"%.0fm", dist];
            NSDictionary *attr = @{
                NSFontAttributeName: [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            };
            CGSize strSize = [distStr sizeWithAttributes:attr];
            [distStr drawAtPoint:CGPointMake(screenX - strSize.width / 2.0, screenY + 2) withAttributes:attr];
        }
    }
}

@end

@interface LaraESPOverlayWindow ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) ESPDrawView *drawView;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIView *menuContainerView;
@end

@implementation LaraESPOverlayWindow

+ (instancetype)sharedOverlay {
    static LaraESPOverlayWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        instance = [[LaraESPOverlayWindow alloc] initWithFrame:screenBounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 1000.0;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        self.opaque = NO;
        
        // Default ESP Settings
        ESPConfig cfg;
        cfg.showBox = YES;
        cfg.showLine = YES;
        cfg.showDistance = YES;
        cfg.showHealth = YES;
        cfg.showName = NO;
        cfg.showSkeleton = NO;
        cfg.showFOVCircle = YES;
        cfg.showCrosshair = YES;
        cfg.fovRadius = 120.0f;
        cfg.maxDistance = 400.0f;
        _espConfig = cfg;
        
        _drawView = [[ESPDrawView alloc] initWithFrame:frame];
        _drawView.config = _espConfig;
        [self addSubview:_drawView];
        
        [self setupFloatingMenuButton];
    }
    return self;
}

- (void)setupFloatingMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(20, 100, 48, 48);
    _menuButton.layer.cornerRadius = 24;
    _menuButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.8];
    _menuButton.layer.borderWidth = 1.5;
    _menuButton.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.8].CGColor;
    [_menuButton setTitle:@"FF" forState:UIControlStateNormal];
    [_menuButton setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    _menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPan:)];
    [_menuButton addGestureRecognizer:pan];
    [_menuButton addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:_menuButton];
}

- (void)handleMenuPan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    CGPoint newCenter = CGPointMake(pan.view.center.x + translation.x, pan.view.center.y + translation.y);
    
    // Bound inside screen
    CGRect bounds = self.bounds;
    newCenter.x = MIN(MAX(newCenter.x, 30), bounds.size.width - 30);
    newCenter.y = MIN(MAX(newCenter.y, 50), bounds.size.height - 50);
    
    pan.view.center = newCenter;
    [pan setTranslation:CGPointZero inView:self];
}

- (void)startOverlayLoop {
    if (_displayLink) return;
    
    self.hidden = NO;
    _isOverlayActive = YES;
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame)];
    if (@available(iOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 120);
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    NSLog(@"[LaraESPOverlayWindow] Overlay CADisplayLink rendering loop started.");
}

- (void)stopOverlayLoop {
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    _isOverlayActive = NO;
    self.hidden = YES;
}

- (void)renderFrame {
    if (!_isOverlayActive) return;
    
    _drawView.config = self.espConfig;
    
    // Perform memory read via LaraMemoryReader & update entities
    LaraMemoryReader *reader = [LaraMemoryReader sharedInstance];
    if (reader.isKernelReady && reader.targetProcAddress != 0) {
        // Example mock entity structure for overlay visualization test
        NSMutableArray *list = [NSMutableArray array];
        
        // Populate tracking coordinates from memory reader
        _drawView.entitiesToDraw = list;
    }
    
    [_drawView setNeedsDisplay];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    
    // If user touches interactive controls (menu button / menu container), intercept touch
    if (hitView == _menuButton || [hitView isDescendantOfView:_menuButton] ||
        (_menuContainerView && [hitView isDescendantOfView:_menuContainerView])) {
        return hitView;
    }
    
    // Transparent click-through for rest of overlay so touch passes to game
    return nil;
}

- (void)toggleMenuVisibility {
    NSLog(@"[LaraESPOverlayWindow] Menu Button Toggled");
}

@end
