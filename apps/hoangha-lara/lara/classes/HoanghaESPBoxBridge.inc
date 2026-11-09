#import "../../Standalone/HHFFProfile.h"

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
 HHPlaceWindow(s,HHFloating.menu,CGRectMake((size.width-width)/2,(size.height-230)/2,width,230));
 if(HHFloating.countLabel)HHSetRect(s,HHFloating.countLabel,CGRectMake((size.width-108)/2,12,108,22));
 if(HHFloating.canvas){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;HHFloating.previousCount=0;HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,size});}
}
BOOL hoangha_floating_esp_enabled(void){return HHFloating.active&&HHFloating.espEnabled;}
CGSize hoangha_floating_size(void){return HHFloating.screen;}
void hoangha_floating_status(RemoteCall *s,NSString *status){
 if(HHFloating.statusLabel&&status.length)HHSend(s,HHFloating.statusLabel,"setText:",remote_NSString(s,status.UTF8String),0);
}
static BOOL HHSetCanvasPath(RemoteCall *s,uint64_t path){
 HHFastCall call=HHFloating.canvasPath;
 if(!call.invocation||![s remote_write:call.scratch+64 from:&path size:sizeof(path)])return NO;
 remote_msg(s,call.invocation,HHFloating.setArgument,call.scratch+64,2,0,0);
 return HHRunCall(s,call,NULL);
}
static NSUInteger HHNumberMarks(CGRect *marks, CGRect box, const HHFFBox *target, CGFloat screenWidth){
 static const uint8_t digits[]={63,6,91,79,102,109,125,7,127,111};
 const CGRect strokes[]={
  {{0,0},{2.8,.6}},{{2.8,.6},{.6,2.4}},{{2.8,3.6},{.6,2.4}},
  {{0,6},{2.8,.6}},{{0,3.6},{.6,2.4}},{{0,.6},{.6,2.4}},{{0,3},{2.8,.6}}
 };
 char text[12];
 snprintf(text,sizeof(text),"%u-%u",(unsigned)target->number,(unsigned)target->hp);
 CGFloat x=MAX(1,MIN(screenWidth-1-5*strlen(text),CGRectGetMidX(box)-2.5*strlen(text)));
 CGFloat y=MAX(2,CGRectGetMinY(box)-9);
 NSUInteger count=0;
 for(const char *p=text;*p;p++,x+=5){
  uint8_t mask=*p=='-'?64:digits[*p-'0'];
  for(NSUInteger i=0;i<7;i++)if(mask&(1<<i))marks[count++]=CGRectOffset(strokes[i],x,y);
 }
 return count;
}

static void HHUpdateEnemyBadge(RemoteCall *s,NSUInteger count){
 if(!HHFloating.countLabel||HHFloating.badgeCount==count)return;
 if(count){
  NSString *label=[NSString stringWithFormat:@"ĐỊCH  %lu",(unsigned long)count];
  HHSend(s,HHFloating.countLabel,"setText:",remote_NSString(s,label.UTF8String),0);
 }
 HHSend(s,HHFloating.countLabel,"setHidden:",count==0,0);
 HHFloating.badgeCount=count;
}
BOOL hoangha_floating_boxes(RemoteCall *s,NSArray<NSValue *> *boxes){
 if(!HHFloating.active||s.lastError.length)return NO;
 CGRect rectangles[HHMaxMarks];CGPoint lines[2*HHMaxBoxes+1];
 NSUInteger count=0,targets=0;
 CGPoint origin=CGPointMake(HHFloating.screen.width*0.5,HHFloating.screen.height-8);
 lines[0]=origin;
 if(HHFloating.espEnabled)for(NSValue *value in boxes){
  HHFFBox target={0};
  [value getValue:&target size:sizeof(target)];
  CGRect r=CGRectMake(round(target.x*4)/4,round(target.y*4)/4,round(target.w*4)/4,round(target.h*4)/4);
  if(!isfinite(r.origin.x)||!isfinite(r.origin.y)||!isfinite(r.size.width)||!isfinite(r.size.height)||r.size.width<1||r.size.height<1||r.size.width>HHFloating.screen.width*2||r.size.height>HHFloating.screen.height*2)continue;
  rectangles[count++]=r;
  if(HHFloating.countEnabled)count+=HHNumberMarks(rectangles+count,r,&target,HHFloating.screen.width);
  lines[2*targets+1]=CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r));
  lines[2*targets+2]=origin;
  if(++targets==HHMaxBoxes)break;
 }
 HHUpdateEnemyBadge(s,HHFloating.countEnabled?targets:0);
 if(!count){if(HHFloating.canvasVisible){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;HHFloating.previousCount=0;}return !s.lastError.length;}
 if(HHFloating.canvasVisible&&HHFloating.previousLine==HHFloating.lineEnabled&&HHFloating.previousCount==count&&!memcmp(rectangles,HHFloating.previousRectangles,count*sizeof(CGRect)))return YES;
 if(!HHFloating.canvas){
  uint64_t root=0;
  HHFloating.canvas=HHCreateSmallWindow(s,(CGRect){CGPointZero,HHFloating.screen},&root);
  if(!HHFloating.canvas)return NO;
  HHAssociate(s,HHCanvasKey,HHFloating.canvas);
  HHSend(s,HHFloating.canvas,"setUserInteractionEnabled:",0,0);HHSend(s,root,"setUserInteractionEnabled:",0,0);
  HHSetNumber(s,HHFloating.canvas,"windowLevel",3000);
  uint64_t colors=remote_getClass(s,"UIColor");
  HHFloating.countLabel=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
  HHSetRect(s,HHFloating.countLabel,CGRectMake((HHFloating.screen.width-108)/2,12,108,22));
  HHSend(s,HHFloating.countLabel,"setTextAlignment:",NSTextAlignmentCenter,0);
  HHSend(s,HHFloating.countLabel,"setTextColor:",HHSend(s,colors,"systemRedColor",0,0),0);
  HHSend(s,HHFloating.countLabel,"setFont:",HHFont(s,16),0);
  HHSend(s,HHFloating.countLabel,"setHidden:",1,0);
  HHSend(s,root,"addSubview:",HHFloating.countLabel,0);HHSend(s,HHFloating.countLabel,"release",0,0);
  HHUpdateEnemyBadge(s,HHFloating.countEnabled?targets:0);
  HHFloating.shape=HHSend(s,remote_getClass(s,"CAShapeLayer"),"new",0,0);
  uint64_t actions=HHSend(s,remote_getClass(s,"NSMutableDictionary"),"new",0,0);
  uint64_t null=HHSend(s,remote_getClass(s,"NSNull"),"null",0,0);
  HHSend(s,actions,"setObject:forKey:",null,remote_NSString(s,"path"));
  HHSend(s,HHFloating.shape,"setActions:",actions,0);HHSend(s,actions,"release",0,0);
  uint64_t color=HHSend(s,colors,"whiteColor",0,0),cgColor=HHSend(s,color,"CGColor",0,0);
  HHSend(s,HHFloating.shape,"setStrokeColor:",cgColor,0);HHSend(s,HHFloating.shape,"setFillColor:",0,0);
  CGFloat width=1;HHInvoke(s,HHFloating.shape,"setLineWidth:",&width,sizeof(width),NULL,0,NULL,0);
  HHSend(s,HHSend(s,root,"layer",0,0),"addSublayer:",HHFloating.shape,0);HHSend(s,HHFloating.shape,"release",0,0);
  uint64_t emptyPath=0;
  HHFloating.canvasPath=HHPrepareCall(s,HHFloating.shape,"setPath:",&emptyPath,sizeof(emptyPath));
  if(!HHFloating.canvasPath.invocation)return NO;
  HHFloating.rectangles=RemoteArbCall(s,malloc,sizeof(rectangles)+sizeof(lines));
  HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,HHFloating.screen});
 }
 if(!HHFloating.rectangles||![s remote_write:HHFloating.rectangles from:rectangles size:count*sizeof(CGRect)])return NO;
 uint64_t path=RemoteArbCall(s,CGPathCreateMutable);if(!path)return NO;
 RemoteArbCall(s,CGPathAddRects,path,0,HHFloating.rectangles,count);
 if(HHFloating.lineEnabled){
  uint64_t points=HHFloating.rectangles+sizeof(rectangles);
  if(![s remote_write:points from:lines size:(2*targets+1)*sizeof(CGPoint)]){
   if(!s.lastError.length)RemoteArbCall(s,CGPathRelease,path);
   return NO;
  }
  RemoteArbCall(s,CGPathAddLines,path,0,points,2*targets+1);
 }
 BOOL drawn=HHSetCanvasPath(s,path);
 if(!s.lastError.length)RemoteArbCall(s,CGPathRelease,path);
 if(!drawn)return NO;
 if(!HHFloating.canvasVisible)HHSend(s,HHFloating.canvas,"setHidden:",0,0);
 if(!s.lastError.length){HHFloating.canvasVisible=YES;HHFloating.previousLine=HHFloating.lineEnabled;HHFloating.previousCount=count;memcpy(HHFloating.previousRectangles,rectangles,count*sizeof(CGRect));}
 return !s.lastError.length;
}
