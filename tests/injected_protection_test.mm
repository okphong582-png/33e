#import <Foundation/Foundation.h>
#import "../sources/InjectedProtection.h"
#include "../obfuscation/AntiREProtection.h"
#include <cassert>
#include <thread>
#include <vector>

int main() {
    @autoreleasepool {
        assert(NSThread.isMainThread && !ANTI_RE_CHECK());
        for (unsigned i = 0; i < 16; ++i) MizzeStartOwnCodeProtection();
        NSTimeInterval end = NSProcessInfo.processInfo.systemUptime + 5;
        while (!_anti_re_::state().initialized.load() && NSProcessInfo.processInfo.systemUptime < end)
            [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        assert(ANTI_RE_CHECK());
        assert(_monite_::monitors().count == 6); // Four code sections + two exact data spans.
        std::vector<std::thread> threads;
        for (unsigned i = 0; i < 8; ++i) threads.emplace_back([] {
            @autoreleasepool {
                for (unsigned j = 0; j < 100; ++j)
                    assert([MizzeDefaultLicenseDatabaseURL() isEqualToString:@"https://appchatai-313e3-default-rtdb.firebaseio.com"]);
            }
        });
        for (auto& thread : threads) thread.join();
        assert(ANTI_RE_CHECK());
        puts("Injected protection: deferred once-only startup and concurrent config decode passed.");
    }
}
