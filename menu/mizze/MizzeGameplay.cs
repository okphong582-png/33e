using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static bool MzInSilent;
        public static CGKJLKPMGDJ MzChangedAim;
        public static Player MzAimOwner;
        public static GameObject MzAppliedObject;
        public static Collider MzAppliedCollider;
        public static GameObject MzOldAimObject;
        public static Collider MzOldAimCollider;
        public static Vector3 MzOldHpc,MzOldDoj,MzOldDirection,MzOldOrigin,MzOldOnm,MzAppliedPoint,MzAppliedDirection,MzAppliedOrigin;
        public static bool MzOldDkp,MzOldEfm,MzOldCeo,MzOldClo;
        public static bool MzEnemy(Player p){return p!=null&&!p.IsLocalPlayer()&&p.CurHP>0&&!p.IsLocalTeammate(false)&&!p.IsLocalTeammate(true)&&p.gameObject!=null&&p.gameObject.activeInHierarchy&&p.RootTransform!=null&&p.GetHeadTF()!=null;}
        public static bool MzProject(Camera cam,Vector3 world,out Vector2 screen){screen=new Vector2();if(!MzPoint(world))return false;Vector3 p=cam.WorldToScreenPoint(world);if(!MzPoint(p)||p.z<=0)return false;screen=new Vector2(p.x,Screen.height-p.y);return true;}
        public static void MzWorldLine(Camera cam,Vector3 a,Vector3 b,float width){Vector2 x,y;if(MzProject(cam,a,out x)&&MzProject(cam,b,out y))MzLine(x.x,x.y,y.x,y.y,width);}
        public static void MzBone(Camera cam,Transform a,Transform b){if(a!=null&&b!=null)MzWorldLine(cam,a.position,b.position,1.5f);}
        public static void MzBox(float x,float y,float w,float h)
        {
            if(MzSwitch[2]){float cw=w*.25f,ch=h*.2f;MzLine(x,y,x+cw,y,1.5f);MzLine(x,y,x,y+ch,1.5f);MzLine(x+w-cw,y,x+w,y,1.5f);MzLine(x+w,y,x+w,y+ch,1.5f);MzLine(x,y+h,x+cw,y+h,1.5f);MzLine(x,y+h-ch,x,y+h,1.5f);MzLine(x+w-cw,y+h,x+w,y+h,1.5f);MzLine(x+w,y+h-ch,x+w,y+h,1.5f);}
            else {MzLine(x,y,x+w,y,1.5f);MzLine(x,y+h,x+w,y+h,1.5f);MzLine(x,y,x,y+h,1.5f);MzLine(x+w,y,x+w,y+h,1.5f);}
        }
        public static void MzBox3D(Camera cam,Vector3 root,Vector3 head)
        {
            float half=Mathf.Clamp((head.y-root.y)*.22f,.15f,1);Vector3 a=new Vector3(root.x-half,root.y,root.z-half),b=new Vector3(root.x+half,root.y,root.z-half),c=new Vector3(root.x+half,root.y,root.z+half),d=new Vector3(root.x-half,root.y,root.z+half),up=new Vector3(0,head.y-root.y,0);
            MzWorldLine(cam,a,b,1.5f);MzWorldLine(cam,b,c,1.5f);MzWorldLine(cam,c,d,1.5f);MzWorldLine(cam,d,a,1.5f);MzWorldLine(cam,a+up,b+up,1.5f);MzWorldLine(cam,b+up,c+up,1.5f);MzWorldLine(cam,c+up,d+up,1.5f);MzWorldLine(cam,d+up,a+up,1.5f);MzWorldLine(cam,a,a+up,1.5f);MzWorldLine(cam,b,b+up,1.5f);MzWorldLine(cam,c,c+up,1.5f);MzWorldLine(cam,d,d+up,1.5f);
        }
        public static void MzSampleEsp()
        {
            MzDrawingEsp=true;MzDrawBudget=192;
            try {
                var cam=MzEspCamera;var match=MzEspMatch;if(cam==null||match==null)return;
                var cameraTransform=cam.transform;if(cameraTransform==null)return;Vector3 cameraPosition=cameraTransform.position;if(!MzPoint(cameraPosition))return;
                if(!MzSwitch[0])return;var players=match.ILPNGCMEFFI();if(players==null)return;int count=players.Count;if(count>64)count=64;int shown=0,limit=MzVisibleLimit();
                for(int i=0;i<count&&shown<limit&&MzCommandCount+32<=192;i++){
                    if(i>0&&Time.realtimeSinceStartup-MzEspSampleStarted>.004f)break;
                    int before=MzCommandCount;
                    // The native roster can shrink during a scene/round change. No transform is retained across frames.
                    try {
                        if(i>=players.Count)break;var p=players[i] as Player;if(p==null||p.IsLocalPlayer()||p.IsLocalTeammate(false)||p.IsLocalTeammate(true))continue;
                        var obj=p.gameObject;if(obj==null||!obj.activeInHierarchy)continue;int hp=p.CurHP;if(hp<=0)continue;
                        var rootTransform=p.RootTransform;var headTransform=p.GetHeadTF();if(rootTransform==null||headTransform==null)continue;
                        Vector3 root=rootTransform.position,head=headTransform.position;if(!MzPoint(root)||!MzPoint(head))continue;float distance=Vector3.Distance(root,cameraPosition);if(!MzFinite(distance)||distance>MzRange)continue;
                        Vector2 feet,top;if(!MzProject(cam,root,out feet)||!MzProject(cam,head,out top))continue;
                        float h=feet.y-top.y,w=h*.5f,x=(feet.x+top.x)*.5f-w*.5f,y=top.y;if(!MzFinite(h)||h<=4||h>Screen.height*2||x+w<0||x>Screen.width||y+h<0||y>Screen.height)continue;shown++;
                        GUI.color=MzEspColor;if(MzSwitch[1]){if(MzSwitch[3])MzBox3D(cam,root,head);else MzBox(x,y,w,h);}
                        if(MzSwitch[4]){string name=MzSafeName(p.NickName);if(name!=null){MzText(x-22,y-25,w+150,name);}}
                        if(MzSwitch[6])MzText(x,y+h+4,w+80,((int)distance).ToString()+" m");
                        if(MzSwitch[5]){int max=p.MaxHP;float ratio=max>0?Mathf.Clamp((float)hp/max,0,1):0;MzTint(.02f,.04f,.06f,.9f);MzFill(x-7,y,4,h,0);GUI.color=MzHealthColor;MzFill(x-7,y+h*(1-ratio),4,h*ratio,0);}
                        GUI.color=MzEspColor;if(MzSwitch[8])MzCircle(top.x,top.y,Mathf.Clamp(h*.025f,3,8),1.5f);if(MzSwitch[10])MzLine(Screen.width*.5f,MzLineOrigin==0?Screen.height-8:MzLineOrigin==1?Screen.height*.5f:8,feet.x,feet.y,1);
                        if(MzSwitch[9]){MzTint(1,.3f,.3f,1);MzWorldLine(cam,root,root+new Vector3(.65f,0,0),1.5f);MzTint(.3f,1,.3f,1);MzWorldLine(cam,root,root+new Vector3(0,.65f,0),1.5f);MzTint(.3f,.5f,1,1);MzWorldLine(cam,root,root+new Vector3(0,0,.65f),1.5f);}
                        if(MzSwitch[7]){GUI.color=MzEspColor;MzSampleSkeleton(cam,p,top,feet);}
                    }catch(Exception e){MzTrimCommands(before);MzLogFault("esp-player",e);}
                }
            }catch(Exception){}finally{MzDrawingEsp=false;}
        }
        public static Player MzPickTarget()
        {
            var cam=Camera.main;var match=COW.GameFacade.CurrentMatch();if(cam==null||match==null)return null;var list=match.ILPNGCMEFFI();if(list==null)return null;Player best=null;float radius=MzEffectiveFov(),bestDistance=radius*radius;
            for(int i=0;i<list.Count&&i<128;i++){var p=list[i] as Player;if(!MzEnemy(p))continue;float range=Vector3.Distance(cam.transform.position,p.RootTransform.position);if(!MzFinite(range)||range>MzRange)continue;Vector2 head;if(!MzProject(cam,p.GetHeadTF().position,out head))continue;float dx=head.x-Screen.width*.5f,dy=head.y-Screen.height*.5f,distance=dx*dx+dy*dy;if(distance<bestDistance){bestDistance=distance;best=p;}}return best;
        }
        public static void MzRunAim()
        {
            if(!MzOnThread())return;
            try {
                if(!MzSwitch[11]&&!MzSwitch[12]){MzRestoreSilent();return;}if(COW.GameFacade.CurrentMatch()==null){MzRestoreSilent();return;}var local=COW.GameFacade.GetLocalPlayerOrObServer();if(!MzSwitch[12]||local==null||!local.IsLocalPlayer()||local.CurHP<=0||!local.IsFiring())MzRestoreSilent();
                if(local==null||!local.IsLocalPlayer()||local.CurHP<=0||!local.IsFiring()||(!MzSwitch[11]&&!MzSwitch[12]))return;var target=MzPickTarget();if(target==null)return;
                if(MzSwitch[14]){Vector2 p;if(MzProject(Camera.main,target.GetHeadTF().position,out p)){MzTint(1,.76f,.3f,1);MzLine(Screen.width*.5f,Screen.height*.5f,p.x,p.y,1.5f);}}
                if(MzSwitch[11]){var camera=Camera.main;var cameraTransform=camera==null?null:camera.transform;var headTransform=target.GetHeadTF();if(cameraTransform==null||headTransform==null)return;Vector3 origin=cameraTransform.position,point=headTransform.position;Vector3 direction=point-origin;if(!MzPoint(origin)||!MzPoint(point))return;if(MzPoint(direction)&&Vector3.Distance(new Vector3(),direction)>.01f)local.SetAimRotation(Quaternion.LookRotation(direction),true);}
            }catch(Exception){}
        }
        public static bool MzSame(Vector3 a,Vector3 b){return a.x==b.x&&a.y==b.y&&a.z==b.z;}
        public static void MzRestoreSilent()
        {
            if(!MzOnThread())return;
            try {
                var a=MzChangedAim;
                // Restore only if native code has not replaced our values.
                if(a!=null&&MzAimOwner!=null&&System.Object.ReferenceEquals(MzAimOwner.FDMIEDDNCEC,a)&&a.JHAINOBIFMA==MzAppliedObject&&a.JINDNOFABKB==MzAppliedCollider&&MzSame(a.HPCOJHGFEEG,MzAppliedPoint)&&MzSame(a.DOJDNHCGFGK,MzAppliedPoint)&&MzSame(a.HLDECMJFKJK,MzAppliedDirection)&&MzSame(a.EKPLMDDKOGB,MzAppliedOrigin)&&MzSame(a.ONMKMEGMHOL,MzAppliedOrigin)&&a.DKPDBLLJEAA&&!a.EFMBNPNFGHM&&!a.CEOKOILBODN&&!a.CLOLKHNMNEK){a.JHAINOBIFMA=MzOldAimObject;a.JINDNOFABKB=MzOldAimCollider;a.HPCOJHGFEEG=MzOldHpc;a.DOJDNHCGFGK=MzOldDoj;a.HLDECMJFKJK=MzOldDirection;a.EKPLMDDKOGB=MzOldOrigin;a.ONMKMEGMHOL=MzOldOnm;a.DKPDBLLJEAA=MzOldDkp;a.EFMBNPNFGHM=MzOldEfm;a.CEOKOILBODN=MzOldCeo;a.CLOLKHNMNEK=MzOldClo;}MzChangedAim=null;MzAimOwner=null;
            }catch(Exception){MzChangedAim=null;}
        }
        public static void MzSilent(Player local,CGKJLKPMGDJ result)
        {
            if(!MzOnThread()||MzInSilent||!MzSwitch[12])return;MzInSilent=true;
            try {
                if(local==null||!local.IsLocalPlayer())return;MzRestoreSilent();if(!MzInitialized||!MzAuthorized()||!MzSwitch[12]||result==null||local.CurHP<=0||!local.IsFiring())return;var target=MzPickTarget();if(target==null||target.HeadCollider==null)return;
                Vector3 point=target.GetHeadTF().position,origin=local.AimStartPostion,delta=point-origin;if(!MzPoint(point)||!MzPoint(origin)||Vector3.Distance(new Vector3(),delta)<=.01f)return;Vector3 direction=Vector3.Normalize(delta);if(!MzPoint(direction))return;
                MzChangedAim=result;MzAimOwner=local;MzAppliedObject=target.gameObject;MzAppliedCollider=target.HeadCollider;MzOldAimObject=result.JHAINOBIFMA;MzOldAimCollider=result.JINDNOFABKB;MzOldHpc=result.HPCOJHGFEEG;MzOldDoj=result.DOJDNHCGFGK;MzOldDirection=result.HLDECMJFKJK;MzOldOrigin=result.EKPLMDDKOGB;MzOldOnm=result.ONMKMEGMHOL;MzOldDkp=result.DKPDBLLJEAA;MzOldEfm=result.EFMBNPNFGHM;MzOldCeo=result.CEOKOILBODN;MzOldClo=result.CLOLKHNMNEK;MzAppliedPoint=point;MzAppliedOrigin=origin;MzAppliedDirection=direction;
                result.JHAINOBIFMA=target.gameObject;result.JINDNOFABKB=target.HeadCollider;result.HPCOJHGFEEG=point;result.DOJDNHCGFGK=point;result.HLDECMJFKJK=direction;result.EKPLMDDKOGB=origin;result.ONMKMEGMHOL=origin;result.DKPDBLLJEAA=true;result.EFMBNPNFGHM=false;result.CEOKOILBODN=false;result.CLOLKHNMNEK=false;
            }catch(Exception e){MzRestoreSilent();MzLogFault("silent",e);}finally{MzInSilent=false;}
        }
    }
}
