#import "HHFreeFireReader.h"
#import "HHFFProfile.h"
#import "HHSilentAim.h"
#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "vm.h"
#import <mach/mach.h>
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <math.h>

enum { HHGamePageLimit = 96, HHGameMapEntryLimit = 4096 };

typedef struct {
    uint64_t address, local, entryAddress;
    uint64_t start, end, object, offset, usedAt;
    CFAbsoluteTime checkedAt;
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
            // The map is already bound to this PID. Bound the costly kernel entry
            // walk while retaining a short freshness window for remaps.
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            if (now - page->checkedAt < 0.10) {
                page->usedAt = memory->frame;
                return page->local;
            }
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
                    page->checkedAt = now;
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
                         entry.links.end, entry.vme_object_value, entry.vme_offset,
                         memory->frame, CFAbsoluteTimeGetCurrent()};
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

static BOOL HHGameCanWrite(HHGameMemory *memory,uint64_t address,size_t size) {
    if(!memory->map||address<0x10000||!size||size>PAGE_SIZE||
       (address&PAGE_MASK)+size>PAGE_SIZE)return NO;
    uint64_t entryAddress=vmmapfindentry(memory->map,address);
    struct vmmapentry entry={0};
    if(!entryAddress)return NO;
    ds_kreadbuf(entryAddress,&entry,sizeof(entry));
    return HHReadableEntry(&entry,address)&&(entry.protection&VM_PROT_WRITE)&&
        address<=entry.links.end&&size<=entry.links.end-address;
}

static BOOL HHGameWrite(HHGameMemory *memory,uint64_t address,const void *data,size_t size) {
    if(!data||!HHGameCanWrite(memory,address,size))return NO;
    uint64_t pageAddress=address&~(uint64_t)PAGE_MASK;
    for(size_t i=0;i<HHGamePageLimit;i++)if(memory->pages[i].local&&
       memory->pages[i].address==pageAddress){
        memory->pages[i].checkedAt=0;
        memory->pages[i].usedAt=0;
    }
    uint64_t mapped=HHMapGamePage(memory,pageAddress);
    if(!mapped)return NO;
    memcpy((void *)(uintptr_t)(mapped+(address&PAGE_MASK)),data,size);
    return YES;
}

static BOOL HHProbePointer(HHGameMemory *memory,uint64_t address,uint64_t *value) {
    *value=0;
    return HHGameRead(memory,address,value,sizeof(*value))&&
        *value>0x10000&&*value<0x80000000000ULL&&(*value&7)==0;
}

static BOOL HHVisibleEnemy(HHGameMemory *memory,uint64_t player) {
    uint64_t manager=0,avatar=0,klass=0,name=0,space=0;
    uint8_t visible=0;
    char className[16]={0},namespaceName[11]={0};
    return HHProbePointer(memory,player+0x770,&manager)&&
        HHProbePointer(memory,manager+0x138,&avatar)&&
        HHProbePointer(memory,avatar,&klass)&&
        HHGameRead(memory,klass+0x10,&name,sizeof(name))&&name>0x10000&&name<0x80000000000ULL&&
        HHGameRead(memory,klass+0x18,&space,sizeof(space))&&space>0x10000&&space<0x80000000000ULL&&
        HHGameRead(memory,name,className,sizeof(className))&&
        HHGameRead(memory,space,namespaceName,sizeof(namespaceName))&&
        strcmp(className,"UmaAvatarSimple")==0&&strcmp(namespaceName,"UMA.Simple")==0&&
        HHGameRead(memory,avatar+0x101,&visible,sizeof(visible))&&visible==1;
}

static BOOL HHFiring(HHGameMemory *memory,uint64_t local) {
    uint64_t pool=0,entries=0,pri=0;uint16_t raw=0;
    return HHProbePointer(memory,local+0x70,&pool)&&
        HHProbePointer(memory,pool+0x10,&entries)&&
        HHProbePointer(memory,entries+0xc8,&pri)&&
        HHGameRead(memory,pri+0x18,&raw,sizeof(raw))&&raw==2;
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
@property(nonatomic,copy) NSString *lastAimCapability;
@property(nonatomic) CFAbsoluteTime aimProbeAt;
@property(nonatomic) CFAbsoluteTime nextSilentAt;
@property(nonatomic,copy) NSString *silentReport;
@property(nonatomic,copy) NSString *lastSilentReport;
@property(nonatomic,copy) NSString *neckReport;
@property(nonatomic,copy) NSString *lastNeckReport;
@property(nonatomic,strong) NSMutableDictionary<NSNumber *, NSNumber *> *numbers;
@end

@implementation HHFreeFireReader
@synthesize silentEnabled=_silentEnabled;
@synthesize neckEnabled=_neckEnabled;
- (instancetype)init {
    if ((self = [super init])) {
        _status = @"Đang chờ FF TH";
        _fovPercent = 18;
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
        hh_silent_stop();
        hh_ff_reset_cache();
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
    }
    return self.base != 0;
}

- (NSString *)takeAimCapabilityReport {
    NSString *report=self.aimCapabilityReport;
    self.aimCapabilityReport=nil;
    return report;
}

- (NSString *)takeSilentReport {
    NSString *report=self.silentReport;
    self.silentReport=nil;
    return report;
}

- (NSString *)takeNeckReport {
    NSString *report=self.neckReport;
    self.neckReport=nil;
    return report;
}

- (void)setSilentEnabled:(BOOL)enabled {
    if (_silentEnabled == enabled) return;
    _silentEnabled=enabled;
    self.nextSilentAt=0;
    if (!enabled) hh_silent_stop();
}

- (NSArray<NSValue *> *)boxesForSize:(CGSize)size {
    if (!_memory.map || !self.base || (kill(self.pid, 0) != 0 && errno == ESRCH)) return @[];
    ++_memory.frame;
    HHFFBox boxes[32];
    size_t count = 0;
    int stage = 0;
    uint64_t match=0,local=0;float origin[3]={0};
    BOOL sampled = hh_ff_snapshot_stage(HHGameRead, &_memory, self.base, size.width, size.height, boxes, &count, &stage,&match,&local,origin,self.silentEnabled||self.neckEnabled);
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if(now>=self.aimProbeAt){
        self.aimProbeAt=now+5;
        NSString *report=HHProbeAimCapability(&_memory,self.base,self.pid);
        if(![report isEqualToString:self.lastAimCapability]){
            self.lastAimCapability=report;
            self.aimCapabilityReport=report;
        }
    }
    if (!sampled) {
        if(self.silentEnabled)hh_silent_clear();
        if (!self.recovering) HHReleaseGamePages(&_memory);
        self.recovering = YES;
        NSArray<NSString *> *stages=@[@"kích thước màn hình", @"phiên trận", @"nhân vật/camera", @"danh sách người chơi", @"dữ liệu trận thay đổi", @"ma trận camera"];
        NSString *reason=stage>=0 && stage<(int)stages.count?stages[(NSUInteger)stage]:@"dữ liệu chưa hợp lệ";
        self.status=[@"ESP đang chờ: " stringByAppendingString:reason];
        return nil;
    }
    self.recovering = NO;
    HHFFBox *chosen=NULL;
    if(self.silentEnabled||self.neckEnabled){
        float percent=isfinite(self.fovPercent)?fminf(48.f,fmaxf(5.f,self.fovPercent)):18.f;
        float best=INFINITY, radius=MIN(size.width,size.height)*percent/100.f;
        for(size_t i=0;i<count;i++){
            HHFFBox *box=&boxes[i];
            if(!isfinite(box->headX)||!isfinite(box->headY)||
               box->headX<0||box->headX>size.width||box->headY<0||box->headY>size.height||
               !isfinite(box->head[0])||!isfinite(box->head[1])||!isfinite(box->head[2])||
               !isfinite(box->hip[0])||!isfinite(box->hip[1])||!isfinite(box->hip[2])||
               (fabsf(box->hip[0])+fabsf(box->hip[1])+fabsf(box->hip[2])<0.01f)||
               !HHVisibleEnemy(&_memory,box->id))continue;
            float dx=box->headX-size.width*0.5f,dy=box->headY-size.height*0.5f;
            float distance=dx*dx+dy*dy;
            if(distance<radius*radius&&distance<best){best=distance;chosen=box;}
        }
    }
    if(self.silentEnabled&&now>=self.nextSilentAt){
        int state=hh_silent_update(self.pid,self.base,match,local,chosen?chosen->id:0,
                                   chosen?chosen->head:NULL,chosen?chosen->hip:NULL);
        NSString *report=[NSString stringWithFormat:@"Silent aim: state=%d target=%d detail=%s",
                          state,chosen!=NULL,hh_silent_failure()];
        if(![report isEqualToString:self.lastSilentReport]){
            self.lastSilentReport=report;self.silentReport=report;
        }
        if(state==9||state==10)self.nextSilentAt=now+2;
    }
    if(self.neckEnabled){
        NSString *state=@"đợi mục tiêu trong FOV";
        uint64_t currentLocal=0;
        if(chosen&&HHFiring(&_memory,local)&&
           HHProbePointer(&_memory,match+0xd8,&currentLocal)&&currentLocal==local&&
           fabsf(origin[0])+fabsf(origin[1])+fabsf(origin[2])>0.01f){
            uint8_t knocked=1;
            float rotation[4]={0};
            if(HHGameRead(&_memory,local+0x1258,&knocked,sizeof(knocked))&&!knocked&&
               hh_ff_neck_rotation(origin,chosen->head,chosen->hip,rotation)&&
               HHGameCanWrite(&_memory,local+0x614,sizeof(rotation))&&
               HHGameCanWrite(&_memory,local+0x628,sizeof(rotation))){
                BOOL first=HHGameWrite(&_memory,local+0x614,rotation,sizeof(rotation));
                BOOL second=first&&HHGameWrite(&_memory,local+0x628,rotation,sizeof(rotation));
                state=second?@"đã ghi góc quay":@"ghi góc quay thất bại";
            }else state=@"dữ liệu/góc quay chưa đủ điều kiện";
        }else if(chosen)state=@"đợi bắn hoặc camera hợp lệ";
        NSString *report=[@"Aim cổ: " stringByAppendingString:state];
        if(![report isEqualToString:self.lastNeckReport]){
            self.lastNeckReport=report;self.neckReport=report;
        }
    }

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
    hh_silent_stop();
    hh_ff_reset_cache();
    _silentEnabled=NO;
    self.nextSilentAt=0;
    self.silentReport=nil;
    self.lastSilentReport=nil;
    _neckEnabled=NO;
    self.neckReport=nil;
    self.lastNeckReport=nil;
    HHReleaseGamePages(&_memory);
    _memory.map = 0;
    self.base = 0;
    self.pid = 0;
    self.retryAt = 0;
    self.recovering = NO;
    self.aimCapabilityReport=nil;
    self.lastAimCapability=nil;
    self.aimProbeAt=0;
    [self.numbers removeAllObjects];
    self.status = @"Đang chờ FF TH";
}

- (void)dealloc {
    hh_silent_stop();
    HHReleaseGamePages(&_memory);
}
@end
