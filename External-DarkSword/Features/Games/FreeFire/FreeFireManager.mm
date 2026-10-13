#import "FreeFireManager.h"
#import "../../License/LicenseSession.h"
#import "../../Overlay/RemoteWebViewOverlay.h"
#import "../../Diagnostics/MizzeStartupDiagnostics.h"
#import "../../../App/Support/helper.h"
#include "FreeFireReader.h"
#include <dlfcn.h>
#include <mach/task_info.h>

// Same image-discovery routine already used by AoV; no change to RemoteCall.
static uint64_t FindUnityFramework(RemoteCall *remoteCall) {
    uint64_t task_info_addr = (uint64_t)dlsym(RTLD_DEFAULT, "task_info");
    uint64_t mach_task_self_addr =
        (uint64_t)dlsym(RTLD_DEFAULT, "mach_task_self_");

    if (!task_info_addr || !mach_task_self_addr) {
        return 0;
    }

    uint32_t target_mach_task_self = 0;
    // Get mach_task_self of process need get
    if (![remoteCall remoteRead:mach_task_self_addr
                                  to:&target_mach_task_self
                                size:sizeof(target_mach_task_self)] ||
        target_mach_task_self == MACH_PORT_NULL) {
        return 0;
    }

    uint64_t scratch_addr = [remoteCall trojanMem] + 0x1000;
    uint32_t count = TASK_DYLD_INFO_COUNT;
    if (![remoteCall remote_write:scratch_addr
                                  from:&count
                                  size:sizeof(count)]) {
        return 0;
    }

    /*
    Get info a task (process)
    flavor = 17 (TASK_DYLD_INFO) => Get pointer refer to image dyld table of a
    process

    kern_return_t task_info
                  (task_t task,
                  task_flavor_t flavor,
                  task_info_t task_info,
                  mach_msg_type_number_t task_info_count);
    */
    uint64_t args[4] = {
        target_mach_task_self, // x0
        TASK_DYLD_INFO,        // x1 = 17 => Get info dylib loaded
        scratch_addr + 8,      // x2 = task_info_out
        scratch_addr           // x3 = task_info_outCnt
    };

    uint64_t ret =
        [remoteCall doRemoteCallStableWithTimeout:5
                                          functionName:(char *)"task_info"
                                       functionPointer:(void *)task_info_addr
                                                  args:args
                                              argCount:4];

    if (ret != KERN_SUCCESS) {
        return 0;
    }

    /*
    task_info (type task_info_t) is task_dyld_info

    struct task_dyld_info {
        uint64_t all_image_info_addr;       // +0x0
        uint64_t all_image_info_size;       // +0x8
        uint32_t all_image_info_format;     // +0x10
    }
    */
    uint64_t all_image_info_addr = 0;
    if (![remoteCall remoteRead:(scratch_addr + 8)
                                  to:&all_image_info_addr
                                size:sizeof(all_image_info_addr)] ||
        !validOffsetPtr(all_image_info_addr)) {
        return 0;
    }

    /*
    Read all_image_info_addr + 0x0 => address of dyld_all_image_infos

    struct dyld_all_image_infos {
     uint32_t version;                // +0x00
     uint32_t infoArrayCount;         // +0x04
     uint64_t infoArray;              // +0x08, array of dyld_image_info
     ...
    };

    struct dyld_image_info {
     uint64_t imageLoadAddress;    // +0x00
     uint64_t imageFilePath;       // +0x08
     uint64_t imageFileModDate;    // +0x10
    };

    dyld_image_info => 8 (uint64_t) * 3 = 24 = 0x18 (size of object type
    dyld_image_info)
    */
    uint32_t infoArrayCount = 0;
    uint64_t infoArray = 0;
    BOOL readCount = [remoteCall remoteRead:(all_image_info_addr + 4)
                                              to:&infoArrayCount
                                            size:sizeof(infoArrayCount)];
    BOOL readArray = [remoteCall remoteRead:(all_image_info_addr + 8)
                                              to:&infoArray
                                            size:sizeof(infoArray)];

    static const uint32_t kMaxDyldImageCount = 3000;
    if (!readCount || !readArray || infoArrayCount == 0 ||
        infoArrayCount > kMaxDyldImageCount || !validOffsetPtr(infoArray)) {
        return 0;
    }

    static const uint64_t kDyldImageInfoSize = 0x18;
    for (uint32_t remaining = infoArrayCount; remaining > 0; --remaining) {
        uint32_t i = remaining - 1;
        if ((uint64_t)i > (UINT64_MAX - infoArray) / kDyldImageInfoSize) {
            break;
        }

        uint64_t entry = infoArray + (uint64_t)i * kDyldImageInfoSize;
        if (!validOffsetPtr(entry) || !validOffsetPtr(entry + 8))
            continue;

        uint64_t imageFilePathAddr = 0;
        uint64_t imageLoadAddress = 0;
        BOOL readLoadAddress =
            [remoteCall remoteRead:entry
                                     to:&imageLoadAddress
                                   size:sizeof(imageLoadAddress)];
        BOOL readPathAddress =
            [remoteCall remoteRead:(entry + 8)
                                     to:&imageFilePathAddr
                                   size:sizeof(imageFilePathAddr)];
        if (!readLoadAddress || !readPathAddress ||
            !validOffsetPtr(imageFilePathAddr))
            continue;

        char pathBuf[512] = {0};
        if (![remoteCall remoteRead:imageFilePathAddr
                                      to:pathBuf
                                    size:sizeof(pathBuf) - 1])
            continue;

        if (strstr(pathBuf, "UnityFramework")) {
            return imageLoadAddress;
        }
    }

    return 0;
}


@interface FreeFireManager ()
@property(nonatomic,strong) RemoteCall *remoteCall;
@property(nonatomic,strong) RemoteWebViewOverlay *overlay;
@property(nonatomic,strong) dispatch_queue_t queue;
@property(nonatomic,strong) dispatch_source_t timer;
@property(atomic,assign) BOOL running;
@property(atomic,copy,readwrite) NSString *statusMessage;
@property(nonatomic,assign) uint64_t base;
@property(nonatomic,assign) BOOL profileChecked;
@property(nonatomic,assign) BOOL profileSupported;
@property(nonatomic,assign) NSTimeInterval nextSetup;
@property(nonatomic,assign) BOOL sentEmpty;
@end

#include "OverlayStartupSchedule.h"
@implementation FreeFireManager {
    MizzeOverlayStartup::Schedule _startup;
}
- (instancetype)initWithRemoteCall:(RemoteCall *)remoteCall {
    if((self=[super init])) {
        _remoteCall=remoteCall;_isESPEnabled=NO;_statusMessage=@"Free Fire: đang mở nút Mizze…";
        _queue=dispatch_queue_create("external.darksword.ff.esp",DISPATCH_QUEUE_SERIAL);
        _overlay=[[RemoteWebViewOverlay alloc] initWithRemoteCall:remoteCall];
        _overlay.gameIdentifier=@"freefire";
    }
    return self;
}
- (void)runLoop {
    if(self.running)return;
    if(!self.overlay.isOverlayReady)_startup.reset();
    self.running=YES;
    self.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,self.queue);
    dispatch_source_set_timer(self.timer,DISPATCH_TIME_NOW,NSEC_PER_SEC/20,NSEC_PER_MSEC*5);
    __weak FreeFireManager *weakSelf=self;
    dispatch_source_set_event_handler(self.timer,^{[weakSelf updateFrame];});
    dispatch_resume(self.timer);
}
- (void)emptyFrame {
    if(!self.sentEmpty) { [self.overlay clearTargets];self.sentEmpty=YES; }
}
- (void)startOverlay {
    [self runLoop];
    dispatch_async(self.queue,^{
        if(!self.running)return;
        if(!self.overlay.isOverlayReady)self->_startup.reset();
        else [self.overlay refreshOverlayLayout];
    });
}
- (void)updateFrame {
    @autoreleasepool {
        if(!self.running)return;
        if(![LicenseSession shared].authorized) { [self emptyFrame];return; }
        NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
        if(!self.overlay.isOverlayReady && _startup.begin(now)) {
            BOOL ready=[self.overlay setupBaseOverlay];
            _startup.finish(ready,self.overlay.setupCanRetry);
            if(!ready)MizzeRecordStage(@"ff.overlay.failed",self.overlay.setupError);
        }
        if(!self.overlay.isOverlayReady) {
            self.statusMessage=self.overlay.setupError.length?self.overlay.setupError:@"Free Fire: chưa tạo được menu; hãy xem nhật ký khởi tạo";
            return;
        }
        if(![LicenseSession shared].authorized) { [self emptyFrame];return; }
        if(!self.isESPEnabled) { [self emptyFrame];self.statusMessage=@"Free Fire: ESP đã tắt";return; }
        if(!self.base) {
            if(now<self.nextSetup)return;
            self.nextSetup=now+2;self.base=FindUnityFramework(self.remoteCall);
            if(!self.base) { [self emptyFrame];self.statusMessage=@"Free Fire: chưa đọc được UnityFramework";return; }
        }
        auto read=[&](uint64_t address,void *buffer,size_t size) {return bool([self.remoteCall remoteRead:address to:buffer size:size]);};
        FreeFireESP::Reader<decltype(read)> reader(read);
        if(!self.profileChecked) {self.profileSupported=reader.supports(self.base);self.profileChecked=YES;}
        if(!self.profileSupported) { [self emptyFrame];self.statusMessage=@"Free Fire: bản game không khớp TH 1.132.1";return; }
        FreeFireESP::Frame frame;
        if(!reader.snapshot(self.base,float(self.overlay.cachedScreenWidth),float(self.overlay.cachedScreenHeight),frame)) {
            [self emptyFrame];self.statusMessage=@"Free Fire: đang chờ trận hoặc dữ liệu hợp lệ";return;
        }
        if(!self.running || !self.isESPEnabled) { [self emptyFrame];return; }
        NSMutableArray<NSDictionary *> *targets=[NSMutableArray arrayWithCapacity:frame.count];
        for(size_t i=0;i<frame.count;i++) {
            const auto &t=frame.targets[i];
            [targets addObject:@{@"id":@(t.id),@"sx":@(t.headX),@"sy":@(t.headY),@"headX":@(t.headX),@"headY":@(t.headY),
                @"footX":@(t.footX),@"footY":@(t.footY),@"visible":@YES,@"onScreen":@YES,@"hasBox":@YES,
                @"boxX":@(t.x),@"boxY":@(t.y),@"boxW":@(t.w),@"boxH":@(t.h),
                @"drawLine":@NO,@"drawName":@NO,@"drawHealth":@NO,@"drawDistance":@NO}];
        }
        BOOL published=[self.overlay updateOverlayTargets:targets];self.sentEmpty=frame.count==0;
        self.statusMessage=published?[NSString stringWithFormat:@"Free Fire: ESP • %lu địch",(unsigned long)frame.count]:@"Free Fire: chưa tạo được lớp ESP; menu vẫn sẵn sàng";
    }
}
- (void)stopLoop {
    self.running=NO;
    if(self.timer) {dispatch_source_cancel(self.timer);self.timer=nil;}
    // Drain this reader before its RemoteCall can be destroyed or switched.
    dispatch_sync(self.queue,^{[self.overlay tearDown];});
}
- (void)clearOverlayTargets {dispatch_async(self.queue,^{[self emptyFrame];});}
- (void)setOverlayMenuVisible:(BOOL)visible {dispatch_async(self.queue,^{if(self.running)[self.overlay setOverlayMenuVisible:visible];});}
- (void)toggleOverlayMenu {dispatch_async(self.queue,^{if(self.running)[self.overlay toggleOverlayMenu];});}
- (void)setOverlayFloatButtonPositionX:(CGFloat)xRatio y:(CGFloat)yRatio {dispatch_async(self.queue,^{if(self.running)[self.overlay setOverlayFloatButtonPositionX:xRatio y:yRatio];});}
- (void)refreshOverlayLayout {dispatch_async(self.queue,^{if(self.running)[self.overlay refreshOverlayLayout];});}
@end
