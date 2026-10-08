#import <UIKit/UIKit.h>

// Main-thread UI only. No key, network, game or startup initialization here.
@interface MizzeLicenseLockView : UIView
- (void)updateMessage:(NSString *)message;
- (BOOL)handleTouchAtWindowPoint:(CGPoint)point phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId;
@end

MizzeLicenseLockView *MizzeShowLicenseLock(UIView *host, NSString *message);
void MizzeRemoveLicenseLock(UIView *host);
MizzeLicenseLockView *MizzeFindLicenseLock(UIView *host);
