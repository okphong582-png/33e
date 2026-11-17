#pragma once
#import <UIKit/UIKit.h>
#import "../esp/drawing_view/ESPStyle.h"
static inline UIColor *MizzeMint() { return [UIColor colorWithRed:.19 green:.40 blue:.62 alpha:1]; }
static inline UIColor *MizzeBackground() { return [UIColor colorWithWhite:1 alpha:.10]; }
static inline UIColor *MizzeSurface() { return [UIColor colorWithWhite:1 alpha:.10]; }
static inline UIColor *MizzeRaised() { return [UIColor colorWithWhite:1 alpha:.22]; }
static inline UIColor *MizzeBorder() { return [UIColor colorWithWhite:1 alpha:.42]; }
static inline UIColor *MizzeText() { return [UIColor colorWithRed:.12 green:.18 blue:.25 alpha:1]; }
static inline UIColor *MizzeMuted() { return [UIColor colorWithRed:.24 green:.30 blue:.38 alpha:.9]; }
static inline UIFont *MizzeFont(CGFloat size, UIFontWeight weight = UIFontWeightMedium) {
    NSString *name = weight >= UIFontWeightSemibold ? @"AvenirNext-DemiBold" : @"AvenirNext-Medium";
    return [UIFont systemFontOfSize:size weight:weight];
}
