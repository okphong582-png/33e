#import <Foundation/Foundation.h>

extern "C" int __isOSVersionAtLeast(int major, int minor, int patch) {
    NSOperatingSystemVersion required = {major, minor, patch};
    return [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:required];
}

extern "C" int __isPlatformVersionAtLeast(int platform, int major, int minor, int patch) {
    if (platform != 2) return 0;
    return __isOSVersionAtLeast(major, minor, patch);
}
