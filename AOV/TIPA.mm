#import "ui/Overlay.h"
#import <objc/message.h>
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
- (BOOL)isInRange;
- (BOOL)isInRangeLift;
- (NSInteger)orientation;
- (void)setHandler:(void (^)(id))handler;
- (void)invalidate;
@end
static void WriteStatus(NSString *s){[s writeToFile:StatusPath atomically:YES encoding:NSUTF8StringEncoding error:nil];}
@interface AOVHUDWindow : UIWindow
@end
@implementation AOVHUDWindow
+ (BOOL)_isSystemWindow{return YES;}
- (BOOL)_isWindowServerHostingManaged{return NO;}
- (BOOL)_usesWindowServerHitTesting{return YES;}
- (BOOL)_ignoresHitTest{return NO;}
- (instancetype)initWithFrame:(CGRect)f{return [super _initWithFrame:f attached:YES];}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event{return [HUDOverlay hitTest:[HUDOverlay convertPoint:p fromView:self] withEvent:event];}
@end
@interface AOVHUDApplication : UIApplication
@end
@implementation AOVHUDApplication
- (instancetype)init {
    if((self=[super init])){int token;notify_register_dispatch(StopNotification,&token,dispatch_get_main_queue(),^(int value){WriteStatus(@"Đã tắt menu");_exit(0);});}return self;
}
@end
@interface AOVHUDDelegate : NSObject <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) id hosting;
@property(nonatomic,strong) id orientationObserver;
- (void)hostWindow;
- (void)rotate:(UIInterfaceOrientation)orientation;
@end
@implementation AOVHUDDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts{
    self.window=[[AOVHUDWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.backgroundColor=UIColor.clearColor;self.window.windowLevel=10000010;
    UIViewController *root=[UIViewController new];root.view.backgroundColor=UIColor.clearColor;self.window.rootViewController=root;
    HUDOverlay=[[AOVOverlay alloc] initWithFrame:self.window.bounds];[root.view addSubview:HUDOverlay];self.window.hidden=NO;[self.window makeKeyAndVisible];
    [self rotate:UIInterfaceOrientationLandscapeRight];[self hostWindow];
    Class observer=NSClassFromString(@"FBSOrientationObserver");
    self.orientationObserver=observer?[observer new]:nil;
    if([self.orientationObserver respondsToSelector:@selector(setHandler:)]){
        __weak AOVHUDDelegate *weak=self;
        [self.orientationObserver setHandler:^(id update){if([update respondsToSelector:@selector(orientation)]){NSInteger orientation=[update orientation];dispatch_async(dispatch_get_main_queue(),^{[weak rotate:(UIInterfaceOrientation)orientation];});}}];
    }
    __weak AOVHUDDelegate *weak=self;
    int token;notify_register_dispatch("SBSpringBoardDidLaunchNotification",&token,dispatch_get_main_queue(),^(int t){[weak hostWindow];});
    return YES;
}
- (void)rotate:(UIInterfaceOrientation)o{
    if(o==UIInterfaceOrientationUnknown)return;
    CGRect screen=UIScreen.mainScreen.bounds;CGFloat w=MIN(screen.size.width,screen.size.height),h=MAX(screen.size.width,screen.size.height);
    self.window.transform=CGAffineTransformIdentity;
    self.window.bounds=CGRectMake(0,0,UIInterfaceOrientationIsLandscape(o)?h:w,UIInterfaceOrientationIsLandscape(o)?w:h);
    self.window.center=CGPointMake(CGRectGetMidX(screen),CGRectGetMidY(screen));
    CGFloat angle=o==UIInterfaceOrientationLandscapeLeft?-M_PI_2:o==UIInterfaceOrientationLandscapeRight?M_PI_2:o==UIInterfaceOrientationPortraitUpsideDown?M_PI:0;
    self.window.transform=CGAffineTransformMakeRotation(angle);self.window.rootViewController.view.frame=self.window.bounds;HUDOverlay.frame=self.window.bounds;[HUDOverlay setNeedsLayout];
}
- (void)hostWindow{
    Class host=NSClassFromString(@"SBSAccessibilityWindowHostingController");self.hosting=host?[host new]:nil;
    SEL selector=NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
    if(![self.hosting respondsToSelector:selector]){WriteStatus(@"iOS không hỗ trợ cửa sổ nổi");_exit(2);}
    unsigned int context=[self.window _contextId];double level=self.window.windowLevel;
    if(!context){[self.window layoutIfNeeded];context=[self.window _contextId];}
    if(!context){WriteStatus(@"Không tạo được cửa sổ nổi");_exit(2);}
    NSMethodSignature *signature=[self.hosting methodSignatureForSelector:selector];
    if(!signature||signature.numberOfArguments!=4){WriteStatus(@"Cửa sổ nổi chưa tương thích");_exit(2);}
    NSInvocation *call=[NSInvocation invocationWithMethodSignature:signature];call.target=self.hosting;call.selector=selector;[call setArgument:&context atIndex:2];[call setArgument:&level atIndex:3];[call invoke];WriteStatus(@"Menu đã bật — mở Liên Quân");
}
@end
static void HIDCallback(void *target,void *ref,void *service,void *event){
    @autoreleasepool{
        Class cls=NSClassFromString(@"AXEventRepresentation");
        if(!cls||![cls respondsToSelector:@selector(representationWithHIDEvent:hidStreamIdentifier:)])return;
        id rep=[cls representationWithHIDEvent:event hidStreamIdentifier:@"UIApplicationEvents"];
        id path=[[[rep handInfo] paths] firstObject];if(!path)return;
        UITouchPhase phase;
        if([rep isTouchDown])phase=UITouchPhaseBegan;else if([rep isMove])phase=UITouchPhaseMoved;else if([rep isCancel])phase=UITouchPhaseCancelled;else if([rep isLift]||[rep isInRange]||[rep isInRangeLift])phase=UITouchPhaseEnded;else return;
        CGPoint location=[rep location];NSInteger identity=[path pathIdentity];
        dispatch_async(dispatch_get_main_queue(),^{[HUDOverlay handleScreenPoint:location phase:phase identity:identity];});
    }
}
@interface AOVLauncherController : UIViewController
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *start;
@property(nonatomic,assign) BOOL launching;
@end
@implementation AOVLauncherController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];
    UIStackView *stack=[[UIStackView alloc] init];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=18;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:stack];
    UILabel *title=[UILabel new];title.text=@"AOV";title.font=[UIFont systemFontOfSize:44 weight:UIFontWeightBold];title.textColor=[UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];title.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:title];
    UILabel *subtitle=[UILabel new];subtitle.text=@"ESP địch · ESP bùa xanh";subtitle.font=[UIFont systemFontOfSize:17 weight:UIFontWeightMedium];subtitle.textColor=UIColor.whiteColor;subtitle.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:subtitle];
    self.start=[UIButton buttonWithType:UIButtonTypeSystem];[self.start setTitle:@"Bật menu nổi" forState:UIControlStateNormal];self.start.backgroundColor=[UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];[self.start setTitleColor:UIColor.blackColor forState:UIControlStateNormal];self.start.titleLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];self.start.layer.cornerRadius=16;[self.start.heightAnchor constraintEqualToConstant:56].active=YES;[self.start addTarget:self action:@selector(launch) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.start];
    UIButton *stop=[UIButton buttonWithType:UIButtonTypeSystem];[stop setTitle:@"Tắt menu" forState:UIControlStateNormal];stop.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];[stop addTarget:self action:@selector(stopHUD) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:stop];
    self.status=[UILabel new];self.status.text=@"Liên Quân VN · 1.64.1.7";self.status.numberOfLines=3;self.status.textAlignment=NSTextAlignmentCenter;self.status.textColor=[UIColor colorWithWhite:.65 alpha:1];self.status.font=[UIFont systemFontOfSize:13];[stack addArrangedSubview:self.status];
    UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];credit.textColor=[UIColor colorWithWhite:.4 alpha:1];credit.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:credit];
    [NSLayoutConstraint activateConstraints:@[[stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[stack.widthAnchor constraintEqualToConstant:280]]];
}
- (void)stopHUD{notify_post(StopNotification);self.status.text=@"Đã tắt menu";}
- (void)launch{
    if(self.launching)return;self.launching=YES;self.start.enabled=NO;self.status.text=@"Đang mở menu…";
    // Stop our previous HUD, then spawn a fresh copy with isolated settings.
    notify_post(StopNotification);__weak AOVLauncherController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *executable=NSBundle.mainBundle.executablePath;posix_spawnattr_t attr;posix_spawnattr_init(&attr);
        int error=posix_spawnattr_set_persona_np(&attr,99,1);
        if(!error)error=posix_spawnattr_set_persona_uid_np(&attr,0);
        if(!error)error=posix_spawnattr_set_persona_gid_np(&attr,0);
        posix_spawnattr_setpgroup(&attr,0);posix_spawnattr_setflags(&attr,POSIX_SPAWN_SETPGROUP);
        pid_t pid=0;const char *args[]={executable.fileSystemRepresentation,"-hud",nullptr};
        WriteStatus(@"Đang mở menu…");
        if(!error)error=posix_spawn(&pid,args[0],nullptr,&attr,const_cast<char **>(args),environ);posix_spawnattr_destroy(&attr);
        if(!error)dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{int status;while(waitpid(pid,&status,0)<0&&errno==EINTR){};});
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{AOVLauncherController *s=weak;if(!s)return;s.launching=NO;s.start.enabled=YES;s.status.text=error?[NSString stringWithFormat:@"Không mở được HUD (%d)",error]:([NSString stringWithContentsOfFile:StatusPath encoding:NSUTF8StringEncoding error:nil]?:@"Chưa nhận được trạng thái HUD");});
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
    for(const char *path:{"/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices","/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices","/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices","/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities","/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices"})dlopen(path,RTLD_LAZY|RTLD_GLOBAL);
    auto gs=(void(*)())dlsym(RTLD_DEFAULT,"GSInitialize"),bks=(void(*)())dlsym(RTLD_DEFAULT,"BKSDisplayServicesStart"),init=(void(*)())dlsym(RTLD_DEFAULT,"UIApplicationInitialize");
    auto singleton=(void(*)(id))dlsym(RTLD_DEFAULT,"UIApplicationInstantiateSingleton");
    auto callback=(void *(*)(void(*)(void *,void *,void *,void *)))dlsym(RTLD_DEFAULT,"BKSHIDEventRegisterEventCallback");
    if(!gs||!bks||!init||!singleton||!callback||![UIWindow instancesRespondToSelector:@selector(_initWithFrame:attached:)]){WriteStatus(@"iOS không hỗ trợ khởi chạy HUD");return 2;}
    [UIScreen class];CFRunLoopGetCurrent();gs();bks();init();singleton(AOVHUDApplication.class);
    UIApplication *app=UIApplication.sharedApplication;static AOVHUDDelegate *delegate=[AOVHUDDelegate new];app.delegate=delegate;
    if([app respondsToSelector:@selector(_accessibilityInit)])[app _accessibilityInit];
    callback(HIDCallback);
    auto eventInit=(void(*)(Boolean))dlsym(RTLD_DEFAULT,"GSEventInitialize");auto mode=(void(*)(CFStringRef))dlsym(RTLD_DEFAULT,"GSEventPushRunLoopMode");if(eventInit)eventInit(false);if(mode)mode(kCFRunLoopDefaultMode);
    if(![app respondsToSelector:@selector(__completeAndRunAsPlugin)]){WriteStatus(@"UIKit chưa hỗ trợ HUD");return 2;}
    [app __completeAndRunAsPlugin];CFRunLoopRun();return 0;
}
int main(int argc,char **argv){@autoreleasepool{if(argc>1&&!strcmp(argv[1],"-hud"))return RunHUD();return UIApplicationMain(argc,argv,nil,NSStringFromClass(AOVLauncherDelegate.class));}}
