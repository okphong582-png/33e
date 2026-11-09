#import "HHFreeFireReader.h"
#import "HHFFProfile.h"
#import "RemoteCall.h"
#import "utils.h"
#import "darksword.h"
#import "offsets.h"
#include <mach/task_info.h>
#include <dlfcn.h>
#include <string.h>

static BOOL HHGamePointer(uint64_t p){return p>0x10000&&p<0x80000000000ULL&&(p&7)==0;}
static uint64_t HHUnityImage(RemoteCall *s){
 void *taskInfo=dlsym(RTLD_DEFAULT,"task_info"),*selfPort=dlsym(RTLD_DEFAULT,"mach_task_self_");
 uint32_t task=0,count=TASK_DYLD_INFO_COUNT;
 if(!taskInfo||!selfPort||![s remoteRead:(uint64_t)selfPort to:&task size:sizeof(task)]||!task)return 0;
 uint64_t scratch=s.trojanMem+0x1000;
 if(![s remote_write:scratch from:&count size:sizeof(count)])return 0;
 uint64_t args[]={task,TASK_DYLD_INFO,scratch+8,scratch};
 if([s doRemoteCallStableWithTimeout:5 functionName:"task_info" functionPointer:taskInfo args:args argCount:4]!=KERN_SUCCESS)return 0;
 uint64_t info=0,array=0;uint32_t images=0;
 if(![s remoteRead:scratch+8 to:&info size:8]||!HHGamePointer(info)||![s remoteRead:info+4 to:&images size:4]||images>3000||!images||![s remoteRead:info+8 to:&array size:8]||!HHGamePointer(array))return 0;
 for(uint32_t i=images;i>0;i--){
  uint64_t entry[3]={0};char path[512]={0};
  if(![s remoteRead:array+24ULL*(i-1) to:entry size:sizeof(entry)]||!HHGamePointer(entry[0])||!HHGamePointer(entry[1]))continue;
  if([s remoteRead:entry[1] to:path size:sizeof(path)-1]&&strstr(path,"/UnityFramework.framework/UnityFramework"))return entry[0];
 }return 0;
}
static bool HHGameRead(void *context,uint64_t address,void *buffer,size_t size){
 RemoteCall *session=(__bridge RemoteCall *)context;
 return !session.lastError.length&&[session remoteRead:address to:buffer size:size];
}
@interface HHFreeFireReader ()
@property(nonatomic,strong) RemoteCall *session;
@property(nonatomic,copy,readwrite) NSString *status;
@property(nonatomic) uint64_t base,process;
@property(nonatomic) CFAbsoluteTime retryAt;
@property(nonatomic) BOOL profileChecked,profileSupported;
@property(nonatomic) BOOL connectionAttempted;
@end
@implementation HHFreeFireReader
- (instancetype)init{if((self=[super init]))_status=@"Đang chờ FF TH";return self;}
- (BOOL)connectIfNeededForPID:(pid_t)pid{
 if(pid<=0)return NO;
 CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
 if(now<self.retryAt)return self.session.pid==pid&&!self.session.lastError.length;
 self.retryAt=now+2;
 if(!ds_is_ready()){self.status=@"Phiên Lara chưa sẵn sàng";return NO;}
 uint64_t process=proc_find_by_name("FreeFire");
 if(self.session&&(!process||process!=self.process||self.session.pid!=pid||self.session.lastError.length)){[self disconnect];self.connectionAttempted=YES;self.status=@"Phiên game đã đổi; tắt/bật ESP để thử lại";self.retryAt=now+3;return NO;}
 if(!process||(pid_t)ds_kread32(process+off_proc_p_pid)!=pid){self.status=@"Chưa khớp phiên FF TH đang mở";return NO;}
 if(!self.session){
  if(self.connectionAttempted){self.status=@"Kết nối lỗi; tắt/bật ESP để thử lại";return NO;}
  self.connectionAttempted=YES;
  self.session=[[RemoteCall alloc] initWithProcess:@"FreeFire" useMigFilterBypass:NO];
  if(!self.session){self.status=[RemoteCall lastInitError]?:@"Chưa kết nối được FF TH";self.retryAt=now+5;return NO;}
  if(self.session.pid!=pid){[self disconnect];self.connectionAttempted=YES;self.status=@"Phiên FF TH đã đổi khi kết nối";return NO;}
  self.process=process;self.status=@"Đã kết nối FF TH";
 }
 if(!self.base){self.base=HHUnityImage(self.session);if(!self.base){self.status=@"Đang chờ UnityFramework";return YES;}}
 if(!self.profileChecked){self.profileSupported=hh_ff_supports(HHGameRead,(__bridge void *)self.session,self.base);self.profileChecked=YES;}
 if(!self.profileSupported)self.status=@"Bản game không khớp FF TH 1.132.1";
 return YES;
}
- (NSArray<NSValue *> *)boxesForSize:(CGSize)size{
 if(!self.session||!self.base||!self.profileSupported)return @[];
 HHFFBox boxes[32];size_t count=0;
 if(!hh_ff_snapshot(HHGameRead,(__bridge void *)self.session,self.base,size.width,size.height,boxes,&count)){self.status=@"Đang chờ trận / dữ liệu hợp lệ";return @[];}
 NSMutableArray *result=[NSMutableArray arrayWithCapacity:count];
 for(size_t i=0;i<count;i++)[result addObject:[NSValue valueWithCGRect:CGRectMake(boxes[i].x,boxes[i].y,boxes[i].w,boxes[i].h)]];
 self.status=[NSString stringWithFormat:@"ESP Box · %lu đối tượng",(unsigned long)count];return result;
}
- (void)disconnect{
 RemoteCall *session=self.session;self.session=nil;
 if(session)[session destroyRemoteCall];self.base=0;self.process=0;self.profileChecked=NO;self.profileSupported=NO;self.connectionAttempted=NO;self.status=@"Đang chờ FF TH";
}
@end
