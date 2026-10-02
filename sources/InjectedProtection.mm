#ifdef MIZZE_INJECTED
#import "InjectedProtection.h"
#import <UIKit/UIKit.h>
#include "../obfuscation/AntiREProtection.h"

// Only the encoded bytes are emitted to the custom data section.
static constexpr uint8_t databaseBytes[] = {104, 116, 116, 112, 115, 58, 47, 47, 97, 112, 112, 99, 104, 97, 116, 97, 105, 45, 51, 49, 51, 101, 51, 45, 100, 101, 102, 97, 117, 108, 116, 45, 114, 116, 100, 98, 46, 102, 105, 114, 101, 98, 97, 115, 101, 105, 111, 46, 99, 111, 109};
static constexpr _vdata_::VDBuffer<sizeof(databaseBytes), 0x4C4943454E5345ULL> database
    VDATA_DATA_SECTION = {databaseBytes, _obf_::MakeSeq<sizeof(databaseBytes)>::type()};

NSString* MizzeDefaultLicenseDatabaseURL(void) {
    uint8_t decoded[sizeof(databaseBytes)]{};
    if (!database.decrypt_to(decoded, sizeof(decoded))) return @"";
    NSString* result = [[NSString alloc] initWithBytes:decoded length:sizeof(decoded) encoding:NSUTF8StringEncoding];
    // Wipe the temporary stack buffer after Foundation takes its copy.
    volatile uint8_t* wipe = decoded;
    for (size_t i = 0; i < sizeof(decoded); ++i) wipe[i] = 0;
    return result ?: @"";
}

void MizzeStartOwnCodeProtection(void) {
    NSCAssert(NSThread.isMainThread, @"Protection scheduling requires the main thread");
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_queue_t queue = dispatch_queue_create("com.mizze.own-code-integrity", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        dispatch_async(queue, ^{
            BOOL healthy = _monite_::mt_register_section(database.data, sizeof(database.data)) && ANTI_RE_INIT();
            NSLog(@"[Mizze] Own-code protection: %@", healthy ? @"ready" : @"self-check failed");
        });
        static dispatch_source_t timer;
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC),
                                  15 * NSEC_PER_SEC, 2 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
            dispatch_async(queue, ^{
                static BOOL reported = NO;
                if (!ANTI_RE_CHECK() && !reported) {
                    reported = YES;
                    NSLog(@"[Mizze] Own-code integrity check failed");
                }
            });
        });
        dispatch_resume(timer);
    });
}
#endif
