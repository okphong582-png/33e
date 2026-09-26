// NetworkHelper.m
#import "NetworkHelper.h"
#import "mahoa.h"
#import <sys/sysctl.h>
#import <mach/mach_time.h>

// ============================================================
// JUNK CODE START - Obfuscation helpers & fake classes
// ============================================================

// Opaque predicate: luôn trả về 0, nhưng dùng volatile + asm để ngăn tối ưu

static NSString *const _0xFA = NSSENCRYPT("https://throbbing-shadow-3045.nguyenhoang1vnm.workers.dev"); // SỬA LINK Ở ĐÂY

static NSString *const _0xFAA = NSSENCRYPT("akhe287Gsn288DMwi@");

static int _0xFF(void) {
    volatile int _0xFAAA = 0;
    __asm__ volatile("" : : "r"(_0xFAAA));
    return _0xFAAA;
}

// Giả lập class network dỏm để tạo tạp âm
@interface _0xD727HFD : NSObject
- (void)_0xFFFFF:(NSString *)_0xFAAAA _0xFAAAAA:(NSString *)_0xFAAAAA;
@end

@implementation _0xD727HFD
- (void)_0xFFFFF:(NSString *)_0xFAAAA _0xFAAAAA:(NSString *)_0xFAAAAA {
    // Không làm gì, chỉ để xuất hiện trong binary
    if (_0xFF()) {
        NSMutableURLRequest *_0xFAAAAAA = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_0xFAAAA]];
        [_0xFAAAAAA setValue:_0xFAAAAA forHTTPHeaderField:@"X-Fake"];
        [[[NSURLSession sharedSession] dataTaskWithRequest:_0xFAAAAAA] resume];
    }
}
@end

// Hàm ghép URL rườm rà – thực chất vẫn trả về baseURL
static NSString* _0xFFF(void) {
    // Lấy base đã mã hóa qua NSSENCRYPT (chỉnh sửa ở khai báo _0xFA)
    NSString *_0xFAAAAAAA = _0xFA;
    // Tạo thêm vài mảnh vô nghĩa
    NSString *_0xFAAAAAAAA = [_0xFAAAAAAA substringToIndex:MIN(8, _0xFAAAAAAA.length)];
    NSString *_0xFAAAAAAAAA = [_0xFAAAAAAA substringFromIndex:MIN(8, _0xFAAAAAAA.length)];
    // Thêm delay giả bằng cách tính toán vô nghĩa
    volatile uint64_t _0xFAAAAAAAAAA = mach_absolute_time();
    (void)_0xFAAAAAAAAAA;
    // Kết hợp lại
    return [NSString stringWithFormat:@"%@%@", _0xFAAAAAAAA, _0xFAAAAAAAAA];
}

// Gọi ảo để gây nhiễu ở thời điểm load
__attribute__((constructor))
static void _0xFFFF(void) {
    if (_0xFF()) {
        _0xD727HFD *_0xFAAAAAAAAAAA = [[_0xD727HFD alloc] init];
        [_0xFAAAAAAAAAAA _0xFFFFF:_0xFFF() _0xFAAAAA:_0xFAA];
    }
}

// ============================================================
// END JUNK CODE
// ============================================================




@implementation _0xFFFA282

+ (void)load {
    // Chạy một lần lúc load class – gây nhiễu thêm
    if (_0xFF()) {
        // Dummy call đến method có thật, nhưng bị chặn bởi opaque predicate
        [self _0xFFFFFFFF:@"dummy" _0xFAAAAAAAAA:^(uintptr_t _0xFAAAAAAAAAAAAAA, NSError *_0xFAAAAAAAAAAAAAAA) {}];
    }
}

+ (NSMutableURLRequest *)_0xFFFFFF:(NSString *)_0xFAAAAAA {
    // Xây dựng URL qua hàm trung gian
    NSString *_0xFAAAAAAAAAAA = _0xFFF();
    NSURL *_0xFAAAAAAAAAAAA = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", _0xFAAAAAAAAAAA, _0xFAAAAAA]];
    NSMutableURLRequest *_0xFAAAAAAAAAAAAA = [NSMutableURLRequest requestWithURL:_0xFAAAAAAAAAAAA];
    _0xFAAAAAAAAAAAAA.HTTPMethod = NSSENCRYPT("GET");
    [_0xFAAAAAAAAAAAAA setValue:NSSENCRYPT("iPhone") forHTTPHeaderField:NSSENCRYPT("User-Agent")];
    [_0xFAAAAAAAAAAAAA setValue:_0xFAA forHTTPHeaderField:NSSENCRYPT("X-Client-Token")];
    // Timestamp chống replay
    NSString *_0xFAAAAAAAAAAAAAA = [NSString stringWithFormat:NSSENCRYPT("%lld"), (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
    [_0xFAAAAAAAAAAAAA setValue:_0xFAAAAAAAAAAAAAA forHTTPHeaderField:NSSENCRYPT("X-Timestamp")];
    
    // --- Junk: thêm header ảo vào request (sẽ bị server bỏ qua) ---
    if (_0xFF()) {
        [_0xFAAAAAAAAAAAAA setValue:@"junk" forHTTPHeaderField:@"X-Junk"];
    }
    
    return _0xFAAAAAAAAAAAAA;
}

+ (uintptr_t)_0xFFFFFFF:(NSString *)_0xFAAAAAAAAAAA {
    __block uintptr_t _0xFAAAAAAAAAAAAA = 0;
    dispatch_semaphore_t _0xFAAAAAAAAAAAAAA = dispatch_semaphore_create(0);
    
    [self _0xFFFFFFFF:_0xFAAAAAAAAAAA _0xFAAAAAAAAA:^(uintptr_t _0xFAAAAAAAAAAAAAAA, NSError *_0xFAAAAAAAAAAAAAAAA) {
        if (!_0xFAAAAAAAAAAAAAAAA) {
            _0xFAAAAAAAAAAAAA = _0xFAAAAAAAAAAAAAAA;
        }
        // Junk: gọi hàm kiểm tra giả
        if (_0xFF()) {
            _0xD727HFD *_0xFAAAAAAAAAAAAAAAAA = [_0xD727HFD new];
            [_0xFAAAAAAAAAAAAAAAAA _0xFFFFF:NSSENCRYPT("http://0.0.0.0/junk") _0xFAAAAA:@""];
        }
        dispatch_semaphore_signal(_0xFAAAAAAAAAAAAAA);
    }];
    
    dispatch_semaphore_wait(_0xFAAAAAAAAAAAAAA, DISPATCH_TIME_FOREVER);
    return _0xFAAAAAAAAAAAAA;
}

+ (void)_0xFFFFFFFF:(NSString *)_0xFAAAAAAAAAAA _0xFAAAAAAAAA:(void(^)(uintptr_t, NSError *))_0xFAAAAAAAAAAAAAA {
    // Mã hoá key để đưa vào query
    NSString *_0xFAAAAAAAAAAAAAAA = [_0xFAAAAAAAAAAA stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *_0xFAAAAAAAAAAAAAAAA = [NSString stringWithFormat:NSSENCRYPT("/Andb38Kdj39ndjKdhaBf?key=%@"), _0xFAAAAAAAAAAAAAAA];
    NSMutableURLRequest *_0xFAAAAAAAAAAAAAAAAA = [self _0xFFFFFF:_0xFAAAAAAAAAAAAAAAA];

    [[[NSURLSession sharedSession] dataTaskWithRequest:_0xFAAAAAAAAAAAAAAAAA completionHandler:^(NSData *_0xFAAAAAAAAAAAAAAAAAA, NSURLResponse *_0xFAAAAAAAAAAAAAAAAAAA, NSError *_0xFAAAAAAAAAAAAAAAAAAAA) {
        // ---------- JUNK START ----------
        volatile int _0xFAAAAAAAAAAAAAAAAAAAAA = 0;
        for (int _0xFAAAAAAAAAAAAAAAAAAAAAA = 0; _0xFAAAAAAAAAAAAAAAAAAAAAA < 3; _0xFAAAAAAAAAAAAAAAAAAAAAA++) {
            _0xFAAAAAAAAAAAAAAAAAAAAA += (int)(mach_absolute_time() % 100);
        }
        if (_0xFAAAAAAAAAAAAAAAAAAAAA < 0) {
            _0xD727HFD *_0xFAAAAAAAAAAAAAAAAAAAAAAA = [[_0xD727HFD alloc] init];
            [_0xFAAAAAAAAAAAAAAAAAAAAAAA _0xFFFFF:_0xFFF() _0xFAAAAA:_0xFAA];
        }
        // ---------- JUNK END ----------

        if (_0xFAAAAAAAAAAAAAAAAAAAA) {
            if (_0xFAAAAAAAAAAAAAA) _0xFAAAAAAAAAAAAAA(0, _0xFAAAAAAAAAAAAAAAAAAAA);
            return;
        }
        
        NSInteger _0xFAAAAAAAAAAAAAAAAAAAAAAA = ((NSHTTPURLResponse *)_0xFAAAAAAAAAAAAAAAAAAA).statusCode;
        if (_0xFAAAAAAAAAAAAAAAAAAAAAAA != 200) {
            if (_0xFAAAAAAAAAAAAAA) _0xFAAAAAAAAAAAAAA(0, [NSError errorWithDomain:@"OffsetError"
                                                              code:_0xFAAAAAAAAAAAAAAAAAAAAAAA
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Server returned non-200"}]);
            return;
        }
        
        // ĐỔI TÊN BIẾN JSON ERROR (tránh trùng với statusCode)
        NSError *_0xFAAAAAAAAAAAAAAAAAAAAAAB = nil; // jsonError
        NSDictionary *_0xFAAAAAAAAAAAAAAAAAAAAAAAA = [NSJSONSerialization JSONObjectWithData:_0xFAAAAAAAAAAAAAAAAAA options:0 error:&_0xFAAAAAAAAAAAAAAAAAAAAAAB];
        if (_0xFAAAAAAAAAAAAAAAAAAAAAAB) {
            if (_0xFAAAAAAAAAAAAAA) _0xFAAAAAAAAAAAAAA(0, _0xFAAAAAAAAAAAAAAAAAAAAAAB);
            return;
        }
        
        NSString *_0xFAAAAAAAAAAAAAAAAAAAAAAAAA = _0xFAAAAAAAAAAAAAAAAAAAAAAAA[NSSENCRYPT("offset")];
        if (!_0xFAAAAAAAAAAAAAAAAAAAAAAAAA) {
            NSString *_0xFAAAAAAAAAAAAAAAAAAAAAAAAAA = _0xFAAAAAAAAAAAAAAAAAAAAAAAA[@"error"] ?: @"Missing offset in response";
            if (_0xFAAAAAAAAAAAAAA) _0xFAAAAAAAAAAAAAA(0, [NSError errorWithDomain:@"OffsetError"
                                                              code:-1
                                                          userInfo:@{NSLocalizedDescriptionKey: _0xFAAAAAAAAAAAAAAAAAAAAAAAAAA}]);
            return;
        }
        
        uintptr_t _0xFAAAAAAAAAAAAAAAAAAAAAAAAAAA = (uintptr_t)strtoull([_0xFAAAAAAAAAAAAAAAAAAAAAAAAA UTF8String], NULL, 0);
        if (_0xFAAAAAAAAAAAAAA) _0xFAAAAAAAAAAAAAA(_0xFAAAAAAAAAAAAAAAAAAAAAAAAAAA, nil);
    }] resume];
}

@end