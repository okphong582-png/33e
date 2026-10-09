#import "Overlay.h"
#include "../core/Process.h"
#include "TouchState.h"
#include <algorithm>
#import <QuartzCore/QuartzCore.h>
#include <memory>
static UIColor *Mint(){return [UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];}
static UIFont *Font(CGFloat size,UIFontWeight weight){return [UIFont systemFontOfSize:size weight:weight];}
@interface FCMFeatureRow : UIControl
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *detailLabel;
@property(nonatomic,strong) UILabel *mark;
@property(nonatomic,strong) UIView *checkbox;
- (instancetype)initWithName:(NSString *)name detail:(NSString *)detail symbol:(NSString *)symbol;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
@implementation FCMFeatureRow
- (instancetype)initWithName:(NSString *)name detail:(NSString *)detail symbol:(NSString *)symbol {
    if((self=[super initWithFrame:CGRectZero])){
        self.layer.cornerRadius=14;self.layer.borderWidth=1;self.isAccessibilityElement=YES;self.accessibilityLabel=name;
        UIImageView *icon=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
        icon.tintColor=Mint();icon.contentMode=UIViewContentModeScaleAspectFit;icon.frame=CGRectMake(14,21,22,22);[self addSubview:icon];
        _nameLabel=[UILabel new];_nameLabel.text=name;_nameLabel.font=Font(16,UIFontWeightSemibold);_nameLabel.textColor=UIColor.whiteColor;_nameLabel.frame=CGRectMake(48,12,176,22);[self addSubview:_nameLabel];
        _detailLabel=[UILabel new];_detailLabel.text=detail;_detailLabel.font=Font(11,UIFontWeightMedium);_detailLabel.textColor=[UIColor colorWithWhite:.6 alpha:1];_detailLabel.frame=CGRectMake(48,36,176,16);[self addSubview:_detailLabel];
        _checkbox=[UIView new];_checkbox.layer.cornerRadius=7;_checkbox.layer.borderWidth=1.2;_checkbox.frame=CGRectMake(230,20,24,24);[self addSubview:_checkbox];
        _mark=[UILabel new];_mark.text=@"X";_mark.font=Font(14,UIFontWeightBold);_mark.textAlignment=NSTextAlignmentCenter;_mark.frame=_checkbox.bounds;[_checkbox addSubview:_mark];
        for(UIView *child in self.subviews)child.userInteractionEnabled=NO;
        [self setOn:NO animated:NO];
    }return self;
}
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    self.selected=on;self.accessibilityValue=on?@"Bật":@"Tắt";
    self.accessibilityTraits=UIAccessibilityTraitButton|(on?UIAccessibilityTraitSelected:0);
    void (^changes)(void)=^{
        self.backgroundColor=on?[Mint() colorWithAlphaComponent:.09]:[UIColor colorWithWhite:.12 alpha:1];
        self.layer.borderColor=(on?[Mint() colorWithAlphaComponent:.6]:[UIColor colorWithWhite:.2 alpha:1]).CGColor;
        self->_checkbox.backgroundColor=on?Mint():UIColor.clearColor;
        self->_checkbox.layer.borderColor=(on?Mint():[UIColor colorWithWhite:.4 alpha:1]).CGColor;
        self->_mark.textColor=[UIColor colorWithWhite:.06 alpha:1];self->_mark.alpha=on?1:0;
    };
    if(animated&&!UIAccessibilityIsReduceMotionEnabled())[UIView animateWithDuration:.16 animations:changes];else changes();
}
- (void)setHighlighted:(BOOL)highlighted {[super setHighlighted:highlighted];self.alpha=highlighted?.72:1;}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat mid=CGRectGetMidY(self.bounds);
    for(UIView *v in self.subviews)if([v isKindOfClass:UIImageView.class])v.center=CGPointMake(25,mid);
    _nameLabel.frame=CGRectMake(48,mid-20,176,22);_detailLabel.frame=CGRectMake(48,mid+4,176,16);
    _checkbox.center=CGPointMake(242,mid);
}
@end
@interface FCMOverlay () {
    UIView *_drawing;
    UIView *_panel;
    UIButton *_dot,*_close;
    FCMFeatureRow *_shot;
    UIView *_divider;
    CAGradientLayer *_panelGradient;
    UILabel *_status;
    NSTimer *_timer;
    dispatch_queue_t _queue;
    std::shared_ptr<fcm::Process> _reader;
    BOOL _busy,_enabled;
    CGPoint _touchStart,_dotStart;
    fcm::TouchState _touch;
    __weak UIControl *_touchTarget;
}
@end
@implementation FCMOverlay
- (UIView *)drawingView{return _drawing;}
- (CGRect)interactiveFrame{return _panel.hidden?_dot.frame:_panel.frame;}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];[b setTitle:title forState:UIControlStateNormal];b.titleLabel.font=Font(16,UIFontWeightSemibold);
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;b.contentEdgeInsets=UIEdgeInsetsMake(0,14,0,14);
    b.backgroundColor=[UIColor colorWithWhite:.14 alpha:1];b.layer.cornerRadius=12;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:.25 alpha:1].CGColor;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        self.backgroundColor=UIColor.clearColor;self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _reader=std::make_shared<fcm::Process>();_queue=dispatch_queue_create("com.hoanghadev.fcm.reader",DISPATCH_QUEUE_SERIAL);
        _drawing=[[UIView alloc] initWithFrame:self.bounds];_drawing.backgroundColor=UIColor.clearColor;_drawing.userInteractionEnabled=NO;[self addSubview:_drawing];
        _dot=[self button:@"FC" action:@selector(toggleMenu)];_dot.titleLabel.font=Font(20,UIFontWeightBold);_dot.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_dot.contentEdgeInsets=UIEdgeInsetsZero;
        _dot.frame=CGRectMake(22,80,52,52);_dot.layer.cornerRadius=26;[_dot setTitleColor:Mint() forState:UIControlStateNormal];_dot.layer.borderColor=Mint().CGColor;
        _dot.accessibilityLabel=@"Mở menu FCM";_dot.layer.shadowColor=UIColor.blackColor.CGColor;_dot.layer.shadowOpacity=.35;_dot.layer.shadowRadius=8;_dot.layer.shadowOffset=CGSizeMake(0,3);
        [_dot addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)]];[self addSubview:_dot];
        _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithWhite:.07 alpha:1];_panel.layer.cornerRadius=22;_panel.layer.borderWidth=1;_panel.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;_panel.hidden=YES;
        _panel.layer.shadowColor=UIColor.blackColor.CGColor;_panel.layer.shadowOpacity=.4;_panel.layer.shadowRadius=18;_panel.layer.shadowOffset=CGSizeMake(0,6);[self addSubview:_panel];
        _panelGradient=[CAGradientLayer layer];_panelGradient.colors=@[(id)[UIColor colorWithRed:.08 green:.15 blue:.14 alpha:1].CGColor,(id)[UIColor colorWithWhite:.07 alpha:1].CGColor];_panelGradient.cornerRadius=22;[_panel.layer insertSublayer:_panelGradient atIndex:0];
        UILabel *title=[UILabel new];title.text=@"FC Mobile";title.font=Font(23,UIFontWeightBold);title.textColor=UIColor.whiteColor;title.frame=CGRectMake(20,14,190,30);[_panel addSubview:title];
        UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.textColor=Mint();credit.font=Font(11,UIFontWeightMedium);credit.frame=CGRectMake(20,47,190,16);[_panel addSubview:credit];
        _close=[self button:@"×" action:@selector(toggleMenu)];_close.frame=CGRectMake(244,12,44,44);_close.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_close.contentEdgeInsets=UIEdgeInsetsZero;_close.titleLabel.font=Font(25,UIFontWeightMedium);_close.accessibilityLabel=@"Đóng menu";[_panel addSubview:_close];
        UILabel *section=[UILabel new];section.text=@"HỖ TRỢ SÚT · THỬ NGHIỆM";section.textColor=[UIColor colorWithWhite:.5 alpha:1];section.font=Font(10,UIFontWeightSemibold);section.frame=CGRectMake(20,73,240,14);[_panel addSubview:section];
        _shot=[[FCMFeatureRow alloc] initWithName:@"Giảm sai số sút" detail:@"Bật trước khi vào trận" symbol:@"soccerball"];[_shot addTarget:self action:@selector(toggleShot) forControlEvents:UIControlEventTouchUpInside];[_panel addSubview:_shot];
        _divider=[UIView new];_divider.backgroundColor=[UIColor colorWithWhite:1 alpha:.08];[_panel addSubview:_divider];
        _status=[UILabel new];_status.font=Font(11,UIFontWeightMedium);_status.textColor=[UIColor colorWithWhite:.65 alpha:1];_status.numberOfLines=1;_status.frame=CGRectMake(20,249,264,23);[_panel addSubview:_status];
        [self updateButtons];
        __weak FCMOverlay *weak=self;
        _timer=[NSTimer timerWithTimeInterval:.25 repeats:YES block:^(NSTimer *t){[weak tick];}];[NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }return self;
}
- (void)stop{[self stopWithCompletion:nil];}
- (void)stopWithCompletion:(void (^)(void))completion{
    [_timer invalidate];_timer=nil;[self cancelScreenTouch];auto reader=_reader;
    dispatch_async(_queue,^{reader->restoreShot();if(completion)dispatch_async(dispatch_get_main_queue(),completion);});
}
- (void)dealloc{[_timer invalidate];}
- (void)layoutSubviews{
    [super layoutSubviews];_drawing.frame=self.bounds;
    UIEdgeInsets safe=self.safeAreaInsets;
    CGFloat maxX=MAX(safe.left+32,self.bounds.size.width-safe.right-32),maxY=MAX(safe.top+32,self.bounds.size.height-safe.bottom-32);
    _dot.center=CGPointMake(std::clamp(_dot.center.x,safe.left+32,maxX),std::clamp(_dot.center.y,safe.top+32,maxY));
    // Never assign a frame while a view has an animated transform.
    CGFloat panelHeight=210;
    _panel.bounds=CGRectMake(0,0,304,panelHeight);
    CGFloat x=std::clamp(_dot.frame.origin.x,safe.left+8,MAX(safe.left+8,self.bounds.size.width-safe.right-312));
    CGFloat y=std::clamp(_dot.frame.origin.y,safe.top+8,MAX(safe.top+8,self.bounds.size.height-safe.bottom-panelHeight-8));
    _panel.center=CGPointMake(x+152,y+panelHeight*.5);_panelGradient.frame=_panel.bounds;
    _shot.frame=CGRectMake(18,93,268,64);
    _divider.frame=CGRectMake(20,panelHeight-31,264,1);_status.frame=CGRectMake(20,panelHeight-26,264,22);
    _panel.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:_panel.bounds cornerRadius:22].CGPath;
    if(self.geometryChanged)self.geometryChanged();
}
- (UIControl *)controlAtPoint:(CGPoint)p{
    if(!self.userInteractionEnabled||self.hidden||self.alpha<.01)return nil;
    if(!_panel.hidden){
        for(UIControl *control in @[_close,_shot]){
            CGPoint local=[self convertPoint:p toView:control];
            if(control.enabled&&!control.hidden&&CGRectContainsPoint(control.bounds,local))return control;
        }
    }
    if(!_dot.hidden&&CGRectContainsPoint(_dot.frame,p))return _dot;
    return nil;
}
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e{return [self controlAtPoint:p]!=nil;}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e{return [self controlAtPoint:p];}
- (void)toggleMenu{
    BOOL show=_panel.hidden;[self cancelScreenTouch];[_panel.layer removeAllAnimations];_panel.transform=CGAffineTransformIdentity;_panel.alpha=1;
    _panel.hidden=!show;_dot.hidden=show;[self setNeedsLayout];[self layoutIfNeeded];
    if(show&&!UIAccessibilityIsReduceMotionEnabled()){
        // Fade without moving hit regions underneath an incoming touch.
        _panel.alpha=0;
        [UIView animateWithDuration:.15 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{self->_panel.alpha=1;} completion:nil];
    }
}
- (void)panDot:(UIPanGestureRecognizer *)g{CGPoint d=[g translationInView:self];_dot.center=CGPointMake(_dot.center.x+d.x,_dot.center.y+d.y);[g setTranslation:CGPointZero inView:self];[self setNeedsLayout];}
- (void)updateButtons{[_shot setOn:_enabled animated:YES];}
- (void)toggleShot{_enabled=!_enabled;[self updateButtons];[self tick];}
- (void)activateControl:(UIControl *)control{if(control==_dot||control==_close)[self toggleMenu];else if(control==_shot)[self toggleShot];}
- (void)tick{
    if(!self.window||self.hidden||_busy)return;
    _busy=YES;BOOL enabled=_enabled;auto reader=_reader;__weak FCMOverlay *weak=self;
    dispatch_async(_queue,^{auto state=reader->update(enabled);
        dispatch_async(dispatch_get_main_queue(),^{FCMOverlay *s=weak;if(!s)return;s->_busy=NO;if(enabled!=s->_enabled)return;
            switch(state){
                case fcm::State::ready:s->_status.text=@"Đã cập nhật tham số sút";break;
                case fcm::State::unsupported:s->_status.text=@"Chỉ hỗ trợ FC Mobile VN 27.1.01";break;
                case fcm::State::denied:s->_status.text=@"iOS chưa cấp quyền chỉnh game";break;
                case fcm::State::disconnected:s->_status.text=@"Mở FC Mobile VN";break;
                case fcm::State::off:s->_status.text=@"Chọn chức năng để bật";break;
                default:s->_status.text=@"Chờ dữ liệu cài đặt sút";break;
            }
        });
    });
}
- (BOOL)handleScreenPoint:(CGPoint)point phase:(UITouchPhase)phase identity:(NSInteger)identity{
    if(!self.window)return NO;
    CGPoint p=[self convertPoint:point fromCoordinateSpace:UIScreen.mainScreen.coordinateSpace];
    if(phase==UITouchPhaseBegan){
        UIView *v=[self hitTest:p withEvent:nil];if(!v)return NO;
        if(!_touch.begin(identity,p.x,p.y,CACurrentMediaTime()))return NO;
        _touchTarget.highlighted=NO;
        while(v&&v!=self&&![v isKindOfClass:UIControl.class])v=v.superview;
        _touchTarget=[v isKindOfClass:UIControl.class]?(UIControl *)v:nil;
        _touchTarget.highlighted=YES;_touchStart=p;_dotStart=_dot.center;
        return YES;
    }
    if(!_touch.owns(identity))return NO;
    if(phase==UITouchPhaseMoved){
        _touch.move(identity,p.x,p.y,CACurrentMediaTime());
        CGFloat dx=p.x-_touchStart.x,dy=p.y-_touchStart.y;
        if(_touchTarget==_dot&&_touch.dragged()){_dot.center=CGPointMake(_dotStart.x+dx,_dotStart.y+dy);[self setNeedsLayout];[self layoutIfNeeded];}
        else if(_touchTarget)_touchTarget.highlighted=CGRectContainsPoint(_touchTarget.bounds,[self convertPoint:p toView:_touchTarget]);
    }
    if(phase==UITouchPhaseEnded||phase==UITouchPhaseCancelled){
        UIControl *target=_touchTarget;
        // Include travel in the lift packet when HID did not send a move.
        _touch.move(identity,p.x,p.y,CACurrentMediaTime());
        BOOL inside=target&&!target.hidden&&target.enabled&&CGRectContainsPoint(CGRectInset(target.bounds,-6,-6),[self convertPoint:p toView:target]);
        BOOL activate=_touch.finish(identity,phase==UITouchPhaseCancelled,inside);
        target.highlighted=NO;_touchTarget=nil;
        if(activate)[self activateControl:target];
    }return YES;
}
- (void)cancelScreenTouch{_touch.cancel();_touchTarget.highlighted=NO;_touchTarget=nil;}
@end
