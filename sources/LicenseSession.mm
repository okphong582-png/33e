#import "LicenseSession.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

@interface LicenseSession ()
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSDictionary *config;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) NSTimeInterval validUntilUptime;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,assign) NSUInteger generation;
@end

@implementation LicenseSession
+ (instancetype)shared { static LicenseSession *x; static dispatch_once_t once; dispatch_once(&once, ^{ x=[LicenseSession new]; }); return x; }
- (instancetype)init {
    if ((self=[super init])) {
        NSString *p=[NSBundle.mainBundle pathForResource:@"AuthConfig" ofType:@"plist"];
        self.config=p ? [NSDictionary dictionaryWithContentsOfFile:p] : @{};
        NSURLSessionConfiguration *c=[NSURLSessionConfiguration ephemeralSessionConfiguration];
        c.URLCache=nil; c.HTTPCookieStorage=nil; c.URLCredentialStorage=nil;
        c.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
        c.timeoutIntervalForRequest=12; c.timeoutIntervalForResource=15;
        self.session=[NSURLSession sessionWithConfiguration:c delegate:self delegateQueue:NSOperationQueue.mainQueue];
    }
    return self;
}
- (BOOL)configured {
    NSURL *u=[NSURL URLWithString:self.config[@"DatabaseURL"] ?: @""];
    return [u.scheme isEqualToString:@"https"] && u.host.length && !u.user && !u.password && !u.query && !u.fragment && [self.config[@"FirebaseAPIKey"] length]>=20;
}
- (BOOL)authorized { return NSProcessInfo.processInfo.systemUptime < self.validUntilUptime; }
- (NSMutableDictionary *)query:(NSString *)account {
    return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService:@"com.dts.bugchi.license",
              (__bridge id)kSecAttrAccessGroup:@"com.dts.bugchi",
              (__bridge id)kSecAttrAccount:account} mutableCopy];
}
- (NSData *)load:(NSString *)account {
    NSMutableDictionary *q=[self query:account]; q[(__bridge id)kSecReturnData]=@YES; CFTypeRef out=NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q,&out)!=errSecSuccess) return nil;
    return CFBridgingRelease(out);
}
- (BOOL)save:(NSData *)data account:(NSString *)account {
    NSMutableDictionary *q=[self query:account];
    NSDictionary *a=@{(__bridge id)kSecValueData:data,(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
    OSStatus s=SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)a);
    if(s==errSecItemNotFound){[q addEntriesFromDictionary:a];s=SecItemAdd((__bridge CFDictionaryRef)q,NULL);}
    return s==errSecSuccess;
}
- (void)remove:(NSString *)account { SecItemDelete((__bridge CFDictionaryRef)[self query:account]); }
- (NSString *)hash:(NSString *)value {
    NSData *d=[value dataUsingEncoding:NSUTF8StringEncoding]; uint8_t out[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(d.bytes,(CC_LONG)d.length,out);
    NSMutableString *s=[NSMutableString stringWithCapacity:64]; for(NSUInteger i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [s appendFormat:@"%02x",out[i]]; return s;
}
- (NSString *)encoded:(NSString *)s { return [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]; }
- (NSURL *)firebase:(NSString *)host path:(NSString *)path {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@?key=%@",host,path,[self encoded:self.config[@"FirebaseAPIKey"] ?: @""]]];
}
- (NSURL *)database:(NSString *)path token:(NSString *)token {
    NSString *base=[self.config[@"DatabaseURL"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@.json?auth=%@",base,path,[self encoded:token ?: @""]]];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))done { done(nil); }
- (void)request:(NSURL *)url method:(NSString *)method body:(id)body done:(void (^)(id,NSInteger))done {
    if(!url || ![url.scheme isEqualToString:@"https"]){done(nil,0);return;}
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url]; r.HTTPMethod=method;
    [r setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    if(body){[r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:NSJSONWritingFragmentsAllowed error:nil];}
    [[self.session dataTaskWithRequest:r completionHandler:^(NSData *d,NSURLResponse *resp,NSError *e){
        NSInteger status=[resp isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)resp).statusCode:0;
        id obj=(!e&&d.length<=32768)?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil; done(obj,status);
    }] resume];
}
- (void)refreshToken:(NSString *)refresh done:(void (^)(NSDictionary *,NSInteger))done {
    NSURL *u=[self firebase:@"securetoken.googleapis.com" path:@"v1/token"]; NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:u]; r.HTTPMethod=@"POST";
    [r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody=[[NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@",[self encoded:refresh ?: @""]] dataUsingEncoding:NSUTF8StringEncoding];
    [[self.session dataTaskWithRequest:r completionHandler:^(NSData *d,NSURLResponse *resp,NSError *e){
        NSInteger status=[resp isKindOfClass:NSHTTPURLResponse.class]?((NSHTTPURLResponse *)resp).statusCode:0;
        id obj=(!e&&d.length<=32768)?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil; done([obj isKindOfClass:NSDictionary.class]?obj:nil,status);
    }] resume];
}
- (NSDictionary *)tokens {
    NSData *d=[self load:@"tokens"]; id x=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
    return [x isKindOfClass:NSDictionary.class]?x:@{};
}
- (void)readLicense:(NSString *)hash uid:(NSString *)uid token:(NSString *)token done:(void (^)(BOOL,NSTimeInterval))done {
    [self request:[self database:[NSString stringWithFormat:@"licenses/%@",hash] token:token] method:@"GET" body:nil done:^(id object,NSInteger status){
        NSDictionary *record=[object isKindOfClass:NSDictionary.class]?object:nil; NSTimeInterval expiry=[record[@"expiresAt"] doubleValue]/1000.0;
        NSString *owner=[record[@"ownerUid"] isKindOfClass:NSString.class]?record[@"ownerUid"]:nil;
        BOOL valid=status==200 && [record[@"enabled"] boolValue] && expiry>NSDate.date.timeIntervalSince1970 && (!owner.length||[owner isEqualToString:uid]);
        if(!valid){done(NO,0);return;} if(owner.length){done(YES,expiry);return;}
        [self request:[self database:[NSString stringWithFormat:@"licenses/%@/ownerUid",hash] token:token] method:@"PUT" body:uid done:^(id ignored,NSInteger claimStatus){
            if(claimStatus!=200){done(NO,0);return;} [self readLicense:hash uid:uid token:token done:done];
        }];
    }];
}
- (void)loginWithKey:(NSString *)key completion:(void (^)(BOOL,NSString *))completion {
    if(self.busy){completion(NO,@"Đang kiểm tra yêu cầu trước.");return;}
    if(![self configured]){completion(NO,@"Chưa cấu hình Firebase.");return;}
    NSString *normalized=[[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if(normalized.length<8||normalized.length>128){completion(NO,@"Key không hợp lệ.");return;}
    [self.timer invalidate];self.timer=nil;[self remove:@"tokens"];self.busy=YES;self.validUntilUptime=0;NSUInteger generation=++self.generation;
    [self request:[self firebase:@"identitytoolkit.googleapis.com" path:@"v1/accounts:signUp"] method:@"POST" body:@{@"returnSecureToken":@YES} done:^(id object,NSInteger status){
        if(generation!=self.generation)return; NSDictionary *d=[object isKindOfClass:NSDictionary.class]?object:nil;
        NSString *idToken=d[@"idToken"],*uid=d[@"localId"],*refresh=d[@"refreshToken"];
        if(!idToken.length||!uid.length||!refresh.length){self.busy=NO;completion(NO,@"Firebase Anonymous Auth chưa bật hoặc không kết nối được.");return;}
        NSString *hash=[self hash:normalized];
        [self readLicense:hash uid:uid token:idToken done:^(BOOL valid,NSTimeInterval expiry){
            if(generation!=self.generation)return;self.busy=NO;
            if(!valid){completion(NO,@"Key không hợp lệ, hết hạn hoặc đã gắn thiết bị khác.");return;}
            NSDictionary *stored=@{@"idToken":idToken,@"refreshToken":refresh,@"uid":uid,@"licenseHash":hash,@"expires":@(NSDate.date.timeIntervalSince1970+3000)};
            if(![self save:[NSJSONSerialization dataWithJSONObject:stored options:0 error:nil] account:@"tokens"]){completion(NO,@"Không lưu được phiên.");return;}
            self.validUntilUptime=NSProcessInfo.processInfo.systemUptime+MIN(100,expiry-NSDate.date.timeIntervalSince1970);completion(YES,@"Đã xác thực.");
        }];
    }];
}
- (void)refresh:(void (^)(BOOL,NSString *))completion {
    if(self.busy){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self refresh:completion];});return;}
    if(![self configured]){self.validUntilUptime=0;if(completion)completion(NO,@"Chưa cấu hình Firebase.");return;}
    NSDictionary *t=[self tokens];NSString *refresh=t[@"refreshToken"],*uid=t[@"uid"],*hash=t[@"licenseHash"];
    if(!refresh.length||!uid.length||hash.length!=64){self.validUntilUptime=0;if(completion)completion(NO,@"Vui lòng nhập key.");return;}
    self.busy=YES;NSUInteger generation=self.generation;
    void (^verify)(NSString *)=^(NSString *idToken){[self readLicense:hash uid:uid token:idToken done:^(BOOL valid,NSTimeInterval expiry){
        if(generation!=self.generation)return;self.busy=NO;self.validUntilUptime=valid?NSProcessInfo.processInfo.systemUptime+MIN(100,expiry-NSDate.date.timeIntervalSince1970):0;
        if(completion)completion(valid,valid?@"Đã xác thực.":@"Key đã hết hạn hoặc bị thu hồi.");
    }];};
    if([t[@"expires"] doubleValue]>NSDate.date.timeIntervalSince1970&&[t[@"idToken"] isKindOfClass:NSString.class]){verify(t[@"idToken"]);return;}
    [self refreshToken:refresh done:^(NSDictionary *d,NSInteger status){if(generation!=self.generation)return;NSString *idToken=d[@"id_token"],*newRefresh=d[@"refresh_token"]?:refresh;
        if(!idToken.length){self.busy=NO;self.validUntilUptime=0;if(completion)completion(NO,@"Phiên Firebase hết hạn.");return;}
        NSDictionary *u=@{@"idToken":idToken,@"refreshToken":newRefresh,@"uid":uid,@"licenseHash":hash,@"expires":@(NSDate.date.timeIntervalSince1970+3000)};
        [self save:[NSJSONSerialization dataWithJSONObject:u options:0 error:nil] account:@"tokens"];verify(idToken);
    }];
}
- (void)monitor {if(!self.timer)self.timer=[NSTimer scheduledTimerWithTimeInterval:40 repeats:YES block:^(NSTimer *timer){[self refresh:nil];}];}
- (void)logout {++self.generation;self.busy=NO;self.validUntilUptime=0;[self.timer invalidate];self.timer=nil;[self remove:@"tokens"];}
@end
