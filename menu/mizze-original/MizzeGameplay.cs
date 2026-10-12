using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
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
        // Fixed screen-coordinate scratch space: no Player/Transform survives a sample.
        public static float[] MzProjectedX,MzProjectedY;
        public static bool[] MzProjectedValid;
        public static string[] MzDistanceLabels;
        public static void MzProjectionScratch()
        {
            if(MzProjectedX!=null)return;MzProjectedX=new float[11];MzProjectedY=new float[11];MzProjectedValid=new bool[11];
        }
        public static void MzProjectSlot(Camera camera,int slot,Vector3 world)
        {
            Vector2 point;bool valid=MzProject(camera,world,out point);MzProjectedValid[slot]=valid;if(valid){MzProjectedX[slot]=point.x;MzProjectedY[slot]=point.y;}
        }
        public static void MzBoneSlot(Camera camera,int slot,Transform bone)
        {
            MzProjectedValid[slot]=false;if(bone!=null)MzProjectSlot(camera,slot,bone.position);
        }
        public static void MzProjectedEdge(int first,int second)
        {
            var valid=MzProjectedValid;if(!valid[first]||!valid[second])return;var x=MzProjectedX;var y=MzProjectedY;MzLine(x[first],y[first],x[second],y[second],1.5f);
        }
        public static string MzDistanceLabel(float distance)
        {
            if(MzDistanceLabels==null)MzDistanceLabels=new string[501];int value=(int)Mathf.Clamp(distance,0,500);var labels=MzDistanceLabels;
            if(labels[value]==null)labels[value]=value.ToString()+" m";return labels[value];
        }
        public static void MzBox3D(Camera cam,Vector3 root,Vector3 head)
        {
            MzProjectionScratch();float half=Mathf.Clamp((head.y-root.y)*.22f,.15f,1);
            MzProjectSlot(cam,0,new Vector3(root.x-half,root.y,root.z-half));MzProjectSlot(cam,1,new Vector3(root.x+half,root.y,root.z-half));
            MzProjectSlot(cam,2,new Vector3(root.x+half,root.y,root.z+half));MzProjectSlot(cam,3,new Vector3(root.x-half,root.y,root.z+half));
            MzProjectSlot(cam,4,new Vector3(root.x-half,head.y,root.z-half));MzProjectSlot(cam,5,new Vector3(root.x+half,head.y,root.z-half));
            MzProjectSlot(cam,6,new Vector3(root.x+half,head.y,root.z+half));MzProjectSlot(cam,7,new Vector3(root.x-half,head.y,root.z+half));
            MzProjectedEdge(0,1);MzProjectedEdge(1,2);MzProjectedEdge(2,3);MzProjectedEdge(3,0);MzProjectedEdge(4,5);MzProjectedEdge(5,6);MzProjectedEdge(6,7);MzProjectedEdge(7,4);MzProjectedEdge(0,4);MzProjectedEdge(1,5);MzProjectedEdge(2,6);MzProjectedEdge(3,7);
        }
        public static void MzSkeleton(Camera cam,Player player,Vector2 head,Vector2 root)
        {
            MzProjectionScratch();MzProjectedX[0]=head.x;MzProjectedY[0]=head.y;MzProjectedX[1]=root.x;MzProjectedY[1]=root.y;MzProjectedValid[0]=true;MzProjectedValid[1]=true;
            MzBoneSlot(cam,2,player.NeckBone);MzBoneSlot(cam,3,player.ArmBoneLeft);MzBoneSlot(cam,4,player.HandBoneLeft);MzBoneSlot(cam,5,player.ArmBoneRight);MzBoneSlot(cam,6,player.HandBoneRight);
            MzBoneSlot(cam,7,player.LegBoneLeft);MzBoneSlot(cam,8,player.FootBoneLeft);MzBoneSlot(cam,9,player.LegBoneRight);MzBoneSlot(cam,10,player.FootBoneRight);
            MzProjectedEdge(0,2);MzProjectedEdge(2,1);MzProjectedEdge(2,3);MzProjectedEdge(3,4);MzProjectedEdge(2,5);MzProjectedEdge(5,6);MzProjectedEdge(1,7);MzProjectedEdge(7,8);MzProjectedEdge(1,9);MzProjectedEdge(9,10);
        }
        public static void MzSampleEsp()
        {
            MzDrawingEsp=true;MzDrawBudget=512;
            try {
                var cam=Camera.main;var match=COW.GameFacade.CurrentMatch();if(cam==null||match==null)return;
                var cameraTransform=cam.transform;if(cameraTransform==null)return;Vector3 cameraPosition=cameraTransform.position;if(!MzPoint(cameraPosition))return;
                if(!MzSwitch[0])return;var players=match.ILPNGCMEFFI();if(players==null)return;int count=players.Count;if(count>128)count=128;int shown=0;
                for(int i=0;i<count&&shown<(MzBatchReady?16:3)&&MzCommandCount+40<=512;i++){
                    if(i>0&&Time.realtimeSinceStartup-MzEspSampleStarted>.012f)break;
                    int before=MzCommandCount,beforeQuads=MzQuadCount;
                    // The native roster can shrink during a scene/round change. No transform is retained across frames.
                    try {
                        if(i>=players.Count)break;var p=players[i] as Player;if(p==null||p.IsLocalPlayer()||p.IsLocalTeammate(false)||p.IsLocalTeammate(true))continue;
                        var obj=p.gameObject;if(obj==null||!obj.activeInHierarchy)continue;int hp=p.CurHP;if(hp<=0)continue;
                        var rootTransform=p.RootTransform;var headTransform=p.GetHeadTF();if(rootTransform==null||headTransform==null)continue;
                        Vector3 root=rootTransform.position,head=headTransform.position;if(!MzPoint(root)||!MzPoint(head))continue;float distance=Vector3.Distance(root,cameraPosition);if(!MzFinite(distance)||distance>MzRange)continue;
                        Vector2 feet,top;if(!MzProject(cam,root,out feet)||!MzProject(cam,head,out top))continue;
                        float h=feet.y-top.y,w=h*.5f,x=(feet.x+top.x)*.5f-w*.5f,y=top.y;if(!MzFinite(h)||h<=4||h>Screen.height*2||x+w<0||x>Screen.width||y+h<0||y>Screen.height)continue;shown++;
                        GUI.color=MzEspColor;if(MzSwitch[1]){if(MzSwitch[3])MzBox3D(cam,root,head);else MzBox(x,y,w,h);}
                        if(MzSwitch[4]){string name=p.NickName;if(name!=null){if(name.Length>24)name=name.Substring(0,24);MzText(x-22,y-25,w+150,name);}}
                        if(MzSwitch[6])MzText(x,y+h+4,w+80,MzDistanceLabel(distance));
                        if(MzSwitch[5]){int max=p.MaxHP;float ratio=max>0?Mathf.Clamp((float)hp/max,0,1):0;MzTint(.02f,.04f,.06f,.9f);MzFill(x-7,y,4,h,0);GUI.color=MzHealthColor;MzFill(x-7,y+h*(1-ratio),4,h*ratio,0);}
                        GUI.color=MzEspColor;if(MzSwitch[8])MzCircle(top.x,top.y,Mathf.Clamp(h*.025f,3,8),1.5f);if(MzSwitch[10])MzLine(Screen.width*.5f,MzLineOrigin==0?Screen.height-8:MzLineOrigin==1?Screen.height*.5f:8,feet.x,feet.y,1);
                        if(MzSwitch[9]){MzTint(1,.3f,.3f,1);MzWorldLine(cam,root,root+new Vector3(.65f,0,0),1.5f);MzTint(.3f,1,.3f,1);MzWorldLine(cam,root,root+new Vector3(0,.65f,0),1.5f);MzTint(.3f,.5f,1,1);MzWorldLine(cam,root,root+new Vector3(0,0,.65f),1.5f);}
                        if(MzSwitch[7]){GUI.color=MzEspColor;MzSkeleton(cam,p,top,feet);}
                    }catch(Exception){MzTrimCommands(before);MzQuadCount=beforeQuads;MzBatchDirty=true;}
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
            try {
                if(!MzSwitch[11]&&!MzSwitch[12]){MzRestoreSilent();return;}var local=COW.GameFacade.GetLocalPlayerOrObServer();if(!MzSwitch[12]||local==null||!local.IsLocalPlayer()||local.CurHP<=0||!local.IsFiring())MzRestoreSilent();
                if(local==null||!local.IsLocalPlayer()||local.CurHP<=0||!local.IsFiring()||(!MzSwitch[11]&&!MzSwitch[12]))return;var target=MzPickTarget();if(target==null)return;
                if(MzSwitch[14]){Vector2 p;if(MzProject(Camera.main,target.GetHeadTF().position,out p)){MzTint(1,.76f,.3f,1);MzLine(Screen.width*.5f,Screen.height*.5f,p.x,p.y,1.5f);}}
                if(MzSwitch[11]){var camera=Camera.main;var cameraTransform=camera==null?null:camera.transform;var headTransform=target.GetHeadTF();if(cameraTransform==null||headTransform==null)return;Vector3 origin=cameraTransform.position,point=headTransform.position;Vector3 direction=point-origin;if(!MzPoint(origin)||!MzPoint(point))return;if(MzPoint(direction)&&Vector3.Distance(new Vector3(),direction)>.01f)local.SetAimRotation(Quaternion.LookRotation(direction),true);}
            }catch(Exception){}
        }
        public static bool MzSame(Vector3 a,Vector3 b){return a.x==b.x&&a.y==b.y&&a.z==b.z;}
        public static void MzRestoreSilent()
        {
            try {
                var a=MzChangedAim;
                // Restore only if native code has not replaced our values.
                if(a!=null&&MzAimOwner!=null&&System.Object.ReferenceEquals(MzAimOwner.FDMIEDDNCEC,a)&&a.JHAINOBIFMA==MzAppliedObject&&a.JINDNOFABKB==MzAppliedCollider&&MzSame(a.HPCOJHGFEEG,MzAppliedPoint)&&MzSame(a.DOJDNHCGFGK,MzAppliedPoint)&&MzSame(a.HLDECMJFKJK,MzAppliedDirection)&&MzSame(a.EKPLMDDKOGB,MzAppliedOrigin)&&MzSame(a.ONMKMEGMHOL,MzAppliedOrigin)&&a.DKPDBLLJEAA&&!a.EFMBNPNFGHM&&!a.CEOKOILBODN&&!a.CLOLKHNMNEK){a.JHAINOBIFMA=MzOldAimObject;a.JINDNOFABKB=MzOldAimCollider;a.HPCOJHGFEEG=MzOldHpc;a.DOJDNHCGFGK=MzOldDoj;a.HLDECMJFKJK=MzOldDirection;a.EKPLMDDKOGB=MzOldOrigin;a.ONMKMEGMHOL=MzOldOnm;a.DKPDBLLJEAA=MzOldDkp;a.EFMBNPNFGHM=MzOldEfm;a.CEOKOILBODN=MzOldCeo;a.CLOLKHNMNEK=MzOldClo;}MzChangedAim=null;MzAimOwner=null;
            }catch(Exception){MzChangedAim=null;}
        }
        public static void MzSilent(Player local,CGKJLKPMGDJ result)
        {
            try {
                if(local==null||!local.IsLocalPlayer())return;MzRestoreSilent();if(!MzInitialized||!MzAuthorized()||!MzSwitch[12]||result==null||local.CurHP<=0||!local.IsFiring())return;var target=MzPickTarget();if(target==null||target.HeadCollider==null)return;
                Vector3 point=target.GetHeadTF().position,origin=local.AimStartPostion,delta=point-origin;if(!MzPoint(point)||!MzPoint(origin)||Vector3.Distance(new Vector3(),delta)<=.01f)return;Vector3 direction=Vector3.Normalize(delta);if(!MzPoint(direction))return;
                MzChangedAim=result;MzAimOwner=local;MzAppliedObject=target.gameObject;MzAppliedCollider=target.HeadCollider;MzOldAimObject=result.JHAINOBIFMA;MzOldAimCollider=result.JINDNOFABKB;MzOldHpc=result.HPCOJHGFEEG;MzOldDoj=result.DOJDNHCGFGK;MzOldDirection=result.HLDECMJFKJK;MzOldOrigin=result.EKPLMDDKOGB;MzOldOnm=result.ONMKMEGMHOL;MzOldDkp=result.DKPDBLLJEAA;MzOldEfm=result.EFMBNPNFGHM;MzOldCeo=result.CEOKOILBODN;MzOldClo=result.CLOLKHNMNEK;MzAppliedPoint=point;MzAppliedOrigin=origin;MzAppliedDirection=direction;
                result.JHAINOBIFMA=target.gameObject;result.JINDNOFABKB=target.HeadCollider;result.HPCOJHGFEEG=point;result.DOJDNHCGFGK=point;result.HLDECMJFKJK=direction;result.EKPLMDDKOGB=origin;result.ONMKMEGMHOL=origin;result.DKPDBLLJEAA=true;result.EFMBNPNFGHM=false;result.CEOKOILBODN=false;result.CLOLKHNMNEK=false;
            }catch(Exception){MzRestoreSilent();}
        }
    }
}
