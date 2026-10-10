// Execute the final patch in the pinned Tencent VM with offline game/Unity doubles.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Globalization;
using System.Text;
using IFix.Core;
using UnityEngine;
using UnityEngine.Networking;
using COW.GamePlay;
using Object=System.Object;
unsafe static class MizzeRuntimeTest
{
    static VirtualMachine Vm;static Dictionary<string,int> Methods=new Dictionary<string,int>();static Dictionary<string,NewFieldInfo> Fields=new Dictionary<string,NewFieldInfo>();static Component Driver;static int Checks;
    static void Check(bool ok,string message){Checks++;if(!ok)throw new Exception("FAIL: "+message);}
    static Type Resolve(string full)
    {
        return Type.GetType(full,a=>a.Name=="mscorlib"?typeof(object).Assembly:typeof(MizzeRuntimeTest).Assembly,(a,n,c)=>a.GetType(n,true,c),true);
    }
    static MethodBase ReadMethod(BinaryReader r,Type[] types)
    {
        bool generic=r.ReadBoolean();var owner=types[r.ReadInt32()];string name=r.ReadString();var args=generic?new Type[r.ReadInt32()]:new Type[0];for(int i=0;i<args.Length;i++)args[i]=types[r.ReadInt32()];
        var ps=new Type[r.ReadInt32()];for(int i=0;i<ps.Length;i++){if(generic&&r.ReadBoolean())throw new Exception("Unexpected generic parameter descriptor");ps[i]=types[r.ReadInt32()];}
        var flags=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.Static;
        MethodBase method=generic?(MethodBase)owner.GetMethods(flags).Single(m=>m.Name==name&&m.IsGenericMethodDefinition&&m.GetGenericArguments().Length==args.Length&&m.GetParameters().Select(p=>p.ParameterType).SequenceEqual(ps)).MakeGenericMethod(args):name==".ctor"?(MethodBase)owner.GetConstructor(flags,null,ps,null):owner.GetMethod(name,flags,null,ps,null);
        Check(method!=null,"resolve "+owner+"."+name);return method;
    }
    static VirtualMachine Load(string file)
    {
        var allocated=new List<IntPtr>();using(var r=new BinaryReader(File.OpenRead(file)))
        {
            Check(r.ReadUInt64()==0x66a319b20db4a2cb,"game container magic");r.ReadString();var types=new Type[r.ReadInt32()];for(int i=0;i<types.Length;i++)types[i]=Resolve(r.ReadString());
            int count=r.ReadInt32();var root=Marshal.AllocHGlobal(IntPtr.Size*count);allocated.Add(root);Instruction** codes=(Instruction**)root;var handlers=new ExceptionHandler[count][];
            for(int i=0;i<count;i++){int n=r.ReadInt32();var ptr=Marshal.AllocHGlobal(sizeof(Instruction)*n);allocated.Add(ptr);codes[i]=(Instruction*)ptr;for(int j=0;j<n;j++){codes[i][j].Code=(IFix.Core.Code)r.ReadInt32();codes[i][j].Operand=r.ReadInt32();}handlers[i]=new ExceptionHandler[r.ReadInt32()];for(int j=0;j<handlers[i].Length;j++){int kind=r.ReadInt32(),catchId=r.ReadInt32();handlers[i][j]=new ExceptionHandler {HandlerType=(ExceptionHandlerType)kind,CatchType=catchId<0?null:types[catchId],TryStart=r.ReadInt32(),TryEnd=r.ReadInt32(),HandlerStart=r.ReadInt32(),HandlerEnd=r.ReadInt32()};}}
            var externs=new MethodBase[r.ReadInt32()];for(int i=0;i<externs.Length;i++)externs[i]=ReadMethod(r,types);var strings=new string[r.ReadInt32()];for(int i=0;i<strings.Length;i++)strings[i]=r.ReadString();
            var fields=new FieldInfo[r.ReadInt32()];var newFields=new Dictionary<int,NewFieldInfo>();
            for(int i=0;i<fields.Length;i++){bool added=r.ReadBoolean();var owner=types[r.ReadInt32()];string name=r.ReadString();if(added){var f=new NewFieldInfo {Name=name,DeclaringType=owner,FieldType=types[r.ReadInt32()],MethodId=r.ReadInt32()};newFields.Add(i,f);Fields.Add(name,f);Check(owner.GetField(name)==null,"VM owns new field "+name);}else{fields[i]=owner.GetField(name,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.Static);Check(fields[i]!=null,"resolve field "+name);}}
            Check(r.ReadInt32()==0,"no static-slot metadata");Check(r.ReadInt32()==0,"no closures");r.ReadString();r.ReadString();Check(!r.ReadBoolean(),"game flag");int fixes=r.ReadInt32();Check(fixes==4,"four lifecycle/GUI/aim fixes");for(int i=0;i<fixes;i++){var m=ReadMethod(r,types);int id=r.ReadInt32();Check(Methods[m.Name]==id,"fix table maps "+m.Name);}Check(r.ReadInt32()==0&&r.BaseStream.Position==r.BaseStream.Length,"complete container");
            return new VirtualMachine(codes,delegate{foreach(var ptr in allocated)Marshal.FreeHGlobal(ptr);}) {ExternTypes=types,ExternMethods=externs,InternStrings=strings,FieldInfos=fields,NewFieldInfos=newFields,ExceptionHandlers=handlers,StaticFieldTypes=new Type[0],Cctors=new int[0]};
        }
    }
    static void Set(string name,object value){Fields[name].SetValue(null,value);}static T Get<T>(string name){return (T)Fields[name].GetValue(null);}
    static object Run(string name,params object[] args)
    {
        var c=Call.Begin();foreach(var a in args){if(a is float)c.PushSingle((float)a);else if(a is int)c.PushInt32((int)a);else if(a is bool)c.PushBoolean((bool)a);else if(a!=null&&a.GetType().IsValueType)c.PushValueType(a);else c.PushObject(a);}Vm.Execute(Methods[name],ref c,args.Length);object result=null;
        if(name=="get_UIModelRole"||name=="get_LastAimingInfoFromWeapon"||name=="MzPickTarget"||name=="MzHash")result=c.GetObject();else if(name=="IsReallyInStealth"||name=="MzAuthorized"||name=="MzEnemy")result=c.GetBoolean();Call.End(ref c);return result;
    }
    static void Frame(EventType type,float x=0,float y=0)
    {
        Event.current=new Event {type=type,mousePosition=new Vector2(x*(Get<float>("MzScale")>0?Get<float>("MzScale"):1.35f),y*(Get<float>("MzScale")>0?Get<float>("MzScale"):1.35f))};GUI.Calls.Clear();GUI.color=new Color(.3f,.4f,.5f,1);GUI.contentColor=new Color(.4f,.5f,.6f,.7f);GUI.matrix=new Matrix4x4 {Tag=99};Run("OnGUI",Driver);Check(GUI.color.r==.3f&&GUI.contentColor.r==.4f&&GUI.contentColor.a==.7f&&GUI.matrix.Tag==99,"GUI color/content/matrix restored");
    }
    static void Click(float x,float y){Frame(EventType.MouseDown,x,y);Frame(EventType.MouseUp,x,y);}
    static Transform Bone(float x,float y,float z){return new Transform {position=new Vector3(x,y,z)};}
    static Player Enemy(float x=.2f,float headY=1.2f,float z=10)
    {
        var p=new Player {gameObject=new GameObject("enemy"),Root=Bone(x,-.5f,z),Head=Bone(x,headY,z),Neck=Bone(x,headY-.3f,z),ArmL=Bone(x-.2f,.5f,z),HandL=Bone(x-.4f,.2f,z),ArmR=Bone(x+.2f,.5f,z),HandR=Bone(x+.4f,.2f,z),LegL=Bone(x-.15f,-.8f,z),FootL=Bone(x-.15f,-1.2f,z),LegR=Bone(x+.15f,-.8f,z),FootR=Bone(x+.15f,-1.2f,z)};p.Collider=new Collider {gameObject=p.gameObject};return p;
    }
    static string Record(string device,bool enabled=true,long expiry=1791633660000,string extra="")
    {
        return "{\"protocol\":4,\"enabled\":"+(enabled?"true":"false")+",\"expiresAt\":"+expiry+(device==null?"":",\"binding\":{\"deviceHash\":\""+device+"\",\"version\":1,\"claimedAt\":1791633600000}")+extra+"}";
    }
    const string Date="Sat, 10 Oct 2026 12:00:00 GMT";
    static void License(string record,string date=Date){Run("MzCheckRecord",record,date);}
    static int Lines(){return GUI.Calls.Count(d=>d.Text==null&&d.Matrix.Tag==2);}static int Labels(){return GUI.Calls.Count(d=>d.Text!=null);}
    static string Number(float f){return f.ToString("0.###",CultureInfo.InvariantCulture);}
    static void Snapshot(string file)
    {
        var b=new StringBuilder("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""+Screen.width+"\" height=\""+Screen.height+"\" viewBox=\"0 0 "+Screen.width+" "+Screen.height+"\"><rect width=\"100%\" height=\"100%\" fill=\"#26333d\"/>");
        foreach(var d in GUI.Calls){var r=d.Rect;string c="rgb("+(int)(d.Color.r*255)+","+(int)(d.Color.g*255)+","+(int)(d.Color.b*255)+")";float sx=d.Matrix.Scale.x==0?1:d.Matrix.Scale.x,sy=d.Matrix.Scale.y==0?1:d.Matrix.Scale.y;
            b.Append("<g transform=\"translate("+Number(d.Matrix.Position.x)+" "+Number(d.Matrix.Position.y)+") rotate("+Number(d.Matrix.Angle)+") scale("+Number(sx)+" "+Number(sy)+")\" opacity=\""+Number(d.Color.a)+"\">");
            if(d.Text!=null){int font=d.FontSize>0?d.FontSize:12;float x=d.Align==TextAnchor.MiddleCenter?r.x+r.width*.5f:r.x,y=d.Align==TextAnchor.UpperLeft?r.y+font:r.y+r.height*.5f+font*.33f;string anchor=d.Align==TextAnchor.MiddleCenter?"middle":"start";var lines=new List<string>();if(d.Wrap){string line="";foreach(string word in d.Text.Split(' ')){if(line.Length>0&&(line.Length+word.Length+1)*font*.54f>r.width){lines.Add(line);line=word;}else line+=(line.Length>0?" ":"")+word;}lines.Add(line);}else lines.Add(d.Text);
                for(int i=0;i<lines.Count&&i*font*1.2f<r.height;i++)b.Append("<text x=\""+Number(x)+"\" y=\""+Number(y+i*font*1.2f)+"\" text-anchor=\""+anchor+"\" font-family=\"Arial\" font-size=\""+font+"\" fill=\""+c+"\">"+System.Security.SecurityElement.Escape(lines[i])+"</text>");
            }else b.Append("<rect x=\""+Number(r.x)+"\" y=\""+Number(r.y)+"\" width=\""+Number(r.width)+"\" height=\""+Number(r.height)+"\" rx=\""+Number(d.Radius)+"\" fill=\""+c+"\"/>");b.Append("</g>");
        }b.Append("</svg>");File.WriteAllText(file,b.ToString());
    }
    static void ExtendedChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[13]=true;
        Screen.Width=1280;Screen.Height=720;Set("MzFov",150f);Set("MzRange",150f);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",3);Set("MzColorTarget",0);
        COW.GameFacade.Match=new JMAGGLCNGIG();var bad=Enemy();bad.FailHP=true;var enemy=Enemy();COW.GameFacade.Match.Players.Add(bad);COW.GameFacade.Match.Players.Add(enemy);
        GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==52,"despawn getter failure leaves next enemy and FOV rendering intact");Check(!Get<bool>("MzDrawingEsp"),"drawing flag restored after exception");
        bad.FailHP=false;bad.Destroyed=true;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==52,"Unity destroyed player wrapper skipped");
        Click(210,222);Color esp=Get<Color>("MzEspColor");Check(esp.r==.3f&&esp.g==.65f,"palette changes actual ESP color");Check(PlayerPrefs.Saved.ContainsKey("Mizze.Color.ESP"),"palette persisted after tap");
        Click(270,143);Click(210,222);Color fov=Get<Color>("MzFovColor");Check(fov.r==.3f&&fov.b==1,"FOV palette independent");
        Frame(EventType.MouseDown,230,349);Frame(EventType.MouseDrag,390,349);Frame(EventType.MouseUp,390,349);fov=Get<Color>("MzFovColor");Check(Math.Abs(fov.r-(390-134-84)/270f)<.001f,"RGB drag controls actual red channel");Check(Get<int>("MzDragMode")==0&&PlayerPrefs.Saved["Mizze.Color.FOV"].Length==6,"RGB releases drag and persists color");
        GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Any(d=>d.Text==null&&Math.Abs(d.Color.r-fov.r)<.001f&&d.Color.b==1),"FOV renderer consumes selected color");Check(GUI.Calls.Any(d=>d.Text==null&&d.Color.r==esp.r&&d.Color.g==esp.g),"box renderer consumes selected color");
        Click(390,143);Click(210,222);Check(Get<Color>("MzHealthColor").b==1,"health palette independent");
        Set("MzColorTarget",0);Run("MzAppearanceInit");Check(Get<Color>("MzEspColor").b==1&&Math.Abs(Get<Color>("MzFovColor").r-fov.r)<.005f,"colors survive appearance reinitialization");
        Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Màu ESP")&&GUI.Calls.Any(d=>d.Text=="Đỏ "+((int)(Get<Color>("MzEspColor").r*255)).ToString()),"UTF-8 Vietnamese survives translated bytecode");Check(Font.Loads==1&&GUIStyle.DefaultFont==GUI.skin.font,"font loaded once and game default restored");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;
        int maximum=0;for(int frame=0;frame<1200;frame++){if(frame%20==0)((Player)COW.GameFacade.Match.Players[frame%150]).Destroyed=true;GUI.Calls.Clear();Run("MzRender");maximum=Math.Max(maximum,GUI.Calls.Count);if(frame%100==0){Check(GUI.Calls.Count<=704&&Get<int>("MzDrawBudget")>=0&&!Get<bool>("MzDrawingEsp"),"bounded all-ESP stress frame "+frame);GC.Collect();}}Check(maximum>300,"stress exercised dense all-feature drawing");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==0&&!Get<bool>("MzDrawingEsp"),"match teardown resets render state");
        Set("MzOpen",true);Set("MzTab",3);for(int i=0;i<18;i++)Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
    }
    static int Main(string[] args)
    {
        foreach(var line in File.ReadAllLines(args[1])){var a=line.Split('\t');Methods.Add(a[2],int.Parse(a[0]));}Vm=Load(args[0]);
        // Lobby getter preserves the lazy model and bootstraps with no match or player.
        var model=Run("get_UIModelRole");Check(model!=null&&System.Object.ReferenceEquals(model,Run("get_UIModelRole")),"lobby cached model preserved");Check(GCommon.UIModelManager.instance.Calls==1,"model initialized once");
        var g=GameObject.Find("__mizze_driver");Check(g!=null&&g.Added!=null&&g.Persistent,"persistent driver created in lobby");Driver=g.Added;Check(Get<float>("MzPanelX")==120&&Get<float>("MzPanelY")==16,"new initial panel position");Set("MzPanelX",98f);Set("MzPanelY",30f);
        Frame(EventType.Repaint);Check(Labels()==1&&GUI.Calls.Any(d=>d.Text=="Mizze"),"only circular Mizze launcher initially");Check(Math.Abs(Get<float>("MzScale")-1.35f)<.0001f,"larger display scale at 720p");Check(GUI.Calls.Any(d=>d.Text==null&&d.Rect.width==74&&d.Color.r<.03f&&d.Color.g<.03f),"launcher uses explicit black shader color");Check(GUI.Calls.Single(d=>d.Text=="Mizze").FontSize==20&&GUI.Calls.Single(d=>d.Text=="Mizze").Matrix.Scale.x==1.35f,"larger launcher font and size");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"launcher.svg"));
        var local=Enemy(0);local.Local=true;local.Stealth=true;local.Origin=new Vector3(0,0,1);COW.GameFacade.Local=local;
        Check((bool)Run("IsReallyInStealth",local)&&local.StealthCalls==1&&local.Movable,"native stealth and movement preserved");local.Stealth=false;Check(!(bool)Run("IsReallyInStealth",local),"false stealth preserved");
        Click(56,128);Check(Get<bool>("MzOpen")&&Get<int>("MzTab")==2,"launcher opens key panel");Frame(EventType.MouseDown,56,128);Frame(EventType.MouseDrag,206,228);Frame(EventType.MouseUp,206,228);Check(Get<float>("MzBubbleX")==174&&Get<bool>("MzOpen"),"bubble drag does not toggle");
        Frame(EventType.MouseDown,140,54);Frame(EventType.MouseDrag,180,94);Frame(EventType.MouseUp,180,94);Check(Get<float>("MzPanelX")==138&&Get<float>("MzPanelY")==70,"panel drags independently");Set("MzPanelX",98f);Set("MzPanelY",30f);
        string hash=Get<string>("MzDeviceHash");Check(hash.Length==64,"device hash initialized");License(Record(hash));Check((bool)Run("MzAuthorized"),"missing lock handled as absent with game-like lazy JSON node");License(Record(hash,extra:",\"lock\":null"));Check((bool)Run("MzAuthorized"),"explicit null lock accepted");License(Record(hash,extra:",\"lock\":{\"until\":1791633500000,\"message\":\"finished\"}"));Check((bool)Run("MzAuthorized"),"expired temporary lock accepted");License(Record(hash,extra:",\"lock\":{}"));Check(!(bool)Run("MzAuthorized")&&Get<string>("MzLicenseMessage").Contains("until/message"),"malformed lock still rejected with field-specific message");License(Record(hash,extra:",\"lock\":false"));Check(!(bool)Run("MzAuthorized")&&Get<string>("MzLicenseMessage").Contains("lock sai định dạng"),"non-object lock still rejected");License(Record(hash));
        License(Record(hash,false));Check(!(bool)Run("MzAuthorized"),"disabled key rejected");License(Record(hash,expiry:1791633599000));Check(!(bool)Run("MzAuthorized"),"expired key rejected");License(Record(new string('a',64)));Check(!(bool)Run("MzAuthorized"),"other device rejected");License(Record(hash,extra:",\"lock\":{\"until\":0,\"message\":\"locked\"}"));Check(!(bool)Run("MzAuthorized"),"permanent lock rejected");License(Record(hash).Replace("\"enabled\":true","\"enabled\":\"true\""));Check(!(bool)Run("MzAuthorized"),"typed boolean required");License(Record(hash),"bad-date");Check(!(bool)Run("MzAuthorized"),"invalid server date rejected");
        Set("MzKeyHash",new string('b',64));Set("MzCanClaim",true);Set("MzClaimAttempted",false);License(Record(null));var request=Get<UnityWebRequest>("MzRequest");Check(request.Method=="PUT"&&request.Headers["if-match"]=="null_etag"&&!(bool)Run("MzAuthorized"),"conditional first binding never authorizes before readback");request.responseCode=412;request.isDone=true;Run("MzLicensePoll");request=Get<UnityWebRequest>("MzRequest");Check(request.Method=="GET","binding conflict rereads server");request.responseCode=200;request.Date=Date;request.downloadHandler=new DownloadHandler {text=Record(new string('a',64))};request.isDone=true;Run("MzLicensePoll");Check(!(bool)Run("MzAuthorized"),"losing binding claim stays rejected");
        Run("MzBeginRead");request=Get<UnityWebRequest>("MzRequest");Set("MzKeyboard",new TouchScreenKeyboard {status=TouchScreenKeyboard.Status.Done,text="  test-key-new  "});Run("MzLicensePoll");Check(request.Disposed&&Get<UnityWebRequest>("MzRequest").Url.Contains((string)Run("MzHash","TEST-KEY-NEW")),"key change cancels stale request");Get<UnityWebRequest>("MzRequest").Dispose();Set("MzRequest",null);Set("MzKeyHash","");
        License(Record(hash));float deadline=Get<float>("MzLeaseDeadline");Time.Now=deadline+1;Check(!(bool)Run("MzAuthorized"),"lease expires without network result");Time.Now=0;License(Record(hash));
        COW.GameFacade.Match=new JMAGGLCNGIG();Camera.main=new Camera {gameObject=new GameObject("camera")};var enemy=Enemy();COW.GameFacade.Match.Players.Add(enemy);var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;
        GUI.Calls.Clear();Run("MzRender");Check(Lines()==4,"2D box four edges");switches[2]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==8,"corner box eight edges");switches[2]=false;switches[3]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==12,"3D box twelve edges");switches[1]=false;switches[3]=false;
        switches[4]=true;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Any(d=>d.Text==enemy.Nick),"real nickname label");switches[4]=false;switches[5]=true;GUI.Calls.Clear();Run("MzRender");var bars=GUI.Calls.Where(d=>d.Text==null).ToArray();Check(bars.Length==2&&bars[1].Rect.height==bars[0].Rect.height*.5f,"health geometry from current/max HP");switches[5]=false;
        switches[6]=true;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Any(d=>d.Text!=null&&d.Text.EndsWith(" m")),"distance label");switches[6]=false;switches[7]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==10,"skeleton projects ten bone segments");switches[7]=false;switches[8]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==16,"head circle reduced to sixteen segments");switches[8]=false;switches[9]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==3,"XYZ axes");switches[9]=false;switches[10]=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==1,"ESP snapline");switches[10]=false;
        switches[1]=true;enemy.Team=true;GUI.Calls.Clear();Run("MzRender");Check(Lines()==0&&Run("MzPickTarget")==null,"team filtered from ESP and aim");enemy.Team=false;enemy.HP=0;GUI.Calls.Clear();Run("MzRender");Check(Lines()==0,"dead filtered");enemy.HP=100;enemy.Head.position=new Vector3(float.NaN,1,10);Check(Run("MzPickTarget")==null,"invalid projection filtered");enemy.Head.position=new Vector3(.2f,1.2f,10);
        Set("MzFov",20f);Check(Run("MzPickTarget")==null,"small FOV excludes target");Set("MzFov",150f);Check(System.Object.ReferenceEquals(Run("MzPickTarget"),enemy),"head inside FOV selected");Set("MzRange",5f);Check(Run("MzPickTarget")==null,"range cap applies to aim");Set("MzRange",150f);
        switches[11]=true;Run("MzRunAim");Check(local.AimCalls==0,"normal aim idle without firing");local.Firing=true;Run("MzRunAim");var expected=Vector3.Normalize(enemy.Head.position-local.Origin);Check(local.AimCalls==1&&Vector3.Distance(local.LastRotation.Direction,expected)<.0001,"normal aim calls game rotation toward head");switches[11]=false;switches[12]=true;
        var aim=local.FDMIEDDNCEC;aim.HPCOJHGFEEG=new Vector3(7,8,9);aim.EFMBNPNFGHM=true;var result=Run("get_LastAimingInfoFromWeapon",local);Check(Object.ReferenceEquals(result,aim)&&aim.JHAINOBIFMA==enemy.gameObject&&aim.JINDNOFABKB==enemy.Collider&&Vector3.Distance(aim.HLDECMJFKJK,expected)<.0001&&aim.DKPDBLLJEAA&&!aim.EFMBNPNFGHM,"silent updates native aiming record and preserves returned object");Check(local.AimCalls==1,"silent avoids camera rotation call");Run("get_LastAimingInfoFromWeapon",enemy);Check(aim.JHAINOBIFMA==enemy.gameObject,"remote aiming getter leaves local silent record intact");local.Firing=false;Run("get_LastAimingInfoFromWeapon",local);Check(aim.HPCOJHGFEEG.x==7&&aim.EFMBNPNFGHM&&aim.JHAINOBIFMA==null,"silent restores when firing stops");
        local.Firing=true;Run("get_LastAimingInfoFromWeapon",local);aim.JHAINOBIFMA=new GameObject("native-new-target");Run("MzRestoreSilent");Check(aim.JHAINOBIFMA.name=="native-new-target","native updates not overwritten by restoration");switches[12]=false;local.Firing=false;
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(enemy);GUI.Calls.Clear();Run("MzRender");Check(Lines()==32*4,"bounded ESP traversal and visible-player draw cap");COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(enemy);
        Set("MzTab",1);Set("MzOpen",true);Set("MzFov",150f);Frame(EventType.MouseDown,289,368);Frame(EventType.MouseDrag,466,368);Frame(EventType.MouseUp,466,368);Check(Get<float>("MzFov")==480,"FOV slider full range");
        Click(140,176);Check(switches[11]&&!switches[12],"aim head toggle connected");Click(140,224);Check(switches[12]&&!switches[11],"silent toggle mutually exclusive");Click(140,224);Check(!switches[12],"silent toggle turns off");
        Set("MzTab",0);Set("MzEspPage",1);Click(337,438);Check(Get<int>("MzLineOrigin")==1,"line origin cycles to center");Click(337,438);Check(Get<int>("MzLineOrigin")==2,"line origin cycles to top");switches[10]=true;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Any(d=>d.Matrix.Tag==2&&d.Matrix.Position.y==8),"top line projects from selected origin");Click(337,438);Check(Get<int>("MzLineOrigin")==0,"line origin cycles to bottom");
        COW.GameFacade.Match=null;GUI.Calls.Clear();switches[13]=true;Run("MzRender");Check(GUI.Calls.Count==0,"lobby has no ESP or FOV overlay");COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);
        Set("MzEspPage",0);Set("MzTab",1);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzFov",150f);Set("MzBubbleX",24f);Set("MzBubbleY",96f);switches[11]=true;switches[2]=true;switches[4]=true;switches[5]=true;switches[6]=true;
        for(int i=0;i<18;i++)Frame(EventType.Repaint);Check(Get<float>("MzOpenAnim")>.95f&&Get<float[]>("MzSwitchAnim")[1]>.95f,"panel and toggle animation advances");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-aim.svg"));Set("MzTab",0);for(int i=0;i<18;i++)Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-esp.svg"));
        Set("MzOpen",false);bool was=switches[0];Frame(EventType.MouseUp,140,140);Check(switches[0]==was,"closing animation accepts no hidden toggle taps");
        Set("MzOpen",true);Set("MzTab",2);for(int i=0;i<18;i++)Frame(EventType.Repaint);
        Check(GUI.Calls.Any(d=>d.Rect.width==382&&d.Rect.height==440&&d.Color.r<.03f&&d.Color.g<.03f),"compact panel supplies explicit black color");Check(GUI.Calls.Any(d=>d.Wrap&&d.FontSize==18),"key message wraps with independent readable style");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-key.svg"));
        COW.GameFacade.Match=null;Screen.Width=1883;Screen.Height=870;Frame(EventType.Repaint);Check(Math.Abs(Get<float>("MzScale")-1.63125f)<.0001f,"scale matches supplied screenshot resolution");Check(80*Get<float>("MzScale")>125&&382*Get<float>("MzScale")>600,"button and panel grow on user's screen");float savedLease=Get<float>("MzLeaseDeadline");string savedMessage=Get<string>("MzLicenseMessage");Set("MzLeaseDeadline",0f);Set("MzLicenseMessage","Nhập khóa Mizze để kích hoạt");Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-key-870p.svg"));Set("MzLeaseDeadline",savedLease);Set("MzLicenseMessage",savedMessage);
        Screen.Width=2340;Screen.Height=1080;Frame(EventType.Repaint);Check(Math.Abs(Get<float>("MzScale")-2.025f)<.0001f,"high resolution scaling");Set("MzTab",1);Click(Get<float>("MzPanelX")+30,Get<float>("MzPanelY")+126);Check(!switches[11],"scaled touch toggles correct aim row");
        Screen.Width=390;Screen.Height=844;Frame(EventType.Repaint);float scale=Get<float>("MzScale");Check((Get<float>("MzPanelX")+382)*scale<=Screen.width&&(Get<float>("MzPanelY")+440)*scale<=Screen.height,"portrait layout clamps within viewport");
        Screen.Width=1280;Screen.Height=720;Frame(EventType.Repaint);Check(Get<float>("MzScale")==1.35f,"landscape scale restored after resize");
        Set("MzDriver",null);GameObject.World.Clear();GameObject.FailAdd=true;Check(!(bool)Run("IsReallyInStealth",local)&&local.Movable,"bootstrap failure preserves game behavior");GameObject.FailAdd=false;Run("MzEnsure");Check(GameObject.Find("__mizze_driver").Added!=null,"bootstrap retries component creation");
        ExtendedChecks(args);
        Console.WriteLine("PASS: "+Checks+" checks; final IFix bytecode executed by pinned Tencent VM. Lobby, drag, animations, ESP geometry/filtering, head aim/fire/FOV, silent record/restore, key binding/expiry/races. Unity/game/network are offline doubles; iPhone loading and in-game aim remain unverified.");GC.KeepAlive(Vm);return 0;
    }
}
