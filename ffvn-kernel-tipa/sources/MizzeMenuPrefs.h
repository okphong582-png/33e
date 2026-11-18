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

// Compact edition exposes ESP and three aim modes only. Retired saved toggles
// are disabled so a hidden setting cannot keep applying an old feature.
static inline void MizzePrepareCompactPrefs(void) {
    ESPPrefsSetFloat(@"AimType",2);
    ESPPrefsSetFloat(@"AimActivation",0);
    for(NSString *key in @[@"AimbotFire",@"AimbotScope",@"AimHipAlways",@"AimNeck"]) if(ESPPrefsBool(key,NO)) ESPPrefsSetBool(key,NO);
    if (!ESPPrefsBool(@"CompactGlassWhiteV2",NO)) {
        MizzeApplyReferenceColors();
        ESPPrefsSetBool(@"ESPEnabled",YES);
        ESPPrefsSetBool(@"EnemyCount",YES);
        ESPPrefsSetBool(@"Box",YES); ESPPrefsSetBool(@"CleanESP",YES);
        ESPPrefsSetBool(@"AimTargetLine",NO);
        ESPPrefsSetBool(@"CompactGlassWhiteV2",YES);
    }
    if(ESPPrefsBool(@"Box3D",NO))ESPPrefsSetBool(@"Box3D",NO);
    if(ESPPrefsBool(@"XYZAxes",NO))ESPPrefsSetBool(@"XYZAxes",NO);
    for (NSString *key in @[@"AutoFire",@"AutoFireFloating",@"GhostMode",@"GhostModeFloating",
        @"Fly",@"FlyFloating",@"FakeLag",@"FakeLagFloating",@"RunSpeed",@"RunSpeedFloating",
        @"FastFire",@"ShootNoReload",@"VisualSpin",@"AimLag"])
        if (ESPPrefsBool(key,NO)) ESPPrefsSetBool(key,NO);
    if (!ESPPrefsBool(@"HideFeatureButtons",NO)) ESPPrefsSetBool(@"HideFeatureButtons",YES);
}
static inline BOOL MizzeAimEnabled(void) {
    return AimModePolicy::ReadType(ESPPrefsFloat(@"AimType",0))==AimModePolicy::Type::Silent ?
        ESPPrefsBool(@"SilentAim",NO) : AimModePolicy::ReadActivation(ESPPrefsFloat(@"AimActivation",0))!=AimModePolicy::Activation::Off;
}
static inline void MizzeSetAimEnabled(BOOL enabled) {
    const BOOL silent=AimModePolicy::ReadType(ESPPrefsFloat(@"AimType",0))==AimModePolicy::Type::Silent;
    ESPPrefsSetBool(@"SilentAim",enabled && silent);
    ESPPrefsSetFloat(@"AimActivation",static_cast<int>(enabled && !silent ?
        AimModePolicy::Activation::Fire : AimModePolicy::Activation::Off));
}
