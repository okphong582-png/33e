#pragma once
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSNotificationName const LicenseSessionDidBecomeUnauthorizedNotification;
// Unauthorized notifications carry NSString values under "message" and "reason".

@interface LicenseSession : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL authorized;
@property (atomic, copy, readonly) NSString *lastMessage;
@property (atomic, readonly) NSTimeInterval expiresAt;
- (BOOL)configured;
- (void)loginWithKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion;
// YES means this request was verified online. A transient failure never extends
// an existing short lease; use authorized to decide whether a running UI must stop.
- (void)refresh:(void (^)(BOOL, NSString *))completion;
- (void)logout;
- (void)monitor;
@end
