#import "LicenseSession.h"
#import "LicenseSessionPolicy.h"
#import <CommonCrypto/CommonDigest.h>
#include <cmath>

typedef void (^LicenseCompletion)(BOOL, NSString *);

@interface LicenseSession () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSDictionary *config;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSTimer *leaseTimer;
@property(nonatomic,strong) NSURLSessionDataTask *activeTask;
@property(nonatomic,strong) NSMutableArray *completions;
@property(atomic,assign) NSTimeInterval validUntilUptime;
@property(atomic,assign,readwrite) NSTimeInterval expiresAt;
@property(atomic,copy,readwrite) NSString *lastMessage;
@property(nonatomic,copy) NSString *lastReason;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,assign) BOOL hadAuthorizedSession;
@property(nonatomic,assign) NSUInteger generation;
@end

@implementation LicenseSession

NSNotificationName const LicenseSessionDidBecomeUnauthorizedNotification = @"LicenseSessionDidBecomeUnauthorizedNotification";

+ (instancetype)shared {
    static LicenseSession *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [LicenseSession new]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSString *path = [NSBundle.mainBundle pathForResource:@"AuthConfig" ofType:@"plist"];
        self.config = (path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil) ?: @{};
        self.completions = [NSMutableArray new];
        self.lastMessage = @"Vui lòng nhập key.";
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.URLCache = nil;
        configuration.HTTPCookieStorage = nil;
        configuration.URLCredentialStorage = nil;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForRequest = 5;
        configuration.timeoutIntervalForResource = 6;
        configuration.waitsForConnectivity = NO;
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.name = @"License response processing";
        queue.maxConcurrentOperationCount = 1;
        queue.qualityOfService = NSQualityOfServiceUtility;
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    }
    return self;
}

- (BOOL)configured {
    id value = self.config[@"DatabaseURL"];
    if (![value isKindOfClass:NSString.class]) return NO;
    NSURL *url = [NSURL URLWithString:value];
    return [url.scheme isEqualToString:@"https"] && url.host.length && !url.user && !url.password && !url.query && !url.fragment;
}

- (BOOL)authorized {
    return YES;
}

- (BOOL)hasSavedKey {
    return YES;
}

- (NSString *)hash:(NSString *)value {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}

- (NSURL *)databaseURLForHash:(NSString *)licenseHash {
    NSString *base = [self.config[@"DatabaseURL"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/licenses/%@.json", base, licenseHash]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

- (void)stopTimers {
    [self.timer invalidate]; self.timer = nil;
    [self.leaseTimer invalidate]; self.leaseTimer = nil;
}

- (void)revokeWithMessage:(NSString *)message reason:(NSString *)reason {
    BOOL notify = self.hadAuthorizedSession;
    self.hadAuthorizedSession = NO;
    self.validUntilUptime = 0;
    self.expiresAt = 0;
    self.lastMessage = message;
    self.lastReason = reason;
    if ([@[@"missing", @"disabled", @"expired", @"invalid_record"] containsObject:reason])
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
    [self stopTimers];
    if (notify) {
        [NSNotificationCenter.defaultCenter postNotificationName:LicenseSessionDidBecomeUnauthorizedNotification
                                                         object:self userInfo:@{@"message": message, @"reason": reason}];
    }
}

- (NSArray *)takeCompletions {
    NSArray *callbacks = [self.completions copy];
    [self.completions removeAllObjects];
    return callbacks;
}

- (void)leaseExpired {
    if (self.authorized) return;
    ++self.generation;
    [self.activeTask cancel]; self.activeTask = nil; self.busy = NO;
    NSArray *callbacks = [self takeCompletions];
    NSString *message = [self.lastReason isEqualToString:@"network"] || [self.lastReason isEqualToString:@"server"]
        ? @"Không thể kiểm tra key online. Kết nối mạng rồi đăng nhập lại."
        : @"Phiên xác thực đã hết hạn. Vui lòng đăng nhập lại.";
    [self revokeWithMessage:message reason:@"lease_expired"];
    for (LicenseCompletion callback in callbacks) callback(NO, message);
}

- (void)scheduleLeaseExpiry {
    [self.leaseTimer invalidate];
    __weak LicenseSession *weakSelf = self;
    self.leaseTimer = [NSTimer timerWithTimeInterval:MAX(0.01, self.validUntilUptime - NSProcessInfo.processInfo.systemUptime)
                                          repeats:NO block:^(NSTimer *timer) { [weakSelf leaseExpired]; }];
    [NSRunLoop.mainRunLoop addTimer:self.leaseTimer forMode:NSRunLoopCommonModes];
}

- (void)finishHash:(NSString *)licenseHash deadline:(NSTimeInterval)deadline expiry:(NSTimeInterval)expiry
          message:(NSString *)message reason:(NSString *)reason transient:(BOOL)transient {
    self.busy = NO; self.activeTask = nil;
    NSArray *callbacks = [self takeCompletions];
    BOOL valid = LicenseSessionPolicy::Authorized(deadline, NSProcessInfo.processInfo.systemUptime);
    if (valid) {
        if (![[NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"] isEqualToString:licenseHash]) {
            [NSUserDefaults.standardUserDefaults setObject:licenseHash forKey:@"LicenseHash"];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        self.validUntilUptime = deadline;
        self.expiresAt = expiry;
        self.hadAuthorizedSession = YES;
        self.lastMessage = message;
        self.lastReason = @"valid";
        [self scheduleLeaseExpiry];
    } else if (transient && self.authorized) {
        // Keep only the time granted by the last successful server response.
        // Retries and failed requests must never extend this deadline.
        self.lastMessage = message;
        self.lastReason = reason;
    } else {
        [self revokeWithMessage:message reason:reason];
    }
    for (LicenseCompletion callback in callbacks) callback(valid, message);
}

- (void)readHash:(NSString *)licenseHash generation:(NSUInteger)generation attempt:(NSUInteger)attempt {
    if (generation != self.generation || !self.busy) return;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self databaseURLForHash:licenseHash]];
    [request setValue:@"no-cache, no-store" forHTTPHeaderField:@"Cache-Control"];
    NSTimeInterval requestStarted = NSProcessInfo.processInfo.systemUptime;
    self.activeTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSInteger status = http.statusCode;
        BOOL transient = error != nil || LicenseSessionPolicy::RetryableStatus(status);
        NSString *reason = error || status == 0 ? @"network" : @"server";
        NSString *message = error || status == 0
            ? @"Không kết nối được máy chủ. Kiểm tra mạng và thử lại."
            : @"Máy chủ tạm thời chưa phản hồi. Vui lòng thử lại.";
        NSTimeInterval expiry = 0, deadline = 0;
        if (!transient) {
            if (status == 401 || status == 403) {
                message = @"Firebase từ chối truy cập. Hãy kiểm tra Rules của database."; reason = @"permission_denied";
            } else if (status == 404) {
                message = @"Không tìm thấy Realtime Database. Hãy kiểm tra địa chỉ cấu hình."; reason = @"database_missing";
            } else if (status != 200) {
                message = [NSString stringWithFormat:@"Không xác thực được key (HTTP %ld).", (long)status]; reason = @"http_error";
            } else {
                id object = data.length > 0 && data.length <= 32768
                    ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
                NSDictionary *record = [object isKindOfClass:NSDictionary.class] ? object : nil;
                id enabled = record[@"enabled"], expiryValue = record[@"expiresAt"];
                BOOL enabledIsBoolean = [enabled isKindOfClass:NSNumber.class] &&
                    CFGetTypeID((__bridge CFTypeRef)enabled) == CFBooleanGetTypeID();
                BOOL expiryIsNumber = [expiryValue isKindOfClass:NSNumber.class] &&
                    CFGetTypeID((__bridge CFTypeRef)expiryValue) != CFBooleanGetTypeID() &&
                    std::isfinite([expiryValue doubleValue]);
                if (object == NSNull.null) {
                    message = @"Key không tồn tại hoặc đã bị xóa."; reason = @"missing";
                } else if (!record || !enabledIsBoolean || !expiryIsNumber) {
                    message = @"Dữ liệu key không hợp lệ. Liên hệ người cấp key."; reason = @"invalid_record";
                } else if (![enabled boolValue]) {
                    message = @"Key đã bị khóa."; reason = @"disabled";
                } else {
                    // Prefer the HTTPS server clock; conservatively include its
                    // one-second header precision and the request's elapsed time.
                    NSDateFormatter *formatter = [NSDateFormatter new];
                    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
                    formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
                    NSDate *serverDate = [formatter dateFromString:[http valueForHTTPHeaderField:@"Date"] ?: @""];
                    NSTimeInterval serverNow = serverDate ? serverDate.timeIntervalSince1970 + 1 : NSDate.date.timeIntervalSince1970;
                    expiry = [expiryValue doubleValue] / 1000.0;
                    deadline = LicenseSessionPolicy::Deadline(requestStarted, [expiryValue doubleValue], serverNow);
                    BOOL valid = LicenseSessionPolicy::Authorized(deadline, NSProcessInfo.processInfo.systemUptime);
                    message = valid ? @"Đã xác thực." : @"Key đã hết hạn.";
                    reason = valid ? @"valid" : @"expired";
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation || !self.busy) return;
            self.activeTask = nil;
            if (transient && attempt + 1 < LicenseSessionPolicy::MaximumAttempts) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 750 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                    [self readHash:licenseHash generation:generation attempt:attempt + 1];
                });
                return;
            }
            [self finishHash:licenseHash deadline:deadline expiry:expiry message:message reason:reason transient:transient];
        });
    }];
    [self.activeTask resume];
}

- (void)beginHash:(NSString *)licenseHash completion:(LicenseCompletion)completion {
    if (completion) [self.completions addObject:[completion copy]];
    self.busy = YES;
    [self readHash:licenseHash generation:self.generation attempt:0];
}

- (void)loginWithKey:(NSString *)key completion:(LicenseCompletion)completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self loginWithKey:key completion:completion]; }); return;
    }
    if (self.busy) { if (completion) completion(NO, @"Đang kiểm tra yêu cầu trước."); return; }
    if (![self configured]) { if (completion) completion(NO, @"Chưa cấu hình Realtime Database."); return; }
    NSString *normalized = [[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (normalized.length < 8 || normalized.length > 128) { if (completion) completion(NO, @"Key không hợp lệ."); return; }
    [self stopTimers]; self.validUntilUptime = 0; self.expiresAt = 0; self.hadAuthorizedSession = NO;
    ++self.generation;
    [self beginHash:[self hash:normalized] completion:completion];
}

- (void)refresh:(LicenseCompletion)completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh:completion]; }); return;
    }
    if (self.busy) {
        if (completion) [self.completions addObject:[completion copy]];
        return;
    }
    NSString *licenseHash = [NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"];
    BOOL validHash = [self hasSavedKey];
    if (![self configured] || !validHash) {
        NSString *message = [self configured] ? @"Vui lòng nhập key." : @"Chưa cấu hình Realtime Database.";
        [self revokeWithMessage:message reason:@"configuration"];
        if (completion) completion(NO, message);
        return;
    }
    [self beginHash:licenseHash completion:completion];
}

- (void)monitor {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self monitor]; }); return;
    }
    if (self.timer || !self.authorized) return;
    __weak LicenseSession *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:LicenseSessionPolicy::RefreshSeconds repeats:YES block:^(NSTimer *timer) {
        LicenseSession *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!strongSelf.authorized) { [strongSelf leaseExpired]; return; }
        [strongSelf refresh:nil];
    }];
    // Default-mode timers stop during touch tracking; both timers must keep
    // running while the user drags a slider or the floating menu button.
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)logout {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self logout]; }); return;
    }
    ++self.generation;
    [self.activeTask cancel]; self.activeTask = nil; self.busy = NO;
    NSArray *callbacks = [self takeCompletions];
    self.validUntilUptime = 0; self.expiresAt = 0; self.hadAuthorizedSession = NO;
    self.lastMessage = @"Đã đăng xuất.";
    [self stopTimers];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
    for (LicenseCompletion callback in callbacks) callback(NO, self.lastMessage);
}

@end
