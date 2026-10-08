#import "Overlay.h"
#include "../core/Process.h"
#import <QuartzCore/QuartzCore.h>
#include <memory>
static UIColor *Mint(){return [UIColor colorWithRed:.35 green:.95 blue:.77 alpha:1];}
static UIFont *Font(CGFloat size,UIFontWeight weight){return [UIFont systemFontOfSize:size weight:weight];}
@interface AOVDrawing : UIView { @public aov::Snapshot snapshot; }
@end
@implementation AOVDrawing
- (instancetype)initWithFrame:(CGRect)f{if((self=[super initWithFrame:f])){self.backgroundColor=UIColor.clearColor;self.opaque=NO;self.userInteractionEnabled=NO;}return self;}
- (void)drawRect:(CGRect)rect{
    if(snapshot.state!=aov::State::ready)return;
    CGContextRef c=UIGraphicsGetCurrentContext();
    for(const auto &a:snapshot.actors){
        aov::Point p,t;
        aov::Vec3 top=a.position;top.y+=a.blue?1.5f:2.1f;
        if(!aov::project(a.position,snapshot.view,snapshot.projection,self.bounds.size.width,self.bounds.size.height,p)||!aov::project(top,snapshot.view,snapshot.projection,self.bounds.size.width,self.bounds.size.height,t))continue;
        CGFloat h=std::hypot(p.x-t.x,p.y-t.y);if(h<6||h>self.bounds.size.height*.8)continue;
        CGFloat w=MAX(20,h*.48),x=t.x-w*.5,y=MIN(t.y,p.y),bottom=MAX(t.y,p.y);
        UIColor *color=a.blue?[UIColor colorWithRed:.35 green:.72 blue:1 alpha:1]:Mint();
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
        NSString *name=a.blue?@"Bùa xanh":[NSString stringWithFormat:@"Địch · %d%%",int(ratio*100)];
        NSShadow *shadow=[NSShadow new];shadow.shadowColor=UIColor.blackColor;shadow.shadowOffset=CGSizeMake(0,1);shadow.shadowBlurRadius=2;
        NSDictionary *attrs=@{NSFontAttributeName:Font(12,UIFontWeightSemibold),NSForegroundColorAttributeName:color,NSShadowAttributeName:shadow};
        CGSize s=[name sizeWithAttributes:attrs];[name drawAtPoint:CGPointMake(t.x-s.width*.5,y-s.height-5) withAttributes:attrs];
    }
}
@end
@interface AOVOverlay () {
    AOVDrawing *_drawing;
    UIView *_panel;
    UIButton *_dot,*_enemy,*_blue,*_close;
    UILabel *_status;
    NSTimer *_timer;
    dispatch_queue_t _queue;
    std::shared_ptr<aov::Process> _reader;
    BOOL _busy,_enemies,_buffs;
    CGPoint _touchStart,_dotStart;
    NSInteger _touchIdentity;
    __weak UIView *_touchTarget;
    BOOL _moved;
}
@end
@implementation AOVOverlay
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];[b setTitle:title forState:UIControlStateNormal];b.titleLabel.font=Font(16,UIFontWeightSemibold);
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;b.contentEdgeInsets=UIEdgeInsetsMake(0,14,0,14);
    b.backgroundColor=[UIColor colorWithWhite:.14 alpha:1];b.layer.cornerRadius=12;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:.25 alpha:1].CGColor;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        self.backgroundColor=UIColor.clearColor;self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_touchIdentity=-1;
        _reader=std::make_shared<aov::Process>();_queue=dispatch_queue_create("com.hoanghadev.aov.reader",DISPATCH_QUEUE_SERIAL);
        NSUserDefaults *d=NSUserDefaults.standardUserDefaults;_enemies=[d boolForKey:@"AOV.Enemies"];_buffs=[d boolForKey:@"AOV.BlueBuff"];
        _drawing=[[AOVDrawing alloc] initWithFrame:self.bounds];_drawing.autoresizingMask=self.autoresizingMask;[self addSubview:_drawing];
        _dot=[self button:@"A" action:@selector(toggleMenu)];_dot.titleLabel.font=Font(20,UIFontWeightBold);_dot.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_dot.contentEdgeInsets=UIEdgeInsetsZero;
        _dot.frame=CGRectMake(22,80,48,48);_dot.layer.cornerRadius=24;[_dot setTitleColor:Mint() forState:UIControlStateNormal];_dot.layer.borderColor=Mint().CGColor;
        [_dot addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)]];[self addSubview:_dot];
        _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithWhite:.065 alpha:.97];_panel.layer.cornerRadius=20;_panel.layer.borderWidth=1;_panel.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;_panel.hidden=YES;[self addSubview:_panel];
        UILabel *title=[UILabel new];title.text=@"AOV";title.font=Font(23,UIFontWeightBold);title.textColor=Mint();title.frame=CGRectMake(18,16,180,30);[_panel addSubview:title];
        UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.textColor=[UIColor colorWithWhite:.6 alpha:1];credit.font=Font(11,UIFontWeightMedium);credit.frame=CGRectMake(18,48,190,16);[_panel addSubview:credit];
        _close=[self button:@"×" action:@selector(toggleMenu)];_close.frame=CGRectMake(220,16,42,42);_close.titleLabel.font=Font(23,UIFontWeightMedium);[_panel addSubview:_close];
        _enemy=[self button:@"" action:@selector(toggleEnemy)];_enemy.frame=CGRectMake(16,80,248,52);[_panel addSubview:_enemy];
        _blue=[self button:@"" action:@selector(toggleBlue)];_blue.frame=CGRectMake(16,142,248,52);[_panel addSubview:_blue];
        _status=[UILabel new];_status.font=Font(11,UIFontWeightMedium);_status.textColor=[UIColor colorWithWhite:.65 alpha:1];_status.numberOfLines=2;_status.frame=CGRectMake(18,206,246,32);[_panel addSubview:_status];
        [self updateButtons];
        __weak AOVOverlay *weak=self;
        _timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *t){[weak tick];}];[NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }return self;
}
- (void)stop{[_timer invalidate];_timer=nil;}
- (void)dealloc{[_timer invalidate];}
- (void)layoutSubviews{
    [super layoutSubviews];_drawing.frame=self.bounds;
    UIEdgeInsets safe=self.safeAreaInsets;
    CGFloat maxX=MAX(safe.left+24,self.bounds.size.width-safe.right-24),maxY=MAX(safe.top+24,self.bounds.size.height-safe.bottom-24);
    _dot.center=CGPointMake(std::clamp(_dot.center.x,safe.left+24,maxX),std::clamp(_dot.center.y,safe.top+24,maxY));
    _panel.frame=CGRectMake(std::clamp(_dot.frame.origin.x,safe.left+8,MAX(safe.left+8,self.bounds.size.width-safe.right-288)),std::clamp(_dot.frame.origin.y,safe.top+8,MAX(safe.top+8,self.bounds.size.height-safe.bottom-254)),280,246);
}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e{
    if(!self.userInteractionEnabled||self.hidden||self.alpha<.01)return nil;
    if(!_panel.hidden&&CGRectContainsPoint(_panel.frame,p))return [_panel hitTest:[self convertPoint:p toView:_panel] withEvent:e];
    if(CGRectContainsPoint(_dot.frame,p))return [_dot hitTest:[self convertPoint:p toView:_dot] withEvent:e];return nil;
}
- (void)toggleMenu{_panel.hidden=!_panel.hidden;[self setNeedsLayout];if(!_panel.hidden){_panel.alpha=0;_panel.transform=CGAffineTransformMakeScale(.97,.97);[UIView animateWithDuration:.18 animations:^{self->_panel.alpha=1;self->_panel.transform=CGAffineTransformIdentity;}];}}
- (void)panDot:(UIPanGestureRecognizer *)g{CGPoint d=[g translationInView:self];_dot.center=CGPointMake(_dot.center.x+d.x,_dot.center.y+d.y);[g setTranslation:CGPointZero inView:self];[self setNeedsLayout];}
- (void)updateButtons{
    [_enemy setTitle:_enemies?@"[ X ]   ESP địch":@"[   ]   ESP địch" forState:UIControlStateNormal];
    [_blue setTitle:_buffs?@"[ X ]   ESP bùa xanh":@"[   ]   ESP bùa xanh" forState:UIControlStateNormal];
    for(UIButton *b in @[_enemy,_blue]){BOOL on=b==_enemy?_enemies:_buffs;[b setTitleColor:on?Mint():UIColor.whiteColor forState:UIControlStateNormal];b.layer.borderColor=(on?Mint():[UIColor colorWithWhite:.25 alpha:1]).CGColor;}
}
- (void)toggleEnemy{_enemies=!_enemies;[NSUserDefaults.standardUserDefaults setBool:_enemies forKey:@"AOV.Enemies"];[self updateButtons];}
- (void)toggleBlue{_buffs=!_buffs;[NSUserDefaults.standardUserDefaults setBool:_buffs forKey:@"AOV.BlueBuff"];[self updateButtons];}
- (void)tick{
    if(!self.window||self.hidden||_busy)return;
    if(!_enemies&&!_buffs){_drawing->snapshot={};[_drawing setNeedsDisplay];_status.text=@"Chọn ESP để bật";return;}
    _busy=YES;BOOL enemy=_enemies,buff=_buffs;auto reader=_reader;__weak AOVOverlay *weak=self;
    dispatch_async(_queue,^{
        auto sample=reader->update(enemy,buff);
        dispatch_async(dispatch_get_main_queue(),^{AOVOverlay *s=weak;if(!s)return;s->_busy=NO;
            if(enemy!=s->_enemies||buff!=s->_buffs)return;
            s->_drawing->snapshot=std::move(sample);[s->_drawing setNeedsDisplay];
            switch(s->_drawing->snapshot.state){
                case aov::State::ready:s->_status.text=@"ESP đang hoạt động";break;
                case aov::State::unsupported:s->_status.text=@"Bản AOV này chưa có dữ liệu tương thích";break;
                case aov::State::denied:s->_status.text=@"iOS không cấp quyền đọc game";break;
                case aov::State::disconnected:s->_status.text=@"Mở Liên Quân VN";break;
                default:s->_status.text=@"Chờ dữ liệu trận đấu";break;
            }
        });
    });
}
- (BOOL)handleScreenPoint:(CGPoint)point phase:(UITouchPhase)phase identity:(NSInteger)identity{
    CGPoint p=[self convertPoint:point fromCoordinateSpace:UIScreen.mainScreen.coordinateSpace];
    if(phase==UITouchPhaseBegan){
        if(_touchIdentity!=-1)return NO;
        UIView *v=[self hitTest:p withEvent:nil];if(!v)return NO;
        _touchTarget=v;_touchIdentity=identity;_touchStart=p;_dotStart=_dot.center;_moved=NO;return YES;
    }
    if(identity!=_touchIdentity)return NO;
    if(phase==UITouchPhaseMoved){
        CGFloat dx=p.x-_touchStart.x,dy=p.y-_touchStart.y;if(std::hypot(dx,dy)>7)_moved=YES;
        if(_touchTarget==_dot&&_moved){_dot.center=CGPointMake(_dotStart.x+dx,_dotStart.y+dy);[self setNeedsLayout];}
    }
    if(phase==UITouchPhaseEnded||phase==UITouchPhaseCancelled){
        UIView *target=_touchTarget;
        if(phase==UITouchPhaseEnded&&!_moved&&[target isKindOfClass:UIButton.class]&&CGRectContainsPoint(target.bounds,[self convertPoint:p toView:target]))[(UIButton *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
        _touchIdentity=-1;_touchTarget=nil;
    }return YES;
}
@end
