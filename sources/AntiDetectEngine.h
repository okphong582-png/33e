// AntiDetectEngine.h — public API for 9-layer max stealth + anti-ban engine
// Layers 8–16 (complements bypassscandylibgame.mm layers 1–7)
#pragma once
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── Engine init ──────────────────────────────────────────────────────────────
// Call once from BypassScanDylibGameInstall(), after all layer-1-7 hooks are in.
void AntiDetectInstall(void);

// ── Anti-ban runtime API (call from cheat feature code) ─────────────────────

// Apply ±4px Gaussian jitter to a raw aimbot screen coordinate
CGPoint AntiDetect_ApplyAimNoise(CGPoint rawAim);

// Returns YES when features should be suppressed this frame
// (scan freeze active, or an anti-ban suppression window is running)
BOOL AntiDetect_ShouldSuppressThisFrame(void);

// Randomized auto-fire reaction delay: 65 – 140 ms
NSTimeInterval AntiDetect_AimReactionDelay(void);

// Clamp a speed multiplier to human-plausible range 1.00 – 1.09×
// (with per-frame micro-variation via Gaussian noise)
float AntiDetect_SafeSpeedMultiplier(float requested);

// Randomised ESP refresh interval: 60 – 90 ms
NSTimeInterval AntiDetect_ESPRefreshInterval(void);

// Returns YES during the post-scan-window cooldown (500 ms – 2 s after unfreeze)
BOOL AntiDetect_IsInCooldown(void);

#ifdef __cplusplus
}
#endif
