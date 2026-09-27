// ============================================================
// _0xHAPP827.mm
// main() entry point
// BẢN ĐÃ XÓA AUTH SERVER (UUID check, performRuntimeCheck)
// GIỮ LẠI: FishHook restore, AntiHook, ProxyCheck, HUD spawn
// ============================================================

#import <notify.h>
#import "rootless.h"
#import <mach-o/dyld.h>
#import <sys/utsname.h>
#import <objc/runtime.h>
#import <mach-o/loader.h>
#import <mach-o/arch.h>
#include <uuid/uuid.h>
#include <string.h>
#include "KabraxHide.h"

#import "HUDHelper.h"
#import "HUDMainApplicationDelegate.h"
#import "TSEventFetcher.h"
#import "BackboardServices.h"
#import "AXEventRepresentation.h"
#import "UIApplication+Private.h"
#import "FishHookChecker.h"
#import "AntiHook.h"
#import "ProxyChecker.h"
#import "mahoa.h"
#import <dlfcn.h>

// ============================================================
// MACRO JUNK CODE (giữ nguyên để tránh bị reverse)
// ============================================================
#define _JUNK1() do { for (int _i=0; _i<10; _i++) { _i = _i; } } while(0)
#define _JUNK2(x) do { if ((x) == 0) { (void)(x); } } while(0)
#define _JUNK3() do { @try { } @catch(id e) { } } while(0)
#define _JUNK4() do { usleep(0); } while(0)
#define _JUNK5(x) do { volatile long _tmp = (long)(x); _tmp = _tmp + 1; } while(0)

// ============================================================
// EXTERN: Touch callback từ HUD
// ============================================================
extern BOOL HUDFloatButtonHandleTouch(CGPoint screenPoint, UITouchPhase phase, NSInteger pointerId);

// ============================================================
// LẤY MODEL THIẾT BỊ
// ============================================================
NSString *mDeviceModel(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

// ============================================================
// [REMOVED] _0x7C3A - Lấy UUID từ Mach-O
// [REMOVED] _0xB1F4 - Lấy UUID app
// [REMOVED] performRuntimeCheck - Check UUID với server
// [REMOVED] _0x2873DAH - Timer check server
// ============================================================

// ============================================================
// HUD EVENT CALLBACK - Xử lý touch từ hệ thống
// ============================================================
void _HUDEventCallback(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    @autoreleasepool {
    static UIApplication *app = [UIApplication sharedApplication];

    if (@available(iOS 15.1, *)) {}
    else {
        [app _enqueueHIDEvent:event];
    }

    BOOL shouldUseAXEvent = YES;

    BOOL isExactly15 = NO;
    static NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 15 && version.minorVersion == 0 && version.patchVersion == 0) {
        NSString *deviceModel = mDeviceModel();
        if (![deviceModel hasPrefix:@"iPhone13,"] && ![deviceModel hasPrefix:@"iPhone14,"]) {
            isExactly15 = YES;
        }
    }

    if (@available(iOS 15.0, *)) {
        shouldUseAXEvent = !isExactly15;
    } else {
        shouldUseAXEvent = NO;
    }

    if (shouldUseAXEvent)
    {
        static Class AXEventRepresentationCls = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/AccessibilityUtilities.framework"] load];
            AXEventRepresentationCls = objc_getClass("AXEventRepresentation");
        });

        AXEventRepresentation *rep = [AXEventRepresentationCls
            representationWithHIDEvent:event
            hidStreamIdentifier:@"UIApplicationEvents"];
        if (!rep || ![[[rep handInfo] paths] count]) return;

        {
            void (^handleTouch)(void) = ^(void) {
                @autoreleasepool {
                // The HUD window is created after online verification completes.
                UIWindow *keyWindow = [[app windows] firstObject];
                if (!keyWindow) return;

                UITouchPhase phase;
                if ([rep isTouchDown])
                    phase = UITouchPhaseBegan;
                else if ([rep isMove])
                    phase = UITouchPhaseMoved;
                else if ([rep isCancel])
                    phase = UITouchPhaseCancelled;
                else if ([rep isLift] || [rep isInRange] || [rep isInRangeLift])
                    phase = UITouchPhaseEnded;
                else return;

                NSInteger pointerId = [[[[rep handInfo] paths] firstObject] pathIdentity];
                CGPoint loc = [rep location];

                // The menu handles its own controls. Unconsumed events belong
                // to the foreground app, which already receives the original
                // HID event. Synthesizing them in the HUD instead generated
                // private UIKit touches for every game movement/fire gesture.
                HUDFloatButtonHandleTouch(loc, phase, pointerId);
                }
            };

            if ([NSThread isMainThread]) {
                handleTouch();
            } else {
                dispatch_async(dispatch_get_main_queue(), handleTouch);
            }
        }
    }
    }
}

// ============================================================
// MAIN
// ============================================================
int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        // ====================================================
        // ✅ BƯỚC 1: RESTORE SYMBOL GỐC (FISHHOOK CHECKER)
        // ====================================================
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("dlsym")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("open")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("fopen")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("access")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("stat")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("statfs")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("objc_msgSend")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("_dyld_image_count")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("_dyld_get_image_name")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("_dyld_get_image_header")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("_dyld_get_image_vmaddr_slide")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("dladdr")];
        [_0x2828DAB _0x2828DAA:NSSENCRYPT("proc_regionfilename")];

        // ====================================================
        // [REMOVED] BƯỚC 2: SERVER CHECK TIMER - ĐÃ XÓA
        // ====================================================
        // _0x2873DAH();

        // ====================================================
        // ✅ BƯỚC 3: ANTIHOOK CHECK (KHÔNG EXIT)
        // ====================================================
        [AntiHook runDefaultChecksWithCallback:^(NSString *functionName) {
            // [MODIFIED] Không exit nữa, chỉ log
            NSLog(@"[AntiHook] ⚠️ Phát hiện hook trên hàm: %@", functionName);

            void *funcAddr = dlsym(RTLD_DEFAULT, functionName.UTF8String);
            void *orig = [AntiHook originalImplementationForFunction:funcAddr];
            if (orig) {
                NSLog(@"[AntiHook]   -> Đã khôi phục địa chỉ gốc tại %p", orig);
            }

            // [REMOVED] exit(0);
        }];

        // ====================================================
        // ✅ BƯỚC 4: PROXY CHECK (KHÔNG EXIT)
        // ====================================================
        if ([_0xPO34326 _0x4544DAN:YES]) {
            // [MODIFIED] Không exit nữa, chỉ log
            NSLog(@"[ProxyChecker] ⚠️ VPN/Proxy detected");
            // [REMOVED] exit(0);
        }

        // ====================================================
        // [REMOVED] BƯỚC 5: UUID CHECK - ĐÃ XÓA HOÀN TOÀN
        // ====================================================
        // _JUNK1();
        // NSString *_0x1A4F = _0xB1F4();
        // if (!_0x1A4F) { exit(0); }
        // NSURL *_0x2827 = [KH_CLS("NSURL") URLWithString:...];
        // ... (toàn bộ block UUID check)
        // [REMOVED]

        _JUNK1();

        // ====================================================
        // ✅ BƯỚC 6: APP ENTRY LOGIC
        // ====================================================
        if (argc <= 1) {
            // Chạy app chính (không phải HUD)
            return UIApplicationMain(argc, argv, @"MainApplication", @"MainApplicationDelegate");
        }

        if (strcmp(argv[1], "-hud") == 0)
        {
            // ================================================
            // CHẠY HUD PROCESS
            // ================================================
            if (argc > 2 && argv[2] && strlen(argv[2]) == 64) {
                NSString *licenseHash = [NSString stringWithUTF8String:argv[2]];
                if (licenseHash.length == 64) {
                    [[NSUserDefaults standardUserDefaults] setObject:licenseHash forKey:@"LicenseHash"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
            HUDMarkStarting();

            [UIScreen initialize];
            CFRunLoopGetCurrent();

            GSInitialize();
            BKSDisplayServicesStart();
            UIApplicationInitialize();

            UIApplicationInstantiateSingleton(objc_getClass("HUDMainApplication"));
            static id<UIApplicationDelegate> appDelegate = [[objc_getClass("HUDMainApplicationDelegate") alloc] init];
            [UIApplication.sharedApplication setDelegate:appDelegate];
            [UIApplication.sharedApplication _accessibilityInit];

            [NSRunLoop currentRunLoop];
            BKSHIDEventRegisterEventCallback(_HUDEventCallback);

            if (@available(iOS 15.0, *)) {
                GSEventInitialize(0);
                GSEventPushRunLoopMode(kCFRunLoopDefaultMode);
            }

            [UIApplication.sharedApplication __completeAndRunAsPlugin];

            static int _springboardBootToken;
            notify_register_dispatch("SBSpringBoardDidLaunchNotification",
                                     &_springboardBootToken,
                                     dispatch_get_main_queue(),
                                     ^(int token) {
                (void)token;
                [(HUDMainApplicationDelegate *)appDelegate restoreWindowHosting];
            });

            CFRunLoopRun();
            return EXIT_SUCCESS;
        }
    }
}
