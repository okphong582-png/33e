#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <map>
#include <string>
#include <cassert>
#include <cmath>
#define LOG(...) ((void)0)
static BOOL g_isDebug=NO;
static const CGFloat kWidth=844,kHeight=390;
static const NSUInteger UIViewAutoresizingFlexibleWidth=2,UIViewAutoresizingFlexibleHeight=16;
@interface RemoteCall : NSObject @end
@implementation RemoteCall @end
static CGRect screen=CGRectMake(0,0,390,844);
@interface UIScreen : NSObject
@property(readonly) CGRect bounds;
+ (instancetype)mainScreen;
@end
@implementation UIScreen
+ (instancetype)mainScreen {static UIScreen *s;static dispatch_once_t once;dispatch_once(&once,^{s=[UIScreen new];});return s;}
- (CGRect)bounds {return screen;}
@end
@interface OverlayWebSocketServer : NSObject
@property(readonly) uint16_t port;
@property(readonly) NSUInteger clientCount;
+ (instancetype)sharedServer;
- (BOOL)start;
- (void)broadcastTextData:(NSData *)data;
- (void)broadcastText:(NSString *)text;
@end
static NSMutableArray *payloads;
static bool serverFail=false;
@implementation OverlayWebSocketServer
+ (instancetype)sharedServer {static OverlayWebSocketServer *s;static dispatch_once_t once;dispatch_once(&once,^{s=[OverlayWebSocketServer new];});return s;}
- (uint16_t)port {return 12345;}
- (NSUInteger)clientCount {return 3;}
- (BOOL)start {return !serverFail;}
- (void)broadcastTextData:(NSData *)data {[payloads addObject:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];}
- (void)broadcastText:(NSString *)text {[payloads addObject:text];}
@end
void MizzeRecordStage(NSString *stage,NSString *detail) {(void)stage;(void)detail;}
static int nextID=100,viewAttempt=0,failAt=0,rectCalls=0,offMainUIKit=0;
static std::string failPhase;
static bool keyWindow=true,legacyWindow=true,webKit=true,unknownScene=false,hugeScenes=false;
static std::map<uint64_t,std::string> live;
static std::map<uint64_t,uint64_t> parents;
static uint64_t allocate(const char *kind) {uint64_t id=nextID++;live[id]=kind;return id;}
static bool failure(const char *phase) {return failAt==viewAttempt && failPhase==phase;}
uint64_t remote_getClass(RemoteCall *,const char *name) {
 if(!strcmp(name,"UIApplication"))return 1;
 if(!strcmp(name,"WKWebViewConfiguration"))return webKit?2:0;
 if(!strcmp(name,"WKWebView"))return webKit?3:0;
 if(!strcmp(name,"UIColor"))return 4;
 return 0;
}
uint64_t remote_sel(RemoteCall *,const char *name) {return (uint64_t)sel_registerName(name);}
static uint64_t message(uint64_t receiver,uint64_t selector,uint64_t argument,bool main) {
 const char *s=sel_getName((SEL)selector);
 if(!strcmp(s,"sharedApplication"))return 10;
 if(!strcmp(s,"keyWindow"))return keyWindow?20:0;
 if(!strcmp(s,"connectedScenes"))return 11;
 if(!strcmp(s,"allObjects"))return 12;
 if(!strcmp(s,"count"))return receiver==12?(hugeScenes?1000:1):1;
 if(!strcmp(s,"objectAtIndex:"))return receiver==12?13:20;
 if(!strcmp(s,"respondsToSelector:"))return !unknownScene;
 if(!strcmp(s,"windows")) {assert(receiver!=13||!unknownScene);return receiver==10?(legacyWindow?14:0):(legacyWindow?0:14);}
 if(!strcmp(s,"isHidden"))return 0;
 if(!strcmp(s,"isKeyWindow"))return 1;
 if(!strcmp(s,"clearColor"))return 30;
 if(!strcmp(s,"alloc")) {
   if(!main)offMainUIKit++;
   if(receiver==3){viewAttempt++;if(failure("alloc"))return 0;return allocate("view");}
   return allocate("config");
 }
 if(!strcmp(s,"init")) {if(!main)offMainUIKit++;return receiver;}
 if(!strcmp(s,"initWithFrame:configuration:")) {
   if(!main)offMainUIKit++;
   if(failure("init")){assert(live.erase(receiver)==1);return 0;}return receiver;
 }
 if(!strcmp(s,"release")){assert(live.erase(receiver)==1);return 0;}
 if(!strcmp(s,"loadHTMLString:baseURL:"))return failure("load")?0:40;
 if(!strcmp(s,"addSubview:")){if(!failure("attach"))parents[argument]=receiver;return 0;}
 if(!strcmp(s,"superview"))return parents[receiver];
 if(!strcmp(s,"removeFromSuperview")){parents.erase(receiver);return 0;}
 return 0;
}
uint64_t remote_msg(RemoteCall *,uint64_t r,uint64_t s,uint64_t a,uint64_t,uint64_t,uint64_t) {return message(r,s,a,false);}
uint64_t remote_msg_on_main_thread(RemoteCall *,uint64_t r,uint64_t s,const void *const *args,const size_t *sizes,size_t count) {
 uint64_t a=0;if(count&&sizes[0]==sizeof(a))memcpy(&a,args[0],sizeof(a));return message(r,s,a,true);
}
uint64_t remote_NSString(RemoteCall *,const char *) {return failure("html")?0:allocate("html");}
CGRect remote_getCGRect(RemoteCall *,uint64_t,uint64_t) {rectCalls++;return CGRectMake(0,0,NAN,NAN);}
// INSERT_PRODUCTION_OVERLAY
@interface TestOverlay : RemoteWebViewOverlay
@property(copy) NSString *missingResource;
@end
@implementation TestOverlay
- (NSString *)loadOverlayHTMLResource:(NSString *)resource {return [resource isEqualToString:self.missingResource]?nil:@"<html>test</html>";}
@end
static void reset(void) {
 assert(live.empty());parents.clear();payloads=[NSMutableArray new];
 nextID=100;viewAttempt=failAt=rectCalls=offMainUIKit=0;failPhase="";
 keyWindow=legacyWindow=webKit=true;unknownScene=hugeScenes=serverFail=false;
 screen=CGRectMake(0,0,390,844);
}
static TestOverlay *overlay(void) {TestOverlay *o=[[TestOverlay alloc]initWithRemoteCall:[RemoteCall new]];o.gameIdentifier=@"freefire";return o;}
static void success(TestOverlay *o) {
 assert([o setupBaseOverlay]);assert(o.isOverlayReady);assert(viewAttempt==3);
 assert(o.cachedScreenWidth==844&&o.cachedScreenHeight==390);
 assert(live.size()==3);for(auto &entry:live)assert(entry.second=="view");
 assert([o setupBaseOverlay]);assert(viewAttempt==3);
 [o refreshOverlayLayout];[o setOverlayFloatButtonPositionX:.2 y:.8];[o toggleOverlayMenu];
 assert(rectCalls==0&&offMainUIKit==0);
 [o tearDown];assert(!o.isOverlayReady);assert(live.empty());assert(parents.empty());
 NSDictionary *last=payloads.lastObject;assert([last[@"game"]isEqual:@"freefire"]);assert([last[@"targets"]count]==0);
 [o tearDown];assert(live.empty());
}
int main(void) {@autoreleasepool {
 reset();success(overlay());
 reset();keyWindow=false;unknownScene=true;success(overlay());
 reset();keyWindow=legacyWindow=false;success(overlay());
 reset();keyWindow=false;hugeScenes=true;success(overlay());
 for(const char *phase:{"alloc","init","html","load","attach"})for(int stage=1;stage<=3;stage++){
   reset();failPhase=phase;failAt=stage;TestOverlay *o=overlay();
   assert(![o setupBaseOverlay]);assert(!o.isOverlayReady);assert(o.setupError.length);
   assert(live.empty()&&parents.empty());[o tearDown];assert(live.empty());
 }
 for(NSString *resource in @[@"overlay_esp",@"overlay_menu",@"overlay_fab"]){
   reset();TestOverlay *o=overlay();o.missingResource=resource;assert(![o setupBaseOverlay]);assert(live.empty()&&parents.empty());
 }
 reset();webKit=false;assert(![overlay()setupBaseOverlay]);assert(viewAttempt==0);
 reset();serverFail=true;assert(![overlay()setupBaseOverlay]);assert(viewAttempt==0);
 for(CGFloat width:{CGFloat(NAN),CGFloat(INFINITY),CGFloat(0),CGFloat(9000)}){reset();screen=CGRectMake(0,0,width,390);assert(![overlay()setupBaseOverlay]);assert(viewAttempt==0);}
 NSLog(@"PASS production overlay: success, legacy/scene windows, invalid bounds, missing WebKit/HTML/server, 15 staged failures, ownership rollback, scoped clear, no FF CGRect helper, main-thread construction.");
 }return 0;}
