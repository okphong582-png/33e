#import <Foundation/Foundation.h>
#import "../sources/LicenseSession.h"
#include <cassert>

static NSInteger mode = 0; // valid, missing, offline, expired
@interface LicenseTestProtocol : NSURLProtocol
@end
@implementation LicenseTestProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host isEqualToString:@"license.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    if (mode == 2) {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
        return;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    id record = mode == 1 ? (id)NSNull.null : @{@"enabled":@YES,
        @"expiresAt":@((NSDate.date.timeIntervalSince1970 + (mode == 3 ? -60 : 3600)) * 1000)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingFragmentsAllowed error:nil];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

static LicenseSession *NewSession() {
    LicenseSession *session = [LicenseSession new];
    [(NSURLSession *)[session valueForKey:@"session"] invalidateAndCancel];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.protocolClasses = @[LicenseTestProtocol.class];
    [session setValue:[NSURLSession sessionWithConfiguration:configuration] forKey:@"session"];
    [session setValue:@{@"DatabaseURL":@"https://license.test"} forKey:@"config"];
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
int main() {
    @autoreleasepool {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"LicenseHash"];
        LicenseSession *first = NewSession();
        assert(!first.hasSavedKey && !first.authorized);
        Verify(first, YES, YES);
        assert(first.hasSavedKey && first.authorized);
        LicenseSession *reopened = NewSession();
        assert(reopened.hasSavedKey && !reopened.authorized); // Cache grants no access.
        mode = 2; Verify(reopened, NO, NO);
        assert(reopened.hasSavedKey && !reopened.authorized); // Offline preserves retry only.
        mode = 0; Verify(reopened, NO, YES);
        assert(reopened.authorized);
        mode = 1; Verify(reopened, NO, NO);
        assert(!reopened.hasSavedKey && !reopened.authorized);
        mode = 0; Verify(reopened, YES, YES);
        mode = 3; Verify(reopened, NO, NO);
        assert(!reopened.hasSavedKey && !reopened.authorized);
        mode = 0; Verify(reopened, YES, YES);
        [reopened logout];
        assert(!reopened.hasSavedKey && !reopened.authorized);
        [first logout];
        puts("License restore: online verification, offline denial, deletion, expiry and logout passed.");
    }
}
