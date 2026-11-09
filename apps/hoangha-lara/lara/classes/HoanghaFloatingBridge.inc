// Two bounded windows: a 58-point bubble and a compact panel. No full-screen
// overlay or modal/key window is used. Events outside their bounds remain with
// the underlying windows. UIKit event actions only update three shared bytes.
enum { HHMaxBoxes = 32, HHMaxMarks = HHMaxBoxes * 72 };

typedef struct {
    uint64_t invocation, scratch, length;
} HHFastCall;

static struct {
    uint64_t app, scene, roots, bubble, menu, pan, flags, espSwitch, statusLabel, canvas, shape, rectangles;
    uint64_t orientationObserver;
    NSInteger orientation;
    CGSize fixedScreen;
    BOOL espEnabled, canvasVisible, lineEnabled, countEnabled, previousLine;
    uint64_t countLabel;
    NSUInteger badgeCount;
    HHFastCall lineState, countState;
    CGRect previousRectangles[HHMaxMarks];NSUInteger previousCount;
    uint64_t perform, invoke, setArgument, getReturn;
    HHFastCall panState, translation, move, menuHidden, espState, bubbleBounds, menuBounds, canvasPath;
    CGSize screen;
    CGPoint position, dragBase;
    BOOL dragging, menuVisible, active;
    CFAbsoluteTime lastMetrics;
} HHFloating;

static const char *HHBubbleKey = "hoanghaFloatingBubble_v14";
static const char *HHMenuKey = "hoanghaFloatingMenu_v14";
static const char *HHRootsKey = "hoanghaFloatingRoots_v14";
static const char *HHCanvasKey = "hoanghaESPBoxCanvas_v15";

static void HHAssociate(RemoteCall *s, const char *key, uint64_t value) {
    RemoteArbCall(s, objc_setAssociatedObject, HHFloating.app, remote_sel(s, key),
                  value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void HHKeep(RemoteCall *s, uint64_t object) {
    if (object) HHSend(s, HHFloating.roots, "addObject:", object, 0);
}

static void HHRemoveOld(RemoteCall *s, const char *key) {
    uint64_t object = HHExistingWindow(s, HHFloating.app, remote_sel(s, key));
    if (object) HHSend(s, object, "setHidden:", 1, 0);
    HHAssociate(s, key, 0);
}

static HHFastCall HHPrepareCall(RemoteCall *s, uint64_t target, const char *name,
                                const void *argument, size_t bytes) {
    HHFastCall call = {0};
    uint64_t selector = remote_sel(s, name);
    uint64_t signature = HHRawSend(s, target, "methodSignatureForSelector:", selector, 0);
    if (!signature) return call;
    call.length = HHRawSend(s, signature, "methodReturnLength", 0, 0);
    if (call.length > 64 || bytes > 64) return (HHFastCall){0};
    call.invocation = HHRawSend(s, remote_getClass(s, "NSInvocation"),
                                "invocationWithMethodSignature:", signature, 0);
    if (!call.invocation) return (HHFastCall){0};
    HHRawSend(s, call.invocation, "setTarget:", target, 0);
    HHRawSend(s, call.invocation, "setSelector:", selector, 0);
    call.scratch = RemoteArbCall(s, calloc, 1, 128);
    if (!call.scratch) return (HHFastCall){0};
    if (bytes) {
        if (![s remote_write:call.scratch + 64 from:argument size:bytes]) return (HHFastCall){0};
        remote_msg(s, call.invocation, HHFloating.setArgument, call.scratch + 64, 2, 0, 0);
    }
    HHRawSend(s, call.invocation, "retainArguments", 0, 0);
    HHKeep(s, call.invocation);
    return call;
}

static BOOL HHRunCall(RemoteCall *s, HHFastCall call, void *result) {
    if (!call.invocation || s.lastError.length) return NO;
    remote_msg(s, call.invocation, HHFloating.perform, HHFloating.invoke, 0, 1, 0);
    if (s.lastError.length) return NO;
    if (call.length) {
        remote_msg(s, call.invocation, HHFloating.getReturn, call.scratch, 0, 0, 0);
        return !s.lastError.length && [s remoteRead:call.scratch to:result size:call.length];
    }
    return YES;
}

static BOOL HHMenuHidden(RemoteCall *s,BOOL hidden){
    if(![s remote_write:HHFloating.menuHidden.scratch+64 from:&hidden size:sizeof(hidden)])return NO;
    remote_msg(s,HHFloating.menuHidden.invocation,HHFloating.setArgument,HHFloating.menuHidden.scratch+64,2,0,0);
    return HHRunCall(s,HHFloating.menuHidden,NULL);
}
static BOOL HHCachedBounds(RemoteCall *s,HHFastCall call,CGSize expected){
    CGRect bounds=CGRectZero;if(!HHRunCall(s,call,&bounds))return NO;
    return isfinite(bounds.size.width)&&isfinite(bounds.size.height)&&fabs(bounds.size.width-expected.width)<2&&fabs(bounds.size.height-expected.height)<2;
}

static CGPoint HHPhysicalPoint(CGPoint logical) {
    HHPoint p=hh_overlay_point((HHPoint){logical.x,logical.y},(HHSize){HHFloating.fixedScreen.width,HHFloating.fixedScreen.height},(int)HHFloating.orientation);
    return CGPointMake(p.x,p.y);
}
static void HHPlaceWindow(RemoteCall *s,uint64_t window,CGRect logical) {
    CGRect bounds=(CGRect){CGPointZero,logical.size};CGPoint center=HHPhysicalPoint(CGPointMake(CGRectGetMidX(logical),CGRectGetMidY(logical)));
    CGAffineTransform transform=CGAffineTransformMakeRotation(hh_overlay_angle((int)HHFloating.orientation));
    HHInvoke(s,window,"setBounds:",&bounds,sizeof(bounds),NULL,0,NULL,0);
    HHInvoke(s,window,"setCenter:",&center,sizeof(center),NULL,0,NULL,0);
    HHInvoke(s,window,"setTransform:",&transform,sizeof(transform),NULL,0,NULL,0);
}
static BOOL HHMoveBubble(RemoteCall *s, CGPoint position) {
    position.x = MIN(MAX(4, position.x), MAX(4, HHFloating.screen.width - 62));
    position.y = MIN(MAX(4, position.y), MAX(4, HHFloating.screen.height - 62));
    CGPoint center=HHPhysicalPoint(CGPointMake(position.x+29,position.y+29));
    if (![s remote_write:HHFloating.move.scratch + 64 from:&center size:sizeof(center)]) return NO;
    remote_msg(s, HHFloating.move.invocation, HHFloating.setArgument,
               HHFloating.move.scratch + 64, 2, 0, 0);
    if (!HHRunCall(s, HHFloating.move, NULL)) return NO;
    HHFloating.position = position;
    return YES;
}

static BOOL HHSmallWindowIsBounded(RemoteCall *s, uint64_t window, CGSize expected) {
    CGRect frame = HHGetRect(s, window, "bounds");
    BOOL okay = isfinite(frame.size.width) && isfinite(frame.size.height) &&
                fabs(frame.size.width - expected.width) < 2 &&
                fabs(frame.size.height - expected.height) < 2;
    if (!okay) {
        HHSend(s, window, "setHidden:", 1, 0);
        HHError(@"Cửa sổ nổi bị hệ thống mở rộng; đã ẩn để không chặn cảm ứng.");
    }
    return okay;
}

static uint64_t HHCreateSmallWindow(RemoteCall *s, CGRect frame, uint64_t *content) {
    uint64_t window = HHSend(s, remote_getClass(s, "UIWindow"), "alloc", 0, 0);
    window = HHSend(s, window, "initWithWindowScene:", HHFloating.scene, 0);
    uint64_t controller = HHSend(s, remote_getClass(s, "UIViewController"), "new", 0, 0);
    if (!window || !controller) return 0;
    HHSend(s, window, "setRootViewController:", controller, 0);
    HHSend(s, window, "setUserInteractionEnabled:", 1, 0);
    HHSetNumber(s, window, "windowLevel", 3001);
    HHSetRect(s, window, frame);
    *content = HHSend(s, controller, "view", 0, 0);
    HHSetRect(s, *content, (CGRect){CGPointZero, frame.size});
    uint64_t clear = HHSend(s, remote_getClass(s, "UIColor"), "clearColor", 0, 0);
    HHSend(s, window, "setBackgroundColor:", clear, 0);
    HHSend(s, *content, "setBackgroundColor:", clear, 0);
    HHKeep(s, window);
    HHSend(s, controller, "release", 0, 0);
    HHSend(s, window, "release", 0, 0);
    return HHSmallWindowIsBounded(s, window, frame.size) ? window : 0;
}

static uint64_t HHEventAction(RemoteCall *s, uint64_t data, NSUInteger index) {
    uint64_t signature = HHRawSend(s, data, "methodSignatureForSelector:",
                                   remote_sel(s, "resetBytesInRange:"), 0);
    if (!signature) return 0;
    uint64_t action = HHRawSend(s, remote_getClass(s, "NSInvocation"),
                                "invocationWithMethodSignature:", signature, 0);
    uint64_t scratch = RemoteArbCall(s, malloc, sizeof(NSRange));
    if (!signature || !action || !scratch) return 0;
    NSRange range = NSMakeRange(index, 1);
    BOOL written = [s remote_write:scratch from:&range size:sizeof(range)];
    HHRawSend(s, action, "setTarget:", data, 0);
    HHRawSend(s, action, "setSelector:", remote_sel(s, "resetBytesInRange:"), 0);
    if (written) HHRawSend(s, action, "setArgument:atIndex:", scratch, 2);
    HHRawSend(s, action, "retainArguments", 0, 0);
    if (!s.lastError.length) RemoteArbCall(s, free, scratch);
    HHKeep(s, action);
    return written ? action : 0;
}

static BOOL HHControlAction(RemoteCall *s, uint64_t button, uint64_t action, uint64_t event) {
    if (!button || !action) return NO;
    // UIKit calls NSInvocation.invoke in its own process when the control fires.
    uint64_t selector = remote_sel(s, "addTarget:action:forControlEvents:");
    uint64_t signature = HHRawSend(s, button, "methodSignatureForSelector:", selector, 0);
    if (!signature) return NO;
    uint64_t invocation = HHRawSend(s, remote_getClass(s, "NSInvocation"),
        "invocationWithMethodSignature:", signature, 0);
    uint64_t scratch = RemoteArbCall(s, malloc, 24);
    uint64_t args[3] = {action, HHFloating.invoke, event};
    if (!invocation || !scratch || ![s remote_write:scratch from:args size:sizeof(args)]) return NO;
    HHRawSend(s, invocation, "setTarget:", button, 0);
    HHRawSend(s, invocation, "setSelector:", selector, 0);
    for (NSUInteger i = 0; i < 3; i++) HHRawSend(s, invocation, "setArgument:atIndex:", scratch + i * 8, i + 2);
    HHRawSend(s, invocation, "retainArguments", 0, 0);
    remote_msg(s, invocation, HHFloating.perform, HHFloating.invoke, 0, 1, 0);
    if (!s.lastError.length) RemoteArbCall(s, free, scratch);
    return !s.lastError.length;
}

static BOOL HHButtonAction(RemoteCall *s,uint64_t button,uint64_t action){return HHControlAction(s,button,action,UIControlEventTouchUpInside);}
static uint64_t HHLogo(RemoteCall *s, NSData *logo) {
    uint64_t buffer = RemoteArbCall(s, malloc, logo.length);
    if (!buffer || ![s remote_write:buffer from:logo.bytes size:logo.length]) return 0;
    uint64_t data = HHSend(s, remote_getClass(s, "NSData"), "alloc", 0, 0);
    data = HHSend(s, data, "initWithBytes:length:", buffer, logo.length);
    if (!s.lastError.length) RemoteArbCall(s, free, buffer);
    uint64_t image = HHSend(s, remote_getClass(s, "UIImage"), "alloc", 0, 0);
    image = HHSend(s, image, "initWithData:", data, 0);
    HHSend(s, data, "release", 0, 0);
    return image;
}

bool hoangha_floating_start(RemoteCall *s, NSData *logo) {
    HHError(@"");
    if (!s || !logo.length) { HHError(@"Thiếu ảnh logo."); return false; }
    memset(&HHFloating, 0, sizeof(HHFloating));
    if (!hoangha_overlay_hide(s)) return false; // Remove v1.3's full-screen text window.
    HHFloating.app = HHApplication(s);
    HHFloating.scene = HHWindowScene(s, HHFloating.app);
    if (!HHFloating.app || !HHFloating.scene) return false;
    HHRemoveOld(s, HHBubbleKey); HHRemoveOld(s, HHMenuKey);HHRemoveOld(s,HHCanvasKey); HHAssociate(s, HHRootsKey, 0);
    HHFloating.roots = HHSend(s, remote_getClass(s, "NSMutableArray"), "new", 0, 0);
    HHAssociate(s, HHRootsKey, HHFloating.roots);
    HHSend(s, HHFloating.roots, "release", 0, 0);
    HHFloating.perform = remote_sel(s, "performSelectorOnMainThread:withObject:waitUntilDone:");
    HHFloating.invoke = remote_sel(s, "invoke");
    HHFloating.setArgument = remote_sel(s, "setArgument:atIndex:");
    HHFloating.getReturn = remote_sel(s, "getReturnValue:");
    uint64_t screen = HHSend(s, remote_getClass(s, "UIScreen"), "mainScreen", 0, 0);
    uint64_t fixed=HHSend(s,screen,"fixedCoordinateSpace",0,0);
    HHFloating.fixedScreen=HHGetRect(s,fixed?:screen,"bounds").size;
    HHFloating.screen=HHFloating.fixedScreen;HHFloating.orientation=1;
    if (HHFloating.screen.width < 100 || HHFloating.screen.height < 100) return false;
    HHFloating.position = CGPointMake(12, HHFloating.screen.height * 0.35);
    uint64_t content = 0;
    HHFloating.bubble = HHCreateSmallWindow(s, (CGRect){HHFloating.position, {58, 58}}, &content);
    if (!HHFloating.bubble) return false;
    HHAssociate(s, HHBubbleKey, HHFloating.bubble);
    uint64_t button = HHSend(s, remote_getClass(s, "UIButton"), "new", 0, 0);
    HHSetRect(s, button, CGRectMake(0, 0, 58, 58));
    uint64_t image = HHLogo(s, logo);
    if (!button || !image) return false;
    uint64_t imageView = HHSend(s, remote_getClass(s, "UIImageView"), "new", 0, 0);
    HHSetRect(s, imageView, CGRectMake(0,0,58,58));
    HHSend(s, imageView, "setImage:", image, 0);
    HHSend(s, imageView, "setUserInteractionEnabled:", 0, 0);
    HHSend(s, imageView, "setContentMode:", UIViewContentModeScaleAspectFill, 0);
    HHSend(s, button, "addSubview:", imageView, 0);
    HHSend(s, imageView, "release", 0, 0);
    HHSend(s, image, "release", 0, 0);
    HHSend(s, button, "setClipsToBounds:", 1, 0);
    HHSetNumber(s, HHSend(s, button, "layer", 0, 0), "cornerRadius", 29);
    HHSend(s, content, "addSubview:", button, 0);
    HHSend(s, button, "setAccessibilityLabel:", remote_NSString(s, "Mizze — mở menu"), 0);

    uint64_t data = HHSend(s, remote_getClass(s, "NSMutableData"), "alloc", 0, 0);
    data = HHSend(s, data, "initWithLength:", 6, 0);
    HHKeep(s, data);
    HHFloating.flags = HHSend(s, data, "mutableBytes", 0, 0);
    const uint8_t clear[6] = {1, 1, 1, 1, 1, 1};
    if (!HHFloating.flags || ![s remote_write:HHFloating.flags from:clear size:sizeof(clear)]) return false;
    uint64_t tap = HHEventAction(s, data, 0), close = HHEventAction(s, data, 1), drag = HHEventAction(s, data, 2), esp=HHEventAction(s,data,3);
    if (!HHButtonAction(s, button, tap)) return false;
    HHFloating.pan = HHSend(s, remote_getClass(s, "UIPanGestureRecognizer"), "alloc", 0, 0);
    HHFloating.pan = HHSend(s, HHFloating.pan, "initWithTarget:action:", drag, HHFloating.invoke);
    HHSend(s, HHFloating.pan, "setCancelsTouchesInView:", 1, 0);
    HHSend(s, button, "addGestureRecognizer:", HHFloating.pan, 0);
    HHSend(s, HHFloating.pan, "release", 0, 0);
    HHSend(s, button, "release", 0, 0);

    CGSize panel = CGSizeMake(MIN(280, HHFloating.screen.width - 24), 230);
    CGRect panelFrame = CGRectMake((HHFloating.screen.width-panel.width)/2,
                                   (HHFloating.screen.height-panel.height)/2, panel.width, panel.height);
    uint64_t panelRoot = 0;
    HHFloating.menu = HHCreateSmallWindow(s, panelFrame, &panelRoot);
    if (!HHFloating.menu) return false;
    HHAssociate(s, HHMenuKey, HHFloating.menu);
    uint64_t colors = remote_getClass(s, "UIColor");
    HHSend(s, panelRoot, "setBackgroundColor:", HHSend(s, colors, "secondarySystemBackgroundColor", 0, 0), 0);
    HHSetNumber(s, HHSend(s, panelRoot, "layer", 0, 0), "cornerRadius", 18);
    HHSend(s, panelRoot, "setClipsToBounds:", 1, 0);
    uint64_t title = HHSend(s, remote_getClass(s, "UILabel"), "new", 0, 0);
    HHSetRect(s, title, CGRectMake(18, 15, panel.width-76, 28));
    HHSend(s, title, "setText:", remote_NSString(s, "MIZZE  /  ESP"), 0);
    HHSend(s, title, "setFont:", HHFont(s, 20), 0);
    HHSend(s, title, "setTextColor:", HHSend(s, colors, "labelColor", 0, 0), 0);
    HHSend(s, panelRoot, "addSubview:", title, 0); HHSend(s, title, "release", 0, 0);
    uint64_t text=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
    HHSetRect(s,text,CGRectMake(18,64,panel.width-102,32));
    HHSend(s,text,"setText:",remote_NSString(s,"ESP Box"),0);HHSend(s,text,"setFont:",HHFont(s,18),0);
    HHSend(s,text,"setTextColor:",HHSend(s,colors,"labelColor",0,0),0);
    HHSend(s,panelRoot,"addSubview:",text,0);HHSend(s,text,"release",0,0);
    HHFloating.espSwitch=HHSend(s,remote_getClass(s,"UISwitch"),"new",0,0);
    HHSetRect(s,HHFloating.espSwitch,CGRectMake(panel.width-72,64,51,31));
    HHSend(s,HHFloating.espSwitch,"setOn:animated:",0,0);
    HHSend(s,HHFloating.espSwitch,"setAccessibilityLabel:",remote_NSString(s,"ESP Box"),0);
    HHSend(s,panelRoot,"addSubview:",HHFloating.espSwitch,0);
    if(!HHControlAction(s,HHFloating.espSwitch,esp,UIControlEventValueChanged))return false;
    HHSend(s,HHFloating.espSwitch,"release",0,0);
    const char *options[]={"Đường nối","Số địch"};
    HHFastCall *states[]={&HHFloating.lineState,&HHFloating.countState};
    for (NSUInteger i=0;i<2;i++) {
        CGFloat y=108+42*i;
        uint64_t label=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
        uint64_t toggle=HHSend(s,remote_getClass(s,"UISwitch"),"new",0,0);
        uint64_t name=remote_NSString(s,options[i]);
        HHSetRect(s,label,CGRectMake(18,y,panel.width-102,31));
        HHSetRect(s,toggle,CGRectMake(panel.width-72,y,51,31));
        HHSend(s,label,"setText:",name,0);
        HHSend(s,label,"setFont:",HHFont(s,16),0);
        HHSend(s,toggle,"setAccessibilityLabel:",name,0);
        HHSend(s,panelRoot,"addSubview:",label,0);
        HHSend(s,panelRoot,"addSubview:",toggle,0);
        HHSend(s,label,"release",0,0);
        if(!HHControlAction(s,toggle,HHEventAction(s,data,4+i),UIControlEventValueChanged))return false;
        *states[i]=HHPrepareCall(s,toggle,"isOn",NULL,0);
        HHSend(s,toggle,"release",0,0);
        if(!states[i]->invocation)return false;
    }
    HHFloating.statusLabel=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
    HHSetRect(s,HHFloating.statusLabel,CGRectMake(18,187,panel.width-36,32));
    HHSend(s,HHFloating.statusLabel,"setText:",remote_NSString(s,"ESP Box đang tắt"),0);
    HHSend(s,HHFloating.statusLabel,"setNumberOfLines:",3,0);HHSend(s,HHFloating.statusLabel,"setFont:",HHFont(s,12),0);
    HHSend(s,HHFloating.statusLabel,"setTextColor:",HHSend(s,colors,"secondaryLabelColor",0,0),0);
    HHSend(s,panelRoot,"addSubview:",HHFloating.statusLabel,0);HHSend(s,HHFloating.statusLabel,"release",0,0);
    uint64_t closeButton = HHSend(s, remote_getClass(s, "UIButton"), "new", 0, 0);
    HHSetRect(s, closeButton, CGRectMake(panel.width-52, 8, 44, 44));
    HHSend(s, closeButton, "setTitle:forState:", remote_NSString(s, "×"), 0);
    HHSend(s, closeButton, "setTitleColor:forState:", HHSend(s, colors, "labelColor", 0, 0), 0);
    HHSend(s, closeButton, "setAccessibilityLabel:", remote_NSString(s, "Đóng menu"), 0);
    HHSend(s, panelRoot, "addSubview:", closeButton, 0);
    if (!HHButtonAction(s, closeButton, close)) return false;
    HHSend(s, closeButton, "release", 0, 0);
    HHSend(s, data, "release", 0, 0);

    uint64_t nilView = HHFloating.bubble;
    HHFloating.panState = HHPrepareCall(s, HHFloating.pan, "state", NULL, 0);
    HHFloating.translation = HHPrepareCall(s, HHFloating.pan, "translationInView:", &nilView, sizeof(nilView));
    CGPoint bubbleCenter = CGPointMake(HHFloating.position.x+29,HHFloating.position.y+29);
    HHFloating.move = HHPrepareCall(s, HHFloating.bubble, "setCenter:", &bubbleCenter, sizeof(bubbleCenter));
    BOOL hidden=YES;
    HHFloating.menuHidden=HHPrepareCall(s,HHFloating.menu,"setHidden:",&hidden,sizeof(hidden));
    HHFloating.espState=HHPrepareCall(s,HHFloating.espSwitch,"isOn",NULL,0);
    HHFloating.bubbleBounds=HHPrepareCall(s,HHFloating.bubble,"bounds",NULL,0);
    HHFloating.menuBounds=HHPrepareCall(s,HHFloating.menu,"bounds",NULL,0);
    if (!HHFloating.panState.invocation || !HHFloating.translation.invocation || !HHFloating.move.invocation||!HHFloating.menuHidden.invocation||!HHFloating.espState.invocation||!HHFloating.bubbleBounds.invocation||!HHFloating.menuBounds.invocation) return false;
    HHSend(s, HHFloating.menu, "setHidden:", 1, 0);
    HHSend(s, HHFloating.bubble, "setHidden:", 0, 0);
    HHFloating.active = !s.lastError.length && HHSmallWindowIsBounded(s, HHFloating.bubble, CGSizeMake(58,58));
    return HHFloating.active;
}

bool hoangha_floating_tick(RemoteCall *s) {
    if (!HHFloating.active || s.lastError.length) return false;
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if (now-HHFloating.lastMetrics>5.0) {
        HHFloating.lastMetrics=now;
        if (!HHCachedBounds(s,HHFloating.bubbleBounds,CGSizeMake(58,58))) {HHSend(s,HHFloating.bubble,"setHidden:",1,0);return false;}

    }
    uint8_t flags[6];
    if (![s remoteRead:HHFloating.flags to:flags size:sizeof(flags)]) return false;
    for (NSUInteger i=0;i<sizeof(flags);i++) if (flags[i]==0) {
        uint8_t clear=1;
        if (![s remote_write:HHFloating.flags+i from:&clear size:1]) return false;
    }
    if(flags[3]==0){BOOL enabled=NO;if(!HHRunCall(s,HHFloating.espState,&enabled))return false;HHFloating.espEnabled=enabled;}
    if(flags[4]==0&&!HHRunCall(s,HHFloating.lineState,&HHFloating.lineEnabled))return false;
    if(flags[5]==0&&!HHRunCall(s,HHFloating.countState,&HHFloating.countEnabled))return false;
    if (flags[0]==0) {
        HHFloating.menuVisible = !HHFloating.menuVisible;
        if (HHFloating.menuVisible) hoangha_foreground_game(s, NULL);
        if(!HHMenuHidden(s,!HHFloating.menuVisible))return false;
        if (HHFloating.menuVisible && !HHCachedBounds(s, HHFloating.menuBounds,
            CGSizeMake(MIN(280,HHFloating.screen.width-24),230))) {HHMenuHidden(s,YES);return false;}
    }
    if (flags[1]==0) {
        HHFloating.menuVisible=NO;
        if(!HHMenuHidden(s,YES))return false;
    }
    if (flags[2]==0 || HHFloating.dragging) {
        uint64_t state=0; CGPoint translation=CGPointZero;
        if (!HHRunCall(s, HHFloating.panState, &state)) return false;
        if (state==UIGestureRecognizerStateBegan || state==UIGestureRecognizerStateChanged || state==UIGestureRecognizerStateEnded) {
            if (!HHFloating.dragging) HHFloating.dragBase=HHFloating.position;
            HHFloating.dragging=YES;
            if (!HHRunCall(s, HHFloating.translation, &translation)) return false;
            if (isfinite(translation.x) && isfinite(translation.y) &&
                !HHMoveBubble(s, CGPointMake(HHFloating.dragBase.x+translation.x,HHFloating.dragBase.y+translation.y))) return false;
        }
        if (state==UIGestureRecognizerStatePossible || state>=UIGestureRecognizerStateEnded) HHFloating.dragging=NO;
    }
    return !s.lastError.length;
}

bool hoangha_floating_stop(RemoteCall *s) {
    HHFloating.active=NO;
    if (!s || s.lastError.length) return false;
    if (!HHFloating.app) HHFloating.app=HHApplication(s);
    if (!HHFloating.app) return false;
    HHRemoveOld(s, HHBubbleKey); HHRemoveOld(s, HHMenuKey);HHRemoveOld(s,HHCanvasKey);
    if(HHFloating.rectangles&&!s.lastError.length)RemoteArbCall(s,free,HHFloating.rectangles);
    HHFastCall calls[]={HHFloating.panState,HHFloating.translation,HHFloating.move,HHFloating.menuHidden,HHFloating.espState,HHFloating.bubbleBounds,HHFloating.menuBounds,HHFloating.canvasPath,HHFloating.lineState,HHFloating.countState};
    for (NSUInteger i=0;i<sizeof(calls)/sizeof(calls[0]);i++) if (calls[i].scratch && !s.lastError.length) RemoteArbCall(s, free, calls[i].scratch);
    HHAssociate(s, HHRootsKey, 0);
    BOOL okay=!s.lastError.length;
    memset(&HHFloating,0,sizeof(HHFloating));
    return okay;
}

#include "HoanghaESPBoxBridge.inc"
