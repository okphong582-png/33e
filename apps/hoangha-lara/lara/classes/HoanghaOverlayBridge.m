#import "HoanghaOverlayBridge.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../../Standalone/HHOverlayGeometry.h"
#import <objc/runtime.h>
#import <stdlib.h>
#import <math.h>
#import <string.h>

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

// Invoke UIKit through Foundation's real call frame rather than the synthetic
// RemoteCall return address (the crash report faults at 0x401 in ARC handling).
static uint64_t HHRawSend(RemoteCall *session, uint64_t target, const char *name,
                          uint64_t a0, uint64_t a1) {
    if (!target || session.lastError.length) return 0;
    uint64_t selector = remote_sel(session, name);
    return selector ? remote_msg(session, target, selector, a0, a1, 0, 0) : 0;
}

static BOOL HHInvoke(RemoteCall *session, uint64_t target, const char *name,
                     const void *arg0, size_t size0, const void *arg1, size_t size1,
                     void *result, size_t capacity) {
    if (!target || session.lastError.length) return NO;
    uint64_t selector = remote_sel(session, name);
    uint64_t signature = HHRawSend(session, target, "methodSignatureForSelector:", selector, 0);
    if (!signature) {
        HHError([NSString stringWithFormat:@"Không tìm thấy phương thức %s.", name]);
        return NO;
    }
    uint64_t count = HHRawSend(session, signature, "numberOfArguments", 0, 0);
    uint64_t length = HHRawSend(session, signature, "methodReturnLength", 0, 0);
    if (count > 4 || length > capacity || size0 > 64 || size1 > 64) {
        HHError(@"Kiểu dữ liệu lời gọi UIKit chưa được hỗ trợ.");
        return NO;
    }
    uint64_t invocation = HHRawSend(session, remote_getClass(session, "NSInvocation"),
                                    "invocationWithMethodSignature:", signature, 0);
    uint64_t scratch = invocation ? RemoteArbCall(session, calloc, 1, 256) : 0;
    if (!scratch) return NO;
    BOOL okay = YES;
    HHRawSend(session, invocation, "setTarget:", target, 0);
    HHRawSend(session, invocation, "setSelector:", selector, 0);
    if (count > 2) {
        okay = arg0 && [session remote_write:scratch + 64 from:arg0 size:size0];
        if (okay) HHRawSend(session, invocation, "setArgument:atIndex:", scratch + 64, 2);
    }
    if (okay && count > 3) {
        okay = arg1 && [session remote_write:scratch + 128 from:arg1 size:size1];
        if (okay) HHRawSend(session, invocation, "setArgument:atIndex:", scratch + 128, 3);
    }
    if (okay && !session.lastError.length) {
        HHRawSend(session, invocation, "retainArguments", 0, 0);
        uint64_t perform = remote_sel(session, "performSelectorOnMainThread:withObject:waitUntilDone:");
        uint64_t invoke = remote_sel(session, "invoke");
        remote_msg(session, invocation, perform, invoke, 0, 1, 0);
        if (length && !session.lastError.length) {
            HHRawSend(session, invocation, "getReturnValue:", scratch, 0);
            okay = [session remoteRead:scratch to:result size:length];
        }
    }
    if (!session.lastError.length) RemoteArbCall(session, free, scratch);
    return okay && !session.lastError.length;
}

static uint64_t HHSend(RemoteCall *session, uint64_t target, const char *name,
                       uint64_t a0, uint64_t a1) {
    uint64_t result = 0;
    HHInvoke(session, target, name, &a0, sizeof(a0), &a1, sizeof(a1), &result, sizeof(result));
    return result;
}

static CGRect HHGetRect(RemoteCall *session, uint64_t target, const char *name) {
    CGRect result = CGRectZero;
    HHInvoke(session, target, name, NULL, 0, NULL, 0, &result, sizeof(result));
    return result;
}

static void HHSetRect(RemoteCall *session, uint64_t target, CGRect rect) {
    HHInvoke(session, target, "setFrame:", &rect, sizeof(rect), NULL, 0, NULL, 0);
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

static uint64_t HHFont(RemoteCall *session, CGFloat pointSize) {
    uint64_t font = 0;
    HHInvoke(session, remote_getClass(session, "UIFont"), "boldSystemFontOfSize:",
             &pointSize, sizeof(pointSize), NULL, 0, &font, sizeof(font));
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
        BOOL (^operation)(void) = ^BOOL {
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
            CGRect bounds = HHGetRect(session, screen, "bounds");
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
                HHSetRect(session, window, bounds);
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
                    HHSetRect(session, rootView, bounds);
                    HHSetRect(session, label, bounds);
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
        };
        BOOL success = operation();
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
        BOOL (^operation)(void) = ^BOOL {
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
        };
        BOOL success = operation();
        if (!success) HHError(session.lastError ?: @"SpringBoard chưa ẩn được chữ.");
        return success && session.lastError.length == 0;
    }
}

#include "HoanghaFloatingBridge.inc"
