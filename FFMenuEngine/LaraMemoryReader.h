#import <Foundation/Foundation.h>
#import <mach/mach.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * LaraMemoryReader
 * Cross-process user-memory backend using Lara's DarkSword VM mapping.
 */
@interface LaraMemoryReader : NSObject

@property (nonatomic, assign, readonly) pid_t targetPID;
@property (nonatomic, assign, readonly) uint64_t targetProcAddress;
@property (nonatomic, assign, readonly) uint64_t targetTaskAddress;
@property (nonatomic, assign, readonly) uint64_t targetMapAddress;
@property (nonatomic, assign, readonly) uint64_t mainModuleBase;
@property (nonatomic, assign, readonly) BOOL isKernelReady;
@property (nonatomic, assign, readonly) BOOL isAttached;
@property (nonatomic, copy, readonly) NSString *lastError;

+ (instancetype)sharedInstance;

/**
 * Check that Lara's existing DarkSword initialization has completed
 */
- (BOOL)initializeKernelExploit;

/**
 * Attach to target process by executable name (e.g., "FreeFire", "FreeFireMax")
 */
- (BOOL)attachToProcessNamed:(NSString *)processName;
- (void)detach;

/**
 * Read memory buffer from target process at virtual address
 */
- (BOOL)readMemoryAtAddress:(uint64_t)address buffer:(void *)buffer size:(size_t)size;

/**
 * Read primitive types from target process memory
 */
- (uint8_t)readUInt8:(uint64_t)address;
- (uint16_t)readUInt16:(uint64_t)address;
- (uint32_t)readUInt32:(uint64_t)address;
- (uint64_t)readUInt64:(uint64_t)address;
- (float)readFloat:(uint64_t)address;

/**
 * Write memory buffer through the target's DarkSword VM mapping.
 * A failed multi-page write may have written earlier pages.
 */
- (BOOL)writeMemoryAtAddress:(uint64_t)address buffer:(const void *)buffer size:(size_t)size;

@end

NS_ASSUME_NONNULL_END
