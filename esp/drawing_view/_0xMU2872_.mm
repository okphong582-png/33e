#import "menu.h"
#import "icons.h"
#import "ModMenuViewController.h"
#import "ESPPrefs.h"
#import "esp.h"
#import "../../mahoa.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#include "KabraxHide.h"

static const CGFloat kMenuButtonSize = 64.0f;

@interface _0xB1872A2 ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIImageView *gifImageView;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL touchOnButton;
@property (nonatomic, assign) BOOL buttonDragging;
@property (nonatomic, assign) CGPoint buttonDragStartCenter;
@property (nonatomic, assign) CGPoint buttonDragStartPoint;
@property (nonatomic, strong) _0xDEADBEEE *presentedModMenu;
@end

@implementation _0xB1872A2

- (UIImage *)loadAnimatedGIFNamed:(NSString *)name {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    if (!path) {
        path = [[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
    }
    if (!path) {
        path = [@"/Applications/Bugchi.app" stringByAppendingPathComponent:name];
    }
    if (!path) {
        path = @"/Applications/Bugchi.app/Dragon Ball Z Rage GIF.gif";
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    
    NSDictionary *sourceOptions = @{(__bridge NSString *)kCGImageSourceShouldCache: @NO};
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)sourceOptions);
    if (!source) return nil;
    
    size_t count = CGImageSourceGetCount(source);
    if (count == 0) {
        CFRelease(source);
        return nil;
    }
    
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    NSTimeInterval totalDuration = 0.0;
    
    // A 64-point button does not need every full-resolution GIF frame resident.
    const size_t stride = MAX((size_t)1, (count + 47) / 48);
    CGFloat scale = MIN(UIScreen.mainScreen.scale, 3.0);
    NSDictionary *thumbnailOptions = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(kMenuButtonSize * scale),
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES
    };
    for (size_t i = 0; i < count; i++) {
        if (i % stride == 0) {
            CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, i, (__bridge CFDictionaryRef)thumbnailOptions);
            if (imageRef) {
                [images addObject:[UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp]];
                CGImageRelease(imageRef);
            }
        }
        float frameDuration = 0.08f;
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        if (properties) {
            CFDictionaryRef gifProps = (CFDictionaryRef)CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            if (gifProps) {
                NSNumber *delayTime = (__bridge NSNumber *)CFDictionaryGetValue(gifProps, kCGImagePropertyGIFUnclampedDelayTime);
                if (!delayTime || [delayTime floatValue] == 0) {
                    delayTime = (__bridge NSNumber *)CFDictionaryGetValue(gifProps, kCGImagePropertyGIFDelayTime);
                }
                if (delayTime && [delayTime floatValue] > 0) {
                    frameDuration = [delayTime floatValue];
                }
            }
            CFRelease(properties);
        }
        totalDuration += frameDuration;
    }
    CFRelease(source);
    if (images.count == 0) return nil;
    if (images.count == 1) return images.firstObject;
    return [UIImage animatedImageWithImages:images duration:totalDuration > 0 ? totalDuration : (count * 0.08f)];
}

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
        _gifImageView.frame = _menuButton.bounds;
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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(releaseAnimationFrames)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resetTouchState)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [self setupMenuButton];
    }
    return self;
}

- (void)setupMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    _menuButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    _menuButton.layer.cornerRadius = kMenuButtonSize / 2.0f;
    _menuButton.layer.borderWidth = 1.5f;
    _menuButton.layer.borderColor = [UIColor colorWithRed:0.48f green:0.65f blue:1.0f alpha:0.9f].CGColor;
    _menuButton.layer.shadowOpacity = 0;
    _menuButton.layer.zPosition = 999.0f;
    _menuButton.clipsToBounds = YES;
    
    _gifImageView = [[UIImageView alloc] initWithFrame:_menuButton.bounds];
    _gifImageView.contentMode = UIViewContentModeScaleAspectFill;
    _gifImageView.clipsToBounds = YES;
    _gifImageView.layer.cornerRadius = kMenuButtonSize / 2.0f;
    _gifImageView.userInteractionEnabled = NO;
    
    UIImage *gifAnim = [self loadAnimatedGIFNamed:@"Dragon Ball Z Rage GIF.gif"];
    if (gifAnim) {
        _gifImageView.image = gifAnim;
    } else {
        UIImage *icon = FloatButtonIcon();
        if (icon) {
            _gifImageView.image = icon;
        } else {
            [_menuButton setTitle:KH_NS("DBZ") forState:UIControlStateNormal];
            [_menuButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
            _menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0f];
        }
    }
    
    [_menuButton addSubview:_gifImageView];
    [self addSubview:_menuButton];
    [self loadMenuButtonPosition];
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

- (void)releaseAnimationFrames {
    UIImage *first = _gifImageView.image.images.firstObject;
    if (first) _gifImageView.image = first;
}

- (void)presentModMenu {
    if (self->_presentedModMenu) return;
    dispatch_async(dispatch_get_main_queue(), ^{
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
