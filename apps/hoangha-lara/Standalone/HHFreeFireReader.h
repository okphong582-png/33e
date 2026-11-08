#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class RemoteCall;
@interface HHFreeFireReader : NSObject
@property(nonatomic,readonly) RemoteCall *session;
@property(nonatomic,readonly) NSString *status;
- (BOOL)connectIfNeeded;
- (NSArray<NSValue *> *)boxesForSize:(CGSize)size;
- (void)disconnect;
@end
