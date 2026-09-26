#import "_0xC2863HD.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>
// #import "mahoa.h"   // Comment để tránh lỗi macro

#define OPAQUE_TRUE(x)  ((x*0 + 1) ? 1 : 0)
#define OPAQUE_FALSE(x) ((x*0) ? 1 : 0)
#define DEAD_CODE()     __asm__ volatile("nop\n\t nop\n\t nop\n\t nop");

static void _0xFFF(void) {
    volatile int _0xFFFF = 0x12345678;
    _0xFFFF ^= 0x12345678;
    if (OPAQUE_TRUE(_0xFFFF)) _0xFFFF = 1; else _0xFFFF = 0;
    for (int _0xFFFFF = 0; _0xFFFFF < 5; _0xFFFFF++) { DEAD_CODE(); }
}

static BOOL _0xFFFFFF(void) {
    _0xFFF();
    volatile int _0xFFFFFFF = 0xDEADBEEF;
    _0xFFFFFFF ^= 0xDEADBEEF;
    if (OPAQUE_FALSE(_0xFFFFFFF)) _0xFFFFFFF = 0xCAFE;
    
    // Dùng chuỗi thường, không mã hóa để tránh lỗi
    const char *allowList[] = {
        "/System/Library/",
        "/usr/lib/",
        "Frameworks/DataDomeSDK.framework",
        NULL
    };
    
    uint32_t _0xFFFFFFFF = _dyld_image_count();
    BOOL _0xFFFFFFFFF = NO;
    
    for (uint32_t _0xFFFFFFFFFF = 0; _0xFFFFFFFFFF < _0xFFFFFFFF; _0xFFFFFFFFFF++) {
        for (int _0xFFFFFFFFFFF = 0; _0xFFFFFFFFFFF < 3; _0xFFFFFFFFFFF++) { DEAD_CODE(); }
        const char *_0xFFFFFFFFFFFF = _dyld_get_image_name(_0xFFFFFFFFFF);
        if (!_0xFFFFFFFFFFFF) continue;
        if (OPAQUE_TRUE(_0xFFFFFFFFFF)) {
            volatile int _0xFFFFFFFFFFFFF = 0;
            _0xFFFFFFFFFFFFF += 1;
        }
        const char *_0xFFFFFFFFFFFFFF = [[[NSBundle mainBundle] executablePath] UTF8String];
        if (strcmp(_0xFFFFFFFFFFFF, _0xFFFFFFFFFFFFFF) == 0) {
            for (int _0xFFFFFFFFFFFFFFF = 0; _0xFFFFFFFFFFFFFFF < 2; _0xFFFFFFFFFFFFFFF++) { DEAD_CODE(); }
            continue;
        }
        NSString *_0xFFFFFFFFFFFFFFFF = [NSString stringWithUTF8String:_0xFFFFFFFFFFFF];
        if (!_0xFFFFFFFFFFFFFFFF) continue;
        
        // Kiểm tra ngoại lệ (chuỗi thường)
        if ([_0xFFFFFFFFFFFFFFFF containsString:@".app/Frameworks/"]) {
            volatile int _0xFFFFFFFFFFFFFFFFF = 0;
            if (OPAQUE_TRUE(_0xFFFFFFFFFFFFFFFFF)) _0xFFFFFFFFFFFFFFFFF = 1;
            continue;
        }
        if ([_0xFFFFFFFFFFFFFFFF containsString:@"DataDomeSDK"]) {
            for (int _0xFFFFFFFFFFFFFFFFFF = 0; _0xFFFFFFFFFFFFFFFFFF < 1; _0xFFFFFFFFFFFFFFFFFF++) { DEAD_CODE(); }
            continue;
        }
        BOOL _0xFFFFFFFFFFFFFFFFFFFF = NO;
        for (int _0xFFFFFFFFFFFFFFFFFFFFF = 0; allowList[_0xFFFFFFFFFFFFFFFFFFFFF] != NULL; _0xFFFFFFFFFFFFFFFFFFFFF++) {
            if (strstr(_0xFFFFFFFFFFFF, allowList[_0xFFFFFFFFFFFFFFFFFFFFF]) == _0xFFFFFFFFFFFF) {
                _0xFFFFFFFFFFFFFFFFFFFF = YES;
                break;
            }
            if (OPAQUE_TRUE(_0xFFFFFFFFFFFFFFFFFFFFF)) {
                if (strstr(_0xFFFFFFFFFFFF, allowList[_0xFFFFFFFFFFFFFFFFFFFFF]) != NULL) {
                    _0xFFFFFFFFFFFFFFFFFFFF = YES;
                    break;
                }
            }
        }
        if (!_0xFFFFFFFFFFFFFFFFFFFF) {
            _0xFFFFFFFFF = YES;
            volatile int _0xFFFFFFFFFFFFFFFFFFFFFF = 1;
            while (_0xFFFFFFFFFFFFFFFFFFFFFF < 1) { DEAD_CODE(); _0xFFFFFFFFFFFFFFFFFFFFFF++; }
            break;
        }
    }
    for (int _0xFFFFFFFFFFFFFFFFFFFFFFF = 0; _0xFFFFFFFFFFFFFFFFFFFFFFF < 5; _0xFFFFFFFFFFFFFFFFFFFFFFF++) { DEAD_CODE(); }
    if (OPAQUE_FALSE(_0xFFFFFFFFF)) _0xFFFFFFFFF = NO;
    return _0xFFFFFFFFF;
}

static void __attribute__((noreturn)) _0xFFFFFFFFFFFFFFFFFFFFFFFF(void) {
    exit(0);
}

// Constructor đã bị comment – không tự chạy
/*
__attribute__((constructor))
static void _0xFFFFFFFFFFFFFFFFFFFFFFFFF(void) {
    _0xFFF();
    volatile int _0xFFFFFFFFFFFFFFFFFFFFFFFFFF = 1;
    if (OPAQUE_FALSE(_0xFFFFFFFFFFFFFFFFFFFFFFFFFF)) _0xFFFFFFFFFFFFFFFFFFFFFFFFFF = 0;
    else _0xFFFFFFFFFFFFFFFFFFFFFFFFFF = 1;
    if (_0xFFFFFFFFFFFFFFFFFFFFFFFFFF == 1) {
        BOOL _0xFFFFFFFFFFFFFFFFFFFFFFFFFFF = _0xFFFFFF();
        if (_0xFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
            _0xFFFFFFFFFFFFFFFFFFFFFFFF();
        }
    }
}
*/

@implementation _0xFF

+ (BOOL)_0xFFFF {
    _0xFFF();
    volatile int _0xFFFFFFFFFFFFFFFFFFFFFF = 0;
    if (OPAQUE_TRUE(_0xFFFFFFFFFFFFFFFFFFFFFF)) _0xFFFFFFFFFFFFFFFFFFFFFF = 1;
    else _0xFFFFFFFFFFFFFFFFFFFFFF = 0;
    if (_0xFFFFFFFFFFFFFFFFFFFFFF == 0) {
        BOOL _0xFFFFFFFFFFFFFFFFFFFFFFF = _0xFFFFFF();
        if (_0xFFFFFFFFFFFFFFFFFFFFFFF) {
            _0xFFFFFFFFFFFFFFFFFFFFFFFF();
            return YES;
        }
    }
    return NO;
}

@end