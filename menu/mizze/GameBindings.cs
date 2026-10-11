// Compile-time declarations plus selected patch bodies. CompilerHost chooses the fixes;
// remaining declaration bodies are excluded from the generated payload.
using System;
using System.Collections;
using UnityEngine;
[assembly: System.Reflection.AssemblyVersion("0.86.0.518")]
namespace GCommon
{
    public class Entity : Component {public Transform m_CachedTransform;public uint UniqueID {get{return 0;}}}
    public interface ITransformNode {Transform transform {get;}}
    public class SingletonModule<T> where T:class {public static T instance {get {return null;}}}
    public class UIModelManager : SingletonModule<UIModelManager> {public T GetModel<T>() where T:class {return null;}}
}
namespace COW
{
    public static class GameSettingData {public static bool CachedSmoothHighFrame(){return false;}}
    public class UIModelRole {}
    public static partial class GameFacade
    {
        public static UIModelRole m_modelRole;
        public static GamePlay.JMAGGLCNGIG CurrentMatch(){return null;}
        public static GamePlay.Player GetLocalPlayerOrObServer(){return null;}
        public static UIModelRole UIModelRole
        {
            get
            {
                GamePlay.SceneEditBoxSelectTool.MzEnsure();
                if(m_modelRole==null)m_modelRole=GCommon.UIModelManager.instance.GetModel<UIModelRole>();
                return m_modelRole;
            }
        }
    }
}
namespace COW.GamePlay
{
    public class JMAGGLCNGIG {public IList ILPNGCMEFFI(){return null;}public Player HFMDJGBOJKF(BEADLMGGGGL id,bool b){return null;}}
    public struct BEADLMGGGGL {public static BEADLMGGGGL DEIPJDIGKIP(uint id){return new BEADLMGGGGL();}public static bool GHAMDLFNMMA(BEADLMGGGGL a,BEADLMGGGGL b){return false;}}
    public class AttackableEntity : GCommon.Entity {public bool IsDead {get{return false;}}}
    public class CGKJLKPMGDJ
    {
        public GameObject JHAINOBIFMA;
        public Collider JINDNOFABKB;
        public Vector3 HPCOJHGFEEG,DOJDNHCGFGK,HLDECMJFKJK,EKPLMDDKOGB,ONMKMEGMHOL;
        public bool DKPDBLLJEAA,EFMBNPNFGHM,CEOKOILBODN,CLOLKHNMNEK;
    }
    public class PlayerAttributes : Component
    {
        public bool ShootNoReload;
        public bool IsAmmoFree {get{return false;}set{}}
        public float FireIntervalScale {get{return 1;}set{}}
    }
    public class Player : AttackableEntity
    {
        // Small native hook bodies reconstructed from TH 1.132.1; preserve return values.
        public Player LNHFOHKEAMP;
        public bool JKACHEMNCEI,FFOPCLFLIMO,IsKnockedDownBleed;
        public BEADLMGGGGL GIEBNLMODIB;
        public GFLBFKKDAMK GBJCJJNPPEC;
        public bool IsBeingCarried {get {SceneEditBoxSelectTool.MzLagBefore(this);return LNHFOHKEAMP!=null;}}
        public bool NeedRunHighFrame(){SceneEditBoxSelectTool.MzLagBefore(this);return COW.GameSettingData.CachedSmoothHighFrame()&&IsLocalPlayer()&&!JKACHEMNCEI;}
        public bool get_IsDieing(){return false;}
        public bool LastInFrustum(){return false;}
        public void UpdateKnockdownIsInCamera()
        {
            if(!IsLocalPlayer()){SceneEditBoxSelectTool.MzLagAfter(this);return;}
            if((int)GBJCJJNPPEC.OILOHAELLEC()!=8||FFOPCLFLIMO)return;
            if(BEADLMGGGGL.GHAMDLFNMMA(GIEBNLMODIB,BEADLMGGGGL.DEIPJDIGKIP(0u)))return;
            var target=COW.GameFacade.CurrentMatch().HFMDJGBOJKF(GIEBNLMODIB,false);
            if(target==null||target.IsDead||target.get_IsDieing()||target.IsLocalPlayer())return;
            FFOPCLFLIMO=target.LastInFrustum();
        }
        // Existing native cache fields; ESP never populates them.
        public GCommon.ITransformNode IIPBIDIBJDK,GBKFHDFCPMD,DLAHJBJFMCF,BKDOIIEJBFI,BOHFADPGJKH,FCFGLFMIBOO,BDJLHMNECMA,LFIGLLJCDOG,HOPHAMCLGOA,FKHGDFCPCFE,KMMMDCDJOLD;
        public PlayerAttributes get_Attributes(){return null;}
        public CGKJLKPMGDJ FDMIEDDNCEC;
        public bool IsInStealth(){return false;}
        public bool IsReallyInStealth(){return IsInStealth();}
        public CGKJLKPMGDJ LastAimingInfoFromWeapon
        {
            get {var result=FDMIEDDNCEC;if(SceneEditBoxSelectTool.MzInitialized&&SceneEditBoxSelectTool.MzSwitch[12])SceneEditBoxSelectTool.MzSilent(this,result);return result;}
        }
        public bool IsLocalPlayer(){return false;}
        public int CurHP {get {return 0;}}
        public int MaxHP {get {return 0;}}
        public string NickName {get {return "";}}
        public bool IsLocalTeammate(bool b){return false;}
        public Transform RootTransform {get {return null;}}
        public Transform GetHeadTF(){return null;}
        public Transform NeckBone {get {return null;}}
        public Transform ArmBoneLeft {get {return null;}}
        public Transform ArmBoneRight {get {return null;}}
        public Transform HandBoneLeft {get {return null;}}
        public Transform HandBoneRight {get {return null;}}
        public Transform LegBoneLeft {get {return null;}}
        public Transform LegBoneRight {get {return null;}}
        public Transform FootBoneLeft {get {return null;}}
        public Transform FootBoneRight {get {return null;}}
        public Collider HeadCollider {get {return null;}}
        public Vector3 AimStartPostion {get {return new Vector3();}}
        public bool IsFiring(){return false;}
        public void SetAimRotation(Quaternion q,bool b){}
    }
}

namespace message {public enum KOJPEFFGGIJ : uint {None=0,Knocked=8}}
public class GFLBFKKDAMK {public message.KOJPEFFGGIJ OILOHAELLEC(){return message.KOJPEFFGGIJ.None;}}
