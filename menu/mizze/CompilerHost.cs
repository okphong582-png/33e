using System;
using System.IO;
using System.Linq;
using Mono.Cecil;
using IFix;

sealed class MizzeConfigure : GenerateConfigure
{
    public override bool TryGetConfigure(string tag,MethodReference m,out int flag)
    {
        flag=0;return tag=="IFix.IFixAttribute" &&
            ((m.DeclaringType.FullName=="COW.GamePlay.SceneEditBoxSelectTool" && m.Name=="OnGUI") ||
             (m.DeclaringType.FullName=="COW.GamePlay.Player" && (m.Name=="get_LastAimingInfoFromWeapon" || m.Name=="NeedRunHighFrame")) ||
             (m.DeclaringType.FullName=="COW.GameFacade" && m.Name=="get_UIModelRole"));
    }
    public override bool IsNewMethod(MethodReference m) {return m.DeclaringType.FullName=="COW.GamePlay.SceneEditBoxSelectTool" && m.Name.StartsWith("Mz");}
    public override bool IsNewClass(TypeReference t) {return false;}
    public override bool isNewField(FieldReference f) {return f!=null && f.DeclaringType.FullName=="COW.GamePlay.SceneEditBoxSelectTool" && f.Name.StartsWith("Mz");}
    public override void AddNewMethod(MethodReference m) {}
    public override void AddNewClass(TypeReference t) {}
    public override void AddNewField(FieldReference f) {}
}
static class CompilerHost
{
    public static int Main(string[] args)
    {
        try
        {
            var assembly=AssemblyDefinition.ReadAssembly(args[0]);
            var resolver=(BaseAssemblyResolver)assembly.MainModule.AssemblyResolver;
            resolver.AddSearchDirectory(Path.GetDirectoryName(Path.GetFullPath(args[0])));
            resolver.AddSearchDirectory(Path.GetDirectoryName(Path.GetFullPath(args[1])));
            var core=AssemblyDefinition.ReadAssembly(args[1]);var translator=new CodeTranslator();
            translator.Process(assembly,core,new MizzeConfigure(),ProcessMode.Patch);
            translator.Serialize(args[2]);
            var map=(System.Collections.Generic.Dictionary<MethodReference,int>)typeof(CodeTranslator).GetField("methodToId",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).GetValue(translator);
            File.WriteAllLines(Path.Combine(Path.GetDirectoryName(args[2]),"methods.tsv"),map.OrderBy(p=>p.Value).Select(p=>p.Value+"\t"+p.Key.DeclaringType.FullName+"\t"+p.Key.Name));
            return 0;
        }
        catch(Exception e) {Console.Error.WriteLine(e);return 1;}
    }
}
