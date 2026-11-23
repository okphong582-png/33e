#import "MZAnimatedMenuIcon.h"
#import "MZMenuAnimationData.h"
#import <QuartzCore/QuartzCore.h>

@interface MZAnimatedMenuIcon ()
@property (nonatomic, strong) MZMenuAnimationData *animationData;
@property (nonatomic) BOOL suspended;
@end

@implementation MZAnimatedMenuIcon
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.blackColor;
    self.clipsToBounds = YES;
    self.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.layer.contentsScale = UIScreen.mainScreen.scale;
    self.layer.contents = (__bridge id)[UIImage imageNamed:@"logo.png"].CGImage;
    _playing = YES;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(suspendAnimation:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(resumeAnimation:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(refreshAnimation) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    static dispatch_queue_t decodeQueue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ decodeQueue = dispatch_queue_create("vn.mizze.menu.gif.decode", DISPATCH_QUEUE_SERIAL); });
    NSURL *url = [NSBundle.mainBundle URLForResource:@"Mizze-Antiban-Eye-Slow" withExtension:@"gif"];
    __weak MZAnimatedMenuIcon *weakSelf = self;
    dispatch_async(decodeQueue, ^{
        static MZMenuAnimationData *cached;
        static BOOL loaded = NO;
        if (!loaded) { cached = [MZMenuAnimationData decodeURL:url]; loaded = YES; }
        MZMenuAnimationData *data = cached;
        dispatch_async(dispatch_get_main_queue(), ^{
            MZAnimatedMenuIcon *view = weakSelf;
            if (!view || !data) return; // Static logo remains usable if decoding fails.
            view.animationData = data;
            view.layer.contents = data.frames.firstObject;
            // Present the supplied disc inside a circular button; the GIF itself
            // remains byte-for-byte unchanged (its square corners are magenta).
            view.layer.contentsRect = CGRectMake(0.035, 0.035, 0.93, 0.93);
            [view refreshAnimation];
        });
    });
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2;
}
- (void)didMoveToWindow { [super didMoveToWindow]; [self refreshAnimation]; }
- (void)setPlaying:(BOOL)playing {
    if (_playing == playing) return;
    _playing = playing;
    [self refreshAnimation];
}
- (void)suspendAnimation:(NSNotification *)note { self.suspended = YES; [self refreshAnimation]; }
- (void)resumeAnimation:(NSNotification *)note { self.suspended = NO; [self refreshAnimation]; }
- (void)refreshAnimation {
    BOOL animate = self.window && self.playing && !self.suspended &&
                   !UIAccessibilityIsReduceMotionEnabled() && self.animationData;
    if (!animate) { [self.layer removeAnimationForKey:@"mizze.menu.gif"]; return; }
    if ([self.layer animationForKey:@"mizze.menu.gif"]) return;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.values = self.animationData.frames;
    animation.keyTimes = self.animationData.keyTimes;
    animation.duration = self.animationData.duration;
    animation.calculationMode = kCAAnimationDiscrete;
    animation.repeatCount = HUGE_VALF;
    [self.layer addAnimation:animation forKey:@"mizze.menu.gif"];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
