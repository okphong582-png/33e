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
            for(int i=0;i<fields.Length;i++){bool added=r.ReadBoolean();var owner=types[r.ReadInt32()];string name=r.ReadString();if(added){var f=new NewFieldInfo {Name=name,DeclaringType=owner,FieldType=types[r.ReadInt32()],MethodId=r.ReadInt32()};newFields.Add(i,f);string logical=System.Text.RegularExpressions.Regex.Replace(name,@"^Mizze_[0-9a-f]{16}_","");Check(logical==name&&name.StartsWith("Mz"),"legacy-source field name "+name);Fields.Add(logical,f);Check(owner.GetField(name)==null,"VM owns new field "+name);}else{fields[i]=owner.GetField(name,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.Static);Check(fields[i]!=null,"resolve field "+name);}}
            Check(r.ReadInt32()==0,"no static-slot metadata");Check(r.ReadInt32()==0,"no closures");r.ReadString();r.ReadString();Check(!r.ReadBoolean(),"game flag");int fixes=r.ReadInt32();Check(fixes==7,"old source match hook plus UI/aim/recovery/presentation fixes; native frame bodies remain intact");for(int i=0;i<fixes;i++){var m=ReadMethod(r,types);int id=r.ReadInt32();Check(Methods[m.Name]==id,"fix table maps "+m.Name);}Check(r.ReadInt32()==0&&r.BaseStream.Position==r.BaseStream.Length,"complete container");
            return new VirtualMachine(codes,delegate{foreach(var ptr in allocated)Marshal.FreeHGlobal(ptr);}) {ExternTypes=types,ExternMethods=externs,InternStrings=strings,FieldInfos=fields,NewFieldInfos=newFields,ExceptionHandlers=handlers,StaticFieldTypes=new Type[0],Cctors=new int[0]};
        }
    }
    static void Set(string name,object value){Fields[name].SetValue(null,value);}static T Get<T>(string name){return (T)Fields[name].GetValue(null);}
    static object Run(string name,params object[] args)
    {
        var c=Call.Begin();foreach(var a in args){if(a is float)c.PushSingle((float)a);else if(a is int)c.PushInt32((int)a);else if(a is long)c.PushInt64((long)a);else if(a is bool)c.PushBoolean((bool)a);else if(a!=null&&a.GetType().IsValueType)c.PushValueType(a);else c.PushObject(a);}Vm.Execute(Methods[name],ref c,args.Length);object result=null;
        if(name=="get_UIModelRole"||name=="get_LastAimingInfoFromWeapon"||name=="MzPickTarget"||name=="MzHash"||name=="MzSafeName")result=c.GetObject();else if(name=="IsReallyInStealth"||name=="MzAuthorized"||name=="MzEnemy"||name=="MzOnThread"||name=="NeedRunHighFrame"||name=="get_IsBeingCarried"||name=="MzLagContext"||name=="MzLagButtonVisible"||name=="MzLagButtonHit")result=c.GetBoolean();Call.End(ref c);return result;
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
        Click(400,305);Check(Get<float>("MzFireMultiplier")==3&&Math.Abs(attributes.FireIntervalScale-1f/3)<.0001f,"3x selector updates from original interval baseline");
        attributes.FireIntervalScale=.8f;Set("MzNextWeapon",0f);Run("MzWeaponPoll");Check(Math.Abs(attributes.FireIntervalScale-.8f/3)<.0001f&&Get<float>("MzOldFireScale")==.8f,"native buff change becomes new baseline while enabled");
        Click(154,192);Check(switches[16]&&attributes.IsAmmoFree&&attributes.ShootNoReload,"no-reload toggle sets both real client ammo flags");
        int freeWrites=attributes.FreeWrites;Time.Now=.4f;Run("MzWeaponPoll");Check(attributes.FreeWrites==freeWrites,"unchanged ammo flag is never written each poll");
        for(int i=0;i<30;i++)Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Súng")&&GUI.Calls.Any(d=>d.Text=="Không nạp đạn")&&GUI.Calls.Any(d=>d.Text!=null&&d.Text.Contains("Nút nổi Fakelag")),"weapon tab labels experimental presentation-only fakelag");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"menu-weapons.svg"));
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
        Set("MzDriver",null);GameObject.World.Remove("__mizze_driver");Set("MzNextBootstrap",0f);int bootNested=0;GameObject.OnAdd=delegate(){bootNested++;Run("MzEnsure");};Run("MzEnsure");GameObject.OnAdd=null;Check(bootNested==1&&!Get<bool>("MzBooting")&&GameObject.Find("__mizze_driver").Added!=null,"nested native component creation creates one driver without recursion");Driver=GameObject.Find("__mizze_driver").Added;
        int renderNested=0;Camera.OnProjection=delegate(){renderNested++;Run("MzRender");};GUI.Calls.Clear();Render();Camera.OnProjection=null;Check(renderNested==2&&Lines()==4&&!Get<bool>("MzInRender"),"native projection callback cannot reenter renderer or replace its command buffer");
        var ring=Get<Texture2D>("MzRing");var headRing=Get<Texture2D>("MzHeadRing");Set("MzRing",null);Set("MzHeadRing",null);int created=Texture2D.Created;Render();Check(Texture2D.Created==created&&Get<Texture2D>("MzRing")==null&&Get<Texture2D>("MzHeadRing")==null,"box-only ESP performs no procedural ring allocation");Set("MzRing",ring);Set("MzHeadRing",headRing);
        local.HP=0;heads=enemy.HeadReads;GUI.Calls.Clear();Render();Check(Get<int>("MzCommandCount")==0&&enemy.HeadReads==heads,"local death clears old ESP before touching enemy skeletons");local.HP=100;local.Local=false;Render();Check(enemy.HeadReads==heads,"observer or incomplete local actor prevents ESP sampling");local.Local=true;local.gameObject.activeInHierarchy=false;Render();Check(enemy.HeadReads==heads,"inactive local actor prevents ESP sampling during scene transitions");local.gameObject.activeInHierarchy=true;
        string badName=new string('a',23)+"\ud83d\ude00"+"more";Check((string)Run("MzSafeName",badName)==new string('a',23)+"\ud83d\ude00","nickname limit never splits a valid UTF-16 surrogate pair");Check((string)Run("MzSafeName","Việt\n\ud800Nam\udc00")=="ViệtNam","nickname filter preserves Vietnamese accents and removes controls or invalid surrogates");
        Set("MzErrorWritten",false);GUI.FailTexture=true;for(int i=0;i<3;i++)Render();Check(Get<bool>("MzEspBlocked")&&!switches[0]&&Get<int>("MzCommandCount")==0&&!Get<bool>("MzInRender"),"three repeat native API managed exceptions stop ESP and release render guard");
        string log=Path.Combine(Application.TestFolder,"Mizze-error.log");Check(File.Exists(log)&&File.ReadAllText(log).Contains("esp-render")&&File.ReadAllText(log).Contains("GUI texture failure"),"managed renderer fault writes phase and exception stack to Documents log");string firstLog=File.ReadAllText(log);Run("MzLogFault","another",new Exception("second"));Check(File.ReadAllText(log)==firstLog,"successful frames and duplicate faults never rewrite log");GUI.FailTexture=false;GUI.Calls.Clear();Run("MzRender");Check(GUI.Calls.Count==0,"blocked renderer performs no automatic unsafe retry");
        Set("MzTab",0);Set("MzEspPage",0);Set("MzOpen",true);Set("MzPanelX",120f);Set("MzPanelY",16f);Click(154,148);Check(switches[0]&&!Get<bool>("MzEspBlocked")&&Get<int>("MzEspFailures")==0,"explicit ESP toggle resets circuit breaker");Render();Check(Get<int>("MzCommandCount")==4,"ESP resumes after explicit retry when renderer succeeds");
        Array.Clear(switches,0,switches.Length);switches[11]=true;int aimCalls=local.AimCalls;Set("MzLastLogicFrame",-1);Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(local.AimCalls==aimCalls+1,"two repaint passes in one game frame execute aim only once");Time.Frame++;Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(local.AimCalls==aimCalls+2,"next game frame still executes aim");
        File.Delete(log);COW.GameFacade.Match=null;
    }
    static void MenuRecoveryChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);Set("MzLeaseDeadline",1000f);Set("MzKeyHash","");
        var local=Enemy(0);local.Local=true;var enemy=Enemy(1);COW.GameFacade.Local=local;COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(enemy);
        for(int smooth=0;smooth<2;smooth++)for(int isLocal=0;isLocal<2;isLocal++)for(int skip=0;skip<2;skip++){
            COW.GameSettingData.Smooth=smooth!=0;local.Local=isLocal!=0;local.JKACHEMNCEI=skip!=0;
            Check((bool)Run("NeedRunHighFrame",local)==(smooth!=0&&isLocal!=0&&skip==0),"recovery hook preserves native boolean return table");
        }
        local.Local=true;local.JKACHEMNCEI=false;COW.GameSettingData.Smooth=false;
        Set("MzOpen",true);Set("MzBubbleX",84f);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzTab",0);Set("MzOpenAnim",1f);
        var color=Get<Color>("MzEspColor");switches[1]=true;var old=Get<GameObject>("MzDriver");old.Destroyed=true;Time.Now=5;Set("MzNextBootstrap",0f);int adds=GameObject.AddCalls;
        Run("NeedRunHighFrame",enemy);Check(GameObject.AddCalls==adds,"remote actors never create replacement menu drivers");
        Run("NeedRunHighFrame",local);var recovered=Get<GameObject>("MzDriver");Check(recovered!=null&&!Object.ReferenceEquals(old,recovered)&&recovered.Persistent&&GameObject.AddCalls==adds+1,"local frame recreates destroyed menu driver without a lobby model callback");Driver=recovered.Added;
        Check(Get<bool>("MzOpen")&&Get<float>("MzBubbleX")==84&&Get<Color>("MzEspColor").r==color.r&&Object.ReferenceEquals(switches,Get<bool[]>("MzSwitch")),"scene recovery preserves open state, position, colors and switches");
        int finds=GameObject.FindCalls,localReads=local.LocalReads;adds=GameObject.AddCalls;int writes=enemy.Root.PositionWrites;
        for(int i=0;i<5000;i++)Run("NeedRunHighFrame",local);
        Check(GameObject.FindCalls==finds&&GameObject.AddCalls==adds&&local.LocalReads==localReads&&enemy.Root.PositionWrites==writes,"healthy menu recovery performs no roster, player, transform or component work in repeated callbacks");
        recovered.Destroyed=true;Time.Now=7;GameObject.FailAdd=true;Run("NeedRunHighFrame",local);adds=GameObject.AddCalls;
        for(int i=0;i<100;i++)Run("NeedRunHighFrame",local);
        Check(GameObject.AddCalls==adds&&!Get<bool>("MzBooting"),"failed component creation is throttled and cannot recurse or crash original callback");
        GameObject.FailAdd=false;Time.Now=8.1f;Run("NeedRunHighFrame",local);Driver=Get<GameObject>("MzDriver").Added;Check(Driver!=null&&GameObject.AddCalls==adds+1,"next recovery attempt succeeds after transient creation failure");
        var stableDriver=Get<GameObject>("MzDriver");stableDriver.Destroyed=true;Time.Now=10;Set("MzNextBootstrap",0f);adds=GameObject.AddCalls;finds=GameObject.FindCalls;Exception workerError=null;
        var worker=new System.Threading.Thread(delegate(){try{Run("NeedRunHighFrame",local);}catch(Exception e){workerError=e;}});worker.Start();worker.Join();
        Check(workerError==null&&GameObject.AddCalls==adds&&GameObject.FindCalls==finds,"worker callback cannot create or inspect Unity driver objects");Run("NeedRunHighFrame",local);Driver=Get<GameObject>("MzDriver").Added;
        switches[17]=false;Run("MzLagPulse");Check(enemy.Root.PositionWrites==writes,"disabled fakelag does not write actor transforms");
        Set("MzEspBlocked",false);switches[0]=true;switches[1]=true;GUI.FailTexture=true;Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&!Get<bool>("MzInGui"),"managed ESP draw failure leaves the launcher visible and releases GUI guard");GUI.FailTexture=false;switches[0]=false;
        GUI.FailRoundedOnce=true;Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&!Get<bool>("MzInGui"),"panel draw failure does not prevent the independent launcher from rendering");Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="ESP"),"panel resumes after a transient draw exception");
        COW.GameFacade.Match=null;Set("MzBubbleX",24f);Time.Now=0;
    }
    static bool UiHit(float x,float y)
    {
        var box=Get<BoxCollider>("MzTouchPanel");var bubble=Get<SphereCollider>("MzTouchBubble");
        if(box!=null&&box.enabled){var p=box.transform.localPosition;var size=box.size;if(Math.Abs(x-Screen.width*.5f-p.x)<=size.x*.5f&&Math.Abs(y-Screen.height*.5f+p.y)<=size.y*.5f)return true;}
        var lag=Get<SphereCollider>("MzTouchLag");if(lag!=null&&lag.enabled){var p=lag.transform.localPosition;float dx=x-Screen.width*.5f-p.x,dy=y-Screen.height*.5f+p.y;if(dx*dx+dy*dy<=lag.radius*lag.radius)return true;}
        if(bubble!=null&&bubble.enabled){var p=bubble.transform.localPosition;float dx=x-Screen.width*.5f-p.x,dy=y-Screen.height*.5f+p.y;if(dx*dx+dy*dy<=bubble.radius*bubble.radius)return true;}return false;
    }
    static void TouchAndSoakChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);Set("MzLeaseDeadline",10000f);Set("MzKeyHash","");Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzBubbleX",24f);Set("MzBubbleY",96f);Set("MzTab",0);Set("MzEspPage",0);Time.Now=0;
        UICamera.Main=new Camera {gameObject=new GameObject("ngui-camera")};UICamera.Main.gameObject.layer=5;Frame(EventType.Repaint);
        Check(Get<GameObject>("MzTouchRoot")!=null&&Get<GameObject>("MzTouchRoot").layer==5&&Object.ReferenceEquals(Get<GameObject>("MzTouchRoot").transform.Parent,UICamera.Main.transform),"input shield uses existing NGUI camera/layer without replacing any global input provider");
        float scale=Get<float>("MzScale");Check(UiHit(154*scale,148*scale)&&UiHit(60*scale,136*scale)&&!UiHit(900,600),"panel and bubble collider regions block underlay; outside remains clear");
        Frame(EventType.MouseDown,470,430);Check(Event.current.type==EventType.Used,"blank panel space consumes mouse down");Frame(EventType.MouseUp,470,430);Check(Event.current.type==EventType.Used&&!Get<bool>("MzOwnPointer"),"blank panel space consumes release and clears ownership");
        Frame(EventType.MouseDown,900,600);Check(Event.current.type==EventType.MouseDown,"outside click passes through IMGUI");Frame(EventType.MouseUp,154,148);Check(!switches[0],"outside-start gesture cannot activate a menu toggle after moving inside");
        Frame(EventType.MouseDown,60,136);Frame(EventType.MouseDrag,160,236);Frame(EventType.MouseUp,160,236);scale=Get<float>("MzScale");Check(UiHit(160*scale,236*scale)&&!UiHit(60*scale,136*scale),"circular shield follows dragged launcher rather than covering its previous location");Set("MzBubbleX",24f);Set("MzBubbleY",96f);
        Set("MzOpen",false);Set("MzOpenAnim",0f);Frame(EventType.Repaint);Check(!Get<BoxCollider>("MzTouchPanel").enabled&&UiHit(60*scale,136*scale)&&!UiHit(154*scale,148*scale),"closed menu releases panel region while launcher remains protected");
        Set("MzOpen",true);Set("MzOpenAnim",1f);Frame(EventType.Repaint);int adds=GameObject.AddCalls;for(int i=0;i<1000;i++)Run("MzTouchSync");Check(GameObject.AddCalls==adds,"steady input shield reuses two widgets/colliders without creating frame objects");
        Screen.Width=2340;Screen.Height=1080;Frame(EventType.Repaint);scale=Get<float>("MzScale");Check(UiHit(154*scale,148*scale)&&!UiHit(2300,1000),"input shield rescales with display dimensions");Screen.Width=1280;Screen.Height=720;Frame(EventType.Repaint);
        var previous=Get<GameObject>("MzTouchRoot");UICamera.Main=new Camera {gameObject=new GameObject("ngui-replacement")};Frame(EventType.Repaint);Check(previous.Destroyed&&Get<GameObject>("MzTouchRoot")!=null&&!Object.ReferenceEquals(previous,Get<GameObject>("MzTouchRoot")),"camera replacement releases old shield hierarchy before creating a new one");
        UICamera.Main.FailScreenProjection=true;Screen.Width=1281;Frame(EventType.Repaint);Check(Get<bool>("MzTouchFailed")&&Get<GameObject>("MzTouchRoot")==null&&GUI.Calls.Any(d=>d.Text=="Mizze"),"failed shield projection releases colliders without hiding launcher or disabling game input globally");UICamera.Main=null;Screen.Width=1280;Set("MzTouchFailed",false);Frame(EventType.Repaint);
        var local=Enemy(0);local.Local=true;var enemy=Enemy();COW.GameFacade.Local=local;Camera.main=new Camera {gameObject=new GameObject("soak-camera")};var match=new JMAGGLCNGIG();match.Players.Add(enemy);COW.GameFacade.Match=match;Array.Clear(switches,0,switches.Length);switches[0]=true;switches[1]=true;switches[4]=true;switches[5]=true;switches[6]=true;switches[13]=true;
        Set("MzEspBlocked",false);Set("MzEspFailures",0);Set("MzSampleFailures",0);Set("MzNextSession",0f);Time.Now=0;Render();Run("MzSessionPulse");var rects=Get<Rect[]>("MzRects");var names=Get<string[]>("MzNameCache");int created=Texture2D.Created,uploads=Texture2D.Uploaded,calls=COW.GameFacade.LocalCalls;
        for(int i=0;i<60;i++){GUI.Calls.Clear();Run("MzRender");}Check(COW.GameFacade.LocalCalls==calls,"repeated repaint before sample deadline does not repeat local actor/native bone validation");
        long baseline=GC.GetTotalMemory(true);for(int frame=1;frame<=1800;frame++){
            Time.Now=frame*.5f;Time.Frame++;GUI.Calls.Clear();Run("MzRender");Run("MzSessionPulse");
            if(frame%120==0)Check(Get<int>("MzCommandCount")<=192&&!Get<bool>("MzEspBlocked")&&!Get<bool>("MzInRender"),"ESP stays active at simulated minute "+(frame/120));
        }
        long retained=GC.GetTotalMemory(true)-baseline;Check(retained<8*1024*1024,"15-minute simulated soak has bounded retained managed memory");
        Check(Object.ReferenceEquals(rects,Get<Rect[]>("MzRects"))&&Object.ReferenceEquals(names,Get<string[]>("MzNameCache"))&&Texture2D.Created==created&&Texture2D.Uploaded==uploads,"15-minute soak reuses draw buffers, text caches and textures");
        var lines=Get<string[]>("MzSessionLines");string log=File.ReadAllText(Path.Combine(Application.TestFolder,"Mizze-session.log"));Check(lines.Length==12&&Get<int>("MzSessionCount")==12&&log.Length<4096&&log.Contains("t=900"),"session diagnostics retain only twelve bounded records through simulated minute fifteen");
        enemy.Dead=true;GUI.Calls.Clear();Render();Check(Get<int>("MzCommandCount")==0,"despawn/death guard rejects actor before reading pooled HP and bones");enemy.Dead=false;
        COW.GameFacade.Match=null;Run("MzRender");Check(Get<string[]>("MzNameCache").All(n=>n==null)&&Get<string[]>("MzDistanceCache").All(n=>n==null)&&Get<JMAGGLCNGIG>("MzEspMatch")==null,"match teardown releases label values and cached context");
        Array.Clear(switches,0,switches.Length);Time.Now=0;
    }
    static void LagBegin(Player actor){Time.Frame++;Run("NeedRunHighFrame",actor);}
    static void FakeLagChecks()
    {
        var switches=Get<bool[]>("MzSwitch");Array.Clear(switches,0,switches.Length);
        Time.Now=0;Set("MzLeaseDeadline",1000f);Set("MzKeyHash","");Set("MzThreadId",System.Threading.Thread.CurrentThread.ManagedThreadId);
        var local=Enemy(0);local.Local=true;var enemy=Enemy(1);var match=new JMAGGLCNGIG();match.Players.Add(enemy);
        COW.GameFacade.Local=local;COW.GameFacade.Match=match;int calls=COW.GameFacade.LocalCalls,writes=enemy.Root.PositionWrites;
        Run("MzLagPulse");LagBegin(enemy);Run("get_IsBeingCarried",enemy);Run("UpdateKnockdownIsInCamera",enemy);
        Check(!switches[17]&&!Get<bool>("MzLagActive")&&Get<Player[]>("MzLagPlayers")==null&&enemy.Root.PositionWrites==writes&&COW.GameFacade.LocalCalls==calls,"disabled lag allocates no actor arrays and performs no native position or local queries");
        // Original small-hook semantics must hold independently of the new feature.
        for(int smooth=0;smooth<2;smooth++)for(int isLocal=0;isLocal<2;isLocal++)for(int skip=0;skip<2;skip++){
            COW.GameSettingData.Smooth=smooth!=0;local.Local=isLocal!=0;local.JKACHEMNCEI=skip!=0;
            Check((bool)Run("NeedRunHighFrame",local)==(smooth!=0&&isLocal!=0&&skip==0),"NeedRunHighFrame preserves native short-circuit return table");
        }
        local.Local=true;local.JKACHEMNCEI=false;COW.GameSettingData.Smooth=false;
        Check(!(bool)Run("get_IsBeingCarried",enemy),"carried getter preserves absent carrier");enemy.LNHFOHKEAMP=local;
        Check((bool)Run("get_IsBeingCarried",enemy),"carried getter preserves living carrier");local.Destroyed=true;
        Check(!(bool)Run("get_IsBeingCarried",enemy),"carried getter preserves Unity destroyed-object semantics");local.Destroyed=false;enemy.LNHFOHKEAMP=null;
        local.GBJCJJNPPEC.State=message.KOJPEFFGGIJ.Knocked;local.GIEBNLMODIB=BEADLMGGGGL.DEIPJDIGKIP(7u);match.Lookup=enemy;enemy.Frustum=true;
        Run("UpdateKnockdownIsInCamera",local);Check(local.FFOPCLFLIMO&&match.LookupCalls==1&&!match.LookupOption,"local knocked camera hook preserves target lookup and frustum assignment");
        Run("UpdateKnockdownIsInCamera",local);Check(match.LookupCalls==1,"local frustum flag still suppresses repeat lookup");
        local.FFOPCLFLIMO=false;local.GIEBNLMODIB=BEADLMGGGGL.DEIPJDIGKIP(0u);Run("UpdateKnockdownIsInCamera",local);Check(match.LookupCalls==1,"zero target ID still skips native match lookup");
        local.GIEBNLMODIB=BEADLMGGGGL.DEIPJDIGKIP(7u);
        foreach(int mode in new[]{0,1,2,3,4}){
            match.Lookup=mode==0?null:enemy;enemy.Destroyed=mode==1;enemy.Dead=mode==2;enemy.Dying=mode==3;enemy.Local=mode==4;
            Run("UpdateKnockdownIsInCamera",local);Check(!local.FFOPCLFLIMO,"native local camera rejects missing/destroyed/dead/dying/local target");
        }
        enemy.Destroyed=false;enemy.Dead=false;enemy.Dying=false;enemy.Local=false;local.GBJCJJNPPEC.State=message.KOJPEFFGGIJ.None;
        Check(System.Runtime.InteropServices.Marshal.SizeOf(typeof(BEADLMGGGGL))==24&&System.Runtime.InteropServices.Marshal.OffsetOf(typeof(BEADLMGGGGL),"IKNFINCJNLH").ToInt32()==16,"native entity ID fixture retains full24-byte layout");
        var stamp=new BEADLMGGGGL {EOKFPKOEDDJ=7,DDJGLLGPBJD=0x10203040,JLIDCJLKLBD=0x81,JHHPHPJMFNG=0x72,IKNFINCJNLH=0xFEDCBA9876543210UL};local.GBJCJJNPPEC.State=message.KOJPEFFGGIJ.Knocked;local.GIEBNLMODIB=stamp;local.FFOPCLFLIMO=false;match.Lookup=enemy;Run("UpdateKnockdownIsInCamera",local);Check(BEADLMGGGGL.GHAMDLFNMMA(stamp,match.LastLookupId),"VM native lookup forwards every ID byte including high64bits");local.GBJCJJNPPEC.State=message.KOJPEFFGGIJ.None;
        Check(!Methods.ContainsKey("GFHCADCHHEO"),"local-only shadow path is not used as remote presentation hook");
        // Drive the actual entry and presentation hooks around simulated native movement.
        Set("MzOpen",true);Set("MzTab",4);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzLagNextPulse",0f);Set("MzLagSeconds",.15f);Click(154,236);Check(switches[17]&&!Get<bool>("MzLagEnabled")&&!Get<bool>("MzLagActive"),"menu toggle reveals floating control without activating hold");Click(Get<float>("MzLagX")+40,Get<float>("MzLagY")+40);Check(Get<bool>("MzLagEnabled"),"floating tap activates presentation hold");Click(400,390);Check(Get<float>("MzLagSeconds")==.25f&&Get<bool>("MzLagActive"),"250 ms UI selector reconnects the actual hold duration");Click(280,390);Check(Get<float>("MzLagSeconds")==.15f,"150 ms UI selector changes actual hold duration");Check(Get<bool>("MzLagActive")&&Get<int>("MzLagRosterCount")==1,"lag activation selects only current-match enemies");
        Vector3 anchor=enemy.Root.position;Run("UpdateKnockdownIsInCamera",enemy);Time.Now=.05f;
        LagBegin(enemy);enemy.Root.position=anchor+new Vector3(1,0,0);Run("get_IsBeingCarried",enemy);enemy.Root.position=anchor+new Vector3(2,0,0);Run("UpdateKnockdownIsInCamera",enemy);
        Check(enemy.Root.position.x==anchor.x&&Get<int>("MzLagWrites")==1,"post-update hook holds visible anchor after native movement");
        int lateWrites=enemy.Root.PositionWrites;Run("NeedRunHighFrame",enemy);Run("get_IsBeingCarried",enemy);Check(enemy.Root.position.x==anchor.x&&enemy.Root.PositionWrites==lateWrites,"same-frame avatar LateUpdate queries preserve the held pose until rendering");
        int nestedLag=0;enemy.Root.OnPositionWrite=delegate(){nestedLag++;Run("NeedRunHighFrame",enemy);Run("UpdateKnockdownIsInCamera",enemy);};
        LagBegin(enemy);enemy.Root.OnPositionWrite=null;Check(nestedLag==1&&!Get<bool>("MzLagBusy"),"nested native transform callback does not recurse into lag writes");Check(enemy.Root.position.x==anchor.x+2,"update-entry helper restores latest real position before native logic");
        enemy.Root.position=anchor+new Vector3(3,0,0);Run("get_IsBeingCarried",enemy);Check(enemy.Root.position.x==anchor.x+3,"post-entry getter leaves a newer native position untouched");Run("UpdateKnockdownIsInCamera",enemy);
        Run("UpdateKnockdownIsInCamera",enemy);switches[17]=false;Run("MzLagPulse");Check(enemy.Root.position.x==anchor.x+3&&!Get<bool>("MzLagActive")&&Get<Player[]>("MzLagPlayers").All(p=>p==null),"duplicate end callback and disabling preserve true pose and release every actor reference");
        // Bounded hold interval, explicit native correction, actor reuse and scene identity.
        switches[17]=true;Set("MzLagEnabled",true);Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);float first=enemy.Root.position.x;
        Time.Now=.1f;LagBegin(enemy);enemy.Root.position=new Vector3(first+1,0,10);Run("UpdateKnockdownIsInCamera",enemy);
        enemy.Root.position=new Vector3(44,0,10);LagBegin(enemy);Check(enemy.Root.position.x==44,"incoming correction is never overwritten by stale real position");
        Time.Now=.5f;Run("UpdateKnockdownIsInCamera",enemy);Check(enemy.Root.position.x==44,"expired 150 ms anchor refreshes to current position");
        Time.Now=.55f;LagBegin(enemy);enemy.Root.position=new Vector3(45,0,10);Run("UpdateKnockdownIsInCamera",enemy);
        enemy.Id++;int changed=enemy.Root.PositionWrites;LagBegin(enemy);Check(enemy.Root.PositionWrites==changed,"recycled entity UniqueID prevents old-pose restoration");Run("UpdateKnockdownIsInCamera",enemy);Check(enemy.Root.PositionWrites==changed,"stale roster identity cannot apply to a recycled entity");
        Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);Time.Now=.6f;LagBegin(enemy);enemy.Root.position=new Vector3(46,0,10);Run("UpdateKnockdownIsInCamera",enemy);
        var replacement=Bone(99,0,10);enemy.m_CachedTransform=replacement;LagBegin(enemy);Check(replacement.PositionWrites==1&&replacement.position.x==99,"replacement root transform never receives stale cached restoration");enemy.m_CachedTransform=enemy.Root;
        Run("MzLagStop");Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);LagBegin(enemy);enemy.Root.position=new Vector3(47,0,10);Run("UpdateKnockdownIsInCamera",enemy);
        changed=enemy.Root.PositionWrites;COW.GameFacade.Match=new JMAGGLCNGIG();LagBegin(enemy);Check(enemy.Root.PositionWrites==changed&&!Get<bool>("MzLagActive"),"match change drops old-scene references without writing an old actor");
        COW.GameFacade.Match=match;Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);LagBegin(enemy);enemy.Root.position=new Vector3(48,0,10);Run("UpdateKnockdownIsInCamera",enemy);
        var oldLocal=local;COW.GameFacade.Local=Enemy(0);COW.GameFacade.Local.Local=true;changed=enemy.Root.PositionWrites;LagBegin(enemy);Check(enemy.Root.PositionWrites==changed&&!Get<bool>("MzLagActive"),"local-player context replacement drops stale hold without writing");COW.GameFacade.Local=oldLocal;
        Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);LagBegin(enemy);enemy.Root.position=new Vector3(49,0,10);Run("UpdateKnockdownIsInCamera",enemy);Time.Now=2;
        Run("UpdateKnockdownIsInCamera",enemy);Check(enemy.Root.position.x==49&&!Get<bool>("MzLagActive"),"one-second missing UI heartbeat releases owned pose instead of holding indefinitely");
        Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);LagBegin(enemy);enemy.Root.position=new Vector3(50,0,10);Run("UpdateKnockdownIsInCamera",enemy);Run("MzReject","test-key-disabled");
        Check(enemy.Root.position.x==50&&!Get<bool>("MzLagActive"),"key rejection immediately restores lag pose");Set("MzLeaseDeadline",1000f);
        // Actors absent from the roster, teammates and invalid objects never receive a write.
        Set("MzLagNextPulse",0f);Run("MzLagPulse");var stranger=Enemy(8);writes=stranger.Root.PositionWrites;Run("UpdateKnockdownIsInCamera",stranger);stranger.Root.position=new Vector3(9,0,10);Run("UpdateKnockdownIsInCamera",stranger);Check(stranger.Root.PositionWrites==writes+1,"non-match avatar never enters lag rows");
        enemy.Team=true;Time.Now+=.2f;Run("MzLagPulse");changed=enemy.Root.PositionWrites;Run("UpdateKnockdownIsInCamera",enemy);Check(enemy.Root.PositionWrites==changed&&Get<int>("MzLagRosterCount")==0,"team transition releases roster membership");enemy.Team=false;
        foreach(int bad in new[]{0,1,2,3}){
            enemy.HP=bad==0?0:100;enemy.IsKnockedDownBleed=bad==1;enemy.LNHFOHKEAMP=bad==2?local:null;enemy.gameObject.activeInHierarchy=bad!=3;
            Set("MzLagNextPulse",0f);Run("MzLagPulse");changed=enemy.Root.PositionWrites;Run("UpdateKnockdownIsInCamera",enemy);Check(enemy.Root.PositionWrites==changed,"dead/knocked/carried/inactive actor receives no lag position writes");
        }
        enemy.HP=100;enemy.IsKnockedDownBleed=false;enemy.LNHFOHKEAMP=null;enemy.gameObject.activeInHierarchy=true;
        Run("MzLagStop");Set("MzLagNextPulse",0f);Run("MzLagPulse");Run("UpdateKnockdownIsInCamera",enemy);LagBegin(enemy);enemy.Root.position=new Vector3(51,0,10);enemy.Root.FailWrite=true;Run("UpdateKnockdownIsInCamera",enemy);
        Check(Get<bool>("MzLagBlocked")&&!switches[17]&&!Get<bool>("MzLagActive")&&Get<Player[]>("MzLagPlayers").All(p=>p==null),"write failure stops only lag, disables its toggle and releases rows");enemy.Root.FailWrite=false;Set("MzLagBlocked",false);
        // Dense scene: fixed actor arrays and 16 holds across repeated update/post phases.
        match.Players.Clear();for(int i=0;i<150;i++)match.Players.Add(Enemy(i*.01f));switches[17]=true;Set("MzLagEnabled",true);Set("MzLagNextPulse",0f);Run("MzLagPulse");var rows=Get<Player[]>("MzLagPlayers");var roster=Get<Player[]>("MzLagRoster");
        Check(Get<int>("MzLagRosterCount")==32,"dense roster sampling is capped at 32 eligible enemies");
        for(int i=0;i<=10;i++)switches[i]=true;switches[13]=true;Set("MzEspBlocked",false);Set("MzEspFailures",0);Set("MzSampleFailures",0);Camera.main=new Camera {gameObject=new GameObject("lag-and-esp")};
        for(int frame=0;frame<90;frame++){
            Time.Now+=.016f;Time.Frame++;Run("MzLagPulse");
            foreach(Player actor in match.Players){Run("NeedRunHighFrame",actor);actor.Root.position=actor.Root.position+new Vector3(.01f,0,0);Run("get_IsBeingCarried",actor);Run("UpdateKnockdownIsInCamera",actor);}
            Check(rows.Count(p=>p!=null)<=16,"dense frame never exceeds 16 retained actors");
            if(frame%10==0){GUI.Calls.Clear();Render();Check(!Get<bool>("MzEspBlocked")&&!Get<bool>("MzSampleFaulted")&&GUI.Calls.Count<=193,"all ESP features and FOV stay inside render budget while lag holds are active");}
        }
        Check(Object.ReferenceEquals(rows,Get<Player[]>("MzLagPlayers"))&&Object.ReferenceEquals(roster,Get<Player[]>("MzLagRoster")),"dense update loop reuses fixed arrays without growing actor storage");
        var held=rows.First(p=>p!=null);Exception workerError=null;changed=held.Root.PositionWrites;
        var worker=new System.Threading.Thread(delegate(){try{Run("NeedRunHighFrame",held);Run("get_IsBeingCarried",held);Run("UpdateKnockdownIsInCamera",held);}catch(Exception e){workerError=e;}});worker.Start();worker.Join();Check(workerError==null&&held.Root.PositionWrites==changed,"off-thread native hook calls preserve their return path without mutating positions");
        Run("MzLagStop");Check(rows.All(p=>p==null)&&roster.All(p=>p==null),"stop clears all fixed hold and roster references after dense scene");
        Array.Clear(switches,0,switches.Length);Time.Now=0;COW.GameFacade.Match=null;
    }
    static void FloatingLagChecks(string[] args)
    {
        var sw=Get<bool[]>("MzSwitch");Array.Clear(sw,0,sw.Length);Set("MzLagEnabled",false);Run("MzLagStop");Set("MzLeaseDeadline",10000f);Set("MzKeyHash","");Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",4);Set("MzPanelX",120f);Set("MzPanelY",16f);Set("MzLagX",800f);Set("MzLagY",200f);Set("MzTouchFailed",false);Set("MzDragMode",0);Time.Now=0;
        var local=Enemy(0);local.Local=true;var enemy=Enemy(1);var match=new JMAGGLCNGIG();match.Players.Add(enemy);COW.GameFacade.Local=local;COW.GameFacade.Match=match;UICamera.Main=new Camera {gameObject=new GameObject("floating-lag-ui")};Frame(EventType.Repaint);
        Check(!GUI.Calls.Any(d=>d.Text=="FL TẮT"||d.Text=="FL BẬT")&&!Get<SphereCollider>("MzTouchLag").enabled,"floating button and its input collider start hidden");
        Click(154,236);Frame(EventType.Repaint);float x=Get<float>("MzLagX")+40,y=Get<float>("MzLagY")+40,scale=Get<float>("MzScale");
        Check(sw[17]&&!Get<bool>("MzLagEnabled")&&GUI.Calls.Any(d=>d.Text=="FL TẮT")&&UiHit(x*scale,y*scale),"menu switch shows an inactive floating toggle and its exact hit region");for(int i=0;i<30;i++)Frame(EventType.Repaint);Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"fakelag-floating.svg"));
        Set("MzOpen",false);Set("MzOpenAnim",0f);Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="FL TẮT")&&!Get<BoxCollider>("MzTouchPanel").enabled,"floating control stays usable after menu closes");
        Click(x,y);Check(Get<bool>("MzLagEnabled")&&Get<bool>("MzLagActive")&&Event.current.type==EventType.Used,"floating tap enables actual hold and consumes game input");
        var anchor=enemy.Root.position;Run("get_IsBeingCarried",enemy);Run("UpdateKnockdownIsInCamera",enemy);Time.Frame++;Time.Now=.05f;Run("get_IsBeingCarried",enemy);enemy.Root.position=anchor+new Vector3(1,0,0);Run("UpdateKnockdownIsInCamera",enemy);
        Check(enemy.Root.position.x==anchor.x&&Get<int>("MzLagTailCalls")>0,"native remote path skips local shadow logic yet shared tail actually holds changed position");
        Click(x,y);Check(!Get<bool>("MzLagEnabled")&&!Get<bool>("MzLagActive")&&enemy.Root.position.x==anchor.x+1&&sw[17],"floating off immediately restores real pose while leaving button visible");
        Frame(EventType.MouseDown,x,y);Frame(EventType.MouseDrag,x-100,y+90);Frame(EventType.MouseUp,x-100,y+90);Frame(EventType.Repaint);
        float nx=Get<float>("MzLagX")+40,ny=Get<float>("MzLagY")+40;Check(Math.Abs(nx-Mathf.Clamp(x-100,44,Screen.width/scale-44))<.01f&&Math.Abs(ny-Mathf.Clamp(y+90,44,Screen.height/scale-44))<.01f&&!Get<bool>("MzLagEnabled")&&UiHit(nx*scale,ny*scale)&&!UiHit(x*scale,y*scale),"drag moves only floating control and collider without activating it");
        Frame(EventType.MouseDown,900,600);Frame(EventType.MouseUp,nx,ny);Check(!Get<bool>("MzLagEnabled"),"gesture begun outside cannot activate the floating toggle");
        Click(nx,ny);Check(Get<bool>("MzLagEnabled"),"floating control can re-enable after drag");Set("MzOpen",true);Set("MzOpenAnim",1f);Set("MzTab",4);Click(154,236);Frame(EventType.Repaint);
        Check(!sw[17]&&!Get<bool>("MzLagEnabled")&&!Get<bool>("MzLagActive")&&!Get<SphereCollider>("MzTouchLag").enabled&&!GUI.Calls.Any(d=>d.Text=="FL TẮT"||d.Text=="FL BẬT")&&!UiHit(nx*scale,ny*scale),"menu off hides button and collider, restores/releases holds and frees underlying game input");
        Click(154,236);Click(Get<float>("MzLagX")+40,Get<float>("MzLagY")+40);Set("MzLeaseDeadline",-.1f);Frame(EventType.Repaint);Check(!Get<bool>("MzLagEnabled")&&!Get<bool>("MzLagActive")&&!Get<SphereCollider>("MzTouchLag").enabled,"expired key removes floating hit region and stops hold");
        Array.Clear(sw,0,sw.Length);Set("MzLeaseDeadline",10000f);Time.Now=0;UICamera.Main=null;COW.GameFacade.Match=null;Run("MzTouchRelease");
    }
    static void CompatibilityChecks()
    {
        string log=File.ReadAllText(Path.Combine(Application.TestFolder,"Mizze-startup.log"));Check(log.Contains("Mizze R8 legacy startup")&&log.Contains("driver-ready")&&log.Contains("gui-entered")&&log.Contains("launcher-painted"),"R8 log confirms bootstrap, GUI entry and successful launcher draw through baseline path");
        var sw=Get<bool[]>("MzSwitch");Array.Clear(sw,0,sw.Length);Set("MzOpen",false);Set("MzOpenAnim",0f);Set("MzLeaseDeadline",10000f);Set("MzKeyHash","");Set("MzBubbleX",24f);Set("MzBubbleY",96f);Screen.Width=1280;Screen.Height=720;Frame(EventType.Repaint);Run("MzLagButtonPlace");Check(Get<float>("MzLagX")==24&&Get<float>("MzLagY")==188,"FL is placed directly below visible Mizze launcher");
        float width=Screen.width/Get<float>("MzScale"),height=Screen.height/Get<float>("MzScale");Set("MzBubbleY",height-84);Run("MzLagButtonPlace");Check(Get<float>("MzLagY")==height-176,"FL falls above bubble when below would leave viewport");
        Set("MzBubbleX",24f);Set("MzBubbleY",4f);Screen.Width=390;Screen.Height=100;Set("MzScale",1f);Run("MzLagButtonPlace");Check(Get<float>("MzLagX")==116&&Get<float>("MzLagY")==4,"short viewport places FL beside bubble instead of hiding off-screen");Screen.Width=1280;Screen.Height=720;Set("MzBubbleX",24f);Set("MzBubbleY",96f);Frame(EventType.Repaint);
        sw[17]=true;Run("MzLagButtonPlace");Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&GUI.Calls.Any(d=>d.Text=="FL TẮT"),"FL visibility does not replace or hide Mizze launcher");sw[17]=false;Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&!GUI.Calls.Any(d=>d.Text=="FL TẮT"||d.Text=="FL BẬT"),"disabling FL leaves Mizze visible through original drawing path");
        Set("MzLeaseDeadline",0f);Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze"),"inactive key cannot hide baseline Mizze launcher");Set("MzLeaseDeadline",10000f);int stages=Get<int>("MzStartupCount");for(int i=0;i<120;i++)Frame(EventType.Repaint);Check(Get<int>("MzStartupCount")==stages,"steady drawing does not write additional startup log records");
    }
    static void MemoryChecks()
    {
        const long mb=1048576L;var sw=Get<bool[]>("MzSwitch");COW.GcUtil.Calls=0;COW.GcUtil.Fail=false;Set("MzMemoryBaseline",0L);Set("MzMemoryNextCollect",0f);Set("MzMemoryPaused",false);Set("MzMemoryCollections",0);
        Run("MzMemoryStep",100*mb,1f);Run("MzMemoryStep",130*mb,2f);Check(COW.GcUtil.Calls==0,"low heap and small growth do not force GC");
        Set("MzInGui",true);Run("MzMemoryStep",400*mb,3f);Set("MzInGui",false);Set("MzInRender",true);Run("MzMemoryStep",400*mb,3f);Set("MzInRender",false);Check(COW.GcUtil.Calls==0,"memory collection never runs inside GUI or renderer");
        COW.GcUtil.OnCollect=delegate(){Check(!Get<bool>("MzInGui")&&Get<bool>("MzMemoryBusy")&&!COW.GcUtil.AutoGcDisabled,"game collector temporarily enables GC outside GUI with reentry guard");Run("MzMemoryStep",500*mb,3f);};Run("MzMemoryStep",400*mb,3f);COW.GcUtil.OnCollect=null;
        Check(COW.GcUtil.Calls==1&&Get<int>("MzMemoryCollections")==1&&!Get<bool>("MzMemoryBusy")&&COW.GcUtil.AutoGcDisabled&&Get<long>("MzMemoryAfter")<400*mb,"growth triggers one collection, restores disabled mode and records reclaimed memory");
        Run("MzMemoryStep",500*mb,4f);Check(COW.GcUtil.Calls==1,"collection cooldown prevents frame-by-frame GC");
        Exception workerError=null;var worker=new System.Threading.Thread(delegate(){try{Run("MzMemoryStep",900*mb,10f);}catch(Exception e){workerError=e;}});worker.Start();worker.Join();Check(workerError==null&&COW.GcUtil.Calls==1,"worker thread cannot invoke native collector");
        var memoryLocal=Enemy(0);memoryLocal.Local=true;var memoryEnemy=Enemy();COW.GameFacade.Local=memoryLocal;COW.GameFacade.Match=new JMAGGLCNGIG();COW.GameFacade.Match.Players.Add(memoryEnemy);Set("MzLeaseDeadline",10000f);sw[17]=true;Set("MzLagEnabled",true);Set("MzLagBlocked",false);Set("MzLagNextPulse",0f);Time.Now=0;Run("MzLagPulse");var heldPoint=memoryEnemy.Root.position;Run("UpdateKnockdownIsInCamera",memoryEnemy);Run("get_IsBeingCarried",memoryEnemy);memoryEnemy.Root.position=heldPoint+new Vector3(1,0,0);Run("UpdateKnockdownIsInCamera",memoryEnemy);
        Check(memoryEnemy.Root.position.x==heldPoint.x,"memory pause fixture has an active held remote pose");
        Set("MzMemoryBefore",1000*mb);Run("MzMemoryComplete",1000*mb,20f);Check(Get<bool>("MzMemoryPaused")&&Get<int>("MzMemoryPressure")==2&&Get<float>("MzMemoryNextCollect")==50f,"unreclaimable high live heap pauses heavy work and backs GC off for thirty seconds");
        Check(memoryEnemy.Root.position.x==heldPoint.x+1&&!Get<bool>("MzLagActive"),"memory trim restores held pose before marking heavy work paused");sw[0]=true;sw[13]=true;Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze")&&Get<int>("MzCommandCount")==0,"memory pause retains launcher while clearing heavy ESP work");
        Run("MzMemoryStep",300*mb,21f);Check(!Get<bool>("MzMemoryPaused"),"heap recovery automatically resumes features without losing switches");
        COW.GcUtil.Fail=true;Set("MzMemoryNextCollect",0f);Set("MzMemoryBaseline",100*mb);Run("MzMemoryStep",500*mb,30f);Check(!Get<bool>("MzMemoryBusy")&&Get<int>("MzMemoryFaults")>0&&Get<float>("MzMemoryNextCollect")==60f,"collector fault releases guard and backs off instead of breaking menu");COW.GcUtil.Fail=false;
        Set("MzMemoryPaused",false);Set("MzMemoryPressure",0);Set("MzMemoryBaseline",0L);Set("MzMemoryNextCollect",0f);
        long replayHeap=100*mb,peak=replayHeap;int replayStart=COW.GcUtil.Calls;COW.GcUtil.OnCollect=delegate(){replayHeap=100*mb;};
        Run("MzMemoryStep",replayHeap,100f);for(int second=1;second<=900;second++){replayHeap+=7506272L;if(replayHeap>peak)peak=replayHeap;Run("MzMemoryStep",replayHeap,100f+second);}
        COW.GcUtil.OnCollect=null;Check(peak<280*mb&&COW.GcUtil.Calls-replayStart>20&&COW.GcUtil.Calls-replayStart<60,"15-minute replay of user log growth stays below 280 MiB when garbage is reclaimable; not a device RAM claim");
        Set("MzMemoryPaused",false);Set("MzMemoryPressure",0);Set("MzMemoryBaseline",0L);Set("MzMemoryNext",0f);Set("MzMemoryNextCollect",0f);Array.Clear(sw,0,sw.Length);
    }
    static void AllocationProfile(string file)
    {
        AppDomain.MonitoringIsEnabled=true;var sw=Get<bool[]>("MzSwitch");
        var local=Enemy(0);local.Local=true;COW.GameFacade.Local=local;var match=new JMAGGLCNGIG();COW.GameFacade.Match=match;for(int i=0;i<12;i++)match.Players.Add(Enemy((i-6)*.25f));
        Camera.main=new Camera {gameObject=new GameObject("allocation-camera")};UICamera.Main=new Camera {gameObject=new GameObject("allocation-ui")};Set("MzLeaseDeadline",10000f);Set("MzKeyHash","");Time.Now=0;
        var output=new StringBuilder();output.Append("{\"frames\":300,\"environment\":\"offline .NET IFix VM; includes test doubles, not iOS measurements\",\"modes\":[");
        for(int mode=0;mode<4;mode++){
            Array.Clear(sw,0,sw.Length);if(mode>0){sw[0]=true;sw[1]=true;}if(mode==2||mode==3){for(int i=4;i<11;i++)sw[i]=true;sw[13]=true;}
            Set("MzOpen",mode==3);Set("MzOpenAnim",mode==3?1f:0f);Set("MzTab",0);
            for(int i=0;i<60;i++){Time.Now+=1f/60;Frame(EventType.Repaint);}
            long retainedBefore=GC.GetTotalMemory(true),allocatedBefore=AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize;
            for(int i=0;i<300;i++){Time.Now+=1f/60;Frame(EventType.Repaint);}
            long allocated=AppDomain.CurrentDomain.MonitoringTotalAllocatedMemorySize-allocatedBefore,retainedAfter=GC.GetTotalMemory(true);
            if(mode>0)output.Append(',');output.Append("{\"name\":\"");output.Append(mode==0?"launcher":mode==1?"box12":mode==2?"allEsp6":"allEsp6-menuOpen");output.Append("\",\"allocatedBytes\":");output.Append(allocated);output.Append(",\"retainedDelta\":");output.Append(retainedAfter-retainedBefore);output.Append('}');
        }
        output.Append("]}\n");File.WriteAllText(file,output.ToString());Console.WriteLine(output.ToString());
    }
    static int Main(string[] args)
    {
        foreach(var line in File.ReadAllLines(args[1])){var a=line.Split('\t');Methods.Add(a[2],int.Parse(a[0]));}
        Vm=Load(args[0]);
        // A late patch load can enter a match before any lobby getter is called.
        var bootPlayer=Enemy(0);bootPlayer.Local=true;COW.GameFacade.Local=bootPlayer;COW.GameFacade.Match=new JMAGGLCNGIG();
        Time.Now=Single.NaN;Set("MzNextBootstrap",Single.MaxValue);Set("MzThreadId",Int32.MaxValue);GameObject.OnAdd=delegate(){Check(Get<bool>("MzInitialized")&&Get<bool[]>("MzSwitch").Length==18,"old source initializes state before native AddComponent callback");Run("MzEnsure");};
        Check(!(bool)Run("IsReallyInStealth",bootPlayer)&&Get<bool>("MzInitialized")&&Get<GameObject>("MzDriver")!=null&&GCommon.UIModelManager.instance.Calls==0,"old-source cold entry ignores stale thread and future retry timestamp and creates driver without lobby getter");GameObject.OnAdd=null;Time.Now=0;Set("MzNextBootstrap",0f);Check(COW.GcUtil.Calls==0,"old bootstrap runs before a usable Unity clock and never collects before the first GUI callback");COW.GameFacade.Match=null;
        // Lobby getter preserves the lazy model and reuses the already persistent driver.
        var model=Run("get_UIModelRole");Check(Get<bool[]>("MzSwitch").Length==18,"old-source initialization creates the upgraded switch array on a fresh process");Check(model!=null&&System.Object.ReferenceEquals(model,Run("get_UIModelRole")),"lobby cached model preserved");Check(GCommon.UIModelManager.instance.Calls==1,"model initialized once");
        var g=GameObject.Find("__mizze_driver");Check(g!=null&&g.Added!=null&&g.Persistent,"persistent driver created in lobby");Driver=g.Added;Check(Get<float>("MzPanelX")==120&&Get<float>("MzPanelY")==16,"new initial panel position");Check(!Get<bool[]>("MzSwitch")[0]&&!Get<bool[]>("MzSwitch")[13],"fresh boot keeps ESP and FOV inactive until explicitly enabled");Set("MzPanelX",98f);Set("MzPanelY",30f);
        Set("MzThreadId",Int32.MaxValue);Frame(EventType.Repaint);Check(Get<int>("MzThreadId")==System.Threading.Thread.CurrentThread.ManagedThreadId,"first Unity GUI callback replaces stale bootstrap thread before drawing");Check(Labels()==1&&GUI.Calls.Any(d=>d.Text=="Mizze"),"only circular Mizze launcher initially");Check(Math.Abs(Get<float>("MzScale")-1.35f)<.0001f,"larger display scale at 720p");Check(GUI.Calls.Any(d=>d.Text==null&&d.Rect.width==74&&d.Color.r<.03f&&d.Color.g<.04f),"launcher uses explicit black shader color");Check(GUI.Calls.Single(d=>d.Text=="Mizze").FontSize==20&&GUI.Calls.Single(d=>d.Text=="Mizze").Matrix.Scale.x==1.35f,"larger launcher font and size");Snapshot(Path.Combine(Path.GetDirectoryName(args[0]),"launcher.svg"));
        if(args.Length>2&&args[2]=="profile"){AllocationProfile(Path.Combine(Path.GetDirectoryName(args[0]),"allocation-profile.json"));return 0;}
        var local=Enemy(0);local.Local=true;local.Stealth=true;local.Origin=new Vector3(0,0,1);COW.GameFacade.Local=local;
        Check(!(bool)Run("IsReallyInStealth",local)&&local.StealthCalls==0&&local.Movable,"native real-stealth ignores IsInStealth flag and preserves movement");
        local.BLNAPOLKCDL=new Dictionary<uint,FHAPNJGMHLM>();Check(!(bool)Run("IsReallyInStealth",local),"empty native stealth dictionary remains false");
        var hidden=new TestStealth {Value=false};var real=new TestStealth {Value=true};local.BLNAPOLKCDL.Add(1,null);local.BLNAPOLKCDL.Add(2,hidden);local.BLNAPOLKCDL.Add(3,real);
        Check((bool)Run("IsReallyInStealth",local)&&hidden.Calls==1&&real.Calls==1&&local.StealthCalls==0,"restored match hook uses dictionary value MKGBABFOOFP like native ARM64 body");real.Value=false;Check(!(bool)Run("IsReallyInStealth",local),"all inactive native stealth flags remain false");local.Stealth=false;local.BLNAPOLKCDL=null;
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
        Set("MzDriver",null);GameObject.World.Clear();GameObject.FailAdd=true;Set("MzNextBootstrap",0f);int stealthAdds=GameObject.AddCalls;Check(!local.IsReallyInStealth()&&local.Movable&&GameObject.AddCalls==stealthAdds,"unpatched stealth never initializes menu");Run("MzEnsure");Check(!Get<bool>("MzBooting"),"bootstrap exception releases reentry guard");GameObject.FailAdd=false;Time.Now+=1.1f;Run("MzEnsure");Check(GameObject.Find("__mizze_driver").Added!=null,"bootstrap retries component creation");
        BackgroundChecks(args);
        ExtendedChecks(args);
        StabilityChecks(args);
        SafeRendererChecks();
        CachedNodeChecks();
        UiPerformanceChecks();
        WeaponChecks(args);
        MenuRecoveryChecks();
        FaultIsolationChecks();
        TouchAndSoakChecks();
        FakeLagChecks();
        FloatingLagChecks(args);
        CompatibilityChecks();
        GUI.FailColorReadOnce=true;Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(!Get<bool>("MzInGui"),"GUI snapshot exception cannot permanently latch rendering guard");Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze"),"launcher recovers on next frame after snapshot failure");
        GUI.matrix=new Matrix4x4 {Tag=99};GUI.FailRestoreOnce=true;Event.current=new Event {type=EventType.Repaint};Run("OnGUI",Driver);Check(!Get<bool>("MzInGui"),"GUI cleanup exception always releases rendering guard");Frame(EventType.Repaint);Check(GUI.Calls.Any(d=>d.Text=="Mizze"),"launcher recovers after GUI restore failure");
        MemoryChecks();
        Console.WriteLine("PASS: "+Checks+" checks; final IFix bytecode executed by pinned Tencent VM. Lobby, drag, animations, ESP geometry/filtering, head aim/fire/FOV, silent record/restore, key binding/expiry/races. Unity/game/network are offline doubles; iPhone loading, in-game aim and native crash behavior remain unverified; presentation fakelag remains experimental and device-unverified.");GC.KeepAlive(Vm);return 0;
    }
}
