using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static Texture2D[] MzBackgroundFrames;
        public static string[] MzBackgroundEncoded;
        public static int MzBackgroundLoaded;
        public static bool MzBackgroundFailed;
        public static float MzBackgroundClock,MzBackgroundLast,MzBackgroundNextLoad;
        public static void MzBackground(float x,float y)
        {
            if(!MzUiPaint)return;
            float now=Time.realtimeSinceStartup;
            if(MzOpen){
                if(MzBackgroundLast>0){float elapsed=now-MzBackgroundLast;if(elapsed>=0&&elapsed<.2f)MzBackgroundClock+=elapsed;}
                MzBackgroundLast=now;
                if(!MzBackgroundFailed&&MzBackgroundLoaded<15&&now>=MzBackgroundNextLoad){
                    Texture2D texture=null;
                    try{
                        if(MzBackgroundFrames==null){MzBackgroundFrames=new Texture2D[15];MzBackgroundEncoded=MzBackgroundData();}
                        texture=new Texture2D(2,2,TextureFormat.RGBA32,false);
                        byte[] data=Convert.FromBase64String(MzBackgroundEncoded[MzBackgroundLoaded]);
                        if(!ImageConversion.LoadImage(texture,data,true))throw new Exception("Không đọc được nền động");
                        texture.filterMode=FilterMode.Bilinear;texture.wrapMode=TextureWrapMode.Clamp;
                        MzBackgroundFrames[MzBackgroundLoaded]=texture;MzBackgroundEncoded[MzBackgroundLoaded]=null;MzBackgroundLoaded++;
                        if(MzBackgroundLoaded==15)MzBackgroundEncoded=null;
                    }catch(Exception e){if(texture!=null)UnityEngine.Object.Destroy(texture);MzBackgroundEncoded=null;MzBackgroundFailed=true;MzLogFault("menu-background",e);}
                    MzBackgroundNextLoad=now+.04f;
                }
            }else MzBackgroundLast=0;
            if(MzBackgroundLoaded==0)return;
            // Original GIF timing: 170,160,170 ms repeated; a complete loop is 2.5 s.
            float cycle=MzBackgroundClock%2.5f;int group=(int)(cycle/.5f);float part=cycle-group*.5f;int index=group*3+(part<.17f?0:part<.33f?1:2);
            if(index>=MzBackgroundLoaded)index=0;
            var frame=MzBackgroundFrames[index];if(frame==null)return;
            MzTint(1,1,1,.62f*MzOpenAnim);GUI.DrawTexture(new Rect(x,y,382,440),frame);
        }
        public static void MzGlassPanel(float x,float y)
        {
            MzTint(0,0,0,.07f*MzOpenAnim);MzFill(x-7,y+2,396,454,31);
            MzTint(0,0,0,.13f*MzOpenAnim);MzFill(x-3,y+3,388,448,27);
            MzTint(.82f,.88f,1,.18f*MzOpenAnim);MzFill(x-1,y-1,384,442,25);
            MzTint(.025f,.03f,.045f,.85f*MzOpenAnim);MzFill(x,y,382,440,24);
            MzBackground(x,y);
            MzTint(.018f,.022f,.032f,.56f*MzOpenAnim);MzFill(x,y,382,440,24);
            MzTint(.90f,.95f,1,.06f*MzOpenAnim);MzFill(x+2,y+2,378,65,23);
            MzTint(1,1,1,.21f*MzOpenAnim);MzFill(x+25,y+1,332,1,0);
            MzTint(.88f,.94f,1,(.13f+.05f*MzMotion)*MzOpenAnim);MzFill(x+41+MzMotion*70,y+3,146,1,0);
            MzTint(.97f,.98f,1,MzOpenAnim);MzTitle(x+23,y+11,180,"Mizze");
            MzTint(.75f,.78f,.83f,.88f*MzOpenAnim);MzSmall(x+24,y+39,290,MzMemoryPaused?"Giảm tải · Bộ nhớ cao":MzEspBlocked?"ESP tạm dừng · Bật lại để thử":"GLASS  /  iOS");
            MzTint(1,1,1,.06f*MzOpenAnim);MzFill(x+330,y+18,30,30,15);
            MzTint(.9f,.92f,.95f,MzOpenAnim);MzCenter(x+326,y+10,46,48,"×");
            if(MzTap(x+326,y+10,46,48)){MzOpen=false;MzDragMode=0;MzBackgroundLast=0;}
            MzTint(.015f,.018f,.025f,.65f*MzOpenAnim);MzFill(x+12,y+68,358,36,18);
            MzTint(1,1,1,.08f*MzOpenAnim);MzFill(x+13,y+69,356,1,0);
            MzTint(1,1,1,.93f*MzOpenAnim);MzFill(x+14+MzTabAnim*71,y+71,69,30,15);
            for(int i=0;i<5;i++){
                float active=Mathf.Clamp(1-Math.Abs(MzTabAnim-i),0,1);
                MzTint(.72f-.65f*active,.74f-.66f*active,.78f-.68f*active,MzOpenAnim);
                MzCenter(x+14+i*71,y+70,69,32,i==0?"ESP":i==1?"Aim":i==2?"Khóa":i==3?"Màu":"Súng");
                if(MzTap(x+14+i*71,y+70,69,32))MzTab=MzAuthorized()?i:2;
            }
        }
    }
}
