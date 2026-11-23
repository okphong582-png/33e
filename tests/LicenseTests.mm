#import <Foundation/Foundation.h>
#include <cassert>
#include <cstdio>
#import "../app/sources/MizzeLicense.mm"
int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);
 NSData *data=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
 NSDictionary *f=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];assert(f);
 NSDictionary *record=f[@"record"];NSString *hash=f[@"hash"];double now=[f[@"now"]doubleValue];
 assert(VerifyRecord(record,hash,now));
 assert(!VerifyRecord(record,@"other-key",now));
 assert(!VerifyRecord(record,hash,2000000000001.0));
 NSMutableDictionary *r=[record mutableCopy];r[@"enabled"]=@NO;assert(!VerifyRecord(r,hash,now));
 r=[record mutableCopy];[r removeObjectForKey:@"tipaSignature"];assert(!VerifyRecord(r,hash,now));
 r=[record mutableCopy];r[@"expiresAt"]=@2000000000001.0;assert(!VerifyRecord(r,hash,now));
 r=[record mutableCopy];NSMutableData *sig=[[[NSData alloc]initWithBase64EncodedString:r[@"tipaSignature"] options:0]mutableCopy];((uint8_t *)sig.mutableBytes)[0]^=1;r[@"tipaSignature"]=[sig base64EncodedStringWithOptions:0];assert(!VerifyRecord(r,hash,now));
 r=[record mutableCopy];r[@"lock"]=@{@"until":@(now+1000)};assert(!VerifyRecord(r,hash,now));
 NSDictionary *lease=@{@"version":@6,@"keyHash":hash,@"uid":@"device-A",@"sessionId":@"session-A",@"nonce":@"fresh",@"closed":@NO,@"issuedAt":@(now)};
 assert(VerifyLease(lease,hash,@"device-A",@"session-A",@"fresh",now));
 assert(!VerifyLease(lease,hash,@"device-B",@"session-A",@"fresh",now));
 assert(!VerifyLease(lease,hash,@"device-A",@"session-B",@"fresh",now));
 assert(!VerifyLease(lease,hash,@"device-A",@"session-A",@"old",now));
 assert(MizzeDirectLeasePolicy::Remaining(now,now-13000,now+60000,now,.1)==0);
 assert(MizzeDirectLeasePolicy::Remaining(now,now+3000,now+60000,now,.1)==0);
 assert(MizzeDirectLeasePolicy::Remaining(now,now,now-1,now,.1)==0);
 deadline.store(CACurrentMediaTime()+10);online.store(false);assert(!MizzeLicenseAuthorized());
 online.store(true);assert(MizzeLicenseAuthorized());
 deadline.store(CACurrentMediaTime()-1);assert(!MizzeLicenseAuthorized());
 puts("PASS: signature modification, key mismatch, signed expiry, revoke, lock, missing fields, nonce replay, two devices, session mismatch, stale lease and offline gate");
}return 0;}
