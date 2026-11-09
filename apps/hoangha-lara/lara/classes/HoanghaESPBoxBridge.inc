// Display objects stay in SpringBoard, beside the existing floating menu.
// The full-size drawing window is noninteractive; only the bounded menu receives touches.
static uint64_t HHOptionalSend(RemoteCall *springboard, uint64_t object, const char *name) {
    if (!object || springboard.lastError.length) return 0;
    if (!(BOOL)HHRawSend(springboard, object, "respondsToSelector:", remote_sel(springboard, name), 0)) return 0;
    return HHSend(springboard, object, name, 0, 0);
}

static BOOL HHIsFreeFire(RemoteCall *springboard, uint64_t front) {
    uint64_t identifier = HHOptionalSend(springboard, front, "bundleIdentifier");
    if (!identifier) return NO;
    const char prefix[] = "com.dts.freefireth";
    char bundle[64] = {0};
    uint64_t length = HHSend(springboard, identifier, "lengthOfBytesUsingEncoding:", NSUTF8StringEncoding, 0);
    if (length < sizeof(prefix) - 1 || length >= sizeof(bundle)) return NO;
    uint64_t bytes = HHSend(springboard, identifier, "UTF8String", 0, 0);
    if (!bytes || ![springboard remoteRead:bytes to:bundle size:length] ||
        memcmp(bundle, prefix, sizeof(prefix) - 1)) return NO;
    for (size_t i = sizeof(prefix) - 1; i < length; ++i) {
        if (bundle[i] < '0' || bundle[i] > '9') return NO;
    }
    return YES;
}

static NSInteger HHDisplayOrientation(RemoteCall *springboard, BOOL expectLandscape) {
    NSInteger current = (NSInteger)HHOptionalSend(springboard, HHFloating.app, "_frontMostAppOrientation");
    if (UIInterfaceOrientationIsLandscape(current) ||
        (!expectLandscape && UIInterfaceOrientationIsPortrait(current))) return current;

    if (!HHFloating.orientationObserver) {
        uint64_t cls = remote_getClass(springboard, "FBSOrientationObserver");
        uint64_t observer = HHOptionalSend(springboard, cls, "new");
        if (observer) {
            HHKeep(springboard, observer);
            HHSend(springboard, observer, "release", 0, 0);
            HHFloating.orientationObserver = observer;
        }
    }
    NSInteger observed = (NSInteger)HHOptionalSend(springboard, HHFloating.orientationObserver, "activeInterfaceOrientation");
    if (UIInterfaceOrientationIsLandscape(observed) ||
        (!expectLandscape && UIInterfaceOrientationIsPortrait(observed))) return observed;
    NSInteger statusBar = (NSInteger)HHOptionalSend(springboard, HHFloating.app, "statusBarOrientation");
    return UIInterfaceOrientationIsLandscape(statusBar) || !current ? statusBar : current;
}

static void HHLayoutFloatingWindows(RemoteCall *s,CGSize size,NSInteger orientation);

pid_t hoangha_foreground_game(RemoteCall *springboard, NSString **waitingStatus) {
    if (!HHFloating.active || springboard.lastError.length) return 0;
    // Opening the menu can refresh layout without probing the game process.
    uint64_t front = waitingStatus ? HHOptionalSend(springboard, HHFloating.app, "_accessibilityFrontMostApplication") : 0;
    BOOL isFreeFire = HHIsFreeFire(springboard, front);
    NSInteger current = HHDisplayOrientation(springboard, isFreeFire);
    BOOL landscape = UIInterfaceOrientationIsLandscape(current);
    CGSize fixed = HHFloating.fixedScreen;
    HHLayoutFloatingWindows(springboard, landscape ? CGSizeMake(fixed.height, fixed.width) : fixed, current);
    if (!waitingStatus) return 0;
    *waitingStatus = @"Đang chờ FF TH mở";
    if (!isFreeFire || springboard.lastError.length) return 0;
    *waitingStatus = @"Chưa nhận hướng ngang";
    if (!landscape) return 0;

    uint64_t state = HHOptionalSend(springboard, front, "processState");
    pid_t pid = (pid_t)HHOptionalSend(springboard, state, "pid");
    if (pid <= 0) pid = (pid_t)HHOptionalSend(springboard, front, "pid");
    if (pid <= 0) pid = (pid_t)HHOptionalSend(springboard, front, "processID");
    if (pid <= 0 || springboard.lastError.length) {
        *waitingStatus = @"Chưa nhận tiến trình FF TH";
        return 0;
    }
    *waitingStatus = @"Đang xác nhận phiên FF TH";
    return pid;
}
static void HHLayoutFloatingWindows(RemoteCall *s,CGSize size,NSInteger orientation){
 if(!HHFloating.active||s.lastError.length||orientation<1||orientation>4||!isfinite(size.width)||!isfinite(size.height)||size.width<100||size.height<100||size.width>10000||size.height>10000)return;
 if(CGSizeEqualToSize(size,HHFloating.screen)&&orientation==HHFloating.orientation)return;
 HHFloating.screen=size;HHFloating.orientation=orientation;HHFloating.dragging=NO;
 HHPoint point=hh_overlay_clamp((HHPoint){HHFloating.position.x,HHFloating.position.y},(HHSize){size.width,size.height},58);
 HHFloating.position=CGPointMake(point.x,point.y);
 HHPlaceWindow(s,HHFloating.bubble,(CGRect){HHFloating.position,{58,58}});
 CGFloat width=MIN(280,size.width-24);
 HHPlaceWindow(s,HHFloating.menu,CGRectMake((size.width-width)/2,(size.height-180)/2,width,180));
 if(HHFloating.canvas){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;HHFloating.previousCount=0;HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,size});}
}
BOOL hoangha_floating_esp_enabled(void){return HHFloating.active&&HHFloating.espEnabled;}
CGSize hoangha_floating_size(void){return HHFloating.screen;}
void hoangha_floating_status(RemoteCall *s,NSString *status){
 if(HHFloating.statusLabel&&status.length)HHSend(s,HHFloating.statusLabel,"setText:",remote_NSString(s,status.UTF8String),0);
}
BOOL hoangha_floating_boxes(RemoteCall *s,NSArray<NSValue *> *boxes){
 if(!HHFloating.active||s.lastError.length)return NO;
 CGRect rectangles[32];NSUInteger count=0;
 if(HHFloating.espEnabled)for(NSValue *value in boxes){
  CGRect r=value.CGRectValue;
  if(!isfinite(r.origin.x)||!isfinite(r.origin.y)||!isfinite(r.size.width)||!isfinite(r.size.height)||r.size.width<1||r.size.height<1||r.size.width>HHFloating.screen.width*2||r.size.height>HHFloating.screen.height*2)continue;
  rectangles[count++]=r;if(count==32)break;
 }
 if(!count){if(HHFloating.canvasVisible){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;HHFloating.previousCount=0;}return !s.lastError.length;}
 if(HHFloating.canvasVisible&&HHFloating.previousCount==count&&!memcmp(rectangles,HHFloating.previousRectangles,count*sizeof(CGRect)))return YES;
 if(!HHFloating.canvas){
  uint64_t root=0;
  HHFloating.canvas=HHCreateSmallWindow(s,(CGRect){CGPointZero,HHFloating.screen},&root);
  if(!HHFloating.canvas)return NO;
  HHAssociate(s,HHCanvasKey,HHFloating.canvas);
  HHSend(s,HHFloating.canvas,"setUserInteractionEnabled:",0,0);HHSend(s,root,"setUserInteractionEnabled:",0,0);
  HHSetNumber(s,HHFloating.canvas,"windowLevel",3000);
  HHFloating.shape=HHSend(s,remote_getClass(s,"CAShapeLayer"),"new",0,0);
  uint64_t actions=HHSend(s,remote_getClass(s,"NSMutableDictionary"),"new",0,0);
  uint64_t null=HHSend(s,remote_getClass(s,"NSNull"),"null",0,0);
  HHSend(s,actions,"setObject:forKey:",null,remote_NSString(s,"path"));
  HHSend(s,HHFloating.shape,"setActions:",actions,0);HHSend(s,actions,"release",0,0);
  uint64_t color=HHSend(s,remote_getClass(s,"UIColor"),"cyanColor",0,0),cgColor=HHSend(s,color,"CGColor",0,0);
  HHSend(s,HHFloating.shape,"setStrokeColor:",cgColor,0);HHSend(s,HHFloating.shape,"setFillColor:",0,0);
  CGFloat width=1.5;HHInvoke(s,HHFloating.shape,"setLineWidth:",&width,sizeof(width),NULL,0,NULL,0);
  HHSend(s,HHSend(s,root,"layer",0,0),"addSublayer:",HHFloating.shape,0);HHSend(s,HHFloating.shape,"release",0,0);
  HHFloating.rectangles=RemoteArbCall(s,malloc,sizeof(rectangles));
  HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,HHFloating.screen});
 }
 if(!HHFloating.rectangles||![s remote_write:HHFloating.rectangles from:rectangles size:count*sizeof(CGRect)])return NO;
 uint64_t path=RemoteArbCall(s,CGPathCreateMutable);if(!path)return NO;
 RemoteArbCall(s,CGPathAddRects,path,0,HHFloating.rectangles,count);
 HHSend(s,HHFloating.shape,"setPath:",path,0);
 if(!s.lastError.length)RemoteArbCall(s,CGPathRelease,path);
 if(!HHFloating.canvasVisible)HHSend(s,HHFloating.canvas,"setHidden:",0,0);
 if(!s.lastError.length){HHFloating.canvasVisible=YES;HHFloating.previousCount=count;memcpy(HHFloating.previousRectangles,rectangles,count*sizeof(CGRect));}
 return !s.lastError.length;
}
