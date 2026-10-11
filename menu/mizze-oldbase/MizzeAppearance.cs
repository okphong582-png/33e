using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static Color MzEspColor,MzFovColor,MzHealthColor;
        public static Color[] MzPalette;
        public static int MzColorTarget;
        public static GUIStyle MzSmallStyle,MzTitleStyle;
        public static float MzMotion;
        public static void MzAppearanceInit()
        {
            MzPalette=new Color[18];
            MzPalette[0]=new Color(.4f,.92f,.79f,1);MzPalette[1]=new Color(.3f,.65f,1,1);MzPalette[2]=new Color(.62f,.44f,1,1);MzPalette[3]=new Color(1,.4f,.66f,1);MzPalette[4]=new Color(1,.32f,.32f,1);MzPalette[5]=new Color(1,.72f,.28f,1);
            MzPalette[6]=new Color(.25f,1,.48f,1);MzPalette[7]=new Color(.2f,.9f,1,1);MzPalette[8]=new Color(.88f,.4f,1,1);MzPalette[9]=new Color(1,.64f,.82f,1);MzPalette[10]=new Color(1,.54f,.3f,1);MzPalette[11]=new Color(1,.95f,.35f,1);
            MzPalette[12]=new Color(.7f,1,.84f,1);MzPalette[13]=new Color(.65f,.82f,1,1);MzPalette[14]=new Color(.82f,.7f,1,1);MzPalette[15]=new Color(1,.84f,.9f,1);MzPalette[16]=new Color(1,1,1,1);MzPalette[17]=new Color(.68f,.72f,.8f,1);
            MzEspColor=MzLoadColor("ESP",MzPalette[0]);MzFovColor=MzLoadColor("FOV",MzPalette[7]);MzHealthColor=MzLoadColor("HP",MzPalette[6]);
        }
        public static Color MzLoadColor(string key,Color fallback)
        {
            try{string s=PlayerPrefs.GetString("Mizze.Color."+key,"");if(s.Length!=6)return fallback;int n=Convert.ToInt32(s,16);return new Color(((n>>16)&255)/255f,((n>>8)&255)/255f,(n&255)/255f,1);}catch(Exception){return fallback;}
        }
        public static string MzColorHex(Color c){return ((int)(Mathf.Clamp(c.r,0,1)*255)).ToString("X2")+((int)(Mathf.Clamp(c.g,0,1)*255)).ToString("X2")+((int)(Mathf.Clamp(c.b,0,1)*255)).ToString("X2");}
        public static Color MzSelectedColor(){return MzColorTarget==0?MzEspColor:MzColorTarget==1?MzFovColor:MzHealthColor;}
        public static void MzSetColor(Color color,bool save)
        {
            color=new Color(Mathf.Clamp(color.r,0,1),Mathf.Clamp(color.g,0,1),Mathf.Clamp(color.b,0,1),1);
            MzNextEsp=0;if(MzColorTarget==0)MzEspColor=color;else if(MzColorTarget==1)MzFovColor=color;else MzHealthColor=color;
            if(save)PlayerPrefs.SetString("Mizze.Color."+(MzColorTarget==0?"ESP":MzColorTarget==1?"FOV":"HP"),MzColorHex(color));
        }
        public static void MzTitle(float x,float y,float w,string text)
        {
            if(!MzUiPaint)return;
            if(MzTitleStyle==null){var style=new GUIStyle();style.fontSize=25;style.wordWrap=false;style.alignment=TextAnchor.MiddleLeft;style.normal.textColor=new Color(1,1,1,1);MzTitleStyle=style;}GUI.Label(new Rect(x,y,w,32),text,MzTitleStyle);
        }
        public static void MzSmall(float x,float y,float w,string text)
        {
            if(!MzUiPaint)return;
            if(MzSmallStyle==null){var style=new GUIStyle();style.fontSize=16;style.wordWrap=false;style.alignment=TextAnchor.MiddleLeft;style.normal.textColor=new Color(1,1,1,1);MzSmallStyle=style;}
            GUI.Label(new Rect(x,y,w,22),text,MzSmallStyle);
        }
        public static void MzColorSlider(int channel,float x,float y,string label)
        {
            Color c=MzSelectedColor();float value=channel==0?c.r:channel==1?c.g:c.b;MzTint(.85f,.89f,.95f,MzOpenAnim);MzSmall(x,y,80,label+" "+((int)(value*255)).ToString());
            var e=Event.current;int mode=5+channel;
            if(MzOpen&&e.type==EventType.MouseDown&&new Rect(x+84,y-2,270,28).Contains(MzPointer)){MzDragMode=mode;e.Use();}
            if(MzDragMode==mode&&(e.type==EventType.Used||e.type==EventType.MouseDrag||e.type==EventType.MouseUp)){
                bool save=e.type==EventType.MouseUp;value=Mathf.Clamp((MzPointer.x-x-84)/270,0,1);if(channel==0)c.r=value;else if(channel==1)c.g=value;else c.b=value;MzSetColor(c,save);if(save)MzDragMode=0;e.Use();
            }
            MzTint(.15f,.16f,.20f,MzOpenAnim);MzFill(x+84,y+9,270,4,2);MzTint(channel==0?1:.4f,channel==1?1:.4f,channel==2?1:.4f,MzOpenAnim);MzFill(x+84,y+9,270*value,4,2);MzFill(x+84+270*value-7,y+4,14,14,7);
        }
        public static void MzColorPanel(float x,float y)
        {
            for(int i=0;i<3;i++){MzTint(MzColorTarget==i?.13f:.07f,MzColorTarget==i?.22f:.075f,MzColorTarget==i?.24f:.09f,.52f*MzOpenAnim);MzFill(x+i*120,y,114,34,11);MzTint(.92f,.97f,1,MzOpenAnim);MzCenter(x+i*120,y,114,34,i==0?"Màu ESP":i==1?"Màu FOV":"Máu");if(MzTap(x+i*120,y,114,34))MzColorTarget=i;}
            Color selected=MzSelectedColor();MzTint(.10f,.15f,.19f,.32f*MzOpenAnim);MzFill(x,y+44,354,40,12);GUI.color=new Color(selected.r,selected.g,selected.b,MzOpenAnim);MzFill(x+10,y+52,24,24,8);MzSmall(x+46,y+53,296,"#"+MzColorHex(selected)+"   •   Màu đã chọn");
            for(int i=0;i<18;i++){float px=x+(i%6)*60,py=y+94+(i/6)*39;Color c=MzPalette[i];bool active=Math.Abs(selected.r-c.r)<.006f&&Math.Abs(selected.g-c.g)<.006f&&Math.Abs(selected.b-c.b)<.006f;
                if(active){MzTint(1,1,1,MzOpenAnim);MzFill(px-2-MzMotion,py-2-MzMotion,56+2*MzMotion,35+2*MzMotion,10);}GUI.color=new Color(c.r,c.g,c.b,MzOpenAnim);MzFill(px,py,52,31,8);if(MzTap(px,py,52,31))MzSetColor(c,true);
            }
            MzColorSlider(0,x,y+221,"Đỏ");MzColorSlider(1,x,y+254,"Lục");MzColorSlider(2,x,y+287,"Lam");
        }
    }
}
