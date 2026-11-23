#import <UIKit/UIKit.h>

// App chrome theme.
//
// The app is light-only: MainApplicationDelegate forces
// UIUserInterfaceStyleLight on the window, so there is no second palette to
// keep in sync and MZThemeIsLight() always answers YES.
//
// The accent is fixed at the default mint. The custom picker was deleted, and
// MZTheme no longer reads AppAccentMode or AppAccentColor*, so an install that
// chose a colour earlier cannot get stuck showing it with no way back.
//
// The in-game menu has its own copy of these tokens inside
// ModMenuViewController.mm and reads AppThemeMode/AppAccent* straight from
// prefs. Nothing here writes AppThemeMode, so switching the app to light can
// never move the in-game menu's theme. MainApplicationDelegate clears the
// accent keys once at launch so that menu also falls back to mint.
//
// ModMenuViewController.mm is frozen. Only the app process uses this header.

#ifdef __cplusplus
extern "C" {
#endif

extern NSString * const MZThemeDidChangeNotification;

void MZThemeLoadFromPrefs(void);
void MZThemeNotifyChanged(void);

BOOL MZThemeIsLight(void);
int MZThemeAccentMode(void); // always 0: the custom accent is gone

UIColor *MZThemeBg(void);
UIColor *MZThemePanel(void);
UIColor *MZThemePanel2(void);
UIColor *MZThemeLine(void);
UIColor *MZThemeText(void);
UIColor *MZThemeMuted(void);
UIColor *MZThemeAccent(void);
UIColor *MZThemeAccentSoft(CGFloat alpha);
UIColor *MZThemeBlue(void);
UIColor *MZThemeOrange(void);
UIColor *MZThemeRed(void);
UIColor *MZThemeGreen(void);
UIColor *MZThemeTeal(void);
UIColor *MZThemePurple(void);

UIFont *MZThemeFont(CGFloat size, UIFontWeight weight);

// Default mint accent.
extern const float kMZThemeDefaultAccentR;
extern const float kMZThemeDefaultAccentG;
extern const float kMZThemeDefaultAccentB;

// Tab bar chrome. Call again after MZThemeLoadFromPrefs when the accent moves.
void MZThemeApplyToTabBar(UITabBar *tabBar);

#ifdef __cplusplus
}
#endif