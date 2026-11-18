#import "MizzeLicense.h"
#import "MizzeLicenseConfig.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <Network/Network.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/stat.h>
#include <atomic>
#include <cmath>
static std::atomic<double> deadline{0};
static NSString *message=@"Nhập key để tiếp tục.", *activeKey, *device;
static BOOL busy=NO, online=YES;
static unsigned long generation=0;
static NSString *const authPath=@"/var/mobile/Library/Caches/com.mizze.ffvn.license.plist";
static NSString *Hash(NSString *s){NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString *r=[NSMutableString string];for(unsigned char b:h)[r appendFormat:@"%02x",b];return r;}
static NSMutableDictionary *Query(NSString *account){return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.mizze.ffvn.license",(__bridge id)kSecAttrAccount:account} mutableCopy];}
static NSString *Load(NSString *a){NSMutableDictionary *q=Query(a);q[(__bridge id)kSecReturnData]=@YES;CFTypeRef v=NULL;if(SecItemCopyMatching((__bridge CFDictionaryRef)q,&v)!=errSecSuccess)return @"";return [[NSString alloc] initWithData:CFBridgingRelease(v) encoding:NSUTF8StringEncoding]?:@"";}
static void Store(NSString *a,NSString *s){NSMutableDictionary *q=Query(a);NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];NSDictionary *u=@{(__bridge id)kSecValueData:d};if(SecItemUpdate((__bridge CFDictionaryRef)q,(__bridge CFDictionaryRef)u)==errSecItemNotFound){[q addEntriesFromDictionary:u];q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;SecItemAdd((__bridge CFDictionaryRef)q,NULL);}}
NSString *MizzeLicenseSavedKey(void){return Load(@"key");}
BOOL MizzeLicenseAuthorized(void){return online && CACurrentMediaTime()<deadline.load();}
NSString *MizzeLicenseMessage(void){return message;}
static void Deny(NSString *text){deadline.store(0);message=text;}
static NSURLSession *Session(){static NSURLSession *s;static dispatch_once_t once;dispatch_once(&once,^{NSURLSessionConfiguration *c=NSURLSessionConfiguration.ephemeralSessionConfiguration;c.timeoutIntervalForRequest=5;c.timeoutIntervalForResource=6;c.URLCache=nil;c.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;s=[NSURLSession sessionWithConfiguration:c];});return s;}
static NSURL *URL(NSString *hash,BOOL binding){return [NSURL URLWithString:[NSString stringWithFormat:@"%@/licensesV4/%@%@.json?nonce=%@",MIZZE_FIREBASE,hash,binding?@"/binding":@"",NSUUID.UUID.UUIDString]];}
static BOOL Verify(NSDictionary *record,NSString *hash,double now){
    if(![record isKindOfClass:NSDictionary.class]||[record[@"protocol"] intValue]!=4||![record[@"enabled"] isEqual:@YES])return NO;
    if(![record[@"tipaPayload"] isKindOfClass:NSString.class]||![record[@"tipaSignature"] isKindOfClass:NSString.class])return NO;
    NSData *raw=[[NSData alloc] initWithBase64EncodedString:record[@"tipaPayload"]?:@"" options:0],*sig=[[NSData alloc] initWithBase64EncodedString:record[@"tipaSignature"]?:@"" options:0];
    if(!raw.length||raw.length>4096||sig.length!=384)return NO;
    NSData *der=[[NSData alloc] initWithBase64EncodedString:MIZZE_LICENSE_PUBLIC options:0];
    SecKeyRef pub=SecKeyCreateWithData((__bridge CFDataRef)der,(__bridge CFDictionaryRef)@{(__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeRSA,(__bridge id)kSecAttrKeyClass:(__bridge id)kSecAttrKeyClassPublic,(__bridge id)kSecAttrKeySizeInBits:@3072},NULL);
    BOOL valid=pub&&SecKeyVerifySignature(pub,kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,(__bridge CFDataRef)raw,(__bridge CFDataRef)sig,NULL);if(pub)CFRelease(pub);if(!valid)return NO;
    NSDictionary *p=[NSJSONSerialization JSONObjectWithData:raw options:0 error:nil];
    if(![p isKindOfClass:NSDictionary.class]||![p[@"aud"] isEqual:@"mizze-ffvn-tipa"]||![p[@"keyHash"] isEqual:hash]||[p[@"v"] intValue]!=1)return NO;
    double expiry=[p[@"expiresAt"] doubleValue];if(!isfinite(expiry)||expiry<=now||expiry!=[record[@"expiresAt"] doubleValue])return NO;
    id lock=record[@"lock"];if([lock isKindOfClass:NSDictionary.class]&&([lock[@"until"] doubleValue]==0||[lock[@"until"] doubleValue]>now))return NO;
    return YES;
}
static void CheckHash(NSString *hash,NSString *identity,BOOL mayBind,void (^done)(BOOL,NSString *)){
    const double started=CACurrentMediaTime();
    const unsigned long requestGeneration=generation;
    [[Session() dataTaskWithURL:URL(hash,NO) completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        NSHTTPURLResponse *r=(NSHTTPURLResponse *)response;NSDictionary *record=nil;double now=0;
        if(!error&&[r isKindOfClass:NSHTTPURLResponse.class]&&r.statusCode==200&&data.length<32768){
            record=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];NSDateFormatter *f=[NSDateFormatter new];f.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];f.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss zzz";now=[[f dateFromString:[r valueForHTTPHeaderField:@"Date"]] timeIntervalSince1970]*1000;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            if(requestGeneration!=generation){done(NO,@"Phiên đã đóng.");return;}
            if(error||!online){Deny(@"Đang mất mạng");done(NO,message);return;}
            if(!now||!Verify(record,hash,now)){Deny(@"Key không hợp lệ, đã hết hạn hoặc bị thu hồi.");done(NO,message);return;}
            NSDictionary *binding=record[@"binding"];
            if(!binding&&mayBind){
                NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:URL(hash,YES)];request.HTTPMethod=@"PUT";[request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                request.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"deviceHash":identity,@"claimedAt":@{@".sv":@"timestamp"}} options:0 error:nil];
                [[Session() dataTaskWithRequest:request completionHandler:^(NSData *d,NSURLResponse *resp,NSError *err){dispatch_async(dispatch_get_main_queue(),^{if(err){Deny(@"Đang mất mạng");done(NO,message);}else CheckHash(hash,identity,NO,done);});}] resume];return;
            }
            if(![binding isKindOfClass:NSDictionary.class]||![binding[@"deviceHash"] isEqual:identity]){Deny(@"Key đã liên kết thiết bị khác.");done(NO,message);return;}
            double remaining=MIN(12.0,([record[@"expiresAt"] doubleValue]-now)/1000)-(CACurrentMediaTime()-started);
            if(remaining<=0){Deny(@"Phiên kiểm tra đã hết hạn. Thử lại.");done(NO,message);return;}
            deadline.store(CACurrentMediaTime()+remaining);message=@"Key đã xác minh";done(YES,message);
        });
    }] resume];
}
void MizzeLicenseCheck(NSString *key,void (^completion)(BOOL,NSString *)){
    if(busy){if(completion)completion(NO,@"Đang kiểm tra key…");return;}
    NSString *clean=[key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(clean.length<8||clean.length>256){Deny(@"Nhập key hợp lệ.");if(completion)completion(NO,message);return;}
    if(!device.length){device=Load(@"device");if(!device.length){device=Hash(NSUUID.UUID.UUIDString);Store(@"device",device);}}
    busy=YES;activeKey=Hash(clean);CheckHash(activeKey,device,YES,^(BOOL ok,NSString *text){busy=NO;if(ok){Store(@"key",clean);[@{@"hash":activeKey,@"device":device} writeToFile:authPath atomically:YES];chmod(authPath.fileSystemRepresentation,0600);}if(completion)completion(ok,text);});
}
void MizzeLicenseForget(void){++generation;deadline.store(0);activeKey=nil;SecItemDelete((__bridge CFDictionaryRef)Query(@"key"));[[NSFileManager defaultManager] removeItemAtPath:authPath error:nil];message=@"Nhập key để tiếp tục.";}
void MizzeLicenseBegin(void){static dispatch_once_t once;dispatch_once(&once,^{
    static nw_path_monitor_t monitor;monitor=nw_path_monitor_create();nw_path_monitor_set_queue(monitor,dispatch_get_main_queue());nw_path_monitor_set_update_handler(monitor,^(nw_path_t path){online=nw_path_get_status(path)==nw_path_status_satisfied;if(!online)Deny(@"Đang mất mạng");});nw_path_monitor_start(monitor);
    void (^refresh)(void)=^{if(busy)return;NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:authPath];NSString *h=saved[@"hash"],*d=saved[@"device"];if(h.length!=64||d.length!=64)return;busy=YES;CheckHash(h,d,NO,^(BOOL ok,NSString *text){busy=NO;});};refresh();
    [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *timer){refresh();}];
});}
