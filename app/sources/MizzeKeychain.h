#pragma once
#import <Foundation/Foundation.h>
#import <Security/Security.h>

NSData *MizzeKeychainRead(NSString *service, NSString *account, OSStatus *status);
BOOL MizzeKeychainWrite(NSString *service, NSString *account, NSData *data, OSStatus *status);
BOOL MizzeKeychainDelete(NSString *service, NSString *account, OSStatus *status);
NSDictionary *MizzeKeychainReadIdentity(NSString *service, OSStatus *status);
BOOL MizzeKeychainWriteIdentity(NSString *service, NSString *uid, NSString *refresh, OSStatus *status);
