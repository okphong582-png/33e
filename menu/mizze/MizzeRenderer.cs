using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static Texture2D MzRing,MzHeadRing;
        public static Texture2D MzWhite;
        public static Rect[] MzRects;
        public static Color[] MzColors;
        public static Matrix4x4[] MzMatrices;
        public static string[] MzTexts;
        public static Texture[] MzTextures;
        public static bool[] MzRotated;
        public static int MzCommandCount,MzEspWidth,MzEspHeight;
        public static bool MzBuilding,MzInRender,MzEspBlocked,MzSampleFaulted;
        public static int MzEspFailures,MzSampleFailures;
        public static float MzNextEsp,MzEspSampleStarted;
        public static JMAGGLCNGIG MzEspMatch;
        public static Camera MzEspCamera;
        public static float MzFovMaximum()
        {
            float value=Screen.height*.5f-8,wide=Screen.width*.5f-8;if(value>wide)value=wide;if(value>480)value=480;if(value<20)value=20;return value;
        }
        public static float MzEffectiveFov(){return Mathf.Clamp(MzFov,20,MzFovMaximum());}
        public static Texture2D MzCreateRing(int size,float thickness)
        {
            var pixels=new Color[size*size];float mid=size*.5f,radius=mid-2,inner=radius-thickness;
            // Only the narrow boundary needs a square root. The transparent centre and
            // outside are skipped; this texture is generated once, never per frame.
            float outerSquare=(radius+1)*(radius+1),innerSquare=(inner-1)*(inner-1);
            for(int y=0;y<size;y++)for(int x=0;x<size;x++){
                float dx=x+.5f-mid,dy=y+.5f-mid,square=dx*dx+dy*dy;if(square<innerSquare||square>outerSquare)continue;
                float distance=Mathf.Sqrt(square),alpha=Mathf.Clamp(radius+.5f-distance,0,1)*Mathf.Clamp(distance-inner+.5f,0,1);
                pixels[y*size+x]=new Color(1,1,1,alpha);
            }
            Texture2D texture=null;
            try{texture=new Texture2D(size,size,TextureFormat.RGBA32,false);texture.filterMode=FilterMode.Bilinear;texture.wrapMode=TextureWrapMode.Clamp;texture.SetPixels(pixels);texture.Apply(false,true);return texture;}
            catch(Exception){if(texture!=null)UnityEngine.Object.Destroy(texture);throw;}
        }
        public static void MzRendererInit()
        {
            if(MzWhite==null)MzWhite=Texture2D.whiteTexture;if(MzRects==null){MzRects=new Rect[192];MzColors=new Color[192];MzMatrices=new Matrix4x4[192];MzTexts=new string[192];MzTextures=new Texture[192];MzRotated=new bool[192];}
        }
        public static void MzClearCommands()
        {
            MzTrimCommands(0);
        }
        public static void MzTrimCommands(int count)
        {
            for(int i=count;i<MzCommandCount;i++){MzTexts[i]=null;MzTextures[i]=null;}MzCommandCount=count;
        }
        public static void MzCommand(Rect rect,Matrix4x4 matrix,bool rotated,string text,Texture texture)
        {
            if(MzCommandCount>=192)return;int i=MzCommandCount++;MzRects[i]=rect;MzColors[i]=GUI.color;MzMatrices[i]=matrix;MzRotated[i]=rotated;MzTexts[i]=text;MzTextures[i]=texture;
        }
        public static void MzDrawCommands()
        {
            var matrix=GUI.matrix;var tint=GUI.color;bool previous=false;var identity=Matrix4x4.identity;
            var rects=MzRects;var colors=MzColors;var matrices=MzMatrices;var turns=MzRotated;var texts=MzTexts;var textures=MzTextures;int count=MzCommandCount;
            try{MzStyles();var style=MzLabelStyle;for(int i=0;i<count;i++){
                bool rotated=turns[i];if(rotated||previous)GUI.matrix=rotated?matrices[i]:identity;previous=rotated;GUI.color=colors[i];
                if(texts[i]!=null)GUI.Label(rects[i],texts[i],style);else {var texture=textures[i];if(texture!=null)GUI.DrawTexture(rects[i],texture);}
            }}finally{GUI.matrix=matrix;GUI.color=tint;}
        }
        public static void MzRender()
        {
            if(!MzOnThread()||MzInRender||MzEspBlocked)return;MzInRender=true;
            try{
                if(!MzSwitch[0]&&!MzSwitch[13]){if(MzRects!=null)MzClearCommands();return;}
                var match=COW.GameFacade.CurrentMatch();var camera=Camera.main;
                if(match==null||camera==null){if(MzRects!=null)MzClearCommands();MzEspMatch=null;MzEspCamera=null;MzNextEsp=0;return;}
                var local=COW.GameFacade.GetLocalPlayerOrObServer();
                if(local==null||!local.IsLocalPlayer()||local.CurHP<=0||local.gameObject==null||!local.gameObject.activeInHierarchy||MzCachedNode(local.IIPBIDIBJDK)==null||MzCachedNode(local.GBKFHDFCPMD)==null){if(MzRects!=null)MzClearCommands();MzEspMatch=null;MzEspCamera=null;MzNextEsp=0;return;}
                MzRendererInit();if(MzSwitch[13]&&MzRing==null)MzRing=MzCreateRing(256,1.5f);if(MzSwitch[0]&&MzSwitch[8]&&MzHeadRing==null)MzHeadRing=MzCreateRing(32,3);float now=Time.realtimeSinceStartup;
                bool changed=!System.Object.ReferenceEquals(match,MzEspMatch)||camera!=MzEspCamera||MzEspWidth!=Screen.width||MzEspHeight!=Screen.height;
                if(changed){MzClearCommands();MzNextEsp=0;MzEspMatch=match;MzEspCamera=camera;MzEspWidth=Screen.width;MzEspHeight=Screen.height;}
                if(MzSwitch[0]){
                    if(now>=MzNextEsp){MzClearCommands();MzBuilding=true;MzEspSampleStarted=now;
                        try{MzSampleEsp();if(MzSampleFaulted){MzClearCommands();MzSampleFailures++;if(MzSampleFailures>=3){MzEspBlocked=true;MzSwitch[0]=false;}}else MzSampleFailures=0;}finally{MzBuilding=false;float cost=Time.realtimeSinceStartup-now;MzNextEsp=Time.realtimeSinceStartup+(MzSampleFaulted?.5f:cost>.008f?.066f:.033f);}
                    }
                    MzDrawCommands();
                }else MzClearCommands();
                // FOV is one square, unrotated draw. Its outline cannot run out of a
                // per-enemy segment budget and scales equally on both axes.
                if(MzSwitch[13]){GUI.color=MzFovColor;MzCircle(Screen.width*.5f,Screen.height*.5f,MzEffectiveFov(),1.5f);}
                MzEspFailures=0;
            }catch(Exception e){MzBuilding=false;MzDrawingEsp=false;if(MzRects!=null)MzClearCommands();MzNextEsp=Time.realtimeSinceStartup+.25f;MzLogFault("esp-render",e);MzEspFailures++;if(MzEspFailures>=3){MzEspBlocked=true;MzSwitch[0]=false;}}finally{MzInRender=false;}
        }
    }
}
