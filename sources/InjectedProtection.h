#pragma once
#import <Foundation/Foundation.h>

// Start on the main thread only after the host's overlay is ready.
void MizzeStartOwnCodeProtection(void);
NSString* MizzeDefaultLicenseDatabaseURL(void);
