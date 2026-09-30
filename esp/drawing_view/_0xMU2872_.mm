#import "menu.h"
#import "icons.h"
#import "ModMenuViewController.h"
#import "ESPPrefs.h"
#import "esp.h"
#import "../../mahoa.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#include "KabraxHide.h"

static const CGFloat kMenuButtonSize = 44.0f;

@interface _0xB1872A2 ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL touchOnButton;
@property (nonatomic, assign) BOOL buttonDragging;
@property (nonatomic, assign) CGPoint buttonDragStartCenter;
@property (nonatomic, assign) CGPoint buttonDragStartPoint;
@property (nonatomic, strong) _0xDEADBEEE *presentedModMenu;
@end

@implementation _0xB1872A2

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.superview && _menuButton) {
        CGSize size = self.bounds.size;
        if (size.width < kMenuButtonSize || size.height < kMenuButtonSize) return;
        CGRect frame = _menuButton.frame;
        
        frame.size.width = kMenuButtonSize;
        frame.size.height = kMenuButtonSize;
        
        if (CGRectGetMaxX(frame) > size.width) frame.origin.x = size.width - frame.size.width;
        if (CGRectGetMaxY(frame) > size.height) frame.origin.y = size.height - frame.size.height;
        if (frame.origin.x < 0) frame.origin.x = 0;
        if (frame.origin.y < 0) frame.origin.y = 0;
        
        _menuButton.frame = frame;
    }
    if (_presentedModMenu && _presentedModMenu.view) {
        _presentedModMenu.view.frame = self.bounds;
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        _trackingPointerId = -1;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resetTouchState)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resetTouchState)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [self setupMenuButton];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(matchReadyChanged) name:ESPMatchReadyChangedNotification object:nil];
        [self matchReadyChanged];
    }
    return self;
}

- (void)setupMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    _menuButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.78 blue:0.36 alpha:0.95];
    _menuButton.layer.cornerRadius = kMenuButtonSize / 2.0f;
    _menuButton.layer.borderWidth = 1.0f;
    _menuButton.layer.borderColor = [UIColor colorWithRed:0.7 green:1 blue:0.78 alpha:0.75].CGColor;
    _menuButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _menuButton.layer.shadowOffset = CGSizeMake(0, 2);
    _menuButton.layer.shadowOpacity = 0;
    _menuButton.layer.shadowRadius = 4.0f;
    _menuButton.layer.zPosition = 999.0f;
    _menuButton.clipsToBounds = YES;
    
    [_menuButton setTitle:@"Mizze" forState:UIControlStateNormal];
    [_menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _menuButton.titleLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightBold];
    _menuButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_menuButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragNativeButton:)];
    [_menuButton addGestureRecognizer:pan];
    
    [self addSubview:_menuButton];
    [self loadMenuButtonPosition];
}
- (void)matchReadyChanged {
    self.hidden = !ESPMatchReady();
    if (self.hidden) { [self hideMenu]; [self resetTouchState]; }
}

- (void)loadMenuButtonPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:KH_NS("FloatingMenuBtnX")];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:KH_NS("FloatingMenuBtnY")];
    
    if (x > 10.0f && y > 10.0f) {
        _menuButton.frame = CGRectMake(x, y, kMenuButtonSize, kMenuButtonSize);
    } else {
        _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || (_presentedModMenu && hit == _presentedModMenu.view)) return nil;
    return hit;
}
- (void)dragNativeButton:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) _buttonDragStartCenter = _menuButton.center;
    CGPoint delta = [pan translationInView:self];
    _menuButton.center = CGPointMake(_buttonDragStartCenter.x + delta.x, _buttonDragStartCenter.y + delta.y);
    [self setNeedsLayout]; [self layoutIfNeeded];
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [NSUserDefaults.standardUserDefaults setFloat:_menuButton.frame.origin.x forKey:@"FloatingMenuBtnX"];
        [NSUserDefaults.standardUserDefaults setFloat:_menuButton.frame.origin.y forKey:@"FloatingMenuBtnY"];
    }
}

- (UIViewController *)viewControllerForView:(UIView *)view {
    UIResponder *r = view;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = [r nextResponder];
    return [r isKindOfClass:[UIViewController class]] ? (UIViewController *)r : nil;
}

- (void)resetTouchState {
    _touchOnButton = NO;
    _buttonDragging = NO;
    _trackingPointerId = -1;
}

- (void)presentModMenu {
    if (!ESPMatchReady()) return;
    if (self->_presentedModMenu) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!ESPMatchReady()) return;
        if (self->_presentedModMenu) return;
        
        UIViewController *parentVC = [self viewControllerForView:self];
        if (!parentVC) return;
        
        [self resetTouchState];
        
        _0xDEADBEEE *vc = [[_0xDEADBEEE alloc] init];
        CGRect b = self.bounds;
        if (b.size.width <= 0 || b.size.height <= 0) {
            b = [UIScreen mainScreen].bounds;
        }
        vc.view.frame = b;
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        vc.view.alpha = 1.0f;
        vc.view.transform = CGAffineTransformIdentity;
        
        __weak _0xB1872A2 *wself = self;
        vc.onCloseBlock = ^{
            [wself dismissModMenu];
        };
        vc.onExitHUDRequested = ^{
            if (wself && wself.onExitHUDRequested) {
                wself.onExitHUDRequested();
            }
        };
        self->_presentedModMenu = vc;
        
        [parentVC addChildViewController:vc];
        [self addSubview:vc.view];
        [vc didMoveToParentViewController:parentVC];
        [self bringSubviewToFront:vc.view];
        
        self.menuButton.hidden = YES;
    });
}

- (void)dismissModMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_presentedModMenu) return;
        
        _0xDEADBEEE *vc = self->_presentedModMenu;
        self->_presentedModMenu = nil;
        
        [vc willMoveToParentViewController:nil];
        [vc.view removeFromSuperview];
        [vc removeFromParentViewController];
        
        // Khôi phục hiển thị chuẩn cho nút menu
        self.menuButton.transform = CGAffineTransformIdentity;
        self.menuButton.alpha = 1.0f;
        self.menuButton.hidden = NO;
        self.menuButton.layer.zPosition = 999.0f;
        [self.menuButton.layer removeAllAnimations];
        
        // Kiểm tra toạ độ an toàn
        CGRect currentFrame = self.menuButton.frame;
        if (currentFrame.size.width < 10.0f || currentFrame.size.height < 10.0f ||
            currentFrame.origin.x < 0 || currentFrame.origin.y < 0) {
            [self loadMenuButtonPosition];
        }
        
        [self bringSubviewToFront:self.menuButton];
        [self resetTouchState];
        [self setNeedsLayout];
    });
}

- (void)showMenu {
    if (_presentedModMenu) return;
    [self presentModMenu];
}

- (void)hideMenu {
    if (_presentedModMenu) {
        [self dismissModMenu];
    }
}

- (BOOL)handleTouchAtWindowPoint:(CGPoint)windowPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    if (!ESPMatchReady() || self.hidden) return NO;
    CGPoint local = [self convertPoint:windowPoint fromView:self.window];
    const CGFloat kInset = 12.0f;
    CGRect btnHit = CGRectInset(_menuButton.frame, -kInset, -kInset);
    BOOL insideBtn = CGRectContainsPoint(btnHit, local);

    // KHI BẢNG MENU ĐANG MỞ
    if (_presentedModMenu) {
        CGPoint inMenuView = [self convertPoint:local toView:_presentedModMenu.view];
        if ([_presentedModMenu _0xF010:inMenuView phase:(NSInteger)phase pointerId:pointerId]) {
            return YES;
        }
        // Chạm vào bất kỳ điểm nào bên ngoài menu (màn hình game Free Fire Max) để đóng
        if (!insideBtn && phase == UITouchPhaseBegan) {
            [self dismissModMenu];
            return YES;
        }
        return YES;
    }

    // KHI MENU ĐANG ĐÓNG: Xử lý kéo thả nút
    switch (phase) {
        case UITouchPhaseBegan: {
            if (insideBtn && !_touchOnButton) {
                _touchOnButton = YES;
                _buttonDragging = NO;
                _trackingPointerId = pointerId;
                _buttonDragStartCenter = _menuButton.center;
                _buttonDragStartPoint = local;
                return YES;
            }
            return NO;
        }
        case UITouchPhaseMoved: {
            if (_touchOnButton && pointerId == _trackingPointerId) {
                const CGFloat kDragThreshold = 10.0f;
                CGFloat dx = local.x - _buttonDragStartPoint.x;
                CGFloat dy = local.y - _buttonDragStartPoint.y;
                
                if (!_buttonDragging && (fabs(dx) + fabs(dy) > kDragThreshold)) {
                    _buttonDragging = YES;
                }
                
                if (_buttonDragging) {
                    _menuButton.center = CGPointMake(_buttonDragStartCenter.x + dx, _buttonDragStartCenter.y + dy);
                    [self setNeedsLayout];
                    [self layoutIfNeeded];
                    _buttonDragStartCenter = _menuButton.center;
                    _buttonDragStartPoint = local;
                }
                return YES;
            }
            return NO;
        }
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled: {
            if (_touchOnButton && pointerId == _trackingPointerId) {
                BOOL wasDrag = _buttonDragging;
                [self resetTouchState];

                if (!wasDrag && phase == UITouchPhaseEnded) {
                    [self togglePanel];
                } else {
                    // CHỈ LƯU TỌA ĐỘ KHI ĐÃ KÉO THẢ XONG (tránh lưu đè khi bấm mở menu)
                    CGRect btnFrame = _menuButton.frame;
                    if (btnFrame.origin.x >= 0 && btnFrame.origin.y >= 0 && btnFrame.size.width >= kMenuButtonSize) {
                        [[NSUserDefaults standardUserDefaults] setFloat:(float)btnFrame.origin.x forKey:KH_NS("FloatingMenuBtnX")];
                        [[NSUserDefaults standardUserDefaults] setFloat:(float)btnFrame.origin.y forKey:KH_NS("FloatingMenuBtnY")];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                }
                return YES;
            }
            return NO;
        }
        default:
            return NO;
    }
}

- (BOOL)handleTouchAtLocalPoint:(CGPoint)localPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    return [self handleTouchAtWindowPoint:[self convertPoint:localPoint toView:self.window] phase:phase pointerId:pointerId];
}

- (void)togglePanel {
    if (_presentedModMenu) {
        [self dismissModMenu];
    } else {
        [self presentModMenu];
    }
}

- (void)reloadFloatingAuxButtonsFromPrefs {
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
