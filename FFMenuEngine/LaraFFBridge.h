#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LaraFFBridge : NSObject

+ (instancetype)sharedBridge NS_SWIFT_NAME(shared());

/**
 * Initialize Lara FF Menu Engine with DarkSword Exploit
 */
- (void)startFFEngine;

/**
 * Show / Toggle menu overlay on screen
 */
- (void)showMenuOverlay;
- (void)toggleMenuOverlay;

/**
 * Returns YES if kernel R/W is ready
 */
- (BOOL)isExploitReady;

@end

NS_ASSUME_NONNULL_END
