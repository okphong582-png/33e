// Build-time declarations only. Their bodies are never put into the patch.
using System;
using System.Collections;
using UnityEngine;
[assembly: System.Reflection.AssemblyVersion("0.86.0.518")]
namespace GCommon
{
    public interface ITransformNode {Transform transform {get;}}
    public class SingletonModule<T> where T:class {public static T instance {get {return null;}}}
    public class UIModelManager : SingletonModule<UIModelManager> {public T GetModel<T>() where T:class {return null;}}
}
namespace COW
{
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
    public class JMAGGLCNGIG {public IList ILPNGCMEFFI(){return null;}}
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
    public class Player : Component
    {
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
