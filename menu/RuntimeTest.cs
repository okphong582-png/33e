// Executes the produced bytes in the pinned upstream IFix interpreter.
// Unity/game APIs below are test doubles; this cannot verify iPhone IL2CPP loading.
using System;
using System.IO;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using IFix.Core;

namespace IFix.Core
{
    // Unused legacy entry points required by upstream VirtualMachine.cs.
    static class PatchManager
    {
        public static void Load(Stream s) { throw new NotSupportedException(); }
        public static void Unload(Assembly a) { throw new NotSupportedException(); }
    }
}
namespace UnityEngine
{
    public class Object
    {
        public string name { get; set; }
        public bool persistent;
        public static bool operator ==(Object a,Object b) { return ReferenceEquals(a,b); }
        public static bool operator !=(Object a,Object b) { return !ReferenceEquals(a,b); }
        public override bool Equals(object o) { return ReferenceEquals(this,o); }
        public override int GetHashCode() { return base.GetHashCode(); }
        public static void DontDestroyOnLoad(Object o) { o.persistent=true; }
    }
    public class Component : Object
    {
        public GameObject gameObject { get; set; }
        public Transform transform { get { return gameObject.transform; } }
    }
    public class GameObject : Object
    {
        public static readonly Dictionary<string,GameObject> World=new Dictionary<string,GameObject>();
        public static bool FailAdd;
        public Transform transform { get; private set; }
        public bool activeInHierarchy { get; set; }
        public Component component;
        public GameObject(string n) { name=n;transform=new Transform();activeInHierarchy=true;World[n]=this; }
        public static GameObject Find(string n) { GameObject g;return World.TryGetValue(n,out g)?g:null; }
        public Component GetComponent(Type t) { return component!=null && t.IsInstanceOfType(component)?component:null; }
        public Component AddComponent(Type t)
        {
            if(FailAdd)throw new InvalidOperationException("simulated component creation failure");
            component=(Component)Activator.CreateInstance(t);component.gameObject=this;return component;
        }
    }
    public class Transform : Object
    {
        public Vector3 localScale { get; set; }
        public Vector3 position { get; set; }
        public Transform() { localScale=new Vector3(1,1,1); }
    }
    public struct Vector3 { public float x,y,z;public Vector3(float a,float b,float c){x=a;y=b;z=c;} }
    public struct Vector2 { public float x,y;public Vector2(float a,float b){x=a;y=b;} }
    public struct Color { public float r,g,b,a;public Color(float x,float y,float z,float w){r=x;g=y;b=z;a=w;} }
    public struct Matrix4x4 { public int tag;public static Matrix4x4 identity { get {return new Matrix4x4 {tag=1};} } }
    public struct Rect
    {
        public float x,y,width,height;
        public Rect(float a,float b,float c,float d){x=a;y=b;width=c;height=d;}
        public bool Contains(Vector2 p){return p.x>=x && p.x<x+width && p.y>=y && p.y<y+height;}
    }
    public enum EventType { MouseDown=0,MouseUp=1,Repaint=7,Used=12 }
    public class Event { public static Event current {get;set;} public EventType type {get;set;} public Vector2 mousePosition {get;set;} public void Use(){type=EventType.Used;} }
    public class Texture : Object {}
    public class Texture2D : Texture { public static Texture2D whiteTexture { get {return new Texture2D();} } }
    public static class GUI
    {
        public static Color color {get;set;}
        public static Matrix4x4 matrix {get;set;}
        public static readonly List<string> Labels=new List<string>();
        public static readonly List<Rect> Boxes=new List<Rect>();
        public static void Label(Rect r,string s) {Labels.Add(s);}
        public static void DrawTexture(Rect r,Texture t) {if(color.r<0.1f && color.g>0.9f)Boxes.Add(r);}
    }
    public static class Screen { public static int height {get{return 720;}} public static int width {get{return 1280;}} }
    public class Camera : Object
    {
        public static Camera main {get;set;}
        public static bool FailProjection;
        public Vector3 WorldToScreenPoint(Vector3 v) { if(FailProjection)throw new InvalidOperationException("projection failure");return v; }
    }
}
namespace COW
{
    public static class GameFacade {public static GamePlay.JMAGGLCNGIG Match;public static GamePlay.JMAGGLCNGIG CurrentMatch(){return Match;}}
}
namespace COW.GamePlay
{
    public class SceneEditBoxSelectTool : UnityEngine.Component {}
    public class JMAGGLCNGIG {public IList Players=new ArrayList();public IList ILPNGCMEFFI(){return Players;}}
    public class Player : UnityEngine.Component
    {
        public bool Stealth,Local,Team;
        public int HP=100,StealthCalls;
        public bool Movable=true;
        public UnityEngine.Transform Root,Head;
        public bool IsInStealth(){StealthCalls++;return Stealth;}
        public bool IsLocalPlayer(){return Local;}
        public int CurHP {get{return HP;}}
        public bool IsLocalTeammate(bool b){return Team;}
        public UnityEngine.Transform RootTransform {get{return Root;}}
        public UnityEngine.Transform GetHeadTF(){return Head;}
    }
}
unsafe static class RuntimeTest
{
    static void Check(bool b,string message) {if(!b)throw new Exception("FAIL: "+message);}
    static Type Resolve(string full)
    {
        var name=full.Split(',')[0];var type=Type.GetType(name)??typeof(RuntimeTest).Assembly.GetType(name);
        if(type==null)throw new Exception("Missing test type: "+name);return type;
    }
    static MethodBase ReadMethod(BinaryReader r,Type[] types)
    {
        Check(!r.ReadBoolean(),"non-generic extern");var owner=types[r.ReadInt32()];string name=r.ReadString();
        var parameters=new Type[r.ReadInt32()];for(int i=0;i<parameters.Length;i++)parameters[i]=types[r.ReadInt32()];
        MethodBase m=name==".ctor"?(MethodBase)owner.GetConstructor(parameters):owner.GetMethod(name,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.Static,null,parameters,null);
        Check(m!=null,"resolve extern "+owner+"."+name);return m;
    }
    static VirtualMachine Load(string file)
    {
        var allocated=new List<IntPtr>();
        using(var r=new BinaryReader(File.OpenRead(file)))
        {
            r.ReadUInt64();r.ReadString();
            var types=new Type[r.ReadInt32()];for(int i=0;i<types.Length;i++)types[i]=Resolve(r.ReadString());
            int count=r.ReadInt32();Check(count==3,"three VM methods");
            var root=Marshal.AllocHGlobal(IntPtr.Size*count);allocated.Add(root);Instruction** codes=(Instruction**)root;
            var handlers=new ExceptionHandler[count][];
            for(int i=0;i<count;i++)
            {
                int n=r.ReadInt32();var ptr=Marshal.AllocHGlobal(sizeof(Instruction)*n);allocated.Add(ptr);codes[i]=(Instruction*)ptr;
                for(int j=0;j<n;j++){codes[i][j].Code=(IFix.Core.Code)r.ReadInt32();codes[i][j].Operand=r.ReadInt32();}
                handlers[i]=new ExceptionHandler[r.ReadInt32()];
                for(int j=0;j<handlers[i].Length;j++)handlers[i][j]=new ExceptionHandler {HandlerType=(ExceptionHandlerType)r.ReadInt32(),CatchType=types[r.ReadInt32()],TryStart=r.ReadInt32(),TryEnd=r.ReadInt32(),HandlerStart=r.ReadInt32(),HandlerEnd=r.ReadInt32()};
            }
            var methods=new MethodBase[r.ReadInt32()];for(int i=0;i<methods.Length;i++)methods[i]=ReadMethod(r,types);
            var strings=new string[r.ReadInt32()];for(int i=0;i<strings.Length;i++)strings[i]=r.ReadString();
            var fields=new FieldInfo[r.ReadInt32()];for(int i=0;i<fields.Length;i++){Check(!r.ReadBoolean(),"no new fields");var owner=types[r.ReadInt32()];fields[i]=owner.GetField(r.ReadString());Check(fields[i]!=null,"resolve field");}
            return new VirtualMachine(codes,delegate {foreach(var ptr in allocated)Marshal.FreeHGlobal(ptr);}) {ExternTypes=types,ExternMethods=methods,InternStrings=strings,FieldInfos=fields,ExceptionHandlers=handlers,StaticFieldTypes=new Type[0],Cctors=new int[0]};
        }
    }
    static bool Bootstrap(VirtualMachine vm,COW.GamePlay.Player p)
    {
        var c=Call.Begin();c.PushObject(p);vm.Execute(0,ref c,1);bool result=c.GetBoolean();Call.End(ref c);return result;
    }
    static void Frame(VirtualMachine vm,UnityEngine.Component driver,UnityEngine.EventType type,int x=0,int y=0)
    {
        UnityEngine.Event.current=new UnityEngine.Event {type=type,mousePosition=new UnityEngine.Vector2(x,y)};
        UnityEngine.GUI.Labels.Clear();UnityEngine.GUI.Boxes.Clear();
        UnityEngine.GUI.color=new UnityEngine.Color(.3f,.4f,.5f,1);UnityEngine.GUI.matrix=new UnityEngine.Matrix4x4 {tag=99};
        var c=Call.Begin();c.PushObject(driver);vm.Execute(1,ref c,1);Call.End(ref c);
        Check(UnityEngine.GUI.color.r==.3f && UnityEngine.GUI.matrix.tag==99,"restore GUI state");
    }
    static COW.GamePlay.Player Enemy()
    {
        return new COW.GamePlay.Player {gameObject=new UnityEngine.GameObject("enemy"),Root=new UnityEngine.Transform {position=new UnityEngine.Vector3(500,100,10)},Head=new UnityEngine.Transform {position=new UnityEngine.Vector3(500,300,10)}};
    }
    static int Main(string[] args)
    {
        var vm=Load(args[0]);var player=new COW.GamePlay.Player {Stealth=true};
        Check(Bootstrap(vm,player),"true native return");Check(player.StealthCalls==1 && player.Movable,"native call once and movement state preserved");
        var g=UnityEngine.GameObject.Find("__33e_menu_driver");Check(g!=null && g.component!=null && g.persistent,"create persistent driver");
        player.Stealth=false;Check(!Bootstrap(vm,player),"false native return");Check(!Bootstrap(vm,null),"null player");
        var driver=g.component;Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Labels.Contains("ESP BOX: ON"),"menu visible without gestures or match data");
        COW.GameFacade.Match=new COW.GamePlay.JMAGGLCNGIG();UnityEngine.Camera.main=new UnityEngine.Camera();
        var enemy=Enemy();COW.GameFacade.Match.Players.Add(enemy);Frame(vm,driver,UnityEngine.EventType.Repaint);
        Check(UnityEngine.GUI.Boxes.Count==4,"ESP four edges");var box=UnityEngine.GUI.Boxes[0];Check(box.x==450 && box.y==420 && box.width==100 && box.height==2,"box geometry");
        Check(enemy.HP==100 && enemy.Movable && enemy.Root.position.x==500,"enemy state unchanged");
        Frame(vm,driver,UnityEngine.EventType.MouseUp,60,110);Check(g.transform.localScale.y==0,"toggle off");
        Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Boxes.Count==0 && UnityEngine.GUI.Labels.Contains("ESP BOX: OFF"),"off label, no boxes");
        Frame(vm,driver,UnityEngine.EventType.MouseUp,60,110);Check(g.transform.localScale.y==1,"toggle on");
        UnityEngine.Camera.FailProjection=true;Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Labels.Contains("ESP BOX: ON"),"projection failure preserves menu");UnityEngine.Camera.FailProjection=false;
        enemy.Local=true;Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Boxes.Count==0,"local filtered");enemy.Local=false;
        enemy.Team=true;Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Boxes.Count==0,"team filtered");enemy.Team=false;
        enemy.HP=0;Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Boxes.Count==0,"dead filtered");enemy.HP=100;
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(enemy);Frame(vm,driver,UnityEngine.EventType.Repaint);Check(UnityEngine.GUI.Boxes.Count==512,"bounded traversal");
        UnityEngine.GameObject.World.Clear();UnityEngine.GameObject.FailAdd=true;Check(!Bootstrap(vm,player),"bootstrap exception preserves false result");
        player.Stealth=true;Check(Bootstrap(vm,player),"bootstrap exception preserves true result");Check(player.Movable,"bootstrap failure leaves movement state intact");
        UnityEngine.GameObject.FailAdd=false;Bootstrap(vm,player);Check(UnityEngine.GameObject.Find("__33e_menu_driver").component!=null,"retry component creation");
        Console.WriteLine("PASS: upstream IFix execution, native results, persistent bootstrap, always-visible menu, ESP geometry, toggle, filtering, loop bound, GUI restoration, exception isolation. Unity/game APIs mocked; iPhone loading unverified.");
        GC.KeepAlive(vm);return 0;
    }
}
