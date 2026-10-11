using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        // Presentation hold only. No socket, packet loss or shared IFix table writes.
        public static bool MzLagActive,MzLagBlocked,MzLagBusy,MzLagEnabled;
        public static float MzLagX,MzLagY;public static int MzLagTailCalls;
        public static float MzLagSeconds,MzLagDeadline,MzLagNextPulse;
        public static string MzLagMessage;
        public static JMAGGLCNGIG MzLagMatch;
        public static Player MzLagLocal;
        public static uint MzLagLocalId;
        public static Player[] MzLagPlayers,MzLagRoster;
        public static uint[] MzLagRosterIds;
        public static int MzLagRosterCount;
        public static Transform[] MzLagTransforms;
        public static uint[] MzLagIds;
        public static bool[] MzLagApplied;
        public static int[] MzLagFrames;
        public static Vector3[] MzLagReal,MzLagShown;
        public static float[] MzLagUntil;
        public static int MzLagCount,MzLagWrites,MzLagRestores;


        public static void MzLagButtonPlace()
        {
            float width=Screen.width/MzScale,height=Screen.height/MzScale;
            float x=MzBubbleX,y=MzBubbleY+92;
            if(y+84>height)y=MzBubbleY-92;
            if(y<4){y=MzBubbleY;x=MzBubbleX+92;if(x+84>width)x=MzBubbleX-92;}
            MzLagX=Mathf.Clamp(x,4,width-84);MzLagY=Mathf.Clamp(y,4,height-84);
        }
        public static bool MzLagButtonVisible(){return MzSwitch!=null&&MzSwitch.Length>17&&MzSwitch[17]&&MzAuthorized();}
        public static bool MzLagButtonHit(Vector2 p){float dx=p.x-MzLagX-40,dy=p.y-MzLagY-40;return MzLagButtonVisible()&&dx*dx+dy*dy<=1600;}
        public static void MzLagButtonToggle()
        {
            if(!MzOnThread()||!MzLagButtonVisible())return;
            MzLagEnabled=!MzLagEnabled;MzLagBlocked=false;MzLagNextPulse=0;MzLagPulse();
        }
        public static void MzLagButtonDraw()
        {
            if(!MzUiPaint||!MzLagButtonVisible())return;
            MzTint(0,0,0,.22f);MzFill(MzLagX+3,MzLagY+5,80,80,40);
            MzTint(MzLagEnabled?.44f:.65f,MzLagEnabled?.93f:.71f,MzLagEnabled?.72f:.79f,.66f);MzFill(MzLagX,MzLagY,80,80,40);
            MzTint(.025f,.035f,.045f,.86f);MzFill(MzLagX+3,MzLagY+3,74,74,37);
            MzTint(.96f,.99f,1,1);MzCenter(MzLagX,MzLagY,80,80,MzLagEnabled?"FL BẬT":"FL TẮT");
        }
        public static void MzLagDrop(int i)
        {
            MzLagPlayers[i]=null;MzLagTransforms[i]=null;MzLagIds[i]=0;MzLagUntil[i]=0;MzLagApplied[i]=false;MzLagFrames[i]=0;
        }
        public static bool MzLagContext()
        {
            return !MzMemoryPaused&&MzLagMatch!=null&&MzLagLocal!=null&&MzLagLocal.UniqueID==MzLagLocalId&&
                System.Object.ReferenceEquals(COW.GameFacade.CurrentMatch(),MzLagMatch)&&
                System.Object.ReferenceEquals(COW.GameFacade.GetLocalPlayerOrObServer(),MzLagLocal);
        }
        public static bool MzLagMember(Player p)
        {
            if(p==null||MzLagRoster==null)return false;
            for(int i=0;i<MzLagRosterCount;i++)if(System.Object.ReferenceEquals(p,MzLagRoster[i])&&p.UniqueID==MzLagRosterIds[i])return true;
            return false;
        }
        public static bool MzLagRow(int i,Player p)
        {
            if(p==null||!System.Object.ReferenceEquals(p,MzLagPlayers[i])||p.UniqueID!=MzLagIds[i])return false;
            var t=MzLagTransforms[i];if(t==null||!System.Object.ReferenceEquals(p.m_CachedTransform,t))return false;
            var obj=p.gameObject;return obj!=null&&obj.activeInHierarchy&&!p.IsDead&&p.CurHP>0&&!p.IsKnockedDownBleed;
        }
        public static void MzLagRestoreRow(int i)
        {
            if(!MzLagApplied[i])return;var p=MzLagPlayers[i];if(!MzLagRow(i,p))return;
            var t=MzLagTransforms[i];Vector3 current=t.position;
            // A native correction wins. Never restore to an object/pose we no longer own.
            if(MzPoint(current)&&MzSame(current,MzLagShown[i])&&!MzSame(current,MzLagReal[i])){
                t.position=MzLagReal[i];MzLagRestores++;
            }
            MzLagApplied[i]=false;
        }
        public static void MzLagStop()
        {
            if(!MzOnThread())return;bool wasBusy=MzLagBusy;MzLagBusy=true;try{MzLagActive=false;
            if(MzLagPlayers!=null){
                bool context=false;try{context=MzLagContext();}catch(Exception){}
                for(int i=0;i<16;i++){
                    if(context)try{MzLagRestoreRow(i);}catch(Exception e){MzLogFault("fakelag-restore",e);}
                    MzLagDrop(i);
                }
            }
            if(MzLagRoster!=null)for(int i=0;i<32;i++){MzLagRoster[i]=null;MzLagRosterIds[i]=0;}MzLagRosterCount=0;
            MzLagMatch=null;MzLagLocal=null;MzLagLocalId=0;MzLagCount=0;MzLagDeadline=0;
            }finally{MzLagBusy=wasBusy;}
        }
        public static void MzLagFault(Exception e)
        {
            MzLagBlocked=true;MzLagEnabled=false;MzSwitch[17]=false;MzLagStop();
            MzLagMessage="Fakelag đã dừng do dữ liệu lỗi";MzLogFault("fakelag",e);
        }
        public static void MzLagPulse()
        {
            if(MzMemoryPaused){MzLagStop();return;}
            if(!MzOnThread()||MzLagBusy)return;
            if(!MzSwitch[17]||!MzAuthorized())MzLagEnabled=false;
            if(!MzSwitch[17]||!MzLagEnabled||MzLagBlocked||!MzAuthorized()){
                if(MzLagMatch!=null||MzLagActive)MzLagStop();
                if(!MzLagBlocked)MzLagMessage="Fakelag · TẮT";return;
            }
            float now=Time.realtimeSinceStartup;if(!MzFinite(now)){MzLagStop();return;}if(now<MzLagNextPulse)return;MzLagNextPulse=now+.2f;
            MzLagBusy=true;try{
                var match=COW.GameFacade.CurrentMatch();if(match==null){MzLagStop();MzLagMessage="Fakelag · Chờ vào trận";return;}var local=COW.GameFacade.GetLocalPlayerOrObServer();
                if(match==null||local==null||!local.IsLocalPlayer()||local.IsDead||local.CurHP<=0||local.IsKnockedDownBleed){
                    MzLagStop();MzLagMessage="Fakelag · Chờ vào trận";return;
                }
                uint id=local.UniqueID;if(id==0){MzLagStop();return;}
                if(!System.Object.ReferenceEquals(match,MzLagMatch)||!System.Object.ReferenceEquals(local,MzLagLocal)||id!=MzLagLocalId)MzLagStop();
                if(MzLagPlayers==null){
                    var roster=new Player[32];var rosterIds=new uint[32];var playersBuffer=new Player[16];var transforms=new Transform[16];
                    var ids=new uint[16];var applied=new bool[16];var frames=new int[16];var real=new Vector3[16];var shown=new Vector3[16];var until=new float[16];
                    MzLagRoster=roster;MzLagRosterIds=rosterIds;MzLagTransforms=transforms;MzLagIds=ids;MzLagApplied=applied;
                    MzLagFrames=frames;MzLagReal=real;MzLagShown=shown;MzLagUntil=until;MzLagPlayers=playersBuffer;
                }
                MzLagMatch=match;MzLagLocal=local;MzLagLocalId=id;
                for(int i=0;i<32;i++){MzLagRoster[i]=null;MzLagRosterIds[i]=0;}MzLagRosterCount=0;
                var players=match.ILPNGCMEFFI();if(players==null){MzLagStop();MzLagMessage="Fakelag · Chờ danh sách địch";return;}
                int count=players.Count;if(count>64)count=64;
                for(int i=0;i<count&&MzLagRosterCount<32;i++){
                    if(i>=players.Count)break;var p=players[i] as Player;
                    if(p==null||p.IsLocalPlayer()||p.IsLocalTeammate(false)||p.IsLocalTeammate(true)||p.IsDead||p.CurHP<=0||p.IsKnockedDownBleed||p.LNHFOHKEAMP!=null)continue;
                    uint pid=p.UniqueID;if(pid==0)continue;MzLagRoster[MzLagRosterCount]=p;MzLagRosterIds[MzLagRosterCount++]=pid;
                }
                MzLagDeadline=now+.5f;MzLagActive=true;
                int held=0;
                for(int i=0;i<16;i++)if(!System.Object.ReferenceEquals(MzLagPlayers[i],null)){
                    if(!MzLagRow(i,MzLagPlayers[i]))MzLagDrop(i);else if(!MzLagMember(MzLagPlayers[i])||MzLagPlayers[i].IsLocalPlayer()||MzLagPlayers[i].IsLocalTeammate(false)||MzLagPlayers[i].IsLocalTeammate(true)||MzLagPlayers[i].LNHFOHKEAMP!=null){MzLagRestoreRow(i);MzLagDrop(i);}else held++;
                }
                MzLagCount=held;MzLagMessage="Fakelag · "+held.ToString()+" / 16 · "+MzLagWrites.ToString()+" lần giữ";
            }catch(Exception e){MzLagFault(e);}finally{MzLagBusy=false;}
        }
        public static void MzLagBefore(Player p)
        {
            if(!MzOnThread()||MzLagBusy||MzLagMatch==null||MzLagPlayers==null||System.Object.ReferenceEquals(p,null))return;
            MzLagBusy=true;try{
                for(int i=0;i<16;i++)if(System.Object.ReferenceEquals(p,MzLagPlayers[i])){
                    if(!MzLagContext()){MzLagStop();return;}
                    float now=Time.realtimeSinceStartup;
                    // These getters also run in avatar LateUpdate. Keep the final pose for this
                    // Unity frame; restore on the next frame, or immediately on release/expiry.
                    if(MzLagApplied[i]&&MzLagActive&&MzSwitch[17]&&MzLagEnabled&&MzAuthorized()&&MzFinite(now)&&now<=MzLagDeadline&&MzLagFrames[i]==Time.frameCount&&MzLagRow(i,p))return;
                    MzLagRestoreRow(i);
                    if(!MzLagActive||!MzSwitch[17]||!MzLagEnabled||!MzAuthorized()||!MzFinite(now)||now>MzLagDeadline||!MzLagRow(i,p))MzLagDrop(i);
                    return;
                }
            }catch(Exception e){MzLagFault(e);}finally{MzLagBusy=false;}
        }
        public static void MzLagAfter(Player p)
        {
            if(!MzOnThread()||MzLagBusy||!MzLagActive)return;
            MzLagBusy=true;try{
                if(!MzLagMember(p))return;MzLagTailCalls++;float now=Time.realtimeSinceStartup;
                if(!MzSwitch[17]||!MzLagEnabled||!MzAuthorized()||!MzFinite(now)||now>MzLagDeadline||!MzLagContext()){
                    MzLagStop();return;
                }
                if(p.IsLocalPlayer()||p.IsLocalTeammate(false)||p.IsLocalTeammate(true)||p.IsDead||p.CurHP<=0||p.IsKnockedDownBleed||p.LNHFOHKEAMP!=null)return;
                var obj=p.gameObject;if(obj==null||!obj.activeInHierarchy)return;
                var t=p.m_CachedTransform;if(t==null)return;Vector3 current=t.position;if(!MzPoint(current))return;
                uint id=p.UniqueID;if(id==0)return;int row=-1,empty=-1;
                for(int i=0;i<16;i++){
                    if(System.Object.ReferenceEquals(p,MzLagPlayers[i])){row=i;break;}
                    if(empty<0&&System.Object.ReferenceEquals(MzLagPlayers[i],null))empty=i;
                }
                if(row<0)row=empty;if(row<0)return;
                if(MzLagApplied[row]){MzLagRestoreRow(row);current=t.position;if(!MzPoint(current))return;}
                bool continuing=System.Object.ReferenceEquals(p,MzLagPlayers[row])&&id==MzLagIds[row]&&System.Object.ReferenceEquals(t,MzLagTransforms[row]);
                if(!continuing||now>=MzLagUntil[row]||Vector3.Distance(current,MzLagShown[row])>10){
                    MzLagShown[row]=current;MzLagApplied[row]=false;MzLagUntil[row]=now+(MzFinite(MzLagSeconds)?Mathf.Clamp(MzLagSeconds,.1f,.25f):.15f);
                }
                // Save the latest true pose after native interpolation. Retain only a bounded anchor.
                MzLagPlayers[row]=p;MzLagIds[row]=id;MzLagTransforms[row]=t;MzLagReal[row]=current;
                if(!MzSame(current,MzLagShown[row])){MzLagApplied[row]=true;MzLagFrames[row]=Time.frameCount;t.position=MzLagShown[row];MzLagWrites++;}
            }catch(Exception e){MzLagFault(e);}finally{MzLagBusy=false;}
        }
    }
}
