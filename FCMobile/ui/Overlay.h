#import <UIKit/UIKit.h>
@interface FCMOverlay : UIView
@property(nonatomic,copy) void (^geometryChanged)(void);
- (UIView *)drawingView;
- (CGRect)interactiveFrame;
- (BOOL)handleScreenPoint:(CGPoint)point phase:(UITouchPhase)phase identity:(NSInteger)identity;
- (void)cancelScreenTouch;
- (void)stop;
- (void)stopWithCompletion:(void (^)(void))completion;
@end
