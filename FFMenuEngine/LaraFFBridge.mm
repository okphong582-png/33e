#import "LaraFFBridge.h"
#import "LaraMemoryReader.h"
#import "LaraESPOverlayWindow.h"
#import "FFMenuController.h"

@implementation LaraFFBridge

+ (instancetype)sharedBridge {
    static LaraFFBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LaraFFBridge alloc] init];
    });
    return instance;
}

- (void)startFFEngine {
    NSLog(@"[LaraFFBridge] Starting Lara FF Engine...");
    
    // 1. Initialize DarkSword Kernel Exploit
    BOOL kReady = [[LaraMemoryReader sharedInstance] initializeKernelExploit];
    if (kReady) {
        NSLog(@"[LaraFFBridge] Exploit ready. Starting ESP Overlay Window...");
        
        // 2. Start ESP Overlay Window CADisplayLink Loop
        dispatch_async(dispatch_get_main_queue(), ^{
            LaraESPOverlayWindow *overlay = [LaraESPOverlayWindow sharedOverlay];
            [overlay startOverlayLoop];
            
            // 3. Attach Menu Controller
            FFMenuController *menu = [FFMenuController sharedMenu];
            menu.overlayWindow = overlay;
            UIViewController *root = overlay.rootViewController;
            if (menu.parentViewController != root) {
                [root addChildViewController:menu];
                menu.view.frame = root.view.bounds;
                menu.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [root.view addSubview:menu.view];
                [menu didMoveToParentViewController:root];
            }
            [overlay setMenuContainer:menu.view];
            [menu showMenu];
        });
    } else {
        NSLog(@"[LaraFFBridge] Exploit initialization deferred or failed.");
    }
}

- (void)toggleMenuOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FFMenuController sharedMenu] toggleMenu];
    });
}

- (BOOL)isExploitReady {
    return [LaraMemoryReader sharedInstance].isKernelReady;
}

@end
