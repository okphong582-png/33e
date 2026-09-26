// ProxyChecker.m
#import "ProxyChecker.h"
#import <CFNetwork/CFNetwork.h>
#import "mahoa.h"
@implementation _0xPO34326

+ (BOOL)_0x4544DAN:(BOOL)_0x3873X {
    NSDictionary *settings = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    if (!settings) {
        return NO;
    }

    if (_0x3873X) {
        NSDictionary *scoped = settings[@"__SCOPED__"];
        if ([scoped isKindOfClass:[NSDictionary class]]) {
            NSArray *vpnInterfacePrefixes = @[NSSENCRYPT("tap"), NSSENCRYPT("tun"), NSSENCRYPT("ppp"), NSSENCRYPT("ipsec"), NSSENCRYPT("utun")];
            for (NSString *interface in scoped) {
                for (NSString *prefix in vpnInterfacePrefixes) {
                    if ([interface containsString:prefix]) {
                        NSLog(@"detected: %@", interface);
                        return YES;
                    }
                }
            }
        }
    }

    // Check for HTTP/HTTPS proxy keys
    if (settings[@"HTTPProxy"] || settings[@"HTTPSProxy"]) {
        return YES;
    }

    return NO;
}

@end