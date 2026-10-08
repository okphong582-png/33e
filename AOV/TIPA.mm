#import "ui/Overlay.h"
#include "ui/FingerState.h"
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>
#import <dlfcn.h>
#include <spawn.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <initializer_list>
#include <fcntl.h>
extern char **environ;
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t *,uid_t,uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *,uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *,gid_t);
static NSString *const StatusPath=@"/var/mobile/Library/Caches/com.hoanghadev.aov.status";
static const char *StopNotification="com.hoanghadev.aov.stop";
static AOVOverlay *HUDOverlay;
static NSString *HUDSession;
static BOOL RawTouchRouting;
static BOOL NativeTouchRouting;
static CFArrayRef (*HIDChildren)(void *);
static uint32_t (*HIDType)(void *);
static CFIndex (*HIDInteger)(void *,uint32_t);
static double (*HIDFloat)(void *,uint32_t);
@interface UIWindow (AOVPrivate)
- (instancetype)_initWithFrame:(CGRect)frame attached:(BOOL)attached;
- (unsigned int)_contextId;
@end
@interface UIApplication (AOVPrivate)
- (void)_accessibilityInit;
- (void)__completeAndRunAsPlugin;
@end
@interface NSObject (AOVAccessibility)
+ (id)representationWithHIDEvent:(void *)event hidStreamIdentifier:(NSString *)identifier;
- (id)handInfo;
- (NSArray *)paths;
- (NSInteger)pathIdentity;
- (CGPoint)location;
- (BOOL)isTouchDown;
- (BOOL)isMove;
- (BOOL)isCancel;
- (BOOL)isLift;
- (BOOL)isInRangeLift;
- (NSInteger)orientation;
- (void)setHandler:(void (^)(id))handler;
- (void)invalidate;
@end
static BOOL InstallNativeEventLoop(UIApplication *app){
    @try{
        id dispatcher=[app valueForKey:@"eventDispatcher"];
        Class fetcherClass=NSClassFromString(@"UIEventFetcher");
        SEL install=NSSelectorFromString(@"_installEventRunLoopSources:");
        if(!dispatcher||!fetcherClass||![dispatcher respondsToSelector:install])return NO;
        ((void(*)(id,SEL,CFRunLoopRef))objc_msgSend)(dispatcher,install,CFRunLoopGetMain());
        id fetcher=[fetcherClass new];[dispatcher setValue:fetcher forKey:@"eventFetcher"];
        SEL sink=NSSelectorFromString(@"setEventFetcherSink:");
        if([fetcher respondsToSelector:sink])((void(*)(id,SEL,id))objc_msgSend)(fetcher,sink,dispatcher);
        else [fetcher setValue:dispatcher forKey:@"eventFetcherSink"];
        [app setValue:fetcher forKey:@"eventFetcher"];return YES;
    }@catch(NSException *exception){return NO;}
}
static void WriteStatus(NSString *s){
    [@{@"session":HUDSession?:@"",@"message":s,@"pid":@(getpid()),@"ready":@NO} writeToFile:StatusPath atomically:YES];
}
@interface AOVExternalOverlay : AOVOverlay
@property(nonatomic,weak) UIWindow *canvasWindow;
@end
@implementation AOVExternalOverlay
- (UIEdgeInsets)safeAreaInsets{return self.canvasWindow.safeAreaInsets;}
@end
@interface AOVDrawingWindow : UIWindow
@end
@implementation AOVDrawingWindow
+ (BOOL)_isSystemWindow{return YES;}
- (BOOL)_isWindowServerHostingManaged{return NO;}
- (BOOL)_usesWindowServerHitTesting{return NO;}
- (BOOL)_ignoresHitTest{return YES;}
- (instancetype)initWithFrame:(CGRect)f{return [super _initWithFrame:f attached:YES];}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event{
    // Drawing never owns a foreground-game touch. Menu taps come from HID.
    return nil;
}
@end
@interface AOVMenuWindow : AOVDrawingWindow
@end
@implementation AOVMenuWindow
- (BOOL)_usesWindowServerHitTesting{return YES;}
- (BOOL)_ignoresHitTest{return NO;}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event{
    UIView *control=[HUDOverlay hitTest:[HUDOverlay convertPoint:p fromView:self] withEvent:event];
    // Native UIKit dispatch or one manual HID path, never both.
    return NativeTouchRouting?control:(control?self.rootViewController.view:nil);
}
@end
@interface AOVHUDApplication : UIApplication
@end
@implementation AOVHUDApplication
- (instancetype)init {
    if((self=[super init])){
        void (^stop)(int)=^(int value){
            if(HUDOverlay)[HUDOverlay stopWithCompletion:^{WriteStatus(@"Đã tắt menu");_exit(0);}];
            else {WriteStatus(@"Đã tắt menu");_exit(0);}
        };
        int token;notify_register_dispatch(StopNotification,&token,dispatch_get_main_queue(),stop);
        NSString *sessionStop=[@"com.hoanghadev.aov.stop." stringByAppendingString:HUDSession?:@""];
        notify_register_dispatch(sessionStop.UTF8String,&token,dispatch_get_main_queue(),stop);
    }return self;
}
@end
@interface AOVHUDDelegate : NSObject <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) UIWindow *menuWindow;
@property(nonatomic,strong) id hosting;
@property(nonatomic,strong) id menuHosting;
@property(nonatomic,strong) id orientationObserver;
@property(nonatomic,assign) unsigned int hostingAttempts;
@property(nonatomic,assign) UIInterfaceOrientation currentOrientation;
- (void)startHUD;
- (void)hostWindow;
- (void)rotate:(UIInterfaceOrientation)orientation;
- (void)layoutMenuWindow;
@end
@implementation AOVHUDDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts{
    [self startHUD];return YES;
}
- (void)startHUD{
    if(self.window)return;
    WriteStatus(@"Đang tạo cửa sổ nổi…");
    self.window=[[AOVDrawingWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.backgroundColor=UIColor.clearColor;self.window.windowLevel=10000010;self.window.userInteractionEnabled=NO;
    UIViewController *root=[UIViewController new];root.view.backgroundColor=UIColor.clearColor;self.window.rootViewController=root;
    AOVExternalOverlay *external=[[AOVExternalOverlay alloc] initWithFrame:self.window.bounds];external.canvasWindow=self.window;HUDOverlay=external;
    UIView *drawing=[HUDOverlay drawingView];[drawing removeFromSuperview];[root.view addSubview:drawing];
    self.menuWindow=[[AOVMenuWindow alloc] initWithFrame:CGRectMake(0,0,52,52)];self.menuWindow.backgroundColor=UIColor.clearColor;self.menuWindow.windowLevel=10000011;self.menuWindow.clipsToBounds=YES;
    UIViewController *menuRoot=[UIViewController new];menuRoot.view.backgroundColor=UIColor.clearColor;menuRoot.view.clipsToBounds=YES;self.menuWindow.rootViewController=menuRoot;
    HUDOverlay.autoresizingMask=UIViewAutoresizingNone;[menuRoot.view addSubview:HUDOverlay];
    __weak AOVHUDDelegate *geometryOwner=self;HUDOverlay.geometryChanged=^{[geometryOwner layoutMenuWindow];};
    self.window.hidden=NO;self.menuWindow.hidden=NO;[self.menuWindow makeKeyAndVisible];
    UIInterfaceOrientation orientation=UIApplication.sharedApplication.statusBarOrientation;
    [self rotate:orientation==UIInterfaceOrientationUnknown?UIInterfaceOrientationPortrait:orientation];
    [self.window layoutIfNeeded];[HUDOverlay layoutIfNeeded];
    // UIKit can assign the display context on the next run-loop turn.
    dispatch_async(dispatch_get_main_queue(),^{[self hostWindow];});
    Class observer=NSClassFromString(@"FBSOrientationObserver");
    self.orientationObserver=observer?[observer new]:nil;
    if([self.orientationObserver respondsToSelector:@selector(setHandler:)]){
        __weak AOVHUDDelegate *weak=self;
        [self.orientationObserver setHandler:^(id update){if([update respondsToSelector:@selector(orientation)]){NSInteger orientation=((NSInteger(*)(id,SEL))objc_msgSend)(update,@selector(orientation));dispatch_async(dispatch_get_main_queue(),^{[weak rotate:(UIInterfaceOrientation)orientation];});}}];
    }
    __weak AOVHUDDelegate *weak=self;
    int token;notify_register_dispatch("SBSpringBoardDidLaunchNotification",&token,dispatch_get_main_queue(),^(int t){[weak hostWindow];});
}
- (void)rotate:(UIInterfaceOrientation)o{
    if(o==UIInterfaceOrientationUnknown||o==self.currentOrientation)return;
    self.currentOrientation=o;
    CGRect screen=UIScreen.mainScreen.bounds;CGFloat w=MIN(screen.size.width,screen.size.height),h=MAX(screen.size.width,screen.size.height);
    self.window.transform=CGAffineTransformIdentity;
    self.window.bounds=CGRectMake(0,0,UIInterfaceOrientationIsLandscape(o)?h:w,UIInterfaceOrientationIsLandscape(o)?w:h);
    self.window.center=CGPointMake(CGRectGetMidX(screen),CGRectGetMidY(screen));
    CGFloat angle=o==UIInterfaceOrientationLandscapeLeft?-M_PI_2:o==UIInterfaceOrientationLandscapeRight?M_PI_2:o==UIInterfaceOrientationPortraitUpsideDown?M_PI:0;
    [HUDOverlay cancelScreenTouch];
    self.window.transform=CGAffineTransformMakeRotation(angle);self.window.rootViewController.view.frame=self.window.bounds;HUDOverlay.frame=self.window.bounds;[HUDOverlay setNeedsLayout];[HUDOverlay layoutIfNeeded];
    [HUDOverlay drawingView].frame=self.window.bounds;[self layoutMenuWindow];
}
- (void)layoutMenuWindow{
    if(!self.menuWindow||!HUDOverlay)return;
    CGRect rect=[HUDOverlay interactiveFrame];
    CGPoint center=[self.window convertPoint:CGPointMake(CGRectGetMidX(rect),CGRectGetMidY(rect)) toCoordinateSpace:UIScreen.mainScreen.coordinateSpace];
    CGAffineTransform transform=self.window.transform;
    CGRect overlayFrame=CGRectMake(-rect.origin.x,-rect.origin.y,self.window.bounds.size.width,self.window.bounds.size.height);
    if(CGSizeEqualToSize(self.menuWindow.bounds.size,rect.size)&&CGPointEqualToPoint(self.menuWindow.center,center)&&CGAffineTransformEqualToTransform(self.menuWindow.transform,transform)&&CGRectEqualToRect(HUDOverlay.frame,overlayFrame))return;
    self.menuWindow.transform=CGAffineTransformIdentity;self.menuWindow.bounds=CGRectMake(0,0,rect.size.width,rect.size.height);self.menuWindow.center=center;self.menuWindow.transform=transform;
    self.menuWindow.rootViewController.view.frame=self.menuWindow.bounds;HUDOverlay.frame=overlayFrame;
}
- (void)hostWindow{
    self.window.hidden=NO;self.menuWindow.hidden=NO;[self.menuWindow makeKeyAndVisible];[self.window layoutIfNeeded];[self.menuWindow layoutIfNeeded];
    Class host=NSClassFromString(@"SBSAccessibilityWindowHostingController");if(!self.hosting)self.hosting=host?[host new]:nil;
    SEL selector=NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
    if(![self.hosting respondsToSelector:selector]){WriteStatus(@"iOS không hỗ trợ cửa sổ nổi");_exit(2);}
    unsigned int context=[self.window _contextId];double level=self.window.windowLevel;
    unsigned int menuContext=[self.menuWindow _contextId];
    if(!context){[self.window layoutIfNeeded];context=[self.window _contextId];}
    if(!context||!menuContext){
        if(++self.hostingAttempts<20){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self hostWindow];});return;}
        WriteStatus(@"iOS chưa cấp cửa sổ nổi — kiểm tra quyền TrollStore");_exit(2);
    }
    NSMethodSignature *signature=[self.hosting methodSignatureForSelector:selector];
    if(!signature||signature.numberOfArguments!=4){WriteStatus(@"Cửa sổ nổi chưa tương thích");_exit(2);}
    const char *levelType=[signature getArgumentTypeAtIndex:3];
    if(strcmp(levelType,"d")&&strcmp(levelType,"f")){WriteStatus(@"Cửa sổ nổi chưa tương thích");_exit(2);}
    NSInvocation *call=[NSInvocation invocationWithMethodSignature:signature];call.target=self.hosting;call.selector=selector;[call setArgument:&context atIndex:2];
    if(!strcmp(levelType,"f")){float floatLevel=level;[call setArgument:&floatLevel atIndex:3];}else [call setArgument:&level atIndex:3];
    [call invoke];
    if(!self.menuHosting)self.menuHosting=[host new];
    context=menuContext;level=self.menuWindow.windowLevel;call.target=self.menuHosting;[call setArgument:&context atIndex:2];
    if(!strcmp(levelType,"f")){float floatLevel=level;[call setArgument:&floatLevel atIndex:3];}else [call setArgument:&level atIndex:3];
    [call invoke];[HUDOverlay setNeedsLayout];[HUDOverlay layoutIfNeeded];[CATransaction flush];
    [@{@"session":HUDSession?:@"",@"message":@"Đã đăng ký menu — bấm nút A để mở",@"pid":@(getpid()),@"ready":@YES} writeToFile:StatusPath atomically:YES];
}
@end
static BOOL RouteDigitizer(void *event,unsigned int depth,const CGPoint *singlePoint){
    if(!event||depth>3)return NO;
    CFArrayRef children=HIDChildren(event);
    CFIndex count=children?CFArrayGetCount(children):0;
    if(count){
        BOOL routed=NO;
        for(CFIndex i=0;i<MIN(count,32);i++)routed=RouteDigitizer((void *)CFArrayGetValueAtIndex(children,i),depth+1,singlePoint)||routed;
        return routed;
    }
    constexpr uint32_t base=11u<<16;
    if(HIDType(event)!=11||HIDInteger(event,base+4)!=2)return NO;
    // IOHID digitizer fields match the KIF declarations in this repository.
    uint64_t identity=static_cast<uint32_t>(HIDInteger(event,base+6));
    uint64_t index=static_cast<uint32_t>(HIDInteger(event,base+5));
    uint64_t finger=(identity<<32)|index;
    uint32_t mask=static_cast<uint32_t>(HIDInteger(event,base+7));
    static aov::FingerState fingers;
    auto state=fingers.update(finger,HIDInteger(event,base+9)!=0,(mask&(1u<<7))!=0);
    if(state==aov::FingerPhase::none)return YES;
    UITouchPhase phase;
    switch(state){
        case aov::FingerPhase::began:phase=UITouchPhaseBegan;break;
        case aov::FingerPhase::moved:phase=UITouchPhaseMoved;break;
        case aov::FingerPhase::ended:phase=UITouchPhaseEnded;break;
        default:phase=UITouchPhaseCancelled;break;
    }
    double x=HIDFloat(event,base),y=HIDFloat(event,base+1);
    if(!std::isfinite(x)||!std::isfinite(y)){[HUDOverlay cancelScreenTouch];return YES;}
    UIScreen *screen=UIScreen.mainScreen;
    // Hardware positions are normalized in the physical portrait space.
    CGRect fixed=screen.fixedCoordinateSpace.bounds;
    CGPoint point=CGPointMake(fixed.origin.x+x*fixed.size.width,fixed.origin.y+y*fixed.size.height);
    point=[screen.coordinateSpace convertPoint:point fromCoordinateSpace:screen.fixedCoordinateSpace];
    // AX provides UIKit screen coordinates on systems that rotate HID input.
    // Keep raw per-finger phases, but use AX's point for a single-finger packet.
    if(singlePoint)point=*singlePoint;
    [HUDOverlay handleScreenPoint:point phase:phase identity:static_cast<NSInteger>(finger)];
    return YES;
}
static void HIDCallback(void *target,void *ref,void *service,void *event){
    @autoreleasepool{
        if(NativeTouchRouting)return;
        if(RawTouchRouting){
            CFRetain(event);
            dispatch_async(dispatch_get_main_queue(),^{@autoreleasepool{
                Class cls=NSClassFromString(@"AXEventRepresentation");id rep=nil;
                if([cls respondsToSelector:@selector(representationWithHIDEvent:hidStreamIdentifier:)])rep=[cls representationWithHIDEvent:event hidStreamIdentifier:@"UIApplicationEvents"];
                NSArray *paths=[[rep handInfo] paths];CGPoint point=CGPointZero;
                BOOL single=paths.count==1&&[rep respondsToSelector:@selector(location)];
                if(single){point=((CGPoint(*)(id,SEL))objc_msgSend)(rep,@selector(location));single=std::isfinite(point.x)&&std::isfinite(point.y);}
                RouteDigitizer(event,0,single?&point:nullptr);CFRelease(event);
            }});
            return;
        }
        Class cls=NSClassFromString(@"AXEventRepresentation");
        id rep=[cls representationWithHIDEvent:event hidStreamIdentifier:@"UIApplicationEvents"];
        NSArray *paths=[[rep handInfo] paths];
        if(paths.count>1)return; // AX fallback has no per-path coordinates.
        id path=paths.firstObject;if(!path)return;
        UITouchPhase phase;
        if([rep isCancel])phase=UITouchPhaseCancelled;
        else if([rep isLift]||[rep isInRangeLift])phase=UITouchPhaseEnded;
        else if([rep isTouchDown])phase=UITouchPhaseBegan;
        else if([rep isMove])phase=UITouchPhaseMoved;
        else return; // In-range alone is not a finger lift.
        CGPoint location=((CGPoint(*)(id,SEL))objc_msgSend)(rep,@selector(location));NSInteger identity=[path pathIdentity];
        dispatch_async(dispatch_get_main_queue(),^{[HUDOverlay handleScreenPoint:location phase:phase identity:identity];});
    }
}
@interface AOVLauncherController : UIViewController
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *start;
@property(nonatomic,assign) BOOL launching;
@property(nonatomic,strong) NSString *session;
@property(nonatomic,strong) NSTimer *startupTimer;
@property(nonatomic,assign) CFTimeInterval deadline;
@end
@implementation AOVLauncherController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];
    UIStackView *stack=[[UIStackView alloc] init];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];
    UILabel *title=[UILabel new];title.text=@"AOV";title.font=[UIFont systemFontOfSize:44 weight:UIFontWeightBold];title.textColor=[UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];title.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:title];
    UILabel *subtitle=[UILabel new];subtitle.text=@"ESP địch · ESP quái";subtitle.font=[UIFont systemFontOfSize:17 weight:UIFontWeightMedium];subtitle.textColor=UIColor.whiteColor;subtitle.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:subtitle];
    self.start=[UIButton buttonWithType:UIButtonTypeSystem];[self.start setTitle:@"Bật menu nổi" forState:UIControlStateNormal];self.start.backgroundColor=[UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];[self.start setTitleColor:UIColor.blackColor forState:UIControlStateNormal];self.start.titleLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];self.start.layer.cornerRadius=16;[self.start.heightAnchor constraintEqualToConstant:56].active=YES;[self.start addTarget:self action:@selector(launch) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.start];
    UIButton *stop=[UIButton buttonWithType:UIButtonTypeSystem];[stop setTitle:@"Tắt menu" forState:UIControlStateNormal];stop.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];stop.backgroundColor=[UIColor colorWithWhite:.11 alpha:1];stop.layer.cornerRadius=14;stop.layer.borderWidth=1;stop.layer.borderColor=[UIColor colorWithWhite:.23 alpha:1].CGColor;[stop setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];[stop.heightAnchor constraintEqualToConstant:44].active=YES;[stop addTarget:self action:@selector(stopHUD) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:stop];
    self.status=[UILabel new];self.status.text=@"Liên Quân VN · 1.64.1.7";self.status.numberOfLines=3;self.status.textAlignment=NSTextAlignmentCenter;self.status.textColor=[UIColor colorWithWhite:.65 alpha:1];self.status.font=[UIFont systemFontOfSize:13];[stack addArrangedSubview:self.status];
    UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];credit.textColor=[UIColor colorWithWhite:.4 alpha:1];credit.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:credit];
    [NSLayoutConstraint activateConstraints:@[[stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[stack.widthAnchor constraintEqualToConstant:280]]];
}
- (void)stopHUD{notify_post(StopNotification);[self.startupTimer invalidate];self.startupTimer=nil;self.session=nil;self.launching=NO;self.start.enabled=YES;self.status.text=@"Đã tắt menu";}
- (void)pollStartup {
    NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:StatusPath];
    BOOL matches=[state[@"session"] isEqualToString:self.session];
    if(matches&&[state[@"message"] isKindOfClass:NSString.class])self.status.text=state[@"message"];
    if(matches&&[state[@"ready"] boolValue]){
        [self.startupTimer invalidate];self.startupTimer=nil;self.launching=NO;self.start.enabled=YES;return;
    }
    if(CACurrentMediaTime()>self.deadline){
        [self.startupTimer invalidate];self.startupTimer=nil;self.launching=NO;self.start.enabled=YES;
        if(!matches)self.status.text=@"HUD chưa phản hồi — thử bật lại menu";
        else if([state[@"message"] hasPrefix:@"Đang"])self.status.text=@"HUD chưa khởi chạy xong — thử bật lại menu";
    }
}
- (void)launch{
    if(self.launching)return;self.launching=YES;self.start.enabled=NO;self.status.text=@"Đang mở menu…";
    self.session=NSUUID.UUID.UUIDString;NSString *session=self.session;
    // Stop our previous HUD, then spawn a fresh copy with isolated settings.
    notify_post(StopNotification);__weak AOVLauncherController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        AOVLauncherController *current=weak;if(!current||![current.session isEqualToString:session])return;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *executable=NSBundle.mainBundle.executablePath;posix_spawnattr_t attr;posix_spawnattr_init(&attr);
        int error=posix_spawnattr_set_persona_np(&attr,99,1);
        if(!error)error=posix_spawnattr_set_persona_uid_np(&attr,0);
        if(!error)error=posix_spawnattr_set_persona_gid_np(&attr,0);
        posix_spawnattr_setpgroup(&attr,0);posix_spawnattr_setflags(&attr,POSIX_SPAWN_SETPGROUP);
        pid_t pid=0;const char *args[]={executable.fileSystemRepresentation,"-hud",session.UTF8String,nullptr};
        if(!error)error=posix_spawn(&pid,args[0],nullptr,&attr,const_cast<char **>(args),environ);posix_spawnattr_destroy(&attr);
        if(!error)dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
            int status=0;pid_t result;do{result=waitpid(pid,&status,0);}while(result<0&&errno==EINTR);
            dispatch_async(dispatch_get_main_queue(),^{
                AOVLauncherController *s=weak;if(!s||![s.session isEqualToString:session])return;
                [s.startupTimer invalidate];s.startupTimer=nil;s.launching=NO;s.start.enabled=YES;
                NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:StatusPath];
                if(result>0&&WIFSIGNALED(status))s.status.text=[NSString stringWithFormat:@"HUD đã dừng (signal %d) — thử bật lại",WTERMSIG(status)];
                else if([state[@"session"] isEqualToString:session]&&![state[@"ready"] boolValue])s.status.text=state[@"message"];
                else s.status.text=@"HUD đã dừng — bấm Bật menu nổi để mở lại";
                s.session=nil;
            });
        });
        dispatch_async(dispatch_get_main_queue(),^{
            AOVLauncherController *s=weak;
            if(!s||![s.session isEqualToString:session]){
                if(!error){
                    NSString *sessionStop=[@"com.hoanghadev.aov.stop." stringByAppendingString:session];
                    notify_post(sessionStop.UTF8String);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{notify_post(sessionStop.UTF8String);});
                }return;
            }
            if(error){s.launching=NO;s.start.enabled=YES;s.status.text=[NSString stringWithFormat:@"Không mở được HUD (%d)",error];return;}
            s.deadline=CACurrentMediaTime()+12;[s.startupTimer invalidate];
            s.startupTimer=[NSTimer scheduledTimerWithTimeInterval:.4 repeats:YES block:^(NSTimer *t){[weak pollStartup];}];[s pollStartup];
        });
        });
    });
}
@end
@interface AOVLauncherDelegate : NSObject <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AOVLauncherDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts{self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[AOVLauncherController new];[self.window makeKeyAndVisible];return YES;}
@end
static int RunHUD(){
    int lock=open("/var/mobile/Library/Caches/com.hoanghadev.aov.lock",O_CREAT|O_RDWR,0666);
    if(lock<0||flock(lock,LOCK_EX|LOCK_NB)!=0){WriteStatus(@"Menu đã có tiến trình chạy");return 1;}
    WriteStatus(@"Đang khởi tạo HUD…");
    for(const char *path:{"/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices","/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices","/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices","/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities","/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices"})dlopen(path,RTLD_LAZY|RTLD_GLOBAL);
    auto gs=(void(*)())dlsym(RTLD_DEFAULT,"GSInitialize"),bks=(void(*)())dlsym(RTLD_DEFAULT,"BKSDisplayServicesStart"),init=(void(*)())dlsym(RTLD_DEFAULT,"UIApplicationInitialize");
    auto singleton=(void(*)(id))dlsym(RTLD_DEFAULT,"UIApplicationInstantiateSingleton");
    auto callback=(void *(*)(void(*)(void *,void *,void *,void *)))dlsym(RTLD_DEFAULT,"BKSHIDEventRegisterEventCallback");
    if(!gs||!bks||!init||!singleton||!callback||![UIWindow instancesRespondToSelector:@selector(_initWithFrame:attached:)]){WriteStatus(@"iOS không hỗ trợ khởi chạy HUD");return 2;}
    [UIScreen class];CFRunLoopGetCurrent();gs();bks();init();singleton(AOVHUDApplication.class);
    UIApplication *app=UIApplication.sharedApplication;static AOVHUDDelegate *delegate=[AOVHUDDelegate new];app.delegate=delegate;
    NativeTouchRouting=InstallNativeEventLoop(app);
    dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY|RTLD_GLOBAL);
    HIDChildren=(CFArrayRef(*)(void *))dlsym(RTLD_DEFAULT,"IOHIDEventGetChildren");
    HIDType=(uint32_t(*)(void *))dlsym(RTLD_DEFAULT,"IOHIDEventGetType");
    HIDInteger=(CFIndex(*)(void *,uint32_t))dlsym(RTLD_DEFAULT,"IOHIDEventGetIntegerValue");
    HIDFloat=(double(*)(void *,uint32_t))dlsym(RTLD_DEFAULT,"IOHIDEventGetFloatValue");
    RawTouchRouting=HIDChildren&&HIDType&&HIDInteger&&HIDFloat;
    Class representation=NSClassFromString(@"AXEventRepresentation");
    if(!NativeTouchRouting&&!RawTouchRouting&&(!representation||![representation respondsToSelector:@selector(representationWithHIDEvent:hidStreamIdentifier:)])){WriteStatus(@"iOS chưa hỗ trợ cảm ứng menu nổi");return 2;}
    if([app respondsToSelector:@selector(_accessibilityInit)])[app _accessibilityInit];
    if(!NativeTouchRouting)callback(HIDCallback);
    auto eventInit=(void(*)(Boolean))dlsym(RTLD_DEFAULT,"GSEventInitialize");auto mode=(void(*)(CFStringRef))dlsym(RTLD_DEFAULT,"GSEventPushRunLoopMode");if(eventInit)eventInit(false);if(mode)mode(kCFRunLoopDefaultMode);
    if(![app respondsToSelector:@selector(__completeAndRunAsPlugin)]){WriteStatus(@"UIKit chưa hỗ trợ HUD");return 2;}
    dispatch_async(dispatch_get_main_queue(),^{[delegate startHUD];});
    [app __completeAndRunAsPlugin];
    // Some plugin runtimes don't deliver the normal launch delegate callback.
    [delegate startHUD];CFRunLoopRun();return 0;
}
int main(int argc,char **argv){@autoreleasepool{
    if(argc>1&&!strcmp(argv[1],"-hud")){
        HUDSession=argc>2?[NSString stringWithUTF8String:argv[2]]:NSUUID.UUID.UUIDString;
        @try{return RunHUD();}@catch(NSException *e){WriteStatus([NSString stringWithFormat:@"HUD không tương thích (%@)",e.name]);return 2;}
    }
    return UIApplicationMain(argc,argv,nil,NSStringFromClass(AOVLauncherDelegate.class));
}}
