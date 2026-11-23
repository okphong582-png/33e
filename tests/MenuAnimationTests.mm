#import "../esp/esp/MZMenuAnimationData.h"
#import <CoreGraphics/CoreGraphics.h>
#include <cassert>
#include <cmath>
#include <cstdio>

int main(int argc, const char **argv) {
    @autoreleasepool {
        assert(argc == 2);
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        for (int repeat = 0; repeat < 3; ++repeat) {
            @autoreleasepool {
                MZMenuAnimationData *data = [MZMenuAnimationData decodeURL:url];
                assert(data && data.frames.count == 174 && data.frames.count == data.keyTimes.count);
                assert(std::abs(data.duration - 8.0) < 0.001);
                assert(data.decodedBytes > 0 && data.decodedBytes <= 9 * 1024 * 1024);
                assert([data.keyTimes.firstObject doubleValue] == 0);
                assert([data.keyTimes.lastObject doubleValue] == 1);
                for (NSUInteger i = 0; i + 1 < data.frames.count; ++i) {
                    assert([data.keyTimes[i] doubleValue] < [data.keyTimes[i+1] doubleValue]);
                    CGImageRef frame = (__bridge CGImageRef)data.frames[i];
                    assert(CGImageGetWidth(frame) <= 96 && CGImageGetHeight(frame) <= 96);
                }
                assert(data.frames.lastObject == data.frames.firstObject);
            }
        }
        assert(![MZMenuAnimationData decodeURL:nil]);
        NSURL *bad = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        [@"GIF89a broken truncated data" writeToURL:bad atomically:YES encoding:NSUTF8StringEncoding error:nil];
        assert(![MZMenuAnimationData decodeURL:bad]);
        [NSFileManager.defaultManager removeItemAtURL:bad error:nil];
        assert(![MZMenuAnimationData decodeURL:bad]);
        puts("PASS: supplied 173-frame GIF, exact 8s timing, bounded thumbnails, repeated release, invalid/missing GIF fallback");
    }
}
