#include "../Core/AimSelection.h"

#import "esp.h"
#import "ESPPrefs.h"
#import "ESPStyle.h"
#import "LicenseSession.h"
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
#include "KabraxHide.h"
#include <float.h>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <map>


uint64_t Moudule_Base = -1;
float percent = 0.0f;

// ============================================================
// ✅ BIẾN ESP (GIỮ LẠI)
// ============================================================
bool isBox        = YES;
bool isCount      = NO;
bool isHealth     = YES;
bool isName       = YES;
bool isDis        = YES;
bool isLine       = YES;
bool isHeadRedDot = YES;
bool isAimbotFire = YES;
static bool isAimbotScope = YES;
static bool isAimNeck = YES;
static bool showFov = YES;
static float fovPercent = 40.0f;
bool isBox3D = YES;
static uint64_t gAimLockTarget = 0;
static uint64_t gAimLocalPlayer = 0;

static bool gESPPrefsLoadedOnce = false;

// ============================================================
// ✅ SYNC PREFS - ESP & AIMBOT
// ============================================================
void ESPSyncFromPrefs(void) {
    isBox        = ESPPrefsBool(KH_NS("Box"),        NO);
    isHealth     = ESPPrefsBool(KH_NS("Health"),     NO);
    isName       = ESPPrefsBool(KH_NS("Name"),       NO);
    isDis        = ESPPrefsBool(KH_NS("Dis"),        NO);
    isLine       = ESPPrefsBool(KH_NS("Line"),       NO);
    isHeadRedDot = ESPPrefsBool(KH_NS("HeadRedDot"), YES);
    isAimbotFire = ESPPrefsBool(KH_NS("AimbotFire"), YES);
    isAimbotScope = ESPPrefsBool(KH_NS("AimbotScope"), YES);
    isAimNeck = ESPPrefsBool(@"AimNeck", YES);
    showFov = ESPPrefsBool(@"ShowFov", YES);
    fovPercent = ESPPrefsFloat(@"FovSize", 40);
    isBox3D = ESPPrefsBool(@"Box3D", YES);

    // ESP Count logic
    if (isLine || isBox || isHealth) {
        isCount = YES;
    } else {
        isCount = NO;
    }
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
} ESPFrameStats;

// ─── Helpers ──────────────────────────────────
static inline float Clamp01f(float v) {
    return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

static inline void ESPReleasePath(CGMutablePathRef p) { if (p) CGPathRelease(p); }

static inline ESPGeometryBuffers ESPGeometryBuffersCreate(void) {
    ESPGeometryBuffers b{};
    b.boxBotPath       = CGPathCreateMutable();
    b.boxPlayerPath    = CGPathCreateMutable();
    b.boxKnockPath     = CGPathCreateMutable();

    b.lineKnockPath    = CGPathCreateMutable();
    b.lineBotPath      = CGPathCreateMutable();
    b.linePlayerPath   = CGPathCreateMutable();

    b.bonePath         = CGPathCreateMutable();
    b.snaplinePath     = CGPathCreateMutable();
    b.hpBackgroundPath = CGPathCreateMutable();
    b.hpFillPath       = CGPathCreateMutable();
    b.hpWarningPath = CGPathCreateMutable();
    b.hpCriticalPath = CGPathCreateMutable();
    b.hpHighlightPath = CGPathCreateMutable();
    b.aimAssistPath    = CGPathCreateMutable();
    b.alertPath        = CGPathCreateMutable();

    b.boxBotDirty = b.boneDirty = b.lineBotDirty = NO;
    b.hpBackgroundDirty = b.hpFillDirty          = NO;
    b.aimAssistDirty = b.alertDirty              = NO;
    return b;
}

static inline void ESPGeometryBuffersRelease(ESPGeometryBuffers *b) {
    if (!b) return;
    ESPReleasePath(b->boxBotPath);
    ESPReleasePath(b->lineBotPath);
    ESPReleasePath(b->boxPlayerPath);
    ESPReleasePath(b->linePlayerPath);
    ESPReleasePath(b->boxKnockPath);
    ESPReleasePath(b->lineKnockPath);

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
@property (nonatomic, strong) NSMutableArray<CATextLayer *> *textLayerPool;
@property (nonatomic, assign) NSUInteger              activeTextLayerCount;
@property (nonatomic, strong) CATextLayer            *statusLayer;

@property (nonatomic, strong) CAShapeLayer *boxBotLayer;
@property (nonatomic, strong) CAShapeLayer *boxPlayerLayer;
@property (nonatomic, strong) CAShapeLayer *lineBotLayer;
@property (nonatomic, strong) CAShapeLayer *linePlayerLayer;
@property (nonatomic, strong) CAShapeLayer *boxKnockLayer;
@property (nonatomic, strong) CAShapeLayer *lineKnockLayer;
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
    self.textLayerPool          = [NSMutableArray array];

    [self configureRenderingLayers];
    [self setupModuleBase];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:KH_SEL("updateFrame")];
    if (@available(iOS 15.0, *))
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0, 60.0, 60.0);
    else if (@available(iOS 10.0, *))
        self.displayLink.preferredFramesPerSecond = 60;
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
}



- (void)setupModuleBase {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Moudule_Base = (uint64_t)GetGameModule_Base((char *)KH_STR("FreeFire"));
        // ❌ ĐÃ XÓA: Tạo thread silent aim
        // _0x2872TH2 = std::thread(_0xASI2872D);
        // _0x2872TH2.detach();
    });
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
    l.shadowColor = UIColor.blackColor.CGColor;
    l.shadowOffset = CGSizeMake(0, 1);
    l.shadowOpacity = 0.65f;
    l.shadowRadius = 1.0f;
    l.actions = @{ KH_NS("path"): NSNull.null };
    return l;
}

- (void)configureRenderingLayers {
    UIColor *white  = [UIColor colorWithRed:0.72 green:0.91 blue:1.0 alpha:0.95];
    UIColor *clear  = UIColor.clearColor;
    UIColor *yellow = [UIColor colorWithRed:0.95 green:0.79 blue:0.48 alpha:0.9];

    UIColor *hpGreen = [UIColor colorWithRed:0.0f green:0.85f blue:0.2f alpha:1.0f];
    UIColor *red     = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f];

    self.lineKnockLayer  = [self makeShapeLayer:red fill:nil lineWidth:0.5f zPos:1];
    self.boxKnockLayer   = [self makeShapeLayer:red fill:nil lineWidth:0.5f zPos:1];

    self.lineBotLayer    = [self makeShapeLayer:yellow fill:nil lineWidth:1.0f zPos:1];
    self.linePlayerLayer = [self makeShapeLayer:white fill:nil lineWidth:1.0f zPos:1];

    self.boxBotLayer     = [self makeShapeLayer:yellow fill:nil lineWidth:1.0f zPos:3];
    self.boxPlayerLayer  = [self makeShapeLayer:white fill:nil lineWidth:1.0f zPos:3];

    self.fovLayer        = [self makeShapeLayer:[UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f] fill:nil lineWidth:1.0f zPos:0];

    self.snaplineLayer     = [self makeShapeLayer:white   fill:nil     lineWidth:0.8f zPos:1];
    self.boneLayer         = [self makeShapeLayer:white   fill:nil     lineWidth:0.5f zPos:2];
    self.boxLayer          = [self makeShapeLayer:white   fill:nil     lineWidth:0.5f zPos:3];
    self.hpBackgroundLayer = [self makeShapeLayer:nil     fill:[UIColor colorWithWhite:0.02 alpha:0.9] lineWidth:0 zPos:4];
    self.hpFillLayer       = [self makeShapeLayer:nil     fill:hpGreen lineWidth:0    zPos:5];

    self.hpWarningLayer = [self makeShapeLayer:nil fill:[UIColor colorWithRed:1 green:0.72 blue:0.25 alpha:1] lineWidth:0 zPos:5];
    self.hpCriticalLayer = [self makeShapeLayer:nil fill:[UIColor colorWithRed:1 green:0.27 blue:0.32 alpha:1] lineWidth:0 zPos:5];
    self.hpHighlightLayer = [self makeShapeLayer:nil fill:[UIColor colorWithWhite:1 alpha:0.4] lineWidth:0 zPos:6];

    for (CAShapeLayer *l in @[self.hpWarningLayer, self.hpCriticalLayer, self.hpHighlightLayer, self.fovLayer, self.snaplineLayer, self.boneLayer, self.boxLayer,
                               self.hpBackgroundLayer, self.hpFillLayer,
                            self.boxBotLayer, self.boxPlayerLayer, self.lineBotLayer, self.linePlayerLayer, self.lineKnockLayer, self.boxKnockLayer]) {
        [self.layer addSublayer:l];
    }

    self.statusLayer = [CATextLayer layer];
    self.statusLayer.foregroundColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:1.0f].CGColor;
    self.statusLayer.alignmentMode   = kCAAlignmentCenter;
    self.statusLayer.fontSize        = 16.0f;
    self.statusLayer.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:16.0f weight:UIFontWeightHeavy];
    self.statusLayer.backgroundColor = UIColor.clearColor.CGColor;
    self.statusLayer.borderWidth = 0;
    self.statusLayer.cornerRadius = 0;
    self.statusLayer.shadowColor = UIColor.blackColor.CGColor;
    self.statusLayer.shadowOffset = CGSizeMake(0, 1);
    self.statusLayer.shadowOpacity = 0.85f;
    self.statusLayer.shadowRadius = 1.5f;
    self.statusLayer.contentsScale   = UIScreen.mainScreen.scale;
    self.statusLayer.zPosition       = 8;
    self.statusLayer.actions = @{ @"string":NSNull.null, @"frame":NSNull.null, @"hidden":NSNull.null };
    [self.layer addSublayer:self.statusLayer];
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
        layer.shadowOpacity = 1.0f;
        layer.shadowRadius  = 0.0f;
        layer.actions = @{ @"position":NSNull.null, @"bounds":NSNull.null, @"string":NSNull.null, @"hidden":NSNull.null };
        [self.textLayerPool addObject:layer];
        [self.layer addSublayer:layer];
    } else {
        layer = self.textLayerPool.lastObject;
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
    l.string          = text;
    l.frame           = frame;
    l.foregroundColor = color.CGColor;
    l.fontSize        = fs;
    l.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:fs weight:UIFontWeightBold];
    l.alignmentMode   = leftAligned ? kCAAlignmentLeft : kCAAlignmentCenter;
    l.shadowColor     = UIColor.blackColor.CGColor;
    l.shadowOffset    = CGSizeMake(0.5f, 0.5f);
    l.shadowOpacity   = 1.0f;
    l.shadowRadius    = 0.0f;
}

- (void)updateFrame {
    if (!self.window) return;
    if (![LicenseSession shared].authorized) { [self clearAllContent]; return; }
    @autoreleasepool {
#ifdef NOTIFY_DESTROY_HUD
        if (GetGameProcesspid((char *)KH_STR("FreeFire")) == -1) {
            Moudule_Base = (uint64_t)-1;
            [self clearAllContent];
            return;
        }
#endif
        if (Moudule_Base == (uint64_t)-1)
            Moudule_Base = (uint64_t)GetGameModule_Base((char *)KH_STR("FreeFire"));

        if (!gESPPrefsLoadedOnce) {
            ESPSyncFromPrefs();
            gESPPrefsLoadedOnce = true;
        }

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self resetTextLayers];

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
        ApplyPath(self.lineKnockLayer,    buffers.lineKnockPath,    buffers.lineKnockDirty);
        ApplyPath(self.boxBotLayer,       buffers.boxBotPath,       buffers.boxBotDirty);
        ApplyPath(self.boxPlayerLayer,    buffers.boxPlayerPath,    buffers.boxPlayerDirty);
        ApplyPath(self.lineBotLayer,      buffers.lineBotPath,      buffers.lineBotDirty);
        ApplyPath(self.linePlayerLayer,   buffers.linePlayerPath,   buffers.linePlayerDirty);

        ApplyPath(self.hpWarningLayer, buffers.hpWarningPath, buffers.hpWarningDirty);
        ApplyPath(self.hpCriticalLayer, buffers.hpCriticalPath, buffers.hpCriticalDirty);
        ApplyPath(self.hpHighlightLayer, buffers.hpHighlightPath, buffers.hpHighlightDirty);
        ESPGeometryBuffersRelease(&buffers);

        UIColor *boxColor = ESPColor(@"BoxColor", 0.72, 0.91, 1.0);
        UIColor *lineColor = ESPColor(@"LineColor", 0.72, 0.91, 1.0);
        self.boxBotLayer.strokeColor = self.boxPlayerLayer.strokeColor = self.boxKnockLayer.strokeColor = boxColor.CGColor;
        self.lineBotLayer.strokeColor = self.linePlayerLayer.strokeColor = self.lineKnockLayer.strokeColor = lineColor.CGColor;
        self.fovLayer.strokeColor = ESPColor(@"FovColor", 1, 1, 1).CGColor;
        CGMutablePathRef fovPath = CGPathCreateMutable();
        const float radius = AimSelection::Radius(vw, vh, fovPercent);
        BOOL hasFov = RenderFOVCirclePath(fovPath, vw, vh, showFov && stats.inMatch, radius);
        self.fovLayer.path = hasFov ? fovPath : nil;
        CGPathRelease(fovPath);

        // Plain enemy count, with no icon or background.
        if (stats.inMatch && (isCount || isLine || isBox)) {
            int totalEnemies = stats.playerCount + stats.botCount;

            UIFont *fontBasic = [UIFont systemFontOfSize:16.0f weight:UIFontWeightHeavy];
            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            attributes[NSFontAttributeName] = fontBasic;
            attributes[NSForegroundColorAttributeName] = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:1.0f];

            NSString *countStr = [NSString stringWithFormat:@"ĐỊCH: %d", totalEnemies];
            NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:countStr attributes:attributes];
            self.statusLayer.string = attrStr;

            CGFloat bannerWidth = 120.0f;
            self.statusLayer.frame = CGRectMake(vw / 2.0f - (bannerWidth / 2.0f), 22.0f, bannerWidth, 22.0f);
            self.statusLayer.alignmentMode = kCAAlignmentCenter;
            self.statusLayer.hidden = NO;
        } else {
            self.statusLayer.hidden = YES;
        }

        if (stats.inMatch) {
            // OK
        } else {
            [self clearAllContent];
        }

        [CATransaction commit];
    }
}

- (void)clearAllContent {
    gAimLockTarget = 0;
    self.statusLayer.hidden = YES;
    self.boxKnockLayer.path = self.lineKnockLayer.path = self.fovLayer.path = nil;
    self.hpWarningLayer.path = self.hpCriticalLayer.path = self.hpHighlightLayer.path = nil;
    self.boxLayer.path = self.boneLayer.path = self.snaplineLayer.path = self.lineBotLayer.path = self.linePlayerLayer.path = self.boxBotLayer.path = self.boxPlayerLayer.path = nil;
    self.hpBackgroundLayer.path = self.hpFillLayer.path                 = nil;
    self.aimAssistLayer.path = self.alertLayer.path = nil;
    [self resetTextLayers];
}

- (void)dealloc {
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

bool get_IsScoping(uint64_t p)  { return isVaildPtr(p) && GetDataUInt16(p, 12) != 0; }

- (ESPFrameStats)renderESPWithBuffers:(ESPGeometryBuffers *)buffers
                            viewWidth:(CGFloat)vw viewHeight:(CGFloat)vh
                        matrixVpWidth:(CGFloat)vpW matrixVpHeight:(CGFloat)vpH {
    ESPFrameStats stats = {0, 0, false};
    const uint64_t previousTarget = gAimLockTarget;
    gAimLockTarget = 0; // Every early return releases stale targets.
    if (!buffers || !isVaildPtr(Moudule_Base) || IsAtLobby(Moudule_Base)) {
        cachedMatchGame = cachedMatch = cachedCamera = gAimLocalPlayer = 0;
        return stats;
    }
    // Refresh the match identity each frame so a new match cannot reuse a stale lock.
    const uint64_t matchGame = getMatchGame(Moudule_Base);
    const uint64_t match = getMatch(matchGame);
    const bool sameMatch = match == cachedMatch;
    cachedMatchGame = matchGame;
    cachedMatch = match;
    cachedCamera = CameraMain(matchGame);
    if (!isVaildPtr(cachedCamera) || !isVaildPtr(match)) return stats;

    const uint64_t local = getLocalPlayer(match);
    if (!isVaildPtr(local) || get_CurHP(local) <= 0) return stats;
    const bool sameLocal = local == gAimLocalPlayer;
    gAimLocalPlayer = local;
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
    float *matrix = GetViewMatrix(cachedCamera);
    if (!matrix) return stats;
    stats.inMatch = true;

    const bool aiming = !get_IsKnockedDown(local) && AimSelection::Triggered(
        isAimbotFire, isAimbotScope, get_IsFiring(local), get_IsScoping(local));
    AimSelection::Selection selection;
    selection.previous = sameMatch && sameLocal && aiming ? previousTarget : 0;
    Vector3 targetHead;
    const float radius = AimSelection::Radius(vw, vh, fovPercent);
    const uint64_t base = entries + kIl2CppArrayItems;
    for (int i = 0; i < count; ++i) {
        const uint64_t entry = base + (uint64_t)kDictEntryStrideBytePlayer * i;
        if (ReadAddr<int>(entry) < 0) continue; // Removed dictionary entries have a negative hash.
        const uint64_t pawn = ReadAddr<uint64_t>(entry + kDictEntryValueOffByte);
        if (!isVaildPtr(pawn) || pawn == local || isLocalTeamMate(local, pawn)) continue;
        const int hp = get_CurHP(pawn);
        if (hp <= 0) continue;
        const Vector3 hip = getPositionExt(getHip(pawn));
        if (IsZeroVec(hip)) continue;
        const float distance = Vector3::Distance(myLoc, hip);
        if (!std::isfinite(distance) || distance > 150.0f) continue;
        const bool knocked = get_IsKnockedDown(pawn);
        const bool visible = getIsVisible(pawn);
        if (aiming && visible && !knocked) {
            Vector3 head = getPositionExt(getHead(pawn));
            if (isAimNeck) {
                // Estimated neck from available bones; no unverified neck offset is used.
                const Vector3 left = getPositionExt(getLeftShoulder(pawn));
                const Vector3 right = getPositionExt(getRightShoulder(pawn));
                if (IsZeroVec(left) || IsZeroVec(right) || IsZeroVec(head)) head = Vector3();
                else head = Vector3::Lerp((left + right) * 0.5f, head, 0.30f);
            }
            if (!IsZeroVec(head) && std::isfinite(head.x) && std::isfinite(head.y) && std::isfinite(head.z)) {
                const Vector3 screen = WorldToScreenLayer(head, matrix, vpW, vpH, vw, vh);
                selection.consider(pawn, screen.x, screen.y, screen.z, vw, vh, radius, true);
                if (selection.target == pawn) targetHead = head;
            }
        }
        if (visible || knocked) {
            if (get_IsBot(pawn)) ++stats.botCount;
            else ++stats.playerCount;
            _0x35572DA(buffers, ESPTextCallback, (__bridge void *)self,
                       pawn, hp, distance, matrix, vw, vh, vpW, vpH);
        }
    }
    if (aiming && selection.target) {
        const Vector3 direction = targetHead - myLoc;
        if (Vector3::SqrMagnitude(direction) > 0.0001f) {
            const Quaternion rotation = Quaternion::Normalized(Quaternion::LookRotation(direction, Vector3::Up()));
            if (std::isfinite(rotation.x) && std::isfinite(rotation.y) &&
                std::isfinite(rotation.z) && std::isfinite(rotation.w)) {
                if (WriteAddr<Quaternion>(local + kAimRotation, rotation)) {
                    WriteAddr<Quaternion>(local + kAimRotationAux, rotation);
                    gAimLockTarget = selection.target;
                }
            }
        }
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
