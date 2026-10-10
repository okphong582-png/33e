using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool:Component
    {
        // These fields are stored inside IFix VM, separate from game state.
        public static bool MzInitialized,MzOpen,MzDragged;
        public static float MzBubbleX,MzBubbleY,MzPanelX,MzPanelY,MzOpenAnim,MzDragDX,MzDragDY,MzDownX,MzDownY,MzFov,MzRange;
        public static int MzDragMode,MzTab,MzEspPage,MzLineOrigin;
        public static bool[] MzSwitch;
        public static float[] MzSwitchAnim;
        // ESP, box, corners, 3D, name, health, distance, skeleton, head, XYZ, line,
        // aim head on fire, silent on fire, FOV circle, aim target line.
        public static void MzEnsure()
        {
            try {
                if(!MzInitialized){MzSwitch=new bool[15];MzSwitchAnim=new float[15];MzSwitch[0]=true;MzSwitch[1]=true;MzSwitch[2]=true;MzSwitch[4]=true;MzSwitch[5]=true;MzSwitch[6]=true;MzSwitch[13]=true;MzFov=150;MzRange=150;MzBubbleX=24;MzBubbleY=96;MzPanelX=98;MzPanelY=30;MzInitialized=true;try{MzLicenseInit();}catch(Exception){MzLicenseMessage="Loi khoi tao key. Thu nhap lai";}}
                var g=GameObject.Find("__mizze_driver");if(g==null)g=new GameObject("__mizze_driver");if(g.GetComponent(typeof(SceneEditBoxSelectTool))==null)g.AddComponent(typeof(SceneEditBoxSelectTool));UnityEngine.Object.DontDestroyOnLoad(g);
            } catch(Exception){}
        }
        public static bool MzFinite(float f){return !Single.IsNaN(f)&&!Single.IsInfinity(f);}
        public static bool MzPoint(Vector3 p){return MzFinite(p.x)&&MzFinite(p.y)&&MzFinite(p.z);}
        public static void MzTint(float r,float g,float b,float a){GUI.color=new Color(r,g,b,a);}
        public static void MzFill(float x,float y,float w,float h,float radius){GUI.DrawTexture(new Rect(x,y,w,h),Texture2D.whiteTexture,ScaleMode.StretchToFill,true,0,new Color(1,1,1,1),0,radius);}
        public static void MzText(float x,float y,float w,string s){GUI.Label(new Rect(x,y,w,25),s);}
        public static void MzLine(float ax,float ay,float bx,float by,float width)
        {
            if(!MzFinite(ax)||!MzFinite(ay)||!MzFinite(bx)||!MzFinite(by))return;
            float dx=bx-ax,dy=by-ay,length=Mathf.Sqrt(dx*dx+dy*dy);if(length<.5f||length>Screen.width*3)return;var old=GUI.matrix;
            try {GUI.matrix=Matrix4x4.TRS(new Vector3(ax,ay,0),Quaternion.Euler(0,0,Mathf.Atan2(dy,dx)*57.29578f),new Vector3(1,1,1));GUI.DrawTexture(new Rect(0,-width*.5f,length,width),Texture2D.whiteTexture);}
            finally {GUI.matrix=old;}
        }
        public static void MzCircle(float cx,float cy,float radius,float width){float lastX=cx+radius,lastY=cy;for(int i=1;i<=48;i++){float a=i*.1308997f,x=cx+Mathf.Cos(a)*radius,y=cy+Mathf.Sin(a)*radius;MzLine(lastX,lastY,x,y,width);lastX=x;lastY=y;}}
        public static bool MzTap(float x,float y,float w,float h){var e=Event.current;if(!MzOpen||e==null||e.type!=EventType.MouseUp||MzDragMode!=0)return false;if(!new Rect(x,y,w,h).Contains(e.mousePosition))return false;e.Use();return true;}
        public static void MzToggle(int id,float x,float y,string title)
        {
            float a=MzSwitchAnim[id];MzTint(.11f,.15f,.22f,.98f);MzFill(x,y,354,43,12);MzTint(.88f,.94f,.97f,1);MzText(x+13,y+12,275,title);
            MzTint(.16f+.12f*a,.22f+.56f*a,.29f+.36f*a,1);MzFill(x+294,y+10,46,24,12);MzTint(1,1,1,1);MzFill(x+297+22*a,y+13,18,18,9);
            if(MzTap(x,y,354,43)){MzSwitch[id]=!MzSwitch[id];if(id==11&&MzSwitch[id])MzSwitch[12]=false;if(id==12&&MzSwitch[id])MzSwitch[11]=false;if(id==2&&MzSwitch[id])MzSwitch[3]=false;if(id==3&&MzSwitch[id])MzSwitch[2]=false;if(id==11||id==12)MzRestoreSilent();}
        }
        public static void MzSlider(float x,float y,string title,bool fov)
        {
            float min=fov?20:50,max=fov?480:500,value=fov?MzFov:MzRange;MzTint(.88f,.94f,.97f,1);MzText(x,y,350,title+"  "+((int)value).ToString()+(fov?" px":" m"));
            var e=Event.current;if(MzOpen&&e.type==EventType.MouseDown&&new Rect(x,y+22,354,36).Contains(e.mousePosition))MzDragMode=fov?3:4;
            if(MzDragMode==(fov?3:4)&&(e.type==EventType.MouseDown||e.type==EventType.MouseDrag||e.type==EventType.MouseUp)){value=min+Mathf.Clamp((e.mousePosition.x-x)/354,0,1)*(max-min);if(fov)MzFov=value;else MzRange=value;if(e.type==EventType.MouseUp)MzDragMode=0;e.Use();}
            MzTint(.17f,.23f,.31f,1);MzFill(x,y+33,354,6,3);MzTint(.35f,.86f,.72f,1);MzFill(x,y+33,354*(value-min)/(max-min),6,3);MzFill(x+354*(value-min)/(max-min)-9,y+27,18,18,9);
        }
        public static void MzDrag()
        {
            var e=Event.current;Vector2 p=e.mousePosition;
            if(e.type==EventType.MouseDown&&MzDragMode==0){float dx=p.x-MzBubbleX-32,dy=p.y-MzBubbleY-32;if(dx*dx+dy*dy<=1024){MzDragMode=1;MzDragDX=p.x-MzBubbleX;MzDragDY=p.y-MzBubbleY;}else if(MzOpen&&new Rect(MzPanelX,MzPanelY,320,56).Contains(p)){MzDragMode=2;MzDragDX=p.x-MzPanelX;MzDragDY=p.y-MzPanelY;}if(MzDragMode>0){MzDownX=p.x;MzDownY=p.y;MzDragged=false;e.Use();}}
            if((MzDragMode==1||MzDragMode==2)&&(e.type==EventType.MouseDrag||e.type==EventType.MouseUp)){float dx=p.x-MzDownX,dy=p.y-MzDownY;if(dx*dx+dy*dy>36)MzDragged=true;if(MzDragged){if(MzDragMode==1){MzBubbleX=Mathf.Clamp(p.x-MzDragDX,4,Screen.width-68);MzBubbleY=Mathf.Clamp(p.y-MzDragDY,4,Screen.height-68);}else{MzPanelX=Mathf.Clamp(p.x-MzDragDX,4,Screen.width-390);MzPanelY=Mathf.Clamp(p.y-MzDragDY,4,Screen.height-496);}}if(e.type==EventType.MouseUp){if(MzDragMode==1&&!MzDragged){MzOpen=!MzOpen;if(!MzAuthorized())MzTab=2;}MzDragMode=0;}e.Use();}
        }
        public static void MzPanel()
        {
            float x=MzPanelX,y=MzPanelY;MzTint(.01f,.02f,.04f,.36f*MzOpenAnim);MzFill(x+5,y+7,382,488,24);MzTint(.055f,.075f,.11f,MzOpenAnim);MzFill(x,y,382,488,22);MzTint(.09f,.15f,.20f,MzOpenAnim);MzFill(x+10,y+10,362,54,16);MzTint(.38f,.91f,.77f,MzOpenAnim);MzText(x+24,y+24,245,"Mizze   /   FREE FIRE TH");MzTint(.75f,.84f,.9f,MzOpenAnim);MzText(x+342,y+24,24,"x");if(MzTap(x+326,y+10,46,48)){MzOpen=false;MzDragMode=0;}
            for(int i=0;i<3;i++){MzTint(MzTab==i?.19f:.1f,MzTab==i?.39f:.15f,MzTab==i?.35f:.20f,1);MzFill(x+14+i*119,y+77,114,37,11);MzTint(.85f,.96f,.92f,1);MzText(x+51+i*119,y+88,74,i==0?"ESP":i==1?"AIM":"KEY");if(MzTap(x+14+i*119,y+77,114,37))MzTab=MzAuthorized()?i:2;}
            if(!MzAuthorized())MzTab=2;float rowY=y+127;
            if(MzTab==0){int first=MzEspPage==0?0:6,last=MzEspPage==0?6:11;for(int i=first;i<last;i++){string label=i==0?"Bat ESP":i==1?"Khung nguoi choi":i==2?"Khung goc manh":i==3?"Khung 3D":i==4?"Ten nguoi choi":i==5?"Thanh mau":i==6?"Khoang cach":i==7?"Xuong nguoi choi":i==8?"Diem danh dau dau":i==9?"Truc XYZ":"Duong noi muc tieu";MzToggle(i,x+14,rowY,label);rowY+=48;}if(MzEspPage==1)MzSlider(x+14,rowY,"Tam hien thi",false);MzTint(.17f,.29f,.34f,1);MzFill(x+14,y+423,354,38,11);MzTint(.85f,.97f,.95f,1);MzText(x+130,y+433,210,MzEspPage==0?"Tiep   1 / 2":"Truoc   2 / 2");if(MzTap(x+14,y+423,354,38))MzEspPage=1-MzEspPage;}
            else if(MzTab==1){MzToggle(11,x+14,rowY,"Aimbot khi ban / dau");MzToggle(12,x+14,rowY+48,"Silent aim khi ban");MzToggle(13,x+14,rowY+96,"Hien vong FOV");MzToggle(14,x+14,rowY+144,"Day toi muc tieu aim");MzSlider(x+14,rowY+200,"Kich co FOV",true);MzSlider(x+14,rowY+266,"Tam chon muc tieu",false);MzTint(.65f,.76f,.84f,1);MzText(x+14,y+452,354,"Aim chi kich hoat khi ban.");}
            else MzKeyPanel(x+14,rowY);
            if(MzTab==0&&MzEspPage==1){MzTint(.65f,.8f,.85f,1);MzText(x+70,y+465,300,"Goc duong noi: "+(MzLineOrigin==0?"DUOI":MzLineOrigin==1?"GIUA":"TREN")+"  >");if(MzTap(x+14,y+463,354,24))MzLineOrigin=(MzLineOrigin+1)%3;}
        }
        public void OnGUI()
        {
            if(this==null||Event.current==null||gameObject==null||gameObject.name!="__mizze_driver")return;var color=GUI.color;var matrix=GUI.matrix;
            try {
                GUI.matrix=Matrix4x4.identity;MzLicensePoll();MzDrag();
                if(Event.current.type==EventType.Repaint){float t=Mathf.Clamp(Time.unscaledDeltaTime*14,0,1);MzOpenAnim=Mathf.Lerp(MzOpenAnim,MzOpen?1:0,t);for(int i=0;i<15;i++)MzSwitchAnim[i]=Mathf.Lerp(MzSwitchAnim[i],MzSwitch[i]?1:0,t);if(MzAuthorized()){MzRender();MzRunAim();}else MzRestoreSilent();}
                if(MzOpen||MzOpenAnim>.02f)MzPanel();float pulse=1+Mathf.Sin(Time.realtimeSinceStartup*2.4f)*.025f;MzTint(.02f,.04f,.07f,.5f);MzFill(MzBubbleX+2,MzBubbleY+4,64,64,32);MzTint(.1f,.32f,.30f,1);MzFill(MzBubbleX+32-30*pulse,MzBubbleY+32-30*pulse,60*pulse,60*pulse,30*pulse);MzTint(.5f,1,.85f,1);MzText(MzBubbleX+13,MzBubbleY+23,54,"Mizze");
            }catch(Exception){}finally{GUI.color=color;GUI.matrix=matrix;}
        }
    }
}
