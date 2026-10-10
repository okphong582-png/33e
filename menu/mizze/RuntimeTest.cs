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
            for(int i=0;i<fields.Length;i++){bool added=r.ReadBoolean();var owner=types[r.ReadInt32()];string name=r.ReadString();if(added){var f=new NewFieldInfo {Name=name,DeclaringType=owner,FieldType=types[r.ReadInt32()],MethodId=r.ReadInt32()};newFields.Add(i,f);string logical=System.Text.RegularExpressions.Regex.Replace(name,@"^Mizze_[0-9a-f]{16}_","");Check(logical!=name,"build-isolated new field name "+name);Fields.Add(logical,f);Check(owner.GetField(name)==null,"VM owns new field "+name);}else{fields[i]=owner.GetField(name,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.Static);Check(fields[i]!=null,"resolve field "+name);}}
            Check(r.ReadInt32()==0,"no static-slot metadata");Check(r.ReadInt32()==0,"no closures");r.ReadString();r.ReadString();Check(!r.ReadBoolean(),"game flag");int fixes=r.ReadInt32();Check(fixes==3,"three lobby/GUI/aim fixes, no stealth hook");for(int i=0;i<fixes;i++){var m=ReadMethod(r,types);int id=r.ReadInt32();Check(Methods[m.Name]==id,"fix table maps "+m.Name);}Check(r.ReadInt32()==0&&r.BaseStream.Position==r.BaseStream.Length,"complete container");
            return new VirtualMachine(codes,delegate{foreach(var ptr in allocated)Marshal.FreeHGlobal(ptr);}) {ExternTypes=types,ExternMethods=externs,InternStrings=strings,FieldInfos=fields,NewFieldInfos=newFields,ExceptionHandlers=handlers,StaticFieldTypes=new Type[0],Cctors=new int[0]};
        }
    }
    static void Set(string name,object value){Fields[name].SetValue(null,value);}static T Get<T>(string name){return (T)Fields[name].GetValue(null);}
    static object Run(string name,params object[] args)
    {
        var c=Call.Begin();foreach(var a in args){if(a is float)c.PushSingle((float)a);else if(a is int)c.PushInt32((int)a);else if(a is bool)c.PushBoolean((bool)a);else if(a!=null&&a.GetType().IsValueType)c.PushValueType(a);else c.PushObject(a);}Vm.Execute(Methods[name],ref c,args.Length);object result=null;
        if(name=="get_UIModelRole"||name=="get_LastAimingInfoFromWeapon"||name=="MzPickTarget"||name=="MzHash"||name=="MzSafeName")result=c.GetObject();else if(name=="IsReallyInStealth"||name=="MzAuthorized"||name=="MzEnemy"||name=="MzOnThread")result=c.GetBoolean();Call.End(ref c);return result;
    }
    static void Frame(EventType type,float x=0,float y=0)
    {
        if(type==EventType.Repaint)Time.Frame++;Event.current=new Event {type=type,mousePosition=new Vector2(x*(Get<float>("MzScale")>0?Get<float>("MzScale"):1.35f),y*(Get<float>("MzScale")>0?Get<float>("MzScale"):1.35f))};GUI.Calls.Clear();GUI.color=new Color(.3f,.4f,.5f,1);GUI.contentColor=new Color(.4f,.5f,.6f,.7f);GUI.matrix=new Matrix4x4 {Tag=99};Run("OnGUI",Driver);Check(GUI.color.r==.3f&&GUI.contentColor.r==.4f&&GUI.contentColor.a==.7f&&GUI.matrix.Tag==99,"GUI color/content/matrix restored");
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
            }else if(d.Texture is Texture2D&&((Texture2D)d.Texture).Png!=null){b.Append("<image x=\""+Number(r.x)+"\" y=\""+Number(r.y)+"\" width=\""+Number(r.width)+"\" height=\""+Number(r.height)+"\" href=\"data:image/png;base64,"+Convert.ToBase64String(((Texture2D)d.Texture).Png)+"\"/>");
            }else if(d.Texture is Texture2D&&((Texture2D)d.Texture).Width>0){var tex=(Texture2D)d.Texture;float radius=(tex.Width*.5f-2)*(r.width/tex.Width),stroke=(tex.Width==32?3:1.5f)*(r.width/tex.Width);b.Append("<circle cx=\""+Number(r.x+r.width*.5f)+"\" cy=\""+Number(r.y+r.height*.5f)+"\" r=\""+Number(radius-stroke*.5f)+"\" fill=\"none\" stroke=\""+c+"\" stroke-width=\""+Number(stroke)+"\"/>");}else b.Append("<rect x=\""+Number(r.x)+"\" y=\""+Number(r.y)+"\" width=\""+Number(r.width)+"\" height=\""+Number(r.height)+"\" rx=\""+Number(d.Radius)+"\" fill=\""+c+"\"/>");b.Append("</g>");
        }b.Append("</svg>");File.WriteAllText(file,b.ToString());
    }
    static void ExtendedChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[13]=true;
        Screen.Width=1280;Screen.Height=720;Set("MzFov",150f);Set("MzRange",150f);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",3);Set("MzColorTarget",0);
        COW.GameFacade.Match=new JMAGGLCNGIG();var bad=Enemy();bad.FailHP=true;var enemy=Enemy();COW.GameFacade.Match.Players.Add(bad);COW.GameFacade.Match.Players.Add(enemy);
        GUI.Calls.Clear();Render();Check(GUI.Calls.Count==1&&Get<bool>("MzSampleFaulted")&&Get<float>("MzNextEsp")>=Time.Now+.49f,"despawn failure discards sample, keeps FOV and backs off actor reads");Check(!Get<bool>("MzDrawingEsp"),"drawing flag restored after exception");
        bad.FailHP=false;bad.Destroyed=true;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==5,"Unity destroyed player wrapper skipped");
        Click(210,222);Color esp=Get<Color>("MzEspColor");Check(esp.r==.3f&&esp.g==.65f,"palette changes actual ESP color");Check(PlayerPrefs.Saved.ContainsKey("Mizze.Color.ESP"),"palette persisted after tap");
        Click(270,143);Click(210,222);Color fov=Get<Color>("MzFovColor");Check(fov.r==.3f&&fov.b==1,"FOV palette independent");
        Frame(EventType.MouseDown,230,349);Frame(EventType.MouseDrag,390,349);Frame(EventType.MouseUp,390,349);fov=Get<Color>("MzFovColor");Check(Math.Abs(fov.r-(390-134-84)/270f)<.001f,"RGB drag controls actual red channel");Check(Get<int>("MzDragMode")==0&&PlayerPrefs.Saved["Mizze.Color.FOV"].Length==6,"RGB releases drag and persists color");
        GUI.Calls.Clear();Render();Check(GUI.Calls.Any(d=>d.Text==null&&Math.Abs(d.Color.r-fov.r)<.001f&&d.Color.b==1),"FOV renderer consumes selected color");Check(GUI.Calls.Any(d=>d.Text==null&&d.Color.r==esp.r&&d.Color.g==esp.g),"box renderer consumes selected color");
        Click(390,143);Click(210,222);Check(Get<Color>("MzHealthColor").b==1,"health palette independent");
        Set("MzColorTarget",0);Run("MzAppearanceInit");Check(Get<Color>("MzEspColor").b==1&&Math.Abs(Get<Color>("MzFovColor").r-fov.r)<.005f,"colors survive appearance reinitialization");
        Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Màu ESP")&&GUI.Calls.Any(d=>d.Text=="Đỏ "+((int)(Get<Color>("MzEspColor").r*255)).ToString()),"UTF-8 Vietnamese survives translated bytecode");Check(Font.Loads==0&&GUIStyle.FontWrites==0,"menu never creates OS font or changes game shared default");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;
        int maximum=0;for(int frame=0;frame<1200;frame++){if(frame%20==0)((Player)COW.GameFacade.Match.Players[frame%150]).Destroyed=true;GUI.Calls.Clear();Render();maximum=Math.Max(maximum,GUI.Calls.Count);if(frame%100==0){Check(GUI.Calls.Count<=193&&Get<int>("MzCommandCount")<=192&&!Get<bool>("MzDrawingEsp"),"bounded all-ESP stress frame "+frame);GC.Collect();}}Check(maximum>100,"stress exercised bounded all-feature drawing");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Render();Check(GUI.Calls.Count==0&&!Get<bool>("MzDrawingEsp"),"match teardown resets render state");
        Set("MzOpen",true);Set("MzTab",3);for(int i=0;i<18;i++)Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-colors.svg"));
    }
    static void StabilityChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[13]=true;
        var enemy=Enemy();COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Time.Now=0;Set("MzNextEsp",0f);GUI.Calls.Clear();Run("MzRender");int reads=Camera.ProjectionCalls,uploads=Texture2D.Uploaded,created=Texture2D.Created;
        for(int frame=0;frame<60;frame++){Time.Now=.0005f*frame;GUI.Calls.Clear();Run("MzRender");}
        Check(Camera.ProjectionCalls==reads,"sixty repaint calls reuse projected values before refresh");Check(Texture2D.Uploaded==uploads&&Texture2D.Created==created,"rings never allocate or upload per repaint");
        Time.Now=.08f;Run("MzRender");Check(Camera.ProjectionCalls==reads+2,"sample refresh updates current world positions once");
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
        Time.Now=0;int startReads=Camera.ProjectionCalls;for(int frame=0;frame<1200;frame++){Time.Now=frame/60f;GUI.Calls.Clear();Run("MzRender");if(frame%120==0){Check(GUI.Calls.Count<=193&&!Get<bool>("MzBuilding"),"scheduled dense repaint frame "+frame);GC.Collect();}}Check(Camera.ProjectionCalls-startReads<1200*16*20,"scheduled dense scene does not resample every repaint");Check(Texture2D.Created==created&&Texture2D.Uploaded==uploads,"dense scene keeps two ring textures and fixed command buffers");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==0&&Get<int>("MzCommandCount")==0,"match teardown clears all cached overlay commands");
        COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[4]=true;switches[5]=true;switches[13]=true;Set("MzNextEsp",0f);Set("MzOpen",false);Set("MzOpenAnim",0f);Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"esp-continuous.svg"));
        var bad=Enemy();bad.FailNick=true;COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(bad);COW.GameFacade.Match.Players.Add(enemy);GUI.Calls.Clear();Render();Check(GUI.Calls.Count==1&&Get<int>("MzCommandCount")==0,"late getter failure discards incomplete sample");bad.FailNick=false;
        ring.Destroyed=true;GUI.Calls.Clear();Render();Check(Get<Texture2D>("MzRing")!=ring&&Get<Texture2D>("MzRing")!=null,"destroyed native ring is rebuilt before overlay draw");Check(GUI.Calls.All(d=>!System.Object.ReferenceEquals(d.Texture,ring)),"no destroyed ring reaches GUI draw");
        Get<Texture2D>("MzRing").Destroyed=true;Texture2D.FailUpload=true;GUI.Calls.Clear();Render();Check(Texture2D.LastCreated.Destroyed&&GUI.Calls.Count==0,"failed native texture upload destroys partial allocation and skips unsafe draw");Texture2D.FailUpload=false;Render();Check(Get<Texture2D>("MzRing")!=null,"renderer recovers after texture upload failure");
        Time.Now=0;
    }
    static void SafeRendererChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);for(int i=0;i<11;i++)switches[i]=true;switches[13]=true;
        COW.GameFacade.Match=new JMAGGLCNGIG();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(Enemy((i%10-5)*.1f));Set("MzRange",150f);Time.Now=0;
        int draws=Graphics.Draws,meshes=Mesh.Created,materials=Material.Created,reads=Camera.ProjectionCalls;Graphics.FailDraw=true;Material.FailPass=true;Shader.Available=false;
        GUI.Calls.Clear();Render();Check(Graphics.Draws==draws&&Mesh.Created==meshes&&Material.Created==materials,"ESP never creates or draws native mesh/material even when GPU path fails");Check(GL.Depth==0,"ESP never touches GL matrix state");
        Check(Get<Rect[]>("MzRects").Length==192&&GUI.Calls.Count<=193,"all-feature overlay has fixed192 command storage and at most193 draws including FOV");
        Check(Camera.ProjectionCalls-reads==6*(2+24+6+9),"dense skeleton samples each extra bone once and limits complex players to six");
        int textures=Texture2D.Created,white=Texture2D.WhiteReads;var rects=Get<Rect[]>("MzRects");var points=Get<Vector2[]>("MzBonePoints");
        for(int frame=0;frame<1200;frame++){Time.Now=frame/60f;GUI.Calls.Clear();Run("MzRender");if(frame%120==0)Check(GUI.Calls.Count<=193&&!Get<bool>("MzBuilding"),"bounded safe renderer frame "+frame);}
        Check(Graphics.Draws==draws&&Mesh.Created==meshes&&Material.Created==materials&&GL.Depth==0,"1200 dense frames issue no Mesh/Material/GL operations");
        Check(Object.ReferenceEquals(rects,Get<Rect[]>("MzRects"))&&Object.ReferenceEquals(points,Get<Vector2[]>("MzBonePoints")),"dense scene reuses command and bone screen buffers");Check(Texture2D.Created==textures&&Texture2D.WhiteReads==white,"dense rendering creates no textures and caches white texture getter");
        Graphics.FailDraw=false;Material.FailPass=false;Shader.Available=true;Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[7]=true;COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(Enemy());reads=Camera.ProjectionCalls;GUI.Calls.Clear();Render();Check(Camera.ProjectionCalls-reads==11&&Lines()==14,"one skeleton projects eleven unique bones and preserves all ten edges plus box");
        Time.Now=30;Set("MzNextEsp",0f);reads=Camera.ProjectionCalls;Render();Time.Now=30.02f;Run("MzRender");Check(Camera.ProjectionCalls==reads+11,"cached draw between thirty Hz sample updates");Time.Now=30.04f;Run("MzRender");Check(Camera.ProjectionCalls==reads+22,"ESP refreshes at thirty Hz instead of previous thirteen Hz");
        COW.GameFacade.Match=null;GUI.Calls.Clear();Run("MzRender");Check(Get<int>("MzCommandCount")==0&&GUI.Calls.Count==0,"scene exit drops safe renderer commands");Time.Now=0;
    }

    static void CachedNodeChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);for(int i=0;i<11;i++)switches[i]=true;
        Set("MzEspBlocked",false);Set("MzSampleFailures",0);Set("MzEspFailures",0);Set("MzErrorWritten",false);
        Time.Now=1;var local=COW.GameFacade.Local;local.FailLegacyTransforms=true;
        var enemy=Enemy();enemy.FailLegacyTransforms=true;COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);
        int reads=enemy.HeadReads;GUI.Calls.Clear();Render();
        Check(Get<int>("MzCommandCount")>30&&!Get<bool>("MzSampleFaulted")&&enemy.HeadReads==reads,"all ESP reads populated native caches without lazy/head getters");
        var saved=enemy.GBKFHDFCPMD;enemy.GBKFHDFCPMD=null;GUI.Calls.Clear();Render();
        Check(GUI.Calls.Count==0&&enemy.HeadReads==reads&&!Get<bool>("MzSampleFaulted"),"missing native head cache skips actor without initializing it");enemy.GBKFHDFCPMD=saved;
        var node=(GCommon.TestTransformNode)enemy.DLAHJBJFMCF;node.Value.Destroyed=true;GUI.Calls.Clear();Render();
        Check(Get<int>("MzCommandCount")>0&&!Get<bool>("MzSampleFaulted"),"destroyed cached bone omits its edges without dereferencing native position");node.Value.Destroyed=false;
        node.Fail=true;GUI.Calls.Clear();Render();float retry=Get<float>("MzNextEsp");int projections=Camera.ProjectionCalls;Run("MzRender");
        Check(Get<int>("MzSampleFailures")==1&&Get<int>("MzCommandCount")==0&&Camera.ProjectionCalls==projections,"cached-node failure clears incomplete commands and respects retry delay");
        Time.Now=retry+.01f;Run("MzRender");Time.Now=Get<float>("MzNextEsp")+.01f;Run("MzRender");
        Check(Get<bool>("MzEspBlocked")&&!switches[0]&&Get<int>("MzSampleFailures")==3,"three repeated actor sample failures pause ESP rather than loop forever");
        node.Fail=false;enemy.FailLegacyTransforms=false;local.FailLegacyTransforms=false;Set("MzEspBlocked",false);Set("MzSampleFailures",0);Set("MzEspFailures",0);
        switches[0]=true;GUI.Calls.Clear();Render();Check(Get<int>("MzCommandCount")>30,"valid cached bones render again after explicit recovery");
        Array.Clear(switches,0,switches.Length);COW.GameFacade.Match=null;Time.Now=0;
    }
    static void BackgroundChecks(string[] args)
    {
        COW.GameFacade.Match=null;Set("MzKeyHash","");Set("MzRequest",null);Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",0);Set("MzPanelX",120f);Set("MzPanelY",16f);
        int loads=ImageConversion.Loads;
        for(int i=0;i<20;i++){Time.Now=1+i*.05f;int before=ImageConversion.Loads;Frame(EventType.Repaint);Check(ImageConversion.Loads-before<=1,"background uploads at most one frame per repaint");}
        var frames=Get<Texture2D[]>("MzBackgroundFrames");
        Check(Get<int>("MzBackgroundLoaded")==15&&Get<string[]>("MzBackgroundEncoded")==null,"all GIF frames cached and temporary encoded array released");
        Check(frames.All(t=>t!=null&&t.Width==192&&t.Height==222&&t.Released),"background uses fifteen small non-readable textures without mipmaps");
        Check(frames.Select(t=>Convert.ToBase64String(t.Png)).Distinct().Count()==15,"background contains fifteen distinct actual GIF frames");
        int ready=ImageConversion.Loads;var seen=new HashSet<Texture>();
        for(int i=0;i<160;i++){Time.Now=3+i/60f;if(Environment.GetEnvironmentVariable("MIZZE_CAPTURE_ANIMATION")=="1"){if(i==40)Set("MzTab",1);if(i==100)Set("MzTab",3);}Frame(EventType.Repaint);foreach(var d in GUI.Calls)if(d.Texture is Texture2D&&((Texture2D)d.Texture).Png!=null)seen.Add(d.Texture);if(Environment.GetEnvironmentVariable("MIZZE_CAPTURE_ANIMATION")=="1"&&i%4==0)Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"glass-frame-"+(i/4).ToString("D2")+".svg"));}
        Check(seen.Count==15&&ImageConversion.Loads==ready,"full GIF loop draws all cached frames with no repeated decoding");
        Set("MzOpen",false);Set("MzOpenAnim",0f);float clock=Get<float>("MzBackgroundClock");int created=Texture2D.Created;
        for(int i=0;i<60;i++){Time.Now=7+i/60f;Frame(EventType.Repaint);}
        Check(Get<float>("MzBackgroundClock")==clock&&ImageConversion.Loads==ready&&Texture2D.Created==created,"hidden menu pauses GIF clock and performs no texture work");
        Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",0);Set("MzTabAnim",0f);Time.Now=9;Frame(EventType.Repaint);
        Check(Get<float>("MzBackgroundClock")==clock,"reopening resumes GIF without fast-forwarding hidden time");
        Check(GUI.Calls.Any(d=>d.Rect.width==69&&d.Rect.height==30&&d.Radius==15&&d.Color.r>.9f),"active tab is a white animated pill");
        Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-esp.svg"));
        Set("MzTab",1);for(int i=0;i<40;i++){Time.Now+=1/60f;Frame(EventType.Repaint);}Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-aim.svg"));
        var encoded=Get<string[]>("MzBackgroundEncoded");float next=Get<float>("MzBackgroundNextLoad");
        Set("MzBackgroundFrames",null);Set("MzBackgroundLoaded",0);Set("MzBackgroundEncoded",null);Set("MzBackgroundNextLoad",0f);ImageConversion.Fail=true;created=Texture2D.Created;Time.Now+=1;Frame(EventType.Repaint);
        Check(Get<bool>("MzBackgroundFailed")&&Texture2D.LastCreated.Destroyed&&Texture2D.Created==created+1,"failed background decode destroys allocation and falls back to glass");
        ready=ImageConversion.Loads;for(int i=0;i<20;i++){Time.Now+=.1f;Frame(EventType.Repaint);}Check(ImageConversion.Loads==ready,"failed background decode never retries every frame");
        ImageConversion.Fail=false;Set("MzBackgroundFrames",frames);Set("MzBackgroundLoaded",15);Set("MzBackgroundEncoded",encoded);Set("MzBackgroundFailed",false);Set("MzBackgroundNextLoad",next);
        Time.Now=0;Set("MzBackgroundLast",0f);
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
        Check(Get<bool>("MzUiPaint")&&!Get<bool>("MzInGui"),"draw gating and reentrancy guard restored after pointer events");
        Set("MzOpen",true);Set("MzOpenAnim",1f);Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Rect.width==382&&d.Rect.height==440&&Math.Abs(d.Color.a-.56f)<.001f),"glass panel supplies translucent dark fill");Check(GUI.Calls.Any(d=>d.Rect.width==74&&Math.Abs(d.Color.a-.72f)<.001f),"launcher has translucent glass interior");Check(GUI.Calls.Where(d=>d.Text!=null).All(d=>d.Color.a>.82f),"glass keeps text opacity readable");
        Set("MzInGui",true);textures=GUI.NativeTextures;Frame(EventType.Repaint);Check(GUI.Calls.Count==0&&GUI.NativeTextures==textures,"reentrant menu callback never duplicates rendering or gameplay operations");Set("MzInGui",false);
    }
    static void WeaponChecks(string[] args)
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);Time.Now=0;Set("MzLeaseDeadline",1000f);Set("MzKeyHash","");Set("MzNextWeapon",0f);Set("MzFireMultiplier",2f);
        var local=Enemy(0);local.Local=true;var attributes=local.Attributes;COW.GameFacade.Local=local;COW.GameFacade.Match=new JMAGGLCNGIG();
        Run("MzWeaponPoll");Check(local.AttributeReads==0&&attributes.ScaleWrites==0&&!attributes.IsAmmoFree,"weapon toggles default off and perform no native attribute work");
        Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",4);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzBubbleX",24f);Set("MzBubbleY",96f);
        Click(154,148);Check(switches[15]&&attributes.FireIntervalScale==.5f,"fast-fire toggle immediately halves native interval scale");
        int writes=attributes.ScaleWrites;Time.Now=.2f;Run("MzWeaponPoll");Check(attributes.ScaleWrites==writes&&attributes.FireIntervalScale==.5f,"polling never compounds multiplier or rewrites unchanged rate");
        Click(400,286);Check(Get<float>("MzFireMultiplier")==3&&Math.Abs(attributes.FireIntervalScale-1f/3)<.0001f,"3x selector updates from original interval baseline");
        attributes.FireIntervalScale=.8f;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(Math.Abs(attributes.FireIntervalScale-.8f/3)<.0001f&&Get<float>("MzOldFireScale")==.8f,"native buff change becomes new baseline while enabled");
        Click(154,192);Check(switches[16]&&attributes.IsAmmoFree&&attributes.ShootNoReload,"no-reload toggle sets both real client ammo flags");
        int freeWrites=attributes.FreeWrites;Time.Now=.4f;Run("MzWeaponPoll");Check(attributes.FreeWrites==freeWrites,"unchanged ammo flag is never written each poll");
        for(int i=0;i<30;i++)Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Súng")&&GUI.Calls.Any(d=>d.Text=="Không nạp đạn")&&GUI.Calls.Any(d=>d.Text!=null&&d.Text.Contains("Fakelag: chưa")),"weapon tab uses accented labels and marks unavailable lag honestly");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-weapons.svg"));
        Click(154,148);Check(!switches[15]&&attributes.FireIntervalScale==.8f&&attributes.IsAmmoFree,"fast off restores current native baseline independently of ammo feature");
        Click(154,192);Check(!switches[16]&&!attributes.IsAmmoFree&&!attributes.ShootNoReload&&Get<PlayerAttributes>("MzWeaponAttributes")==null,"both off restores original ammo state and releases native wrapper");
        attributes.Free=true;attributes.ShootNoReload=true;switches[16]=true;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Run("MzRestoreWeapon");Check(attributes.Free&&attributes.ShootNoReload,"preexisting native free-ammo flags survive restoration");attributes.Free=false;attributes.ShootNoReload=false;
        switches[15]=true;switches[16]=true;Set("MzNextWeapon",0f);Run("MzWeaponPoll");var replacement=new PlayerAttributes();local.Attributes=replacement;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(attributes.FireIntervalScale==.8f&&!attributes.Free&&!attributes.ShootNoReload&&Math.Abs(replacement.FireIntervalScale-1f/3)<.0001f&&replacement.Free,"attribute component replacement restores old and applies to new");
        local.HP=0;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(replacement.FireIntervalScale==1&&!replacement.Free&&!replacement.ShootNoReload,"player death restores weapon state");local.HP=100;
        Set("MzNextWeapon",0f);Run("MzWeaponPoll");COW.GameFacade.Match=null;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(replacement.FireIntervalScale==1&&!replacement.Free,"match teardown restores weapon state");
        COW.GameFacade.Match=new JMAGGLCNGIG();Set("MzNextWeapon",0f);Run("MzWeaponPoll");Set("MzLeaseDeadline",0f);Run("MzWeaponPoll");Check(replacement.FireIntervalScale==1&&!replacement.Free,"expired key restores weapon state immediately");Set("MzLeaseDeadline",1000f);
        local.Local=false;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(replacement.ScaleWrites>0&&replacement.FireIntervalScale==1&&!replacement.Free,"observer never receives weapon modifications");local.Local=true;
        replacement.FireIntervalScale=float.NaN;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(!Get<bool>("MzFastApplied")&&float.IsNaN(replacement.FireIntervalScale),"invalid fire scale never converted into native interval");replacement.FireIntervalScale=1;Run("MzRestoreWeapon");
        Set("MzNextWeapon",0f);Run("MzWeaponPoll");replacement.Destroyed=true;Run("MzRestoreWeapon");Check(Get<PlayerAttributes>("MzWeaponAttributes")==null&&!Get<bool>("MzFastApplied"),"destroyed attribute wrapper released without restore dereference");replacement=new PlayerAttributes();local.Attributes=replacement;
        Set("MzNextWeapon",0f);Run("MzWeaponPoll");replacement.FireIntervalScale=.9f;Run("MzRestoreWeapon");Check(replacement.FireIntervalScale==.9f,"restoration preserves a newer native rate update");
        Set("MzNextWeapon",0f);Run("MzWeaponPoll");Run("MzReject","disabled");Check(replacement.FireIntervalScale==.9f&&!replacement.Free&&!replacement.ShootNoReload,"license rejection rolls back weapon attributes immediately");
        Set("MzLeaseDeadline",1000f);switches[15]=false;switches[16]=false;Set("MzNextWeapon",0f);Run("MzWeaponPoll");COW.GameFacade.Match=null;Time.Now=0;
    }
    static void FaultIsolationChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);Time.Now=0;Set("MzLeaseDeadline",1000f);Set("MzEspBlocked",false);Set("MzEspFailures",0);Set("MzThreadId",System.Threading.Thread.CurrentThread.ManagedThreadId);
        var local=Enemy(0);local.Local=true;local.Firing=true;var enemy=Enemy();COW.GameFacade.Local=local;COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Camera.main=new Camera {gameObject=new GameObject("camera-fault-check")};
        int localCalls=COW.GameFacade.LocalCalls;switches[0]=true;switches[11]=true;switches[15]=true;COW.GameFacade.Match=null;Render();Run("MzRunAim");Run("MzWeaponPoll");Check(COW.GameFacade.LocalCalls==localCalls,"absent match never queries native local actor from ESP, aim or weapons");COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);Array.Clear(switches,0,switches.Length);Render();Check(COW.GameFacade.LocalCalls==localCalls,"inactive ESP and FOV never query scene or local actor");
        int reads=local.LocalReads,heads=enemy.HeadReads;var original=local.FDMIEDDNCEC;Check(Object.ReferenceEquals(Run("get_LastAimingInfoFromWeapon",local),original)&&local.LocalReads==reads&&enemy.HeadReads==heads,"disabled silent getter returns record without any native player queries");
        Exception workerError=null;int finds=GameObject.FindCalls,adds=GameObject.AddCalls,projections=Camera.ProjectionCalls,attrs=local.AttributeReads;switches[0]=true;switches[1]=true;switches[12]=true;switches[15]=true;
        var worker=new System.Threading.Thread(delegate(){try{Run("MzEnsure");Run("MzRender");Run("MzWeaponPoll");Run("get_LastAimingInfoFromWeapon",local);}catch(Exception e){workerError=e;}});worker.Start();worker.Join();Check(workerError==null&&GameObject.FindCalls==finds&&GameObject.AddCalls==adds&&Camera.ProjectionCalls==projections&&local.AttributeReads==attrs&&local.LocalReads==reads,"off-thread hook calls cannot touch Unity scene, players, aim or weapon attributes");
        switches[15]=false;int nested=0;enemy.OnHead=delegate(){nested++;Run("get_LastAimingInfoFromWeapon",local);};Run("get_LastAimingInfoFromWeapon",local);Check(nested>0&&nested<10&&!Get<bool>("MzInSilent")&&local.FDMIEDDNCEC.JHAINOBIFMA==enemy.gameObject,"nested aiming getter does not recurse and releases silent guard");enemy.OnHead=null;Run("MzRestoreSilent");switches[12]=false;
        Set("MzDriver",null);GameObject.World.Remove("__mizze_driver");int bootNested=0;GameObject.OnAdd=delegate(){bootNested++;Run("MzEnsure");};Run("MzEnsure");GameObject.OnAdd=null;Check(bootNested==1&&!Get<bool>("MzBooting")&&GameObject.Find("__mizze_driver").Added!=null,"nested native component creation creates one driver without recursion");Driver=GameObject.Find("__mizze_driver").Added;
        int renderNested=0;Camera.OnProjection=delegate(){renderNested++;Run("MzRender");};GUI.Calls.Clear();Render();Camera.OnProjection=null;Check(renderNested==2&&Lines()==4&&!Get<bool>("MzInRender"),"native projection callback cannot reenter renderer or replace its command buffer");
        var ring=Get<Texture2D>("MzRing");var headRing=Get<Texture2D>("MzHeadRing");Set("MzRing",null);Set("MzHeadRing",null);int created=Texture2D.Created;Render();Check(Texture2D.Created==created&&Get<Texture2D>("MzRing")==null&&Get<Texture2D>("MzHeadRing")==null,"box-only ESP performs no procedural ring allocation");Set("MzRing",ring);Set("MzHeadRing",headRing);
        local.HP=0;heads=enemy.HeadReads;GUI.Calls.Clear();Render();Check(Get<int>("MzCommandCount")==0&&enemy.HeadReads==heads,"local death clears old ESP before touching enemy skeletons");local.HP=100;local.Local=false;Render();Check(enemy.HeadReads==heads,"observer or incomplete local actor prevents ESP sampling");local.Local=true;local.gameObject.activeInHierarchy=false;Render();Check(enemy.HeadReads==heads,"inactive local actor prevents ESP sampling during scene transitions");local.gameObject.activeInHierarchy=true;
        string badName=new string('a',23)+"\ud83d\ude00"+"more";Check((string)Run("MzSafeName",badName)==new string('a',23)+"\ud83d\ude00","nickname limit never splits a valid UTF-16 surrogate pair");Check((string)Run("MzSafeName","Việt\n\ud800Nam\udc00")=="ViệtNam","nickname filter preserves Vietnamese accents and removes controls or invalid surrogates");
        Set("MzErrorWritten",false);GUI.FailTexture=true;for(int i=0;i<3;i++)Render();Check(Get<bool>("MzEspBlocked")&&!switches[0]&&Get<int>("MzCommandCount")==0&&!Get<bool>("MzInRender"),"three repeat native API managed exceptions stop ESP and release render guard");
        string log=Path.Combine(Application.TestFolder,"Mizze-error.log");Check(File.Exists(log)&&File.ReadAllText(log).Contains("esp-render")&&File.ReadAllText(log).Contains("GUI texture failure"),"managed renderer fault writes phase and exception stack to Documents log");string firstLog=File.ReadAllText(log);Run("MzLogFault","another",new Exception("second"));Check(File.ReadAllText(log)==firstLog,"successful frames and duplicate faults never rewrite log");GUI.FailTexture=false;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==0,"blocked renderer performs no automatic unsafe retry");
        Set("MzTab",0);Set("MzEspPage",0);Set("MzOpen",true);Set("MzPanelX",120f);Set("MzPanelY",16f);Click(154,148);Check(switches[0]&&!Get<bool>("MzEspBlocked")&&Get<int>("MzEspFailures")==0,"explicit ESP toggle resets circuit breaker");Render();Check(Get<int>("MzCommandCount")==4,"ESP resumes after explicit retry when renderer succeeds");
        Array.Clear(switches,0,switches.Length);switches[11]=true;int aimCalls=local.AimCalls;Set("MzLastLogicFrame",-1);Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(local.AimCalls==aimCalls+1,"two repaint passes in one game frame execute aim only once");Time.Frame++;Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(local.AimCalls==aimCalls+2,"next game frame still executes aim");
        File.Delete(log);Directory.Delete(Application.TestFolder);COW.GameFacade.Match=null;
    }
    static int Main(string[] args)
    {
        foreach(var line in File.ReadAllLines(args[1])){var a=line.Split('\t');Methods.Add(a[2],int.Parse(a[0]));}
        var legacyInit=new NewFieldInfo {Name="MzInitialized",FieldType=typeof(bool)};legacyInit.SetValue(null,true);var legacySwitch=new NewFieldInfo {Name="MzSwitch",FieldType=typeof(bool[])};legacySwitch.SetValue(null,new bool[1]);Vm=Load(args[0]);
        // Lobby getter preserves the lazy model and bootstraps with no match or player.
        var model=Run("get_UIModelRole");Check(Get<bool[]>("MzSwitch").Length==17&&(bool)legacyInit.GetValue(null)&&((bool[])legacySwitch.GetValue(null)).Length==1,"new patch ignores retained state from previous unscoped patch");Check(model!=null&&System.Object.ReferenceEquals(model,Run("get_UIModelRole")),"lobby cached model preserved");Check(GCommon.UIModelManager.instance.Calls==1,"model initialized once");
        var g=GameObject.Find("__mizze_driver");Check(g!=null&&g.Added!=null&&g.Persistent,"persistent driver created in lobby");Driver=g.Added;Check(Get<float>("MzPanelX")==120&&Get<float>("MzPanelY")==16,"new initial panel position");Check(!Get<bool[]>("MzSwitch")[0]&&!Get<bool[]>("MzSwitch")[13],"fresh boot keeps ESP and FOV inactive until explicitly enabled");Set("MzPanelX",98f);Set("MzPanelY",30f);
        Frame(EventType.Repaint);Check(Labels()==1&&GUI.Calls.Any(d=>d.Text=="Mizze"),"only circular Mizze launcher initially");Check(Math.Abs(Get<float>("MzScale")-1.35f)<.0001f,"larger display scale at 720p");Check(GUI.Calls.Any(d=>d.Text==null&&d.Rect.width==74&&d.Color.r<.03f&&d.Color.g<.04f),"launcher uses explicit black shader color");Check(GUI.Calls.Single(d=>d.Text=="Mizze").FontSize==20&&GUI.Calls.Single(d=>d.Text=="Mizze").Matrix.Scale.x==1.35f,"larger launcher font and size");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"launcher.svg"));
        var local=Enemy(0);local.Local=true;local.Stealth=true;local.Origin=new Vector3(0,0,1);COW.GameFacade.Local=local;
        Check((bool)local.IsReallyInStealth()&&local.StealthCalls==1&&local.Movable,"native stealth and movement preserved");local.Stealth=false;Check(!(bool)local.IsReallyInStealth(),"false stealth preserved");
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
        COW.GameFacade.Match.Players.Clear();for(int i=0;i<150;i++)COW.GameFacade.Match.Players.Add(enemy);GUI.Calls.Clear();Render();Check(Lines()==12*4,"bounded ESP traversal and twelve visible-player cap");COW.GameFacade.Match.Players.Clear();COW.GameFacade.Match.Players.Add(enemy);
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
        Set("MzDriver",null);GameObject.World.Clear();GameObject.FailAdd=true;int stealthAdds=GameObject.AddCalls;Check(!local.IsReallyInStealth()&&local.Movable&&GameObject.AddCalls==stealthAdds,"unpatched stealth never initializes menu");Run("MzEnsure");Check(!Get<bool>("MzBooting"),"bootstrap exception releases reentry guard");GameObject.FailAdd=false;Run("MzEnsure");Check(GameObject.Find("__mizze_driver").Added!=null,"bootstrap retries component creation");
        BackgroundChecks(args);
        ExtendedChecks(args);
        StabilityChecks(args);
        SafeRendererChecks();
        CachedNodeChecks();
        UiPerformanceChecks();
        WeaponChecks(args);
        FaultIsolationChecks();
        Console.WriteLine("PASS: "+Checks+" checks; final IFix bytecode executed by pinned Tencent VM. Lobby, drag, animations, ESP geometry/filtering, head aim/fire/FOV, silent record/restore, key binding/expiry/races. Unity/game/network are offline doubles; iPhone loading and in-game aim remain unverified.");GC.KeepAlive(Vm);return 0;
    }
}
