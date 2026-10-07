#import "LicenseSession.h"
#import "LicenseSessionPolicy.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#include <cmath>
#include "LicenseEventStream.h"
#ifdef MIZZE_INJECTED
#import "InjectedProtection.h"
#endif

typedef void (^LicenseCompletion)(BOOL, NSString *);

// UIKit is resolved at runtime so the license network tests can run on macOS.
@interface NSObject (MizzeDeviceIdentity)
+ (id)currentDevice;
- (NSUUID *)identifierForVendor;
@end

@interface LicenseSession () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate> {
    LicenseEvents::Parser _events;
}
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
@property(nonatomic,copy) NSString *deviceHash;
@property(nonatomic,assign) BOOL attemptedBinding;
@property(nonatomic,assign) BOOL allowBinding;
@property(nonatomic,strong) NSURLSession *eventSession;
@property(nonatomic,strong) NSURLSessionDataTask *eventTask;
@property(nonatomic,copy) NSString *eventHash;
@property(nonatomic,assign) NSUInteger eventGeneration;
@property(nonatomic,assign) BOOL eventDirty;
@property(nonatomic,assign) BOOL recoverPending;
@property(nonatomic,assign) BOOL retryBinding;
@property(atomic,assign,readwrite) BOOL locked;
@property(nonatomic,assign) NSTimeInterval lockRetryAt;
@end

@implementation LicenseSession

NSNotificationName const LicenseSessionDidBecomeUnauthorizedNotification = @"LicenseSessionDidBecomeUnauthorizedNotification";
NSNotificationName const LicenseSessionDidBecomeAuthorizedNotification = @"LicenseSessionDidBecomeAuthorizedNotification";

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
#ifdef MIZZE_INJECTED
        // The game bundle need not contain the companion app's resources.
        self.config = @{@"DatabaseURL":MizzeDefaultLicenseDatabaseURL()};
#endif
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
        NSURLSessionConfiguration *events=[configuration copy];
        events.timeoutIntervalForRequest=60;events.timeoutIntervalForResource=86400;
        self.eventSession=[NSURLSession sessionWithConfiguration:events delegate:self delegateQueue:NSOperationQueue.mainQueue];
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
    return LicenseSessionPolicy::Authorized(self.validUntilUptime, NSProcessInfo.processInfo.systemUptime);
}

- (BOOL)hasSavedKey {
    NSString *hash = [NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"];
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    return hash.length == 64 && [hash rangeOfCharacterFromSet:nonHex].location == NSNotFound;
}

- (NSString *)hash:(NSString *)value {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}

- (NSString *)currentDeviceHash {
    if (self.deviceHash.length == 64) return self.deviceHash;
    NSDictionary *query=@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:@"com.dts.mizze.device.v1",(__bridge id)kSecAttrAccount:@"identity",
        (__bridge id)kSecReturnData:@YES,(__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne};
    CFTypeRef result=nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query,&result)==errSecSuccess) {
        id stored=CFBridgingRelease(result);
        NSString *cached=[stored isKindOfClass:NSData.class] ? [[NSString alloc] initWithData:stored encoding:NSUTF8StringEncoding] : nil;
        NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
        if (cached.length==64 && [cached rangeOfCharacterFromSet:invalid].location==NSNotFound)
            return self.deviceHash=cached;
    }
    Class deviceClass=NSClassFromString(@"UIDevice");
    id device=[deviceClass currentDevice];
    NSUUID *vendor=[device identifierForVendor];
    if (![vendor isKindOfClass:NSUUID.class]) return nil;
    NSString *identity=[self hash:[@"mizze-device-v1:" stringByAppendingString:vendor.UUIDString]];
    NSMutableDictionary *save=[query mutableCopy];
    [save removeObjectForKey:(__bridge id)kSecReturnData];
    [save removeObjectForKey:(__bridge id)kSecMatchLimit];
    save[(__bridge id)kSecValueData]=[identity dataUsingEncoding:NSUTF8StringEncoding];
    save[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    save[(__bridge id)kSecAttrSynchronizable]=@NO;
    SecItemAdd((__bridge CFDictionaryRef)save,nullptr);
    return self.deviceHash=identity;
}

- (NSURL *)databaseURLForHash:(NSString *)licenseHash {
    NSString *base = [self.config[@"DatabaseURL"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/licensesV3/%@.json", base, licenseHash]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    if(task==self.eventTask&&response.statusCode==307){
        NSURL *origin=[NSURL URLWithString:self.config[@"DatabaseURL"]],*next=request.URL;
        // Firebase streaming can move to another shard of the same database.
        NSString *database=[origin.host componentsSeparatedByString:@"."].firstObject;
        BOOL firebaseHost=[next.host hasSuffix:@".firebaseio.com"]||[next.host hasSuffix:@".firebasedatabase.app"];
        BOOL sameDatabase=[[next.host componentsSeparatedByString:@"."].firstObject isEqualToString:database]||
            [[NSURLComponents componentsWithURL:next resolvingAgainstBaseURL:NO].queryItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == 'ns' AND value == %@",database]].count>0;
        if([next.scheme isEqualToString:@"https"]&&!next.user&&!next.password&&firebaseHost&&sameDatabase){
            NSMutableURLRequest *redirect=[request mutableCopy];[redirect setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
            completionHandler(redirect);return;
        }
    }
    completionHandler(nil);
}

- (void)stopTimers {
    [self.timer invalidate]; self.timer = nil;
    [self.leaseTimer invalidate]; self.leaseTimer = nil;
}

- (void)revokeWithMessage:(NSString *)message reason:(NSString *)reason {
    BOOL notify = self.hadAuthorizedSession||(self.locked&&![self.lastMessage isEqualToString:message]);
    self.hadAuthorizedSession = NO;
    self.validUntilUptime = 0;
    self.expiresAt = 0;
    self.lastMessage = message;
    self.lastReason = reason;
    self.locked=[reason isEqualToString:@"locked"];
    if ([@[@"missing", @"disabled", @"expired", @"invalid_record", @"device_mismatch", @"invalid_binding", @"binding_released"] containsObject:reason])
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
    [self stopTimers];
    if(self.locked){[self monitor];[self watchSavedKey];}
    else if(!self.hasSavedKey){self.recoverPending=NO;self.retryBinding=NO;[self stopWatching];}
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
    BOOL recovered=valid&&self.recoverPending;
    if (valid) {
        if (![[NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"] isEqualToString:licenseHash]) {
            [NSUserDefaults.standardUserDefaults setObject:licenseHash forKey:@"LicenseHash"];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        self.validUntilUptime = deadline;
        [NSUserDefaults.standardUserDefaults setInteger:3 forKey:@"LicenseSavedProtocolVersion"];
        self.expiresAt = expiry;
        self.hadAuthorizedSession = YES;
        self.lastMessage = message;
        self.lastReason = @"valid";
        self.locked=NO;self.lockRetryAt=0;
        [self scheduleLeaseExpiry];
    } else if (transient && (self.authorized||self.locked)) {
        // Keep only the time granted by the last successful server response.
        // Retries and failed requests must never extend this deadline.
        self.lastMessage = message;
        self.lastReason = reason;
    } else {
        if([reason isEqualToString:@"locked"]){
            [NSUserDefaults.standardUserDefaults setObject:licenseHash forKey:@"LicenseHash"];
            self.recoverPending=YES;
            self.retryBinding=self.retryBinding||self.allowBinding;
        }
        [self revokeWithMessage:message reason:reason];
    }
    for (LicenseCompletion callback in callbacks) callback(valid, message);
    if(valid){[self watchSavedKey];[self monitor];}
    if(recovered){self.recoverPending=NO;self.retryBinding=NO;[NSNotificationCenter.defaultCenter postNotificationName:LicenseSessionDidBecomeAuthorizedNotification object:self];}
    if(self.eventDirty){self.eventDirty=NO;dispatch_async(dispatch_get_main_queue(),^{[self refresh:nil];});}
}

- (void)claimHash:(NSString *)licenseHash generation:(NSUInteger)generation {
    if (generation != self.generation || !self.busy) return;
    if (self.attemptedBinding) {
        [self finishHash:licenseHash deadline:0 expiry:0 message:@"Máy chủ chưa cho phép khóa máy. Người cấp key cần cập nhật Firebase Rules."
            reason:@"binding_unavailable" transient:NO];return;
    }
    self.attemptedBinding=YES;
    NSString *url=[[self databaseURLForHash:licenseHash].absoluteString stringByReplacingOccurrencesOfString:@".json" withString:@"/binding.json"];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod=@"PUT";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    // Firebase atomically accepts only the first write to an empty binding.
    [request setValue:@"null_etag" forHTTPHeaderField:@"if-match"];
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"deviceHash":self.deviceHash,
        @"version":@1,@"claimedAt":@{@".sv":@"timestamp"}} options:0 error:nil];
    self.activeTask=[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation || !self.busy) return;
            self.activeTask=nil;
            // A lost response or a competing first activation must be checked by
            // reading the server record. Never grant a lease from a PUT response.
            if (error || http.statusCode==200 || http.statusCode==204 || http.statusCode==412 ||
                http.statusCode==401 || http.statusCode==403 ||
                LicenseSessionPolicy::RetryableStatus(http.statusCode)) {
                [self readHash:licenseHash generation:generation attempt:0];return;
            }
            [self finishHash:licenseHash deadline:0 expiry:0
                message:@"Chưa gắn được key với máy. Người cấp key cần cập nhật Firebase Rules."
                reason:@"binding_denied" transient:NO];
        });
    }];
    [self.activeTask resume];
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
        BOOL needsBinding=NO;NSTimeInterval lockRetry=0;
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
                    BOOL awaitingMigration=[[NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"] isEqualToString:licenseHash]&&
                        [NSUserDefaults.standardUserDefaults integerForKey:@"LicenseSavedProtocolVersion"]<3;
                    message=awaitingMigration ? @"Key cũ đang chờ chuyển sang bản mới. Admin cần bấm Áp dụng Rules trên web key." : @"Key không tồn tại hoặc đã bị xóa.";
                    reason=awaitingMigration ? @"migration_pending" : @"missing";
                } else if (!record || !enabledIsBoolean || !expiryIsNumber || ![record[@"protocol"] isEqual:@3]) {
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
                    NSTimeInterval lockServerNow=serverDate?serverDate.timeIntervalSince1970:serverNow;
                    expiry = [expiryValue doubleValue] / 1000.0;
                    deadline = LicenseSessionPolicy::Deadline(requestStarted, [expiryValue doubleValue], serverNow);
                    BOOL valid = LicenseSessionPolicy::Authorized(deadline, NSProcessInfo.processInfo.systemUptime);
                    message = valid ? @"Đã xác thực." : @"Key đã hết hạn.";
                    reason = valid ? @"valid" : @"expired";
                    if (valid) {
                        id binding=record[@"binding"];
                        NSDictionary *bound=[binding isKindOfClass:NSDictionary.class] ? binding : nil;
                        id boundVersion=bound[@"version"], boundTime=bound[@"claimedAt"];
                        BOOL validBinding=[bound[@"deviceHash"] isKindOfClass:NSString.class] &&
                            [bound[@"deviceHash"] length]==64 && [boundVersion isKindOfClass:NSNumber.class] &&
                            CFGetTypeID((__bridge CFTypeRef)boundVersion)!=CFBooleanGetTypeID() && [boundVersion isEqual:@1] &&
                            [boundTime isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)boundTime)!=CFBooleanGetTypeID() &&
                            std::isfinite([boundTime doubleValue]) && [boundTime doubleValue]>0;
                        if (!binding || binding==NSNull.null) {
                            needsBinding=self.allowBinding;deadline=0;
                            message=@"Key đã được gỡ máy. Vui lòng đăng nhập lại.";reason=@"binding_released";
                        } else if (!validBinding) {
                            deadline=0;message=@"Dữ liệu khóa máy không hợp lệ. Liên hệ người cấp key.";reason=@"invalid_binding";
                        } else if (![binding[@"deviceHash"] isEqualToString:self.deviceHash]) {
                            deadline=0;message=@"Key này đã được kích hoạt trên máy khác.";reason=@"device_mismatch";
                        }
                    }
                    if([reason isEqualToString:@"valid"]||needsBinding){
                        id lockValue=record[@"lock"];
                        if(lockValue&&lockValue!=NSNull.null){
                            NSDictionary *lock=[lockValue isKindOfClass:NSDictionary.class]?lockValue:nil;
                            id until=lock[@"until"],notice=lock[@"message"];
                            BOOL wellFormed=[until isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)until)!=CFBooleanGetTypeID()&&
                                std::isfinite([until doubleValue])&&[until doubleValue]>=0&&[notice isKindOfClass:NSString.class]&&[notice length]<=500;
                            if(!wellFormed){deadline=0;needsBinding=NO;message=@"Dữ liệu khóa key không hợp lệ.";reason=@"invalid_record";}
                            else if([until doubleValue]==0||[until doubleValue]/1000.0>lockServerNow){
                                deadline=0;reason=@"locked";needsBinding=NO;
                                message=[notice length]?notice:@"Key đang bị khóa. Liên hệ admin.";
                                if([until doubleValue]>0){
                                    NSDateFormatter *display=[NSDateFormatter new];display.dateFormat=@"HH:mm dd/MM/yyyy";
                                    message=[message stringByAppendingFormat:@"\nTự mở: %@",[display stringFromDate:[NSDate dateWithTimeIntervalSince1970:[until doubleValue]/1000.0]]];
                                    lockRetry=requestStarted+MAX(.1,[until doubleValue]/1000.0-lockServerNow);
                                }
                            }
                        }
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.generation || !self.busy) return;
            self.activeTask = nil;
            self.lockRetryAt=lockRetry;
            if (needsBinding) { [self claimHash:licenseHash generation:generation]; return; }
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
    if (![self currentDeviceHash]) {
        NSString *message=@"Chưa đọc được mã thiết bị. Mở khóa iPhone rồi thử lại.";
        [self revokeWithMessage:message reason:@"device_unavailable"];
        if (completion) completion(NO,message);return;
    }
    if (completion) [self.completions addObject:[completion copy]];
    self.busy = YES;
    self.attemptedBinding=NO;
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
    [self stopWatching];self.locked=NO;self.recoverPending=NO;self.retryBinding=NO;
    ++self.generation;
    self.allowBinding=YES;
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
    self.allowBinding=(self.recoverPending&&self.retryBinding)||
        [NSUserDefaults.standardUserDefaults integerForKey:@"LicenseSavedProtocolVersion"]<3;
    [self beginHash:licenseHash completion:completion];
}

- (void)monitor {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self monitor]; }); return;
    }
    if (self.timer || (!self.authorized&&!self.locked)) return;
    __weak LicenseSession *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:LicenseSessionPolicy::RefreshSeconds repeats:YES block:^(NSTimer *timer) {
        LicenseSession *strongSelf = weakSelf;
        if (!strongSelf) return;
        if(strongSelf.locked){[strongSelf refresh:nil];return;}
        if (!strongSelf.authorized) { [strongSelf leaseExpired]; return; }
        [strongSelf refresh:nil];
    }];
    // Default-mode timers stop during touch tracking; both timers must keep
    // running while the user drags a slider or the floating menu button.
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    if(self.locked&&self.lockRetryAt>0){
        __weak LicenseSession *retrySelf=self;
        self.leaseTimer=[NSTimer timerWithTimeInterval:MAX(.1,self.lockRetryAt-NSProcessInfo.processInfo.systemUptime) repeats:NO block:^(NSTimer *timer){[retrySelf refresh:nil];}];
        [NSRunLoop.mainRunLoop addTimer:self.leaseTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopWatching {
    ++self.eventGeneration;[self.eventTask cancel];self.eventTask=nil;
    self.eventHash=nil;self.eventDirty=NO;_events.pending.clear();
}
- (void)watchSavedKey {
    if(!self.hasSavedKey||![self configured])return;
    NSString *hash=[NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"];
    if(self.eventTask&&[self.eventHash isEqualToString:hash])return;
    [self stopWatching];self.eventHash=hash;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[self databaseURLForHash:hash]];
    [request setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    self.eventTask=[self.eventSession dataTaskWithRequest:request];[self.eventTask resume];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    if(task!=self.eventTask){completion(NSURLSessionResponseAllow);return;}
    const NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)response).statusCode:0;
    completion(status==200?NSURLSessionResponseAllow:NSURLSessionResponseCancel);
    if(status==401||status==403){[self stopWatching];[self revokeWithMessage:@"Key hoặc phiên bản này không còn được cấp quyền." reason:@"missing"];}
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if(task!=self.eventTask)return;
    const unsigned result=_events.Feed((const char *)data.bytes,data.length);
    if(result&LicenseEvents::Parser::Denied){[self stopWatching];[self revokeWithMessage:@"Key hoặc phiên bản này không còn được cấp quyền." reason:@"missing"];return;}
    if(result&LicenseEvents::Parser::Reconnect){[self.eventTask cancel];return;}
    if(!(result&LicenseEvents::Parser::Refresh))return;
    // Check the initial snapshot too: an admin edit can occur between GET and
    // subscribing. Never lose an invalidation while a read is in flight.
    if(self.busy)self.eventDirty=YES;else [self refresh:nil];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(task!=self.eventTask)return;
    self.eventTask=nil;const NSUInteger generation=self.eventGeneration;
    __weak LicenseSession *weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        LicenseSession *owner=weakSelf;if(owner&&generation==owner.eventGeneration&&owner.hasSavedKey)[owner watchSavedKey];
    });
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
    self.locked=NO;self.recoverPending=NO;self.retryBinding=NO;[self stopWatching];
    [self stopTimers];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseSavedProtocolVersion"];
    for (LicenseCompletion callback in callbacks) callback(NO, self.lastMessage);
}

@end
