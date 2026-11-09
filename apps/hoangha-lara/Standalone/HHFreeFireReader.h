#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface HHFreeFireReader : NSObject
@property(nonatomic,readonly,nonnull) NSString *status;
- (BOOL)connectIfNeededForPID:(pid_t)pid;
- (nullable NSArray<NSValue *> *)boxesForSize:(CGSize)size;
- (void)disconnect;
@end
