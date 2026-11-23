#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL MizzeLicenseAuthorized(void);
NSString *MizzeLicenseMessage(void);
NSString *MizzeLicenseSavedKey(void);
void MizzeLicenseCheck(NSString *key, void (^completion)(BOOL, NSString *));
void MizzeLicenseBegin(void);
void MizzeLicenseForget(void);
#ifdef __cplusplus
}
#endif
