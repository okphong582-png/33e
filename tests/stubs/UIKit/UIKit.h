// Minimal UIKit types for testing the actual window selection on macOS.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, UIApplicationState) {
    UIApplicationStateActive, UIApplicationStateInactive, UIApplicationStateBackground
};

typedef CGFloat UIWindowLevel;
static const UIWindowLevel UIWindowLevelNormal = 0;
typedef NS_ENUM(NSInteger, UISceneActivationState) {
    UISceneActivationStateForegroundActive,
    UISceneActivationStateForegroundInactive,
    UISceneActivationStateBackground,
};

@class UIWindow;
typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
    UIViewAutoresizingFlexibleWidth=1 << 1, UIViewAutoresizingFlexibleHeight=1 << 4
};
@interface UIView : NSObject
@property(nonatomic) CGRect frame;
@property(nonatomic) CGRect bounds;
@property(nonatomic) UIViewAutoresizing autoresizingMask;
@property(nonatomic, weak) UIView *superview;
@property(nonatomic, weak) UIWindow *window;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
@end
@interface UIViewController : NSObject
@property(nonatomic, strong) UIView *view;
@property(nonatomic, weak) UIViewController *parentViewController;
- (void)addChildViewController:(UIViewController *)child;
- (void)removeFromParentViewController;
- (void)willMoveToParentViewController:(UIViewController *)parent;
- (void)didMoveToParentViewController:(UIViewController *)parent;
- (void)beginAppearanceTransition:(BOOL)appearing animated:(BOOL)animated;
- (void)endAppearanceTransition;
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
+ (instancetype)sharedApplication;
@property(nonatomic) UIApplicationState applicationState;
@property(nonatomic, copy) NSSet<UIScene *> *connectedScenes;
@property(nonatomic, copy) NSArray<UIWindow *> *windows;
@end
