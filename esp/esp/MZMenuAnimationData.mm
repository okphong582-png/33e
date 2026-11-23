#import "MZMenuAnimationData.h"
#import <ImageIO/ImageIO.h>
#include <cmath>

@implementation MZMenuAnimationData
+ (instancetype)decodeURL:(NSURL *)url {
    if (!url) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url,
        (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache: @NO});
    if (!source) return nil;
    @try {
        const size_t count = CGImageSourceGetCount(source);
        if (count < 2 || count > 240) return nil;
        NSMutableArray *frames = [NSMutableArray arrayWithCapacity:count + 1];
        NSMutableArray<NSNumber *> *starts = [NSMutableArray arrayWithCapacity:count + 1];
        NSTimeInterval duration = 0;
        NSUInteger bytes = 0;
        for (size_t i = 0; i < count; ++i) {
            @autoreleasepool {
                NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, NULL));
                NSDictionary *gif = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
                NSNumber *delay = gif[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime]
                               ?: gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
                double seconds = [delay doubleValue];
                if (!std::isfinite(seconds) || seconds < 0.01) seconds = 0.1;
                if (duration + seconds > 60) return nil;
                CGImageRef frame = CGImageSourceCreateThumbnailAtIndex(source, i,
                    (__bridge CFDictionaryRef)@{
                        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @96,
                        (__bridge NSString *)kCGImageSourceShouldCacheImmediately: @YES});
                if (!frame) return nil;
                NSUInteger frameBytes = CGImageGetBytesPerRow(frame) * CGImageGetHeight(frame);
                if (CGImageGetWidth(frame) > 96 || CGImageGetHeight(frame) > 96 ||
                    frameBytes > 9 * 1024 * 1024 - bytes) {
                    CGImageRelease(frame);
                    return nil;
                }
                [frames addObject:CFBridgingRelease(frame)];
                [starts addObject:@(duration)];
                bytes += frameBytes;
                duration += seconds;
            }
        }
        for (NSUInteger i = 0; i < starts.count; ++i) starts[i] = @([starts[i] doubleValue] / duration);
        // Discrete contents keep the last frame for its full GIF delay.
        [frames addObject:frames.firstObject];
        [starts addObject:@1.0];
        MZMenuAnimationData *result = [MZMenuAnimationData new];
        result->_frames = [frames copy];
        result->_keyTimes = [starts copy];
        result->_duration = duration;
        result->_decodedBytes = bytes;
        return result;
    } @finally {
        CFRelease(source);
    }
}
@end
