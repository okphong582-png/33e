
#import <notify.h>
#import <pthread.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

#import "pac_helper.h"
#import "UIEventFetcher.h"
#import "UIEventDispatcher.h"
#include "KabraxHide.h"
#import "HUDMainApplication.h"
#import "HUDHelper.h"
#import "UIApplication+Private.h"

@implementation HUDMainApplication

- (instancetype)init
{
    if (self = [super init])
    {
        {
            int outToken;
            notify_register_dispatch(NOTIFY_DESTROY_HUD, &outToken, dispatch_get_main_queue(), ^(int token) {
                uint64_t state = 0;
                notify_get_state(token, &state);
                if (state == 1) {
                    notify_set_state(token, 0);
                    notify_cancel(token);
                    RequestExitHUD();
                }
            });
        }

        do {
            UIEventDispatcher *dispatcher = (UIEventDispatcher *)[self valueForKey:KH_NS("eventDispatcher")];
            if (!dispatcher) break;

            if ([dispatcher respondsToSelector:KH_SEL("_installEventRunLoopSources:")])
            {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                [dispatcher _installEventRunLoopSources:mainRunLoop];
            }
            else
            {
                IMP runMethodIMP = class_getMethodImplementation([self class], KH_SEL("_run"));
                if (!runMethodIMP) break;

                uint32_t *runMethodPtr = (uint32_t *)make_sym_readable((void *)runMethodIMP);

                void (*orig_UIEventDispatcher__installEventRunLoopSources_)(id _Nonnull, SEL _Nonnull, CFRunLoopRef) = NULL;
                for (int i = 0; i < 0x140; i++)
                {

                    if (runMethodPtr[i] != 0xaa0003e2 || (runMethodPtr[i + 1] & 0xff000000) != 0xaa000000)
                        continue;

                    uint32_t blInst = runMethodPtr[i + 2];
                    uint32_t *blInstPtr = &runMethodPtr[i + 2];
                    if ((blInst & 0xfc000000) != 0x94000000) continue;

                    int32_t blOffset = blInst & 0x03ffffff;
                    if (blOffset & 0x02000000)
                        blOffset |= 0xfc000000;
                    blOffset <<= 2;

                    uint64_t blAddr = (uint64_t)blInstPtr + blOffset;

                    uint32_t cbzInst = *((uint32_t *)make_sym_readable((void *)blAddr));
                    if ((cbzInst & 0xff000000) != 0xb4000000) continue;

                    orig_UIEventDispatcher__installEventRunLoopSources_ = (void (*)(id  _Nonnull __strong, SEL _Nonnull, CFRunLoopRef))make_sym_callable((void *)blAddr);
                }

                if (!orig_UIEventDispatcher__installEventRunLoopSources_) break;

                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                orig_UIEventDispatcher__installEventRunLoopSources_(dispatcher, KH_SEL("_installEventRunLoopSources:"), mainRunLoop);
            }

            UIEventFetcher *fetcher = [[KH_CLS("UIEventFetcher") alloc] init];
            [dispatcher setValue:fetcher forKey:KH_NS("eventFetcher")];

            if ([fetcher respondsToSelector:KH_SEL("setEventFetcherSink:")]) {
                [fetcher setEventFetcherSink:dispatcher];
            }
            else
            {
                /* Tested on iOS 15.1.1 and below */
                [fetcher setValue:dispatcher forKey:KH_NS("eventFetcherSink")];
            }

            [self setValue:fetcher forKey:KH_NS("eventFetcher")];
        } while (NO);
    }
    return self;
}

@end
