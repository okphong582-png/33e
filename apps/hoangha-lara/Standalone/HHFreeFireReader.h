#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface HHFreeFireReader : NSObject
@property(nonatomic,readonly) NSString *status;
- (BOOL)connectIfNeededForPID:(pid_t)pid;
- (NSArray<NSValue *> *)boxesForSize:(CGSize)size;
- (void)disconnect;
@end
