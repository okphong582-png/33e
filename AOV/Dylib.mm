#import "ui/Overlay.h"
#import <objc/runtime.h>
static AOVOverlay *overlay;
static UIWindow *gameWindow(){
    NSMutableArray<UIWindow *> *windows=[NSMutableArray array];
    if(@available(iOS 13,*))for(UIScene *s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class]&&s.activationState==UISceneActivationStateForegroundActive)[windows addObjectsFromArray:((UIWindowScene *)s).windows];
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
    UIWindow *best=nil;
    for(UIWindow *w in windows)if(!w.hidden&&w.alpha>.01&&w.rootViewController&&w.windowLevel==UIWindowLevelNormal){if(w.isKeyWindow)return w;best=w;}
    return best;
}
__attribute__((constructor))static void AOVStart(){
    dispatch_async(dispatch_get_main_queue(),^{
        static NSTimer *timer;
        timer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){
            if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
            UIWindow *w=gameWindow();if(!w)return;
            if(!overlay)overlay=[[AOVOverlay alloc] initWithFrame:w.bounds];
            if(overlay.superview!=w){[overlay removeFromSuperview];overlay.frame=w.bounds;[w addSubview:overlay];}
            overlay.hidden=NO;overlay.alpha=1;[w bringSubviewToFront:overlay];
        }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
