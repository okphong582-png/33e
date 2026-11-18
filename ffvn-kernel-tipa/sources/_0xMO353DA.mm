#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPStyle.h"
#import <objc/runtime.h>
#import "UIView+SecureView.h"
#import "MizzeTheme.h"
#import "MizzeLogo.h"
#include "MizzeMenuLayout.h"
#import "MizzeMenuPrefs.h"
#include <cmath>
#include "../esp/Core/PlayerModes.h"

// Keep preference/event routing intact; render a compact silver switch.
@interface MizzeCheckBox : UIButton
@property(nonatomic,assign) BOOL on;
@property(nonatomic,strong) CAShapeLayer *trackLayer;
@property(nonatomic,strong) CAShapeLayer *thumbLayer;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
@implementation MizzeCheckBox
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.trackLayer=[CAShapeLayer layer];self.thumbLayer=[CAShapeLayer layer];
        [self.layer addSublayer:self.trackLayer];[self.layer addSublayer:self.thumbLayer];
        self.accessibilityTraits=UIAccessibilityTraitButton;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    const CGFloat x=(self.bounds.size.width-36)*.5,y=(self.bounds.size.height-20)*.5;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    self.trackLayer.path=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x,y,36,20) cornerRadius:10].CGPath;
    self.trackLayer.fillColor=(self.on ? [MizzeMint() colorWithAlphaComponent:.75] : MizzeBorder()).CGColor;
    self.thumbLayer.path=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x+(self.on?19:3),y+3,14,14)].CGPath;
    self.thumbLayer.fillColor=(self.on && !ESPDarkTheme() ? MizzeSurface() : UIColor.whiteColor).CGColor;
    [CATransaction commit];
}
- (void)setOn:(BOOL)on {
    _on=on;self.selected=on;[self setNeedsLayout];
    self.accessibilityValue=on ? @"Bật" : @"Tắt";
    self.accessibilityTraits=UIAccessibilityTraitButton | (on ? UIAccessibilityTraitSelected : 0);
}
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    CGPathRef oldPath=self.thumbLayer.presentationLayer ? ((CAShapeLayer *)self.thumbLayer.presentationLayer).path : self.thumbLayer.path;
    id previous=oldPath ? (__bridge id)oldPath : nil;
    self.on=on;[self layoutIfNeeded];
    if (animated && previous && !UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *move=[CABasicAnimation animationWithKeyPath:@"path"];
        move.fromValue=previous;move.toValue=(__bridge id)self.thumbLayer.path;move.duration=.16;
        [self.thumbLayer addAnimation:move forKey:@"switch"];
    }
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted];self.alpha=highlighted?.65:1; }
@end

@interface _0xDEADBEEE () <UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIView *panel,*header,*sidebar;
@property(nonatomic,strong) UIVisualEffectView *glass;
@property(nonatomic,strong) CAGradientLayer *sheen;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) NSArray<UIButton *> *navButtons;
@property(nonatomic,strong) NSMutableArray<UIControl *> *controls;
@property(nonatomic,strong) UIControl *activeControl;
@property(nonatomic,assign) NSInteger page,pointer;
@property(nonatomic,assign) BOOL placedPanel,dragging,scrolling;
@property(nonatomic,assign) CGFloat builtWidth,scrollOrigin;
@property(nonatomic,assign) CGPoint began,panelOrigin;
@end
@implementation _0xDEADBEEE
- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size {
    UILabel *v=[[UILabel alloc] initWithFrame:frame];v.text=text;v.textColor=MizzeText();
    v.font=MizzeFont(size,UIFontWeightMedium);v.adjustsFontSizeToFitWidth=YES;v.minimumScaleFactor=.75;return v;
}
- (void)viewDidLoad {
    [super viewDidLoad];MizzePrepareMenuPrefs();MizzePrepareCompactPrefs();
    self.view.backgroundColor=UIColor.clearColor;self.controls=[NSMutableArray array];self.page=1;self.pointer=-1;
    self.panel=[UIView new];self.panel.backgroundColor=UIColor.clearColor;
    self.panel.layer.cornerRadius=22;self.panel.layer.borderWidth=.75;self.panel.layer.borderColor=MizzeBorder().CGColor;
    self.panel.layer.shadowColor=[UIColor colorWithRed:.08 green:.15 blue:.25 alpha:1].CGColor;
    self.panel.layer.shadowOpacity=.20;self.panel.layer.shadowRadius=20;self.panel.layer.shadowOffset=CGSizeMake(0,8);
    [self.view addSubview:self.panel];
    self.glass=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
    self.glass.userInteractionEnabled=NO;self.glass.layer.cornerRadius=22;self.glass.clipsToBounds=YES;
    self.glass.backgroundColor=UIAccessibilityIsReduceTransparencyEnabled()?[UIColor colorWithWhite:.94 alpha:.96]:MizzeBackground();
    [self.panel addSubview:self.glass];
    self.sheen=[CAGradientLayer layer];self.sheen.colors=@[(id)[UIColor colorWithWhite:1 alpha:.27].CGColor,(id)[UIColor colorWithWhite:1 alpha:.02].CGColor];
    self.sheen.startPoint=CGPointMake(0,0);self.sheen.endPoint=CGPointMake(1,1);
    [self.glass.contentView.layer addSublayer:self.sheen];
    self.sidebar=[UIView new];self.sidebar.backgroundColor=[UIColor colorWithWhite:1 alpha:.13];
    self.sidebar.layer.cornerRadius=16;[self.panel addSubview:self.sidebar];
    UIImageView *logo=[[UIImageView alloc] initWithImage:MizzeLogoImage()];logo.tag=13;
    logo.contentMode=UIViewContentModeScaleAspectFit;logo.layer.cornerRadius=14;logo.clipsToBounds=YES;[self.sidebar addSubview:logo];
    self.header=[UIView new];[self.panel addSubview:self.header];
    UILabel *title=[self label:@"MIZZE" frame:CGRectZero size:12];title.tag=10;title.font=MizzeFont(12,UIFontWeightBold);[self.header addSubview:title];
    UIButton *close=[UIButton buttonWithType:UIButtonTypeSystem];close.tag=12;close.tintColor=MizzeText();
    close.accessibilityLabel=@"Thu gọn menu";[close setImage:[UIImage systemImageNamed:@"minus"] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];[self.header addSubview:close];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHeader:)];pan.delegate=self;[self.header addGestureRecognizer:pan];
    NSMutableArray *nav=[NSMutableArray array];NSArray *names=@[@"ESP",@"AIM"],*icons=@[@"person.crop.rectangle",@"scope"];
    for(NSUInteger i=0;i<2;++i){
        UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=200+(i==0?1:0);b.accessibilityLabel=names[i];b.layer.cornerRadius=12;
        UIImageView *icon=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icons[i]]];icon.tag=21;icon.contentMode=UIViewContentModeScaleAspectFit;
        UILabel *name=[self label:names[i] frame:CGRectZero size:8];name.tag=22;name.textAlignment=NSTextAlignmentCenter;
        [b addSubview:icon];[b addSubview:name];[b addTarget:self action:@selector(changePage:) forControlEvents:UIControlEventTouchUpInside];
        [self.sidebar addSubview:b];[nav addObject:b];
    }
    self.navButtons=nav;self.scroll=[UIScrollView new];self.scroll.bounces=NO;self.scroll.showsVerticalScrollIndicator=NO;[self.panel addSubview:self.scroll];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];CGRect area=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    const auto m=MizzeMenuLayout::Measure(area.size.width,area.size.height);CGRect f=self.panel.frame;f.size=CGSizeMake(m.width,m.height);
    if(!self.placedPanel){f.origin=CGPointMake(CGRectGetMidX(area)-m.width*.5,CGRectGetMidY(area)-m.height*.5);self.placedPanel=YES;}
    f.origin.x=MAX(area.origin.x+8,MIN(f.origin.x,CGRectGetMaxX(area)-m.width-8));
    f.origin.y=MAX(area.origin.y+8,MIN(f.origin.y,CGRectGetMaxY(area)-m.height-8));self.panel.frame=f;
    self.glass.frame=self.panel.bounds;self.sheen.frame=self.glass.bounds;
    self.sidebar.frame=CGRectMake(6,6,m.sidebar-4,m.height-12);[self.sidebar viewWithTag:13].frame=CGRectMake(7,10,30,30);
    self.header.frame=CGRectMake(m.sidebar+12,0,m.contentWidth,m.header);
    [self.header viewWithTag:10].frame=CGRectMake(0,0,m.contentWidth-44,m.header);
    [self.header viewWithTag:12].frame=CGRectMake(m.contentWidth-36,0,36,44);
    for(NSUInteger i=0;i<2;++i){UIButton *b=self.navButtons[i];b.frame=CGRectMake(2,62+i*58,40,50);
        [b viewWithTag:21].frame=CGRectMake(11,7,18,18);[b viewWithTag:22].frame=CGRectMake(0,29,40,12);}
    self.scroll.frame=CGRectMake(m.sidebar+12,m.header,m.contentWidth,MAX(1,m.height-m.header-12));
    if(fabs(self.builtWidth-self.scroll.bounds.size.width)>.5)[self buildPage];
}
- (void)closeMenu {if(self.onCloseBlock)self.onCloseBlock();}
- (void)changePage:(UIButton *)sender {self.page=sender.tag-200;self.scroll.contentOffset=CGPointZero;[self buildPage];}
- (CGFloat)contentWidth {return MAX(1,self.scroll.bounds.size.width);}
- (CGFloat)toggle:(NSString *)title key:(NSString *)key fallback:(BOOL)fallback y:(CGFloat)y {
    CGFloat width=[self contentWidth];UIView *row=[[UIView alloc] initWithFrame:CGRectMake(0,y,width,40)];
    row.backgroundColor=MizzeRaised();row.layer.cornerRadius=11;row.layer.borderColor=[UIColor colorWithWhite:1 alpha:.22].CGColor;row.layer.borderWidth=.5;
    UILabel *label=[self label:title frame:CGRectMake(10,0,width-64,40) size:12];[row addSubview:label];
    MizzeCheckBox *box=[[MizzeCheckBox alloc] initWithFrame:CGRectMake(width-52,-2,48,44)];box.accessibilityLabel=title;
    box.on=[key isEqualToString:@"AimEnabled"]?MizzeAimEnabled():ESPPrefsBool(key,fallback);
    objc_setAssociatedObject(box,"key",key,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [box addTarget:self action:@selector(checkboxPressed:) forControlEvents:UIControlEventTouchUpInside];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleRow:)];tap.delegate=self;
    objc_setAssociatedObject(tap,"switch",box,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[row addGestureRecognizer:tap];
    [row addSubview:box];[self.controls addObject:box];[self.scroll addSubview:row];return y+46;
}
- (CGFloat)toggleGrid:(NSArray *)rows y:(CGFloat)y {
    const CGFloat width=[self contentWidth],gap=6;const NSUInteger cols=width>=230?2:1;const CGFloat cell=(width-gap*(cols-1))/cols;
    for(NSUInteger i=0;i<rows.count;++i){NSArray *r=rows[i];[self toggle:r[0] key:r[1] fallback:[r[2] boolValue] y:y];
        MizzeCheckBox *box=(MizzeCheckBox *)self.controls.lastObject;box.superview.frame=CGRectMake((i%cols)*(cell+gap),y+(i/cols)*46,cell,40);
        box.frame=CGRectMake(cell-48,-2,48,44);box.superview.subviews.firstObject.frame=CGRectMake(9,0,MAX(10,cell-56),40);
    }return y+((rows.count+cols-1)/cols)*46;
}
- (void)toggleRow:(UITapGestureRecognizer *)tap {[(UIControl *)objc_getAssociatedObject(tap,"switch") sendActionsForControlEvents:UIControlEventTouchUpInside];}
- (void)checkboxPressed:(MizzeCheckBox *)box {
    [box setOn:!box.on animated:YES];NSString *key=objc_getAssociatedObject(box,"key");
    if([key isEqualToString:@"AimEnabled"])MizzeSetAimEnabled(box.on);else ESPPrefsSetBool(key,box.on);
    ESPClearAimLock();ESPSyncFromPrefs();
}
- (void)aimModeChanged:(UISegmentedControl *)seg {
    const BOOL enabled=MizzeAimEnabled();ESPPrefsSetFloat(@"AimType",seg.selectedSegmentIndex);MizzeSetAimEnabled(enabled);
    ESPClearAimLock();ESPSyncFromPrefs();[self buildPage];
}
- (CGFloat)slider:(NSString *)title key:(NSString *)key min:(float)minimum max:(float)maximum fallback:(float)value y:(CGFloat)y {
    UILabel *label=[self label:@"" frame:CGRectMake(2,y,[self contentWidth]-4,20) size:11];
    UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(0,y+21,[self contentWidth],38)];slider.minimumValue=minimum;slider.maximumValue=maximum;
    slider.value=ESPPrefsFloat(key,value);slider.minimumTrackTintColor=MizzeMint();slider.maximumTrackTintColor=[UIColor colorWithWhite:1 alpha:.5];
    objc_setAssociatedObject(slider,"key",key,OBJC_ASSOCIATION_COPY_NONATOMIC);objc_setAssociatedObject(slider,"title",title,OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(slider,"label",label,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    label.text=[NSString stringWithFormat:@"%@   %.0f%%",title,slider.value];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:label];[self.scroll addSubview:slider];[self.controls addObject:slider];return y+66;
}
- (void)sliderChanged:(UISlider *)slider {
    NSString *key=objc_getAssociatedObject(slider,"key");ESPPrefsSetFloat(key,slider.value);ESPSyncFromPrefs();
    ((UILabel *)objc_getAssociatedObject(slider,"label")).text=[NSString stringWithFormat:@"%@   %.0f%%",objc_getAssociatedObject(slider,"title"),slider.value];
}
- (void)buildPage {
    CGFloat offset=self.scroll.contentOffset.y;for(UIView *v in self.scroll.subviews)[v removeFromSuperview];[self.controls removeAllObjects];self.builtWidth=[self contentWidth];
    ((UILabel *)[self.header viewWithTag:10]).text=self.page==1?@"MIZZE  /  ESP":@"MIZZE  /  SILENT";
    for(UIButton *b in self.navButtons){BOOL active=b.tag-200==self.page;b.backgroundColor=active?[UIColor colorWithWhite:1 alpha:.34]:UIColor.clearColor;
        [b viewWithTag:21].tintColor=active?MizzeMint():MizzeMuted();((UILabel *)[b viewWithTag:22]).textColor=active?MizzeMint():MizzeMuted();}
    CGFloat y=2;
    if(self.page==1){
        y=[self toggle:@"Bật ESP" key:@"ESPEnabled" fallback:YES y:y];
        y=[self toggleGrid:@[@[@"Khung",@"Box",@YES],@[@"Xương",@"Skeleton",@YES],@[@"Line",@"Line",@YES],@[@"Tên",@"Name",@YES],
            @[@"Khoảng cách",@"Dis",@YES],@[@"Máu",@"Health",@YES],@[@"Đếm địch",@"EnemyCount",@YES],@[@"FOV",@"ShowFov",@YES]] y:y];
    }else{
        y=[self toggle:@"Silent Aim" key:@"AimEnabled" fallback:NO y:y];
        y=[self slider:@"FOV" key:@"SilentFovSize" min:5 max:48 fallback:18 y:y+6];
        y=[self slider:@"Tỷ lệ đầu" key:@"SilentHeadPercent" min:0 max:100 fallback:75 y:y];
        y=[self toggle:@"Vòng FOV" key:@"ShowFov" fallback:YES y:y];
    }
    self.scroll.contentSize=CGSizeMake([self contentWidth],y+2);self.scroll.contentOffset=CGPointMake(0,MAX(0,MIN(offset,y+2-self.scroll.bounds.size.height)));
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for(UIView *v=touch.view;v&&v!=gesture.view;v=v.superview)if([v isKindOfClass:UIControl.class])return NO;return YES;
}
- (void)dragHeader:(UIPanGestureRecognizer *)pan {
    if(pan.state==UIGestureRecognizerStateBegan)self.panelOrigin=self.panel.frame.origin;CGPoint d=[pan translationInView:self.view];
    CGRect f=self.panel.frame;f.origin=CGPointMake(self.panelOrigin.x+d.x,self.panelOrigin.y+d.y);self.panel.frame=f;[self viewDidLayoutSubviews];
}
- (void)setSlider:(UISlider *)slider point:(CGPoint)point {
    CGPoint p=[slider convertPoint:point fromView:self.view];CGFloat r=MAX(0,MIN(1,(p.x-14)/MAX(1,slider.bounds.size.width-28)));
    slider.value=slider.minimumValue+r*(slider.maximumValue-slider.minimumValue);[self sliderChanged:slider];
}
- (void)fovSliderTouchUp:(UISlider *)slider {}

- (BOOL)_0xF010:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    if (phase == UITouchPhaseBegan) {
        if (!CGRectContainsPoint(self.panel.frame, point)) return NO;
        if (self.pointer != -1) return YES;
        self.pointer = pointerId; self.began = point; self.panelOrigin = self.panel.frame.origin;
        self.scrollOrigin = self.scroll.contentOffset.y; self.scrolling = NO; self.activeControl = nil;
        CGPoint local = [self.panel convertPoint:point fromView:self.view];
        CGPoint headerPoint=[self.header convertPoint:point fromView:self.view];
        self.dragging=CGRectContainsPoint(self.header.bounds,headerPoint) && headerPoint.x<self.header.bounds.size.width-84;
        if (self.dragging) return YES;
        NSMutableArray *fixed = [NSMutableArray array];
        [fixed addObjectsFromArray:self.navButtons];
        UIView *closeBtn = [self.header viewWithTag:12];
        if ([closeBtn isKindOfClass:[UIControl class]]) [fixed addObject:closeBtn];
        UIView *hideBtn=[self.header viewWithTag:14];
        if ([hideBtn isKindOfClass:UIControl.class]) [fixed addObject:hideBtn];
        for (UIControl *c in fixed) if (CGRectContainsPoint(c.bounds, [c convertPoint:point fromView:self.view])) self.activeControl = c;
        if (CGRectContainsPoint(self.scroll.bounds, [self.scroll convertPoint:point fromView:self.view])) {
            for (UIControl *c in self.controls) {
                if (!c.enabled) continue;
                CGRect hit = c.bounds;
                if ([c isKindOfClass:MizzeCheckBox.class]) hit = [c convertRect:c.superview.bounds fromView:c.superview];
                if (CGRectContainsPoint(hit, [c convertPoint:point fromView:self.view])) { self.activeControl = c; break; }
            }
        }
        if ([self.activeControl isKindOfClass:UIButton.class]) ((UIButton *)self.activeControl).highlighted=YES;
        if ([self.activeControl isKindOfClass:UISlider.class]) [self setSlider:(UISlider *)self.activeControl point:point];
        return YES;
    }
    if (self.pointer != pointerId) return NO;
    CGFloat dx = point.x - self.began.x, dy = point.y - self.began.y;
    if (phase == UITouchPhaseMoved) {
        if (self.dragging) {
            CGRect f = self.panel.frame; f.origin = CGPointMake(self.panelOrigin.x + dx, self.panelOrigin.y + dy); self.panel.frame = f;
            [self viewDidLayoutSubviews];
        } else if ([self.activeControl isKindOfClass:UISlider.class]) {
            [self setSlider:(UISlider *)self.activeControl point:point];
        } else if (fabs(dy) > 7 || self.scrolling) {
            self.scrolling = YES;
            if ([self.activeControl isKindOfClass:UIButton.class]) ((UIButton *)self.activeControl).highlighted=NO;
            CGFloat maxY = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
            self.scroll.contentOffset = CGPointMake(0, MAX(0, MIN(maxY, self.scrollOrigin - dy)));
        }
        return YES;
    }
    if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        UIControl *control = self.activeControl;
        BOOL activate = phase == UITouchPhaseEnded && !self.dragging && !self.scrolling && fabs(dx) < 24 && fabs(dy) < 24;
        self.pointer = -1; self.activeControl = nil;
        if (activate && !control.enabled) activate = NO;
        if ([control isKindOfClass:UIButton.class]) ((UIButton *)control).highlighted=NO;
        if (activate && [control isKindOfClass:UISegmentedControl.class]) {
            UISegmentedControl *seg = (UISegmentedControl *)control;
            CGPoint p = [seg convertPoint:point fromView:self.view];
            seg.selectedSegmentIndex = MAX(0, MIN(seg.numberOfSegments - 1, (NSInteger)(p.x / (seg.bounds.size.width / seg.numberOfSegments))));
            [seg sendActionsForControlEvents:UIControlEventValueChanged];
        } else if (activate && [control isKindOfClass:UIButton.class]) {
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else if (activate && [control isKindOfClass:UITextField.class]) {
            [control becomeFirstResponder];
        }
        if ([control isKindOfClass:UISlider.class]) [self fovSliderTouchUp:(UISlider *)control];
        return YES;
    }
    return YES;
}
@end
