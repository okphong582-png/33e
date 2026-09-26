#pragma once
#import <Foundation/Foundation.h>
@interface LicenseSession : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL authorized;
- (BOOL)configured;
- (void)loginWithKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion;
- (void)refresh:(void (^)(BOOL, NSString *))completion;
- (void)logout;
- (void)monitor;
@end
