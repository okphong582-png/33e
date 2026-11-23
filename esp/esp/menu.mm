#import "menu.h"
#import "ModMenuViewController.h"
#import "ESPPrefs.h"
#import "MZAnimatedMenuIcon.h"
#import <QuartzCore/QuartzCore.h>
#include <cmath>

static const CGFloat kMenuButtonSize = 56.0;

@interface HTHIconSecureWrapper : UITextField
@end
@implementation HTHIconSecureWrapper
- (BOOL)canBecomeFirstResponder { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }
@end

@interface MenuView ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) MZAnimatedMenuIcon *menuIcon;
@property (nonatomic, strong) NSTimer *visibilityTimer;
@property (nonatomic, strong) HTHIconSecureWrapper *secureTextField;
@property (nonatomic, strong) UIView *secureCanvas;
@property (nonatomic, strong) ModMenuViewController *presentedModMenu;
@property (nonatomic) NSInteger trackingPointerId;
@property (nonatomic) BOOL buttonDragging;
@property (nonatomic) CGPoint dragStartCenter;
@property (nonatomic) CGPoint dragStartPoint;
@end

@implementation MenuView
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;
    _trackingPointerId = -1;
    _secureTextField = [[HTHIconSecureWrapper alloc] initWithFrame:self.bounds];
    _secureTextField.userInteractionEnabled = NO;
    _secureTextField.backgroundColor = UIColor.clearColor;
    _secureTextField.text = @"\u200B";
    _secureTextField.textColor = UIColor.clearColor;
    _secureTextField.secureTextEntry = ESPPrefsBool(@"StreamerMode", NO);
    [self addSubview:_secureTextField];
    [_secureTextField layoutIfNeeded];
    _secureCanvas = _secureTextField.subviews.firstObject ?: _secureTextField;
    _secureCanvas.userInteractionEnabled = NO;
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat x = ESPPrefsFloat(@"FloatingMenuBtnX", 20);
    CGFloat y = ESPPrefsFloat(@"FloatingMenuBtnY", 100);
    if (!std::isfinite(x) || !std::isfinite(y)) { x = 20; y = 100; }
    _menuButton.frame = CGRectMake(x, y, kMenuButtonSize, kMenuButtonSize);
    _menuButton.backgroundColor = UIColor.blackColor;
    _menuButton.layer.cornerRadius = kMenuButtonSize / 2;
    _menuButton.clipsToBounds = YES;
    _menuButton.accessibilityLabel = @"Mizze — mở menu";
    _menuIcon = [[MZAnimatedMenuIcon alloc] initWithFrame:_menuButton.bounds];
    _menuIcon.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_menuButton addSubview:_menuIcon];
    [_secureCanvas addSubview:_menuButton];
    [self updateVisibility];
    return self;
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.visibilityTimer invalidate];
    self.visibilityTimer = nil;
    if (self.window) {
        // Weak capture breaks the old MenuView -> display link -> MenuView cycle.
        // Preference visibility needs 5 Hz, not a second 60/120 Hz frame loop.
        __weak MenuView *weakSelf = self;
        self.visibilityTimer = [NSTimer timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *timer) {
            [weakSelf updateVisibility];
        }];
        [NSRunLoop.mainRunLoop addTimer:self.visibilityTimer forMode:NSRunLoopCommonModes];
        [self updateVisibility];
    } else {
        self.menuIcon.playing = NO;
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.secureTextField.frame = self.bounds;
    self.secureCanvas.frame = self.bounds;
    [self clampMenuButton];
    if (self.presentedModMenu) {
        self.presentedModMenu.view.frame = self.bounds;
        [self bringSubviewToFront:self.presentedModMenu.view];
    }
}
- (void)clampMenuButton {
    if (self.bounds.size.width < kMenuButtonSize || self.bounds.size.height < kMenuButtonSize) return;
    CGRect frame = self.menuButton.frame;
    frame.origin.x = MAX(0, MIN(frame.origin.x, self.bounds.size.width - kMenuButtonSize));
    frame.origin.y = MAX(0, MIN(frame.origin.y, self.bounds.size.height - kMenuButtonSize));
    self.menuButton.frame = frame;
}
- (void)updateVisibility {
    BOOL streamer = ESPPrefsBool(@"StreamerMode", NO);
    if (self.secureTextField.secureTextEntry != streamer) {
        [self.menuButton removeFromSuperview];
        self.secureTextField.secureTextEntry = streamer;
        [self.secureTextField setNeedsLayout];
        [self.secureTextField layoutIfNeeded];
        self.secureCanvas = self.secureTextField.subviews.firstObject ?: self.secureTextField;
        self.secureCanvas.userInteractionEnabled = NO;
        [self.secureCanvas addSubview:self.menuButton];
    }
    self.menuButton.hidden = self.presentedModMenu != nil || ESPPrefsBool(@"HideMenu1", NO);
    self.menuIcon.playing = self.window && !self.menuButton.hidden && !self.buttonDragging;
}
- (void)reloadFloatingAuxButtonsFromPrefs { [self updateVisibility]; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit || hit == self || hit == self.secureCanvas || hit == self.secureTextField ||
        hit == self.menuButton || [hit isDescendantOfView:self.menuButton] ||
        hit == self.presentedModMenu.view) return nil;
    return hit; // Empty overlay space never blocks the game's touches.
}
- (UIViewController *)parentController {
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:UIViewController.class]) responder = responder.nextResponder;
    return [responder isKindOfClass:UIViewController.class] ? (UIViewController *)responder : self.window.rootViewController;
}
- (void)showMenu {
    if (self.presentedModMenu) return;
    UIViewController *parent = [self parentController];
    if (!parent) return;
    ModMenuViewController *menu = [ModMenuViewController new];
    menu.view.frame = self.bounds;
    __weak MenuView *weakSelf = self;
    menu.onCloseBlock = ^{ [weakSelf hideMenu]; };
    menu.onExitHUDRequested = ^{ if (weakSelf.onExitHUDRequested) weakSelf.onExitHUDRequested(); };
    self.presentedModMenu = menu;
    [parent addChildViewController:menu];
    [self addSubview:menu.view];
    [menu didMoveToParentViewController:parent];
    [self updateVisibility];
}
- (void)hideMenu {
    ModMenuViewController *menu = self.presentedModMenu;
    if (!menu) return;
    self.presentedModMenu = nil;
    [menu willMoveToParentViewController:nil];
    [menu.view removeFromSuperview];
    [menu removeFromParentViewController];
    [self updateVisibility];
}
- (BOOL)handleTouchAtWindowPoint:(CGPoint)point phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    if (!std::isfinite(point.x) || !std::isfinite(point.y)) return NO;
    CGPoint local = self.window ? [self convertPoint:point fromView:self.window] : point;
    if (self.presentedModMenu) {
        CGPoint inMenu = [self convertPoint:local toView:self.presentedModMenu.view];
        return [self.presentedModMenu handleTouchAtViewPoint:inMenu phase:(NSInteger)phase pointerId:pointerId];
    }
    if (phase == UITouchPhaseBegan) {
        if (self.trackingPointerId != -1 || self.menuButton.hidden ||
            !CGRectContainsPoint(CGRectInset(self.menuButton.frame, -12, -12), local)) return NO;
        self.trackingPointerId = pointerId;
        self.buttonDragging = NO;
        self.dragStartCenter = self.menuButton.center;
        self.dragStartPoint = local;
        return YES;
    }
    if (pointerId != self.trackingPointerId || self.trackingPointerId == -1) return NO;
    if (phase == UITouchPhaseMoved) {
        CGFloat dx = local.x - self.dragStartPoint.x, dy = local.y - self.dragStartPoint.y;
        if (!ESPPrefsBool(@"LockMenuIcon", NO)) {
            if (fabs(dx) + fabs(dy) > 10) self.buttonDragging = YES;
            if (self.buttonDragging) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                self.menuButton.center = CGPointMake(self.dragStartCenter.x + dx, self.dragStartCenter.y + dy);
                [self clampMenuButton];
                [CATransaction commit];
                self.menuIcon.playing = NO;
            }
        }
        return YES;
    }
    if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        BOOL dragged = self.buttonDragging;
        self.trackingPointerId = -1;
        self.buttonDragging = NO;
        if (phase == UITouchPhaseEnded) {
            if (dragged) {
                ESPPrefsSetFloat(@"FloatingMenuBtnX", self.menuButton.frame.origin.x);
                ESPPrefsSetFloat(@"FloatingMenuBtnY", self.menuButton.frame.origin.y);
                ESPPrefsSync();
            } else { [self showMenu]; }
        }
        [self updateVisibility];
        return YES;
    }
    return YES;
}
- (BOOL)handleTouchAtLocalPoint:(CGPoint)point phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    return [self handleTouchAtWindowPoint:self.window ? [self convertPoint:point toView:self.window] : point phase:phase pointerId:pointerId];
}
- (void)dealloc { [_visibilityTimer invalidate]; }
@end
