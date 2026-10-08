#import "Overlay.h"
#include "../core/Process.h"
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
@interface AOVOverlay () {
    AOVDrawing *_drawing;
    UIView *_panel;
    UIButton *_dot,*_enemy,*_monster,*_close;
    UILabel *_status;
    NSTimer *_timer;
    dispatch_queue_t _queue;
    std::shared_ptr<aov::Process> _reader;
    BOOL _busy,_enemies,_monsters;
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
        NSUserDefaults *d=NSUserDefaults.standardUserDefaults;_enemies=[d boolForKey:@"AOV.Enemies"];
        if(![d objectForKey:@"AOV.Monsters"])[d setBool:[d boolForKey:@"AOV.BlueBuff"] forKey:@"AOV.Monsters"];
        _monsters=[d boolForKey:@"AOV.Monsters"];
        _drawing=[[AOVDrawing alloc] initWithFrame:self.bounds];_drawing.autoresizingMask=self.autoresizingMask;[self addSubview:_drawing];
        _dot=[self button:@"A" action:@selector(toggleMenu)];_dot.titleLabel.font=Font(20,UIFontWeightBold);_dot.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter;_dot.contentEdgeInsets=UIEdgeInsetsZero;
        _dot.frame=CGRectMake(22,80,48,48);_dot.layer.cornerRadius=24;[_dot setTitleColor:Mint() forState:UIControlStateNormal];_dot.layer.borderColor=Mint().CGColor;
        [_dot addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDot:)]];[self addSubview:_dot];
        _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithWhite:.065 alpha:.97];_panel.layer.cornerRadius=20;_panel.layer.borderWidth=1;_panel.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;_panel.hidden=YES;[self addSubview:_panel];
        UILabel *title=[UILabel new];title.text=@"AOV";title.font=Font(23,UIFontWeightBold);title.textColor=Mint();title.frame=CGRectMake(18,16,180,30);[_panel addSubview:title];
        UILabel *credit=[UILabel new];credit.text=@"HoangHaDev";credit.textColor=[UIColor colorWithWhite:.6 alpha:1];credit.font=Font(11,UIFontWeightMedium);credit.frame=CGRectMake(18,48,190,16);[_panel addSubview:credit];
        _close=[self button:@"×" action:@selector(toggleMenu)];_close.frame=CGRectMake(220,16,42,42);_close.titleLabel.font=Font(23,UIFontWeightMedium);[_panel addSubview:_close];
        _enemy=[self button:@"" action:@selector(toggleEnemy)];_enemy.frame=CGRectMake(16,80,248,52);[_panel addSubview:_enemy];
        _monster=[self button:@"" action:@selector(toggleMonsters)];_monster.frame=CGRectMake(16,142,248,52);[_panel addSubview:_monster];
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
    [_monster setTitle:_monsters?@"[ X ]   ESP quái":@"[   ]   ESP quái" forState:UIControlStateNormal];
    for(UIButton *b in @[_enemy,_monster]){BOOL on=b==_enemy?_enemies:_monsters;[b setTitleColor:on?Mint():UIColor.whiteColor forState:UIControlStateNormal];b.layer.borderColor=(on?Mint():[UIColor colorWithWhite:.25 alpha:1]).CGColor;}
}
- (void)toggleEnemy{_enemies=!_enemies;[NSUserDefaults.standardUserDefaults setBool:_enemies forKey:@"AOV.Enemies"];[self updateButtons];}
- (void)toggleMonsters{_monsters=!_monsters;[NSUserDefaults.standardUserDefaults setBool:_monsters forKey:@"AOV.Monsters"];[self updateButtons];}
- (void)tick{
    if(!self.window||self.hidden||_busy)return;
    if(!_enemies&&!_monsters){_drawing->snapshot={};[_drawing setNeedsDisplay];_status.text=@"Chọn ESP để bật";return;}
    _busy=YES;BOOL enemy=_enemies,monster=_monsters;auto reader=_reader;__weak AOVOverlay *weak=self;
    dispatch_async(_queue,^{
        auto sample=reader->update(enemy,monster);
        dispatch_async(dispatch_get_main_queue(),^{AOVOverlay *s=weak;if(!s)return;s->_busy=NO;
            if(enemy!=s->_enemies||monster!=s->_monsters)return;
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
