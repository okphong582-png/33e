#import "LicenseSession.h"
#import <CommonCrypto/CommonDigest.h>

@interface LicenseSession () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSDictionary *config;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) NSTimeInterval validUntilUptime;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,assign) NSUInteger generation;
@end

@implementation LicenseSession

+ (instancetype)shared {
    static LicenseSession *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [LicenseSession new]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSString *path = [NSBundle.mainBundle pathForResource:@"AuthConfig" ofType:@"plist"];
        self.config = path ? [NSDictionary dictionaryWithContentsOfFile:path] : @{};
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.URLCache = nil;
        configuration.HTTPCookieStorage = nil;
        configuration.URLCredentialStorage = nil;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForRequest = 12;
        configuration.timeoutIntervalForResource = 15;
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
    }
    return self;
}

- (BOOL)configured {
    NSURL *url = [NSURL URLWithString:self.config[@"DatabaseURL"] ?: @""];
    return [url.scheme isEqualToString:@"https"] && url.host.length && !url.user && !url.password && !url.query && !url.fragment;
}

- (BOOL)authorized { return NSProcessInfo.processInfo.systemUptime < self.validUntilUptime; }

- (NSString *)hash:(NSString *)value {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:64];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}

- (NSURL *)databaseURLForPath:(NSString *)path {
    NSString *base = [self.config[@"DatabaseURL"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@.json", base, path]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler { completionHandler(nil); }

- (void)request:(NSURL *)url method:(NSString *)method body:(id)body done:(void (^)(id, NSInteger))done {
    if (!url || ![url.scheme isEqualToString:@"https"]) { done(nil, 0); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    [request setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    if (body) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingFragmentsAllowed error:nil];
    }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        id object = (!error && data.length <= 32768) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        done(object, status);
    }] resume];
}

- (void)readLicense:(NSString *)licenseHash done:(void (^)(BOOL, NSTimeInterval))done {
    [self request:[self databaseURLForPath:[NSString stringWithFormat:@"licenses/%@", licenseHash]] method:@"GET" body:nil done:^(id object, NSInteger status) {
        NSDictionary *record = [object isKindOfClass:NSDictionary.class] ? object : nil;
        NSTimeInterval expiry = [record[@"expiresAt"] doubleValue] / 1000.0;
        BOOL valid = status == 200 && [record[@"enabled"] boolValue] && expiry > NSDate.date.timeIntervalSince1970;
        done(valid, valid ? expiry : 0);
    }];
}

- (void)loginWithKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    if (self.busy) { completion(NO, @"Đang kiểm tra yêu cầu trước."); return; }
    if (![self configured]) { completion(NO, @"Chưa cấu hình Realtime Database."); return; }
    NSString *normalized = [[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (normalized.length < 8 || normalized.length > 128) { completion(NO, @"Key không hợp lệ."); return; }
    [self.timer invalidate]; self.timer = nil; self.busy = YES; self.validUntilUptime = 0;
    NSUInteger generation = ++self.generation;
    NSString *licenseHash = [self hash:normalized];
    [self readLicense:licenseHash done:^(BOOL valid, NSTimeInterval expiry) {
        if (generation != self.generation) return;
        self.busy = NO;
        if (!valid) { completion(NO, @"Key không tồn tại, đã tắt hoặc hết hạn."); return; }
        [[NSUserDefaults standardUserDefaults] setObject:licenseHash forKey:@"LicenseHash"];
        self.validUntilUptime = NSProcessInfo.processInfo.systemUptime + MIN(100, expiry - NSDate.date.timeIntervalSince1970);
        completion(YES, @"Đã xác thực.");
    }];
}

- (void)refresh:(void (^)(BOOL, NSString *))completion {
    if (self.busy) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self refresh:completion]; }); return; }
    if (![self configured]) { self.validUntilUptime = 0; if (completion) completion(NO, @"Chưa cấu hình Realtime Database."); return; }
    NSString *licenseHash = [[NSUserDefaults standardUserDefaults] stringForKey:@"LicenseHash"];
    if (licenseHash.length != 64) { self.validUntilUptime = 0; if (completion) completion(NO, @"Vui lòng nhập key."); return; }
    self.busy = YES; NSUInteger generation = self.generation;
    [self readLicense:licenseHash done:^(BOOL valid, NSTimeInterval expiry) {
        if (generation != self.generation) return;
        self.busy = NO;
        self.validUntilUptime = valid ? NSProcessInfo.processInfo.systemUptime + MIN(100, expiry - NSDate.date.timeIntervalSince1970) : 0;
        if (completion) completion(valid, valid ? @"Đã xác thực." : @"Key đã hết hạn hoặc bị thu hồi.");
    }];
}

- (void)monitor { if (!self.timer) self.timer = [NSTimer scheduledTimerWithTimeInterval:40 repeats:YES block:^(NSTimer *timer) { [self refresh:nil]; }]; }

- (void)logout {
    ++self.generation; self.busy = NO; self.validUntilUptime = 0; [self.timer invalidate]; self.timer = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"LicenseHash"];
}

@end
