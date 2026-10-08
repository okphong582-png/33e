#import "LicenseLockView.h"
#import <QuartzCore/QuartzCore.h>
#include "LicenseLockImage.inc"

@interface MizzeLicenseLockView ()
@property(nonatomic,strong) UIView *card;
@property(nonatomic,strong) UIImageView *art;
@property(nonatomic,strong) UIView *content;
@property(nonatomic,strong) UILabel *title;
@property(nonatomic,strong) UIView *accent;
@property(nonatomic,strong) UITextView *notice;
@property(nonatomic,strong) UIButton *okay;
@property(nonatomic,copy) NSString *message;
@property(nonatomic,assign) NSInteger activePointer;
@property(nonatomic,assign) NSInteger scrollPointer;
@property(nonatomic,assign) CGFloat lastScrollY;
@end

@implementation MizzeLicenseLockView
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.backgroundColor=[UIColor colorWithWhite:0 alpha:.66];
        self.accessibilityViewIsModal=YES;self.activePointer=self.scrollPointer=NSIntegerMin;
        self.card=[UIView new];self.card.backgroundColor=[UIColor colorWithWhite:.065 alpha:1];
        self.card.layer.cornerRadius=14;self.card.clipsToBounds=YES;
        self.card.layer.borderColor=[UIColor colorWithRed:.49 green:.22 blue:.73 alpha:.8].CGColor;
        self.card.layer.borderWidth=1;[self addSubview:self.card];
        // Embedded in both binaries: TrollFools needs no companion resource files.
        // Decoding happens only when a locked key is shown, never in +load/constructor.
        NSData *data=[[NSData alloc] initWithBase64EncodedString:MizzeLicenseLockImage options:0];
        self.art=[[UIImageView alloc] initWithImage:[UIImage imageWithData:data]];
        self.art.contentMode=UIViewContentModeScaleAspectFill;self.art.clipsToBounds=YES;
        [self.card addSubview:self.art];
        // Cover the sample's baked text so the administrator's message replaces it.
        self.content=[UIView new];self.content.backgroundColor=[UIColor colorWithWhite:.065 alpha:1];
        [self.card addSubview:self.content];
        self.title=[UILabel new];self.title.text=@"THÔNG TIN · MIZZE";self.title.textColor=UIColor.whiteColor;
        self.title.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold];[self.content addSubview:self.title];
        self.accent=[UIView new];self.accent.backgroundColor=[UIColor colorWithRed:1 green:.77 blue:.1 alpha:1];
        [self.content addSubview:self.accent];
        self.notice=[UITextView new];self.notice.editable=NO;self.notice.selectable=NO;
        self.notice.backgroundColor=UIColor.clearColor;self.notice.textColor=UIColor.whiteColor;
        self.notice.textContainerInset=UIEdgeInsetsZero;self.notice.textContainer.lineFragmentPadding=0;
        self.notice.font=[UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [self.content addSubview:self.notice];
        self.okay=[UIButton buttonWithType:UIButtonTypeSystem];[self.okay setTitle:@"OK" forState:UIControlStateNormal];
        [self.okay setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.okay.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        self.okay.backgroundColor=self.accent.backgroundColor;self.okay.layer.cornerRadius=8;
        [self.okay addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [self.content addSubview:self.okay];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect safe=UIEdgeInsetsInsetRect(self.bounds,self.safeAreaInsets);
    CGFloat w=MIN(860,MAX(0,safe.size.width-32)),h=MIN(MAX(240,w*401/1284),MAX(0,safe.size.height-24));
    self.card.frame=CGRectMake(CGRectGetMidX(safe)-w/2,CGRectGetMidY(safe)-h/2,w,h);
    BOOL compact=w<500;
    self.art.frame=compact?CGRectMake(0,0,w,MIN(100,h*.32)):self.card.bounds;
    CGFloat x=compact?0:w*.38,y=compact?CGRectGetMaxY(self.art.frame):12;
    self.content.frame=CGRectMake(x,y,w-x,h-y-(compact?0:12));
    CGFloat cw=self.content.bounds.size.width,ch=self.content.bounds.size.height,p=16;
    self.title.frame=CGRectMake(p,12,MAX(0,cw-2*p),24);
    self.accent.frame=CGRectMake(p,40,32,3);
    self.okay.frame=CGRectMake(MAX(p,cw-116),MAX(0,ch-52),100,40);
    self.notice.frame=CGRectMake(p,54,MAX(0,cw-2*p),MAX(0,ch-116));
}
- (void)updateMessage:(NSString *)message {
    NSString *text=message.length?message:@"Tài khoản đã bị khóa.";
    if([self.message isEqualToString:text])return; // Polling does not reanimate or reopen OK.
    self.message=text;self.notice.text=text;self.notice.contentOffset=CGPointZero;
    self.hidden=NO;self.activePointer=self.scrollPointer=NSIntegerMin;
    [self.superview bringSubviewToFront:self];[self setNeedsLayout];[self layoutIfNeeded];
    [self.card.layer removeAnimationForKey:@"license-lock-shake"];
    if(!UIAccessibilityIsReduceMotionEnabled()) {
        CAKeyframeAnimation *shake=[CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        shake.values=@[@0,@-10,@8,@-5,@3,@0];shake.duration=.36;shake.repeatCount=0;
        [self.card.layer addAnimation:shake forKey:@"license-lock-shake"];
    }
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,self.title);
}
- (void)dismiss { self.hidden=YES;self.activePointer=self.scrollPointer=NSIntegerMin; }
- (BOOL)handleTouchAtWindowPoint:(CGPoint)point phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    if(self.hidden)return NO;
    CGPoint local=[self.okay convertPoint:point fromView:self.window];
    BOOL inside=CGRectContainsPoint(self.okay.bounds,local);
    CGPoint noticePoint=[self.notice convertPoint:point fromView:self.window];
    if(phase==UITouchPhaseBegan&&inside&&self.activePointer==NSIntegerMin)self.activePointer=pointerId;
    else if(phase==UITouchPhaseBegan&&CGRectContainsPoint(self.notice.bounds,noticePoint)&&self.scrollPointer==NSIntegerMin) {
        self.scrollPointer=pointerId;self.lastScrollY=point.y;
    }
    if(self.scrollPointer==pointerId) {
        if(phase==UITouchPhaseMoved) {
            CGFloat limit=MAX(0,self.notice.contentSize.height-self.notice.bounds.size.height);
            CGFloat offset=MIN(limit,MAX(0,self.notice.contentOffset.y+self.lastScrollY-point.y));
            self.notice.contentOffset=CGPointMake(0,offset);self.lastScrollY=point.y;
        }
        if(phase==UITouchPhaseEnded||phase==UITouchPhaseCancelled)self.scrollPointer=NSIntegerMin;
    }
    if(self.activePointer==pointerId&&(phase==UITouchPhaseEnded||phase==UITouchPhaseCancelled)) {
        self.activePointer=NSIntegerMin;
        if(phase==UITouchPhaseEnded&&inside)[self dismiss];
    }
    return YES;
}
@end

MizzeLicenseLockView *MizzeFindLicenseLock(UIView *host) {
    for(UIView *view in host.subviews)if([view isKindOfClass:MizzeLicenseLockView.class])return (MizzeLicenseLockView *)view;
    return nil;
}
MizzeLicenseLockView *MizzeShowLicenseLock(UIView *host,NSString *message) {
    if(!host)return nil;
    MizzeLicenseLockView *view=MizzeFindLicenseLock(host);
    if(!view){view=[[MizzeLicenseLockView alloc] initWithFrame:host.bounds];[host addSubview:view];}
    [view updateMessage:message];return view;
}
void MizzeRemoveLicenseLock(UIView *host) { [MizzeFindLicenseLock(host) removeFromSuperview]; }
