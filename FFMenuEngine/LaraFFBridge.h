#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LaraFFBridge : NSObject

+ (instancetype)sharedBridge;

/**
 * Initialize Lara FF Menu Engine with DarkSword Exploit
 */
- (void)startFFEngine;

/**
 * Toggle menu overlay on screen
 */
- (void)toggleMenuOverlay;

/**
 * Returns YES if kernel R/W is ready
 */
- (BOOL)isExploitReady;

@end

NS_ASSUME_NONNULL_END
