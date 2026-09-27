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

#import <sys/sysctl.h>
#import <unistd.h>
#import <sys/types.h>

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

static void EnableAntiDebugProtection(void) {
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif
    void *handle = dlopen(NULL, RTLD_GLOBAL | RTLD_NOW);
    if (handle) {
        ptrace_ptr_t ptrace_ptr = (ptrace_ptr_t)dlsym(handle, "ptrace");
        if (ptrace_ptr) {
            ptrace_ptr(PT_DENY_ATTACH, 0, 0, 0);
        }
        dlclose(handle);
    }
}

@implementation AntiHook

+ (void)runDefaultChecksWithCallback:(void (^)(NSString *))onHookDetected {
    EnableAntiDebugProtection();
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