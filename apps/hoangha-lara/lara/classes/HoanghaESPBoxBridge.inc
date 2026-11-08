// Display objects stay in SpringBoard, beside the existing floating menu.
// The full-size drawing window is noninteractive; only the bounded menu receives touches.
BOOL hoangha_game_geometry(RemoteCall *game,CGSize *size,NSInteger *orientation){
 if(!game||game.lastError.length)return NO;
 uint64_t app=HHApplication(game),scene=HHWindowScene(game,app);
 if(!scene||HHSend(game,scene,"activationState",0,0)!=UISceneActivationStateForegroundActive)return NO;
 uint64_t space=HHSend(game,scene,"coordinateSpace",0,0);CGRect bounds=HHGetRect(game,space,"bounds");
 NSInteger o=(NSInteger)HHSend(game,scene,"interfaceOrientation",0,0);
 if(o<1||o>4||!isfinite(bounds.size.width)||!isfinite(bounds.size.height)||bounds.size.width<100||bounds.size.height<100||bounds.size.width>10000||bounds.size.height>10000)return NO;
 if(size)*size=bounds.size;if(orientation)*orientation=o;return YES;
}
void hoangha_floating_layout(RemoteCall *s,CGSize size,NSInteger orientation){
 if(!HHFloating.active||s.lastError.length||orientation<1||orientation>4||!isfinite(size.width)||!isfinite(size.height)||size.width<100||size.height<100||size.width>10000||size.height>10000)return;
 if(CGSizeEqualToSize(size,HHFloating.screen)&&orientation==HHFloating.orientation)return;
 HHFloating.screen=size;HHFloating.orientation=orientation;HHFloating.dragging=NO;
 HHPoint point=hh_overlay_clamp((HHPoint){HHFloating.position.x,HHFloating.position.y},(HHSize){size.width,size.height},58);
 HHFloating.position=CGPointMake(point.x,point.y);
 HHPlaceWindow(s,HHFloating.bubble,(CGRect){HHFloating.position,{58,58}});
 CGFloat width=MIN(280,size.width-24);
 HHPlaceWindow(s,HHFloating.menu,CGRectMake((size.width-width)/2,(size.height-180)/2,width,180));
 if(HHFloating.canvas){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);HHPlaceWindow(s,HHFloating.canvas,(CGRect){CGPointZero,size});}
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
 if(!count){if(HHFloating.canvas){HHSend(s,HHFloating.shape,"setPath:",0,0);HHSend(s,HHFloating.canvas,"setHidden:",1,0);}return !s.lastError.length;}
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
 HHSend(s,HHFloating.canvas,"setHidden:",0,0);return !s.lastError.length;
}
