#import "NetworkHelper.h"
#import "mahoa.h"
#include "AsyncOffsetState.h"
#include <map>
#include <string>
#include <cerrno>
#include <cstdlib>

// Decode configuration only when the first offset request needs it, rather
// than invoking Foundation while dyld is initializing an injected image.
static NSString *OffsetEndpoint() {
    static NSString *value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = NSSENCRYPT("https://throbbing-shadow-3045.nguyenhoang1vnm.workers.dev"); });
    return value;
}
static NSString *OffsetClientToken() {
    static NSString *value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = NSSENCRYPT("akhe287Gsn288DMwi@"); });
    return value;
}

@implementation _0xFFFA282

+ (NSURLSession *)offsetSession {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 5;
        configuration.timeoutIntervalForResource = 6;
        configuration.waitsForConnectivity = NO;
        configuration.URLCache = nil;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

+ (uintptr_t)_0xFFFFFFF:(NSString *)key {
    if (!key.length) return 0;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self _0xFFFFFFF:key]; });
        return 0;
    }
    static std::map<std::string, AsyncOffsetState> states;
    const std::string cacheKey(key.UTF8String);
    AsyncOffsetState &state = states[cacheKey];
    if (state.value) return state.value;
    if (state.begin(NSProcessInfo.processInfo.systemUptime)) {
        [self _0xFFFFFFFF:key _0xFAAAAAAAAA:^(uintptr_t value, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                states[cacheKey].finish(error ? 0 : value, NSProcessInfo.processInfo.systemUptime);
            });
        }];
    }
    return 0;
}

+ (void)_0xFFFFFFFF:(NSString *)key _0xFAAAAAAAAA:(void(^)(uintptr_t, NSError *))completion {
    NSURLComponents *components = [NSURLComponents componentsWithString:OffsetEndpoint()];
    components.path = @"/Andb38Kdj39ndjKdhaBf";
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"key" value:key]];
    NSURL *url = components.URL;
    if (!url || ![url.scheme isEqualToString:@"https"]) {
        if (completion) completion(0, [NSError errorWithDomain:@"OffsetError" code:-1
            userInfo:@{NSLocalizedDescriptionKey:@"Địa chỉ dữ liệu không hợp lệ."}]);
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"iPhone" forHTTPHeaderField:@"User-Agent"];
    [request setValue:OffsetClientToken() forHTTPHeaderField:@"X-Client-Token"];
    [request setValue:[NSString stringWithFormat:@"%lld", (long long)(NSDate.date.timeIntervalSince1970 * 1000)]
        forHTTPHeaderField:@"X-Timestamp"];
    [[[self offsetSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        @autoreleasepool {
            if (error) { if (completion) completion(0, error); return; }
            NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            id body = status == 200 && data.length > 0 && data.length <= 32768
                ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
            id raw = [body isKindOfClass:NSDictionary.class] ? body[@"offset"] : nil;
            uintptr_t value = 0;
            if ([raw isKindOfClass:NSString.class] && [raw length] > 0) {
                const char *start = [raw UTF8String];
                char *end = nullptr;
                errno = 0;
                unsigned long long parsed = strtoull(start, &end, 0);
                if (errno == 0 && end != start && *end == '\0' && start[0] != '-' && parsed > 0 && parsed <= UINTPTR_MAX)
                    value = (uintptr_t)parsed;
            }
            NSError *failure = value ? nil : [NSError errorWithDomain:@"OffsetError" code:status ?: -2
                userInfo:@{NSLocalizedDescriptionKey:@"Máy chủ chưa trả dữ liệu hợp lệ. Sẽ tự thử lại."}];
            if (completion) completion(value, failure);
        }
    }] resume];
}
@end
