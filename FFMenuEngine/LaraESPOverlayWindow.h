#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    float x, y, z;
} Vector3D;

typedef struct {
    float x, y;
} Vector2D;

typedef struct {
    BOOL showBox;
    BOOL showLine;
    BOOL showDistance;
    BOOL showHealth;
    BOOL showName;
    BOOL showSkeleton;
    BOOL showFOVCircle;
    BOOL showCrosshair;
    float fovRadius;
    float maxDistance;
} ESPConfig;

@interface LaraESPOverlayWindow : UIWindow

@property (nonatomic, assign) ESPConfig espConfig;
@property (nonatomic, assign) BOOL isOverlayActive;

+ (instancetype)sharedOverlay;
- (void)startOverlayLoop;
- (void)stopOverlayLoop;
- (void)toggleMenuVisibility;

@end

NS_ASSUME_NONNULL_END
