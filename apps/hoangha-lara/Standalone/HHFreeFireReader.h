#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface HHFreeFireReader : NSObject
@property(nonatomic,readonly,nonnull) NSString *status;
@property(nonatomic) BOOL silentEnabled;
- (BOOL)connectIfNeededForPID:(pid_t)pid;
- (nullable NSArray<NSValue *> *)boxesForSize:(CGSize)size;
- (nullable NSString *)takeAimCapabilityReport;
- (nullable NSString *)takeSilentReport;
- (void)disconnect;
@end
