#import "HHFreeFireReader.h"
#import "HHFFProfile.h"
#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "vm.h"
#import <mach/mach.h>
#include <errno.h>
#include <signal.h>
#include <string.h>

enum { HHGamePageLimit = 96, HHGameMapEntryLimit = 4096 };

typedef struct {
    uint64_t address, local, entryAddress;
    uint64_t start, end, object, offset, usedAt;
} HHGamePage;

typedef struct {
    uint64_t map;
    uint64_t frame;
    HHGamePage pages[HHGamePageLimit];
} HHGameMemory;

static void HHReleaseGamePage(HHGamePage *page) {
    if (page->local) vm_deallocate(mach_task_self(), (vm_address_t)page->local, PAGE_SIZE);
    *page = (HHGamePage){0};
}

static void HHReleaseGamePages(HHGameMemory *memory) {
    for (size_t i = 0; i < HHGamePageLimit; ++i) HHReleaseGamePage(&memory->pages[i]);
}

static BOOL HHReadableEntry(const struct vmmapentry *entry, uint64_t address) {
    return entry->links.start <= address && address < entry->links.end &&
        !entry->is_sub_map && !entry->vme_kernel_object && entry->vme_object_or_delta &&
        (entry->protection & VM_PROT_READ);
}

static uint64_t HHMapGamePage(HHGameMemory *memory, uint64_t address) {
    HHGamePage *slot = NULL;
    for (size_t i = 0; i < HHGamePageLimit; ++i) {
        HHGamePage *page = &memory->pages[i];
        if (page->local && page->address == address) {
            if (page->usedAt == memory->frame) return page->local;
            struct vmmapentry entry = {0};
            ds_kreadbuf(page->entryAddress, &entry, sizeof(entry));
            if (HHReadableEntry(&entry, address) && entry.links.start == page->start &&
                entry.links.end == page->end && entry.vme_object_value == page->object &&
                entry.vme_offset == page->offset) {
                uint64_t previous = ds_kreadptr(page->entryAddress);
                uint64_t nextOffset = previous == vmmapgetheader(memory->map) ?
                    off_vm_map_header_links_next : off_vm_map_entry_links_next;
                if (previous && ds_kreadptr(previous + nextOffset) == page->entryAddress) {
                    page->usedAt = memory->frame;
                    return page->local;
                }
            }
            HHReleaseGamePage(page);
            slot = page;
            break;
        }
        if (!slot || page->usedAt < slot->usedAt) slot = page;
    }
    if (!slot || slot->usedAt == memory->frame) return 0;

    uint64_t entryAddress = vmmapfindentry(memory->map, address);
    if (!entryAddress) return 0;
    struct vmmapentry entry = {0};
    ds_kreadbuf(entryAddress, &entry, sizeof(entry));
    if (!HHReadableEntry(&entry, address)) return 0;

    struct vmshmem page = vmmapremotepage(memory->map, address);
    if (page.port) mach_port_deallocate(mach_task_self(), (mach_port_t)page.port);
    if (!page.localAddress) return 0;
    HHReleaseGamePage(slot);
    *slot = (HHGamePage){address, page.localAddress, entryAddress, entry.links.start,
                         entry.links.end, entry.vme_object_value, entry.vme_offset, memory->frame};
    return page.localAddress;
}

// Revalidate a cached page's mapping on first use in each snapshot.
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

static BOOL HHProbePointer(HHGameMemory *memory,uint64_t address,uint64_t *value) {
    *value=0;
    return HHGameRead(memory,address,value,sizeof(*value))&&
        *value>0x10000&&*value<0x80000000000ULL&&(*value&7)==0;
}

static NSString *HHProbeAimCapability(HHGameMemory *memory,uint64_t base,pid_t pid) {
    mach_port_t task=MACH_PORT_NULL;
    kern_return_t taskResult=task_for_pid(mach_task_self(),pid,&task);
    if(taskResult==KERN_SUCCESS&&task!=MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(),task);
    uint64_t type=0,statics=0,game=0,match=0,local=0;
    BOOL context=HHProbePointer(memory,base+0xbb46a50,&type)&&
        HHProbePointer(memory,type+0xb8,&statics)&&
        (HHProbePointer(memory,statics+8,&game)||HHProbePointer(memory,statics,&game))&&
        HHProbePointer(memory,game+0x90,&match)&&HHProbePointer(memory,match+0xd8,&local);
    int rotationRead=0,rotationWrite=0,slotRead=0,slotWrite=0,slotOriginal=0;
    if(context){
        uint64_t entryAddress=vmmapfindentry(memory->map,local+0x614);
        struct vmmapentry entry={0};
        if(entryAddress){
            ds_kreadbuf(entryAddress,&entry,sizeof(entry));
            rotationRead=(entry.protection&VM_PROT_READ)!=0;
            rotationWrite=(entry.protection&VM_PROT_WRITE)!=0;
        }
        uint64_t manager=0,owner=0,weapon=0,handler=0,klass=0,current=0;
        uint8_t combined=0;
        if(HHProbePointer(memory,local+0x740,&manager)&&
           HHGameRead(memory,manager+0x30,&owner,sizeof(owner))&&owner==local&&
           HHGameRead(memory,manager+0x148,&combined,sizeof(combined))&&combined<=1&&
           HHProbePointer(memory,manager+(combined?0xa8:0xa0),&weapon)&&
           HHGameRead(memory,weapon+0x60,&owner,sizeof(owner))&&owner==local&&
           HHProbePointer(memory,weapon+0x80,&handler)&&
           HHProbePointer(memory,handler,&klass)){
            const uint64_t slot=klass+0x138+17*16;
            entryAddress=vmmapfindentry(memory->map,slot);
            if(entryAddress){
                ds_kreadbuf(entryAddress,&entry,sizeof(entry));
                slotRead=(entry.protection&VM_PROT_READ)!=0;
                slotWrite=(entry.protection&VM_PROT_WRITE)!=0;
            }
            if(HHGameRead(memory,slot,&current,sizeof(current)))
                slotOriginal=current==base+0x5c59b94;
        }
    }
    return [NSString stringWithFormat:
        @"Aim capability: gameContext=%d taskForPID=%d taskPort=%d rotationRW=%d/%d shotSlotRW=%d/%d shotSlotOriginal=%d",
        context,(int)taskResult,taskResult==KERN_SUCCESS&&task!=MACH_PORT_NULL,rotationRead,rotationWrite,
        slotRead,slotWrite,slotOriginal];
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

@interface HHFreeFireReader () {
    HHGameMemory _memory;
}
@property(nonatomic,copy,readwrite) NSString *status;
@property(nonatomic) uint64_t base;
@property(nonatomic) pid_t pid;
@property(nonatomic) CFAbsoluteTime retryAt;
@property(nonatomic) BOOL recovering;
@property(nonatomic,copy) NSString *aimCapabilityReport;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *, NSNumber *> *numbers;
@end

@implementation HHFreeFireReader
- (instancetype)init {
    if ((self = [super init])) {
        _status = @"Đang chờ FF TH";
        _numbers = [NSMutableDictionary new];
    }
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
        HHReleaseGamePages(&_memory);
        _memory.map = 0;
        [self.numbers removeAllObjects];
        self.base = 0;
        self.status = @"Chưa khớp phiên FF TH đang mở";
        return NO;
    }

    uint64_t task = proc_task(process);
    uint64_t map = task ? task_get_vm_map(task) : 0;
    if (map != _memory.map) {
        HHReleaseGamePages(&_memory);
        _memory.map = map;
        [self.numbers removeAllObjects];
        self.base = 0;
    }
    if (!map) {
        self.status = @"Chưa đọc được bộ nhớ FF TH";
        return NO;
    }
    if (!self.base) {
        ++_memory.frame;
        self.base = HHUnityImage(&_memory);
        self.status = self.base ? @"Đã nhận FF TH 1.132.1" : @"Chưa tìm thấy Unity 1.132.1";
        if(self.base)self.aimCapabilityReport=HHProbeAimCapability(&_memory,self.base,pid);
    }
    return self.base != 0;
}

- (NSString *)takeAimCapabilityReport {
    NSString *report=self.aimCapabilityReport;
    self.aimCapabilityReport=nil;
    return report;
}

- (NSArray<NSValue *> *)boxesForSize:(CGSize)size {
    if (!_memory.map || !self.base || (kill(self.pid, 0) != 0 && errno == ESRCH)) return @[];
    ++_memory.frame;
    HHFFBox boxes[32];
    size_t count = 0;
    BOOL sampled = hh_ff_snapshot(HHGameRead, &_memory, self.base, size.width, size.height, boxes, &count);
    if (!sampled) {
        if (!self.recovering) HHReleaseGamePages(&_memory);
        self.recovering = YES;
        self.status = @"Đang chờ trận / dữ liệu hợp lệ";
        return nil;
    }
    self.recovering = NO;

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i) {
        NSNumber *key=@(boxes[i].id), *number=self.numbers[key];
        if(!number&&self.numbers.count<1024){
            number=@(self.numbers.count+1);
            self.numbers[key]=number;
        }
        boxes[i].number=number.unsignedShortValue;
        [result addObject:[NSValue valueWithBytes:&boxes[i] objCType:@encode(HHFFBox)]];
    }
    self.status = [NSString stringWithFormat:@"ESP Box · %lu đối tượng", (unsigned long)count];
    return result;
}

- (void)disconnect {
    HHReleaseGamePages(&_memory);
    _memory.map = 0;
    self.base = 0;
    self.pid = 0;
    self.retryAt = 0;
    self.recovering = NO;
    self.aimCapabilityReport=nil;
    [self.numbers removeAllObjects];
    self.status = @"Đang chờ FF TH";
}

- (void)dealloc {
    HHReleaseGamePages(&_memory);
}
@end
