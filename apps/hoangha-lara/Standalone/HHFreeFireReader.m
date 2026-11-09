#import "HHFreeFireReader.h"
#import "HHFFProfile.h"
#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "vm.h"
#include <errno.h>
#include <signal.h>
#include <string.h>

enum { HHGamePageLimit = 96, HHGameMapEntryLimit = 4096 };

typedef struct {
    uint64_t map;
    size_t count;
    struct vmshmem pages[HHGamePageLimit];
} HHGameMemory;

static void HHReleaseGamePages(HHGameMemory *memory) {
    for (size_t i = 0; i < memory->count; ++i) {
        vm_deallocate(mach_task_self(), (vm_address_t)memory->pages[i].localAddress, PAGE_SIZE);
    }
    memory->count = 0;
}

static uint64_t HHMapGamePage(HHGameMemory *memory, uint64_t address) {
    for (size_t i = 0; i < memory->count; ++i) {
        if (memory->pages[i].remoteAddress == address) return memory->pages[i].localAddress;
    }
    if (memory->count == HHGamePageLimit) return 0;

    uint64_t entryAddress = vmmapfindentry(memory->map, address);
    if (!entryAddress) return 0;
    struct vmmapentry entry = {0};
    ds_kreadbuf(entryAddress, &entry, sizeof(entry));
    if (entry.is_sub_map || entry.vme_kernel_object || !entry.vme_object_or_delta ||
        !(entry.protection & VM_PROT_READ)) return 0;

    struct vmshmem page = vmmapremotepage(memory->map, address);
    if (page.port) mach_port_deallocate(mach_task_self(), (mach_port_t)page.port);
    if (!page.localAddress) return 0;
    memory->pages[memory->count++] = page;
    return page.localAddress;
}

// Cache aliases for one snapshot so a later frame cannot read stale pages.
static bool HHGameRead(void *context, uint64_t address, void *buffer, size_t size) {
    HHGameMemory *memory = context;
    if (address < 0x10000 || size > UINT64_MAX - address || !buffer || !size) return false;
    uint8_t *output = buffer;
    while (size) {
        uint64_t offset = address & PAGE_MASK;
        size_t count = MIN(size, PAGE_SIZE - offset);
        uint64_t local = HHMapGamePage(memory, address - offset);
        if (!local) return false;
        memcpy(output, (const void *)(uintptr_t)(local + offset), count);
        address += count;
        output += count;
        size -= count;
    }
    return true;
}

static uint64_t HHUnityImage(HHGameMemory *memory) {
    __block uint64_t base = 0;
    __block unsigned visited = 0;
    vmmapiterateentries(memory->map, ^(uint64_t start, uint64_t end, uint64_t address, BOOL *stop) {
        if (++visited >= HHGameMapEntryLimit) { *stop = YES; return; }
        // UnityFramework 1.132.1 has a large file-backed __TEXT mapping.
        if (start < 0x100000000ULL || end <= start || end - start < 8 * 1024 * 1024) return;
        struct vmmapentry entry = {0};
        ds_kreadbuf(address, &entry, sizeof(entry));
        if (entry.is_sub_map || entry.vme_kernel_object || !entry.vme_object_or_delta ||
            entry.vme_offset || !(entry.protection & VM_PROT_EXECUTE)) return;
        if (hh_ff_supports(HHGameRead, memory, start)) { base = start; *stop = YES; }
        HHReleaseGamePages(memory);
    });
    return base;
}

@interface HHFreeFireReader ()
@property(nonatomic,copy,readwrite) NSString *status;
@property(nonatomic) uint64_t base, map;
@property(nonatomic) pid_t pid;
@property(nonatomic) CFAbsoluteTime retryAt;
@end

@implementation HHFreeFireReader
- (instancetype)init {
    if ((self = [super init])) _status = @"Đang chờ FF TH";
    return self;
}

- (BOOL)connectIfNeededForPID:(pid_t)pid {
    if (pid <= 0 || !ds_is_ready()) return NO;
    if (self.pid != pid) {
        [self disconnect];
        self.pid = pid;
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now < self.retryAt) return self.base != 0;
    self.retryAt = now + 2;
    uint64_t process = proc_find_by_name("FreeFire");
    if (!process || (pid_t)ds_kread32(process + off_proc_p_pid) != pid) {
        self.map = 0;
        self.base = 0;
        self.status = @"Chưa khớp phiên FF TH đang mở";
        return NO;
    }

    uint64_t task = proc_task(process);
    uint64_t map = task ? task_get_vm_map(task) : 0;
    if (map != self.map) self.base = 0;
    self.map = map;
    if (!map) {
        self.status = @"Chưa đọc được bộ nhớ FF TH";
        return NO;
    }
    if (!self.base) {
        HHGameMemory memory = {.map = map};
        self.base = HHUnityImage(&memory);
        self.status = self.base ? @"Đã nhận FF TH 1.132.1" : @"Chưa tìm thấy Unity 1.132.1";
    }
    return self.base != 0;
}

- (NSArray<NSValue *> *)boxesForSize:(CGSize)size {
    if (!self.map || !self.base || (kill(self.pid, 0) != 0 && errno == ESRCH)) return @[];
    HHGameMemory memory = {.map = self.map};
    HHFFBox boxes[32];
    size_t count = 0;
    BOOL sampled = hh_ff_snapshot(HHGameRead, &memory, self.base, size.width, size.height, boxes, &count);
    HHReleaseGamePages(&memory);
    if (!sampled) {
        self.status = @"Đang chờ trận / dữ liệu hợp lệ";
        return @[];
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i) {
        [result addObject:[NSValue valueWithCGRect:CGRectMake(boxes[i].x, boxes[i].y, boxes[i].w, boxes[i].h)]];
    }
    self.status = [NSString stringWithFormat:@"ESP Box · %lu đối tượng", (unsigned long)count];
    return result;
}

- (void)disconnect {
    self.map = 0;
    self.base = 0;
    self.pid = 0;
    self.retryAt = 0;
    self.status = @"Đang chờ FF TH";
}
@end
