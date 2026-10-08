#import <UIKit/UIKit.h>
@interface AOVOverlay : UIView
- (BOOL)handleScreenPoint:(CGPoint)point phase:(UITouchPhase)phase identity:(NSInteger)identity;
- (void)cancelScreenTouch;
- (void)stop;
@end
