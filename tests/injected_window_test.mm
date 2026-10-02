#import "../sources/InjectedWindowSelection.h"
#include <cassert>

@implementation UIViewController @end
@implementation UIScene @end
@implementation UIWindowScene @end
@implementation UIWindow @end
@implementation UIApplication @end

static UIWindow *gameWindow() {
    UIWindow *window = [UIWindow new];
    window.alpha = 1;
    window.bounds = CGRectMake(0, 0, 640, 480);
    window.rootViewController = [UIViewController new];
    return window;
}

int main() {
    @autoreleasepool {
        UIApplication *app = [UIApplication new];
        app.connectedScenes = [NSSet set];
        app.windows = @[];
        assert(!MizzeFindGameWindow(app)); // Prelaunch: no scenes or windows.

        UIWindow *game = gameWindow();
        game.keyWindow = YES;
        app.windows = @[game];
        assert(MizzeFindGameWindow(app) == game); // Legacy Unity lifecycle.
        game.rootViewController = nil;
        assert(!MizzeFindGameWindow(app)); // Window not ready yet.
        game.rootViewController = [UIViewController new];
        game.hidden = YES;
        assert(!MizzeFindGameWindow(app));
        game.hidden = NO;
        game.bounds = CGRectZero;
        assert(!MizzeFindGameWindow(app));
        game.bounds = CGRectMake(0, 0, 640, 480);

        UIWindow *overlay = gameWindow();
        overlay.windowLevel = UIWindowLevelNormal + 1;
        overlay.keyWindow = YES;
        game.keyWindow = NO;
        app.windows = @[overlay, game];
        assert(MizzeFindGameWindow(app) == game); // Overlay cannot own itself.

        UIWindowScene *background = [UIWindowScene new];
        background.activationState = UISceneActivationStateBackground;
        UIWindow *otherGame = gameWindow();
        otherGame.keyWindow = YES;
        otherGame.windowScene = background;
        background.windows = @[otherGame];
        app.connectedScenes = [NSSet setWithObject:background];
        app.windows = @[otherGame];
        assert(!MizzeFindGameWindow(app));

        UIWindowScene *active = [UIWindowScene new];
        active.activationState = UISceneActivationStateForegroundActive;
        game.windowScene = active;
        active.windows = @[overlay, game];
        app.connectedScenes = [NSSet setWithObjects:active, background, nil];
        assert(MizzeFindGameWindow(app) == game); // Modern scene lifecycle.
        active.windows = @[];
        assert(!MizzeFindGameWindow(app)); // Active scene with no windows.
        puts("Prelaunch, legacy Unity, active and background scenes: passed");
    }
}
