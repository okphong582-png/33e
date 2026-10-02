#import <Foundation/Foundation.h>
#include <cassert>

extern "C" int ___isOSVersionAtLeast(int major, int minor, int subminor);
int main() {
    @autoreleasepool {
        NSOperatingSystemVersion os = NSProcessInfo.processInfo.operatingSystemVersion;
        assert(___isOSVersionAtLeast((int)os.majorVersion, (int)os.minorVersion, (int)os.patchVersion));
        assert(___isOSVersionAtLeast(1, 0, 0));
        assert(!___isOSVersionAtLeast((int)os.majorVersion + 1, 0, 0));
        assert(!___isOSVersionAtLeast((int)os.majorVersion, (int)os.minorVersion + 1, 0));
        assert(!___isOSVersionAtLeast((int)os.majorVersion, (int)os.minorVersion, (int)os.patchVersion + 1));
        puts("OS availability follows actual host version: passed");
    }
}
