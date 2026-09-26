// ============================================================
// _0xFAFAFFF.mm
// Killswitch - BẢN ĐÃ XÓA SERVER KILLSWITCH
// Giữ lại: Anti-Debug, Anti-Dyld Insert, VPN/Proxy Detection
// Đã xóa: GitHub Killswitch, Time Spoof Check, Network Monitor
// ============================================================

#import "_0xFAFAFFF.h"
#import "mahoa.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <pthread.h>
#import <termios.h>
#import <sys/ioctl.h>
#import <unistd.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#import <mach-o/loader.h>

// ============================================================
// MACRO MÃ HÓA - CHỈ DÙNG CHO STRING HIỂN THỊ
// ============================================================
#define _0xA001 "https://google.com"
#define _0xA002 "HEAD"
#define _0xA003 "Date"
#define _0xA004 "en_US"
#define _0xA005 "EEE',' dd MMM yyyy HH':'mm':'ss z"
#define _0xA006 "[_0xFAFAFFF] Time spoof detected!"
#define _0xA007 "[_0xFAFAFFF] No Internet!"
#define _0xA008 "[_0xFAFAFFF] checking..."

// [REMOVED] _0xA009 - GitHub URL đã bị xóa
// #define _0xA009 NSSENCRYPT("https://raw.githubusercontent.com/Hole30601/Notion_Update/main/Update7.txt")

#define _0xA010 "[!] Lỗi: %@"
#define _0xA011 "[_0xFAFAFFF] CONTENT = %@"
#define _0xA012 NSSENCRYPT("update=on")
#define _0xA013 "[_0xFAFAFFF] FOUND update=on"
#define _0xA014 NSSENCRYPT("Thông báo")
#define _0xA015 NSSENCRYPT("Update=ON")
#define _0xA016 "OK"
#define _0xA017 "[_0xFAFAFFF] VPN/Proxy detected"
#define _0xA018 "[_0xFAFAFFF] INIT"
#define _0xA019 "[_0xFAFAFFF] Not in Vietnam!"
#define _0xA020 "[_0xFAFAFFF] checking..."

// ============================================================
// CHỐNG DEBUG - PTRACE
// ============================================================
typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
#define PT_DENY_ATTACH 31

static void _0x1001_ptrace(void) {
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    if (handle) {
        ptrace_ptr_t ptrace_ptr = (ptrace_ptr_t)dlsym(handle, "ptrace");
        if (ptrace_ptr) {
            ptrace_ptr(PT_DENY_ATTACH, 0, 0, 0);
        }
        dlclose(handle);
    }
}

// ============================================================
// CHỐNG DEBUG - SYSCTL
// ============================================================
static bool _0x1002_sysctl(void) {
    int mib[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    info.kp_proc.p_flag = 0;
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    if (sysctl(mib, 4, &info, &info_size, NULL, 0) == -1) {
        return false;
    }
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

// ============================================================
// CHỐNG DEBUG - SYSCALL
// ============================================================
static void _0x1003_syscall(void) {
    syscall(26, 31, 0, 0);
}

// ============================================================
// CHỐNG DEBUG - ASM ARM64
// ============================================================
static void _0x1004_asm_arm64(void) {
#ifdef __arm64__
    __asm__ volatile (
        "mov x0, #26\n"
        "mov x1, #31\n"
        "mov x2, #0\n"
        "mov x3, #0\n"
        "mov x16, #0\n"
        "svc #128\n"
    );
#endif
}

// ============================================================
// CHỐNG DEBUG - TỔNG HỢP
// ============================================================
static void _0x1005_protect(void) {
    _0x1001_ptrace();
    _0x1003_syscall();
    _0x1004_asm_arm64();
}

// ============================================================
// KIỂM TRA CÓ ĐANG BỊ DEBUG KHÔNG
// ============================================================
static BOOL _0x1006_is_debugged(void) {
    // Kiểm tra sysctl
    if (_0x1002_sysctl()) {
        return YES;
    }

    // Kiểm tra isatty
    if (isatty(1)) {
        return YES;
    }

    // Kiểm tra ioctl
    struct winsize w;
    if (ioctl(1, TIOCGWINSZ, &w) == 0) {
        return YES;
    }

    // Kiểm tra task_get_exception_ports
    struct {
        exception_mask_t masks[EXC_TYPES_COUNT];
        mach_port_t ports[EXC_TYPES_COUNT];
        exception_behavior_t behaviors[EXC_TYPES_COUNT];
        thread_state_flavor_t flavors[EXC_TYPES_COUNT];
        mach_msg_type_number_t count;
    } info;

    kern_return_t kr = task_get_exception_ports(
        mach_task_self(),
        EXC_MASK_ALL,
        info.masks,
        &info.count,
        info.ports,
        info.behaviors,
        info.flavors
    );

    if (kr == KERN_SUCCESS) {
        for (int i = 0; i < info.count; i++) {
            if (info.ports[i] != 0) {
                return YES;
            }
        }
    }

    return NO;
}

// ============================================================
// KIỂM TRA P_TRACED (DÙNG CHO THREAD)
// ============================================================
static BOOL _0x1003(void) {
    size_t size = sizeof(struct kinfo_proc);
    struct kinfo_proc info;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    }
    return NO;
}

// ============================================================
// THREAD KIỂM TRA DEBUG LIÊN TỤC
// ============================================================
static void *_0x1004(void *p) {
    while (1) {
        if (_0x1003()) {
            // [MODIFIED] Không exit nữa, chỉ log
            // exit(0);
        }
        sleep(1);
    }
    return NULL;
}

// ============================================================
// CHỐNG DYLD INSERT + UNEXPECTED IMAGE
// ============================================================
static bool _0x1005(void) {
    const char *allowList[] = {
        ENCRYPT("/System/Library/"),
        ENCRYPT("/usr/lib/"),
        ENCRYPT("Frameworks/DataDomeSDK.framework"),
        NULL
    };

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;

        const char *exe = [[[NSBundle mainBundle] executablePath] UTF8String];
        if (strcmp(name, exe) == 0) continue;

        // CHO PHÉP FRAMEWORK TRONG APP BUNDLE
        NSString *nameStr = [NSString stringWithUTF8String:name];
        if ([nameStr containsString:NSSENCRYPT(".app/Frameworks/")]) {
            continue;
        }

        // CHO PHÉP CỤ THỂ DATADOMESDK
        if ([nameStr containsString:NSSENCRYPT("DataDomeSDK")]) {
            continue;
        }

        bool allowed = false;
        for (int j = 0; allowList[j]; j++) {
            if (strstr(name, allowList[j]) == name) {
                allowed = true;
                break;
            }
            if (strstr(name, allowList[j]) != NULL) {
                allowed = true;
                break;
            }
        }

        if (!allowed) {
            return true;
        }
    }
    return false;
}

// ============================================================
// CLASS KILLSWITCH
// ============================================================
@interface _0xFAFAFFF ()
@property (nonatomic, strong) dispatch_source_t _0x2001;
@end

@implementation _0xFAFAFFF

// ============================================================
// INIT
// ============================================================
- (instancetype)init {
    self = [super init];
    if (self) {
        _0x1005_protect();

        // KIỂM TRA DEBUG - KHÔNG EXIT NGAY
        if (_0x1006_is_debugged()) {
            // [MODIFIED] Không exit nữa
            // exit(0);
            NSLog(@"[_0xFAFAFFF] ⚠️ Debug detected (không exit)");
        }
    }
    return self;
}

// ============================================================
// START
// ============================================================
- (void)start {
    if (_0x1005()) {
        // [MODIFIED] Không exit nữa
        // exit(0);
        NSLog(@"[_0xFAFAFFF] ⚠️ Unexpected dylib detected (không exit)");
    }

    [self _0x2005];  // Timer chính
    [self _0x2006];  // Proxy check 1 lần

    // [REMOVED] DataDome check - đã xóa
    // [self _0xDA3553];

    // [REMOVED] cccccc - đã xóa
    // [self cccccc];
}

// ============================================================
// KIỂM TRA FRAMEWORK DATADOME CÓ LOAD KHÔNG
// ============================================================
- (BOOL)isDataDomeFrameworkLoaded {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworksPath = [bundlePath stringByAppendingPathComponent:NSSENCRYPT("Frameworks")];
    NSString *frameworkPath = [frameworksPath stringByAppendingPathComponent:NSSENCRYPT("DataDomeSDK.framework")];

    void *handle = dlopen(frameworkPath.UTF8String, RTLD_NOLOAD);
    if (handle) {
        dlclose(handle);
        return YES;
    }

    return NO;
}

// ============================================================
// KIỂM TRA FRAMEWORK TRONG BUNDLE (IPA)
// ============================================================
- (BOOL)_0xFFFFAC {
    NSString *_0xDCF1603 = [[NSBundle mainBundle] bundlePath];
    NSString *_0xB2862 = [_0xDCF1603 stringByAppendingPathComponent:NSSENCRYPT("Frameworks")];
    NSString *_0xFFFFFFFFFF = [_0xB2862 stringByAppendingPathComponent:NSSENCRYPT("DataDomeSDK.framework/DataDomeSDK")];

    NSFileManager *_0xFFFFFFFFFFF = [NSFileManager defaultManager];
    return [_0xFFFFFFFFFFF fileExistsAtPath:_0xFFFFFFFFFF];
}

// ============================================================
// MAIN CHECK - ĐÃ VÔ HIỆU HÓA
// ============================================================
- (void)_0xDA3553 {
    // [REMOVED] DataDome check - đã xóa hoàn toàn
    // Không gọi isDataDomeFrameworkLoaded nữa để tránh exit
}

// ============================================================
// PROXY CHECK - HTTP/HTTPS/SOCKS
// ============================================================
- (BOOL)_0x2007 {
    NSDictionary *settings = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    if (!settings) return NO;

    if ([settings[NSSENCRYPT("HTTPEnable")] boolValue]) return YES;
    if ([settings[NSSENCRYPT("HTTPSEnable")] boolValue]) return YES;
    if ([settings[NSSENCRYPT("SOCKSEnable")] boolValue]) return YES;
    if (settings[NSSENCRYPT("HTTPProxy")] ||
        settings[NSSENCRYPT("HTTPSProxy")] ||
        settings[NSSENCRYPT("SOCKSProxy")]) return YES;

    return NO;
}

// ============================================================
// VPN CHECK - TAP/TUN/PPP/IPSEC/UTUN
// ============================================================
- (BOOL)_0x2008 {
    NSDictionary *settings = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    if (!settings) return NO;

    NSDictionary *scoped = settings[NSSENCRYPT("__SCOPED__")];
    if (![scoped isKindOfClass:[NSDictionary class]]) return NO;

    for (NSString *key in scoped.allKeys) {
        if ([key hasPrefix:NSSENCRYPT("utun")] ||
            [key hasPrefix:NSSENCRYPT("tap")] ||
            [key hasPrefix:NSSENCRYPT("tun")] ||
            [key hasPrefix:NSSENCRYPT("ppp")] ||
            [key containsString:NSSENCRYPT("ipsec")]) {
            return YES;
        }
    }
    return NO;
}

// ============================================================
// PROXY CHECK - GỌI TỪ TIMER
// ============================================================
- (void)_0x2006 {
    if ([self _0x2008] || [self _0x2007]) {
        // [MODIFIED] Không exit nữa
        // dispatch_async(dispatch_get_main_queue(), ^{
        //     exit(0);
        // });
        NSLog(@"[_0xFAFAFFF] ⚠️ VPN/Proxy detected (không exit)");
    }
}

// ============================================================
// LẤY UUID CỦA FILE MACH-O
// ============================================================
- (NSString *)_0xAAAAAAAF:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;

    const uint8_t *bytes = (const uint8_t *)data.bytes;
    const struct mach_header_64 *mh = (const struct mach_header_64 *)bytes;

    if (mh->magic != MH_MAGIC_64 && mh->magic != MH_CIGAM_64) {
        return nil;
    }

    const struct load_command *cmd =
        (const struct load_command *)(bytes + sizeof(struct mach_header_64));

    for (uint32_t i = 0; i < mh->ncmds; i++) {
        if (cmd->cmd == LC_UUID) {
            const struct uuid_command *uc = (const struct uuid_command *)cmd;
            uuid_t uuid;
            memcpy(uuid, uc->uuid, sizeof(uuid));
            uuid_string_t out;
            uuid_unparse_upper(uuid, out);
            return [NSString stringWithUTF8String:out];
        }
        cmd = (const struct load_command *)((const uint8_t *)cmd + cmd->cmdsize);
    }
    return nil;
}

// ============================================================
// TIME SPOOF CHECK - ĐÃ VÔ HIỆU HÓA
// ============================================================
- (void)_0x2010 {
    // [REMOVED] Time spoof check - đã xóa hoàn toàn
    // Không gọi google.com nữa
}

// ============================================================
// NETWORK MONITOR - ĐÃ VÔ HIỆU HÓA
// ============================================================
static void _0x2011(SCNetworkReachabilityRef target,
                     SCNetworkReachabilityFlags flags,
                     void *info) {
    // [REMOVED] Network monitor - đã xóa hoàn toàn
}

- (void)_0x2012 {
    // [REMOVED] Network monitor - đã xóa hoàn toàn
}

// ============================================================
// GITHUB KILLSWITCH - ĐÃ VÔ HIỆU HÓA
// ============================================================
- (void)_0x2013 {
    // [REMOVED] GitHub killswitch - đã xóa hoàn toàn
    // Không gọi raw.githubusercontent.com nữa
}

// ============================================================
// TIMER CHÍNH - CHỈ GIỮ ANTI-DEBUG
// ============================================================
- (void)_0x2005 {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    self._0x2001 = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    // 5 giây / lần
    dispatch_source_set_timer(self._0x2001,
                              dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                              5 * NSEC_PER_SEC,
                              1 * NSEC_PER_SEC);

    __weak __typeof__(self) weakSelf = self;
    dispatch_source_set_event_handler(self._0x2001, ^{
        __strong __typeof__(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // [REMOVED] Tất cả server checks - đã xóa
        // [strongSelf _0x2006];   // Proxy check
        // [strongSelf _0x2012];   // Network monitor
        // [strongSelf _0x2010];   // Time check
        // [strongSelf _0x2013];   // GitHub check
        // [strongSelf _0xDA3553]; // DataDome check

        // Chỉ giữ anti-debug check
        if (_0x1005()) {
            // [MODIFIED] Không exit nữa
            // exit(0);
        }
        if (_0x1003()) {
            // [MODIFIED] Không exit nữa
            // exit(0);
        }
    });

    dispatch_resume(self._0x2001);
}

// ============================================================
// CONSTRUCTOR - CHỈ GIỮ ANTI-DEBUG THREAD
// ============================================================
__attribute__((constructor)) static void _0x3001() {
    // [REMOVED] Killswitch auto-start - đã xóa
    // Không tự động chạy killswitch nữa

    // Chỉ giữ anti-debug thread
    pthread_t thread;
    pthread_create(&thread, NULL, _0x1004, NULL);
    pthread_detach(thread);

    // [REMOVED] Auto-start killswitch sau 3s - đã xóa
    // dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
    //                dispatch_get_main_queue(), ^{
    //     _0xFAFAFFF *ks = [[_0xFAFAFFF alloc] init];
    //     [ks start];
    // });
}

// ============================================================
// DEALLOC
// ============================================================
- (void)dealloc {
    if (self._0x2001) {
        dispatch_source_cancel(self._0x2001);
        self._0x2001 = nil;
    }
}

@end