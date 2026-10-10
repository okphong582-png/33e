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
    public void Emit(int code, int operand = 0) { Instructions.Add(new[] { code, operand }); }
    public void Label(string name) { labels.Add(name, Instructions.Count); }
    public void Branch(int code, string label) { branches.Add(Tuple.Create(Instructions.Count, label)); Emit(code); }
    public void Call(int originalId, int arguments) { Emit(175, (arguments << 16) | Bindings.External[originalId]); }
    public void New(int originalId, int arguments) { Emit(106, (arguments << 16) | Bindings.External[originalId]); }
    public void Float(float value) { Emit(3, BitConverter.ToInt32(BitConverter.GetBytes(value), 0)); }
    public void Rect(float x, float y, float width, float height) { Float(x); Float(y); Float(width); Float(height); New(129, 4); }
    public void Color(float r, float g, float b, float a) { Float(r); Float(g); Float(b); Float(a); New(146, 4); Call(147, 1); }
    public void Write(BinaryWriter w)
    {
        foreach (var b in branches) Instructions[b.Item1][1] = labels[b.Item2] - b.Item1;
        w.Write(Instructions.Count);
        foreach (var i in Instructions) { w.Write(i[0]); w.Write(i[1]); }
        w.Write(0); // exception handlers
    }
}

static class Program
{
    static readonly List<string> Strings = new List<string>();
    const string Driver = "__33e_menu_driver";
    static void Text(Code c, string s) { int id = Strings.IndexOf(s); if (id < 0) { id = Strings.Count; Strings.Add(s); } c.Emit(16, id); }
    static void Label(Code c, float x, float y, float w, float h, string s) { c.Rect(x,y,w,h); Text(c,s); c.Call(149,2); }
    static void Fill(Code c, float x, float y, float w, float h) { c.Rect(x,y,w,h); c.Call(145,0); c.Call(148,2); }
    static void ReadState(Code c, int field) { c.Emit(95,4); c.Emit(38,field); }
    static void Toggle(Code c, int field)
    {
        c.Emit(95,4); ReadState(c,field); c.Float(0); c.Emit(67); c.Emit(52); c.Emit(4,field);
        c.Emit(20,1); c.Call(10,1); c.Emit(20,4); c.Call(12,2);
    }
    static void Click(Code c, float x, float y, float w, float h, int field, string end)
    {
        c.Emit(20,0); c.Call(131,1); c.Emit(180,1); c.Branch(165,end); // MouseUp only
        c.Rect(x,y,w,h); c.Emit(176,3); c.Emit(95,3);
        c.Emit(20,0); c.Call(130,1); c.Call(132,2); c.Branch(62,end);
        Toggle(c,field); c.Emit(20,0); c.Call(138,1); c.Label(end);
    }
    static Code Bootstrap(bool stealth)
    {
        var c = new Code(); c.Emit(57,(2<<16)|8);
        c.Emit(28,0); c.Call(stealth ? 200 : 57,1); c.Emit(176,0); // preserve the original getter result
        Text(c,Driver); c.Call(2,1); c.Emit(176,1);
        c.Emit(20,1); c.Emit(17); c.Call(0,2); c.Branch(62,"component");
        Text(c,Driver); c.New(9,1); c.Emit(176,1);
        c.Emit(20,1); c.Call(10,1); c.Float(0); c.Float(1); c.Float(1); c.New(11,3); c.Call(12,2);
        c.Label("component"); c.Emit(20,1); c.Emit(126,Bindings.SceneType); c.Emit(89); c.Call(218,2);
        c.Emit(17); c.Call(0,2); c.Branch(62,"done");
        c.Emit(20,1); c.Emit(126,Bindings.SceneType); c.Emit(89); c.Call(13,2); c.Emit(161);
        c.Emit(20,1); c.Call(14,1);
        c.Label("done"); c.Emit(20,0); c.Emit(136,1); return c;
    }
    static Code Menu()
    {
        var c = new Code(); c.Emit(57,(6<<16)|8);
        c.Emit(28,0); c.Emit(17); c.Call(0,2); c.Branch(62,"self"); c.Emit(136);
        c.Label("self"); c.Call(93,0); c.Emit(176,0); c.Emit(20,0); c.Branch(115,"event"); c.Emit(136);
        c.Label("event"); c.Emit(28,0); c.Call(7,1); c.Emit(176,1);
        c.Emit(20,1); c.Emit(17); c.Call(0,2); c.Branch(115,"return");
        c.Emit(20,1); c.Call(94,1); Text(c,Driver); c.Call(95,2); c.Branch(115,"return");
        c.Emit(20,1); c.Call(10,1); c.Call(54,1); c.Emit(176,4);
        c.Call(142,0); c.Emit(176,2);
        c.Call(141,0); c.Emit(176,5); c.Call(143,0); c.Call(144,1);
        ReadState(c,1); c.Float(0); c.Emit(67); c.Branch(115,"panel");
        c.Emit(20,0); c.Call(131,1); c.Emit(180,7); c.Branch(165,"panel"); // Repaint
        c.Emit(151,3); // RenderBoxes(), a VM method written from this project's source
        c.Label("panel");
        c.Color(0.06f,0.08f,0.13f,0.96f); Fill(c,24,24,300,148);
        c.Color(0.08f,0.45f,0.85f,1); Fill(c,24,24,300,52);
        c.Color(1,1,1,1); Label(c,40,42,270,30,"33e | FREE FIRE TH");
        c.Color(0.15f,0.25f,0.38f,1); Fill(c,40,92,268,56); c.Color(1,1,1,1);
        ReadState(c,1); c.Float(0); c.Emit(67); c.Branch(62,"enabled");
        Label(c,56,110,240,30,"ESP BOX: OFF"); c.Branch(42,"clicked");
        c.Label("enabled"); Label(c,56,110,240,30,"ESP BOX: ON"); c.Label("clicked");
        Click(c,40,92,268,56,1,"toggleDone");
        c.Emit(20,5); c.Call(144,1);
        c.Emit(20,2); c.Call(147,1);
        c.Label("return"); c.Emit(136); return c;
    }
    static void VectorField(Code c, int local, int field) { c.Emit(95,local); c.Emit(38,field); }
    static void BoxRect(Code c, int side)
    {
        c.Emit(20,9); // left
        if (side == 3) { c.Emit(20,12); c.Emit(174); c.Float(2); c.Emit(96); }
        c.Emit(20,10); // top
        if (side == 1) { c.Emit(20,11); c.Emit(174); c.Float(2); c.Emit(96); }
        if (side < 2) c.Emit(20,12); else c.Float(2);
        if (side < 2) c.Float(2); else c.Emit(20,11);
        c.New(129,4); c.Call(145,0); c.Call(148,2);
    }
    static Code Boxes()
    {
        // locals: match, list, camera, index, enemy, root, head, projected feet,
        // projected head, left, top, height, width. No game state is written.
        var c=new Code(); c.Emit(57,(13<<16)|8);
        c.Call(201,0); c.Emit(176,0); c.Emit(20,0); c.Branch(62,"done");
        c.Emit(20,0); c.Call(202,1); c.Emit(176,1); c.Emit(20,1); c.Branch(62,"done");
        c.Call(203,0); c.Emit(176,2); c.Emit(20,2); c.Emit(17); c.Call(0,2); c.Branch(115,"done");
        c.Emit(180,0); c.Emit(176,3); c.Branch(42,"condition");
        c.Label("loop"); c.Emit(20,1); c.Emit(20,3); c.Call(204,2); c.Emit(142,Bindings.PlayerType); c.Emit(176,4);
        c.Emit(20,4); c.Emit(17); c.Call(0,2); c.Branch(115,"next");
        c.Emit(20,4); c.Call(206,1); c.Branch(115,"next"); // local player
        c.Emit(20,4); c.Call(207,1); c.Emit(180,0); c.Branch(132,"next"); // dead
        c.Emit(20,4); c.Emit(180,0); c.Call(208,2); c.Branch(115,"next");
        c.Emit(20,4); c.Emit(180,1); c.Call(208,2); c.Branch(115,"next");
        c.Emit(20,4); c.Call(7,1); c.Emit(17); c.Call(0,2); c.Branch(115,"next");
        c.Emit(20,4); c.Call(7,1); c.Call(209,1); c.Branch(62,"next"); // inactive
        c.Emit(20,4); c.Call(210,1); c.Emit(176,5); c.Emit(20,5); c.Emit(17); c.Call(0,2); c.Branch(115,"next");
        c.Emit(20,4); c.Call(211,1); c.Emit(176,6); c.Emit(20,6); c.Emit(17); c.Call(0,2); c.Branch(115,"next");
        c.Emit(20,2); c.Emit(20,5); c.Call(212,1); c.Call(213,2); c.Emit(176,7);
        c.Emit(20,2); c.Emit(20,6); c.Call(212,1); c.Call(213,2); c.Emit(176,8);
        for(int local=7;local<=8;local++) for(int field=0;field<3;field++) {
            VectorField(c,local,field); c.Call(216,1); c.Branch(115,"next");
            VectorField(c,local,field); c.Call(217,1); c.Branch(115,"next");
        }
        VectorField(c,7,2); c.Float(0); c.Branch(132,"next");
        VectorField(c,8,2); c.Float(0); c.Branch(132,"next");
        VectorField(c,8,1); VectorField(c,7,1); c.Emit(96); c.Emit(176,11);
        c.Emit(20,11); c.Float(4); c.Branch(132,"next");
        c.Emit(20,11); c.Call(214,0); c.Emit(52); c.Float(2); c.Emit(40); c.Branch(46,"next");
        c.Emit(20,11); c.Float(0.5f); c.Emit(40); c.Emit(176,12);
        VectorField(c,8,0); VectorField(c,7,0); c.Emit(174); c.Float(0.5f); c.Emit(40);
        c.Emit(20,12); c.Float(0.5f); c.Emit(40); c.Emit(96); c.Emit(176,9);
        c.Call(214,0); c.Emit(52); VectorField(c,8,1); c.Emit(96); c.Emit(176,10);
        // Reject boxes entirely outside the display.
        c.Emit(20,9); c.Emit(20,12); c.Emit(174); c.Float(0); c.Branch(130,"next");
        c.Emit(20,9); c.Call(215,0); c.Emit(52); c.Branch(46,"next");
        c.Emit(20,10); c.Emit(20,11); c.Emit(174); c.Float(0); c.Branch(130,"next");
        c.Emit(20,10); c.Call(214,0); c.Emit(52); c.Branch(46,"next");
        c.Color(0.05f,0.95f,1,1); for(int side=0;side<4;side++) BoxRect(c,side);
        c.Label("next"); c.Emit(20,3); c.Emit(180,1); c.Emit(174); c.Emit(176,3);
        c.Label("condition"); c.Emit(20,3); c.Emit(180,128); c.Branch(173,"done");
        c.Emit(20,3); c.Emit(20,1); c.Call(205,1); c.Branch(130,"loop");
        c.Label("done"); c.Emit(136); return c;
    }
    public static int Main(string[] args)
    {
        string output = args.Length > 0 ? args[0] : "dist";
        Directory.CreateDirectory(output);
        var bootstrap = Bootstrap(false); var menu = Menu(); var stealth = Bootstrap(true); var boxes = Boxes();
        string file = Path.Combine(output,"Assembly-CSharp-patch.bytes");
        using (var w = new BinaryWriter(File.Create(file),new UTF8Encoding(false)))
        {
            Bindings.Header(w); w.Write(4); bootstrap.Write(w); menu.Write(w); stealth.Write(w); boxes.Write(w); Bindings.Externs(w);
            w.Write(Strings.Count); foreach (var s in Strings) w.Write(s); Bindings.Tail(w);
        }
        string hash; using (var sha = SHA256.Create()) hash = BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(file))).Replace("-","").ToLowerInvariant();
        File.WriteAllText(Path.Combine(output,"SHA256SUMS.txt"),hash+"  Assembly-CSharp-patch.bytes\n");
        Console.WriteLine("Built IFix menu: "+new FileInfo(file).Length+" bytes; SHA256 "+hash);
        Console.WriteLine("Device loading and game compatibility remain unverified."); return 0;
    }
}
