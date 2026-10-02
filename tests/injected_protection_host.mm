#import <UIKit/UIKit.h>
@implementation UIApplication
+ (instancetype)sharedApplication {
    static UIApplication* value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [UIApplication new]; });
    return value;
}
@end
