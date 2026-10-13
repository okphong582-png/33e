#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../../../Core/TaskRop/RemoteCall.h"

NS_ASSUME_NONNULL_BEGIN
@interface FreeFireManager : NSObject
@property(atomic, assign) BOOL isESPEnabled;
@property(atomic, copy, readonly) NSString *statusMessage;
- (instancetype)initWithRemoteCall:(RemoteCall *)remoteCall;
- (void)runLoop;
- (void)startOverlay;
- (void)stopLoop;
- (void)clearOverlayTargets;
- (void)setOverlayMenuVisible:(BOOL)visible;
- (void)toggleOverlayMenu;
- (void)setOverlayFloatButtonPositionX:(CGFloat)xRatio y:(CGFloat)yRatio;
- (void)refreshOverlayLayout;
@end
NS_ASSUME_NONNULL_END
