// Minimal UIKit types for testing the actual window selection on macOS.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef CGFloat UIWindowLevel;
static const UIWindowLevel UIWindowLevelNormal = 0;
typedef NS_ENUM(NSInteger, UISceneActivationState) {
    UISceneActivationStateForegroundActive,
    UISceneActivationStateForegroundInactive,
    UISceneActivationStateBackground,
};

@class UIWindow;
@interface UIViewController : NSObject
@end
@interface UIScene : NSObject
@property(nonatomic) UISceneActivationState activationState;
@end
@interface UIWindowScene : UIScene
@property(nonatomic, copy) NSArray<UIWindow *> *windows;
@end
@interface UIWindow : NSObject
@property(nonatomic) BOOL hidden;
@property(nonatomic) CGFloat alpha;
@property(nonatomic) CGRect bounds;
@property(nonatomic) UIWindowLevel windowLevel;
@property(nonatomic, getter=isKeyWindow) BOOL keyWindow;
@property(nonatomic, strong) UIViewController *rootViewController;
@property(nonatomic, weak) UIWindowScene *windowScene;
@end
@interface UIApplication : NSObject
@property(nonatomic, copy) NSSet<UIScene *> *connectedScenes;
@property(nonatomic, copy) NSArray<UIWindow *> *windows;
@end
