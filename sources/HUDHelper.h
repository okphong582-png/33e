
#include "KabraxHide.h"
#import <Foundation/Foundation.h>

BOOL IsHUDEnabled(void);
BOOL StartHUD(NSError **error);
void StopHUD(void);
NSString *HUDLastStatusMessage(void);
void HUDMarkStarting(void);
void HUDMarkReady(void);
void RequestExitHUDWithMessage(NSString *message);
void _0xFFFADK2(BOOL isEnabled);

void RequestExitHUD(void);
