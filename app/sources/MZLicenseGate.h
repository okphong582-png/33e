#pragma once
#import <UIKit/UIKit.h>
@interface MZLicenseGate : NSObject
@property(class, nonatomic, readonly) BOOL authorized;
+ (UIViewController *)lockViewController;
+ (void)startWithAuthorized:(dispatch_block_t)authorized terminal:(void(^)(NSString *))terminal;
@end
