// C# build tool for a small IFix menu, using the supplied game's opcode layout.
// This is an explicit bytecode emitter, not a general C# -> IFix compiler.
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;

sealed class Code
{
    public readonly List<int[]> Instructions = new List<int[]>();
    readonly Dictionary<string, int> labels = new Dictionary<string, int>();
    readonly List<Tuple<int,string>> branches = new List<Tuple<int,string>>();
    readonly List<string[]> catches = new List<string[]>();
    public void Emit(GameCode code, int operand = 0) { Instructions.Add(new[] { (int)code, operand }); }
    public void Label(string name) { labels.Add(name, Instructions.Count); }
    public void Branch(GameCode code, string label) { branches.Add(Tuple.Create(Instructions.Count, label)); Emit(code); }
    public void Catch(string start, string end, string handler, string handlerEnd) { catches.Add(new[] { start,end,handler,handlerEnd }); }
    public void Call(int originalId, int arguments) { Emit(GameCode.CallExtern, (arguments << 16) | Bindings.External[originalId]); }
    public void New(int originalId, int arguments) { Emit(GameCode.Newobj, (arguments << 16) | Bindings.External[originalId]); }
    public void Float(float value) { Emit(GameCode.Ldc_R4, BitConverter.ToInt32(BitConverter.GetBytes(value), 0)); }
    public void Rect(float x, float y, float width, float height) { Float(x); Float(y); Float(width); Float(height); New(129, 4); }
    public void Color(float r, float g, float b, float a) { Float(r); Float(g); Float(b); Float(a); New(146, 4); Call(147, 1); }
    public void Write(BinaryWriter w)
    {
        foreach (var b in branches) Instructions[b.Item1][1] = labels[b.Item2] - b.Item1;
        w.Write(Instructions.Count);
        foreach (var i in Instructions) { w.Write(i[0]); w.Write(i[1]); }
        w.Write(catches.Count);
        foreach(var h in catches) { w.Write(0); w.Write(Bindings.ExceptionType); w.Write(labels[h[0]]); w.Write(labels[h[1]]); w.Write(labels[h[2]]); w.Write(labels[h[3]]); }
    }
}

static class Program
{
    static readonly List<string> Strings = new List<string>();
    const string Driver = "__33e_menu_driver";
    static void Text(Code c, string s) { int id = Strings.IndexOf(s); if (id < 0) { id = Strings.Count; Strings.Add(s); } c.Emit(GameCode.Ldstr, id); }
    static void Label(Code c, float x, float y, float w, float h, string s) { c.Rect(x,y,w,h); Text(c,s); c.Call(149,2); }
    static void Fill(Code c, float x, float y, float w, float h) { c.Rect(x,y,w,h); c.Call(145,0); c.Call(148,2); }
    static void ReadState(Code c, int field) { c.Emit(GameCode.Ldloca,4); c.Emit(GameCode.Ldfld,field); }
    static void Toggle(Code c, int field)
    {
        c.Emit(GameCode.Ldloca,4); ReadState(c,field); c.Float(0); c.Emit(GameCode.Ceq); c.Emit(GameCode.Conv_R4); c.Emit(GameCode.Stfld,field);
        c.Emit(GameCode.Ldloc,1); c.Call(10,1); c.Emit(GameCode.Ldloc,4); c.Call(12,2);
    }
    static void Click(Code c, float x, float y, float w, float h, int field, string end)
    {
        c.Emit(GameCode.Ldloc,0); c.Call(131,1); c.Emit(GameCode.Ldc_I4,1); c.Branch(GameCode.Bne_Un,end); // MouseUp only
        c.Rect(x,y,w,h); c.Emit(GameCode.Stloc,3); c.Emit(GameCode.Ldloca,3);
        c.Emit(GameCode.Ldloc,0); c.Call(130,1); c.Call(132,2); c.Branch(GameCode.Brfalse,end);
        Toggle(c,field); c.Emit(GameCode.Ldloc,0); c.Call(138,1); c.Label(end);
    }
    static Code Bootstrap()
    {
        var c = new Code(); c.Emit(GameCode.StackSpace,(2<<16)|8);
        c.Emit(GameCode.Ldarg,0); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brfalse,"self");
        c.Emit(GameCode.Ldc_I4,0); c.Emit(GameCode.Ret,1);
        c.Label("self"); c.Emit(GameCode.Ldarg,0); c.Call(200,1); c.Emit(GameCode.Stloc,0);
        c.Label("try");
        Text(c,Driver); c.Call(2,1); c.Emit(GameCode.Stloc,1);
        c.Emit(GameCode.Ldloc,1); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brfalse,"component");
        Text(c,Driver); c.New(9,1); c.Emit(GameCode.Stloc,1);
        c.Emit(GameCode.Ldloc,1); c.Call(10,1); c.Float(0); c.Float(1); c.Float(1); c.New(11,3); c.Call(12,2);
        c.Label("component"); c.Emit(GameCode.Ldloc,1); c.Emit(GameCode.Ldtype,Bindings.SceneType); c.Emit(GameCode.Nop); c.Call(218,2);
        c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brfalse,"done");
        c.Emit(GameCode.Ldloc,1); c.Emit(GameCode.Ldtype,Bindings.SceneType); c.Emit(GameCode.Nop); c.Call(13,2); c.Emit(GameCode.Pop);
        c.Emit(GameCode.Ldloc,1); c.Call(14,1);
        c.Branch(GameCode.Br,"done");
        c.Label("endTry"); c.Label("catch"); c.Emit(GameCode.Pop); c.Branch(GameCode.Br,"done");
        c.Label("done"); c.Emit(GameCode.Ldloc,0); c.Emit(GameCode.Ret,1);
        c.Catch("try","endTry","catch","done"); return c;
    }
    static Code Menu()
    {
        var c = new Code(); c.Emit(GameCode.StackSpace,(6<<16)|8);
        c.Emit(GameCode.Ldarg,0); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brfalse,"self"); c.Emit(GameCode.Ret);
        c.Label("self"); c.Call(93,0); c.Emit(GameCode.Stloc,0); c.Emit(GameCode.Ldloc,0); c.Branch(GameCode.Brtrue,"event"); c.Emit(GameCode.Ret);
        c.Label("event"); c.Emit(GameCode.Ldarg,0); c.Call(7,1); c.Emit(GameCode.Stloc,1);
        c.Emit(GameCode.Ldloc,1); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"return");
        c.Emit(GameCode.Ldloc,1); c.Call(94,1); Text(c,Driver); c.Call(95,2); c.Branch(GameCode.Brtrue,"return");
        c.Emit(GameCode.Ldloc,1); c.Call(10,1); c.Call(54,1); c.Emit(GameCode.Stloc,4);
        c.Call(142,0); c.Emit(GameCode.Stloc,2);
        c.Call(141,0); c.Emit(GameCode.Stloc,5); c.Call(143,0); c.Call(144,1);
        ReadState(c,1); c.Float(0); c.Emit(GameCode.Ceq); c.Branch(GameCode.Brtrue,"panel");
        c.Emit(GameCode.Ldloc,0); c.Call(131,1); c.Emit(GameCode.Ldc_I4,7); c.Branch(GameCode.Bne_Un,"panel"); // Repaint
        c.Emit(GameCode.Call,2); // RenderBoxes(), a VM method written from this project's source
        c.Label("panel");
        c.Color(0.06f,0.08f,0.13f,0.96f); Fill(c,24,24,300,148);
        c.Color(0.08f,0.45f,0.85f,1); Fill(c,24,24,300,52);
        c.Color(1,1,1,1); Label(c,40,42,270,30,"33e | FREE FIRE TH");
        c.Color(0.15f,0.25f,0.38f,1); Fill(c,40,92,268,56); c.Color(1,1,1,1);
        ReadState(c,1); c.Float(0); c.Emit(GameCode.Ceq); c.Branch(GameCode.Brfalse,"enabled");
        Label(c,56,110,240,30,"ESP BOX: OFF"); c.Branch(GameCode.Br,"clicked");
        c.Label("enabled"); Label(c,56,110,240,30,"ESP BOX: ON"); c.Label("clicked");
        Click(c,40,92,268,56,1,"toggleDone");
        c.Emit(GameCode.Ldloc,5); c.Call(144,1);
        c.Emit(GameCode.Ldloc,2); c.Call(147,1);
        c.Label("return"); c.Emit(GameCode.Ret); return c;
    }
    static void VectorField(Code c, int local, int field) { c.Emit(GameCode.Ldloca,local); c.Emit(GameCode.Ldfld,field); }
    static void BoxRect(Code c, int side)
    {
        c.Emit(GameCode.Ldloc,9); // left
        if (side == 3) { c.Emit(GameCode.Ldloc,12); c.Emit(GameCode.Add); c.Float(2); c.Emit(GameCode.Sub); }
        c.Emit(GameCode.Ldloc,10); // top
        if (side == 1) { c.Emit(GameCode.Ldloc,11); c.Emit(GameCode.Add); c.Float(2); c.Emit(GameCode.Sub); }
        if (side < 2) c.Emit(GameCode.Ldloc,12); else c.Float(2);
        if (side < 2) c.Float(2); else c.Emit(GameCode.Ldloc,11);
        c.New(129,4); c.Call(145,0); c.Call(148,2);
    }
    static Code Boxes()
    {
        // locals: match, list, camera, index, enemy, root, head, projected feet,
        // projected head, left, top, height, width. No game state is written.
        var c=new Code(); c.Emit(GameCode.StackSpace,(13<<16)|8); c.Label("try");
        c.Call(201,0); c.Emit(GameCode.Stloc,0); c.Emit(GameCode.Ldloc,0); c.Branch(GameCode.Brfalse,"done");
        c.Emit(GameCode.Ldloc,0); c.Call(202,1); c.Emit(GameCode.Stloc,1); c.Emit(GameCode.Ldloc,1); c.Branch(GameCode.Brfalse,"done");
        c.Call(203,0); c.Emit(GameCode.Stloc,2); c.Emit(GameCode.Ldloc,2); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"done");
        c.Emit(GameCode.Ldc_I4,0); c.Emit(GameCode.Stloc,3); c.Branch(GameCode.Br,"condition");
        c.Label("loop"); c.Emit(GameCode.Ldloc,1); c.Emit(GameCode.Ldloc,3); c.Call(204,2); c.Emit(GameCode.Isinst,Bindings.PlayerType); c.Emit(GameCode.Stloc,4);
        c.Emit(GameCode.Ldloc,4); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,4); c.Call(206,1); c.Branch(GameCode.Brtrue,"next"); // local player
        c.Emit(GameCode.Ldloc,4); c.Call(207,1); c.Emit(GameCode.Ldc_I4,0); c.Branch(GameCode.Ble,"next"); // dead
        c.Emit(GameCode.Ldloc,4); c.Emit(GameCode.Ldc_I4,0); c.Call(208,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,4); c.Emit(GameCode.Ldc_I4,1); c.Call(208,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,4); c.Call(7,1); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,4); c.Call(7,1); c.Call(209,1); c.Branch(GameCode.Brfalse,"next"); // inactive
        c.Emit(GameCode.Ldloc,4); c.Call(210,1); c.Emit(GameCode.Stloc,5); c.Emit(GameCode.Ldloc,5); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,4); c.Call(211,1); c.Emit(GameCode.Stloc,6); c.Emit(GameCode.Ldloc,6); c.Emit(GameCode.Ldnull); c.Call(0,2); c.Branch(GameCode.Brtrue,"next");
        c.Emit(GameCode.Ldloc,2); c.Emit(GameCode.Ldloc,5); c.Call(212,1); c.Call(213,2); c.Emit(GameCode.Stloc,7);
        c.Emit(GameCode.Ldloc,2); c.Emit(GameCode.Ldloc,6); c.Call(212,1); c.Call(213,2); c.Emit(GameCode.Stloc,8);
        for(int local=7;local<=8;local++) for(int field=0;field<3;field++) {
            VectorField(c,local,field); c.Call(216,1); c.Branch(GameCode.Brtrue,"next");
            VectorField(c,local,field); c.Call(217,1); c.Branch(GameCode.Brtrue,"next");
        }
        VectorField(c,7,2); c.Float(0); c.Branch(GameCode.Ble,"next");
        VectorField(c,8,2); c.Float(0); c.Branch(GameCode.Ble,"next");
        VectorField(c,8,1); VectorField(c,7,1); c.Emit(GameCode.Sub); c.Emit(GameCode.Stloc,11);
        c.Emit(GameCode.Ldloc,11); c.Float(4); c.Branch(GameCode.Ble,"next");
        c.Emit(GameCode.Ldloc,11); c.Call(214,0); c.Emit(GameCode.Conv_R4); c.Float(2); c.Emit(GameCode.Mul); c.Branch(GameCode.Bgt,"next");
        c.Emit(GameCode.Ldloc,11); c.Float(0.5f); c.Emit(GameCode.Mul); c.Emit(GameCode.Stloc,12);
        VectorField(c,8,0); VectorField(c,7,0); c.Emit(GameCode.Add); c.Float(0.5f); c.Emit(GameCode.Mul);
        c.Emit(GameCode.Ldloc,12); c.Float(0.5f); c.Emit(GameCode.Mul); c.Emit(GameCode.Sub); c.Emit(GameCode.Stloc,9);
        c.Call(214,0); c.Emit(GameCode.Conv_R4); VectorField(c,8,1); c.Emit(GameCode.Sub); c.Emit(GameCode.Stloc,10);
        // Reject boxes entirely outside the display.
        c.Emit(GameCode.Ldloc,9); c.Emit(GameCode.Ldloc,12); c.Emit(GameCode.Add); c.Float(0); c.Branch(GameCode.Blt,"next");
        c.Emit(GameCode.Ldloc,9); c.Call(215,0); c.Emit(GameCode.Conv_R4); c.Branch(GameCode.Bgt,"next");
        c.Emit(GameCode.Ldloc,10); c.Emit(GameCode.Ldloc,11); c.Emit(GameCode.Add); c.Float(0); c.Branch(GameCode.Blt,"next");
        c.Emit(GameCode.Ldloc,10); c.Call(214,0); c.Emit(GameCode.Conv_R4); c.Branch(GameCode.Bgt,"next");
        c.Color(0.05f,0.95f,1,1); for(int side=0;side<4;side++) BoxRect(c,side);
        c.Label("next"); c.Emit(GameCode.Ldloc,3); c.Emit(GameCode.Ldc_I4,1); c.Emit(GameCode.Add); c.Emit(GameCode.Stloc,3);
        c.Label("condition"); c.Emit(GameCode.Ldloc,3); c.Emit(GameCode.Ldc_I4,128); c.Branch(GameCode.Bge,"done");
        c.Emit(GameCode.Ldloc,3); c.Emit(GameCode.Ldloc,1); c.Call(205,1); c.Branch(GameCode.Blt,"loop");
        c.Branch(GameCode.Br,"done"); c.Label("endTry"); c.Label("catch"); c.Emit(GameCode.Pop);
        c.Label("done"); c.Emit(GameCode.Ret); c.Catch("try","endTry","catch","done"); return c;
    }
    public static int Main(string[] args)
    {
        string output = args.Length > 0 ? args[0] : "dist";
        Directory.CreateDirectory(output);
        var bootstrap = Bootstrap(); var menu = Menu(); var boxes = Boxes();
        string file = Path.Combine(output,"Assembly-CSharp-patch.bytes");
        using (var w = new BinaryWriter(File.Create(file),new UTF8Encoding(false)))
        {
            Bindings.Header(w); w.Write(3); bootstrap.Write(w); menu.Write(w); boxes.Write(w); Bindings.Externs(w);
            w.Write(Strings.Count); foreach (var s in Strings) w.Write(s); Bindings.Tail(w);
        }
        string hash; using (var sha = SHA256.Create()) hash = BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(file))).Replace("-","").ToLowerInvariant();
        File.WriteAllText(Path.Combine(output,"SHA256SUMS.txt"),hash+"  Assembly-CSharp-patch.bytes\n");
        Console.WriteLine("Built IFix menu: "+new FileInfo(file).Length+" bytes; SHA256 "+hash);
        Console.WriteLine("Device loading and game compatibility remain unverified."); return 0;
    }
}
