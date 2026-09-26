// ============================================================
// _0xE298S9_.mm
// ESP chính - BẢN ĐÃ XÓA AIMBOT / SILENT AIM / AIM LOCK
// CHỈ GIỮ LẠI: ESP Line, Box, Hp, Count
// ============================================================

#import "esp.h"
#import "ESPPrefs.h"
#import "../drawing_view/offset.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <string>
#include <vector>
#include <cmath>
#include "KabraxHide.h"
#include <float.h>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <map>

// ============================================================
// ❌ ĐÃ XÓA: Thread silent aim
// std::thread _0x2872TH2;
// std::mutex _0x2OK2872;
// std::condition_variable _0x2829CV;
// bool _0x2RSL292 = false;
// bool _0xESL2872 = false;
// ============================================================

uint64_t Moudule_Base = -1;
float percent = 0.0f;

// ============================================================
// ✅ BIẾN ESP (GIỮ LẠI)
// ============================================================
bool isBox      = YES;
bool isCount    = NO;
bool isHealth   = YES;
bool isName     = YES;
bool isDis      = YES;
bool isLine     = YES;

// ❌ ĐÃ XÓA: Biến aimbot
// bool isEspBot   = NO;
// bool isBone     = NO;
// bool _0x92710   = NO;
// bool _0x3872DA  = NO;
// bool isAimIgnoreBot    = NO;
// bool isAimIgnoreKnock  = YES;
// bool isAimCheckVisible = NO;
// bool isAimRage         = NO;
// bool isLineAim         = YES;
// bool _0x3872DB         = YES;
// bool _0x2872o          = NO;
// bool aimsilent1        = NO;
// int  box               = 0;
// int  triggerMode       = 3;
// int  _0x2874           = 0;
// int  _0x3872AB         = 0;
// int  aimTargetMode     = 0;
// float aimFov           = 150.0f;
// float aimDistance      = 150.0f;
// float aimSpeed         = 0.95f;
// bool _0x2873           = NO;
// bool _0x83278          = NO;
// int  _0x28726          = 0;

static bool gESPPrefsLoadedOnce = false;

// ============================================================
// ✅ SYNC PREFS - CHỈ ESP
// ============================================================
void ESPSyncFromPrefs(void) {
    isBox    = ESPPrefsBool(KH_NS("Box"),    NO);
    isHealth = ESPPrefsBool(KH_NS("Health"), NO);
    isName   = ESPPrefsBool(KH_NS("Name"),   NO);
    isDis    = ESPPrefsBool(KH_NS("Dis"),    NO);
    isLine   = ESPPrefsBool(KH_NS("Line"),   NO);
    
    // ❌ ĐÃ XÓA: Toàn bộ sync aimbot
    // isBone            = ESPPrefsBool(KH_NS("Bone"),            NO);
    // isEspBot          = ESPPrefsBool(KH_NS("EspBot"),          NO);
    // isAimIgnoreBot    = ESPPrefsBool(KH_NS("AimIgnoreBot"),    NO);
    // isAimCheckVisible = ESPPrefsBool(KH_NS("AimCheckVisible"), NO);
    // isAimRage         = ESPPrefsBool(KH_NS("AimRage"),         NO);
    // isLineAim         = ESPPrefsBool(KH_NS("LineAim"),         YES);
    // _0x3872DA         = ESPPrefsBool(KH_NS("Aimbot"),          NO);
    // aimsilent1        = ESPPrefsBool(KH_NS("aimsilent"),       NO);
    // _0x92710          = ESPPrefsBool(KH_NS("aiplayer"),        NO);
    // _0x2872o          = ESPPrefsBool(KH_NS("AimHead"),         NO);
    // _0x2873           = ESPPrefsBool(KH_NS("AimSHead"),        NO);
    // _0x3872DB         = ESPPrefsBool(KH_NS("ShowFov"),         YES);
    // _0x83278          = ESPPrefsBool(KH_NS("AIPos"),           NO);
    // box               = (int)ESPPrefsFloat(KH_NS("box"), 0.0f);
    // triggerMode       = (int)ESPPrefsFloat(KH_NS("TriggerMode"), 3.0f);
    // _0x2874           = (int)ESPPrefsFloat(KH_NS("AimPos"), 0.0f);
    // aimTargetMode     = (int)ESPPrefsFloat(KH_NS("AimTargetMode"), 0.0f);
    // aimFov            = ESPPrefsFloat(KH_NS("Fov"), 150.0f);
    // aimDistance       = ESPPrefsFloat(KH_NS("Distance"), 150.0f);
    // aimSpeed          = ESPPrefsFloat(KH_NS("Speed"), 75.0f) / 100.0f;

    // ESP Count logic
    if (isLine) {
        isCount = YES;
    }
    else if (isBox) {
        isCount = YES;
    }
    else if (isHealth) {
        isCount = YES;
    }
    else {
        isCount = NO;
    }
}

// ============================================================
// ❌ ĐÃ XÓA: Aim lock state
// static uint64_t gAimLockTarget       = 0;
// static int      gAimLockLostFrames   = 0;
// static const int kAimLockMaxLostFrames = 10;
// ============================================================

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
static int      cacheRefreshTick = 0;

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
    ESPGeometryBuffers b;
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
    if ([str hasPrefix:@"[KH_STR("] || [str hasSuffix:@")]"]) {
        finalSize = 7.5f;
    } else {
        finalSize = 9.0f;
    }

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

// ============================================================
// ❌ ĐÃ XÓA: Global variables cho silent aim
// uint64_t _0xHIT2872 = 0;
// Vector3 g_TargetDir = {0, 0, 0};
// Vector3 g_TargetPos = {0,0,0};
// Vector3 g_HitLocation = {0,0,0};
// uint8_t g_SpecialHitType = 0;
// Vector3 g_HitNormal = {0,0,0};
// Vector3 g_StartPosition = {0,0,0};
// Vector3 g_StartPositionOrg = {0,0,0};
// bool g_IgnoreHappens;
// bool g_ViewBlocked;
// uint64_t g_HitGroup = 0;
// bool _0xD8A2T7A = false;
// std::atomic<float> _0x287SL28{ -1.0f };
// ============================================================

// ============================================================
// ❌ ĐÃ XÓA: Hàm silent aim thread
// void _0xASI2872D() { ... }
// ============================================================

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
    l.lineJoin        = kCALineJoinMiter;
    l.lineCap         = kCALineCapSquare;
    l.contentsScale   = UIScreen.mainScreen.scale;
    l.zPosition       = z;
    l.allowsEdgeAntialiasing = NO;
    l.actions = @{ KH_NS("path"): NSNull.null };
    return l;
}

- (void)configureRenderingLayers {
    UIColor *white  = UIColor.whiteColor;
    UIColor *clear  = UIColor.clearColor;
    UIColor *yellow = UIColor.yellowColor;

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
    self.hpBackgroundLayer = [self makeShapeLayer:nil     fill:clear   lineWidth:0    zPos:4];
    self.hpFillLayer       = [self makeShapeLayer:nil     fill:hpGreen lineWidth:0    zPos:5];

    for (CAShapeLayer *l in @[self.fovLayer, self.snaplineLayer, self.boneLayer, self.boxLayer,
                               self.hpBackgroundLayer, self.hpFillLayer,
                            self.boxBotLayer, self.boxPlayerLayer, self.lineBotLayer, self.linePlayerLayer, self.lineKnockLayer, self.boxKnockLayer]) {
        [self.layer addSublayer:l];
    }

    self.statusLayer = [CATextLayer layer];
    self.statusLayer.foregroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f].CGColor;
    self.statusLayer.alignmentMode   = kCAAlignmentCenter;
    self.statusLayer.fontSize        = 17.0f;
    self.statusLayer.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:17.0f weight:UIFontWeightHeavy];
    self.statusLayer.backgroundColor = [UIColor colorWithRed:0.05f green:0.05f blue:0.12f alpha:0.85f].CGColor;
    self.statusLayer.borderColor     = [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:0.9f].CGColor;
    self.statusLayer.borderWidth     = 1.5f;
    self.statusLayer.cornerRadius    = 16.0f;
    self.statusLayer.shadowColor     = [UIColor colorWithRed:1.0f green:0.5f blue:0.0f alpha:0.8f].CGColor;
    self.statusLayer.shadowOffset    = CGSizeZero;
    self.statusLayer.shadowOpacity   = 0.9f;
    self.statusLayer.shadowRadius    = 6.0f;
    self.statusLayer.contentsScale   = UIScreen.mainScreen.scale;
    self.statusLayer.zPosition       = 8;
    self.statusLayer.actions = @{ KH_NS("stringKH_STR("):NSNull.null, KH_NS(")frameKH_STR("):NSNull.null, @")hidden":NSNull.null };
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
        layer.actions = @{ KH_NS("positionKH_STR("):NSNull.null, KH_NS(")bounds"):NSNull.null,
                           KH_NS("stringKH_STR("):NSNull.null,   @")hidden":NSNull.null };
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

// ============================================================
// ✅ UPDATE FRAME - ĐÃ XÓA FOV CIRCLE (aimbot)
// ============================================================
- (void)updateFrame {
    if (!self.window) return;
    @autoreleasepool {
#ifdef NOTIFY_DESTROY_HUD
        if (GetGameProcesspid((char *)KH_STR("FreeFire")) == -1) {
            notify_post(NOTIFY_DESTROY_HUD);
            exit(0);
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

        ESPGeometryBuffersRelease(&buffers);

        // ❌ ĐÃ XÓA: FOV Circle rendering
        // CGMutablePathRef fovPath = CGPathCreateMutable();
        // BOOL hasFov = RenderFOVCirclePath(fovPath, vw, vh, _0x3872DB, aimFov);
        // self.fovLayer.path = hasFov ? fovPath : nil;
        // CGPathRelease(fovPath);
        
        self.fovLayer.path = nil;   // Ẩn FOV circle hoàn toàn

        // ESP Count hiển thị - Từ đầu dây xuống (Top-Center Player Counter Badge)
        if (isCount || isLine || isBox) {
            int totalEnemies = stats.playerCount + stats.botCount;

            UIFont *fontBasic = [UIFont systemFontOfSize:17.0f weight:UIFontWeightHeavy];
            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            attributes[NSFontAttributeName] = fontBasic;
            attributes[NSForegroundColorAttributeName] = (totalEnemies > 0) ? [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f] : [UIColor colorWithRed:0.8f green:0.8f blue:0.8f alpha:1.0f];

            NSString *countStr = [NSString stringWithFormat:@"🎯 PLAYERS NEARBY: %d", totalEnemies];
            NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:countStr attributes:attributes];
            self.statusLayer.string = attrStr;

            CGFloat bannerWidth = 210.0f;
            self.statusLayer.frame = CGRectMake(vw / 2.0f - (bannerWidth / 2.0f), 22.0f, bannerWidth, 32.0f);
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
    self.boxLayer.path = self.boneLayer.path = self.snaplineLayer.path = self.lineBotLayer.path = self.linePlayerLayer.path = self.boxBotLayer.path = self.boxPlayerLayer.path = nil;
    self.hpBackgroundLayer.path = self.hpFillLayer.path                 = nil;
    self.aimAssistLayer.path = self.alertLayer.path = nil;
    [self resetTextLayers];
}

- (void)dealloc {
    [_displayLink invalidate];
    _displayLink = nil;
}

// ============================================================
// ❌ ĐÃ XÓA: Toàn bộ hàm aimbot
// Quaternion GetRotationToLocation(...)
// Vector3 GetAimTargetPos(...)
// void _0x387228(...)
// ============================================================

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

// ============================================================
// ✅ MAIN ESP RENDER - CHỈ CÒN ESP LINE / BOX / HP / COUNT
// ============================================================
- (ESPFrameStats)renderESPWithBuffers:(ESPGeometryBuffers *)buffers
                            viewWidth:(CGFloat)vw viewHeight:(CGFloat)vh
                        matrixVpWidth:(CGFloat)vpW matrixVpHeight:(CGFloat)vpH {

    ESPFrameStats stats = {0, 0, false};
    if (!buffers || Moudule_Base == -1 || IsAtLobby(Moudule_Base)) return stats;

    cacheRefreshTick++;
    if (cacheRefreshTick > 30 ||
        !isVaildPtr(cachedMatchGame) || !isVaildPtr(cachedMatch) || !isVaildPtr(cachedCamera)) {
        cachedMatchGame = getMatchGame(Moudule_Base);
        if (!isVaildPtr(cachedMatchGame)) return stats;
        cachedCamera     = CameraMain(cachedMatchGame);
        cachedMatch      = getMatch(cachedMatchGame);
        cacheRefreshTick = 0;
    }
    if (!isVaildPtr(cachedCamera) || !isVaildPtr(cachedMatch)) return stats;

    uint64_t _0x2872P = getLocalPlayer(cachedMatch);
    if (!isVaildPtr(_0x2872P) || get_CurHP(_0x2872P) <= 0) return stats;

    stats.inMatch = true;

    uint64_t camTransform = ReadAddr<uint64_t>(_0x2872P + kMainCameraTransform);
    if (!isVaildPtr(camTransform)) return stats;
    Vector3 myLoc = getPositionExt(camTransform);

    uint64_t playerDict = ReadAddr<uint64_t>(cachedMatch + kMatchPlayerDict);
    if (!isVaildPtr(playerDict)) return stats;

    int      dictCount  = ReadAddr<int>(playerDict + kDictCount);
    uint64_t entriesArr = ReadAddr<uint64_t>(playerDict + kDictEntries);
    if (!isVaildPtr(entriesArr)) return stats;

    int slotCap = ReadAddr<int>(entriesArr + kIl2CppArrayMaxLength);
    if (slotCap <= 0 || slotCap > 256 || dictCount <= 0) return stats;

    float *matrix = GetViewMatrix(cachedCamera);
    if (!matrix) return stats;

    CGFloat screenVpW = vpW > 1.0 ? vpW : vw;
    CGFloat screenVpH = vpH > 1.0 ? vpH : vh;

    const uint64_t base = entriesArr + kIl2CppArrayItems;

    // ====================================================
    // LOOP QUA TẤT CẢ PLAYER - CHỈ VẼ ESP
    // ====================================================
    for (int i = 0; i < slotCap; i++) {
        uint64_t ent = base + (uint64_t)kDictEntryStrideBytePlayer * (uint64_t)i;
        if (ReadAddr<int>(ent) == 0) continue;

        uint64_t pawn = ReadAddr<uint64_t>(ent + (uint64_t)kDictEntryValueOffByte);
        if (!isVaildPtr(pawn) || isLocalTeamMate(_0x2872P, pawn)) continue;

        int hp = get_CurHP(pawn);
        if (hp <= 0) continue;

        Vector3 footPos = getPositionExt(getHip(pawn));
        if (IsZeroVec(footPos)) continue;

        float dis = Vector3::Distance(myLoc, footPos);
        if (dis > 150.0f) continue;

        bool isBot     = get_IsBot(pawn);
        bool isKnocked = get_IsKnockedDown(pawn);
        bool Visible   = getIsVisible(pawn);
        bool espVis    = Visible || isKnocked;

        // ❌ ĐÃ XÓA: Toàn bộ logic aimbot
        // - Tìm bestTarget
        // - Tính bestScore / bestDistance
        // - Silent aim write memory
        // - Aimbot rotation

        if (espVis) {
            if (isBot)
                stats.botCount++;
            else
                stats.playerCount++;

            // ✅ Vẽ ESP cho pawn này
            _0x35572DA(buffers,
                       ESPTextCallback,
                       (__bridge void *)self,
                       pawn, hp, dis, matrix,
                       (float)vw, (float)vh,
                       (float)screenVpW, (float)screenVpH);
        }
    }

    // ❌ ĐÃ XÓA: Toàn bộ logic sau loop
    // if(_0x2872o) {...}
    // if(_0x83278) {...}
    // if (!(_0x3872DA || aimsilent1)) {...}
    // if (aimsilent1 && bestTarget) {...}
    // if (_0x3872DA && bestTarget) {...}

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