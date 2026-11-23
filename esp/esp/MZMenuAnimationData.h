#import <Foundation/Foundation.h>

// Immutable, display-sized frames. Decode once, never on the drawing timer.
@interface MZMenuAnimationData : NSObject
@property (nonatomic, copy, readonly) NSArray *frames;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *keyTimes;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSUInteger decodedBytes;
+ (instancetype)decodeURL:(NSURL *)url;
@end
