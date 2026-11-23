#import "MZTheme.h"
#import "ESPPrefs.h"

NSString * const MZThemeDidChangeNotification = @"MZThemeDidChangeNotification";

const float kMZThemeDefaultAccentR = 0.925f;
const float kMZThemeDefaultAccentG = 0.941f;
const float kMZThemeDefaultAccentB = 0.949f;

static int g_accentMode = 0;
static float g_ar = kMZThemeDefaultAccentR;
static float g_ag = kMZThemeDefaultAccentG;
static float g_ab = kMZThemeDefaultAccentB;

// Mizze black/silver palette. These are the systemGroupedBackground /
// secondarySystemGroupedBackground / separator / label / secondaryLabel light
// values written out as literals rather than looked up by name, because the
// app runs on iOS 15+ where all five exist; the literals only mean the app
// looks the same if a lookup ever fails on an odd build.
static UIColor *MDHex(uint32_t rgb, CGFloat alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:alpha];
}

// The custom accent is gone: the picker screen is deleted and the app is
// fixed to the default silver. MZTheme deliberately does not read AppAccentMode
// or AppAccentColor* any more, because an install that picked a colour earlier
// still has those keys on disk and would otherwise keep showing it with no way
// to change it back.
void MZThemeLoadFromPrefs(void) {
    g_accentMode = 0;
    g_ar = kMZThemeDefaultAccentR;
    g_ag = kMZThemeDefaultAccentG;
    g_ab = kMZThemeDefaultAccentB;
}

void MZThemeNotifyChanged(void) {
    MZThemeLoadFromPrefs();
    [[NSNotificationCenter defaultCenter] postNotificationName:MZThemeDidChangeNotification object:nil];
}

BOOL MZThemeIsLight(void) { return NO; }
int MZThemeAccentMode(void) { return g_accentMode; }

UIColor *MZThemeBg(void)     { return MDHex(0x050506, 1.0f); } // systemGroupedBackground
UIColor *MZThemePanel(void)  { return MDHex(0x101013, 1.0f); } // card
UIColor *MZThemePanel2(void) { return MDHex(0x19191E, 1.0f); } // secondary fill
UIColor *MZThemeLine(void)   { return MDHex(0x3A3A42, 0.7f); }  // separator
UIColor *MZThemeText(void)   { return MDHex(0xF4F4F6, 1.0f); }
UIColor *MZThemeMuted(void)  { return MDHex(0x9999A4, 1.0f); } // secondaryLabel

UIColor *MZThemeAccent(void) {
    return [UIColor colorWithRed:g_ar green:g_ag blue:g_ab alpha:1.0f];
}
UIColor *MZThemeAccentSoft(CGFloat alpha) {
    return [UIColor colorWithRed:g_ar green:g_ag blue:g_ab alpha:alpha];
}

UIColor *MZThemeBlue(void)   { return MDHex(0x007AFF, 1.0f); }
UIColor *MZThemeGreen(void)  { return MDHex(0x34C759, 1.0f); }
UIColor *MZThemeOrange(void) { return MDHex(0xFF9500, 1.0f); }
UIColor *MZThemeRed(void)    { return MDHex(0xFF3B30, 1.0f); }
UIColor *MZThemeTeal(void)   { return MDHex(0x30B0C7, 1.0f); }
UIColor *MZThemePurple(void) { return MDHex(0xAF52DE, 1.0f); }

// SF Pro. The bundled Inter/FA .ttf files this used to load are not in the
// repo, so every one of those lookups fell through to the system font anyway.
UIFont *MZThemeFont(CGFloat size, UIFontWeight weight) {
    return [UIFont systemFontOfSize:size weight:weight];
}

void MZThemeApplyToTabBar(UITabBar *tabBar) {
    if (!tabBar) return;
    MZThemeLoadFromPrefs();
    tabBar.translucent = NO;
    tabBar.tintColor = MZThemeAccent();
    if ([tabBar respondsToSelector:@selector(setUnselectedItemTintColor:)]) {
        tabBar.unselectedItemTintColor = MZThemeMuted();
    }
    tabBar.barTintColor = MZThemePanel();
    tabBar.backgroundColor = MZThemePanel();

    Class appearanceCls = NSClassFromString(@"UITabBarAppearance");
    if (!appearanceCls) return;
    id app = [[appearanceCls alloc] init];
    if ([app respondsToSelector:@selector(configureWithOpaqueBackground)]) {
        [app configureWithOpaqueBackground];
    }
    if ([app respondsToSelector:@selector(setBackgroundColor:)]) {
        [app setBackgroundColor:MZThemePanel()];
    }
    if ([app respondsToSelector:@selector(setShadowColor:)]) {
        [app setShadowColor:MZThemeLine()];
    }
    UIColor *sel = MZThemeAccent();
    UIColor *uns = MZThemeMuted();
    @try {
        id stacked = [app valueForKey:@"stackedLayoutAppearance"];
        id normal = [stacked valueForKey:@"normal"];
        id selected = [stacked valueForKey:@"selected"];
        [normal setValue:uns forKey:@"iconColor"];
        [normal setValue:@{ NSForegroundColorAttributeName: uns } forKey:@"titleTextAttributes"];
        [selected setValue:sel forKey:@"iconColor"];
        [selected setValue:@{ NSForegroundColorAttributeName: sel } forKey:@"titleTextAttributes"];
    } @catch (__unused NSException *e) {}
    if ([tabBar respondsToSelector:@selector(setStandardAppearance:)]) {
        [tabBar setValue:app forKey:@"standardAppearance"];
    }
    if ([tabBar respondsToSelector:NSSelectorFromString(@"setScrollEdgeAppearance:")]) {
        @try { [tabBar setValue:app forKey:@"scrollEdgeAppearance"]; } @catch (__unused NSException *e) {}
    }
}