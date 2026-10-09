#import "LaraMemoryReader.h"
#include "../lara/kexploit/darksword.h"
#include "../lara/kexploit/offsets.h"
#include "../lara/kexploit/utils.h"
#include <sys/sysctl.h>
#include <mach-o/loader.h>

// Code Signing Flags Definitions (XNU Kernel)
#define CS_VALID            0x00000001
#define CS_GET_TASK_ALLOW   0x00000004
#define CS_INSTALLER        0x00000008
#define CS_HARD             0x00000100
#define CS_KILL             0x00000200
#define CS_RESTRICT         0x00000800
#define CS_DEBUGGED         0x10000000

// Fallback Offsets if offset table not loaded
static const uint64_t OFF_PROC_LIST_NEXT = 0x0;   // p_list.le_next
static const uint64_t OFF_PROC_PID       = 0x60;  // p_pid
static const uint64_t OFF_PROC_TASK      = 0x10;  // task
static const uint64_t OFF_PROC_NAME      = 0x380; // p_name (comm)
static const uint64_t OFF_TASK_MAP       = 0x28;  // map

@interface LaraMemoryReader ()
@property (nonatomic, assign, readwrite) pid_t targetPID;
@property (nonatomic, assign, readwrite) uint64_t targetProcAddress;
@property (nonatomic, assign, readwrite) uint64_t targetTaskAddress;
@property (nonatomic, assign, readwrite) uint64_t targetMapAddress;
@property (nonatomic, assign, readwrite) uint64_t mainModuleBase;
@property (nonatomic, assign, readwrite) BOOL isKernelReady;
@end

@implementation LaraMemoryReader

+ (instancetype)sharedInstance {
    static LaraMemoryReader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LaraMemoryReader alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _targetPID = 0;
        _targetProcAddress = 0;
        _targetTaskAddress = 0;
        _targetMapAddress = 0;
        _mainModuleBase = 0;
        _isKernelReady = NO;
    }
    return self;
}

- (BOOL)initializeKernelExploit {
    if (ds_is_ready()) {
        _isKernelReady = YES;
        return YES;
    }
    
    int status = ds_run();
    if (status == 0 && ds_is_ready()) {
        _isKernelReady = YES;
        NSLog(@"[LaraMemoryReader] DarkSword Kernel Exploit initialized successfully.");
        return YES;
    }
    
    NSLog(@"[LaraMemoryReader] Failed to initialize DarkSword Kernel Exploit. Status: %d", status);
    _isKernelReady = NO;
    return NO;
}

- (BOOL)attachToProcessNamed:(NSString *)processName {
    if (!_isKernelReady && ![self initializeKernelExploit]) {
        NSLog(@"[LaraMemoryReader] Cannot attach: Kernel R/W not available.");
        return NO;
    }
    
    uint64_t our_proc = ds_get_our_proc();
    if (!our_proc) {
        NSLog(@"[LaraMemoryReader] Failed to get our_proc kernel address.");
        return NO;
    }
    
    // Traverse kernel proc linked list to find target process
    uint64_t curr_proc = our_proc;
    const char *target_name = [processName UTF8String];
    BOOL found = NO;
    
    for (int iter = 0; iter < 1000 && curr_proc != 0; iter++) {
        char comm[64] = {0};
        ds_kreadbuf(curr_proc + OFF_PROC_NAME, comm, sizeof(comm) - 1);
        pid_t pid = (pid_t)ds_kread32(curr_proc + OFF_PROC_PID);
        
        if (strstr(comm, target_name) != NULL || [processName isEqualToString:[NSString stringWithUTF8String:comm]]) {
            _targetPID = pid;
            _targetProcAddress = curr_proc;
            _targetTaskAddress = ds_kread64(curr_proc + OFF_PROC_TASK);
            if (_targetTaskAddress != 0) {
                _targetMapAddress = ds_kread64(_targetTaskAddress + OFF_TASK_MAP);
            }
            found = YES;
            NSLog(@"[LaraMemoryReader] Attached to process '%s' (PID: %d, proc: 0x%llx, task: 0x%llx)",
                  comm, pid, _targetProcAddress, _targetTaskAddress);
            
            // Enable JIT and Patch Code Signing Flags
            [self enableJITAndPatchCSFlagsForProcess:_targetProcAddress];
            break;
        }
        
        curr_proc = ds_kread64(curr_proc + OFF_PROC_LIST_NEXT);
    }
    
    if (!found) {
        NSLog(@"[LaraMemoryReader] Process '%@' not found in kernel proc list.", processName);
        return NO;
    }
    
    _mainModuleBase = [self findMainModuleBase];
    return YES;
}

- (BOOL)enableJITAndPatchCSFlagsForProcess:(uint64_t)procAddress {
    if (!procAddress || !_isKernelReady) return NO;
    
    // Offset for p_csflags in proc_t on iOS 17-18
    uint64_t csflags_offset = 0x300;
    uint32_t csflags = ds_kread32(procAddress + csflags_offset);
    
    // Set CS_DEBUGGED, CS_GET_TASK_ALLOW, CS_VALID
    csflags |= (CS_DEBUGGED | CS_GET_TASK_ALLOW | CS_VALID);
    
    // Remove CS_HARD, CS_KILL, CS_RESTRICT
    csflags &= ~(CS_HARD | CS_KILL | CS_RESTRICT);
    
    ds_kwrite32(procAddress + csflags_offset, csflags);
    NSLog(@"[LaraMemoryReader] JIT Enabled & CS_Flags Patched for proc 0x%llx -> New csflags: 0x%x", procAddress, csflags);
    return YES;
}

- (uint64_t)findMainModuleBase {
    uint64_t start_addr = 0x100000000ULL;
    uint64_t end_addr   = 0x200000000ULL;
    uint64_t step       = 0x4000ULL;
    
    for (uint64_t addr = start_addr; addr < end_addr; addr += step) {
        uint32_t magic = [self readUInt32:addr];
        if (magic == MH_MAGIC_64) {
            NSLog(@"[LaraMemoryReader] Found target Mach-O Header at 0x%llx", addr);
            return addr;
        }
    }
    
    return 0x100000000ULL;
}

- (BOOL)readMemoryAtAddress:(uint64_t)address buffer:(void *)buffer size:(size_t)size {
    if (!buffer || size == 0 || address == 0 || !_isKernelReady) return NO;
    ds_kreadbuf(address, buffer, (uint64_t)size);
    return YES;
}

- (uint8_t)readUInt8:(uint64_t)address {
    uint8_t val = 0;
    [self readMemoryAtAddress:address buffer:&val size:sizeof(val)];
    return val;
}

- (uint16_t)readUInt16:(uint64_t)address {
    uint16_t val = 0;
    [self readMemoryAtAddress:address buffer:&val size:sizeof(val)];
    return val;
}

- (uint32_t)readUInt32:(uint64_t)address {
    uint32_t val = 0;
    [self readMemoryAtAddress:address buffer:&val size:sizeof(val)];
    return val;
}

- (uint64_t)readUInt64:(uint64_t)address {
    uint64_t val = 0;
    [self readMemoryAtAddress:address buffer:&val size:sizeof(val)];
    return val;
}

- (float)readFloat:(uint64_t)address {
    float val = 0.0f;
    [self readMemoryAtAddress:address buffer:&val size:sizeof(val)];
    return val;
}

- (BOOL)writeMemoryAtAddress:(uint64_t)address buffer:(const void *)buffer size:(size_t)size {
    if (!buffer || size == 0 || address == 0 || !_isKernelReady) return NO;
    ds_kwritebuf(address, buffer, (uint64_t)size);
    return YES;
}

@end
