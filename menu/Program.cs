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
    static Code Bootstrap()
    {
        var c = new Code(); c.Emit(57,(2<<16)|8);
        c.Emit(28,0); c.Call(57,1); c.Emit(176,0); // preserve the original getter result
        Text(c,Driver); c.Call(2,1); c.Emit(176,1);
        c.Emit(20,1); c.Emit(17); c.Call(0,2); c.Branch(62,"done");
        Text(c,Driver); c.New(9,1); c.Emit(176,1);
        c.Emit(20,1); c.Call(10,1); c.Float(0); c.Float(0); c.Float(1); c.New(11,3); c.Call(12,2);
        c.Emit(20,1); c.Emit(126,Bindings.SceneType); c.Emit(89); c.Call(13,2); c.Emit(161);
        c.Emit(20,1); c.Call(14,1);
        c.Label("done"); c.Emit(20,0); c.Emit(136,1); return c;
    }
    static Code Menu()
    {
        var c = new Code(); c.Emit(57,(5<<16)|8);
        c.Emit(28,0); c.Emit(17); c.Call(0,2); c.Branch(62,"self"); c.Emit(136);
        c.Label("self"); c.Call(93,0); c.Emit(176,0); c.Emit(20,0); c.Branch(115,"event"); c.Emit(136);
        c.Label("event"); c.Emit(28,0); c.Call(7,1); c.Emit(176,1);
        c.Emit(20,1); c.Emit(17); c.Call(0,2); c.Branch(115,"return");
        c.Emit(20,1); c.Call(94,1); Text(c,Driver); c.Call(95,2); c.Branch(115,"return");
        c.Emit(20,1); c.Call(10,1); c.Call(54,1); c.Emit(176,4);
        c.Call(142,0); c.Emit(176,2);
        ReadState(c,0); c.Float(0); c.Emit(67); c.Branch(115,"expanded");
        c.Color(0.08f,0.45f,0.85f,0.96f); Fill(c,24,24,170,56);
        c.Color(1,1,1,1); Label(c,40,40,140,30,"MENU 33e - OPEN");
        Click(c,24,24,170,56,0,"openDone"); c.Branch(42,"restore");
        c.Label("expanded"); c.Color(0.06f,0.08f,0.13f,0.96f); Fill(c,24,24,360,250);
        c.Color(0.08f,0.45f,0.85f,1); Fill(c,24,24,360,64);
        c.Color(1,1,1,1); Label(c,40,44,220,30,"33e | C# MENU"); Label(c,305,44,72,30,"HIDE");
        Label(c,40,104,320,30,"IFix menu loaded"); Label(c,40,136,320,30,"UI demo - tap the button below");
        c.Color(0.15f,0.25f,0.38f,1); Fill(c,40,180,328,56); c.Color(1,1,1,1);
        ReadState(c,1); c.Float(0); c.Emit(67); c.Branch(62,"demoOn");
        Label(c,56,198,296,30,"DEMO: OFF"); c.Branch(42,"drawn");
        c.Label("demoOn"); Label(c,56,198,296,30,"DEMO: ON"); c.Label("drawn");
        Click(c,292,24,92,64,0,"hideDone"); Click(c,40,180,328,56,1,"demoDone");
        c.Label("restore"); c.Emit(20,2); c.Call(147,1);
        c.Label("return"); c.Emit(136); return c;
    }
    public static int Main(string[] args)
    {
        string output = args.Length > 0 ? args[0] : "dist";
        Directory.CreateDirectory(output);
        var bootstrap = Bootstrap(); var menu = Menu();
        string file = Path.Combine(output,"Assembly-CSharp-patch.bytes");
        using (var w = new BinaryWriter(File.Create(file),new UTF8Encoding(false)))
        {
            Bindings.Header(w); w.Write(2); bootstrap.Write(w); menu.Write(w); Bindings.Externs(w);
            w.Write(Strings.Count); foreach (var s in Strings) w.Write(s); Bindings.Tail(w);
        }
        string hash; using (var sha = SHA256.Create()) hash = BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(file))).Replace("-","").ToLowerInvariant();
        File.WriteAllText(Path.Combine(output,"SHA256SUMS.txt"),hash+"  Assembly-CSharp-patch.bytes\n");
        Console.WriteLine("Built IFix menu: "+new FileInfo(file).Length+" bytes; SHA256 "+hash);
        Console.WriteLine("Device loading and game compatibility remain unverified."); return 0;
    }
}
