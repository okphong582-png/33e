// bypassscandylibgame.h
// Public API for the injected bypass anti-scan engine
#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Returns YES when the game's scan window is active and features should freeze
BOOL BypassScanIsFreezing(void);

/// Install the hidden 3-finger long-press gesture menu on a game window
void BypassInstallGestureMenu(UIWindow *gameWindow);

/// Full bypass install — call once from dylib constructor (before UIKit)
void BypassScanDylibGameInstall(void);

/// Notification fired when the hidden gesture triggers a menu toggle
/// Name: "com.iosviet.bypass.togglemenu"
extern NSNotificationName const kBypassToggleMenuNotification;

#ifdef __cplusplus
}
#endif
