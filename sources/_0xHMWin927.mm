// HUDMainWindow.mm - THÊM SWIZZLE HOẶC OVERRIDE TẤT CẢ METHOD LIÊN QUAN ĐẾN ROTATE

#import "HUDMainWindow.h"
#import "UIAutoRotatingWindow.h"
#include "KabraxHide.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>


@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_isSecure { return YES; }
- (BOOL)_shouldCreateContextAsSecure { return YES; }

- (BOOL)_shouldControlAutorotation {
    return YES;
}

- (BOOL)_shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)_usesWindowServerHitTesting {
    return YES;
}

- (BOOL)_ignoresHitTest {
    return NO;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super _initWithFrame:frame attached:YES];

    if (self)
    {
        self.backgroundColor = UIColor.clearColor;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;
    }

    return self;
}

@end