#import <Foundation/Foundation.h>
#import "../esp/Core/NetworkHelper.h"
#include <cassert>

static int requests = 0;
@interface DelayedOffsetProvider : _0xFFFA282
@end
@implementation DelayedOffsetProvider
+ (void)_0xFFFFFFFF:(NSString *)key _0xFAAAAAAAAA:(void(^)(uintptr_t, NSError *))completion {
    ++requests;
    // A mocked server uses the main queue, reproducing the deadlock caused by
    // a synchronous wait on a render callback. No network traffic is sent.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if ([key isEqualToString:@"failure"])
            completion(0, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]);
        else completion(0xb8, nil);
    });
}
@end

int main() {
    @autoreleasepool {
        const NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
        assert([DelayedOffsetProvider _0xFFFFFFF:@"slow"] == 0);
        assert(NSProcessInfo.processInfo.systemUptime - start < 0.1);
        for (int frame = 0; frame < 600; ++frame)
            assert([DelayedOffsetProvider _0xFFFFFFF:@"slow"] == 0);
        assert(requests == 1);
        __block int ticks = 0;
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES block:^(NSTimer *) { ++ticks; }];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        assert(ticks >= 5);
        assert([DelayedOffsetProvider _0xFFFFFFF:@"slow"] == 0xb8);
        assert(requests == 1);
        assert([DelayedOffsetProvider _0xFFFFFFF:@"failure"] == 0);
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        for (int frame = 0; frame < 600; ++frame)
            assert([DelayedOffsetProvider _0xFFFFFFF:@"failure"] == 0);
        assert(requests == 2); // Timeout backs off instead of starting 600 requests.
        [timer invalidate];
        puts("Offset fetch: responsive main loop, shared cache, bounded retry passed.");
    }
}
