// Offline test doubles only. This file is excluded from the patch build.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Web.Script.Serialization;
namespace IFix.Core {static class PatchManager {public static void Load(System.IO.Stream s){throw new NotSupportedException();}public static void Unload(System.Reflection.Assembly a){throw new NotSupportedException();}}}
namespace IFix {public class ILFixInterfaceBridge {}}
namespace UnityEngine
{
    public class Object
    {
        public string name {get;set;}public bool Persistent,Destroyed;
        public static bool operator ==(Object a,Object b){return (ReferenceEquals(a,null)||a.Destroyed)?(ReferenceEquals(b,null)||b.Destroyed):ReferenceEquals(a,b);}public static bool operator !=(Object a,Object b){return !(a==b);}
        public override bool Equals(object o){return ReferenceEquals(this,o);}public override int GetHashCode(){return base.GetHashCode();}public static void DontDestroyOnLoad(Object o){o.Persistent=true;}public static void Destroy(Object o){o.Destroyed=true;}
    }
    public class Component:Object {public GameObject gameObject {get;set;}public Transform transform {get{return gameObject.transform;}}}
    public class GameObject:Object
    {
        public static Dictionary<string,GameObject> World=new Dictionary<string,GameObject>();public static bool FailAdd;
        public Transform transform {get;private set;}public bool activeInHierarchy {get;set;}public Component Added;
        public GameObject(string n){name=n;transform=new Transform();activeInHierarchy=true;World[n]=this;}
        public static GameObject Find(string n){GameObject g;return World.TryGetValue(n,out g)?g:null;}
        public Component GetComponent(Type t){return Added!=null&&t.IsInstanceOfType(Added)?Added:null;}
        public Component AddComponent(Type t){if(FailAdd)throw new Exception("creation failure");Added=(Component)Activator.CreateInstance(t);Added.gameObject=this;return Added;}
    }
    public class Transform:Component {public Vector3 position {get;set;}public Vector3 localScale {get;set;}}
    public class Collider:Component {}
    public struct Vector3
    {
        public float x,y,z;public Vector3(float a,float b,float c){x=a;y=b;z=c;}
        public static Vector3 operator +(Vector3 a,Vector3 b){return new Vector3(a.x+b.x,a.y+b.y,a.z+b.z);}public static Vector3 operator -(Vector3 a,Vector3 b){return new Vector3(a.x-b.x,a.y-b.y,a.z-b.z);}public static Vector3 operator *(Vector3 a,float b){return new Vector3(a.x*b,a.y*b,a.z*b);}
        public static Vector3 Normalize(Vector3 v){float l=Distance(v,new Vector3());return l>0?v*(1/l):new Vector3();}public static float Distance(Vector3 a,Vector3 b){Vector3 d=a-b;return (float)Math.Sqrt(d.x*d.x+d.y*d.y+d.z*d.z);}
    }
    public struct Vector2 {public float x,y;public Vector2(float a,float b){x=a;y=b;}}
    public struct Color {public float r,g,b,a;public Color(float x,float y,float z,float w){r=x;g=y;b=z;a=w;}}
    public struct Quaternion {public Vector3 Direction;public float Angle;public static Quaternion Euler(float a,float b,float c){return new Quaternion {Angle=c};}public static Quaternion LookRotation(Vector3 d){return new Quaternion {Direction=Vector3.Normalize(d)};}}
    public struct Matrix4x4 {public Vector3 Position,Scale;public float Angle;public int Tag;public static Matrix4x4 identity {get{return new Matrix4x4 {Tag=1,Scale=new Vector3(1,1,1)};}}public static Matrix4x4 TRS(Vector3 p,Quaternion q,Vector3 s){return new Matrix4x4 {Position=p,Scale=s,Angle=q.Angle,Tag=2};}}
    public struct Rect {public float x,y,width,height;public Rect(float a,float b,float c,float d){x=a;y=b;width=c;height=d;}public bool Contains(Vector2 p){return p.x>=x&&p.x<x+width&&p.y>=y&&p.y<y+height;}}
    public class Camera:Component {public static Camera main {get;set;}public static int ProjectionCalls;public bool FailProjection;public Vector3 WorldToScreenPoint(Vector3 p){ProjectionCalls++;p=p-transform.position;if(FailProjection)throw new Exception("projection failure");return new Vector3(640+p.x*1000/p.z,360+p.y*1000/p.z,p.z);}}
    public static class Screen {public static int Width=1280,Height=720;public static int height {get{return Height;}}public static int width {get{return Width;}}}
    public static class Time {public static float Now;public static float unscaledDeltaTime {get{return .016f;}}public static float realtimeSinceStartup {get{return Now;}}}
    public static class Mathf {public static float Sqrt(float f){return (float)Math.Sqrt(f);}public static float Sin(float f){return (float)Math.Sin(f);}public static float Cos(float f){return (float)Math.Cos(f);}public static float Atan2(float y,float x){return (float)Math.Atan2(y,x);}public static float Clamp(float v,float a,float b){return Math.Max(a,Math.Min(b,v));}public static float Lerp(float a,float b,float t){return a+(b-a)*Math.Min(1,Math.Max(0,t));}}
    public static class PlayerPrefs {public static Dictionary<string,string> Saved=new Dictionary<string,string>();public static string GetString(string k,string d){string v;return Saved.TryGetValue(k,out v)?v:d;}public static void SetString(string k,string v){Saved[k]=v;}public static void DeleteKey(string k){Saved.Remove(k);}}
    public static class SystemInfo {public static string deviceUniqueIdentifier {get{return "offline-device";}}}
    public enum TouchScreenKeyboardType {Default=0,ASCIICapable=1}
    public class TouchScreenKeyboard {public enum Status {Visible=0,Done=1,Canceled=2,LostFocus=3}public static TouchScreenKeyboard Open(string text,TouchScreenKeyboardType t,bool a,bool m,bool secure,bool alert,string placeholder,int limit){return new TouchScreenKeyboard {text=text};}public string text {get;set;}public Status status {get;set;}}
    public enum TextureFormat {RGBA32=4}public enum FilterMode {Bilinear=1}public enum TextureWrapMode {Clamp=1}
    public class Texture:Object {public FilterMode filterMode {get;set;}public TextureWrapMode wrapMode {get;set;}}public class Texture2D:Texture {public static int Created,Uploaded;public static bool FailUpload;public static Texture2D LastCreated;static Texture2D White=new Texture2D();public int Width,Height;public Color[] Pixels;public bool Released;public Texture2D(){}public Texture2D(int w,int h,TextureFormat f,bool mip){Width=w;Height=h;Created++;LastCreated=this;}public void SetPixels(Color[] p){if(FailUpload)throw new Exception("upload failure");Pixels=(Color[])p.Clone();Uploaded++;}public void Apply(bool mip,bool release){Released=release;}public static Texture2D whiteTexture {get{return White;}}}
    public enum EventType {MouseDown=0,MouseUp=1,MouseMove=2,MouseDrag=3,Repaint=7,Used=12}public enum ScaleMode {StretchToFill=0}
    public class Event {public static Event current {get;set;}public EventType type {get;set;}public Vector2 mousePosition {get;set;}public void Use(){type=EventType.Used;}}
    public enum TextAnchor {UpperLeft=0,MiddleLeft=3,MiddleCenter=4}
    public class GUIStyleState {public Color textColor {get;set;}}
    public sealed class Font {public static int Loads;public string Name;public static Font CreateDynamicFontFromOSFont(string[] names,int size){Loads++;return new Font {Name=names[0]};}}
    public class GUISkin {public Font font {get;set;}}
    public class GUIStyle {public static Font DefaultFont;public static void SetDefaultFont(Font f){DefaultFont=f;}public GUIStyle(){normal=new GUIStyleState();}public int fontSize {get;set;}public bool wordWrap {get;set;}public TextAnchor alignment {get;set;}public GUIStyleState normal {get;private set;}}
    public class Draw {public Texture Texture;public Rect Rect;public Matrix4x4 Matrix;public Color Color;public float Radius;public string Text;public int FontSize;public TextAnchor Align;public bool Wrap;}
    public static class GUI
    {
        static GUISkin Skin=new GUISkin {font=new Font {Name="game-original"}};public static GUISkin skin {get{return Skin;}set{Skin=value;}}
        public static Matrix4x4 matrix {get;set;}public static Color color {get;set;}public static Color contentColor {get;set;}public static List<Draw> Calls=new List<Draw>();
        public static void Label(Rect r,string s){Calls.Add(new Draw {Rect=r,Matrix=matrix,Color=color,Text=s});}
        public static void Label(Rect r,string s,GUIStyle style){Color c=style.normal.textColor;Calls.Add(new Draw {Rect=r,Matrix=matrix,Color=new Color(color.r*contentColor.r*c.r,color.g*contentColor.g*c.g,color.b*contentColor.b*c.b,color.a*contentColor.a*c.a),Text=s,FontSize=style.fontSize,Align=style.alignment,Wrap=style.wordWrap});}
        public static void DrawTexture(Rect r,Texture t){Calls.Add(new Draw {Rect=r,Matrix=matrix,Color=color,Texture=t});}
        public static void DrawTexture(Rect r,Texture t,ScaleMode m,bool a,float aspect,Color c,float b,float radius){Calls.Add(new Draw {Rect=r,Matrix=matrix,Color=c,Radius=radius});}
    }
}
namespace UnityEngine.Networking
{
    public class DownloadHandler {public string text {get;set;}}
    public class UnityWebRequest:IDisposable
    {
        public static List<UnityWebRequest> Requests=new List<UnityWebRequest>();public string Url,Method,Body;public bool Disposed;public Dictionary<string,string> Headers=new Dictionary<string,string>();public string Date;
        public static UnityWebRequest Get(string u){return new UnityWebRequest {Url=u,Method="GET"};}public static UnityWebRequest Put(string u,byte[] b){return new UnityWebRequest {Url=u,Method="PUT",Body=System.Text.Encoding.UTF8.GetString(b)};}
        public UnityWebRequestAsyncOperation SendWebRequest(){Requests.Add(this);return new UnityWebRequestAsyncOperation();}public void SetRequestHeader(string k,string v){Headers[k]=v;}public string GetResponseHeader(string k){return k=="Date"?Date:null;}
        public int timeout {get;set;}public bool isDone {get;set;}public long responseCode {get;set;}public string error {get;set;}public DownloadHandler downloadHandler {get;set;}public void Dispose(){Disposed=true;}
    }
    public class UnityWebRequestAsyncOperation {}
}
namespace SimpleJSON
{
    public enum JSONNodeType {Array=1,Object=2,String=3,Number=4,NullValue=5,Boolean=6,None=7,Custom=255}
    public class JSONNode
    {
        public object ValueObject;public bool Lazy;public JSONNode(object v){ValueObject=v;}public JSONNode this[string key] {get{var d=ValueObject as Dictionary<string,object>;return d!=null&&d.ContainsKey(key)?new JSONNode(d[key]):new JSONNode(null){Lazy=true};}}
        public bool IsObject {get{return ValueObject is Dictionary<string,object>;}}public JSONNodeType Tag {get{return Lazy?JSONNodeType.None:IsNull?JSONNodeType.NullValue:IsObject?JSONNodeType.Object:IsBoolean?JSONNodeType.Boolean:IsNumber?JSONNodeType.Number:IsString?JSONNodeType.String:JSONNodeType.Array;}}
        public bool IsNull {get{return !Lazy&&ValueObject==null;}}public bool IsBoolean {get{return ValueObject is bool;}}public bool IsNumber {get{return ValueObject is int||ValueObject is long||ValueObject is double||ValueObject is decimal;}}public bool IsString {get{return ValueObject is string;}}
        public bool AsBool {get{return Convert.ToBoolean(ValueObject);}}public double AsDouble {get{return Convert.ToDouble(ValueObject);}}public int AsInt {get{return Convert.ToInt32(ValueObject);}}public string Value {get{return Convert.ToString(ValueObject,System.Globalization.CultureInfo.InvariantCulture);}}
        public static JSONNode Parse(string json){return new JSONNode(new JavaScriptSerializer().DeserializeObject(json));}
    }
}
namespace GCommon
{
    public class SingletonModule<T> where T:class,new() {static T Value=new T();public static T instance {get{return Value;}}}
    public class UIModelManager:SingletonModule<UIModelManager> {public int Calls;public T GetModel<T>() where T:class,new(){Calls++;return new T();}}
}
namespace COW
{
    public class UIModelRole {}
    public static class GameFacade {public static UIModelRole m_modelRole;public static UIModelRole UIModelRole {get{return m_modelRole;}}public static GamePlay.JMAGGLCNGIG Match;public static GamePlay.Player Local;public static GamePlay.JMAGGLCNGIG CurrentMatch(){return Match;}public static GamePlay.Player GetLocalPlayerOrObServer(){return Local;}}
}
namespace COW.GamePlay
{
    public class SceneEditBoxSelectTool:UnityEngine.Component {public void OnGUI(){}}
    public class JMAGGLCNGIG {public IList Players=new ArrayList();public IList ILPNGCMEFFI(){return Players;}}
    public class CGKJLKPMGDJ {public UnityEngine.GameObject JHAINOBIFMA;public UnityEngine.Collider JINDNOFABKB;public UnityEngine.Vector3 HPCOJHGFEEG,DOJDNHCGFGK,HLDECMJFKJK,EKPLMDDKOGB,ONMKMEGMHOL;public bool DKPDBLLJEAA,EFMBNPNFGHM,CEOKOILBODN,CLOLKHNMNEK;}
    public class Player:UnityEngine.Component
    {
        public bool IsReallyInStealth(){return IsInStealth();}public CGKJLKPMGDJ LastAimingInfoFromWeapon {get{return FDMIEDDNCEC;}}
        public CGKJLKPMGDJ FDMIEDDNCEC=new CGKJLKPMGDJ();public bool Local,Team,Stealth,Firing,Movable=true;public int HP=100,MaximumHP=200,StealthCalls,AimCalls;public string Nick="Enemy test";public UnityEngine.Vector3 Origin;public UnityEngine.Quaternion LastRotation;
        public bool IsInStealth(){StealthCalls++;return Stealth;}public bool IsLocalPlayer(){return Local;}public bool FailHP;public int CurHP {get{if(FailHP)throw new Exception("despawn getter");return HP;}}public int MaxHP {get{return MaximumHP;}}public bool FailNick;public string NickName {get{if(FailNick)throw new Exception("despawn after box");return Nick;}}public bool IsLocalTeammate(bool b){return Team;}
        public UnityEngine.Transform Root,Head,Neck,ArmL,ArmR,HandL,HandR,LegL,LegR,FootL,FootR;public UnityEngine.Collider Collider;
        public UnityEngine.Transform RootTransform {get{return Root;}}public UnityEngine.Transform GetHeadTF(){return Head;}public UnityEngine.Transform NeckBone {get{return Neck;}}public UnityEngine.Transform ArmBoneLeft {get{return ArmL;}}public UnityEngine.Transform ArmBoneRight {get{return ArmR;}}public UnityEngine.Transform HandBoneLeft {get{return HandL;}}public UnityEngine.Transform HandBoneRight {get{return HandR;}}public UnityEngine.Transform LegBoneLeft {get{return LegL;}}public UnityEngine.Transform LegBoneRight {get{return LegR;}}public UnityEngine.Transform FootBoneLeft {get{return FootL;}}public UnityEngine.Transform FootBoneRight {get{return FootR;}}
        public UnityEngine.Collider HeadCollider {get{return Collider;}}public UnityEngine.Vector3 AimStartPostion {get{return Origin;}}public bool IsFiring(){return Firing;}public void SetAimRotation(UnityEngine.Quaternion q,bool b){LastRotation=q;AimCalls++;}
    }
}
