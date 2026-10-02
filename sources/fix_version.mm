#import <Foundation/Foundation.h>

// The Linux toolchain aliases this helper to __isOSVersionAtLeast. Returning
// true unconditionally also enabled selectors unavailable on the host iOS.
extern "C" int ___isOSVersionAtLeast(int major, int minor, int subminor) {
    NSOperatingSystemVersion required = {major, minor, subminor};
    return [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:required];
}
