#include "mahoa.h"
#import "MizzeLicense.h"
#import "MizzeLicenseConfig.h"
#import "MizzeFirebaseDirectConfig.h"
#include "MizzeDirectLeasePolicy.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <Network/Network.h>
#import <QuartzCore/QuartzCore.h>
#include <atomic>
#include <cmath>
static std::atomic<double> deadline{0};
static std::atomic<bool> online{false};
static BOOL busy=NO;
static const BOOL isHUD=NO;
static unsigned long generation=0;
static NSString *message=@"Nhập key để tiếp tục.",*keyHash,*uid,*refreshToken,*idToken,*sessionID;
static double tokenUntil=0;
static NSURLSessionDataTask *task;
static void(^pending)(BOOL,NSString *);
static NSString *const service=@"com.mizze.ffvn.direct.v6";
static double MizzeLeaseNow(){return CACurrentMediaTime();}
static void Refresh(void(^completion)(BOOL,NSString *));
static BOOL Text(id v){return [v isKindOfClass:NSString.class];}
static BOOL Number(id v){return [v isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)v)!=CFBooleanGetTypeID()&&isfinite([v doubleValue]);}
static BOOL IsBoolean(id v,BOOL expected){return v&&CFGetTypeID((__bridge CFTypeRef)v)==CFBooleanGetTypeID()&&[v boolValue]==expected;}
static NSString *HashData(NSData *data){unsigned char h[32];CC_SHA256(data.bytes,(CC_LONG)data.length,h);NSMutableString *s=[NSMutableString string];for(auto b:h)[s appendFormat:NSSENCRYPT("%02x"),b];return s;}
static NSString *Hash(NSString *s){return HashData([s dataUsingEncoding:NSUTF8StringEncoding]);}
static NSString *Random(){unsigned char b[32];if(SecRandomCopyBytes(kSecRandomDefault,sizeof(b),b))return nil;return HashData([NSData dataWithBytes:b length:sizeof(b)]);}
static NSMutableDictionary *Query(NSString *a){return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:service,(__bridge id)kSecAttrAccount:a,(__bridge id)kSecAttrAccessGroup:NSSENCRYPT("com.dts.bugchi"),(__bridge id)kSecAttrSynchronizable:@NO}mutableCopy];}
static NSString *Load(NSString *a){NSMutableDictionary *q=Query(a);q[(__bridge id)kSecReturnData]=@YES;CFTypeRef result=NULL;if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&result)!=errSecSuccess)return @"";return [[NSString alloc]initWithData:CFBridgingRelease(result) encoding:NSUTF8StringEncoding]?:@"";}
static BOOL Store(NSString *a,NSString *value){NSMutableDictionary *q=Query(a);SecItemDelete((__bridge CFDictionaryRef)q);q[(__bridge id)kSecValueData]=[value dataUsingEncoding:NSUTF8StringEncoding];q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;return SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess;}
static void Notify(){[[NSNotificationCenter defaultCenter]postNotificationName:@"MizzeLicenseStateChanged" object:nil];}
static void Deny(NSString *text){deadline.store(0);message=text?:@"Không xác minh được phiên.";Notify();}
BOOL MizzeLicenseAuthorized(){return online.load()&&deadline.load()>MizzeLeaseNow();}
NSString *MizzeLicenseMessage(){return message?:@"";}
NSString *MizzeLicenseSavedKey(){return Load(@"key");}
@interface m8fb1d6:NSObject<NSURLSessionTaskDelegate>
@end
@implementation m8fb1d6
-(void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t willPerformHTTPRedirection:(NSHTTPURLResponse *)r newRequest:(NSURLRequest *)q completionHandler:(void (^)(NSURLRequest *))done{done(nil);}
@end
static NSURLSession *Session(){static NSURLSession *s;static dispatch_once_t once;dispatch_once(&once,^{NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.timeoutIntervalForRequest=3;c.timeoutIntervalForResource=4;c.URLCache=nil;c.HTTPCookieStorage=nil;c.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;s=[NSURLSession sessionWithConfiguration:c delegate:[m8fb1d6 new] delegateQueue:nil];});return s;}
static NSURL *DatabaseURL(NSString *path,BOOL authenticated){NSURLComponents *c=[NSURLComponents componentsWithString:[MIZZE_FIREBASE stringByAppendingFormat:NSSENCRYPT("/%@.json"),path]];NSMutableArray *q=[NSMutableArray arrayWithObject:[NSURLQueryItem queryItemWithName:NSSENCRYPT("nonce") value:Random()?:@""]];if(authenticated&&idToken.length)[q addObject:[NSURLQueryItem queryItemWithName:NSSENCRYPT("auth") value:idToken]];c.queryItems=q;return c.URL;}
static void Request(NSURL *url,NSString *method,NSDictionary *body,unsigned long g,void(^done)(NSDictionary *,double,NSString *)){
 if(![url.scheme isEqual:NSSENCRYPT("https")]||!url.host.length){done(nil,0,NSSENCRYPT("Không kết nối được dịch vụ xác thực."));return;}
 NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.HTTPMethod=method;[request setValue:NSSENCRYPT("application/json") forHTTPHeaderField:NSSENCRYPT("Content-Type")];[request setValue:NSSENCRYPT("no-cache, no-store") forHTTPHeaderField:NSSENCRYPT("Cache-Control")];if(body)request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
 task=[Session()dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
  NSDictionary *json=nil;double serverNow=0;NSString *failure=nil;
  if(error)failure=NSSENCRYPT("Không kết nối được dịch vụ xác thực.");
  else if(![response isKindOfClass:NSHTTPURLResponse.class]||![response.URL.scheme isEqual:NSSENCRYPT("https")]||![response.URL.host isEqual:url.host]||data.length>32768)failure=NSSENCRYPT("Phản hồi không hợp lệ.");
  else{NSHTTPURLResponse *http=(NSHTTPURLResponse *)response;id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if([value isKindOfClass:NSDictionary.class])json=value;
   if(http.statusCode!=200||!json)failure=(http.statusCode==401||http.statusCode==403)?NSSENCRYPT("Key sai, hết hạn, bị thu hồi hoặc đã gắn máy khác."):NSSENCRYPT("Không xác minh được phiên.");
   NSDateFormatter *f=[NSDateFormatter new];f.locale=[[NSLocale alloc]initWithLocaleIdentifier:NSSENCRYPT("en_US_POSIX")];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=NSSENCRYPT("EEE, dd MMM yyyy HH:mm:ss zzz");serverNow=[[f dateFromString:[http valueForHTTPHeaderField:NSSENCRYPT("Date")]]timeIntervalSince1970]*1000;
  }
  dispatch_async(dispatch_get_main_queue(),^{if(g!=generation)return;done(failure?nil:json,serverNow,failure);});
 }];[task resume];
}
static BOOL Identity(NSString *token,NSString *identity){
 if(!Text(token)||!Text(identity)||identity.length<8||identity.length>128)return NO;
 NSArray *parts=[token componentsSeparatedByString:NSSENCRYPT(".")];if(parts.count!=3)return NO;NSString *encoded=[parts[1] stringByReplacingOccurrencesOfString:NSSENCRYPT("-") withString:NSSENCRYPT("+")];encoded=[encoded stringByReplacingOccurrencesOfString:NSSENCRYPT("_") withString:NSSENCRYPT("/")];while(encoded.length%4)encoded=[encoded stringByAppendingString:NSSENCRYPT("=")];
 NSData *data=[[NSData alloc]initWithBase64EncodedString:encoded options:0];id claims=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 // Identity is issued through trusted Firebase TLS and enforced by RTDB. This
 // parsing is a configuration/subject check, not local JWT signature validation.
 return [claims isKindOfClass:NSDictionary.class]&&[claims[NSSENCRYPT("aud")]isEqual:MIZZE_FIREBASE_PROJECT]&&[claims[NSSENCRYPT("iss")]isEqual:[NSSENCRYPT("https://securetoken.google.com/") stringByAppendingString:MIZZE_FIREBASE_PROJECT]]&&[claims[NSSENCRYPT("sub")]isEqual:identity];
}
static void EnsureIdentity(unsigned long g,void(^done)(BOOL,NSString *)){
 if(idToken.length&&MizzeLeaseNow()<tokenUntil){done(Identity(idToken,uid),NSSENCRYPT("Phiên thiết bị không hợp lệ."));return;}
 BOOL renew=refreshToken.length>0;NSString *address=[NSString stringWithFormat:renew?NSSENCRYPT("https://securetoken.googleapis.com/v1/token?key=%@"):NSSENCRYPT("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%@"),MIZZE_FIREBASE_API_KEY];
 NSDictionary *body=renew?@{NSSENCRYPT("grant_type"):NSSENCRYPT("refresh_token"),NSSENCRYPT("refresh_token"):refreshToken}:@{NSSENCRYPT("returnSecureToken"):@YES};
 Request([NSURL URLWithString:address],NSSENCRYPT("POST"),body,g,^(NSDictionary *r,double now,NSString *error){
  NSString *token=r[renew?NSSENCRYPT("id_token"):NSSENCRYPT("idToken")],*refresh=r[renew?NSSENCRYPT("refresh_token"):NSSENCRYPT("refreshToken")],*identity=r[renew?NSSENCRYPT("user_id"):NSSENCRYPT("localId")];id life=r[renew?NSSENCRYPT("expires_in"):NSSENCRYPT("expiresIn")];
  double seconds=(Text(life)||Number(life))?[life doubleValue]:0;
  if(!r||!Text(refresh)||refresh.length<16||!Identity(token,identity)||seconds<60||seconds>7200||(uid.length&&![uid isEqual:identity])){idToken=nil;tokenUntil=0;done(NO,error?:NSSENCRYPT("Phiên thiết bị không hợp lệ. Xác minh lại."));return;}
  if(!isHUD&&(!Store(NSSENCRYPT("uid"),identity)||!Store(NSSENCRYPT("refresh"),refresh))){done(NO,NSSENCRYPT("Không lưu được phiên an toàn."));return;}
  idToken=token;refreshToken=refresh;uid=identity;tokenUntil=MizzeLeaseNow()+MIN(3600.0,seconds)-30;done(YES,nil);
 });
}
static BOOL VerifyRecord(NSDictionary *r,NSString *hash,double serverNow){
 if(!r||serverNow<=0||!IsBoolean(r[NSSENCRYPT("enabled")],YES)||!Number(r[NSSENCRYPT("protocol")])||[r[NSSENCRYPT("protocol")]intValue]!=4||!Number(r[NSSENCRYPT("expiresAt")])||!Text(r[NSSENCRYPT("tipaPayload")])||!Text(r[NSSENCRYPT("tipaSignature")]))return NO;
 NSData *raw=[[NSData alloc]initWithBase64EncodedString:r[NSSENCRYPT("tipaPayload")] options:0],*sig=[[NSData alloc]initWithBase64EncodedString:r[NSSENCRYPT("tipaSignature")] options:0];if(!raw.length||raw.length>4096||sig.length!=384)return NO;
 NSData *der=[[NSData alloc]initWithBase64EncodedString:MIZZE_LICENSE_PUBLIC options:0];SecKeyRef pub=SecKeyCreateWithData((__bridge CFDataRef)der,(__bridge CFDictionaryRef)@{(__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeRSA,(__bridge id)kSecAttrKeyClass:(__bridge id)kSecAttrKeyClassPublic,(__bridge id)kSecAttrKeySizeInBits:@3072},NULL);
 BOOL valid=pub&&SecKeyVerifySignature(pub,kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,(__bridge CFDataRef)raw,(__bridge CFDataRef)sig,NULL);if(pub)CFRelease(pub);if(!valid)return NO;
 id p=[NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];if(![p isKindOfClass:NSDictionary.class]||!Number(p[NSSENCRYPT("v")])||[p[NSSENCRYPT("v")]intValue]!=1||![p[NSSENCRYPT("aud")]isEqual:NSSENCRYPT("mizze-ffvn-tipa")]||![p[NSSENCRYPT("keyHash")]isEqual:hash]||!Number(p[NSSENCRYPT("expiresAt")])||[p[NSSENCRYPT("expiresAt")]doubleValue]!=[r[NSSENCRYPT("expiresAt")]doubleValue]||[p[NSSENCRYPT("expiresAt")]doubleValue]<=serverNow)return NO;
 id lock=r[NSSENCRYPT("lock")];if(lock&&(![lock isKindOfClass:NSDictionary.class]||!Number(lock[NSSENCRYPT("until")])||[lock[NSSENCRYPT("until")]doubleValue]<=0||[lock[NSSENCRYPT("until")]doubleValue]>serverNow))return NO;
 return YES;
}
static BOOL VerifyLease(NSDictionary *lease, NSString *hash, NSString *identity, NSString *sid, NSString *nonce, double now){
 return lease&&std::isfinite(now)&&now>0&&now<1e16&&Number(lease[@"version"])&&[lease[@"version"]intValue]==6&&
 [lease[@"keyHash"]isEqual:hash]&&[lease[@"uid"]isEqual:identity]&&[lease[@"sessionId"]isEqual:sid]&&
 [lease[@"nonce"]isEqual:nonce]&&IsBoolean(lease[@"closed"],NO)&&Number(lease[@"issuedAt"]);
}
static BOOL InstallAccess(NSDictionary *record,NSDictionary *lease,double recordNow,double current,double remaining){
 if(!online.load()||remaining<=0||remaining>12)return NO;
 deadline.store(current+remaining);message=@"";Notify();return YES;
}
static NSString *SessionPath(){return [NSString stringWithFormat:NSSENCRYPT("tipaDirectV6/sessions/%@/%@/%@"),keyHash,uid,isHUD?NSSENCRYPT("hud"):NSSENCRYPT("launcher")];}
static NSDictionary *SessionBody(NSString *nonce,BOOL closed){return @{NSSENCRYPT("version"):@6,NSSENCRYPT("keyHash"):keyHash,NSSENCRYPT("uid"):uid,NSSENCRYPT("sessionId"):sessionID,NSSENCRYPT("nonce"):nonce,NSSENCRYPT("issuedAt"):@{NSSENCRYPT(".sv"):NSSENCRYPT("timestamp")},NSSENCRYPT("closed"):@(closed)};}
static void Refresh(void(^completion)(BOOL,NSString *)){
 if(busy){if(completion){if(!pending)pending=completion;else completion(NO,NSSENCRYPT("Đang xác minh…"));}return;}
 if(!online||!keyHash.length||!sessionID.length){Deny(NSSENCRYPT("Chưa có kết nối xác thực."));if(completion)completion(NO,message);return;}
 busy=YES;pending=completion;unsigned long g=generation;double started=MizzeLeaseNow();NSString *expectedHash=keyHash,*expectedSession=sessionID;
 void(^finish)(BOOL,NSString *)=^(BOOL ok,NSString *text){if(g!=generation)return;busy=NO;void(^callback)(BOOL,NSString *)=pending;pending=nil;if(!ok)Deny(text);if(callback)callback(ok,message);};
 EnsureIdentity(g,^(BOOL ok,NSString *error){if(!ok){finish(NO,error);return;}
  Request(DatabaseURL([NSSENCRYPT("licensesV4/") stringByAppendingString:expectedHash],NO),NSSENCRYPT("GET"),nil,g,^(NSDictionary *record,double recordNow,NSString *failure){
   if(!VerifyRecord(record,expectedHash,recordNow)){finish(NO,failure?:NSSENCRYPT("Key sai, hết hạn hoặc đã thu hồi."));return;}
   NSString *binding=[NSSENCRYPT("tipaDirectV6/bindings/") stringByAppendingString:expectedHash];
   void(^claimSession)(void)=^{
    NSString *nonce=Random();if(!nonce){finish(NO,NSSENCRYPT("Không tạo được phiên."));return;}
    NSString *path=SessionPath();NSDictionary *body=SessionBody(nonce,NO);
    Request(DatabaseURL(path,YES),NSSENCRYPT("PUT"),body,g,^(NSDictionary *written,double ignored,NSString *writeError){if(!written){finish(NO,writeError);return;}
     Request(DatabaseURL(path,YES),NSSENCRYPT("GET"),nil,g,^(NSDictionary *lease,double now,NSString *readError){
      if(!VerifyLease(lease,expectedHash,uid,expectedSession,nonce,now)) {finish(NO,readError?:NSSENCRYPT("Phản hồi không khớp phiên."));return;}
      double issued=[lease[NSSENCRYPT("issuedAt")]doubleValue];double current=MizzeLeaseNow();double remaining=MizzeDirectLeasePolicy::Remaining(now,issued,[record[NSSENCRYPT("expiresAt")]doubleValue],recordNow,current-started);
      if(remaining<=0||!online){finish(NO,NSSENCRYPT("Phiên hết hạn. Thử lại."));return;}
      if(!InstallAccess(record,lease,recordNow,current,remaining)){finish(NO,NSSENCRYPT("Dữ liệu phiên không hợp lệ."));return;}message=@"";finish(YES,nil);
     });
    });
   };
   Request(DatabaseURL(binding,YES),NSSENCRYPT("GET"),nil,g,^(NSDictionary *bound,double date,NSString *bindingError){
    if(bound){if(![bound[NSSENCRYPT("uid")]isEqual:uid]||![bound[NSSENCRYPT("version")]isEqual:@6]){finish(NO,NSSENCRYPT("Key đã gắn thiết bị khác."));return;}
     claimSession();return;}
    if(isHUD){finish(NO,bindingError);return;}
    // Firebase owns first binding: the client cannot change an existing uid.
    Request(DatabaseURL(binding,YES),NSSENCRYPT("PUT"),@{NSSENCRYPT("uid"):uid,NSSENCRYPT("version"):@6,NSSENCRYPT("claimedAt"):@{NSSENCRYPT(".sv"):NSSENCRYPT("timestamp")}},g,^(NSDictionary *claimed,double time,NSString *claimError){
     if(!claimed||![claimed[NSSENCRYPT("uid")]isEqual:uid]){finish(NO,claimError?:NSSENCRYPT("Key đã gắn thiết bị khác."));return;}claimSession();
    });
   });
  });
 });
}
void MizzeLicenseCheck(NSString *key,void(^completion)(BOOL,NSString *)){
 if(isHUD){Refresh(completion);return;}
 if(busy){NSString *candidate=[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(keyHash.length&&[Hash(candidate)isEqual:keyHash]&&!pending){pending=^(BOOL ok,NSString *text){if(ok&&!Store(NSSENCRYPT("key"),candidate)){Deny(NSSENCRYPT("Không lưu được key an toàn."));ok=NO;}if(completion)completion(ok,message);};return;}if(completion)completion(NO,NSSENCRYPT("Đang xác minh…"));return;}
 NSString *clean=[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(clean.length<8||clean.length>256){++generation;[task cancel];busy=NO;pending=nil;keyHash=sessionID=nil;Deny(NSSENCRYPT("Nhập key hợp lệ."));if(completion)completion(NO,message);return;}
 NSString *hash=Hash(clean);if(![keyHash isEqual:hash]){++generation;Deny(NSSENCRYPT("Đang xác minh…"));keyHash=hash;sessionID=Random();}
 if(!sessionID.length){Deny(NSSENCRYPT("Không tạo được phiên."));if(completion)completion(NO,message);return;}
 Refresh(^(BOOL ok,NSString *text){if(ok&&!Store(NSSENCRYPT("key"),clean)){Deny(NSSENCRYPT("Không lưu được key an toàn."));ok=NO;}if(completion)completion(ok,message);});
}
void MizzeLicenseForget(){
 ++generation;[task cancel];task=nil;busy=NO;pending=nil;
 if(online.load()&&uid.length&&idToken.length){Request(DatabaseURL([@"tipaDirectV6/revocations/" stringByAppendingString:uid],YES),@"PUT",@{@"revokedAt":@{@".sv":@"timestamp"}},generation,^(NSDictionary *r,double time,NSString *error){});}
 for(NSString *account in @[@"key",@"uid",@"refresh"])SecItemDelete((__bridge CFDictionaryRef)Query(account));
 keyHash=uid=refreshToken=idToken=sessionID=nil;tokenUntil=0;
 Deny(@"Nhập key để tiếp tục.");
}
void MizzeLicenseBegin(){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{MizzeLicenseBegin();});return;}
 static dispatch_once_t once;dispatch_once(&once,^{
  uid=Load(@"uid");refreshToken=Load(@"refresh");
  if((uid.length==0)!=(refreshToken.length==0)){
   uid=refreshToken=nil;SecItemDelete((__bridge CFDictionaryRef)Query(@"uid"));SecItemDelete((__bridge CFDictionaryRef)Query(@"refresh"));
  }
  static nw_path_monitor_t monitor=nw_path_monitor_create();
  nw_path_monitor_set_queue(monitor,dispatch_get_main_queue());
  nw_path_monitor_set_update_handler(monitor,^(nw_path_t path){
   online.store(nw_path_get_status(path)==nw_path_status_satisfied);
   if(!online.load()){
    ++generation;[task cancel];task=nil;busy=NO;Deny(@"Mất kết nối mạng.");
    void(^done)(BOOL,NSString *)=pending;pending=nil;if(done)done(NO,message);
   }else if(keyHash.length&&sessionID.length&&!busy)Refresh(nil);
  });nw_path_monitor_start(monitor);
  static dispatch_source_t renew,expiry;
  renew=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
  dispatch_source_set_timer(renew,dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),4*NSEC_PER_SEC,NSEC_PER_MSEC*100);
  dispatch_source_set_event_handler(renew,^{if(online.load()&&!busy&&keyHash.length&&sessionID.length)Refresh(nil);});dispatch_resume(renew);
  expiry=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
  dispatch_source_set_timer(expiry,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_MSEC*250),NSEC_PER_MSEC*250,NSEC_PER_MSEC*25);
  dispatch_source_set_event_handler(expiry,^{if(deadline.load()>0&&(!online.load()||MizzeLeaseNow()>=deadline.load())){
   ++generation;[task cancel];task=nil;busy=NO;Deny(@"Phiên đã kết thúc. Xác minh lại.");
   void(^done)(BOOL,NSString *)=pending;pending=nil;if(done)done(NO,message);
  }});dispatch_resume(expiry);
 });
}
