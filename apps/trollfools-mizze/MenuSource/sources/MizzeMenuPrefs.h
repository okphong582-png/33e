#pragma once
#import "../esp/drawing_view/ESPPrefs.h"
#include "../esp/Core/AimModePolicy.h"
#include "../esp/drawing_view/ESPReferenceStyle.h"

static inline void MizzeApplyReferenceColors(void) {
    using namespace ESPReferenceStyle;
    const RGB colors[]={Box,Fov,Line,Skeleton};
    NSArray *prefixes=@[@"BoxColor",@"FovColor",@"LineColor",@"SkeletonColor"];
    for (NSUInteger i=0;i<prefixes.count;++i) {
        ESPPrefsSetFloat([prefixes[i] stringByAppendingString:@"R"],colors[i].r);
        ESPPrefsSetFloat([prefixes[i] stringByAppendingString:@"G"],colors[i].g);
        ESPPrefsSetFloat([prefixes[i] stringByAppendingString:@"B"],colors[i].b);
    }
}


static inline void MizzePrepareMenuPrefs(void) {
    if (!ESPPrefsBool(@"ReferenceESPStyleV1",NO)) {
        MizzeApplyReferenceColors();
        for (NSString *key in @[@"ESPEnabled",@"Line",@"Skeleton",@"Name",@"Dis",@"Health",@"ShowFov"]) ESPPrefsSetBool(key,YES);
        for (NSString *key in @[@"Box",@"Box3D",@"HeadRedDot",@"XYZAxes"]) ESPPrefsSetBool(key,NO);
        ESPPrefsSetBool(@"ReferenceESPStyleV1",YES);
    }
    if (!ESPPrefsBool(@"ExplicitAimMenuV1", NO)) {
        const auto type = ESPPrefsBool(@"SilentAim", NO) ? AimModePolicy::Type::Silent :
            (ESPPrefsBool(@"AimNeck", NO) ? AimModePolicy::Type::Neck : AimModePolicy::Type::Head);
        ESPPrefsSetFloat(@"AimType", static_cast<int>(type));
        ESPPrefsSetFloat(@"AimActivation", static_cast<int>(AimModePolicy::Activation::Off));
        for (NSString *key in @[@"AimbotFire", @"AimbotScope", @"AimHipAlways", @"SilentAim"])
            ESPPrefsSetBool(key, NO);
        // Existing floating-button choices stay available after the menu upgrade.
        for (NSString *key in @[@"GhostMode", @"FakeLag"])
            if (!AppSettingsObjectForKey([key stringByAppendingString:@"Floating"]))
                ESPPrefsSetBool([key stringByAppendingString:@"Floating"], ESPPrefsBool(key, NO));
        ESPPrefsSetBool(@"ExplicitAimMenuV1", YES);
    }
}
