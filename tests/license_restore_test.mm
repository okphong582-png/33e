#import <Foundation/Foundation.h>
#import "../sources/LicenseSession.h"
#include <cassert>
#ifdef MIZZE_INJECTED
#import "../sources/InjectedProtection.h"
#endif

static NSInteger mode = 0; // valid, missing, offline, expired, race, denied, invalid binding, old protocol
static NSDictionary *serverBinding;
static NSUInteger claims;
@class LicenseTestProtocol;
static NSDictionary *serverLock;
static LicenseTestProtocol *streamProtocol;
static BOOL streamEventsEnabled;
@interface LicenseTestProtocol : NSURLProtocol
@end
@implementation LicenseTestProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqualToString:@"license.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    assert([self.request.URL.path hasPrefix:@"/licensesV3/"]);
    if([[self.request valueForHTTPHeaderField:@"Accept"] isEqualToString:@"text/event-stream"]){
        streamProtocol=self;
        NSHTTPURLResponse *response=[[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":@"text/event-stream"}];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        if(streamEventsEnabled)[self.client URLProtocol:self didLoadData:[@"event: put\ndata: {}\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }
    if (mode == 2) {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
        return;
    }
    NSInteger status=200;
    if ([self.request.HTTPMethod isEqual:@"PUT"]) {
        assert([self.request.URL.path hasSuffix:@"/binding.json"]);
        assert([[self.request valueForHTTPHeaderField:@"if-match"] isEqual:@"null_etag"]);
        NSData *body=self.request.HTTPBody;
        if (!body && self.request.HTTPBodyStream) {
            NSInputStream *stream=self.request.HTTPBodyStream;[stream open];
            NSMutableData *bytes=[NSMutableData data];uint8_t buffer[1024];NSInteger count;
            while((count=[stream read:buffer maxLength:sizeof(buffer)])>0)[bytes appendBytes:buffer length:count];
            [stream close];body=bytes;
        }
        NSDictionary *binding=[NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
        assert([binding[@"claimedAt"] isEqual:@{@".sv":@"timestamp"}]);
        if (mode==5)status=403;
        else if (mode==4) {
            serverBinding=@{@"deviceHash":[@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0],@"version":@1,@"claimedAt":@1};status=412;
        } else if (serverBinding) status=412;
        else {
            serverBinding=@{@"deviceHash":binding[@"deviceHash"],@"version":@1,@"claimedAt":@(NSDate.date.timeIntervalSince1970*1000)};
            ++claims;
        }
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    NSMutableDictionary *license=[@{@"enabled":@YES,@"protocol":mode==7 ? @2 : @3,
        @"expiresAt":@((NSDate.date.timeIntervalSince1970 + (mode == 3 ? -60 : 3600)) * 1000)} mutableCopy];
    if (serverBinding) license[@"binding"]=serverBinding;
    if(serverLock)license[@"lock"]=serverLock;
    if (mode==6)license[@"binding"]=@{@"deviceHash":@"broken",@"version":@1};
    id record = mode == 1 ? (id)NSNull.null : (id)license;
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingFragmentsAllowed error:nil];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {if(streamProtocol==self)streamProtocol=nil;}
@end

static LicenseSession *NewSession() {
    LicenseSession *session = [LicenseSession new];
    [(NSURLSession *)[session valueForKey:@"session"] invalidateAndCancel];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.protocolClasses = @[LicenseTestProtocol.class];
    [session setValue:[NSURLSession sessionWithConfiguration:configuration] forKey:@"session"];
    [(NSURLSession *)[session valueForKey:@"eventSession"] invalidateAndCancel];
    [session setValue:[NSURLSession sessionWithConfiguration:configuration delegate:(id<NSURLSessionDelegate>)session delegateQueue:NSOperationQueue.mainQueue] forKey:@"eventSession"];
    [session setValue:@{@"DatabaseURL":@"https://license.test"} forKey:@"config"];
    [session setValue:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0] forKey:@"deviceHash"];
    return session;
}
static void Verify(LicenseSession *session, BOOL login, BOOL expected) {
    __block BOOL finished = NO;
    void (^completion)(BOOL, NSString *) = ^(BOOL ok, NSString *) {
        assert(ok == expected); finished = YES;
    };
    if (login) [session loginWithKey:@"TEST-RESTORE-1234" completion:completion];
    else [session refresh:completion];
    const NSTimeInterval end = NSProcessInfo.processInfo.systemUptime + 5;
    while (!finished && NSProcessInfo.processInfo.systemUptime < end)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(finished);
}
static void Event(NSString *event) {
    assert(streamProtocol);
    [streamProtocol.client URLProtocol:streamProtocol didLoadData:[event dataUsingEncoding:NSUTF8StringEncoding]];
}
static void WaitState(LicenseSession *session,BOOL locked,BOOL authorized){
    const double end=NSProcessInfo.processInfo.systemUptime+3;
    while((session.locked!=locked||session.authorized!=authorized)&&NSProcessInfo.processInfo.systemUptime<end)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    assert(session.locked==locked&&session.authorized==authorized);
}
int main() {
    @autoreleasepool {
#ifdef MIZZE_INJECTED
        assert([MizzeDefaultLicenseDatabaseURL() isEqualToString:@"https://appchatai-313e3-default-rtdb.firebaseio.com"]);
#endif
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
        LicenseSession *first = NewSession();
        assert(!first.hasSavedKey && !first.authorized);
        Verify(first, YES, YES);
        assert(claims==1 && serverBinding);
        assert(first.hasSavedKey && first.authorized);
        LicenseSession *reopened = NewSession();
        assert(reopened.hasSavedKey && !reopened.authorized); // Cache grants no access.
        mode = 2; Verify(reopened, NO, NO);
        assert(reopened.hasSavedKey && !reopened.authorized); // Offline preserves retry only.
        mode = 0; Verify(reopened, NO, YES);
        assert(claims==1);
        assert(reopened.authorized);
        mode = 1; Verify(reopened, NO, NO);
        assert(!reopened.hasSavedKey && !reopened.authorized);
        mode = 0; Verify(reopened, YES, YES);
        mode = 3; Verify(reopened, NO, NO);
        assert(!reopened.hasSavedKey && !reopened.authorized);
        mode = 0; Verify(reopened, YES, YES);
        serverBinding=nil;Verify(reopened,NO,NO);assert(!reopened.authorized && claims==1);
        Verify(reopened,YES,YES);assert(claims==2);
        [reopened logout];
        assert(!reopened.hasSavedKey && !reopened.authorized);
        [first logout];
        LicenseSession *other=NewSession();
        [other setValue:[@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0] forKey:@"deviceHash"];
        Verify(other,YES,NO);assert(!other.authorized && !other.hasSavedKey && claims==2);
        assert([other.lastMessage containsString:@"máy khác"]);
        serverBinding=nil;mode=4;Verify(first,YES,NO);assert(!first.authorized);
        serverBinding=nil;mode=5;Verify(first,YES,NO);assert(!first.authorized);
        mode=6;Verify(first,YES,NO);assert(!first.authorized);
        mode=7;Verify(first,YES,NO);assert(!first.authorized && claims==2);
        mode=0;serverBinding=nil;streamProtocol=nil;streamEventsEnabled=YES;Verify(first,YES,YES);
        const double ready=NSProcessInfo.processInfo.systemUptime+1;
        while(!streamProtocol&&NSProcessInfo.processInfo.systemUptime<ready)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        const NSUInteger beforeLock=claims;
        serverLock=@{@"until":@0,@"message":@"Admin: kiểm tra lại tài khoản."};
        Event(@"event: patch\ndata: {\"path\":\"/lock\"}\n\n");WaitState(first,YES,NO);
        assert(first.hasSavedKey&&[first.lastMessage containsString:@"kiểm tra"]);
        __block NSUInteger restored=0;
        id observer=[NSNotificationCenter.defaultCenter addObserverForName:LicenseSessionDidBecomeAuthorizedNotification object:first queue:nil usingBlock:^(NSNotification *){++restored;}];
        serverLock=nil;Event(@"event: patch\ndata: {\"path\":\"/lock\",\"data\":null}\n\n");WaitState(first,NO,YES);
        assert(first.hasSavedKey&&claims==beforeLock&&restored==1);
        serverLock=@{@"until":@((NSDate.date.timeIntervalSince1970-.1)*1000),@"message":@"Đã hết giờ khóa"};
        Verify(first,NO,YES);assert(!first.locked);
        serverLock=@{@"until":@((NSDate.date.timeIntervalSince1970+.5)*1000),@"message":@"Khóa tạm"};
        Verify(first,NO,NO);assert(first.locked&&first.hasSavedKey);
        WaitState(first,NO,YES);assert(restored==2&&claims==beforeLock);
        serverLock=@{@"until":@(-1),@"message":@"invalid"};Verify(first,NO,NO);assert(!first.hasSavedKey);
        [NSNotificationCenter.defaultCenter removeObserver:observer];[first logout];
        // Upgrading before the admin migration must not erase the cached V2 key.
        NSString *oldHash=[@"f" stringByPaddingToLength:64 withString:@"f" startingAtIndex:0];
        [NSUserDefaults.standardUserDefaults setObject:oldHash forKey:@"LicenseHash"];
        mode=1;Verify(first,NO,NO);assert(first.hasSavedKey&&!first.authorized);
        assert([first.lastMessage containsString:@"chờ chuyển"]);
        mode=0;serverLock=nil;serverBinding=nil;Verify(first,NO,YES);
        assert(first.hasSavedKey&&claims==beforeLock+1);[first logout];
        puts("License V3: first claim, device binding, protocol isolation, locks, live unlock, messages, expiry and offline guards passed.");
    }
}
