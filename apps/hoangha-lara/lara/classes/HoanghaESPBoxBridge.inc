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
 HHPlaceWindow(s,HHFloating.menu,CGRectMake((size.width-width)/2,(size.height-340)/2,width,340));
 if(HHFloating.countLabel)HHSetRect(s,HHFloating.countLabel,CGRectMake((size.width-72)/2,10,72,32));
 if(HHFloating.canvas){
  uint64_t empty=0;
  HHFastSet(s,HHFloating.canvasPath,&empty,sizeof(empty));
  HHFastSet(s,HHFloating.fovPath,&empty,sizeof(empty));
  HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;
  HHFloating.previousCount=0;HHFloating.previousFOV=NO;HHFloating.previousFOVRadius=0;
  HHFloating.previousTargetCount=0;HHFloating.lastTargetLabelAt=0;
  HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,size});
 }
}
BOOL hoangha_floating_esp_enabled(void){return HHFloating.active&&HHFloating.espEnabled;}
BOOL hoangha_floating_silent_enabled(void){return HHFloating.active&&HHFloating.silentEnabled;}
BOOL hoangha_floating_neck_enabled(void){return HHFloating.active&&HHFloating.neckEnabled;}
float hoangha_floating_fov_percent(void){return HHFloating.fovPercent>=5&&HHFloating.fovPercent<=48?HHFloating.fovPercent:18;}
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
static BOOL HHUpdateFOV(RemoteCall *s,BOOL enabled,CGFloat radius){
 if(!HHFloating.fovPath.invocation)return NO;
 if(!enabled){
  if(HHFloating.previousFOV){uint64_t empty=0;if(!HHFastSet(s,HHFloating.fovPath,&empty,sizeof(empty)))return NO;}
  HHFloating.previousFOV=NO;HHFloating.previousFOVRadius=0;return YES;
 }
 if(HHFloating.previousFOV&&fabs(HHFloating.previousFOVRadius-radius)<0.1)return YES;
 CGPoint circle[65];CGPoint center=CGPointMake(HHFloating.screen.width*0.5,HHFloating.screen.height*0.5);
 for(NSUInteger i=0;i<65;i++){
  CGFloat angle=(CGFloat)i*(2*M_PI/64.0);
  circle[i]=CGPointMake(center.x+radius*cos(angle),center.y+radius*sin(angle));
 }
 uint64_t points=HHFloating.rectangles+sizeof(CGRect)*HHMaxMarks+sizeof(CGPoint)*(2*HHMaxBoxes+1);
 if(!HHFloating.rectangles||![s remote_write:points from:circle size:sizeof(circle)])return NO;
 uint64_t path=RemoteArbCall(s,CGPathCreateMutable);if(!path)return NO;
 RemoteArbCall(s,CGPathAddLines,path,0,points,65);
 BOOL drawn=HHFastSet(s,HHFloating.fovPath,&path,sizeof(path));
 if(!s.lastError.length)RemoteArbCall(s,CGPathRelease,path);
 if(drawn){HHFloating.previousFOV=YES;HHFloating.previousFOVRadius=radius;}
 return drawn;
}
static void HHUpdateEnemyBadge(RemoteCall *s,NSUInteger count){
 if(!HHFloating.countLabel||HHFloating.badgeCount==count)return;
 if(count){
  NSString *label=[NSString stringWithFormat:@"%lu",(unsigned long)count];
  HHSend(s,HHFloating.countLabel,"setText:",remote_NSString(s,label.UTF8String),0);
 }
 HHSend(s,HHFloating.countLabel,"setHidden:",count==0,0);
 HHFloating.badgeCount=count;
}
static void HHUpdateTargetLabels(RemoteCall *s,const HHFFBox *targets,NSUInteger count){
 CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
 if(count==HHFloating.targetLabelCount&&now-HHFloating.lastTargetLabelAt<0.08)return;
 HHFloating.lastTargetLabelAt=now;
 for(NSUInteger i=0;i<count;i++){
  const HHFFBox *target=&targets[i];
  uint64_t label=HHFloating.targetLabels[i];
  if(!label){
   label=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
   if(!label)return;
   HHFloating.targetLabels[i]=label;
   HHSend(s,label,"setTextAlignment:",NSTextAlignmentCenter,0);
   uint64_t colors=remote_getClass(s,"UIColor");
   HHSend(s,label,"setBackgroundColor:",HHSend(s,colors,"clearColor",0,0),0);
   HHSend(s,label,"setTextColor:",HHSend(s,colors,"whiteColor",0,0),0);
   HHSend(s,label,"setShadowColor:",HHSend(s,colors,"blackColor",0,0),0);
   CGSize shadow=CGSizeMake(1,1);
   HHInvoke(s,label,"setShadowOffset:",&shadow,sizeof(shadow),NULL,0,NULL,0);
   HHSend(s,label,"setFont:",HHFont(s,11),0);
   HHSend(s,HHFloating.canvasRoot,"addSubview:",label,0);
   CGRect initialRect=CGRectZero;
   uint64_t initialText=remote_NSString(s,"");
   HHFloating.targetFrames[i]=HHPrepareCall(s,label,"setFrame:",&initialRect,sizeof(initialRect));
   HHFloating.targetTextCalls[i]=HHPrepareCall(s,label,"setText:",&initialText,sizeof(initialText));
   HHSend(s,label,"release",0,0);
   if(!HHFloating.targetFrames[i].invocation||!HHFloating.targetTextCalls[i].invocation)return;
  }
  NSString *name=[NSString stringWithUTF8String:target->name];
  if(!name.length)name=[NSString stringWithFormat:@"#%u",(unsigned)target->number];
  if(name.length>20)name=[[name substringToIndex:20] stringByAppendingString:@"…"];
  NSString *caption=[NSString stringWithFormat:@"%@ · %u HP",name,(unsigned)target->hp];
  const char *bytes=caption.UTF8String;
  if(bytes&&strncmp(bytes,HHFloating.targetTexts[i],sizeof(HHFloating.targetTexts[i]))){
   uint64_t value=remote_NSString(s,bytes);
   if(!HHFastSet(s,HHFloating.targetTextCalls[i],&value,sizeof(value)))return;
   snprintf(HHFloating.targetTexts[i],sizeof(HHFloating.targetTexts[i]),"%s",bytes);
  }
  CGRect rect=CGRectMake(MAX(0,MIN(HHFloating.screen.width-160,target->x+target->w*0.5-80)),
                         MAX(0,target->y-21),160,19);
  if(i>=HHFloating.targetLabelCount||!CGRectEqualToRect(rect,HHFloating.targetLabelRects[i])){
   if(!HHFastSet(s,HHFloating.targetFrames[i],&rect,sizeof(rect)))return;
   HHFloating.targetLabelRects[i]=rect;
  }
  if(i>=HHFloating.targetLabelCount)HHSend(s,label,"setHidden:",0,0);
 }
 for(NSUInteger i=count;i<HHFloating.targetLabelCount;i++)
  HHSend(s,HHFloating.targetLabels[i],"setHidden:",1,0);
 HHFloating.targetLabelCount=count;
}
BOOL hoangha_floating_boxes(RemoteCall *s,NSArray<NSValue *> *boxes){
 if(!HHFloating.active||s.lastError.length)return NO;
 CGRect rectangles[HHMaxMarks];CGPoint lines[2*HHMaxBoxes+1];
 HHFFBox ordered[HHMaxBoxes];
 NSUInteger count=0,targets=0;
 CGPoint origin=CGPointMake(HHFloating.screen.width*0.5,HHFloating.screen.height-8);
 lines[0]=origin;
 if(HHFloating.espEnabled)for(NSValue *value in boxes){
  HHFFBox target={0};
  [value getValue:&target size:sizeof(target)];
  if(!isfinite(target.x)||!isfinite(target.y)||!isfinite(target.w)||!isfinite(target.h)||target.w<1||target.h<1||target.w>HHFloating.screen.width*2||target.h>HHFloating.screen.height*2)continue;
  NSUInteger i=targets;
  while(i>0&&ordered[i-1].id>target.id){ordered[i]=ordered[i-1];i--;}
  ordered[i]=target;
  if(++targets==HHMaxBoxes)break;
 }
 NSUInteger previous=0;
 for(NSUInteger i=0;i<targets;i++){
  const HHFFBox *target=&ordered[i];
  while(previous<HHFloating.previousTargetCount&&HHFloating.previousTargets[previous].id<target->id)previous++;
  const HHRect *prior=previous<HHFloating.previousTargetCount&&HHFloating.previousTargets[previous].id==target->id?
   &HHFloating.previousTargets[previous].rect:NULL;
  HHRect stable=hh_overlay_stable_rect((HHRect){target->x,target->y,target->w,target->h},prior);
  CGRect r=CGRectMake(stable.x,stable.y,stable.width,stable.height);
  ordered[i].x=stable.x;ordered[i].y=stable.y;ordered[i].w=stable.width;ordered[i].h=stable.height;
  rectangles[count++]=r;
  lines[2*i+1]=CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r));
  lines[2*i+2]=origin;
 }
 HHUpdateEnemyBadge(s,HHFloating.countEnabled?targets:0);
 BOOL ring=HHFloating.fovEnabled&&(HHFloating.espEnabled||HHFloating.silentEnabled||HHFloating.neckEnabled);
 CGFloat radius=MIN(HHFloating.screen.width,HHFloating.screen.height)*hoangha_floating_fov_percent()/100.f;
 if(!count&&!ring){
  HHUpdateTargetLabels(s,ordered,0);HHFloating.previousTargetCount=0;
  if(HHFloating.canvas&&HHFloating.previousFOV&&!HHUpdateFOV(s,NO,0))return NO;
  if(HHFloating.canvasVisible){uint64_t empty=0;
   if(!HHFastSet(s,HHFloating.canvasPath,&empty,sizeof(empty)))return NO;
   HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHFloating.canvasVisible=NO;HHFloating.previousCount=0;
  }
  return !s.lastError.length;
 }
 HHFloating.previousTargetCount=targets;
 for(NSUInteger i=0;i<targets;i++){
  const HHFFBox *target=&ordered[i];
  HHFloating.previousTargets[i].id=target->id;
  HHFloating.previousTargets[i].rect=(HHRect){target->x,target->y,target->w,target->h};
 }
 if(!HHFloating.canvas){
  uint64_t root=0;
  HHFloating.canvas=HHCreateSmallWindow(s,(CGRect){CGPointZero,HHFloating.screen},&root);
  if(!HHFloating.canvas)return NO;
  HHFloating.canvasRoot=root;
  HHAssociate(s,HHCanvasKey,HHFloating.canvas);
  HHSend(s,HHFloating.canvas,"setUserInteractionEnabled:",0,0);HHSend(s,root,"setUserInteractionEnabled:",0,0);
  HHSetNumber(s,HHFloating.canvas,"windowLevel",3000);
  uint64_t colors=remote_getClass(s,"UIColor");
  HHFloating.countLabel=HHSend(s,remote_getClass(s,"UILabel"),"new",0,0);
  HHSetRect(s,HHFloating.countLabel,CGRectMake((HHFloating.screen.width-72)/2,10,72,32));
  HHSend(s,HHFloating.countLabel,"setTextAlignment:",NSTextAlignmentCenter,0);
  HHSend(s,HHFloating.countLabel,"setBackgroundColor:",HHSend(s,colors,"clearColor",0,0),0);
  HHSend(s,HHFloating.countLabel,"setTextColor:",HHSend(s,colors,"systemRedColor",0,0),0);
  HHSend(s,HHFloating.countLabel,"setShadowColor:",HHSend(s,colors,"blackColor",0,0),0);
  CGSize shadowOffset=CGSizeMake(1,1);
  HHInvoke(s,HHFloating.countLabel,"setShadowOffset:",&shadowOffset,sizeof(shadowOffset),NULL,0,NULL,0);
  uint64_t countFont=0;
  CGFloat fontSize=22,weight=UIFontWeightSemibold;
  HHInvoke(s,remote_getClass(s,"UIFont"),"monospacedDigitSystemFontOfSize:weight:",
           &fontSize,sizeof(fontSize),&weight,sizeof(weight),&countFont,sizeof(countFont));
  HHSend(s,HHFloating.countLabel,"setFont:",countFont?:HHFont(s,fontSize),0);
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
  HHFloating.fovShape=HHSend(s,remote_getClass(s,"CAShapeLayer"),"new",0,0);
  HHSend(s,HHFloating.fovShape,"setActions:",HHSend(s,HHFloating.shape,"actions",0,0),0);
  HHSend(s,HHFloating.fovShape,"setStrokeColor:",cgColor,0);
  HHSend(s,HHFloating.fovShape,"setFillColor:",0,0);
  HHInvoke(s,HHFloating.fovShape,"setLineWidth:",&width,sizeof(width),NULL,0,NULL,0);
  HHSend(s,HHSend(s,root,"layer",0,0),"addSublayer:",HHFloating.fovShape,0);
  HHSend(s,HHFloating.fovShape,"release",0,0);
  HHFloating.fovPath=HHPrepareCall(s,HHFloating.fovShape,"setPath:",&emptyPath,sizeof(emptyPath));
  if(!HHFloating.fovPath.invocation)return NO;
  HHFloating.rectangles=RemoteArbCall(s,malloc,sizeof(rectangles)+sizeof(lines)+sizeof(CGPoint)*65);
  HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,HHFloating.screen});
 }
 HHUpdateTargetLabels(s,ordered,targets);
 if(s.lastError.length||!HHUpdateFOV(s,ring,radius))return NO;
 if(!count){
  if(HHFloating.previousCount){uint64_t empty=0;if(!HHFastSet(s,HHFloating.canvasPath,&empty,sizeof(empty)))return NO;}
  if(!HHFloating.canvasVisible)HHSend(s,HHFloating.canvas,"setHidden:",0,0);
  HHFloating.canvasVisible=YES;HHFloating.previousCount=0;
  return !s.lastError.length;
 }
 if(HHFloating.canvasVisible&&HHFloating.previousLine==HHFloating.lineEnabled&&
    HHFloating.previousCount==count&&!memcmp(rectangles,HHFloating.previousRectangles,count*sizeof(CGRect)))return YES;
 if(!HHFloating.rectangles||(count&&![s remote_write:HHFloating.rectangles from:rectangles size:count*sizeof(CGRect)]))return NO;
 uint64_t path=RemoteArbCall(s,CGPathCreateMutable);if(!path)return NO;
 if(count)RemoteArbCall(s,CGPathAddRects,path,0,HHFloating.rectangles,count);
 if(HHFloating.lineEnabled&&targets){
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
 if(!s.lastError.length){HHFloating.canvasVisible=YES;HHFloating.previousLine=HHFloating.lineEnabled;
  HHFloating.previousCount=count;
  memcpy(HHFloating.previousRectangles,rectangles,count*sizeof(CGRect));}
 return !s.lastError.length;
}
