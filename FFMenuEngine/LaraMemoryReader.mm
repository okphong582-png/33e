#import "LaraMemoryReader.h"
#import <UIKit/UIKit.h>
#import <mach/mach_vm.h>
#import <mach-o/loader.h>
extern "C" {
#include "../lara/kexploit/darksword.h"
}
#include "../lara/kexploit/utils.h"
#include "../lara/kexploit/offsets.h"
#include "../lara/kexploit/TaskRop/vm.h"
#include <algorithm>
#include <vector>
#include <cstring>

@interface LaraMemoryReader ()
@property (nonatomic, assign, readwrite) pid_t targetPID;
@property (nonatomic, assign, readwrite) uint64_t targetProcAddress;
@property (nonatomic, assign, readwrite) uint64_t targetTaskAddress;
@property (nonatomic, assign, readwrite) uint64_t targetMapAddress;
@property (nonatomic, assign, readwrite) uint64_t mainModuleBase;
@property (nonatomic, copy, readwrite) NSString *lastError;
- (uint64_t)findMainModuleBase;
- (BOOL)hasLiveTarget;
@end

@implementation LaraMemoryReader
+ (instancetype)sharedInstance {
    static LaraMemoryReader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}
- (instancetype)init {
    if ((self = [super init])) _lastError = @"";
    return self;
}
- (BOOL)isKernelReady { return ds_is_ready(); }
- (BOOL)initializeKernelExploit {
    // Use Lara's existing initialization flow, including offsets and progress.
    // The menu must not start a second exploit run independently.
    if (ds_is_ready()) return YES;
    _lastError = @"Run DarkSword and initialize kernel offsets in Lara first.";
    return NO;
}
- (void)detach {
    _targetPID = 0;
    _targetProcAddress = 0;
    _targetTaskAddress = 0;
    _targetMapAddress = 0;
    _mainModuleBase = 0;
}
- (BOOL)hasLiveTarget {
    if (!ds_is_ready() || !_targetPID || !_targetProcAddress || !_targetTaskAddress || !_targetMapAddress) return NO;
    // Resolve from the live list before dereferencing a potentially freed proc.
    uint64_t proc = procbypid(_targetPID);
    return proc == _targetProcAddress && proc_task(proc) == _targetTaskAddress &&
           task_get_vm_map(_targetTaskAddress) == _targetMapAddress;
}
- (BOOL)isAttached {
    if (_mainModuleBase && [self hasLiveTarget]) return YES;
    if (_targetProcAddress) {
        [self detach];
        _lastError = @"Target exited or vm_map changed. Attach again.";
    }
    return NO;
}
- (BOOL)attachToProcessNamed:(NSString *)name {
    [self detach];
    _lastError = @"";
    if (![self initializeKernelExploit]) return NO;
    if (!off_proc_p_pid || !off_proc_p_proc_ro || !off_proc_ro_pr_task ||
        !off_task_map || !off_vm_map_hdr || !off_vm_map_header_nentries ||
        !off_vm_map_header_links_next || !off_vm_object_ref_count ||
        !off_vm_named_entry_backing_copy || !VM_MIN_KERNEL_ADDRESS) {
        _lastError = @"Kernel VM offsets are not ready. Initialize offsets in Lara first.";
        return NO;
    }
    if (!name.length) { _lastError = @"Process name is empty."; return NO; }
    uint64_t proc = proc_find_by_name(name.UTF8String);
    if (!proc) {
        _lastError = [NSString stringWithFormat:@"%@ is not running.", name];
        return NO;
    }
    uint64_t task = proc_task(proc);
    uint64_t map = task ? task_get_vm_map(task) : 0;
    pid_t pid = (pid_t)ds_kread32(proc + off_proc_p_pid);
    if (!ds_isvalid(proc) || !ds_isvalid(task) || !ds_isvalid(map) || pid <= 0) {
        _lastError = @"Cannot resolve target proc/task/vm_map.";
        return NO;
    }
    _targetPID = pid;
    _targetProcAddress = proc;
    _targetTaskAddress = task;
    _targetMapAddress = map;
    _mainModuleBase = [self findMainModuleBase];
    if (!_mainModuleBase || ![self hasLiveTarget]) {
        [self detach];
        _lastError = @"Cannot resolve target module. Retry after the game loads.";
        return NO;
    }
    _lastError = @"";
    return YES;
}

- (BOOL)transferAtAddress:(uint64_t)address buffer:(void *)buffer size:(size_t)size writing:(BOOL)writing {
    if (!buffer || !size || !address || size > UINT64_MAX - address || ![self hasLiveTarget]) return NO;
    const uint64_t pageSize = (uint64_t)vm_page_size;
    if (!pageSize || (pageSize & (pageSize - 1))) return NO;
    size_t offset = 0;
    while (offset < size) {
        uint64_t current = address + offset;
        uint64_t page = current & ~(pageSize - 1);
        size_t within = (size_t)(current - page);
        size_t amount = std::min(size - offset, (size_t)pageSize - within);
        // Existing DarkSword VM backend maps this target's user page locally.
        // A user virtual address must never be passed directly to ds_kreadbuf.
        struct vmshmem shared = vmmapremotepage(_targetMapAddress, page);
        if (!shared.used || !shared.localAddress) {
            if (shared.localAddress) mach_vm_deallocate(mach_task_self(), shared.localAddress, pageSize);
            if (shared.port) mach_port_deallocate(mach_task_self(), (mach_port_t)shared.port);
            _lastError = [NSString stringWithFormat:@"Cannot map target page 0x%llx", (unsigned long long)page];
            return NO;
        }
        uint64_t local = shared.localAddress + within;
        kern_return_t kr;
        mach_vm_size_t actual = 0;
        if (writing) {
            kr = mach_vm_write(mach_task_self(), local, (vm_offset_t)((char *)buffer + offset),
                               (mach_msg_type_number_t)amount);
        } else {
            kr = mach_vm_read_overwrite(mach_task_self(), local, amount,
                                        (mach_vm_address_t)((char *)buffer + offset), &actual);
        }
        mach_vm_deallocate(mach_task_self(), shared.localAddress, pageSize);
        if (shared.port) mach_port_deallocate(mach_task_self(), (mach_port_t)shared.port);
        if (kr != KERN_SUCCESS || (!writing && actual != amount)) {
            _lastError = [NSString stringWithFormat:@"Target page transfer failed: %s", mach_error_string(kr)];
            return NO;
        }
        offset += amount;
    }
    if ([self hasLiveTarget]) return YES;
    _lastError = @"Target changed during memory transfer. Attach again.";
    return NO;
}
- (BOOL)readMemoryAtAddress:(uint64_t)address buffer:(void *)buffer size:(size_t)size {
    if (!buffer || !size) return NO;
    BOOL success = [self transferAtAddress:address buffer:buffer size:size writing:NO];
    if (!success) memset(buffer, 0, size);
    return success;
}
- (BOOL)writeMemoryAtAddress:(uint64_t)address buffer:(const void *)buffer size:(size_t)size {
    return [self transferAtAddress:address buffer:(void *)buffer size:size writing:YES];
}

- (uint64_t)findMainModuleBase {
    __block uint64_t unity = 0, executable = 0;
    // Inspect actual mapped Mach-O headers, avoiding a blind 4 GB scan or fake base.
    vmmapiterateentries(_targetMapAddress, ^(uint64_t start, uint64_t end, uint64_t entry, BOOL *stop) {
        (void)entry;
        if (end <= start || end - start < sizeof(mach_header_64)) return;
        mach_header_64 header = {};
        if (![self readMemoryAtAddress:start buffer:&header size:sizeof(header)] ||
            header.magic != MH_MAGIC_64 || header.sizeofcmds > 1024 * 1024 ||
            header.sizeofcmds > end - start - sizeof(header) ||
            header.ncmds > header.sizeofcmds / sizeof(load_command)) return;
        if (header.filetype == MH_EXECUTE) executable = start;
        if (header.filetype != MH_DYLIB || !header.sizeofcmds) return;
        std::vector<uint8_t> commands(header.sizeofcmds);
        if (![self readMemoryAtAddress:start + sizeof(header) buffer:commands.data() size:commands.size()]) return;
        size_t offset = 0;
        for (uint32_t i = 0; i < header.ncmds; ++i) {
            if (commands.size() - offset < sizeof(load_command)) break;
            load_command command;
            memcpy(&command, commands.data() + offset, sizeof(command));
            if (command.cmdsize < sizeof(command) || command.cmdsize > commands.size() - offset) break;
            if (command.cmd == LC_ID_DYLIB && command.cmdsize >= sizeof(dylib_command)) {
                dylib_command dylib;
                memcpy(&dylib, commands.data() + offset, sizeof(dylib));
                if (dylib.dylib.name.offset >= sizeof(dylib_command) && dylib.dylib.name.offset < command.cmdsize) {
                    const char *path = (const char *)commands.data() + offset + dylib.dylib.name.offset;
                    if (memchr(path, 0, command.cmdsize - dylib.dylib.name.offset)) {
                        NSString *name = [NSString stringWithUTF8String:path];
                        if ([name.lastPathComponent isEqualToString:@"UnityFramework"]) {
                            unity = start;
                            *stop = YES;
                            return;
                        }
                    }
                }
            }
            offset += command.cmdsize;
        }
    });
    return unity ? unity : executable;
}
- (uint8_t)readUInt8:(uint64_t)address {
    uint8_t value = 0; [self readMemoryAtAddress:address buffer:&value size:sizeof(value)]; return value;
}
- (uint16_t)readUInt16:(uint64_t)address {
    uint16_t value = 0; [self readMemoryAtAddress:address buffer:&value size:sizeof(value)]; return value;
}
- (uint32_t)readUInt32:(uint64_t)address {
    uint32_t value = 0; [self readMemoryAtAddress:address buffer:&value size:sizeof(value)]; return value;
}
- (uint64_t)readUInt64:(uint64_t)address {
    uint64_t value = 0; [self readMemoryAtAddress:address buffer:&value size:sizeof(value)]; return value;
}
- (float)readFloat:(uint64_t)address {
    float value = 0; [self readMemoryAtAddress:address buffer:&value size:sizeof(value)]; return value;
}
@end
