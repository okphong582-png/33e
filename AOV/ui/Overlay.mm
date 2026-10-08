#import "Overlay.h"
#include "../core/Process.h"
#include "TouchState.h"
#include "../core/CameraZoom.h"
#import <QuartzCore/QuartzCore.h>
#include <memory>
static UIColor *Mint(){return [UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];}
static UIFont *Font(CGFloat size,UIFontWeight weight){return [UIFont systemFontOfSize:size weight:weight];}
static void StrokeLine(CGContextRef c,CGPoint start,CGPoint end,UIColor *color,CGFloat width){
    CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,width);
    CGContextMoveToPoint(c,start.x,start.y);CGContextAddLineToPoint(c,end.x,end.y);CGContextStrokePath(c);
}
@interface AOVDrawing : UIView { @public aov::Snapshot snapshot; }
@end
@implementation AOVDrawing
- (instancetype)initWithFrame:(CGRect)f{if((self=[super initWithFrame:f])){self.backgroundColor=UIColor.clearColor;self.opaque=NO;self.userInteractionEnabled=NO;}return self;}
- (void)drawRect:(CGRect)rect{
    if(snapshot.state!=aov::State::ready)return;
    CGContextRef c=UIGraphicsGetCurrentContext();
    for(const auto &a:snapshot.actors){
        aov::Point p,t;
        aov::Vec3 top=a.position;top.y+=a.monster?1.5f:2.1f;
        if(!aov::project(a.position,snapshot.view,snapshot.projection,self.bounds.size.width,self.bounds.size.height,p)||!aov::project(top,snapshot.view,snapshot.projection,self.bounds.size.width,self.bounds.size.height,t))continue;
        CGFloat h=std::hypot(p.x-t.x,p.y-t.y);if(h<6||h>self.bounds.size.height*.8)continue;
        CGFloat w=MAX(20,h*.48),x=t.x-w*.5,y=MIN(t.y,p.y),bottom=MAX(t.y,p.y);
        UIColor *color=a.monster?[UIColor colorWithRed:.35 green:.72 blue:1 alpha:1]:Mint();
        // Same top-center snapline and world X/Y/Z triad as the FF overlay.
        CGPoint anchor=CGPointMake(self.bounds.size.width*.5,self.bounds.size.height*.08),target=CGPointMake(t.x,t.y);
        CGContextSetLineCap(c,kCGLineCapRound);
        StrokeLine(c,anchor,target,[UIColor colorWithWhite:0 alpha:.55],2.7);
        StrokeLine(c,anchor,target,[color colorWithAlphaComponent:.8],1.3);
        UIColor *axisColors[]={UIColor.systemRedColor,UIColor.systemGreenColor,UIColor.systemBlueColor};
        for(int axis=0;axis<3;axis++){
            aov::Vec3 end=top;if(axis==0)end.x+=.65f;else if(axis==1)end.y+=.65f;else end.z+=.65f;
            aov::Point projected;
            if(!aov::project(end,snapshot.view,snapshot.projection,self.bounds.size.width,self.bounds.size.height,projected))continue;
            CGPoint endpoint=CGPointMake(projected.x,projected.y);
            StrokeLine(c,target,endpoint,axisColors[axis],1.5);
            CGFloat dx=endpoint.x-target.x,dy=endpoint.y-target.y,length=std::hypot(dx,dy);
            if(length>8){CGFloat ux=dx/length,uy=dy/length;StrokeLine(c,endpoint,CGPointMake(endpoint.x-ux*4+uy*2,endpoint.y-uy*4-ux*2),axisColors[axis],1.5);StrokeLine(c,endpoint,CGPointMake(endpoint.x-ux*4-uy*2,endpoint.y-uy*4+ux*2),axisColors[axis],1.5);}
        }
        CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:0 alpha:.72].CGColor);CGContextSetLineWidth(c,3.3);
        CGFloat corner=MIN(14,w*.3);
        auto box=[&](){
            CGContextBeginPath(c);
            for(int side=0;side<2;side++){
                for(int end=0;end<2;end++){
                    CGFloat bx=side?x+w:x,by=end?bottom:y;
                    CGContextMoveToPoint(c,bx+(side?-corner:corner),by);CGContextAddLineToPoint(c,bx,by);CGContextAddLineToPoint(c,bx,by+(end?-corner:corner));
                }
            }
            CGContextStrokePath(c);
        };box();CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,1.7);box();
        CGFloat ratio=std::clamp(float(a.hp)/a.maxHP,0.f,1.f);
        CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:0 alpha:.7].CGColor);CGContextFillRect(c,CGRectMake(x-1,bottom+6,w+2,5));
        UIColor *hp=ratio>.5?Mint():(ratio>.25?UIColor.systemYellowColor:UIColor.systemRedColor);
        CGContextSetFillColorWithColor(c,hp.CGColor);CGContextFillRect(c,CGRectMake(x,bottom+7,w*ratio,3));
        NSString *name=a.monster?@"Quái":@"Địch";
        NSShadow *shadow=[NSShadow new];shadow.shadowColor=UIColor.blackColor;shadow.shadowOffset=CGSizeMake(0,1);shadow.shadowBlurRadius=2;
        NSDictionary *attrs=@{NSFontAttributeName:Font(12,UIFontWeightSemibold),NSForegroundColorAttributeName:color,NSShadowAttributeName:shadow};
        CGSize s=[name sizeWithAttributes:attrs];[name drawAtPoint:CGPointMake(t.x-s.width*.5,y-s.height-5) withAttributes:attrs];
    }
}
@end
@interface AOVFeatureRow : UIControl
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *detailLabel;
@property(nonatomic,strong) UILabel *mark;
@property(nonatomic,strong) UIView *checkbox;
- (instancetype)initWithName:(NSString *)name detail:(NSString *)detail symbol:(NSString *)symbol;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
@implementation AOVFeatureRow
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
@interface AOVOverlay () {
    AOVDrawing *_drawing;
    UIView *_panel;
    UIButton *_dot,*_close;
    AOVFeatureRow *_enemy,*_monster;
    UISlider *_cameraSlider;
    UIButton *_cameraReset;
    UILabel *_cameraTitle,*_cameraValue;
    UIView *_divider;
    CAGradientLayer *_panelGradient;
    UILabel *_status;
    NSTimer *_timer;
    dispatch_queue_t _queue;
    std::shared_ptr<aov::Process> _reader;
    BOOL _busy,_enemies,_monsters;
    float _zoom;
    CGPoint _touchStart,_dotStart;
    aov::TouchState _touch;
    __weak UIControl *_touchTarget;
}
@end
@implementation AOVOverlay
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
        _reader=std::make_shared<aov::Process>();_queue=dispatch_queue_create("com.hoanghadev.aov.reader",DISPATCH_QUEUE_SERIAL);
        NSUserDefaults *d=NSUserDefaults.standardUserDefaults;_enemies=[d boolForKey:@"AOV.Enemies"];
        if(![d objectForKey:@"AOV.Monsters"])[d setBool:[d boolForKey:@"AOV.BlueBuff"] forKey:@"AOV.Monsters"];
        _monsters=[d boolForKey:@"AOV.Monsters"];
        _zoom=aov::zoomMultiplier([d objectForKey:@"AOV.CameraZoom"]?[d floatForKey:@"AOV.CameraZoom"]:1.f);
        _drawing=[[AOVDrawing alloc] initWithFrame:self.bounds];_drawing.autoresizingMask=self.autoresizingMask;[self addSubview:_drawing];
        _dot=[self button:@"A" action:@selector(toggleMenu)];_dot.titleLabel.font=Font(20,UIFontWeightBold);_dot.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_dot.contentEdgeInsets=UIEdgeInsetsZero;
        _dot.frame=CGRectMake(22,80,52,52);_dot.layer.cornerRadius=26;[_dot setTitleColor:Mint() forState:UIControlStateNormal];_dot.layer.borderColor=Mint().CGColor;
        _dot.accessibilityLabel=@"Mở menu AOV";_dot.layer.shadowColor=UIColor.blackColor.CGColor;_dot.layer.shadowOpacity=.35;_dot.layer.shadowRadius=8;_dot.layer.shadowOffset=CGSizeMake(0,3);
        [_dot addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)]];[self addSubview:_dot];
        _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithWhite:.07 alpha:1];_panel.layer.cornerRadius=22;_panel.layer.borderWidth=1;_panel.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;_panel.hidden=YES;
        _panel.layer.shadowColor=UIColor.blackColor.CGColor;_panel.layer.shadowOpacity=.4;_panel.layer.shadowRadius=18;_panel.layer.shadowOffset=CGSizeMake(0,6);[self addSubview:_panel];
        _panelGradient=[CAGradientLayer layer];_panelGradient.colors=@[(id)[UIColor colorWithRed:.08 green:.15 blue:.14 alpha:1].CGColor,(id)[UIColor colorWithWhite:.07 alpha:1].CGColor];_panelGradient.cornerRadius=22;[_panel.layer insertSublayer:_panelGradient atIndex:0];
        UILabel *title=[UILabel new];title.text=@"AOV Menu";title.font=Font(23,UIFontWeightBold);title.textColor=UIColor.whiteColor;title.frame=CGRectMake(20,14,190,30);[_panel addSubview:title];
        UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.textColor=Mint();credit.font=Font(11,UIFontWeightMedium);credit.frame=CGRectMake(20,47,190,16);[_panel addSubview:credit];
        _close=[self button:@"×" action:@selector(toggleMenu)];_close.frame=CGRectMake(244,12,44,44);_close.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_close.contentEdgeInsets=UIEdgeInsetsZero;_close.titleLabel.font=Font(25,UIFontWeightMedium);_close.accessibilityLabel=@"Đóng menu";[_panel addSubview:_close];
        UILabel *section=[UILabel new];section.text=@"HIỂN THỊ";section.textColor=[UIColor colorWithWhite:.5 alpha:1];section.font=Font(10,UIFontWeightSemibold);section.frame=CGRectMake(20,73,240,14);[_panel addSubview:section];
        _enemy=[[AOVFeatureRow alloc] initWithName:@"ESP địch" detail:@"Tướng · Dây · Thanh máu" symbol:@"person.crop.square"];_enemy.frame=CGRectMake(18,93,268,64);[_enemy addTarget:self action:@selector(toggleEnemy) forControlEvents:UIControlEventTouchUpInside];[_panel addSubview:_enemy];
        _monster=[[AOVFeatureRow alloc] initWithName:@"ESP quái" detail:@"Quái · Dây · Thanh máu" symbol:@"scope"];_monster.frame=CGRectMake(18,167,268,64);[_monster addTarget:self action:@selector(toggleMonsters) forControlEvents:UIControlEventTouchUpInside];[_panel addSubview:_monster];
        _cameraTitle=[UILabel new];_cameraTitle.text=@"Cam xa";_cameraTitle.font=Font(14,UIFontWeightSemibold);_cameraTitle.textColor=UIColor.whiteColor;[_panel addSubview:_cameraTitle];
        _cameraValue=[UILabel new];_cameraValue.textColor=Mint();_cameraValue.font=Font(12,UIFontWeightSemibold);_cameraValue.textAlignment=NSTextAlignmentRight;[_panel addSubview:_cameraValue];
        _cameraSlider=[UISlider new];_cameraSlider.minimumValue=1;_cameraSlider.maximumValue=4;_cameraSlider.value=_zoom;_cameraSlider.minimumTrackTintColor=Mint();_cameraSlider.maximumTrackTintColor=[UIColor colorWithWhite:.23 alpha:1];_cameraSlider.thumbTintColor=Mint();_cameraSlider.accessibilityLabel=@"Khoảng cách camera";
        [_cameraSlider addTarget:self action:@selector(cameraChanged:) forControlEvents:UIControlEventValueChanged];[_panel addSubview:_cameraSlider];
        _cameraReset=[self button:@"Gốc" action:@selector(resetCamera)];_cameraReset.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_cameraReset.contentEdgeInsets=UIEdgeInsetsZero;_cameraReset.titleLabel.font=Font(12,UIFontWeightSemibold);_cameraReset.accessibilityLabel=@"Khôi phục camera gốc";[_panel addSubview:_cameraReset];
        _divider=[UIView new];_divider.backgroundColor=[UIColor colorWithWhite:1 alpha:.08];[_panel addSubview:_divider];
        _status=[UILabel new];_status.font=Font(11,UIFontWeightMedium);_status.textColor=[UIColor colorWithWhite:.65 alpha:1];_status.numberOfLines=1;_status.frame=CGRectMake(20,249,264,23);[_panel addSubview:_status];
        [self updateButtons];
        __weak AOVOverlay *weak=self;
        _timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *t){[weak tick];}];[NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }return self;
}
- (void)stop{[self stopWithCompletion:nil];}
- (void)stopWithCompletion:(void (^)(void))completion{
    [_timer invalidate];_timer=nil;[self cancelScreenTouch];auto reader=_reader;
    dispatch_async(_queue,^{reader->restoreCamera();if(completion)dispatch_async(dispatch_get_main_queue(),completion);});
}
- (void)dealloc{[_timer invalidate];}
- (void)layoutSubviews{
    [super layoutSubviews];_drawing.frame=self.bounds;
    UIEdgeInsets safe=self.safeAreaInsets;
    CGFloat maxX=MAX(safe.left+32,self.bounds.size.width-safe.right-32),maxY=MAX(safe.top+32,self.bounds.size.height-safe.bottom-32);
    _dot.center=CGPointMake(std::clamp(_dot.center.x,safe.left+32,maxX),std::clamp(_dot.center.y,safe.top+32,maxY));
    // Never assign a frame while a view has an animated transform.
    CGFloat available=self.bounds.size.height-safe.top-safe.bottom-16;
    BOOL compact=available<330;CGFloat panelHeight=compact?304:330;
    _panel.bounds=CGRectMake(0,0,304,panelHeight);
    CGFloat x=std::clamp(_dot.frame.origin.x,safe.left+8,MAX(safe.left+8,self.bounds.size.width-safe.right-312));
    CGFloat y=std::clamp(_dot.frame.origin.y,safe.top+8,MAX(safe.top+8,self.bounds.size.height-safe.bottom-panelHeight-8));
    _panel.center=CGPointMake(x+152,y+panelHeight*.5);_panelGradient.frame=_panel.bounds;
    CGFloat rowHeight=compact?48:56;
    _enemy.frame=CGRectMake(18,93,268,rowHeight);_monster.frame=CGRectMake(18,101+rowHeight,268,rowHeight);
    CGFloat cameraY=109+2*rowHeight;
    _cameraTitle.frame=CGRectMake(20,cameraY,100,22);_cameraValue.frame=CGRectMake(123,cameraY,80,22);
    _cameraReset.frame=CGRectMake(224,cameraY-2,60,28);_cameraSlider.frame=CGRectMake(20,cameraY+22,264,38);
    _divider.frame=CGRectMake(20,panelHeight-31,264,1);_status.frame=CGRectMake(20,panelHeight-26,264,22);
    _panel.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:_panel.bounds cornerRadius:22].CGPath;
    if(self.geometryChanged)self.geometryChanged();
}
- (UIControl *)controlAtPoint:(CGPoint)p{
    if(!self.userInteractionEnabled||self.hidden||self.alpha<.01)return nil;
    if(!_panel.hidden){
        for(UIControl *control in @[_close,_enemy,_monster,_cameraSlider,_cameraReset]){
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
- (void)updateButtons{
    [_enemy setOn:_enemies animated:YES];[_monster setOn:_monsters animated:YES];
    _cameraValue.text=[NSString stringWithFormat:@"%.1f×",_zoom];
}
- (void)toggleEnemy{_enemies=!_enemies;[NSUserDefaults.standardUserDefaults setBool:_enemies forKey:@"AOV.Enemies"];[self updateButtons];}
- (void)toggleMonsters{_monsters=!_monsters;[NSUserDefaults.standardUserDefaults setBool:_monsters forKey:@"AOV.Monsters"];[self updateButtons];}
- (void)cameraChanged:(UISlider *)slider{
    _zoom=aov::zoomMultiplier(slider.value);[NSUserDefaults.standardUserDefaults setFloat:_zoom forKey:@"AOV.CameraZoom"];[self updateButtons];
}
- (void)resetCamera{_zoom=1;_cameraSlider.value=1;[self cameraChanged:_cameraSlider];}
- (void)activateControl:(UIControl *)control{
    // External HUD input calls our actions directly instead of UIKit tracking.
    if(control==_dot||control==_close)[self toggleMenu];
    else if(control==_enemy)[self toggleEnemy];
    else if(control==_monster)[self toggleMonsters];
    else if(control==_cameraReset)[self resetCamera];
}
- (void)moveCameraSlider:(CGPoint)p{
    CGPoint local=[self convertPoint:p toView:_cameraSlider];
    CGRect track=[_cameraSlider trackRectForBounds:_cameraSlider.bounds];
    CGFloat fraction=std::clamp((local.x-CGRectGetMinX(track))/MAX(1,track.size.width),CGFloat(0),CGFloat(1));
    _cameraSlider.value=aov::zoomMultiplier(1+3*fraction);[self cameraChanged:_cameraSlider];
}
- (void)tick{
    if(!self.window||self.hidden||_busy)return;
    _busy=YES;BOOL enemy=_enemies,monster=_monsters;float zoom=_zoom;auto reader=_reader;__weak AOVOverlay *weak=self;
    dispatch_async(_queue,^{
        auto sample=reader->update(enemy,monster,zoom);
        dispatch_async(dispatch_get_main_queue(),^{AOVOverlay *s=weak;if(!s)return;s->_busy=NO;
            if(enemy!=s->_enemies||monster!=s->_monsters||zoom!=s->_zoom)return;
            s->_drawing->snapshot=std::move(sample);[s->_drawing setNeedsDisplay];
            switch(s->_drawing->snapshot.state){
                case aov::State::ready:s->_status.text=@"ESP đang hoạt động";break;
                case aov::State::unsupported:s->_status.text=@"Bản AOV này chưa có dữ liệu tương thích";break;
                case aov::State::denied:s->_status.text=@"iOS không cấp quyền đọc game";break;
                case aov::State::disconnected:s->_status.text=@"Mở Liên Quân VN";break;
                default:s->_status.text=@"Chờ dữ liệu trận đấu";break;
            }
            if(!enemy&&!monster&&zoom==1)s->_status.text=@"Chọn chức năng để bật";
            if(s->_drawing->snapshot.zoom==aov::ZoomState::active)s->_status.text=@"Cam xa đang áp dụng";
            else if(s->_drawing->snapshot.zoom==aov::ZoomState::denied)s->_status.text=@"iOS không cấp quyền chỉnh camera";
            else if(zoom>1&&s->_drawing->snapshot.state==aov::State::waiting)s->_status.text=@"Cam xa · Chờ camera trận đấu";
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
        if(_touchTarget==_cameraSlider)[self moveCameraSlider:p];return YES;
    }
    if(!_touch.owns(identity))return NO;
    if(phase==UITouchPhaseMoved){
        _touch.move(identity,p.x,p.y,CACurrentMediaTime());
        CGFloat dx=p.x-_touchStart.x,dy=p.y-_touchStart.y;
        if(_touchTarget==_cameraSlider)[self moveCameraSlider:p];
        else if(_touchTarget==_dot&&_touch.dragged()){_dot.center=CGPointMake(_dotStart.x+dx,_dotStart.y+dy);[self setNeedsLayout];[self layoutIfNeeded];}
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
