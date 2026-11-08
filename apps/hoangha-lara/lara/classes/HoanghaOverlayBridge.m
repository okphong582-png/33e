#import "HoanghaOverlayBridge.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <math.h>

static NSString *HHLastError = @"";
static const NSInteger HHLabelTag = 0x484F414E;

NSString *hoangha_overlay_last_error(void) {
    @synchronized ([RemoteCall class]) {
        return HHLastError;
    }
}

static void HHError(NSString *message) {
    @synchronized ([RemoteCall class]) {
        HHLastError = message ?: @"";
    }
}

static uint64_t HHSend(RemoteCall *session, uint64_t target, const char *name,
                       uint64_t a0, uint64_t a1) {
    if (!target) return 0;
    uint64_t selector = remote_sel(session, name);
    if (!selector) return 0;
    return remote_msg(session, target, selector, a0, a1, 0, 0);
}

static uint64_t HHNumber(RemoteCall *session, int value) {
    return HHSend(session, remote_getClass(session, "NSNumber"),
                  "numberWithInt:", (uint64_t)value, 0);
}

static void HHSetNumber(RemoteCall *session, uint64_t object, const char *key, int value) {
    uint64_t number = HHNumber(session, value);
    uint64_t name = remote_NSString(session, key);
    if (number && name) HHSend(session, object, "setValue:forKey:", number, name);
}

/// NSInvocation marshals CGFloat correctly; RemoteCall's ordinary arguments are integers.
static uint64_t HHFont(RemoteCall *session, CGFloat pointSize) {
    uint64_t cls = remote_getClass(session, "UIFont");
    uint64_t selector = remote_sel(session, "boldSystemFontOfSize:");
    uint64_t signature = HHSend(session, cls, "methodSignatureForSelector:", selector, 0);
    uint64_t invocation = HHSend(session, remote_getClass(session, "NSInvocation"),
                                 "invocationWithMethodSignature:", signature, 0);
    if (!signature || !invocation) return 0;
    uint64_t scratch = RemoteArbCall(session, malloc, sizeof(uint64_t));
    if (!scratch) return 0;
    uint64_t font = 0;
    if ([session remote_write:scratch from:&pointSize size:sizeof(pointSize)]) {
        HHSend(session, invocation, "setTarget:", cls, 0);
        HHSend(session, invocation, "setSelector:", selector, 0);
        HHSend(session, invocation, "setArgument:atIndex:", scratch, 2);
        HHSend(session, invocation, "invoke", 0, 0);
        HHSend(session, invocation, "getReturnValue:", scratch, 0);
        [session remoteRead:scratch to:&font size:sizeof(font)];
    }
    RemoteArbCall(session, free, scratch);
    return font;
}

static uint64_t HHApplication(RemoteCall *session) {
    return HHSend(session, remote_getClass(session, "UIApplication"),
                  "sharedApplication", 0, 0);
}

static uint64_t HHAssociationKey(RemoteCall *session) {
    // A registered selector is stable for the lifetime of SpringBoard, even across app sessions.
    return remote_sel(session, "laraHoanghaCenteredOverlayWindow_v1");
}

static uint64_t HHExistingWindow(RemoteCall *session, uint64_t app, uint64_t key) {
    if (!app || !key) return 0;
    return RemoteArbCall(session, objc_getAssociatedObject, app, key);
}

static uint64_t HHWindowScene(RemoteCall *session, uint64_t app) {
    uint64_t source = HHSend(session, app, "keyWindow", 0, 0);
    uint64_t scene = HHSend(session, source, "windowScene", 0, 0);
    if (scene) return scene;

    uint64_t windows = HHSend(session, app, "windows", 0, 0);
    uint64_t count = HHSend(session, windows, "count", 0, 0);
    for (uint64_t i = 0; i < MIN(count, 64); i++) {
        source = HHSend(session, windows, "objectAtIndex:", i, 0);
        scene = HHSend(session, source, "windowScene", 0, 0);
        if (scene) return scene;
    }

    uint64_t workspace = HHSend(session, remote_getClass(session, "SBMainWorkspace"),
                                "sharedInstance", 0, 0);
    if (workspace) {
        uint64_t responds = remote_sel(session, "mainWindowScene");
        if (HHSend(session, workspace, "respondsToSelector:", responds, 0)) {
            scene = HHSend(session, workspace, "mainWindowScene", 0, 0);
        }
    }
    return scene;
}

bool hoangha_overlay_show(RemoteCall *session) {
    if (!session) {
        HHError(@"Chưa có phiên SpringBoard.");
        return false;
    }
    @synchronized (session) {
        HHError(@"");
        session.lastError = nil;
        BOOL success = [session doRemoteCallSyncOnMainThread:^BOOL {
            uint64_t app = HHApplication(session);
            uint64_t key = HHAssociationKey(session);
            if (!app || !key) {
                HHError(@"Không tìm thấy UIApplication của SpringBoard.");
                return NO;
            }
            uint64_t window = HHExistingWindow(session, app, key);
            if (window) {
                HHSend(session, window, "setHidden:", 0, 0);
                return HHSend(session, window, "isHidden", 0, 0) == 0;
            }

            uint64_t scene = HHWindowScene(session, app);
            uint64_t windowClass = remote_getClass(session, "UIWindow");
            uint64_t controllerClass = remote_getClass(session, "UIViewController");
            uint64_t labelClass = remote_getClass(session, "UILabel");
            uint64_t screen = HHSend(session, remote_getClass(session, "UIScreen"),
                                     "mainScreen", 0, 0);
            if (!scene || !windowClass || !controllerClass || !labelClass || !screen) {
                HHError(@"Không tìm thấy UIWindowScene của SpringBoard.");
                return NO;
            }
            CGRect bounds = remote_getCGRect(session, screen, remote_sel(session, "bounds"));
            if (!isfinite(bounds.size.width) || !isfinite(bounds.size.height) ||
                bounds.size.width < 100 || bounds.size.height < 100 ||
                bounds.size.width > 10000 || bounds.size.height > 10000) {
                HHError(@"Không đọc được kích thước màn hình.");
                return NO;
            }
            bounds.origin = CGPointZero;
            window = HHSend(session, windowClass, "alloc", 0, 0);
            window = HHSend(session, window, "initWithWindowScene:", scene, 0);
            uint64_t controller = HHSend(session, controllerClass, "new", 0, 0);
            uint64_t label = HHSend(session, labelClass, "new", 0, 0);
            BOOL attached = NO;
            if (window && controller && label) {
                remote_setCGRect(session, window, remote_sel(session, "setFrame:"), bounds);
                HHSend(session, window, "setRootViewController:", controller, 0);
                HHSend(session, window, "setUserInteractionEnabled:", 0, 0);
                HHSetNumber(session, window, "windowLevel", 3000);
                uint64_t rootView = HHSend(session, controller, "view", 0, 0);
                uint64_t colors = remote_getClass(session, "UIColor");
                uint64_t clear = HHSend(session, colors, "clearColor", 0, 0);
                uint64_t white = HHSend(session, colors, "whiteColor", 0, 0);
                uint64_t black = HHSend(session, colors, "blackColor", 0, 0);
                uint64_t text = remote_NSString(session, "hoangha");
                CGFloat size = MIN(132.0, MAX(48.0, bounds.size.width / 4.5));
                uint64_t font = HHFont(session, size);
                if (rootView && text && font && clear && white) {
                    HHSend(session, window, "setBackgroundColor:", clear, 0);
                    HHSend(session, rootView, "setBackgroundColor:", clear, 0);
                    remote_setCGRect(session, rootView, remote_sel(session, "setFrame:"), bounds);
                    remote_setCGRect(session, label, remote_sel(session, "setFrame:"), bounds);
                    HHSend(session, label, "setAutoresizingMask:",
                           UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight, 0);
                    HHSend(session, label, "setTag:", HHLabelTag, 0);
                    HHSend(session, label, "setText:", text, 0);
                    HHSend(session, label, "setTextColor:", white, 0);
                    HHSend(session, label, "setFont:", font, 0);
                    HHSend(session, label, "setTextAlignment:", NSTextAlignmentCenter, 0);
                    HHSend(session, label, "setNumberOfLines:", 1, 0);
                    HHSend(session, label, "setAdjustsFontSizeToFitWidth:", 1, 0);
                    HHSend(session, label, "setUserInteractionEnabled:", 0, 0);
                    uint64_t layer = HHSend(session, label, "layer", 0, 0);
                    HHSend(session, layer, "setShadowColor:", HHSend(session, black, "CGColor", 0, 0), 0);
                    HHSetNumber(session, layer, "shadowOpacity", 1);
                    HHSetNumber(session, layer, "shadowRadius", 5);
                    HHSend(session, rootView, "addSubview:", label, 0);
                    RemoteArbCall(session, objc_setAssociatedObject, app, key, window,
                                  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    // Keep the current keyboard/focus: this overlay never becomes the key window.
                    HHSend(session, window, "setHidden:", 0, 0);
                    attached = HHExistingWindow(session, app, key) == window &&
                               HHSend(session, window, "isHidden", 0, 0) == 0 &&
                               HHSend(session, rootView, "viewWithTag:", HHLabelTag, 0) == label;
                    if (!attached) {
                        HHSend(session, window, "setHidden:", 1, 0);
                        RemoteArbCall(session, objc_setAssociatedObject, app, key, 0,
                                      OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                }
            }
            // The association, rootViewController and subview hierarchy own the attached objects.
            HHSend(session, label, "release", 0, 0);
            HHSend(session, controller, "release", 0, 0);
            HHSend(session, window, "release", 0, 0);
            if (!attached) HHError(@"Chưa tạo được chữ hoangha trong SpringBoard.");
            return attached;
        }];
        if (!success && hoangha_overlay_last_error().length == 0) {
            HHError(session.lastError ?: @"SpringBoard không hoàn tất yêu cầu hiển thị.");
        }
        return success && session.lastError.length == 0;
    }
}

bool hoangha_overlay_hide(RemoteCall *session) {
    if (!session) {
        HHError(@"Chưa có phiên SpringBoard để ẩn chữ.");
        return false;
    }
    @synchronized (session) {
        HHError(@"");
        session.lastError = nil;
        BOOL success = [session doRemoteCallSyncOnMainThread:^BOOL {
            uint64_t app = HHApplication(session);
            uint64_t key = HHAssociationKey(session);
            if (!app || !key) return NO;
            uint64_t window = HHExistingWindow(session, app, key);
            if (!window) return YES;
            HHSend(session, window, "setHidden:", 1, 0);
            if (HHSend(session, window, "isHidden", 0, 0) == 0) return NO;
            RemoteArbCall(session, objc_setAssociatedObject, app, key, 0,
                          OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return HHExistingWindow(session, app, key) == 0;
        }];
        if (!success) HHError(session.lastError ?: @"SpringBoard chưa ẩn được chữ.");
        return success && session.lastError.length == 0;
    }
}
