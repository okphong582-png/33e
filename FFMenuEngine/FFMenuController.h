#import <UIKit/UIKit.h>
#import "LaraESPOverlayWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFMenuController : UIViewController

@property (nonatomic, strong) LaraESPOverlayWindow *overlayWindow;

+ (instancetype)sharedMenu;
- (void)showMenu;
- (void)hideMenu;
- (void)toggleMenu;

@end

NS_ASSUME_NONNULL_END
