using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static bool MzOwnPointer,MzTouchFailed;
        public static GameObject MzTouchRoot,MzTouchPanelObject,MzTouchBubbleObject,MzTouchLagObject;
        public static BoxCollider MzTouchPanel;
        public static SphereCollider MzTouchBubble,MzTouchLag;
        public static Camera MzTouchCamera;
        public static float MzTouchNext;
        public static Vector3 MzTouchPanelPose,MzTouchBubblePose,MzTouchLagPose;
        public static float MzTouchScale;
        public static int MzTouchWidth,MzTouchHeight;
        public static bool MzTouchPanelVisible,MzTouchLagVisible;
        public static bool MzMenuHit(Vector2 p)
        {
            float dx=p.x-MzBubbleX-40,dy=p.y-MzBubbleY-40;
            return MzLagButtonHit(p)||dx*dx+dy*dy<=1600||((MzOpen||MzOpenAnim>.02f)&&new Rect(MzPanelX,MzPanelY+12*(1-MzOpenAnim)*(1-MzOpenAnim),382,440).Contains(p));
        }
        public static void MzTouchRelease()
        {
            if(MzTouchRoot!=null)UnityEngine.Object.Destroy(MzTouchRoot);
            MzTouchRoot=null;MzTouchPanelObject=null;MzTouchBubbleObject=null;MzTouchPanel=null;MzTouchBubble=null;MzTouchLagObject=null;MzTouchLag=null;MzTouchCamera=null;
        }
        public static void MzTouchSync()
        {
            if(!MzOnThread()||MzTouchFailed)return;
            try {
                var camera=UICamera.mainCamera;
                if(camera==null){if(MzTouchRoot!=null)MzTouchRelease();return;}
                if(camera!=MzTouchCamera){MzTouchRelease();MzTouchNext=0;}
                if(MzTouchRoot==null){
                    float now=Time.realtimeSinceStartup;if(now<MzTouchNext)return;MzTouchNext=now+1;
                    var root=new GameObject("__mizze_touch");MzTouchRoot=root;root.layer=camera.gameObject.layer;root.transform.SetParent(camera.transform,false);
                    var panel=root.AddComponent(typeof(UIPanel)) as UIPanel;if(panel==null)throw new Exception("Missing touch panel");panel.depth=30000;
                    var box=new GameObject("__mizze_panel_hit");MzTouchPanelObject=box;box.layer=root.layer;box.transform.SetParent(root.transform,false);
                    var widget=box.AddComponent(typeof(UIWidget)) as UIWidget;if(widget==null)throw new Exception("Missing panel widget");widget.fillGeometry=false;widget.depth=30000;
                    MzTouchPanel=box.AddComponent(typeof(BoxCollider)) as BoxCollider;if(MzTouchPanel==null)throw new Exception("Missing panel collider");
                    var bubble=new GameObject("__mizze_bubble_hit");MzTouchBubbleObject=bubble;bubble.layer=root.layer;bubble.transform.SetParent(root.transform,false);
                    var circle=bubble.AddComponent(typeof(UIWidget)) as UIWidget;if(circle==null)throw new Exception("Missing bubble widget");circle.fillGeometry=false;circle.depth=30001;
                    MzTouchBubble=bubble.AddComponent(typeof(SphereCollider)) as SphereCollider;if(MzTouchBubble==null)throw new Exception("Missing bubble collider");
                    var lag=new GameObject("__mizze_lag_hit");MzTouchLagObject=lag;lag.layer=root.layer;lag.transform.SetParent(root.transform,false);
                    var lagWidget=lag.AddComponent(typeof(UIWidget)) as UIWidget;if(lagWidget==null)throw new Exception("Missing lag widget");lagWidget.fillGeometry=false;lagWidget.depth=30002;
                    MzTouchLag=lag.AddComponent(typeof(SphereCollider)) as SphereCollider;if(MzTouchLag==null)throw new Exception("Missing lag collider");
                    MzTouchCamera=camera;MzTouchWidth=0;
                }
                bool resized=MzTouchWidth!=Screen.width||MzTouchHeight!=Screen.height||MzTouchScale!=MzScale;
                if(resized){
                    float z=camera.nearClipPlane+1;var origin=camera.ScreenToWorldPoint(new Vector3(Screen.width*.5f,Screen.height*.5f,z));
                    float sx=Vector3.Distance(origin,camera.ScreenToWorldPoint(new Vector3(Screen.width*.5f+1,Screen.height*.5f,z)));
                    float sy=Vector3.Distance(origin,camera.ScreenToWorldPoint(new Vector3(Screen.width*.5f,Screen.height*.5f+1,z)));
                    if(!MzFinite(sx)||!MzFinite(sy)||sx<=0||sy<=0)throw new Exception("Invalid touch projection");
                    MzTouchRoot.transform.localPosition=new Vector3(0,0,z);MzTouchRoot.transform.localScale=new Vector3(sx,sy,sx);
                    MzTouchPanel.size=new Vector3(382*MzScale,440*MzScale,1);MzTouchBubble.radius=40*MzScale;MzTouchLag.radius=40*MzScale;
                    var widget=MzTouchPanelObject.GetComponent(typeof(UIWidget)) as UIWidget;widget.width=(int)(382*MzScale);widget.height=(int)(440*MzScale);
                    var circle=MzTouchBubbleObject.GetComponent(typeof(UIWidget)) as UIWidget;circle.width=(int)(80*MzScale);circle.height=(int)(80*MzScale);
                    MzTouchWidth=Screen.width;MzTouchHeight=Screen.height;MzTouchScale=MzScale;var lagWidget=MzTouchLagObject.GetComponent(typeof(UIWidget)) as UIWidget;lagWidget.width=(int)(80*MzScale);lagWidget.height=(int)(80*MzScale);
                }
                var p=new Vector3((MzPanelX+191)*MzScale-Screen.width*.5f,Screen.height*.5f-(MzPanelY+220+12*(1-MzOpenAnim)*(1-MzOpenAnim))*MzScale,0);
                var b=new Vector3((MzBubbleX+40)*MzScale-Screen.width*.5f,Screen.height*.5f-(MzBubbleY+40)*MzScale,-2);
                if(resized||!MzSame(p,MzTouchPanelPose)){MzTouchPanelObject.transform.localPosition=p;MzTouchPanelPose=p;}
                if(resized||!MzSame(b,MzTouchBubblePose)){MzTouchBubbleObject.transform.localPosition=b;MzTouchBubblePose=b;}
                var l=new Vector3((MzLagX+40)*MzScale-Screen.width*.5f,Screen.height*.5f-(MzLagY+40)*MzScale,-3);
                if(resized||!MzSame(l,MzTouchLagPose)){MzTouchLagObject.transform.localPosition=l;MzTouchLagPose=l;}
                bool lagVisible=MzLagButtonVisible();if(resized||lagVisible!=MzTouchLagVisible){MzTouchLag.enabled=lagVisible;MzTouchLagVisible=lagVisible;}
                bool visible=MzOpen||MzOpenAnim>.02f;if(resized||visible!=MzTouchPanelVisible){MzTouchPanel.enabled=visible;MzTouchPanelVisible=visible;}
            }catch(Exception e){MzTouchRelease();MzTouchFailed=true;MzLogFault("menu-touch",e);}
        }
    }
}
