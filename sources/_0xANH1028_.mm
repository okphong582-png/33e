#import "AntiHook.h"
#import "MSHookFunctionChecker.h"
#import <dlfcn.h>

// Danh sách hàm mặc định cần giám sát
static const char *defaultFunctionNames[] = {
    "objc_msgSend",
    "dladdr",
    "getenv",
    "sysctl",
    "malloc",
    "free",
    "fopen",
    NULL
};

@implementation AntiHook

+ (void)runDefaultChecksWithCallback:(void (^)(NSString *))onHookDetected {
    for (int i = 0; defaultFunctionNames[i] != NULL; i++) {
        const char *name = defaultFunctionNames[i];
        void *addr = dlsym(RTLD_DEFAULT, name);
        if (!addr) continue;

        if ([MSHookFunctionChecker amIMSHooked:addr]) {
            if (onHookDetected) {
                onHookDetected([NSString stringWithUTF8String:name]);
            }
        }
    }
}

+ (void *)originalImplementationForFunction:(void *)functionAddr {
    if (!functionAddr) return NULL;
    return [MSHookFunctionChecker denyMSHook:functionAddr];
}

@end