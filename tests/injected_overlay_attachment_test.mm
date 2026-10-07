#import "../sources/InjectedOverlayAttachment.h"
#include <cassert>

static bool failViewInsertion, failAppearance;
static unsigned appearanceBegins, appearanceEnds, completedMoves;
@implementation UIView
- (void)addSubview:(UIView *)view {
    if(failViewInsertion) [NSException raise:@"InsertionFailure" format:@"test"];
    view.superview=self;view.window=self.window;
}
- (void)removeFromSuperview { self.superview=nil;self.window=nil; }
@end
@implementation UIWindow @end
@implementation UIViewController
- (void)addChildViewController:(UIViewController *)child { child.parentViewController=self; }
- (void)removeFromParentViewController { self.parentViewController=nil; }
- (void)willMoveToParentViewController:(UIViewController *)parent {}
- (void)didMoveToParentViewController:(UIViewController *)parent { if(parent) ++completedMoves; }
- (void)beginAppearanceTransition:(BOOL)appearing animated:(BOOL)animated { ++appearanceBegins; }
- (void)endAppearanceTransition {
    ++appearanceEnds;
    if(failAppearance) [NSException raise:@"AppearanceFailure" format:@"test"];
}
@end

static UIViewController *controller() {
    UIViewController *value=[UIViewController new];value.view=[UIView new];return value;
}
int main() {
    @autoreleasepool {
        UIWindow *window=[UIWindow new];window.keyWindow=YES;
        UIViewController *host=controller();window.rootViewController=host;
        host.view.bounds=CGRectMake(0,0,812,375);host.view.window=window;
        UIViewController *root=controller();UIView *container=[UIView new];
        container.bounds=host.view.bounds;
        assert(!MizzeAttachChildOverlay(nil,container,root));
        assert(!MizzeAttachChildOverlay(host,container,host));
        assert(!MizzeAttachChildOverlay(controller(),container,root));
        assert(MizzeAttachChildOverlay(host,container,root));
        assert(root.parentViewController==host && root.view.superview==container);
        assert(container.superview==host.view && container.window==window);
        assert(CGRectEqualToRect(container.frame,host.view.bounds));
        assert(CGRectEqualToRect(root.view.frame,container.bounds));
        assert(window.rootViewController==host && window.isKeyWindow);
        assert(appearanceBegins==1 && appearanceEnds==1 && completedMoves==1);
        assert(!MizzeAttachChildOverlay(host,container,root)); // Cannot double-parent.

        UIViewController *failed=controller();UIView *failedContainer=[UIView new];
        failViewInsertion=true;
        assert(!MizzeAttachChildOverlay(host,failedContainer,failed));
        assert(!failed.parentViewController && !failedContainer.superview && !failed.view.superview);
        assert(appearanceBegins==2 && appearanceEnds==2);
        failViewInsertion=false;
        assert(MizzeAttachChildOverlay(host,failedContainer,failed)); // Retry is safe.

        failAppearance=true;
        UIViewController *callbackFailure=controller();UIView *other=[UIView new];
        assert(!MizzeAttachChildOverlay(host,other,callbackFailure));
        assert(!callbackFailure.parentViewController && !other.superview && !callbackFailure.view.superview);
        assert(window.rootViewController==host && window.isKeyWindow);
        puts("Host focus, child containment, retry and lifecycle exception cleanup: passed");
    }
}
