using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool:Component
    {
        // VM-owned state; player movement and the game's shared GUI skin stay separate.
        public static bool MzInitialized,MzOpen,MzDragged,MzDrawingEsp,MzBooting;
        public static int MzThreadId,MzLastLogicFrame;
        public static bool MzOnThread(){return MzInitialized&&MzThreadId==System.Threading.Thread.CurrentThread.ManagedThreadId;}
        public static GameObject MzDriver;
        public static int MzDrawBudget;
        public static bool MzUiPaint,MzInGui;
        public static Texture2D MzUiWhite;
        public static Matrix4x4 MzUiMatrix;
        public static float MzUiMatrixScale;
        public static string[] MzSliderTitles,MzSliderText;
        public static int[] MzSliderValues;
        public static float MzTabAnim;
        public static float MzBubbleX,MzBubbleY,MzPanelX,MzPanelY,MzOpenAnim,MzDragDX,MzDragDY,MzDownX,MzDownY,MzFov,MzRange,MzScale;
        public static int MzDragMode,MzTab,MzEspPage,MzLineOrigin;
        public static Vector2 MzPointer;
        public static GUIStyle MzLabelStyle,MzCenterStyle,MzWrapStyle;
        public static bool[] MzSwitch;
        public static float[] MzSwitchAnim;
        // ESP, box, corners, 3D, name, health, distance, skeleton, head, XYZ, line,
        // aim head on fire, silent on fire, FOV circle, aim target line.
        public static void MzEnsure()
        {
            int thread=System.Threading.Thread.CurrentThread.ManagedThreadId;
            if(MzBooting||(MzThreadId!=0&&MzThreadId!=thread))return;
            MzBooting=true;
            try {
                if(MzDriver==null){var g=GameObject.Find("__mizze_driver");if(g==null)g=new GameObject("__mizze_driver");if(g.GetComponent(typeof(SceneEditBoxSelectTool))==null)g.AddComponent(typeof(SceneEditBoxSelectTool));UnityEngine.Object.DontDestroyOnLoad(g);MzDriver=g;}
                MzThreadId=thread;
                if(!MzInitialized){MzUiPaint=true;MzLastLogicFrame=-1;MzSliderTitles=new string[2];MzSliderText=new string[2];MzSliderValues=new int[2];MzSwitch=new bool[17];MzSwitchAnim=new float[17];MzSwitch[1]=true;MzSwitch[4]=true;MzSwitch[5]=true;MzSwitch[6]=true;MzFireMultiplier=2;MzFov=150;MzRange=150;MzBubbleX=24;MzBubbleY=96;MzPanelX=120;MzPanelY=16;MzInitialized=true;MzAppearanceInit();try{MzLicenseInit();}catch(Exception e){MzLicenseMessage="Lỗi khởi tạo khóa. Thử nhập lại";MzLogFault("license-init",e);}}
            }catch(Exception e){MzLogFault("bootstrap",e);}finally{MzBooting=false;}
        }
        public static bool MzFinite(float f){return !Single.IsNaN(f)&&!Single.IsInfinity(f);}
        public static bool MzPoint(Vector3 p){return MzFinite(p.x)&&MzFinite(p.y)&&MzFinite(p.z);}
        public static void MzTint(float r,float g,float b,float a){if(MzUiPaint||MzBuilding)GUI.color=new Color(r,g,b,a);}
        public static float MzTween(float value,float target,float t){return Math.Abs(value-target)<.001f?target:Mathf.Lerp(value,target,t); }
        public static void MzFill(float x,float y,float w,float h,float radius)
        {
            if(!MzFinite(x)||!MzFinite(y)||!MzFinite(w)||!MzFinite(h)||w<=0||h<=0)return;
            if(MzBuilding){MzCommand(new Rect(x,y,w,h),Matrix4x4.identity,false,null,MzWhite);return;}
            if(!MzUiPaint)return;
            if(MzUiWhite==null)MzUiWhite=Texture2D.whiteTexture;
            // Rounded DrawTexture uses its explicit color.
            var tint=GUI.color;try{GUI.color=new Color(1,1,1,1);GUI.DrawTexture(new Rect(x,y,w,h),MzUiWhite,ScaleMode.StretchToFill,true,0,tint,0,radius);}finally{GUI.color=tint;}
        }
        public static void MzStyles()
        {
            if(MzLabelStyle!=null)return;
            var label=new GUIStyle();label.fontSize=20;label.wordWrap=false;label.alignment=TextAnchor.MiddleLeft;label.normal.textColor=new Color(1,1,1,1);
            var center=new GUIStyle();center.fontSize=20;center.wordWrap=false;center.alignment=TextAnchor.MiddleCenter;center.normal.textColor=new Color(1,1,1,1);
            var wrap=new GUIStyle();wrap.fontSize=18;wrap.wordWrap=true;wrap.alignment=TextAnchor.UpperLeft;wrap.normal.textColor=new Color(1,1,1,1);
            MzCenterStyle=center;MzWrapStyle=wrap;MzLabelStyle=label;
        }
        public static void MzText(float x,float y,float w,string s){if(MzBuilding){MzCommand(new Rect(x,y,w,28),Matrix4x4.identity,false,s,null);return;}if(!MzUiPaint)return;MzStyles();GUI.Label(new Rect(x,y,w,28),s,MzLabelStyle);}
        public static void MzCenter(float x,float y,float w,float h,string s){if(!MzUiPaint)return;MzStyles();GUI.Label(new Rect(x,y,w,h),s,MzCenterStyle);}
        public static void MzMessage(float x,float y,float w,float h,string s){if(!MzUiPaint)return;MzStyles();GUI.Label(new Rect(x,y,w,h),s,MzWrapStyle);}
        public static void MzLine(float ax,float ay,float bx,float by,float width)
        {
            if(!MzFinite(ax)||!MzFinite(ay)||!MzFinite(bx)||!MzFinite(by)||!MzFinite(width)||width<=0)return;
            if((ax<0&&bx<0)||(ax>Screen.width&&bx>Screen.width)||(ay<0&&by<0)||(ay>Screen.height&&by>Screen.height))return;
            float dx=bx-ax,dy=by-ay,length=Mathf.Sqrt(dx*dx+dy*dy);if(!MzFinite(length)||length<.5f||length>Screen.width*3)return;
            Rect rect;Matrix4x4 lineMatrix=Matrix4x4.identity;bool rotated=false;
            // Axis-aligned edges need no matrix calls. Extend both ends by half the
            // stroke so every shared endpoint overlaps instead of leaving a seam.
            if(dy==0)rect=new Rect((ax<bx?ax:bx)-width*.5f,ay-width*.5f,length+width,width);
            else if(dx==0)rect=new Rect(ax-width*.5f,(ay<by?ay:by)-width*.5f,width,length+width);
            else {rotated=true;lineMatrix=Matrix4x4.TRS(new Vector3(ax,ay,0),Quaternion.Euler(0,0,Mathf.Atan2(dy,dx)*57.29578f),new Vector3(1,1,1));rect=new Rect(-width*.5f,-width*.5f,length+width,width);}
            if(MzBuilding){MzCommand(rect,lineMatrix,rotated,null,MzWhite);return;}
            var old=GUI.matrix;try{if(rotated)GUI.matrix=lineMatrix;GUI.DrawTexture(rect,Texture2D.whiteTexture);}finally{if(rotated)GUI.matrix=old;}
        }
        public static void MzCircle(float cx,float cy,float radius,float width)
        {
            if(!MzFinite(cx)||!MzFinite(cy)||!MzFinite(radius)||radius<=0||radius>Screen.width)return;
            MzRendererInit();if(radius<=12){if(MzHeadRing==null)MzHeadRing=MzCreateRing(32,3);}else if(MzRing==null)MzRing=MzCreateRing(256,1.5f);var texture=radius<=12?MzHeadRing:MzRing;float correction=radius<=12?16f/14f:128f/126f;float extent=radius*correction;var rect=new Rect(cx-extent,cy-extent,extent*2,extent*2);
            if(MzBuilding){MzCommand(rect,Matrix4x4.identity,false,null,texture);return;}GUI.DrawTexture(rect,texture);
        }
        public static void MzLayout()
        {
            MzScale=Mathf.Clamp(Screen.height/720f*1.35f,.75f,3);float fitH=Screen.height/456f,fitW=Screen.width/398f;if(MzScale>fitH)MzScale=fitH;if(MzScale>fitW)MzScale=fitW;
            // Capture raw input before the draw matrix; convert exactly once.
            var p=Event.current.mousePosition;MzPointer=new Vector2(p.x/MzScale,p.y/MzScale);
            float width=Screen.width/MzScale,height=Screen.height/MzScale;MzPanelX=Mathf.Clamp(MzPanelX,4,width-386);MzPanelY=Mathf.Clamp(MzPanelY,4,height-444);MzBubbleX=Mathf.Clamp(MzBubbleX,4,width-84);MzBubbleY=Mathf.Clamp(MzBubbleY,4,height-84);
        }
        public static bool MzTap(float x,float y,float w,float h){var e=Event.current;if(!MzOpen||e==null||e.type!=EventType.MouseUp||MzDragMode!=0)return false;if(!new Rect(x,y,w,h).Contains(MzPointer))return false;e.Use();return true;}
        public static void MzToggle(int id,float x,float y,string title)
        {
            float a=MzSwitchAnim[id];MzTint(1,1,1,(.035f+.025f*a)*MzOpenAnim);MzFill(x,y,354,40,13);MzTint(1,1,1,.055f*MzOpenAnim);MzFill(x+13,y,328,1,0);MzTint(.94f,.96f,.98f,MzOpenAnim);MzText(x+12,y+6,276,title);
            MzTint(.32f+.42f*a,.34f+.45f*a,.38f+.45f*a,(.42f+.48f*a)*MzOpenAnim);MzFill(x+294,y+8,46,24,12);MzTint(1,1,1,MzOpenAnim);float bounce=Mathf.Sin(a*3.14159265f)*1.5f;MzFill(x+297+22*a-bounce,y+11-bounce,18+2*bounce,18+2*bounce,9+bounce);
            if(MzTap(x,y,354,40)){MzSwitch[id]=!MzSwitch[id];MzNextEsp=0;if(id==0){MzEspBlocked=false;MzEspFailures=0;MzSampleFailures=0;MzErrorWritten=false;MzRuntimeError=null;}if(id==11&&MzSwitch[id])MzSwitch[12]=false;if(id==12&&MzSwitch[id])MzSwitch[11]=false;if(id==2&&MzSwitch[id])MzSwitch[3]=false;if(id==3&&MzSwitch[id])MzSwitch[2]=false;if(id==11||id==12)MzRestoreSilent();if(id==15||id==16){MzNextWeapon=0;MzWeaponPoll();}}
        }
        public static void MzSlider(float x,float y,string title,bool fov)
        {
            float min=fov?20:50,max=fov?MzFovMaximum():500,value=fov?MzEffectiveFov():MzRange;MzTint(.94f,.96f,.98f,MzOpenAnim);if(MzUiPaint){int slot=fov?0:1,rounded=(int)value;if(MzSliderText[slot]==null||MzSliderTitles[slot]!=title||MzSliderValues[slot]!=rounded){MzSliderTitles[slot]=title;MzSliderValues[slot]=rounded;MzSliderText[slot]=title+"  "+rounded.ToString()+(fov?" px":" m");}MzText(x,y,354,MzSliderText[slot]);}
            var e=Event.current;if(MzOpen&&e.type==EventType.MouseDown&&new Rect(x,y+26,354,32).Contains(MzPointer))MzDragMode=fov?3:4;
            if(MzDragMode==(fov?3:4)&&(e.type==EventType.MouseDown||e.type==EventType.MouseDrag||e.type==EventType.MouseUp)){value=min+Mathf.Clamp((MzPointer.x-x)/354,0,1)*(max-min);if(fov)MzFov=value;else {MzRange=value;MzNextEsp=0;}if(e.type==EventType.MouseUp)MzDragMode=0;e.Use();}
            MzTint(.16f,.16f,.18f,MzOpenAnim);MzFill(x,y+37,354,6,3);MzTint(.89f,.93f,1,MzOpenAnim);MzFill(x,y+37,354*(value-min)/(max-min),6,3);MzFill(x+354*(value-min)/(max-min)-10,y+30,20,20,10);
        }
        public static void MzDrag()
        {
            var e=Event.current;Vector2 p=MzPointer;
            if(e.type==EventType.MouseDown&&MzDragMode==0){float dx=p.x-MzBubbleX-40,dy=p.y-MzBubbleY-40;if(dx*dx+dy*dy<=1600){MzDragMode=1;MzDragDX=p.x-MzBubbleX;MzDragDY=p.y-MzBubbleY;}else if(MzOpen&&new Rect(MzPanelX,MzPanelY,320,60).Contains(p)){MzDragMode=2;MzDragDX=p.x-MzPanelX;MzDragDY=p.y-MzPanelY;}if(MzDragMode>0){MzDownX=p.x;MzDownY=p.y;MzDragged=false;e.Use();}}
            if((MzDragMode==1||MzDragMode==2)&&(e.type==EventType.MouseDrag||e.type==EventType.MouseUp)){float dx=p.x-MzDownX,dy=p.y-MzDownY;if(dx*dx+dy*dy>36)MzDragged=true;if(MzDragged){if(MzDragMode==1){MzBubbleX=Mathf.Clamp(p.x-MzDragDX,4,Screen.width/MzScale-84);MzBubbleY=Mathf.Clamp(p.y-MzDragDY,4,Screen.height/MzScale-84);}else{MzPanelX=Mathf.Clamp(p.x-MzDragDX,4,Screen.width/MzScale-386);MzPanelY=Mathf.Clamp(p.y-MzDragDY,4,Screen.height/MzScale-444);}}if(e.type==EventType.MouseUp){if(MzDragMode==1&&!MzDragged){MzOpen=!MzOpen;if(!MzAuthorized())MzTab=2;}MzDragMode=0;}e.Use();}
        }
        public static void MzPanel()
        {
            float x=MzPanelX,y=MzPanelY+12*(1-MzOpenAnim)*(1-MzOpenAnim);if(!MzAuthorized())MzTab=2;MzGlassPanel(x,y);
            if(!MzAuthorized())MzTab=2;float rowY=y+112;
            if(MzTab==0){int first=MzEspPage==0?0:6,last=MzEspPage==0?6:11;for(int i=first;i<last;i++){string label=i==0?"Bật ESP":i==1?"Khung":i==2?"Khung góc":i==3?"Khung 3D":i==4?"Tên":i==5?"Thanh máu":i==6?"Khoảng cách":i==7?"Xương":i==8?"Vòng đầu":i==9?"Trục XYZ":"Đường nối";MzToggle(i,x+14,rowY,label);rowY+=44;}if(MzEspPage==1)MzSlider(x+14,rowY,"Tầm ESP",false);float pageWidth=MzEspPage==0?354:169;MzTint(.85f,.90f,1,.12f*MzOpenAnim);MzFill(x+14,y+390,pageWidth,36,14);MzTint(.94f,.96f,1,MzOpenAnim);MzCenter(x+14,y+390,pageWidth,36,MzEspPage==0?"1 / 2   ›":"‹   2 / 2");if(MzTap(x+14,y+390,pageWidth,36))MzEspPage=1-MzEspPage;if(MzEspPage==1){MzTint(.11f,.11f,.13f,MzOpenAnim);MzFill(x+199,y+390,169,36,10);MzTint(.94f,.97f,.98f,MzOpenAnim);MzCenter(x+199,y+390,169,36,"Nối: "+(MzLineOrigin==0?"DƯỚI":MzLineOrigin==1?"GIỮA":"TRÊN"));if(MzTap(x+199,y+390,169,36))MzLineOrigin=(MzLineOrigin+1)%3;}}
            else if(MzTab==1){MzToggle(11,x+14,rowY,"Ngắm đầu · Khi bắn");MzToggle(12,x+14,rowY+44,"Silent · Khi bắn");MzToggle(13,x+14,rowY+88,"Vòng FOV");MzToggle(14,x+14,rowY+132,"Đường ngắm");MzSlider(x+14,rowY+184,"Bán kính FOV",true);MzSlider(x+14,rowY+246,"Tầm ngắm",false);}
            else if(MzTab==2)MzKeyPanel(x+14,rowY);else if(MzTab==3)MzColorPanel(x+14,rowY);else MzWeaponPanel(x+14,rowY);
        }
        public void OnGUI()
        {
            if(this==null||Event.current==null)return;var type=Event.current.type;if(type!=EventType.Repaint&&type!=EventType.MouseDown&&type!=EventType.MouseDrag&&type!=EventType.MouseUp)return;
            if(!MzOnThread()||MzInGui||gameObject==null||gameObject.name!="__mizze_driver")return;MzInGui=true;bool previousPaint=MzUiPaint;MzUiPaint=type==EventType.Repaint;var color=GUI.color;var contentColor=GUI.contentColor;var matrix=GUI.matrix;
            try {
                GUI.matrix=Matrix4x4.identity;MzLayout();MzDrag();if(MzUiPaint){GUI.contentColor=new Color(1,1,1,1);MzLicensePoll();}
                if(Event.current.type==EventType.Repaint){MzMotion=(Mathf.Sin(Time.realtimeSinceStartup*2.4f)+1)*.5f;float t=Mathf.Clamp(Time.unscaledDeltaTime*14,0,1);MzOpenAnim=MzTween(MzOpenAnim,MzOpen?1:0,t);if(MzOpen||MzOpenAnim>.02f){MzTabAnim=MzTween(MzTabAnim,MzTab,t);for(int i=0;i<17;i++)MzSwitchAnim[i]=MzTween(MzSwitchAnim[i],MzSwitch[i]?1:0,t);}if(MzAuthorized()){MzRender();int frame=Time.frameCount;if(MzLastLogicFrame!=frame){MzLastLogicFrame=frame;MzRunAim();MzWeaponPoll();}}else {MzRestoreSilent();MzRestoreWeapon();}}
                if(MzUiPaint){if(MzUiMatrixScale!=MzScale){MzUiMatrix=Matrix4x4.TRS(new Vector3(),Quaternion.Euler(0,0,0),new Vector3(MzScale,MzScale,1));MzUiMatrixScale=MzScale;}GUI.matrix=MzUiMatrix;}if(MzOpen||MzOpenAnim>.02f)MzPanel();else MzBackgroundLast=0;
                if(!MzUiPaint)return;
                float pulse=1+Mathf.Sin(Time.realtimeSinceStartup*2.4f)*.015f;MzTint(0,0,0,.20f);MzFill(MzBubbleX+3,MzBubbleY+5,80,80,40);MzTint(.80f,.88f,1,.36f);MzFill(MzBubbleX+40-40*pulse,MzBubbleY+40-40*pulse,80*pulse,80*pulse,40*pulse);MzTint(.025f,.03f,.045f,.72f);MzFill(MzBubbleX+3,MzBubbleY+3,74,74,37);MzTint(.88f,1,.97f,.28f);MzFill(MzBubbleX+22,MzBubbleY+10,36,2,1);MzTint(.97f,.98f,1,1);MzCenter(MzBubbleX,MzBubbleY,80,80,"Mizze");
            }catch(Exception e){MzLogFault("on-gui",e);}finally{GUI.color=color;GUI.contentColor=contentColor;GUI.matrix=matrix;MzUiPaint=previousPaint;MzInGui=false;}
        }
    }
}
