//
//  RemoteWebViewOverlay.m
//  External-DarkSword
//
//  Created by Le Tien Dat on 8/25/26.
//

#import "RemoteWebViewOverlay.h"
#import "../../App/Configuration/Config.h"
#import "../../App/Configuration/Macros.h"
#import "OverlayWebSocketServer.h"
#import "../Diagnostics/MizzeStartupDiagnostics.h"
#include <math.h>

extern uint64_t remote_getClass(RemoteCall *process, const char *name);
extern uint64_t remote_sel(RemoteCall *process, const char *name);
extern uint64_t remote_msg(RemoteCall *process, uint64_t receiver,
                           uint64_t selector, uint64_t a0, uint64_t a1,
                           uint64_t a2, uint64_t a3);
extern uint64_t remote_NSString(RemoteCall *process, const char *str);
extern uint64_t remote_msg_on_main_thread(RemoteCall *proc, uint64_t target,
                                          uint64_t selector,
                                          const void *const *argData,
                                          const size_t *argSizes,
                                          size_t argCount);
extern CGRect remote_getCGRect(RemoteCall *proc, uint64_t obj, uint64_t sel);

static const CGFloat kOverlayFABSize = 45.0;
static const CGFloat kOverlayFABTrailingInset = 80.0;

static CGFloat OverlayClamp(CGFloat value, CGFloat lower, CGFloat upper) {
    return MIN(MAX(value, lower), upper);
}

#pragma mark - RemoteWebViewOverlay

@interface RemoteWebViewOverlay ()

@property(nonatomic, assign, readwrite) RemoteCall *remoteCall;
@property(nonatomic, assign, readwrite) RemoteObjectRef window;
@property(nonatomic, assign, readwrite) RemoteObjectRef parentView;
@property(nonatomic, assign, readwrite) RemoteObjectRef webView;
@property(nonatomic, assign) RemoteObjectRef menuWebView;
@property(nonatomic, assign) RemoteObjectRef floatButtonWebView;
@property(nonatomic, assign, readwrite) BOOL isOverlayReady;
@property(nonatomic, assign, readwrite) CGFloat cachedScreenWidth;
@property(nonatomic, assign, readwrite) CGFloat cachedScreenHeight;
@property(nonatomic, assign) BOOL menuVisible;
@property(nonatomic, assign) BOOL hasCustomFloatButtonPosition;
@property(nonatomic, assign) CGFloat floatButtonXRatio;
@property(nonatomic, assign) CGFloat floatButtonYRatio;
@property(nonatomic, assign) CGSize localScreenSize;
@property(nonatomic, copy, readwrite) NSString *setupError;

@end

@implementation RemoteWebViewOverlay

#pragma mark - Init

- (instancetype)initWithRemoteCall:(RemoteCall *)remoteCall {
    self = [super init];
    if (self) {
        _remoteCall = remoteCall;
        _gameIdentifier = @"aov";
        _localScreenSize = UIScreen.mainScreen.bounds.size;
        _setupError = @"";
        _window = 0;
        _parentView = 0;
        _webView = 0;
        _menuWebView = 0;
        _floatButtonWebView = 0;
        _isOverlayReady = NO;
        _cachedScreenWidth = 0;
        _cachedScreenHeight = 0;
        _menuVisible = NO;
        _hasCustomFloatButtonPosition = NO;
        _floatButtonXRatio = 0;
        _floatButtonYRatio = 0;
    }
    return self;
}

#pragma mark - Remote runtime helpers

- (RemoteObjectRef)getClass:(const char *)name {
    return remote_getClass(self.remoteCall, name);
}

- (uint64_t)getSelector:(const char *)name {
    return remote_sel(self.remoteCall, name);
}

- (RemoteObjectRef)call:(RemoteObjectRef)receiver
               selector:(const char *)selector {
    if (!receiver)
        return 0;
    uint64_t sel = [self getSelector:selector];
    if (!sel)
        return 0;
    return remote_msg(self.remoteCall, receiver, sel, 0, 0, 0, 0);
}

- (RemoteObjectRef)call:(RemoteObjectRef)receiver
               selector:(const char *)selector
               argument:(uint64_t)argument {
    if (!receiver)
        return 0;
    uint64_t sel = [self getSelector:selector];
    if (!sel)
        return 0;
    return remote_msg(self.remoteCall, receiver, sel, argument, 0, 0, 0);
}

#pragma mark - Find UIWindow

- (RemoteObjectRef)visibleWindowInArray:(RemoteObjectRef)windows {
    if (!windows) return 0;
    NSUInteger count = (NSUInteger)[self call:windows selector:"count"];
    if (count > 64) return 0;
    RemoteObjectRef fallback = 0;
    for (NSUInteger i = 0; i < count; i++) {
        RemoteObjectRef candidate = [self call:windows selector:"objectAtIndex:" argument:i];
        if (!candidate || [self call:candidate selector:"isHidden"]) continue;
        if ([self call:candidate selector:"isKeyWindow"]) return candidate;
        if (!fallback) fallback = candidate;
    }
    return fallback;
}

- (BOOL)findFreeFireWindow {
    RemoteObjectRef application = [self call:[self getClass:"UIApplication"] selector:"sharedApplication"];
    if (!application) return NO;
    // Unity can still host its window through the application delegate.
    RemoteObjectRef window = [self call:application selector:"keyWindow"];
    if (window && ![self call:window selector:"isHidden"]) { self.window = window; return YES; }
    RemoteObjectRef scenes = [self call:[self call:application selector:"connectedScenes"] selector:"allObjects"];
    NSUInteger count = (NSUInteger)[self call:scenes selector:"count"];
    if (count <= 64) for (NSUInteger i = 0; i < count; i++) {
        RemoteObjectRef scene = [self call:scenes selector:"objectAtIndex:" argument:i];
        if (![self call:scene selector:"respondsToSelector:" argument:[self getSelector:"windows"]]) continue;
        window = [self visibleWindowInArray:[self call:scene selector:"windows"]];
        if (window) { self.window = window; return YES; }
    }
    window = [self visibleWindowInArray:[self call:application selector:"windows"]];
    self.window = window;
    return window != 0;
}

- (BOOL)findTargetWindow {
    if ([self.gameIdentifier isEqualToString:@"freefire"]) return [self findFreeFireWindow];
    LOG(@"[RemoteWebViewOverlay] Finding target UIWindow...");

    RemoteObjectRef uiApplicationClass = [self getClass:"UIApplication"];
    if (!uiApplicationClass) {
        LOG(@"[RemoteWebViewOverlay] UIApplication class not found");
        return NO;
    }

    RemoteObjectRef application = [self call:uiApplicationClass
                                    selector:"sharedApplication"];
    if (!application) {
        LOG(@"[RemoteWebViewOverlay] UIApplication == NULL");
        return NO;
    }

    RemoteObjectRef connectedScenes = [self call:application
                                        selector:"connectedScenes"];
    if (!connectedScenes) {
        LOG(@"[RemoteWebViewOverlay] connectedScenes == NULL");
        return NO;
    }

    RemoteObjectRef scenes = [self call:connectedScenes selector:"allObjects"];
    if (!scenes) {
        LOG(@"[RemoteWebViewOverlay] scenes == NULL");
        return NO;
    }

    NSUInteger sceneCount = (NSUInteger)[self call:scenes selector:"count"];
    LOG(@"[RemoteWebViewOverlay] sceneCount = %lu", (unsigned long)sceneCount);

    uint64_t objectAtIndexSEL = [self getSelector:"objectAtIndex:"];
    if (!objectAtIndexSEL)
        return NO;

    for (NSUInteger i = 0; i < sceneCount; i++) {
        RemoteObjectRef scene =
            remote_msg(self.remoteCall, scenes, objectAtIndexSEL, i, 0, 0, 0);
        if (!scene)
            continue;

        RemoteObjectRef windows = [self call:scene selector:"windows"];
        if (!windows)
            continue;

        NSUInteger windowCount =
            (NSUInteger)[self call:windows selector:"count"];
        LOG(@"[RemoteWebViewOverlay] scene[%lu] windowCount = %lu",
            (unsigned long)i, (unsigned long)windowCount);

        for (NSUInteger j = 0; j < windowCount; j++) {
            RemoteObjectRef window = remote_msg(self.remoteCall, windows,
                                                objectAtIndexSEL, j, 0, 0, 0);
            if (!window)
                continue;

            RemoteObjectRef hidden = [self call:window selector:"isHidden"];
            LOG(@"[RemoteWebViewOverlay] window[%lu] = 0x%llx hidden=%llu",
                (unsigned long)j, window, hidden);

            if (hidden)
                continue;

            self.window = window;
            LOG(@"[RemoteWebViewOverlay] FOUND UIWindow = 0x%llx", window);
            return YES;
        }
    }

    LOG(@"[RemoteWebViewOverlay] No visible UIWindow found");
    return NO;
}

#pragma mark - Find parent view

- (BOOL)findParentView {
    if (!self.window) {
        LOG(@"[RemoteWebViewOverlay] window is NULL");
        return NO;
    }

    self.parentView = self.window;
    LOG(@"[RemoteWebViewOverlay] parentView = UIWindow 0x%llx", self.window);
    return YES;
}

#pragma mark - Load overlay HTML from bundle

- (NSString *)loadOverlayHTMLResource:(NSString *)resourceName {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:resourceName ofType:@"html"];
    if (!path) {
        LOG(@"[RemoteWebViewOverlay] %@.html not found in bundle!",
            resourceName);
        return nil;
    }

    NSString *html = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    if (html.length == 0) {
        LOG(@"[RemoteWebViewOverlay] %@.html is empty!", resourceName);
        return nil;
    }

    LOG(@"[RemoteWebViewOverlay] %@.html loaded from bundle (%lu bytes)",
        resourceName, (unsigned long)html.length);
    uint16_t port = [OverlayWebSocketServer sharedServer].port;
    html = [html stringByReplacingOccurrencesOfString:@"%%OVERLAY_WS_PORT%%"
                                           withString:@(port).stringValue];
    return [html stringByReplacingOccurrencesOfString:@"%%OVERLAY_GAME%%"
                                           withString:[self.gameIdentifier isEqualToString:@"freefire"] ? @"freefire" : @"aov"];
}

- (void)setView:(RemoteObjectRef)view
      boolValue:(BOOL)value
       selector:(const char *)selectorName {
    if (!view)
        return;

    uint64_t selector = [self getSelector:selectorName];
    if (!selector)
        return;

    const void *params[] = {&value};
    size_t sizes[] = {sizeof(value)};
    remote_msg_on_main_thread(self.remoteCall, view, selector, params, sizes,
                              1);
}

- (void)setFrame:(CGRect)frame forView:(RemoteObjectRef)view {
    if (!view)
        return;

    uint64_t selector = [self getSelector:"setFrame:"];
    if (!selector)
        return;

    const void *params[] = {&frame};
    size_t sizes[] = {sizeof(frame)};
    remote_msg_on_main_thread(self.remoteCall, view, selector, params, sizes,
                              1);
}

- (void)setAutoresizingForView:(RemoteObjectRef)view {
    if (!view)
        return;

    uint64_t selector = [self getSelector:"setAutoresizingMask:"];
    if (!selector)
        return;

    NSUInteger mask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    const void *params[] = {&mask};
    size_t sizes[] = {sizeof(mask)};
    remote_msg_on_main_thread(self.remoteCall, view, selector, params, sizes,
                              1);
}

- (void)makeWebViewTransparent:(RemoteObjectRef)view {
    RemoteObjectRef uiColorClass = [self getClass:"UIColor"];
    uint64_t clearSelector = [self getSelector:"clearColor"];
    if (uiColorClass && clearSelector) {
        RemoteObjectRef clearColor = remote_msg_on_main_thread(
            self.remoteCall, uiColorClass, clearSelector, NULL, NULL, 0);
        if (clearColor) {
            uint64_t backgroundSelector =
                [self getSelector:"setBackgroundColor:"];
            if (backgroundSelector) {
                const void *params[] = {&clearColor};
                size_t sizes[] = {sizeof(clearColor)};
                remote_msg_on_main_thread(self.remoteCall, view,
                                          backgroundSelector, params, sizes, 1);
            }
        }
    }
    [self setView:view boolValue:NO selector:"setOpaque:"];
}

- (void)releaseRemoteObject:(RemoteObjectRef)object {
    if (object) remote_msg_on_main_thread(self.remoteCall, object, [self getSelector:"release"], NULL, NULL, 0);
}

- (void)disposeRemoteWebView:(RemoteObjectRef)view {
    if (!view) return;
    remote_msg_on_main_thread(self.remoteCall, view, [self getSelector:"stopLoading"], NULL, NULL, 0);
    remote_msg_on_main_thread(self.remoteCall, view, [self getSelector:"removeFromSuperview"], NULL, NULL, 0);
    [self releaseRemoteObject:view];
}

- (RemoteObjectRef)createWebViewWithResource:(NSString *)resourceName
                                       frame:(CGRect)frame
                                 interactive:(BOOL)interactive
                                      hidden:(BOOL)hidden
                             autoresizesView:(BOOL)autoresizesView {
    NSString *html = [self loadOverlayHTMLResource:resourceName];
    if (!html || !isfinite(frame.size.width) || !isfinite(frame.size.height) ||
        frame.size.width < 1 || frame.size.height < 1 || frame.size.width > 8192 || frame.size.height > 8192)
        return 0;
    RemoteObjectRef configClass = [self getClass:"WKWebViewConfiguration"];
    RemoteObjectRef webViewClass = [self getClass:"WKWebView"];
    uint64_t initSelector = [self getSelector:"initWithFrame:configuration:"];
    uint64_t loadSelector = [self getSelector:"loadHTMLString:baseURL:"];
    uint64_t addSubviewSelector = [self getSelector:"addSubview:"];
    if (!configClass || !webViewClass || !initSelector || !loadSelector || !addSubviewSelector || !self.parentView) return 0;

    RemoteObjectRef config = remote_msg_on_main_thread(self.remoteCall, configClass, [self getSelector:"alloc"], NULL, NULL, 0);
    config = config ? remote_msg_on_main_thread(self.remoteCall, config, [self getSelector:"init"], NULL, NULL, 0) : 0;
    if (!config) return 0;
    RemoteObjectRef view = remote_msg_on_main_thread(self.remoteCall, webViewClass, [self getSelector:"alloc"], NULL, NULL, 0);
    if (!view) { [self releaseRemoteObject:config]; return 0; }
    const void *initParams[] = {&frame, &config};
    size_t initSizes[] = {sizeof(frame), sizeof(config)};
    view = remote_msg_on_main_thread(self.remoteCall, view, initSelector, initParams, initSizes, 2);
    [self releaseRemoteObject:config];
    if (!view) return 0;

    [self makeWebViewTransparent:view];
    [self setView:view boolValue:interactive selector:"setUserInteractionEnabled:"];
    [self setView:view boolValue:hidden selector:"setHidden:"];
    if (autoresizesView) [self setAutoresizingForView:view];
    RemoteObjectRef remoteHTML = remote_NSString(self.remoteCall, html.UTF8String);
    if (!remoteHTML) { [self disposeRemoteWebView:view]; return 0; }
    uint64_t nilBaseURL = 0;
    const void *loadParams[] = {&remoteHTML, &nilBaseURL};
    size_t loadSizes[] = {sizeof(remoteHTML), sizeof(nilBaseURL)};
    RemoteObjectRef navigation = remote_msg_on_main_thread(self.remoteCall, view, loadSelector, loadParams, loadSizes, 2);
    // remote_NSString returns a retained CFString; WebKit copies the HTML.
    [self releaseRemoteObject:remoteHTML];
    if (!navigation) { [self disposeRemoteWebView:view]; return 0; }
    const void *addParams[] = {&view};
    size_t addSizes[] = {sizeof(view)};
    remote_msg_on_main_thread(self.remoteCall, self.parentView, addSubviewSelector, addParams, addSizes, 1);
    if ([self call:view selector:"superview"] != self.parentView) { [self disposeRemoteWebView:view]; return 0; }
    return view;
}

- (BOOL)refreshWindowBounds {
    if ([self.gameIdentifier isEqualToString:@"freefire"]) {
        // FF is landscape. Avoid remote_getCGRect's private CAMetalDrawable
        // register-spill helper entirely, including orientation/viewport events.
        if (!isfinite(self.localScreenSize.width) || !isfinite(self.localScreenSize.height)) return NO;
        CGFloat width = MAX(self.localScreenSize.width, self.localScreenSize.height);
        CGFloat height = MIN(self.localScreenSize.width, self.localScreenSize.height);
        if (!isfinite(width) || !isfinite(height) || width < 1 || height < 1 || width > 8192 || height > 8192)
            return NO;
        self.cachedScreenWidth = width;
        self.cachedScreenHeight = height;
        return YES;
    }
    uint64_t selector = [self getSelector:"bounds"];
    if (!selector || !self.window)
        return NO;

    CGRect bounds = remote_getCGRect(self.remoteCall, self.window, selector);
    if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0)
        return NO;

    self.cachedScreenWidth = bounds.size.width;
    self.cachedScreenHeight = bounds.size.height;
    return YES;
}

- (CGRect)floatButtonFrame {
    CGFloat width = MAX(self.cachedScreenWidth, kOverlayFABSize);
    CGFloat height = MAX(self.cachedScreenHeight, kOverlayFABSize);
    CGFloat maxX = MAX(0.0, width - kOverlayFABSize);
    CGFloat maxY = MAX(0.0, height - kOverlayFABSize);
    CGFloat x = MAX(0.0, width - kOverlayFABTrailingInset - kOverlayFABSize);
    CGFloat y = maxY * 0.5;

    if (self.hasCustomFloatButtonPosition) {
        x = self.floatButtonXRatio * maxX;
        y = self.floatButtonYRatio * maxY;
    }

    return CGRectMake(OverlayClamp(x, 0.0, maxX), OverlayClamp(y, 0.0, maxY),
                      kOverlayFABSize, kOverlayFABSize);
}

- (void)broadcastOverlayLayout {
    if (!self.isOverlayReady)
        return;

    CGRect frame = [self floatButtonFrame];
    CGFloat centerX = (frame.origin.x + frame.size.width * 0.5) /
                      MAX(self.cachedScreenWidth, 1.0);
    CGFloat centerY = (frame.origin.y + frame.size.height * 0.5) /
                      MAX(self.cachedScreenHeight, 1.0);
    NSDictionary *layout = @{
        @"screenWidth" : @(self.cachedScreenWidth),
        @"screenHeight" : @(self.cachedScreenHeight),
        @"fabSize" : @(kOverlayFABSize),
        @"fabCenterX" : @(centerX),
        @"fabCenterY" : @(centerY),
        @"menuVisible" : @(self.menuVisible)
    };
    NSDictionary *payload = @{@"type" : @"overlayLayout", @"layout" : layout,
                              @"game" : self.gameIdentifier ?: @"aov"};
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:0
                                                     error:nil];
    if (data.length > 0)
        [[OverlayWebSocketServer sharedServer] broadcastTextData:data];
}

#pragma mark - Setup base overlay

- (void)tearDown {
    [self clearTargets];
    self.isOverlayReady = NO;
    self.menuVisible = NO;
    // These handles are only the three views created by this controller.
    // Release the alloc/init ownership after detaching; never touch host views.
    RemoteObjectRef views[] = {self.floatButtonWebView, self.menuWebView, self.webView};
    self.floatButtonWebView = self.menuWebView = self.webView = 0;
    for (NSUInteger i=0;i<3;i++) {
        if (!views[i]) continue;
        [self disposeRemoteWebView:views[i]];
    }
}

- (BOOL)setupFreeFireOverlay {
    self.setupError = @"";
    MizzeRecordStage(@"ff.overlay.begin", @"One bounded setup transaction");
    if (![self findTargetWindow] || ![self findParentView]) {
        self.setupError = @"Chưa tìm thấy cửa sổ Free Fire sẵn sàng.";
        return NO;
    }
    if (![self refreshWindowBounds]) {
        self.setupError = @"Kích thước màn hình chưa hợp lệ.";
        return NO;
    }
    if (![self getClass:"WKWebView"] || ![self getClass:"WKWebViewConfiguration"]) {
        self.setupError = @"Free Fire chưa có WebKit để tạo menu.";
        return NO;
    }
    if (![[OverlayWebSocketServer sharedServer] start]) {
        self.setupError = @"Không khởi tạo được kết nối menu.";
        return NO;
    }
    CGRect full = CGRectMake(0,0,self.cachedScreenWidth,self.cachedScreenHeight);
    MizzeRecordStage(@"ff.overlay.canvas", @"Creating one canvas WebView");
    self.webView = [self createWebViewWithResource:@"overlay_esp" frame:full interactive:NO hidden:NO autoresizesView:YES];
    if (self.webView) {
        MizzeRecordStage(@"ff.overlay.menu", @"Creating one hidden menu WebView");
        self.menuWebView = [self createWebViewWithResource:@"overlay_menu" frame:full interactive:YES hidden:YES autoresizesView:YES];
    }
    if (self.menuWebView) {
        MizzeRecordStage(@"ff.overlay.button", @"Creating floating button");
        self.floatButtonWebView = [self createWebViewWithResource:@"overlay_fab" frame:[self floatButtonFrame] interactive:YES hidden:NO autoresizesView:NO];
    }
    if (!self.webView || !self.menuWebView || !self.floatButtonWebView) {
        self.setupError = @"Tạo menu chưa hoàn tất. Đã dừng, không tự tạo lặp.";
        [self tearDown];
        MizzeRecordStage(@"ff.overlay.rollback", self.setupError);
        return NO;
    }
    self.isOverlayReady = YES;
    [self broadcastOverlayLayout];
    MizzeRecordStage(@"ff.overlay.ready", @"Canvas/menu/button created; device display still needs verification");
    return YES;
}

- (BOOL)setupBaseOverlay {
    if (self.isOverlayReady && self.webView) {
        return YES;
    }
    if ([self.gameIdentifier isEqualToString:@"freefire"]) {
        return [self setupFreeFireOverlay];
    }

    LOG(@"[RemoteWebViewOverlay] Setting up base overlay...");

    if (![self findTargetWindow]) {
        LOG(@"[RemoteWebViewOverlay] setupBaseOverlay: findTargetWindow "
            @"failed");
        return NO;
    }

    if (![self findParentView]) {
        LOG(@"[RemoteWebViewOverlay] setupBaseOverlay: findParentView failed");
        return NO;
    }

    if (![[OverlayWebSocketServer sharedServer] start]) {
        LOG(@"[RemoteWebViewOverlay] setupBaseOverlay: WebSocket start failed");
        return NO;
    }

    uint64_t boundsSEL = [self getSelector:"bounds"];
    if (boundsSEL && self.window) {
        CGRect gameBounds =
            remote_getCGRect(self.remoteCall, self.window, boundsSEL);
        self.cachedScreenWidth = gameBounds.size.width;
        self.cachedScreenHeight = gameBounds.size.height;
        LOG(@"[RemoteWebViewOverlay] Game UIWindow bounds: %.0fx%.0f",
            gameBounds.size.width, gameBounds.size.height);
    } else {
        self.cachedScreenWidth = kWidth;
        self.cachedScreenHeight = kHeight;
        LOG(@"[RemoteWebViewOverlay] Fallback UIScreen: %.0fx%.0f",
            self.cachedScreenWidth, self.cachedScreenHeight);
    }

    RemoteObjectRef wkConfigClass = [self getClass:"WKWebViewConfiguration"];
    if (!wkConfigClass) {
        LOG(@"[RemoteWebViewOverlay] WKWebViewConfiguration class not found");
        return NO;
    }

    RemoteObjectRef config = [self call:wkConfigClass selector:"alloc"];
    if (!config) {
        LOG(@"[RemoteWebViewOverlay] WKWebViewConfiguration alloc failed");
        return NO;
    }

    config = [self call:config selector:"init"];
    if (!config) {
        LOG(@"[RemoteWebViewOverlay] WKWebViewConfiguration init failed");
        return NO;
    }

    LOG(@"[RemoteWebViewOverlay] WKWebViewConfiguration = 0x%llx", config);

    RemoteObjectRef wkWebViewClass = [self getClass:"WKWebView"];
    if (!wkWebViewClass) {
        LOG(@"[RemoteWebViewOverlay] WKWebView class not found");
        return NO;
    }

    RemoteObjectRef webView = [self call:wkWebViewClass selector:"alloc"];
    if (!webView) {
        LOG(@"[RemoteWebViewOverlay] WKWebView alloc failed");
        return NO;
    }

    {
        CGRect frame =
            CGRectMake(0, 0, self.cachedScreenWidth, self.cachedScreenHeight);
        const void *params[] = {&frame, &config};
        size_t sizes[] = {sizeof(frame), sizeof(config)};
        webView = remote_msg_on_main_thread(
            self.remoteCall, webView,
            [self getSelector:"initWithFrame:configuration:"], params, sizes,
            2);
    }

    if (!webView) {
        LOG(@"[RemoteWebViewOverlay] WKWebView initWithFrame:configuration: "
            @"failed");
        return NO;
    }
    LOG(@"[RemoteWebViewOverlay] WKWebView created = 0x%llx", webView);

    {
        RemoteObjectRef uiColorClass = [self getClass:"UIColor"];
        uint64_t clearSEL = [self getSelector:"clearColor"];
        if (uiColorClass && clearSEL) {
            RemoteObjectRef clearColor = remote_msg_on_main_thread(
                self.remoteCall, uiColorClass, clearSEL, NULL, NULL, 0);
            if (clearColor) {
                uint64_t bgSEL = [self getSelector:"setBackgroundColor:"];
                if (bgSEL) {
                    const void *p[] = {&clearColor};
                    size_t s[] = {sizeof(clearColor)};
                    remote_msg_on_main_thread(self.remoteCall, webView, bgSEL,
                                              p, s, 1);
                }
            }
        }
    }

    {
        uint64_t sel = [self getSelector:"setUserInteractionEnabled:"];
        if (sel) {
            BOOL enabled = NO;
            const void *p[] = {&enabled};
            size_t s[] = {sizeof(enabled)};
            remote_msg_on_main_thread(self.remoteCall, webView, sel, p, s, 1);
        }
    }

    {
        uint64_t sel = [self getSelector:"setOpaque:"];
        if (sel) {
            BOOL opaque = NO;
            const void *p[] = {&opaque};
            size_t s[] = {sizeof(opaque)};
            remote_msg_on_main_thread(self.remoteCall, webView, sel, p, s, 1);
        }
    }

    [self setAutoresizingForView:webView];

    {
        uint64_t sel = [self getSelector:"setInspectable:"];
        if (sel) {
            BOOL inspectable = g_isDebug ? YES : NO;
            const void *p[] = {&inspectable};
            size_t s[] = {sizeof(inspectable)};
            remote_msg_on_main_thread(self.remoteCall, webView, sel, p, s, 1);
            LOG(@"[RemoteWebViewOverlay] WKWebView inspectable = %s",
                inspectable ? "YES" : "NO");
        }
    }

    {
        NSString *html = [self loadOverlayHTMLResource:@"overlay_esp"];
        if (!html) {
            LOG(@"[RemoteWebViewOverlay] Failed to load overlay_esp.html");
            return NO;
        }

        uint64_t remoteHTML =
            remote_NSString(self.remoteCall, [html UTF8String]);
        if (!remoteHTML) {
            LOG(@"[RemoteWebViewOverlay] remote_NSString failed for HTML");
            return NO;
        }

        uint64_t loadSEL = [self getSelector:"loadHTMLString:baseURL:"];
        if (loadSEL) {
            uint64_t nilBaseURL = 0;
            const void *p[] = {&remoteHTML, &nilBaseURL};
            size_t s[] = {sizeof(remoteHTML), sizeof(nilBaseURL)};
            remote_msg_on_main_thread(self.remoteCall, webView, loadSEL, p, s,
                                      2);
        }
    }

    {
        uint64_t addSubviewSEL = [self getSelector:"addSubview:"];
        if (addSubviewSEL) {
            const void *p[] = {&webView};
            size_t s[] = {sizeof(webView)};
            remote_msg_on_main_thread(self.remoteCall, self.parentView,
                                      addSubviewSEL, p, s, 1);
        }
    }

    CGRect fullScreenFrame =
        CGRectMake(0, 0, self.cachedScreenWidth, self.cachedScreenHeight);
    self.menuWebView = [self createWebViewWithResource:@"overlay_menu"
                                                 frame:fullScreenFrame
                                           interactive:YES
                                                hidden:YES
                                       autoresizesView:YES];
    if (!self.menuWebView) {
        LOG(@"[RemoteWebViewOverlay] Failed to create menu WebView");
        return NO;
    }

    self.floatButtonWebView =
        [self createWebViewWithResource:@"overlay_fab"
                                  frame:[self floatButtonFrame]
                            interactive:YES
                                 hidden:NO
                        autoresizesView:NO];
    if (!self.floatButtonWebView) {
        LOG(@"[RemoteWebViewOverlay] Failed to create float button WebView");
        return NO;
    }

    self.webView = webView;
    self.isOverlayReady = YES;

    [self broadcastOverlayLayout];

    LOG(@"[RemoteWebViewOverlay] Base overlay ready: esp=0x%llx menu=0x%llx "
        @"fab=0x%llx size=%.0fx%.0f",
        webView, self.menuWebView, self.floatButtonWebView,
        self.cachedScreenWidth, self.cachedScreenHeight);

    return YES;
}

#pragma mark - Overlay interaction and layout

- (void)setOverlayMenuVisible:(BOOL)visible {
    if (!self.isOverlayReady || !self.menuWebView)
        return;

    @synchronized(self) {
        [self setView:self.menuWebView
            boolValue:!visible
             selector:"setHidden:"];
        self.menuVisible = visible;
        [self broadcastOverlayLayout];
        LOG(@"[RemoteWebViewOverlay] Menu %@", visible ? @"shown" : @"hidden");
    }
}

- (void)toggleOverlayMenu {
    @synchronized(self) {
        [self setOverlayMenuVisible:!self.menuVisible];
    }
}

- (void)setOverlayFloatButtonPositionX:(CGFloat)xRatio y:(CGFloat)yRatio {
    if (!self.isOverlayReady || !self.floatButtonWebView)
        return;

    @synchronized(self) {
        [self refreshWindowBounds];

        CGFloat width = MAX(self.cachedScreenWidth, kOverlayFABSize);
        CGFloat height = MAX(self.cachedScreenHeight, kOverlayFABSize);
        CGFloat maxX = MAX(0.0, width - kOverlayFABSize);
        CGFloat maxY = MAX(0.0, height - kOverlayFABSize);
        CGFloat requestedCenterX = OverlayClamp(xRatio, 0.0, 1.0) * width;
        CGFloat requestedCenterY = OverlayClamp(yRatio, 0.0, 1.0) * height;
        CGFloat x =
            OverlayClamp(requestedCenterX - kOverlayFABSize * 0.5, 0.0, maxX);
        CGFloat y =
            OverlayClamp(requestedCenterY - kOverlayFABSize * 0.5, 0.0, maxY);

        self.hasCustomFloatButtonPosition = YES;
        self.floatButtonXRatio = maxX > 0.0 ? x / maxX : 0.0;
        self.floatButtonYRatio = maxY > 0.0 ? y / maxY : 0.0;
        [self setFrame:[self floatButtonFrame] forView:self.floatButtonWebView];
        [self broadcastOverlayLayout];
    }
}

- (void)refreshOverlayLayout {
    if (!self.isOverlayReady || !self.floatButtonWebView)
        return;

    @synchronized(self) {
        if (![self refreshWindowBounds])
            return;
        [self setFrame:[self floatButtonFrame] forView:self.floatButtonWebView];
        [self broadcastOverlayLayout];
    }
}

#pragma mark - Update overlay targets

- (BOOL)updateOverlayTargets:(NSArray<NSDictionary *> *)targets {
    if (!self.isOverlayReady || !self.webView) {
        return NO;
    }

    NSMutableArray<NSDictionary *> *jsonTargets =
        [NSMutableArray arrayWithCapacity:targets.count];

    for (NSUInteger i = 0; i < targets.count; i++) {
        NSDictionary *data = targets[i];

        NSMutableDictionary *target = [NSMutableDictionary dictionary];
        NSNumber *idVal = data[@"id"] ?: @0;
        target[@"id"] =
            [NSString stringWithFormat:@"0x%llx", idVal.unsignedLongLongValue];
        target[@"name"] = data[@"name"] ?: @"";
        target[@"sx"] = data[@"sx"] ?: @0;
        target[@"sy"] = data[@"sy"] ?: @0;
        target[@"headX"] = data[@"headX"] ?: @0;
        target[@"headY"] = data[@"headY"] ?: @0;
        target[@"footX"] = data[@"footX"] ?: @0;
        target[@"footY"] = data[@"footY"] ?: @0;
        target[@"distance"] = data[@"distance"] ?: @0;
        target[@"visible"] = data[@"visible"] ?: @NO;
        target[@"onScreen"] = data[@"onScreen"] ?: @NO;
        target[@"drawLine"] = data[@"drawLine"] ?: @NO;
        target[@"drawHealth"] = data[@"drawHealth"] ?: @NO;
        target[@"drawName"] = data[@"drawName"] ?: @NO;
        target[@"drawDistance"] = data[@"drawDistance"] ?: @YES;
        target[@"hp"] = data[@"hp"] ?: @0;
        target[@"maxHp"] = data[@"maxHp"] ?: @0;

        BOOL hasBox = [data[@"hasBox"] boolValue];
        CGFloat boxW = [data[@"boxW"] doubleValue];
        CGFloat boxH = [data[@"boxH"] doubleValue];
        if (hasBox && boxW > 0.0 && boxH > 0.0) {
            target[@"box"] = @{
                @"x" : data[@"boxX"] ?: @0,
                @"y" : data[@"boxY"] ?: @0,
                @"w" : data[@"boxW"] ?: @0,
                @"h" : data[@"boxH"] ?: @0
            };
        }

        [jsonTargets addObject:target];
    }

    NSError *jsonError = nil;
    NSDictionary *payload = @{@"type" : @"targets", @"targets" : jsonTargets,
                              @"game" : self.gameIdentifier ?: @"aov"};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:&jsonError];
    if (!jsonData) {
        LOG(@"[RemoteWebViewOverlay] JSON serialization failed: %@",
            jsonError.localizedDescription ?: @"unknown error");
        return NO;
    }

    NSString *json = [[NSString alloc] initWithData:jsonData
                                           encoding:NSUTF8StringEncoding];
    if (json.length == 0) {
        LOG(@"[RemoteWebViewOverlay] JSON string is empty");
        return NO;
    }

    static NSUInteger updateLogCounter = 0;
    if (g_isDebug && (updateLogCounter++ % 60 == 0)) {
        LOG(@"[RemoteWebViewOverlay] WS update (%lu entities, %lu bytes, "
            @"%lu clients)",
            (unsigned long)targets.count, (unsigned long)jsonData.length,
            (unsigned long)[OverlayWebSocketServer sharedServer].clientCount);
    }

    [[OverlayWebSocketServer sharedServer] broadcastTextData:jsonData];
    return YES;
}

#pragma mark - Clear targets

- (BOOL)clearTargets {
    if (!self.isOverlayReady || !self.webView)
        return NO;

    if ([self.gameIdentifier isEqualToString:@"freefire"]) return [self updateOverlayTargets:@[]];
    [[OverlayWebSocketServer sharedServer] broadcastText:@"[]"];
    LOG(@"[RemoteWebViewOverlay] Targets cleared");
    return YES;
}

@end
