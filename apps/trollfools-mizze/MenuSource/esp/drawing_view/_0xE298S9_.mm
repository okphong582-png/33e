
#include "../Core/AimSelection.h"
#include "../../sources/MizzeMenuPrefs.h"
#include "../Core/SilentAimSelection.h"
#include "../Core/AutoFire.h"
#include "../Core/GhostMode.h"
#include "../Core/PlayerModes.h"
#include "../Core/PlayerModesControlPolicy.h"
#include "../Core/GamePRI.h"
#include "../Core/AimPoint.h"
#include "../Core/SilentAim.h"
#include "../Core/SilentAimDirection.h"
#include "../Core/SilentAimPolicy.h"

#import "esp.h"
#import "ESPPrefs.h"
#import "ESPStyle.h"
#ifndef MIZZE_INJECTED
#import "HUDHelper.h"
#endif
#import "../drawing_view/offset.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <string>
#include <vector>
#include <cmath>
#include <algorithm>
#include <array>
#include <cstring>
#include "KabraxHide.h"
#include <float.h>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <map>



uint64_t Moudule_Base = -1;
static BOOL gMatchReady = NO;
NSNotificationName const ESPMatchReadyChangedNotification = @"ESPMatchReadyChanged";
BOOL ESPMatchReady(void) { return gMatchReady; }
static void SetMatchReady(BOOL ready) {
    if (gMatchReady == ready) return;
    gMatchReady = ready;
    [NSNotificationCenter.defaultCenter postNotificationName:ESPMatchReadyChangedNotification object:nil];
}
float percent = 0.0f;

// ============================================================
// ✅ BIẾN ESP (GIỮ LẠI)
// ============================================================
bool isBox        = YES;
bool isBone       = NO;
bool isCount      = NO;
bool isHealth     = YES;
bool isName       = YES;
bool isDis        = YES;
bool isLine       = NO;
bool isXYZAxes    = NO;
bool isHeadRedDot = NO;
bool isBox3D = NO;
bool isCleanESP = YES;
static bool showFov    = YES;
static float fovPercent = 40.0f;
static float silentFovPercent = 18.0f;
static float silentMaxDistance = 100.0f;
static bool silentAutoConfig = true;
static uint32_t silentHeadPercent = 75;
static float activeSilentFov = 18;
static AimModePolicy::Type gAimType = AimModePolicy::Type::Head;
static AimModePolicy::Activation gAimActivation = AimModePolicy::Activation::Off;
static bool isAimNeck    = NO;
static bool isSilentAim  = NO;
static bool gAutoFire = false;
static bool gAutoSwap = false, gTargetLine = true, gRunSpeed = false;
static float gRunSpeedValue = 6;
static bool gGhostMode = false;
static int gGhostInstall = 1;
static int gPlayerModesInstall = 1;
static GhostModeSnapshot gGhostSnapshot;
static CFTimeInterval gNextGhostRead = 0;
static uint64_t gAimLockTarget  = 0;
static uint64_t gAimLocalPlayer = 0;
static Vector3  gAimLockedHead  = {};
static Quaternion gAimSmoothed      = {0,0,0,1};
static bool       gAimSmoothedValid = false;
static float      gAimSpeed         = 180.0f;
static float      gESPMaxDistance   = 150.0f; // khoảng cách tối đa hiển thị ESP (mét)


static bool gESPPrefsLoadedOnce = false;
static NSUInteger gRenderPrefsRevision = 0;
static bool gBalancedRender = false;
static bool gNoReload = false;
static bool gFastFire = false;

// ============================================================
// ✅ SYNC PREFS - ESP & AIMBOT
// ============================================================
void ESPSyncFromPrefs(void) {
    MizzePrepareMenuPrefs();
    const bool espEnabled = ESPPrefsBool(@"ESPEnabled", YES);
    isBox        = espEnabled && ESPPrefsBool(KH_NS("Box"),        YES);
    isBone       = espEnabled && ESPPrefsBool(@"Skeleton", NO);
    isHealth     = espEnabled && ESPPrefsBool(KH_NS("Health"),     YES);
    isName       = espEnabled && ESPPrefsBool(KH_NS("Name"),       YES);
    isDis        = espEnabled && ESPPrefsBool(KH_NS("Dis"),        YES);
    isLine       = espEnabled && ESPPrefsBool(KH_NS("Line"), YES);
    isXYZAxes = espEnabled && ESPPrefsBool(@"XYZAxes", NO);
    isHeadRedDot = espEnabled && ESPPrefsBool(KH_NS("HeadRedDot"), NO);
    isBox3D = ESPPrefsBool(@"Box3D", NO);
    isCleanESP = !isBox3D && ESPPrefsBool(@"CleanESP", YES);
    const auto type = AimModePolicy::ReadType(ESPPrefsFloat(@"AimType", 0));
    const auto activation = AimModePolicy::ReadActivation(ESPPrefsFloat(@"AimActivation", 0));
    if (type != gAimType || activation != gAimActivation) ESPClearAimLock();
    gAimType = type;
    gAimActivation = activation;
    const bool autoFire = ESPPrefsBool(@"AutoFire", NO);
    if (gAutoFire && !autoFire) AutoFireClear();
    gAutoFire = autoFire;
    isAimNeck = !gAutoFire && type == AimModePolicy::Type::Neck;
    const bool silentEnabled = gAutoFire || (type == AimModePolicy::Type::Silent && ESPPrefsBool(@"SilentAim", NO));
    if (silentEnabled != isSilentAim) {
        gAimLockTarget = 0;
        gAimSmoothedValid = false;
        SilentAimSetEnabled(silentEnabled);
    }
    isSilentAim = silentEnabled;
    gAutoSwap = false;
    gTargetLine = ESPPrefsBool(@"AimTargetLine", YES);
    gRunSpeed = ESPPrefsBool(@"RunSpeed", NO);
    gRunSpeedValue = ESPPrefsFloat(@"RunSpeedValue", 6);
    if(!gRunSpeed) UpdateRunSpeed(Moudule_Base,false,gRunSpeedValue);
    gGhostMode = ESPPrefsBool(@"GhostMode", NO);
    GhostModeSetEnabled(gGhostMode);
    if (!ESPPrefsBool(@"FlyHeightRaisedV1", NO)) {
        ESPPrefsSetFloat(@"FlyHeight", PlayerModesControl::Height(ESPPrefsFloat(@"FlyHeight", 3.0f) + 1.0f));
        ESPPrefsSetBool(@"FlyHeightRaisedV1", YES);
    }
    PlayerModesSetEnabled(ESPPrefsBool(@"Fly", NO), ESPPrefsBool(@"AimLag", NO),
        ESPPrefsBool(@"FakeLag", NO), ESPPrefsFloat(@"FlyHeight", PlayerModesControl::DefaultHeight));
    PlayerModesSetSpin(ESPPrefsBool(@"VisualSpin", NO), ESPPrefsFloat(@"VisualSpinSpeed",0.5f));
    showFov       = ESPPrefsBool(@"ShowFov", YES);
    fovPercent    = ESPPrefsFloat(@"FovSize", 40);
    gBalancedRender = ESPPrefsBool(@"BalancedRender", NO);
    silentFovPercent = ESPPrefsFloat(@"SilentFovSize", 18);
    silentAutoConfig = ESPPrefsBool(@"SilentAutoConfig", YES);
    silentHeadPercent = SilentAimPolicy::HeadPercent(ESPPrefsFloat(@"SilentHeadPercent", 75));
    activeSilentFov = SilentAimPolicy::Resolve(false, silentAutoConfig, silentFovPercent, silentMaxDistance).fov;
    silentMaxDistance = ESPPrefsFloat(@"SilentMaxDistance", 100);
    if (!std::isfinite(silentMaxDistance)) silentMaxDistance = 100;
    silentMaxDistance = std::max(10.0f, std::min(150.0f, silentMaxDistance));
    gNoReload = gAutoFire || ESPPrefsBool(@"ShootNoReload", NO);
    // AimKill must use ordinary weapon timing even if manual fast fire is saved.
    gFastFire = !gAutoFire && ESPPrefsBool(@"FastFire", NO);
    SyncWeaponFeatureSwitches(Moudule_Base, gNoReload, gFastFire, gAutoFire);
    gAimSpeed       = ESPPrefsFloat(@"AimSpeed", 180.0f);
    gESPMaxDistance = ESPPrefsFloat(@"ESPMaxDistance", 150.0f);
    if (!std::isfinite(gESPMaxDistance)) gESPMaxDistance = 150;
    if (gESPMaxDistance < 30.0f)  gESPMaxDistance = 30.0f;
    if (gESPMaxDistance > 500.0f) gESPMaxDistance = 500.0f;
    gESPPrefsLoadedOnce = true;
    ++gRenderPrefsRevision;

    // ESP Count logic
    if (isLine || isXYZAxes || isBox || isHealth || isBone) {
        isCount = YES;
    } else {
        isCount = NO;
    }
}

// Nhả aim lock → frame kế tiếp chọn lại target trong FOV mới
void ESPClearAimLock(void) {
    gAimLockTarget    = 0;
    gAimSmoothedValid = false;
}



static const NSUInteger kMaxTextLayerPoolSize = 128;

// ============================================================
// STRUCT COW (GIỮ NGUYÊN)
// ============================================================
struct COW_GamePlay_IHAAMHPPLMG_o {
    uint32_t NBPDJAAAFBH;
    uint32_t JEDDPHIHGKL;
    uint8_t  IOICFFEKAIL;
    uint8_t  PHAFNFOFFDB;
    uint64_t BNFAIDHEHOM;
};

COW_GamePlay_IHAAMHPPLMG_o originalPlayerID;
BOOL hasSavedOriginalID = false;

// ─── Frame Cache ──────────────────────────────
static uint64_t cachedMatchGame  = 0;
static uint64_t cachedCamera     = 0;
static uint64_t cachedMatch      = 0;

typedef struct {
    int playerCount;
    int botCount;
    bool inMatch;
    bool firing;
    int  firingRaw;
    bool scoping;
    int aimState;
    int autoFireState;
} ESPFrameStats;

static NSString *AimStateDescription(int state) {
    switch (state) {
        case 1: return @"chờ bắn/ngắm";
        case 2: return @"chưa có mục tiêu trong FOV";
        case 3: return @"không ghi được góc";
        case 4: return @"đã ghi góc";
        case 5: return @"mục tiêu/trạng thái đã đổi";
        case 6: return @"chỉ ghi được góc chính";
        case 7: return @"silent: chờ địch hiện";
        case 8: return @"silent: đã chọn mục tiêu";
        case 9: return @"silent: bản game/vũ khí chưa hỗ trợ";
        case 10: {
            const auto failure = SilentAimLastFailure();
            if (failure.operation && failure.operation[0])
                return [NSString stringWithFormat:@"silent: %s (Mach %d)", failure.operation, failure.code];
            return @"silent: iOS không cho cài xử lý phát bắn";
        }
        default: return @"chờ dữ liệu trận";
    }
}

// ─── Helpers ──────────────────────────────────
static inline float Clamp01f(float v) {
    return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

static inline void ESPReleasePath(CGMutablePathRef p) { if (p) CGPathRelease(p); }

static inline ESPGeometryBuffers ESPGeometryBuffersCreate(void) {
    ESPGeometryBuffers b{};
    if (isBone) b.bonePath = CGPathCreateMutable();
    if (isBox) {
        b.boxBotPath = CGPathCreateMutable();
        b.boxPlayerPath = CGPathCreateMutable();
    }
    if (isBox || isHeadRedDot) b.boxKnockPath = CGPathCreateMutable();
    if (isLine) b.snaplinePath = CGPathCreateMutable();
    if (isXYZAxes) {
        b.axisZPath = CGPathCreateMutable();
        b.axisYPath = CGPathCreateMutable();
        b.axisXPath = CGPathCreateMutable();
    }
    if (isHealth) {
        b.hpBackgroundPath = CGPathCreateMutable();
        b.hpFillPath = CGPathCreateMutable();
        b.hpWarningPath = CGPathCreateMutable();
        b.hpCriticalPath = CGPathCreateMutable();
    }

    b.boxBotDirty = b.boneDirty = b.axisYDirty = NO;
    b.hpBackgroundDirty = b.hpFillDirty          = NO;
    b.aimAssistDirty = b.alertDirty              = NO;
    return b;
}

static inline void ESPGeometryBuffersRelease(ESPGeometryBuffers *b) {
    if (!b) return;
    ESPReleasePath(b->boxBotPath);
    ESPReleasePath(b->axisYPath);
    ESPReleasePath(b->boxPlayerPath);
    ESPReleasePath(b->axisXPath);
    ESPReleasePath(b->boxKnockPath);
    ESPReleasePath(b->axisZPath);

    ESPReleasePath(b->bonePath);
    ESPReleasePath(b->snaplinePath);
    ESPReleasePath(b->hpBackgroundPath);
    ESPReleasePath(b->hpFillPath);
    ESPReleasePath(b->hpWarningPath);
    ESPReleasePath(b->hpCriticalPath);
    ESPReleasePath(b->hpHighlightPath);
    ESPReleasePath(b->aimAssistPath);
    ESPReleasePath(b->alertPath);
}

static inline void ApplyPath(CAShapeLayer *layer, CGMutablePathRef path, bool dirty) {
    if (layer) layer.path = (dirty && path) ? path : nil;
}

// ─── Box ──────────────────────────────────────
static inline void ESPAddBox(CGMutablePathRef path, CGRect rect) {
    if (path) CGPathAddRect(path, NULL, rect);
}

// ─── Snapline ──
static inline void ESPAddSnapline(CGMutablePathRef path, CGPoint start, CGPoint end) {
    if (path) {
        CGPathMoveToPoint(path, NULL, start.x, start.y);
        CGPathAddLineToPoint(path, NULL, end.x, end.y);
    }
}

// ─── Thanh máu ────────────────────────────────
static inline void ESPAddHealthBar(CGMutablePathRef bgPath, CGMutablePathRef fillPath,
                                   CGRect boxRect, float hp) {
    if (!bgPath || !fillPath) return;

    const CGFloat barW = 2.0f;
    const CGFloat gap  = 2.0f;
    const CGFloat bdr  = 0.5f;

    CGFloat x = boxRect.origin.x - gap - barW;
    CGFloat y = boxRect.origin.y;
    CGFloat h = boxRect.size.height;

    CGPathAddRect(bgPath, NULL,
        CGRectMake(x - bdr, y - bdr, barW + bdr * 2.0f, h + bdr * 2.0f));

    CGFloat fillH = h * Clamp01f(hp);
    CGFloat fillY = y + (h - fillH);
    if (fillH > 0.5f)
        CGPathAddRect(fillPath, NULL, CGRectMake(x, fillY, barW, fillH));
}

// ============================================================
// ✅ FOV CIRCLE - GIỮ NGUYÊN HÀM (không gọi nữa)
// ============================================================
static inline BOOL RenderFOVCirclePath(CGMutablePathRef path,
                                        CGFloat vw, CGFloat vh,
                                        BOOL aiming, float fov) {
    if (!aiming || fov <= 0) return NO;
    CGPathAddArc(path, NULL, vw / 2.0f, vh / 2.0f, fov, 0, M_PI * 2, YES);
    return YES;
}

// ─────────────────────────────────────────────
// MARK: - ESP_View Interface
// ─────────────────────────────────────────────
@interface _0xDAB2826 ()
@property (nonatomic, strong) CADisplayLink          *displayLink;
@property (nonatomic, strong) CAShapeLayer           *boxLayer;
@property (nonatomic, strong) CAShapeLayer           *boneLayer;
@property (nonatomic, strong) CAShapeLayer           *snaplineLayer;
@property (nonatomic, strong) CAShapeLayer           *hpBackgroundLayer;
@property (nonatomic, strong) CAShapeLayer           *hpFillLayer;
@property (nonatomic, strong) CAShapeLayer *hpWarningLayer;
@property (nonatomic, strong) CAShapeLayer *hpCriticalLayer;
@property (nonatomic, strong) CAShapeLayer *hpHighlightLayer;
@property (nonatomic, strong) CAShapeLayer           *aimAssistLayer;
@property (nonatomic, strong) CAShapeLayer           *alertLayer;
@property (nonatomic, strong) CAShapeLayer           *fovLayer;
@property (nonatomic, strong) CAShapeLayer *ghostLayer;
@property (nonatomic, strong) NSMutableArray<CATextLayer *> *textLayerPool;
@property (nonatomic, assign) NSUInteger              activeTextLayerCount;

@property (nonatomic, strong) CAShapeLayer *boxBotLayer;
@property (nonatomic, strong) CAShapeLayer *boxPlayerLayer;
@property (nonatomic, strong) CAShapeLayer *axisYLayer;
@property (nonatomic, strong) CAShapeLayer *axisXLayer;
@property (nonatomic, strong) CAShapeLayer *boxKnockLayer;
@property (nonatomic, strong) CAShapeLayer *axisZLayer;
@property (nonatomic, assign) CFTimeInterval nextProcessCheck;
@property (nonatomic, assign) CFTimeInterval nextRenderTime;
@property (nonatomic, assign) NSUInteger appliedRenderRevision;
@property (nonatomic, assign) CGSize lastFovSize;
@property (nonatomic, assign) float lastFovRadius;
@end

// ─────────────────────────────────────────────
// MARK: - ESP_View Implementation
// ─────────────────────────────────────────────
@implementation _0xDAB2826

- (void)showMenu              { }
- (void)hideMenu              { }
- (void)centerMenu            { }
- (void)handlePan:(UIPanGestureRecognizer *)g { }

// ─── FIX TOẠ ĐỘ VÀ SIZE CHỮ ───
static void ESPTextCallback(void *ctx, NSString *str, CGRect frame,
                                UIColor *color, CGFloat fontSize, BOOL leftAligned) {
    if (!ctx || !str) return;
    _0xDAB2826 *view = (__bridge _0xDAB2826 *)ctx;

    CGRect f = CGRectMake(frame.origin.x,
                          frame.origin.y,
                          frame.size.width,
                          frame.size.height);

    CGFloat finalSize = fontSize;

    [view addText:str frame:f
            color:color
         fontSize:finalSize leftAligned:leftAligned];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled = NO;
    self.backgroundColor        = UIColor.clearColor;
    self.clipsToBounds = YES;
    self.textLayerPool          = [NSMutableArray array];

    [self configureRenderingLayers];
#ifdef MIZZE_INJECTED
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:)
                                              name:UIApplicationWillResignActiveNotification object:nil];
#endif
    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    GhostModeCancel(); PlayerModesCancel();
    AutoFireClear(); SilentAimClearTarget();
    [self clearAllContent];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {
        GhostModeCancel(); PlayerModesCancel();
        AutoFireClear(); SilentAimClearTarget();
        [self.displayLink invalidate];
        self.displayLink = nil;
        [self clearAllContent];
        return;
    }
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:KH_SEL("updateFrame")];
        self.appliedRenderRevision = 0;
        self.nextProcessCheck = 0;
        self.nextRenderTime = 0;
        [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
}



- (void)setupModuleBase {
    // Lookup returns zero on failure. Retry while waiting for the game and after
    // a restart; never terminate the floating menu because the game is absent.
    Moudule_Base = (uint64_t)GetGameModule_Base((char *)KH_STR(MIZZE_GAME_PROCESS_NAME));
}

// ─── Layer Factory ────────────────────────────
- (CAShapeLayer *)makeShapeLayer:(UIColor *)stroke fill:(UIColor *)fill
                        lineWidth:(CGFloat)lw zPos:(CGFloat)z {
    CAShapeLayer *l   = [CAShapeLayer layer];
    l.strokeColor     = stroke ? stroke.CGColor : nil;
    l.fillColor       = fill   ? fill.CGColor   : UIColor.clearColor.CGColor;
    l.lineWidth       = lw;
    l.lineJoin        = kCALineJoinRound;
    l.lineCap         = kCALineCapRound;
    l.contentsScale   = UIScreen.mainScreen.scale;
    l.zPosition       = z;
    l.allowsEdgeAntialiasing = YES;
    // No blurred shadows on paths that change every frame: this avoids an
    // offscreen blur pass per layer and keeps small strokes crisp.
    l.shadowOpacity = 0;
    l.actions = @{ KH_NS("path"): NSNull.null };
    return l;
}

- (void)configureRenderingLayers {
    UIColor *white  = [UIColor colorWithRed:0.72 green:0.91 blue:1.0 alpha:0.95];
    UIColor *clear  = UIColor.clearColor;
    UIColor *yellow = [UIColor colorWithRed:0.95 green:0.79 blue:0.48 alpha:0.9];

    UIColor *hpGreen = [UIColor colorWithRed:0.46 green:0.86 blue:0.73 alpha:0.9];
    UIColor *red     = [UIColor colorWithRed:0.9 green:0.55 blue:0.55 alpha:0.8];

    self.axisZLayer  = [self makeShapeLayer:red fill:nil lineWidth:0.5f zPos:1];
    self.boxKnockLayer   = [self makeShapeLayer:red fill:nil lineWidth:0.5f zPos:1];

    self.axisYLayer    = [self makeShapeLayer:yellow fill:nil lineWidth:1.0f zPos:1];
    self.axisXLayer = [self makeShapeLayer:white fill:nil lineWidth:1.0f zPos:1];

    self.boxBotLayer     = [self makeShapeLayer:yellow fill:nil lineWidth:1.0f zPos:3];
    self.boxPlayerLayer  = [self makeShapeLayer:white fill:nil lineWidth:1.0f zPos:3];

    self.fovLayer        = [self makeShapeLayer:[UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f] fill:nil lineWidth:1.5f zPos:7];
    self.ghostLayer = [self makeShapeLayer:[UIColor colorWithRed:0.46 green:0.86 blue:0.73 alpha:0.95]
        fill:nil lineWidth:1.8 zPos:7];
    self.snaplineLayer     = [self makeShapeLayer:white   fill:nil     lineWidth:0.8f zPos:1];
    self.boneLayer         = [self makeShapeLayer:white   fill:nil     lineWidth:1.0f zPos:2];
    self.boxLayer          = [self makeShapeLayer:white   fill:nil     lineWidth:0.5f zPos:3];
    self.hpBackgroundLayer = [self makeShapeLayer:nil     fill:[UIColor colorWithWhite:0.02 alpha:0.9] lineWidth:0 zPos:4];
    self.hpFillLayer       = [self makeShapeLayer:nil     fill:hpGreen lineWidth:0    zPos:5];

    self.hpWarningLayer = [self makeShapeLayer:nil fill:[UIColor colorWithRed:1 green:0.72 blue:0.25 alpha:1] lineWidth:0 zPos:5];
    self.hpCriticalLayer = [self makeShapeLayer:nil fill:[UIColor colorWithRed:1 green:0.27 blue:0.32 alpha:1] lineWidth:0 zPos:5];
    self.hpHighlightLayer = [self makeShapeLayer:nil fill:[UIColor colorWithWhite:1 alpha:0.4] lineWidth:0 zPos:6];

    self.aimAssistLayer = [self makeShapeLayer:[UIColor colorWithRed:0.46 green:0.86 blue:0.73 alpha:0.9] fill:nil lineWidth:1.6 zPos:7];
    for (CAShapeLayer *l in @[self.aimAssistLayer, self.ghostLayer, self.hpWarningLayer, self.hpCriticalLayer, self.hpHighlightLayer, self.fovLayer, self.snaplineLayer, self.boneLayer, self.boxLayer,
                               self.hpBackgroundLayer, self.hpFillLayer,
                            self.boxBotLayer, self.boxPlayerLayer, self.axisYLayer, self.axisXLayer, self.axisZLayer, self.boxKnockLayer]) {
        [self.layer addSublayer:l];
    }

}

- (void)resetTextLayers {
    for (CATextLayer *l in self.textLayerPool) l.hidden = YES;
    self.activeTextLayerCount = 0;
}

- (CATextLayer *)dequeueTextLayer {
    CATextLayer *layer;
    if (self.activeTextLayerCount < self.textLayerPool.count) {
        layer = self.textLayerPool[self.activeTextLayerCount];
    } else if (self.textLayerPool.count < kMaxTextLayerPoolSize) {
        layer = [CATextLayer layer];
        layer.contentsScale = UIScreen.mainScreen.scale;
        layer.alignmentMode = kCAAlignmentCenter;
        layer.shadowColor   = UIColor.blackColor.CGColor;
        layer.shadowOffset  = CGSizeMake(0.5f, 0.5f);
        layer.shadowOpacity = 0.9f;
        layer.shadowRadius  = 0.0f;
        layer.actions = @{ @"position":NSNull.null, @"bounds":NSNull.null, @"string":NSNull.null, @"hidden":NSNull.null };
        [self.textLayerPool addObject:layer];
        [self.layer addSublayer:layer];
    } else {
        return nil;
    }
    layer.hidden = NO;
    self.activeTextLayerCount++;
    return layer;
}

- (void)addText:(NSString *)text frame:(CGRect)frame color:(UIColor *)color
       fontSize:(CGFloat)fontSize leftAligned:(BOOL)leftAligned {
    if (!text.length) return;
    CGFloat fs        = (fontSize > 0) ? fontSize : 9.0f;
    CATextLayer *l    = [self dequeueTextLayer];
    if (!l) return;
    if (![l.string isEqual:text]) l.string = text;
    l.frame           = frame;
    l.foregroundColor = color.CGColor;
    if (l.fontSize != fs || !l.font) {
        l.fontSize = fs;
        l.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:fs weight:UIFontWeightSemibold];
    }
    l.alignmentMode   = leftAligned ? kCAAlignmentLeft : kCAAlignmentCenter;
}

- (void)applyRenderPreferences {
    if (self.appliedRenderRevision == gRenderPrefsRevision) return;
    self.appliedRenderRevision = gRenderPrefsRevision;
    UIColor *boxColor = ESPColor(@"BoxColor", 0.46, 0.86, 0.73);
    self.boxBotLayer.strokeColor = self.boxPlayerLayer.strokeColor = self.boxKnockLayer.strokeColor = boxColor.CGColor;
    self.axisXLayer.strokeColor = [UIColor colorWithRed:1 green:.36 blue:.4 alpha:1].CGColor;
    self.axisYLayer.strokeColor = [UIColor colorWithRed:.46 green:.86 blue:.73 alpha:1].CGColor;
    self.axisZLayer.strokeColor = [UIColor colorWithRed:.36 green:.65 blue:1 alpha:1].CGColor;
    using namespace ESPReferenceStyle;
    self.snaplineLayer.strokeColor = ESPColor(@"LineColor",Line.r,Line.g,Line.b).CGColor;
    self.snaplineLayer.lineWidth = 0.9;
    self.boneLayer.strokeColor = ESPColor(@"SkeletonColor",Skeleton.r,Skeleton.g,Skeleton.b).CGColor;
    self.fovLayer.strokeColor = ESPColor(@"FovColor",Fov.r,Fov.g,Fov.b).CGColor;
    for (CAShapeLayer *layer in @[self.boxBotLayer, self.boxPlayerLayer, self.boxKnockLayer]) {
        layer.lineWidth = isCleanESP ? 1.35 : 1.5;
        layer.opacity = 0.95;
    }
    for (CAShapeLayer *layer in @[self.axisYLayer, self.axisXLayer, self.axisZLayer]) {
        layer.lineWidth = 1.35;
        layer.opacity = .9;
    }
    self.boneLayer.lineWidth = 1.0;
    self.boneLayer.opacity = 0.95;
    self.fovLayer.lineWidth = 1.0;
    self.fovLayer.opacity = 0.92;
    const float fps = gBalancedRender ? 30.0f : 60.0f;
    if (@available(iOS 15.0, *)) self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
    else self.displayLink.preferredFramesPerSecond = (NSInteger)fps;
}

- (void)updateFovCircle {
    const CGFloat vw = self.bounds.size.width, vh = self.bounds.size.height;
    if (!showFov || vw <= 0 || vh <= 0) { self.fovLayer.path = nil; return; }
    const float radius = gAimType == AimModePolicy::Type::Silent ? SilentAimSelection::Radius(vw, vh, activeSilentFov) :
        AimSelection::Radius(vw, vh, fovPercent);
    if (self.fovLayer.path && CGSizeEqualToSize(self.lastFovSize, self.bounds.size) && self.lastFovRadius == radius) return;
    CGMutablePathRef path = CGPathCreateMutable();
    RenderFOVCirclePath(path, vw, vh, YES, radius);
    self.fovLayer.path = path;
    CGPathRelease(path);
    self.lastFovSize = self.bounds.size;
    self.lastFovRadius = radius;
}

- (void)updateFrame {
    if (!self.window) return;
#ifdef MIZZE_INJECTED
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        GhostModeCancel(); PlayerModesCancel();
        [self clearAllContent]; return;
    }
#endif

    @autoreleasepool {
        const CFTimeInterval now = CACurrentMediaTime();
        BeginTransformFrame();
        if (now >= self.nextProcessCheck) {
            self.nextProcessCheck = now + 1.0;
            [self setupModuleBase];
        }

        if (!gESPPrefsLoadedOnce) {
            ESPSyncFromPrefs();
        }
        // Ghost does not depend on a target, gun, ESP dictionary or camera.
        gGhostInstall = GhostModeUpdate(Moudule_Base);
        gPlayerModesInstall = PlayerModesUpdate(Moudule_Base);
        if (now >= gNextGhostRead) {
            gNextGhostRead = now + 0.1;
            gGhostSnapshot = GhostModeRead();
        }
        self.ghostLayer.path = nil;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self applyRenderPreferences];
        if (!isVaildPtr(Moudule_Base)) {
            [self clearAllContent];
            [self updateFovCircle];
            [CATransaction commit];
            return;
        }
        self.activeTextLayerCount = 0;

        CGFloat vw    = self.bounds.size.width;
        CGFloat vh    = self.bounds.size.height;
        CGFloat scale = self.contentScaleFactor > 0.01f ? self.contentScaleFactor : 1.0f;
        CGFloat vpW   = vw * scale;
        CGFloat vpH   = vh * scale;

        ESPGeometryBuffers buffers = ESPGeometryBuffersCreate();
        ESPFrameStats stats = [self renderESPWithBuffers:&buffers
                                               viewWidth:vw viewHeight:vh
                                           matrixVpWidth:vpW matrixVpHeight:vpH];

        ApplyPath(self.boneLayer,         buffers.bonePath,         buffers.boneDirty);
        ApplyPath(self.snaplineLayer,     buffers.snaplinePath,     buffers.snaplineDirty);
        ApplyPath(self.hpBackgroundLayer, buffers.hpBackgroundPath, buffers.hpBackgroundDirty);
        ApplyPath(self.hpFillLayer,       buffers.hpFillPath,       buffers.hpFillDirty);

        ApplyPath(self.boxKnockLayer,     buffers.boxKnockPath,     buffers.boxKnockDirty);
        ApplyPath(self.axisZLayer,    buffers.axisZPath,    buffers.axisZDirty);
        ApplyPath(self.boxBotLayer,       buffers.boxBotPath,       buffers.boxBotDirty);
        ApplyPath(self.boxPlayerLayer,    buffers.boxPlayerPath,    buffers.boxPlayerDirty);
        ApplyPath(self.axisYLayer,      buffers.axisYPath,      buffers.axisYDirty);
        ApplyPath(self.axisXLayer,   buffers.axisXPath,   buffers.axisXDirty);

        ApplyPath(self.hpWarningLayer, buffers.hpWarningPath, buffers.hpWarningDirty);
        ApplyPath(self.hpCriticalLayer, buffers.hpCriticalPath, buffers.hpCriticalDirty);
        ApplyPath(self.hpHighlightLayer, buffers.hpHighlightPath, buffers.hpHighlightDirty);
        ESPGeometryBuffersRelease(&buffers);

        for (NSUInteger i = self.activeTextLayerCount; i < self.textLayerPool.count; ++i)
            self.textLayerPool[i].hidden = YES;

        if (stats.inMatch) {
            // OK
        } else {
            [self clearAllContent];
        }

        // FOV is a screen-space setting and does not depend on successful game reads.
        [self updateFovCircle];
        [CATransaction commit];
        // CADisplayLink owns pacing. A second random timer used to skip valid
        // display ticks and leave ESP geometry behind the moving camera.
        const CFTimeInterval finished = CACurrentMediaTime();
#ifndef MIZZE_INJECTED
        HUDRecordFrame((finished - now) * 1000, stats.playerCount + stats.botCount,
                       AimStateDescription(stats.aimState));
#endif
    }
}

- (void)drawGhostAnchor:(Vector3)anchor matrix:(float *)matrix width:(CGFloat)vw height:(CGFloat)vh
               vpWidth:(CGFloat)vpW vpHeight:(CGFloat)vpH {
    // A small world-space cube marks the saved point, independently of ESP flags.
    Vector3 corners[8], projected[8];
    for (int i = 0; i < 8; ++i) {
        corners[i] = {anchor.x + ((i & 1) ? 0.18f : -0.18f),
            anchor.y + ((i & 2) ? 0.36f : 0), anchor.z + ((i & 4) ? 0.18f : -0.18f)};
        projected[i] = WorldToScreenLayer(corners[i], matrix, vpW, vpH, vw, vh);
    }
    CGMutablePathRef path = CGPathCreateMutable();
    for (int i = 0; i < 8; ++i) for (int bit : {1,2,4}) {
        if (i & bit) continue;
        const auto a = projected[i], b = projected[i | bit];
        if (a.z <= 0.001f || b.z <= 0.001f || !std::isfinite(a.x) || !std::isfinite(a.y) ||
            !std::isfinite(b.x) || !std::isfinite(b.y)) continue;
        CGPathMoveToPoint(path, NULL, a.x, a.y);
        CGPathAddLineToPoint(path, NULL, b.x, b.y);
    }
    self.ghostLayer.path = path;
    CGPathRelease(path);
}
- (void)clearAllContent {
    self.ghostLayer.path = nil;
    AutoFireClear();
    SilentAimSetEnabled(false);
    ResetWeaponFeatures();
    SetMatchReady(NO);
    gAimLockTarget      = 0;
    gAimLockedHead      = {};
    gAimSmoothedValid   = false;
    self.boxKnockLayer.path = self.axisZLayer.path = self.fovLayer.path = nil;
    self.hpWarningLayer.path = self.hpCriticalLayer.path = self.hpHighlightLayer.path = nil;
    self.boxLayer.path = self.boneLayer.path = self.snaplineLayer.path = self.axisYLayer.path = self.axisXLayer.path = self.boxBotLayer.path = self.boxPlayerLayer.path = nil;
    self.hpBackgroundLayer.path = self.hpFillLayer.path                 = nil;
    self.aimAssistLayer.path = self.alertLayer.path = nil;
    [self resetTextLayers];
}

- (void)dealloc {
    GhostModeCancel(); PlayerModesCancel();
    AutoFireClear();
    SilentAimSetEnabled(false);
    ResetWeaponFeatures();
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_displayLink invalidate];
    _displayLink = nil;
}


static inline bool IsZeroVec(const Vector3 &v) {
    return v.x == 0.0f && v.y == 0.0f && v.z == 0.0f;
}

// ============================================================
// ✅ HELPER: Kiểm tra Bot / Knocked
// ============================================================
bool get_IsBot(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    return ReadAddr<uint8_t>(player + (uint64_t)kIsClientBot) != 0;
}

bool get_IsKnockedDown(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    if (get_CurHP(player) <= 0) return false;
    uint64_t phx = ReadAddr<uint64_t>(player + kMyPhysXData);
    if (isVaildPtr(phx)) {
        uint64_t ghg = ReadAddr<uint64_t>(phx + (uint64_t)kPhxNpeononogeo);
        if (isVaildPtr(ghg) && ReadAddr<uint32_t>(ghg + (uint64_t)kGhgState) == 8)
            return true;
    }
    return ReadAddr<uint8_t>(player + kKnocked) != 0;
}

bool get_IsScoping(uint64_t p) { return isVaildPtr(p) && AimSelection::ScopeState(GetDataUInt16(p, 12)); }


- (ESPFrameStats)renderESPWithBuffers:(ESPGeometryBuffers *)buffers
                            viewWidth:(CGFloat)vw viewHeight:(CGFloat)vh
                        matrixVpWidth:(CGFloat)vpW matrixVpHeight:(CGFloat)vpH {
    ESPFrameStats stats = {};
    struct SilentFrame {
        bool published = false;
        ~SilentFrame() {
            if (isSilentAim && !published) SilentAimClearTarget();
            if (gAutoFire && !published) AutoFireClear();
        }
    } silentFrame;
    if (!buffers || !isVaildPtr(Moudule_Base)) {
        cachedMatchGame = cachedMatch = cachedCamera = 0;
        return stats;
    }
    // Refresh the match identity each frame so a new match cannot reuse a stale lock.
    const uint64_t matchGame = getMatchGame(Moudule_Base);
    if (!isVaildPtr(matchGame)) {
        cachedMatchGame = cachedMatch = cachedCamera = 0;
        return stats;
    }
    const uint64_t match = getMatch(matchGame);
    const bool sameMatch = match == cachedMatch;
    cachedMatchGame = matchGame;
    cachedMatch = match;
    cachedCamera = CameraMain(matchGame);
    if (!isVaildPtr(cachedCamera) || !isVaildPtr(match)) return stats;

    const uint64_t local = getLocalPlayer(match);
    if (!isVaildPtr(local) || get_CurHP(local) <= 0) return stats;
    const uint64_t camTransform = ReadAddr<uint64_t>(local + kMainCameraTransform);
    if (!isVaildPtr(camTransform)) return stats;
    const Vector3 myLoc = getPositionExt(camTransform);
    if (IsZeroVec(myLoc) || !std::isfinite(myLoc.x) || !std::isfinite(myLoc.y) || !std::isfinite(myLoc.z)) return stats;

    const uint64_t dict = ReadAddr<uint64_t>(match + kMatchPlayerDict);
    if (!isVaildPtr(dict)) return stats;
    const int count = ReadAddr<int>(dict + kDictCount);
    const uint64_t entries = ReadAddr<uint64_t>(dict + kDictEntries);
    if (!isVaildPtr(entries)) return stats;
    const int capacity = ReadAddr<int>(entries + kIl2CppArrayMaxLength);
    if (capacity <= 0 || capacity > 256 || count < 0 || count > capacity) return stats;
    std::array<uint8_t, 256 * kDictEntryStrideBytePlayer> snapshot{};
    if (count && !_read((long)(entries + kIl2CppArrayItems), snapshot.data(),
                       count * kDictEntryStrideBytePlayer)) return stats;
    // Luôn đọc matrix mới nhất từ camera mỗi frame để ESP theo đúng góc màn hình
    // Không cache matrix — nếu camera xoay, ESP phải cập nhật ngay
    cachedCamera = CameraMain(matchGame);
    float *matrix = GetViewMatrix(cachedCamera);
    if (!matrix) return stats;
    stats.inMatch = true;
    SetMatchReady(YES);
    if (gGhostMode && gGhostSnapshot.active && gGhostSnapshot.match == match && gGhostSnapshot.local == local)
        [self drawGhostAnchor:gGhostSnapshot.anchor matrix:matrix width:vw height:vh vpWidth:vpW vpHeight:vpH];
    UpdateWeaponFeatures(Moudule_Base, gNoReload, gFastFire, gAutoFire);
    UpdateRunSpeed(Moudule_Base,gRunSpeed,gRunSpeedValue);
    self.aimAssistLayer.path = nil;

    stats.firingRaw = get_FiringPRIState(local);
    stats.firing    = GamePRI::Firing(stats.firingRaw);
    stats.scoping   = get_IsScoping(local);
    const auto silentConfig = SilentAimPolicy::Resolve(stats.scoping, silentAutoConfig, silentFovPercent, silentMaxDistance);
    activeSilentFov = silentConfig.fov;
    const float activeSilentDistance = silentConfig.distance;
    const bool triggerActive = gAimType != AimModePolicy::Type::Silent && !get_IsKnockedDown(local) &&
        AimModePolicy::Triggered(gAimActivation, stats.firing, stats.scoping);
    stats.aimState = triggerActive ? 2 : 1;

    const bool sameLocal = sameMatch && (local == gAimLocalPlayer);
    gAimLocalPlayer = local;
    const uint64_t previousTarget = sameLocal ? gAimLockTarget : 0;
    if (!sameLocal) gAimSmoothedValid = false;
    gAimLockTarget = 0;
    gAimLockedHead = {};

    AimSelection::Selection selection;
    selection.previous = triggerActive ? previousTarget : 0;
    SilentAimSelection::Selection silentSelection;
    silentSelection.previous = previousTarget;
    Vector3 targetHead;
    Vector3 targetBody;

    const float radius = isSilentAim ? SilentAimSelection::Radius(vw, vh, activeSilentFov) :
        AimSelection::Radius(vw, vh, fovPercent);
    for (int i = 0; i < count; ++i) {
        const uint8_t *entry = snapshot.data() + kDictEntryStrideBytePlayer * i;
        int hash = -1;
        uint64_t pawn = 0;
        std::memcpy(&hash, entry, sizeof(hash));
        if (hash < 0) continue;
        std::memcpy(&pawn, entry + kDictEntryValueOffByte, sizeof(pawn));
        if (!isVaildPtr(pawn) || pawn == local || isLocalTeamMate(local, pawn)) continue;
        const int hp = get_CurHP(pawn);
        if (hp <= 0) continue;
        const Vector3 hip = getPositionExt(getHip(pawn));
        if (IsZeroVec(hip)) continue;
        const float distance = Vector3::Distance(myLoc, hip);
        if (!std::isfinite(distance) || distance > std::max(gESPMaxDistance,
            isSilentAim ? activeSilentDistance : gESPMaxDistance)) continue;
        const bool knocked = get_IsKnockedDown(pawn);
        const bool visible = getIsVisible(pawn);

        if ((triggerActive || isSilentAim) && visible && !knocked) {
            Vector3 head = getPositionExt(getHead(pawn));
            if (isAimNeck && !isSilentAim) head = AimPoint::Neck(head, hip);
            if (!IsZeroVec(head) && std::isfinite(head.x) &&
                std::isfinite(head.y) && std::isfinite(head.z)) {
                const Vector3 screen = WorldToScreenLayer(head, matrix, vpW, vpH, vw, vh);
                if (isSilentAim) {
                    silentSelection.consider(pawn, screen.x, screen.y, screen.z, vw, vh,
                        radius, distance, activeSilentDistance, true);
                    if (silentSelection.target == pawn) {
                        targetHead = head;
                        const auto chest = SilentAimPolicy::Chest({head.x,head.y,head.z},{hip.x,hip.y,hip.z});
                        targetBody = {chest.x,chest.y,chest.z};
                    }
                } else {
                    selection.consider(pawn, screen.x, screen.y, screen.z, vw, vh, radius, true);
                    if (selection.target == pawn) targetHead = head;
                }
            }
        }

        if ((isLine || isXYZAxes) && distance <= gESPMaxDistance)
            RenderXYZAxes(buffers, getPositionExt(getHead(pawn)), matrix, vw, vh);
        if ((visible || knocked) && distance <= gESPMaxDistance) {
            const bool bot = get_IsBot(pawn);
            if (bot) ++stats.botCount;
            else ++stats.playerCount;
            _0x35572DA(buffers, ESPTextCallback, (__bridge void *)self,
                       pawn, hp, distance, hip, knocked, bot, matrix, vw, vh, vpW, vpH);
        }
    }

    if(gTargetLine && (isSilentAim ? silentSelection.target : selection.target)) {
        const Vector3 point=WorldToScreenLayer(targetHead,matrix,vpW,vpH,vw,vh);
        if(std::isfinite(point.x)&&std::isfinite(point.y)&&point.z>0&&point.x>=0&&point.x<=vw&&point.y>=0&&point.y<=vh) {
            UIBezierPath *line=[UIBezierPath bezierPath];
            [line moveToPoint:CGPointMake(vw*0.5,vh*0.5)];
            [line addLineToPoint:CGPointMake(point.x,point.y)];
            self.aimAssistLayer.path=line.CGPath;
        }
    }
    if (isSilentAim) {
        // Re-arm after invalid match/window frames. The adapter rechecks firing
        // and player/weapon identity at the native handler, not at render time.
        SilentAimSetEnabled(true);
        stats.aimState = SilentAimUpdate(Moudule_Base, match, local,
            get_IsKnockedDown(local) ? 0 : silentSelection.target, targetHead, targetBody, silentHeadPercent);
        if (gAutoFire)
            stats.autoFireState = AutoFireUpdate(Moudule_Base, match, local,
                stats.aimState == 8 ? silentSelection.target : 0,
                myLoc, targetHead, targetBody, silentHeadPercent, gAutoSwap);
        else AutoFireClear();
        silentFrame.published = true;
        gAimLockTarget = silentSelection.target;
        gAimSmoothedValid = false;
        return stats;
    }

    // Write rotation only for the selected trigger mode and a target inside FOV.
    if (triggerActive && selection.target) {
        const uint64_t finalTarget = selection.target;
        const Vector3  finalHead   = targetHead;
        stats.aimState = 5;
        if (getAimVisibility(finalTarget) &&
            get_CurHP(finalTarget) > 0 && !get_IsKnockedDown(finalTarget) &&
            get_CurHP(local) > 0 && !get_IsKnockedDown(local)) {
            const Vector3 direction = finalHead - myLoc;
            if (Vector3::SqrMagnitude(direction) > 0.0001f) {
                const Quaternion targetRot = Quaternion::Normalized(
                    Quaternion::LookRotation(direction, Vector3::Up()));
                if (std::isfinite(targetRot.x) && std::isfinite(targetRot.y) &&
                    std::isfinite(targetRot.z) && std::isfinite(targetRot.w)) {
                    stats.aimState = 3;
                    // So sánh với previousTarget (trước khi reset)
                    // gAimLockTarget đã bị reset = 0 ở trên nên không dùng được
                    if (!gAimSmoothedValid || previousTarget != finalTarget) {
                        gAimSmoothed = ReadAddr<Quaternion>(local + kAimRotation);
                        if (!std::isfinite(gAimSmoothed.x) || !std::isfinite(gAimSmoothed.y) ||
                            !std::isfinite(gAimSmoothed.z) || !std::isfinite(gAimSmoothed.w))
                            gAimSmoothed = targetRot;
                        gAimSmoothedValid = true;
                    }
                    const float dt     = gBalancedRender ? (1.0f/30.0f) : (1.0f/60.0f);
                    const float maxRad = gAimSpeed * Deg2Rad * dt;
                    gAimSmoothed = Quaternion::RotateTowards(gAimSmoothed, targetRot, maxRad);
                    if (WriteAddr<Quaternion>(local + kAimRotation, gAimSmoothed)) {
                        stats.aimState = WriteAddr<Quaternion>(local + kAimRotationAux, gAimSmoothed) ? 4 : 6;
                        gAimLockTarget = finalTarget;
                        gAimLockedHead = finalHead;
                    }
                }
            }
        }
    } else {
        gAimSmoothedValid = false;
    }

    return stats;
}

@end

// ============================================================
// ✅ _0x953DA13 - VIEW CONTAINER (GIỮ NGUYÊN)
// ============================================================
@implementation _0x953DA13 {
    _0xDAB2826 *_0x2862AD;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    for (UIView *v in self.subviews) [v removeFromSuperview];
    self.backgroundColor        = UIColor.clearColor;
    self.userInteractionEnabled = NO;

    _0x2862AD = [[_0xDAB2826 alloc] initWithFrame:self.bounds];
    _0x2862AD.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_0x2862AD];
    return self;
}

@end
