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
        if(full.Split(',')[0]=="System.GC")return typeof(ControlledGc);
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
        var c=Call.Begin();foreach(var a in args){if(a is long)c.PushInt64((long)a);else if(a is float)c.PushSingle((float)a);else if(a is int)c.PushInt32((int)a);else if(a is bool)c.PushBoolean((bool)a);else if(a!=null&&a.GetType().IsValueType)c.PushValueType(a);else c.PushObject(a);}try{Vm.Execute(Methods[name],ref c,args.Length);}catch(Exception e){Console.Error.WriteLine("VM failure method="+name+" checks="+Checks+" time="+Time.Now+" "+e.Message);throw;}object result=null;
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
    static int Lines(){return GUI.Calls.Count(d=>d.Text==null&&d.Texture==Texture2D.whiteTexture);}
    static void Render(){Set("MzNextEsp",0f);Run("MzRender");}static int Labels(){return GUI.Calls.Count(d=>d.Text!=null);}
    static string Number(float f){return f.ToString("0.###",CultureInfo.InvariantCulture);}
    static void Snapshot(string file)
    {
        var b=new StringBuilder("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""+Screen.width+"\" height=\""+Screen.height+"\" viewBox=\"0 0 "+Screen.width+" "+Screen.height+"\"><rect width=\"100%\" height=\"100%\" fill=\"#26333d\"/>");
        foreach(var d in GUI.Calls){var r=d.Rect;string c="rgb("+(int)(d.Color.r*255)+","+(int)(d.Color.g*255)+","+(int)(d.Color.b*255)+")";float sx=d.Matrix.Scale.x==0?1:d.Matrix.Scale.x,sy=d.Matrix.Scale.y==0?1:d.Matrix.Scale.y;
            b.Append("<g transform=\"translate("+Number(d.Matrix.Position.x)+" "+Number(d.Matrix.Position.y)+") rotate("+Number(d.Matrix.Angle)+") scale("+Number(sx)+" "+Number(sy)+")\" opacity=\""+Number(d.Color.a)+"\">");
            if(d.Text!=null){int font=d.FontSize>0?d.FontSize:12;float x=d.Align==TextAnchor.MiddleCenter?r.x+r.width*.5f:r.x,y=d.Align==TextAnchor.UpperLeft?r.y+font:r.y+r.height*.5f+font*.33f;string anchor=d.Align==TextAnchor.MiddleCenter?"middle":"start";var lines=new List<string>();if(d.Wrap){string line="";foreach(string word in d.Text.Split(' ')){if(line.Length>0&&(line.Length+word.Length+1)*font*.54f>r.width){lines.Add(line);line=word;}else line+=(line.Length>0?" ":"")+word;}lines.Add(line);}else lines.Add(d.Text);
                for(int i=0;i<lines.Count&&i*font*1.2f<r.height;i++)b.Append("<text x=\""+Number(x)+"\" y=\""+Number(y+i*font*1.2f)+"\" text-anchor=\""+anchor+"\" font-family=\"Arial\" font-size=\""+font+"\" fill=\""+c+"\">"+System.Security.SecurityElement.Escape(lines[i])+"</text>");
            }else if(d.Texture is Texture2D&&((Texture2D)d.Texture).Png!=null){b.Append("<image x=\""+Number(r.x)+"\" y=\""+Number(r.y)+"\" width=\""+Number(r.width)+"\" height=\""+Number(r.height)+"\" preserveAspectRatio=\"none\" href=\"data:image/png;base64,"+Convert.ToBase64String(((Texture2D)d.Texture).Png)+"\"/>");}else if(d.Texture is Texture2D&&((Texture2D)d.Texture).Width>0){var tex=(Texture2D)d.Texture;float radius=(tex.Width*.5f-2)*(r.width/tex.Width),stroke=(tex.Width==32?3:1.5f)*(r.width/tex.Width);b.Append("<circle cx=\""+Number(r.x+r.width*.5f)+"\" cy=\""+Number(r.y+r.height*.5f)+"\" r=\""+Number(radius-stroke*.5f)+"\" fill=\"none\" stroke=\""+c+"\" stroke-width=\""+Number(stroke)+"\"/>");}else b.Append("<rect x=\""+Number(r.x)+"\" y=\""+Number(r.y)+"\" width=\""+Number(r.width)+"\" height=\""+Number(r.height)+"\" rx=\""+Number(d.Radius)+"\" fill=\""+c+"\"/>");b.Append("</g>");
        }b.Append("</svg>");File.WriteAllText(file,b.ToString());
    }
    static void ExtendedChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[13]=true;
        Screen.Width=1280;Screen.Height=720;Set("MzFov",150f);Set("MzRange",150f);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",3);Set("MzColorTarget",0);
        COW.GameFacade.Match=new JMAGGLCNGIG();var bad=Enemy();bad.FailHP=true;var enemy=Enemy();COW.GameFacade.Match.Players.Add(bad);COW.GameFacade.Match.Players.Add(enemy);
        GUI.Calls.Clear();Render();Check(GUI.Calls.Count==5,"despawn getter failure leaves next enemy and FOV rendering intact");Check(!Get<bool>("MzDrawingEsp"),"drawing flag restored after exception");
        bad.FailHP=false;bad.Destroyed=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==5,"Unity destroyed player wrapper skipped");
        Click(210,222);Color esp=Get<Color>("MzEspColor");Check(esp.r==.3f&&esp.g==.65f,"palette changes actual ESP color");Check(PlayerPrefs.Saved.ContainsKey("Mizze.Color.ESP"),"palette persisted after tap");
        Click(270,143);Click(210,222);Color fov=Get<Color>("MzFovColor");Check(fov.r==.3f&&fov.b==1,"FOV palette independent");
        Frame(EventType.MouseDown,230,349);Frame(EventType.MouseDrag,390,349);Frame(EventType.MouseUp,390,349);fov=Get<Color>("MzFovColor");Check(Math.Abs(fov.r-(390-134-84)/270f)<.001f,"RGB drag controls actual red channel");Check(Get<int>("MzDragMode")==0&&PlayerPrefs.Saved["Mizze.Color.FOV"].Length==6,"RGB releases drag and persists color");
        GUI.Calls.Clear();Render();Check(GUI.Calls.Any(d=>d.Text==null&&Math.Abs(d.Color.r-fov.r)<.001f&&d.Color.b==1),"FOV renderer consumes selected color");Check(GUI.Calls.Any(d=>d.Text==null&&d.Color.r==esp.r&&d.Color.g==esp.g),"box renderer consumes selected color");
        Click(390,143);Click(210,222);Check(Get<Color>("MzHealthColor").b==1,"health palette independent");
        Set("MzColorTarget",0);Run("MzAppearanceInit");Check(Get<Color>("MzEspColor").b==1&&Math.Abs(Get<Color>("MzFovColor").r-fov.r)<.005f,"colors survive appearance reinitialization");
        Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Màu ESP")&&GUI.Calls.Any(d=>d.Text=="Đỏ "+((int)(Get<Color>("MzEspColor").r*255)).ToString()),"UTF-8 Vietnamese survives translated bytecode");Check(Font.Loads==1&&GUIStyle.DefaultFont==GUI.skin.font,"font loaded once and game default restored");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;
        int maximum=0;for(int frame=0;frame<1200;frame++){if(frame%20==0)((Player)COW.GameFacade.Match.Players[frame%150]).Destroyed=true;GUI.Calls.Clear();Render();maximum=Math.Max(maximum,GUI.Calls.Count);if(frame%100==0){Check(GUI.Calls.Count<=513&&Get<int>("MzCommandCount")<=512&&!Get<bool>("MzDrawingEsp"),"bounded all-ESP stress frame "+frame);GC.Collect();}}Check(maximum>250,"stress exercised dense all-feature drawing");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==0&&!Get<bool>("MzDrawingEsp"),"match teardown resets render state");
        Set("MzOpen",true);Set("MzTab",3);for(int i=0;i<18;i++)Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
    }
    static void StabilityChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[13]=true;
        var enemy=Enemy();COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Time.Now=0;Set("MzNextEsp",0f);GUI.Calls.Clear();Run("MzRender");int reads=Camera.ProjectionCalls,uploads=Texture2D.Uploaded,created=Texture2D.Created;
        for(int frame=0;frame<60;frame++){Time.Now=.0005f*frame;GUI.Calls.Clear();Run("MzRender");}
        Check(Camera.ProjectionCalls==reads,"sixty repaint calls reuse projected values before refresh");Check(Texture2D.Uploaded==uploads&&Texture2D.Created==created,"rings never allocate or upload per repaint");
        Time.Now=.051f;Run("MzRender");Check(Camera.ProjectionCalls==reads+2,"sample refresh updates current world positions once");
        var ring=Get<Texture2D>("MzRing");Check(ring.Width==256&&ring.Pixels[128*256+128].a==0&&ring.Released,"ring centre transparent, upload releases CPU storage on device");
        for(int i=0;i<360;i++){double angle=i*Math.PI/180;bool found=false;for(int radius=124;radius<=127;radius++){int x=(int)(128+Math.Cos(angle)*radius),y=(int)(128+Math.Sin(angle)*radius);if(x>=0&&x<256&&y>=0&&y<256&&ring.Pixels[y*256+x].a>.15f)found=true;}Check(found,"continuous raster ring angle "+i);}
        GUI.Calls.Clear();Render();var circle=GUI.Calls.Single(d=>d.Texture==ring);Check(circle.Rect.width==circle.Rect.height&&circle.Matrix.Tag!=2,"FOV remains square and unrotated");
        Set("MzFov",480f);GUI.Calls.Clear();Render();circle=GUI.Calls.Single(d=>d.Texture==ring);Check(circle.Rect.y>=0&&circle.Rect.y+circle.Rect.height<=Screen.height&&circle.Rect.x>=0&&circle.Rect.x+circle.Rect.width<=Screen.width,"maximum FOV fits viewport without clipping its outline");
        Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==4&&GUI.Calls.All(d=>d.Matrix.Tag!=2),"2D edges use direct rectangles without rotation matrices");var edges=GUI.Calls.ToArray();Check(Math.Abs(edges[0].Rect.x-edges[2].Rect.x)<.001f&&Math.Abs(edges[0].Rect.y-edges[2].Rect.y)<.001f,"box endpoint caps overlap at top left");
        // Distinct weapon and camera origins expose the old lateral parallax bug.
        var local=Enemy(0);local.Local=true;local.Firing=true;local.Origin=new Vector3(-.4f,.8f,1);COW.GameFacade.Local=local;Camera.main.transform.position=new Vector3(.4f,1,1);Set("MzFov",480f);switches[11]=true;
        Run("MzRunAim");Vector3 desired=Vector3.Normalize(enemy.Head.position-Camera.main.transform.position);Check(local.AimCalls==1&&Vector3.Distance(local.LastRotation.Direction,desired)<.0001f,"head aim uses camera ray with shoulder offset");Check(Vector3.Distance(local.LastRotation.Direction,Vector3.Normalize(enemy.Head.position-local.Origin))>.05f,"weapon origin no longer introduces lateral bias in camera aim");
        enemy.Head.position=new Vector3(-.1f,1.3f,10);Run("MzRunAim");desired=Vector3.Normalize(enemy.Head.position-Camera.main.transform.position);Check(local.AimCalls==2&&Vector3.Distance(local.LastRotation.Direction,desired)<.0001f,"head aim follows current head position while firing");local.Firing=false;Run("MzRunAim");Check(local.AimCalls==2,"camera aim stops without firing");switches[11]=false;Camera.main.transform.position=new Vector3();
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;
        Time.Now=0;int startReads=Camera.ProjectionCalls;for(int frame=0;frame<1200;frame++){Time.Now=frame/60f;GUI.Calls.Clear();Run("MzRender");if(frame%120==0){Check(GUI.Calls.Count<=513&&!Get<bool>("MzBuilding"),"scheduled dense repaint frame "+frame);GC.Collect();}}Check(Camera.ProjectionCalls-startReads<1200*16*20,"scheduled dense scene does not resample every repaint");Check(Texture2D.Created==created&&Texture2D.Uploaded==uploads,"dense scene keeps two ring textures and fixed command buffers");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==0&&Get<int>("MzCommandCount")==0,"match teardown clears all cached overlay commands");
        COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[4]=true;switches[5]=true;switches[13]=true;Set("MzNextEsp",0f);Set("MzOpen",false);Set("MzOpenAnim",0f);Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"esp-continuous.svg"));
        var bad=Enemy();bad.FailNick=true;COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(bad);COW.GameFacade.Match.Players.Add(enemy);GUI.Calls.Clear();Render();Check(GUI.Calls.Count==8,"late getter failure rolls back whole enemy instead of caching half a shape");
        ring.Destroyed=true;GUI.Calls.Clear();Render();Check(Get<Texture2D>("MzRing")!=ring&&Get<Texture2D>("MzRing")!=null,"destroyed native ring is rebuilt before overlay draw");Check(GUI.Calls.All(d=>!System.Object.ReferenceEquals(d.Texture,ring)),"no destroyed ring reaches GUI draw");
        Get<Texture2D>("MzRing").Destroyed=true;Texture2D.FailUpload=true;GUI.Calls.Clear();Render();Check(Texture2D.LastCreated.Destroyed&&GUI.Calls.Count==0,"failed native texture upload destroys partial allocation and skips unsafe draw");Texture2D.FailUpload=false;Render();Check(Get<Texture2D>("MzRing")!=null,"renderer recovers after texture upload failure");
        Time.Now=0;
    }
    static void BatchChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;COW.GameFacade.Match=new JMAGGLCNGIG();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));Set("MzRange",150f);Time.Now=0;
        int draws=Graphics.Draws;GUI.Calls.Clear();Render();Check(Graphics.Draws==draws+1,"dense all-feature ESP uses one native mesh draw");Check(GUI.Calls.Count(d=>d.Text==null&&!d.MeshQuad)<=17,"only head/FOV texture draws remain outside mesh");Check(Get<int>("MzQuadCount")<=512&&GL.Depth==0,"batch capacity and GL matrix stack bounded");
        var material=Get<Material>("MzMaterial");Check(material.Values["_ZWrite"]==0&&material.Values["_ZTest"]==8&&material.Values["_Cull"]==0,"overlay material disables depth writes and culling");
        var mesh=Get<Mesh>("MzMesh");Check(mesh.Indices.All(i=>i>=0&&i<mesh.Vertices.Length)&&mesh.Vertices.All(v=>!float.IsNaN(v.x)&&!float.IsInfinity(v.y)),"uploaded mesh has valid finite vertices and indices");
        int whiteReads=Texture2D.WhiteReads,matrixWrites=GUI.MatrixWrites,nativeTextures=GUI.NativeTextures;GUI.Calls.Clear();Run("MzRender");Check(Texture2D.WhiteReads==whiteReads&&GUI.MatrixWrites-matrixWrites<=2,"cached solid batch avoids per-line texture lookup and GUI matrix calls");Check(GUI.NativeTextures-nativeTextures<=17,"dense frame issues at most seventeen native texture draws");
        int uploads=Mesh.Uploads,created=Mesh.Created;for(int frame=0;frame<600;frame++){GUI.Calls.Clear();Run("MzRender");}Check(Mesh.Uploads==uploads&&Mesh.Created==created,"six hundred cached repaints do not rebuild or upload mesh");
        Graphics.FailDraw=true;GUI.Calls.Clear();Run("MzRender");Check(GL.Depth==0&&!Get<bool>("MzBatchReady")&&mesh.Destroyed&&material.Destroyed,"GPU failure restores stack and destroys failed native resources");Graphics.FailDraw=false;Shader.Available=false;GUI.Calls.Clear();Render();Check(GUI.Calls.Count(d=>d.Text==null&&d.Texture==Texture2D.whiteTexture)<=96,"shader-unavailable fallback remains bounded");Check(!Get<bool>("MzBatchReady"),"missing shader does not masquerade as active batch");
        Shader.Available=true;Time.Now=6;GUI.Calls.Clear();Render();Check(Get<bool>("MzBatchReady")&&Get<Mesh>("MzMesh")!=mesh,"batch recovers after bounded retry interval");
        Material.FailPass=true;GUI.Calls.Clear();Run("MzRender");Check(!Get<bool>("MzBatchReady")&&GL.Depth==0,"unsupported material pass disables batch safely");Material.FailPass=false;Time.Now=12;Render();Check(Get<bool>("MzBatchReady"),"valid material pass recovers");
        var first=Get<Vector3[]>("MzVertices");var colors=Get<Color[]>("MzVertexColors");for(int frame=0;frame<1200;frame++){Time.Now=12+frame/60f;GUI.Calls.Clear();Run("MzRender");}Check(System.Object.ReferenceEquals(first,Get<Vector3[]>("MzVertices"))&&System.Object.ReferenceEquals(colors,Get<Color[]>("MzVertexColors")),"long dense scene reuses CPU vertex buffers");Check(GL.Depth==0,"dense batch leaves GL stack balanced");Time.Now=0;
    }
    static void UiPerformanceChecks()
    {
        COW.GameFacade.Match=null;Time.Now=0;Set("MzKeyHash","");Set("MzRequest",null);Set("MzKeyboard",null);Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",1);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzFov",150f);
        Frame(EventType.Repaint);int fonts=GUIStyle.FontWrites,white=Texture2D.WhiteReads,textures=GUI.NativeTextures,matrices=GUI.MatrixWrites;
        Frame((EventType)8);Check(GUI.Calls.Count==0&&GUI.NativeTextures==textures&&GUIStyle.FontWrites==fonts&&GUI.MatrixWrites==matrices+1,"layout event skips all menu drawing, font and matrix work");
        Frame(EventType.MouseDown,2,2);Check(GUI.Calls.Count==0&&GUI.NativeTextures==textures&&GUIStyle.FontWrites==fonts,"touch-down handles input without native UI drawing or font switching");
        Frame(EventType.MouseUp,2,2);Check(GUI.Calls.Count==0&&GUI.NativeTextures==textures&&GUIStyle.FontWrites==fonts,"touch-up handles input without drawing or font switching");
        var label=Get<string[]>("MzSliderText")[0];int transforms=Matrix4x4.TrsCalls;
        for(int i=0;i<120;i++)Frame(EventType.Repaint);
        Check(Texture2D.WhiteReads==white,"open menu reuses white texture without per-shape native getter");Check(Matrix4x4.TrsCalls==transforms,"stable scale reuses menu transform for 120 repaints");Check(Object.ReferenceEquals(label,Get<string[]>("MzSliderText")[0]),"unchanged slider reuses formatted text");
        Set("MzFov",151f);Frame(EventType.Repaint);Check(Get<string[]>("MzSliderText")[0].Contains("151 px")&&!Object.ReferenceEquals(label,Get<string[]>("MzSliderText")[0]),"FOV text updates when rounded value changes");
        Set("MzTab",0);Set("MzEspPage",1);Frame(EventType.Repaint);Check(Get<string[]>("MzSliderText")[1].StartsWith("Tầm ESP"),"shared range label refreshes its title when switching tab");
        Set("MzOpen",false);for(int i=0;i<120;i++)Frame(EventType.Repaint);Check(Get<float>("MzOpenAnim")==0,"close animation settles exactly to zero");var animation=Get<float[]>("MzSwitchAnim");float before=animation[0];Get<bool[]>("MzSwitch")[0]=!Get<bool[]>("MzSwitch")[0];Frame(EventType.Repaint);Check(animation[0]==before,"fully closed panel skips hidden toggle animation updates");
        Check(Get<bool>("MzUiPaint"),"draw gating restored after pointer events");
    }

    static void OldSourceGlossChecks(string[] args)
    {
        License(Record(Get<string>("MzDeviceHash")));Set("MzKeyHash","");Set("MzRequest",null);
        COW.GameFacade.Match=new JMAGGLCNGIG();var player=Enemy(0);player.Local=true;player.Attributes=new PlayerAttributes();COW.GameFacade.Local=player;
        var s=Get<bool[]>("MzSwitch");Array.Clear(s,0,s.Length);s[15]=true;s[16]=true;Set("MzRunLevel",1);Set("MzFireLevel",1);
        Time.Now=1;Set("MzExtrasNext",0f);Run("MzExtrasPoll");
        Check(player.Attributes.ForceSetRunAndDashSpeed==7.5f&&player.Attributes.FireIntervalScale==.5f,"new toggles write real native speed/fire attributes");
        for(int i=0;i<100;i++){Time.Now+=.11f;Run("MzExtrasPoll");}
        Check(player.Attributes.ForceSetRunAndDashSpeed==7.5f&&player.Attributes.FireIntervalScale==.5f,"repeated polls do not compound multipliers");
        Set("MzRunLevel",2);Set("MzFireLevel",2);Time.Now+=.11f;Run("MzExtrasPoll");
        Check(player.Attributes.ForceSetRunAndDashSpeed==10&&Math.Abs(player.Attributes.FireIntervalScale-1f/3)<.0001,"levels update from captured base values");
        s[15]=false;Time.Now+=.11f;Run("MzExtrasPoll");Check(player.Attributes.ForceSetRunAndDashSpeed==0&&player.Attributes.FireIntervalScale<.34f,"run restores independently of rapid fire");
        player.Attributes.FireIntervalScale=.8f;Run("MzExtrasRestore");Check(player.Attributes.FireIntervalScale==.8f,"restoration preserves intervening native changes");
        s[15]=true;Time.Now+=.11f;Run("MzExtrasPoll");var first=player.Attributes;player.Attributes=new PlayerAttributes {BaseRun=6};
        Time.Now+=.11f;Run("MzExtrasPoll");Check(first.ForceSetRunAndDashSpeed==0&&first.FireIntervalScale==.8f&&player.Attributes.ForceSetRunAndDashSpeed==12,"player attribute replacement restores old owner and captures new base");
        player.HP=0;Time.Now+=.11f;Run("MzExtrasPoll");Check(player.Attributes.ForceSetRunAndDashSpeed==0&&player.Attributes.FireIntervalScale==1,"death restores both overrides");
        player.HP=100;Time.Now+=.11f;Run("MzExtrasPoll");License(Record(Get<string>("MzDeviceHash"),false));Run("MzExtrasPoll");
        Check(player.Attributes.ForceSetRunAndDashSpeed==0&&player.Attributes.FireIntervalScale==1,"key revocation restores speed and fire");
        License(Record(Get<string>("MzDeviceHash")));s[15]=false;s[16]=false;
        Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",4);Set("MzTabAnim",4f);Set("MzUiPaint",true);Set("MzPanelX",120f);Set("MzPanelY",16f);
        Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Chạy nhanh")&&GUI.Calls.Any(d=>d.Text=="Bắn nhanh"),"new speed tab renders Vietnamese controls");
        Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-speed.svg"));
        Set("MzBackgroundNextLoad",0f);int loaded=Get<int>("MzBackgroundLoaded");
        for(int i=0;i<30;i++){Time.Now+=.05f;Frame(EventType.Repaint);}
        Check(Get<int>("MzBackgroundLoaded")==15&&Get<string[]>("MzBackgroundEncoded")==null,"GIF loads at most 15 frames and releases encoded data");
        var frames=Get<Texture2D[]>("MzBackgroundFrames");Check(frames.All(f=>f.Width==192&&f.Height==222&&f.Released),"small GIF frames uploaded non-readable");
        int count=ImageConversion.Loads;for(int i=0;i<100;i++){Time.Now+=.02f;Frame(EventType.Repaint);}
        Check(ImageConversion.Loads==count,"animated repaints reuse uploaded textures without decoding");
        Set("MzOpen",false);for(int i=0;i<80;i++){Time.Now+=.02f;Frame(EventType.Repaint);}
        float clock=Get<float>("MzBackgroundClock");Time.Now+=5;Frame(EventType.Repaint);Check(Get<float>("MzBackgroundClock")==clock,"closed menu pauses GIF clock");
        Set("MzOpen",true);Set("MzBackgroundLoaded",0);Set("MzBackgroundFrames",null);Set("MzBackgroundNextLoad",0f);ImageConversion.Fail=true;Time.Now+=.1f;Frame(EventType.Repaint);
        Check(Get<bool>("MzBackgroundFailed")&&GUI.Calls.Any(d=>d.Text=="Mizze"),"image decode failure preserves the old launcher and glass panel");
        int failed=ImageConversion.Loads;Time.Now+=1;Frame(EventType.Repaint);Check(ImageConversion.Loads==failed,"failed GIF does not enter a repeated allocation loop");
        ImageConversion.Fail=false;Set("MzBackgroundFrames",frames);Set("MzBackgroundLoaded",15);Set("MzBackgroundFailed",false);
        Set("MzTab",0);Set("MzTabAnim",0f);Set("MzOpenAnim",1f);Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-glass.svg"));
    }


    static void EspMemoryChecks()
    {
        var sw=Get<bool[]>("MzSwitch");Array.Clear(sw,0,sw.Length);sw[0]=true;sw[1]=true;sw[4]=true;sw[6]=true;
        COW.GameFacade.Match=new JMAGGLCNGIG();var enemy=Enemy();enemy.Nick=new string('N',80);COW.GameFacade.Match.Players.Add(enemy);
        Time.Now=1;Render();Check(Math.Abs(Get<float>("MzNextEsp")-1.05f)<.001f,"sparse ESP targets 20Hz");Check(Get<int>("MzCommandCount")==2&&Get<int>("MzQuadCount")==4,"solid ESP kept only in mesh, labels in command buffer");
        var label=Get<string[]>("MzNameLabels")[0];var distances=Get<string[]>("MzDistanceLabels");
        Time.Now=1.1f;Render();Check(Object.ReferenceEquals(label,Get<string[]>("MzNameLabels")[0])&&Object.ReferenceEquals(distances,Get<string[]>("MzDistanceLabels")),"stable labels reuse bounded cached strings");
        enemy.Nick="Changed";Time.Now=2.1f;Render();Check(Get<string[]>("MzNameLabels")[0]=="Changed","nickname cache refreshes without retaining stale text indefinitely");
        sw[4]=false;Time.Now=2.2f;Render();Check(Get<Player[]>("MzNameOwners").All(p=>p==null),"disabling names releases all cached owners");sw[4]=true;
        var vertices=Get<Vector3[]>("MzVertices");var rects=Get<Rect[]>("MzRects");int textures=Texture2D.Created,meshes=Mesh.Created;
        for(int i=0;i<600;i++){Time.Now+=1f/60;GUI.Calls.Clear();Run("MzRender");}
        Check(Object.ReferenceEquals(vertices,Get<Vector3[]>("MzVertices"))&&Object.ReferenceEquals(rects,Get<Rect[]>("MzRects"))&&Texture2D.Created==textures&&Mesh.Created==meshes,"ESP soak reuses managed/native drawing resources");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Run("MzRender");Check(Get<Player[]>("MzNameOwners").All(p=>p==null)&&Get<string[]>("MzNameLabels").All(s=>s==null),"leaving match releases cached player and name references");
        Set("MzGuiThread",System.Threading.Thread.CurrentThread.ManagedThreadId);Set("MzGuiActive",false);Set("MzBuilding",false);Set("MzDrawingEsp",false);
        Set("MzMemoryBaseline",0L);Set("MzMemoryNextCollect",0f);Set("MzMemoryPressure",0);Set("MzMemoryPaused",false);COW.GcUtil.After=201326592;ControlledGc.Override=201326592;
        int calls=COW.GcUtil.Calls;Run("MzMemoryStep",134217728L,1f);Check(COW.GcUtil.Calls==calls,"healthy heap does not trigger manual collection");
        Run("MzMemoryStep",1073741824L,2f);Check(COW.GcUtil.Calls==calls+1&&Get<long>("MzMemoryFreed")==872415232L&&!Get<bool>("MzMemoryBusy"),"GB pressure invokes original game collector outside GUI");
        Run("MzMemoryStep",1073741824L,3f);Check(COW.GcUtil.Calls==calls+1,"collection cooldown prevents per-frame GC stalls");
        Set("MzGuiActive",true);Set("MzMemoryNextCollect",0f);Run("MzMemoryStep",1073741824L,20f);Check(COW.GcUtil.Calls==calls+1,"collector cannot run during GUI");Set("MzGuiActive",false);
        Set("MzGuiThread",System.Threading.Thread.CurrentThread.ManagedThreadId+1);Run("MzMemoryStep",1073741824L,20f);Check(COW.GcUtil.Calls==calls+1,"collector ignores non-GUI thread callbacks");Set("MzGuiThread",System.Threading.Thread.CurrentThread.ManagedThreadId);
        COW.GcUtil.After=943718400L;Set("MzMemoryNextCollect",0f);Run("MzMemoryStep",943718400L,21f);Check(!Get<bool>("MzMemoryPaused")&&Get<int>("MzMemoryPressure")==1,"first unreclaimed high reading does not hide ESP immediately");
        var backgrounds=Get<Texture2D[]>("MzBackgroundFrames");Run("MzMemoryStep",943718400L,52f);
        Check(Get<bool>("MzMemoryPaused")&&Get<bool>("MzMemoryTrimmed")&&Get<int>("MzCommandCount")==0,"persistent unreclaimed heap pressure suspends heavy work and trims caches");
        Check(backgrounds==null||backgrounds.All(p=>p==null||p.Destroyed),"pressure trim destroys owned GIF textures");
        Set("MzLeaseDeadline",100000f);Set("MzKeyHash","");Set("MzRequest",null);Set("MzOpen",true);Set("MzOpenAnim",1f);
        int samples=Camera.ProjectionCalls,reads=ControlledGc.Reads;Frame(EventType.Repaint);
        Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&GUI.Calls.Any(d=>d.Text=="Giảm tải · RAM cao")&&!Get<bool>("MzGuiActive"),"pressure fallback preserves launcher and menu");
        Check(Camera.ProjectionCalls==samples&&ControlledGc.Reads==reads,"paused GUI does no ESP sampling or heap polling");
        Run("MzMemoryStep",268435456L,53f);Check(!Get<bool>("MzMemoryPaused")&&!Get<bool>("MzBackgroundFailed"),"memory recovery resumes ESP and GIF with hysteresis");
        COW.GcUtil.After=1288490188L;Set("MzMemoryPressure",0);Set("MzMemoryNextCollect",0f);Run("MzMemoryStep",1288490188L,53.1f);Check(Get<bool>("MzMemoryPaused"),"unreclaimed GB heap trims immediately instead of waiting thirty seconds");Run("MzMemoryStep",268435456L,53.2f);
        COW.GcUtil.Fail=true;Set("MzMemoryNextCollect",0f);int faults=Get<int>("MzMemoryFaults");Run("MzMemoryStep",1073741824L,54f);
        Check(Get<int>("MzMemoryFaults")==faults+1&&!Get<bool>("MzMemoryBusy")&&Get<float>("MzMemoryNextCollect")>=84,"collector exception releases guard and backs off");
        int attempts=COW.GcUtil.Attempts;Run("MzMemoryStep",1073741824L,55f);Check(COW.GcUtil.Attempts==attempts,"collector failure is not retried every callback");
        COW.GcUtil.Fail=false;COW.GcUtil.After=-1;ControlledGc.Override=-1;Set("MzMemoryNext",0f);Set("MzMemoryNextCollect",10000f);
        reads=ControlledGc.Reads;Time.Now=60;Run("MzMemoryPulse");Run("MzMemoryPulse");Check(ControlledGc.Reads==reads+1,"heap is polled at most once each second");
        Set("MzMemoryBaseline",0L);Set("MzMemoryNextCollect",0f);Time.Now=0;Set("MzMemoryNext",0f);
    }
    static void AllocationProfile(string file)
    {
        Run("get_UIModelRole");Driver=GameObject.Find("__mizze_driver").Added;AppDomain.MonitoringIsEnabled=true;var sw=Get<bool[]>("MzSwitch");
        var local=Enemy(0);local.Local=true;COW.GameFacade.Local=local;var match=new JMAGGLCNGIG();COW.GameFacade.Match=match;for(int i=0;i<12;i++)match.Players.Add(Enemy((i-6)*.25f));
        Camera.main=new Camera {gameObject=new GameObject("allocation-camera")};Set("MzLeaseDeadline",10000f);Set("MzKeyHash","");Time.Now=0;
        var output=new StringBuilder();output.Append("{\"frames\":300,\"environment\":\"offline .NET IFix VM; includes test doubles, not iOS measurements\",\"modes\":[");
        for(int mode=0;mode<4;mode++){
            Array.Clear(sw,0,sw.Length);if(mode>0){sw[0]=true;sw[1]=true;}if(mode==2||mode==3){for(int i=4;i<11;i++)sw[i]=true;sw[13]=true;}
            Set("MzOpen",mode==3);Set("MzOpenAnim",mode==3?1f:0f);Set("MzTab",0);
            for(int i=0;i<60;i++){Time.Now+=1f/60;Frame(EventType.Repaint);}
            int colorBefore=GUI.ColorWrites,projectionBefore=Camera.ProjectionCalls;long retainedBefore=GC.GetTotalMemory(true),allocatedBefore=AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize;
            for(int i=0;i<300;i++){Time.Now+=1f/60;Frame(EventType.Repaint);}
            long allocated=AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize-allocatedBefore,retainedAfter=GC.GetTotalMemory(true);
            if(mode>0)output.Append(',');output.Append("{\"name\":\"");output.Append(mode==0?"launcher":mode==1?"box12":mode==2?"allEsp12":"allEsp12-menuOpen");output.Append("\",\"allocatedBytes\":");output.Append(allocated);output.Append(",\"retainedDelta\":");output.Append(retainedAfter-retainedBefore);output.Append(",\"nativeColorWrites\":");output.Append(GUI.ColorWrites-colorBefore);output.Append(",\"projections\":");output.Append(Camera.ProjectionCalls-projectionBefore);output.Append('}');
        }
        output.Append("]}\n");File.WriteAllText(file,output.ToString());Console.WriteLine(output.ToString());
    }
    static int Main(string[] args)
    {
        foreach(var line in File.ReadAllLines(args[1])){var a=line.Split('\t');Methods.Add(a[2],int.Parse(a[0]));}Vm=Load(args[0]);
        if(args.Length>2&&args[2]=="profile"){AllocationProfile(Path.Combine(Path.GetDirectoryName(args[0]),"allocation-profile.json"));return 0;}
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
        GUI.Calls.Clear();Render();Check(Lines()==4,"2D box four edges");switches[2]=true;GUI.Calls.Clear();Render();Check(Lines()==8,"corner box eight edges");switches[2]=false;switches[3]=true;GUI.Calls.Clear();Render();Check(Lines()==12,"3D box twelve edges");switches[1]=false;switches[3]=false;
        switches[4]=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Any(d=>d.Text==enemy.Nick),"real nickname label");switches[4]=false;switches[5]=true;GUI.Calls.Clear();Render();var bars=GUI.Calls.Where(d=>d.Text==null).ToArray();Check(bars.Length==2&&bars[1].Rect.height==bars[0].Rect.height*.5f,"health geometry from current/max HP");switches[5]=false;
        switches[6]=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Any(d=>d.Text!=null&&d.Text.EndsWith(" m")),"distance label");switches[6]=false;switches[7]=true;GUI.Calls.Clear();Render();Check(Lines()==10,"skeleton projects ten bone segments");switches[7]=false;switches[8]=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==1&&GUI.Calls[0].Texture is Texture2D,"head circle is one cached texture");switches[8]=false;switches[9]=true;GUI.Calls.Clear();Render();Check(Lines()==3,"XYZ axes");switches[9]=false;switches[10]=true;GUI.Calls.Clear();Render();Check(Lines()==1,"ESP snapline");switches[10]=false;
        switches[1]=true;enemy.Team=true;GUI.Calls.Clear();Render();Check(Lines()==0&&Run("MzPickTarget")==null,"team filtered from ESP and aim");enemy.Team=false;enemy.HP=0;GUI.Calls.Clear();Render();Check(Lines()==0,"dead filtered");enemy.HP=100;enemy.Head.position=new Vector3(float.NaN,1,10);Check(Run("MzPickTarget")==null,"invalid projection filtered");enemy.Head.position=new Vector3(.2f,1.2f,10);
        Set("MzFov",20f);Check(Run("MzPickTarget")==null,"small FOV excludes target");Set("MzFov",150f);Check(System.Object.ReferenceEquals(Run("MzPickTarget"),enemy),"head inside FOV selected");Set("MzRange",5f);Check(Run("MzPickTarget")==null,"range cap applies to aim");Set("MzRange",150f);
        switches[11]=true;Run("MzRunAim");Check(local.AimCalls==0,"normal aim idle without firing");local.Firing=true;Run("MzRunAim");var expected=Vector3.Normalize(enemy.Head.position-Camera.main.transform.position);Check(local.AimCalls==1&&Vector3.Distance(local.LastRotation.Direction,expected)<.0001,"normal aim calls game rotation toward head");switches[11]=false;switches[12]=true;
        var aim=local.FDMIEDDNCEC;aim.HPCOJHGFEEG=new Vector3(7,8,9);aim.EFMBNPNFGHM=true;var result=Run("get_LastAimingInfoFromWeapon",local);Check(Object.ReferenceEquals(result,aim)&&aim.JHAINOBIFMA==enemy.gameObject&&aim.JINDNOFABKB==enemy.Collider&&Vector3.Distance(aim.HLDECMJFKJK,Vector3.Normalize(enemy.Head.position-local.Origin))<.0001&&aim.DKPDBLLJEAA&&!aim.EFMBNPNFGHM,"silent updates native aiming record and preserves returned object");Check(local.AimCalls==1,"silent avoids camera rotation call");Run("get_LastAimingInfoFromWeapon",enemy);Check(aim.JHAINOBIFMA==enemy.gameObject,"remote aiming getter leaves local silent record intact");local.Firing=false;Run("get_LastAimingInfoFromWeapon",local);Check(aim.HPCOJHGFEEG.x==7&&aim.EFMBNPNFGHM&&aim.JHAINOBIFMA==null,"silent restores when firing stops");
        local.Firing=true;Run("get_LastAimingInfoFromWeapon",local);aim.JHAINOBIFMA=new GameObject("native-new-target");Run("MzRestoreSilent");Check(aim.JHAINOBIFMA.name=="native-new-target","native updates not overwritten by restoration");switches[12]=false;local.Firing=false;
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(enemy);GUI.Calls.Clear();Render();Check(Lines()==16*4,"bounded ESP traversal and sixteen visible-player cap");Check(Get<int>("MzEspShown")==16&&Math.Abs(Get<float>("MzNextEsp")-Time.Now-.066667f)<.001f,"dense ESP uses bounded 15Hz sampling");COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(enemy);
        Set("MzTab",1);Set("MzOpen",true);Set("MzFov",150f);Frame(EventType.MouseDown,289,368);Frame(EventType.MouseDrag,466,368);Frame(EventType.MouseUp,466,368);Check(Get<float>("MzFov")==352,"FOV slider stops at full visible circle");
        Click(140,176);Check(switches[11]&&!switches[12],"aim head toggle connected");Click(140,224);Check(switches[12]&&!switches[11],"silent toggle mutually exclusive");Click(140,224);Check(!switches[12],"silent toggle turns off");
        Set("MzTab",0);Set("MzEspPage",1);Click(337,438);Check(Get<int>("MzLineOrigin")==1,"line origin cycles to center");Click(337,438);Check(Get<int>("MzLineOrigin")==2,"line origin cycles to top");switches[10]=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Any(d=>d.Texture==Texture2D.whiteTexture&&d.Matrix.Tag==2&&Math.Abs(d.Matrix.Position.y-8)<2),"top line projects from selected origin");Click(337,438);Check(Get<int>("MzLineOrigin")==0,"line origin cycles to bottom");
        COW.GameFacade.Match=null;GUI.Calls.Clear();switches[13]=true;Render();Check(GUI.Calls.Count==0,"lobby has no ESP or FOV overlay");COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);
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
        StabilityChecks(args);
        BatchChecks();
        UiPerformanceChecks();
        OldSourceGlossChecks(args);
        EspMemoryChecks();
        Console.WriteLine("PASS: "+Checks+" checks; final IFix bytecode executed by pinned Tencent VM. Lobby, drag, animations, ESP geometry/filtering, head aim/fire/FOV, silent record/restore, key binding/expiry/races. Unity/game/network are offline doubles; iPhone loading and in-game aim remain unverified.");GC.KeepAlive(Vm);return 0;
    }
}
