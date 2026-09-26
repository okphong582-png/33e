#pragma once
#import <UIKit/UIKit.h>
#import "ESPPrefs.h"

static inline UIColor *ESPColor(NSString *prefix, CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:ESPPrefsFloat([prefix stringByAppendingString:@"R"], r)
                           green:ESPPrefsFloat([prefix stringByAppendingString:@"G"], g)
                            blue:ESPPrefsFloat([prefix stringByAppendingString:@"B"], b) alpha:1];
}
static inline BOOL ESPDarkTheme() { return ESPPrefsBool(@"DarkTheme", YES); }
