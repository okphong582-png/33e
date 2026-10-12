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
        public static void MzBox3D(Camera cam,Vector3 root,Vector3 head)
        {
            float half=Mathf.Clamp((head.y-root.y)*.22f,.15f,1),left=root.x-half,right=root.x+half,near=root.z-half,far=root.z+half;
            Vector2 a,b,c,d,e,f,g,h;
            // Eight unique corners, instead of 24 projections (two per edge).
            if(!MzProject(cam,new Vector3(left,root.y,near),out a)||!MzProject(cam,new Vector3(right,root.y,near),out b)||
               !MzProject(cam,new Vector3(right,root.y,far),out c)||!MzProject(cam,new Vector3(left,root.y,far),out d)||
               !MzProject(cam,new Vector3(left,head.y,near),out e)||!MzProject(cam,new Vector3(right,head.y,near),out f)||
               !MzProject(cam,new Vector3(right,head.y,far),out g)||!MzProject(cam,new Vector3(left,head.y,far),out h))return;
            MzLine(a.x,a.y,b.x,b.y,1.5f);MzLine(b.x,b.y,c.x,c.y,1.5f);MzLine(c.x,c.y,d.x,d.y,1.5f);MzLine(d.x,d.y,a.x,a.y,1.5f);
            MzLine(e.x,e.y,f.x,f.y,1.5f);MzLine(f.x,f.y,g.x,g.y,1.5f);MzLine(g.x,g.y,h.x,h.y,1.5f);MzLine(h.x,h.y,e.x,e.y,1.5f);
            MzLine(a.x,a.y,e.x,e.y,1.5f);MzLine(b.x,b.y,f.x,f.y,1.5f);MzLine(c.x,c.y,g.x,g.y,1.5f);MzLine(d.x,d.y,h.x,h.y,1.5f);
        }
        public static bool MzBonePoint(Camera cam,Transform bone,out Vector2 point)
        {point=new Vector2();return bone!=null&&MzProject(cam,bone.position,out point);}
        public static void MzScreenBone(bool first,Vector2 a,bool second,Vector2 b)
        {if(first&&second)MzLine(a.x,a.y,b.x,b.y,1.5f);}
        public static void MzSampleEsp()
        {
            MzDrawingEsp=true;MzDrawBudget=512;int shown=0;
            try {
                var cam=Camera.main;var match=COW.GameFacade.CurrentMatch();if(cam==null||match==null)return;
                var cameraTransform=cam.transform;if(cameraTransform==null)return;Vector3 cameraPosition=cameraTransform.position;if(!MzPoint(cameraPosition))return;
                if(!MzSwitch[0])return;var players=match.ILPNGCMEFFI();if(players==null)return;int count=players.Count;if(count>128)count=128;
                for(int i=0;i<count&&shown<(MzBatchReady?16:3)&&MzCommandCount+40<=512;i++){
                    if(i>0&&Time.realtimeSinceStartup-MzEspSampleStarted>.008f)break;
                    int before=MzCommandCount,beforeQuad=MzQuadCount;
                    // The native roster can shrink during a scene/round change. No transform is retained across frames.
                    try {
                        if(i>=players.Count)break;var p=players[i] as Player;if(p==null||p.IsLocalPlayer()||p.IsLocalTeammate(false)||p.IsLocalTeammate(true))continue;
                        var obj=p.gameObject;if(obj==null||!obj.activeInHierarchy)continue;int hp=p.CurHP;if(hp<=0)continue;
                        var rootTransform=p.RootTransform;var headTransform=p.GetHeadTF();if(rootTransform==null||headTransform==null)continue;
                        Vector3 root=rootTransform.position,head=headTransform.position;if(!MzPoint(root)||!MzPoint(head))continue;float distance=Vector3.Distance(root,cameraPosition);if(!MzFinite(distance)||distance>MzRange)continue;
                        Vector2 feet,top;if(!MzProject(cam,root,out feet)||!MzProject(cam,head,out top))continue;
                        float h=feet.y-top.y,w=h*.5f,x=(feet.x+top.x)*.5f-w*.5f,y=top.y;if(!MzFinite(h)||h<=4||h>Screen.height*2||x+w<0||x>Screen.width||y+h<0||y>Screen.height)continue;shown++;
                        MzPaintColor=MzEspColor;if(MzSwitch[1]){if(MzSwitch[3])MzBox3D(cam,root,head);else MzBox(x,y,w,h);}
                        if(MzSwitch[4]){string name=MzCachedName(p,shown-1);if(name!=null)MzText(x-22,y-25,w+150,name);}
                        if(MzSwitch[6])MzText(x,y+h+4,w+80,MzDistanceLabels[(int)Mathf.Clamp(distance,0,500)]);
                        if(MzSwitch[5]){int max=p.MaxHP;float ratio=max>0?Mathf.Clamp((float)hp/max,0,1):0;MzTint(.02f,.04f,.06f,.9f);MzFill(x-7,y,4,h,0);MzPaintColor=MzHealthColor;MzFill(x-7,y+h*(1-ratio),4,h*ratio,0);}
                        MzPaintColor=MzEspColor;if(MzSwitch[8])MzCircle(top.x,top.y,Mathf.Clamp(h*.025f,3,8),1.5f);if(MzSwitch[10])MzLine(Screen.width*.5f,MzLineOrigin==0?Screen.height-8:MzLineOrigin==1?Screen.height*.5f:8,feet.x,feet.y,1);
                        if(MzSwitch[9]){
                            Vector2 axis;MzTint(1,.3f,.3f,1);if(MzProject(cam,new Vector3(root.x+.65f,root.y,root.z),out axis))MzLine(feet.x,feet.y,axis.x,axis.y,1.5f);
                            MzTint(.3f,1,.3f,1);if(MzProject(cam,new Vector3(root.x,root.y+.65f,root.z),out axis))MzLine(feet.x,feet.y,axis.x,axis.y,1.5f);
                            MzTint(.3f,.5f,1,1);if(MzProject(cam,new Vector3(root.x,root.y,root.z+.65f),out axis))MzLine(feet.x,feet.y,axis.x,axis.y,1.5f);
                        }
                        if(MzSwitch[7]){
                            MzPaintColor=MzEspColor;Vector2 neck,armL,armR,handL,handR,legL,legR,footL,footR;
                            bool n=MzBonePoint(cam,p.NeckBone,out neck),al=MzBonePoint(cam,p.ArmBoneLeft,out armL),ar=MzBonePoint(cam,p.ArmBoneRight,out armR),
                                 hl=MzBonePoint(cam,p.HandBoneLeft,out handL),hr=MzBonePoint(cam,p.HandBoneRight,out handR),
                                 ll=MzBonePoint(cam,p.LegBoneLeft,out legL),lr=MzBonePoint(cam,p.LegBoneRight,out legR),
                                 fl=MzBonePoint(cam,p.FootBoneLeft,out footL),fr=MzBonePoint(cam,p.FootBoneRight,out footR);
                            MzScreenBone(true,top,n,neck);MzScreenBone(n,neck,true,feet);MzScreenBone(n,neck,al,armL);MzScreenBone(al,armL,hl,handL);
                            MzScreenBone(n,neck,ar,armR);MzScreenBone(ar,armR,hr,handR);MzScreenBone(true,feet,ll,legL);MzScreenBone(ll,legL,fl,footL);
                            MzScreenBone(true,feet,lr,legR);MzScreenBone(lr,legR,fr,footR);
                        }
                    }catch(Exception){MzTrimCommands(before);MzQuadCount=beforeQuad;}
                }
            }catch(Exception){}finally{MzEspShown=shown;MzTrimLabels(MzSwitch[4]?shown:0);MzDrawingEsp=false;}
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
                MzMemoryPulse();if(local==null||!local.IsLocalPlayer())return;MzRestoreSilent();if(!MzInitialized||!MzAuthorized()||!MzSwitch[12]||result==null||local.CurHP<=0||!local.IsFiring())return;var target=MzPickTarget();if(target==null||target.HeadCollider==null)return;
                Vector3 point=target.GetHeadTF().position,origin=local.AimStartPostion,delta=point-origin;if(!MzPoint(point)||!MzPoint(origin)||Vector3.Distance(new Vector3(),delta)<=.01f)return;Vector3 direction=Vector3.Normalize(delta);if(!MzPoint(direction))return;
                MzChangedAim=result;MzAimOwner=local;MzAppliedObject=target.gameObject;MzAppliedCollider=target.HeadCollider;MzOldAimObject=result.JHAINOBIFMA;MzOldAimCollider=result.JINDNOFABKB;MzOldHpc=result.HPCOJHGFEEG;MzOldDoj=result.DOJDNHCGFGK;MzOldDirection=result.HLDECMJFKJK;MzOldOrigin=result.EKPLMDDKOGB;MzOldOnm=result.ONMKMEGMHOL;MzOldDkp=result.DKPDBLLJEAA;MzOldEfm=result.EFMBNPNFGHM;MzOldCeo=result.CEOKOILBODN;MzOldClo=result.CLOLKHNMNEK;MzAppliedPoint=point;MzAppliedOrigin=origin;MzAppliedDirection=direction;
                result.JHAINOBIFMA=target.gameObject;result.JINDNOFABKB=target.HeadCollider;result.HPCOJHGFEEG=point;result.DOJDNHCGFGK=point;result.HLDECMJFKJK=direction;result.EKPLMDDKOGB=origin;result.ONMKMEGMHOL=origin;result.DKPDBLLJEAA=true;result.EFMBNPNFGHM=false;result.CEOKOILBODN=false;result.CLOLKHNMNEK=false;
            }catch(Exception){MzRestoreSilent();}
        }
    }
}
