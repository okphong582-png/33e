#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "../esp/Core/PlayerModes.h"
#include <mach/mach.h>
extern mach_port_t get_task;
extern uint64_t AimlagModule();

@interface AimlagWindow : UIWindow
@end
@implementation AimlagWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    return (hit==self||hit==self.rootViewController.view)?nil:hit;
}
@end
@interface AimlagController : UIViewController
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) UILabel *caption;
@property(nonatomic,strong) CADisplayLink *displayLink;
@property(nonatomic,assign) BOOL aimlag;
@property(nonatomic,assign) BOOL fakelag;
@end
@implementation AimlagController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
    self.aimlag=[NSUserDefaults.standardUserDefaults boolForKey:@"AimlagMini.AimLag"];
    self.fakelag=[NSUserDefaults.standardUserDefaults boolForKey:@"AimlagMini.FakeLag"];
    UIView *control=[[UIView alloc] initWithFrame:CGRectMake(20,100,82,88)];control.tag=1;
    UIVisualEffectView *glass=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    glass.frame=CGRectMake(13,0,56,56);glass.layer.cornerRadius=28;glass.clipsToBounds=YES;glass.userInteractionEnabled=NO;
    glass.layer.borderWidth=1;glass.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.3].CGColor;
    [control addSubview:glass];
    self.button=[UIButton buttonWithType:UIButtonTypeSystem];self.button.frame=glass.frame;
    [self.button setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
    self.button.accessibilityLabel=@"FakeLag";self.button.accessibilityHint=@"Nhấn để bật tắt; nhấn giữ để chọn Aimlag";
    [self.button addTarget:self action:@selector(toggleFake) forControlEvents:UIControlEventTouchUpInside];
    [self.button addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openMenu:)]];
    [control addSubview:self.button];
    self.caption=[[UILabel alloc] initWithFrame:CGRectMake(0,61,82,24)];self.caption.text=@"FakeLag";
    self.caption.textAlignment=NSTextAlignmentCenter;self.caption.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.caption.textColor=UIColor.whiteColor;self.caption.layer.shadowColor=UIColor.blackColor.CGColor;self.caption.layer.shadowOpacity=0.9;self.caption.layer.shadowRadius=2;
    [control addSubview:self.caption];[self.view addSubview:control];
    [control addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [self sync];
    self.displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];self.displayLink.preferredFramesPerSecond=30;
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)sync {
    [NSUserDefaults.standardUserDefaults setBool:self.aimlag forKey:@"AimlagMini.AimLag"];
    [NSUserDefaults.standardUserDefaults setBool:self.fakelag forKey:@"AimlagMini.FakeLag"];
    self.button.tintColor=self.fakelag?[UIColor colorWithRed:0.46 green:0.86 blue:0.73 alpha:1]:UIColor.whiteColor;
    self.button.accessibilityValue=self.fakelag?@"Bật":@"Tắt";
    PlayerModesSetEnabled(false,self.aimlag,self.fakelag,4);
}
- (void)toggleFake {self.fakelag=!self.fakelag;[self sync];}
- (void)openMenu:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateBegan||self.presentedViewController)return;
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"Aimlag / FakeLag" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [menu addAction:[UIAlertAction actionWithTitle:self.aimlag?@"Aimlag  [X]":@"Aimlag  [ ]" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){self.aimlag=!self.aimlag;[self sync];}]];
    [menu addAction:[UIAlertAction actionWithTitle:self.fakelag?@"FakeLag  [X]":@"FakeLag  [ ]" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self toggleFake];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    UIView *control=gesture.view;CGPoint delta=[gesture translationInView:self.view];
    CGRect frame=control.frame;frame.origin.x=MAX(0,MIN(self.view.bounds.size.width-frame.size.width,frame.origin.x+delta.x));
    frame.origin.y=MAX(self.view.safeAreaInsets.top,MIN(self.view.bounds.size.height-frame.size.height-self.view.safeAreaInsets.bottom,frame.origin.y+delta.y));
    control.frame=frame;[gesture setTranslation:CGPointZero inView:self.view];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *control=[self.view viewWithTag:1];CGRect frame=control.frame;
    frame.origin.x=MAX(0,MIN(self.view.bounds.size.width-frame.size.width,frame.origin.x));
    frame.origin.y=MAX(self.view.safeAreaInsets.top,MIN(self.view.bounds.size.height-frame.size.height-self.view.safeAreaInsets.bottom,frame.origin.y));
    control.frame=frame;
}
- (void)tick {
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive){PlayerModesCancel();return;}
    get_task=mach_task_self();PlayerModesUpdate(AimlagModule());
}
@end
static AimlagWindow *overlay;
static void StartAimlag() {
    UIApplication *app=UIApplication.sharedApplication;
    if(overlay||app.applicationState!=UIApplicationStateActive)return;
    UIWindow *game=nil;
    if(@available(iOS 13.0,*))for(UIScene *scene in app.connectedScenes)
        if([scene isKindOfClass:UIWindowScene.class]&&scene.activationState==UISceneActivationStateForegroundActive)
            for(UIWindow *window in ((UIWindowScene *)scene).windows)if(window.isKeyWindow)game=window;
    if(!game)for(UIWindow *window in app.windows)if(window.isKeyWindow)game=window;
    if(!game)return;
    overlay=game.windowScene?[[AimlagWindow alloc] initWithWindowScene:game.windowScene]:[[AimlagWindow alloc] initWithFrame:game.frame];
    overlay.frame=game.frame;overlay.backgroundColor=UIColor.clearColor;overlay.windowLevel=UIWindowLevelNormal+1;
    overlay.rootViewController=[AimlagController new];overlay.hidden=NO;
}
__attribute__((constructor)) static void AimlagEntry() {
    dispatch_async(dispatch_get_main_queue(),^{
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){StartAimlag();}];
        [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){StartAimlag();}];
        StartAimlag();
    });
}
