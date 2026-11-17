using System;
using System.IO;
using IFix;
using Mono.Cecil;

sealed class StartupConfigure : GenerateConfigure
{
    public override bool TryGetConfigure(string tag, MethodReference method, out int flag)
    {
        flag = 0;
        return tag == "IFix.IFixAttribute" && method.DeclaringType.FullName == "COW.COWGameEntry"
            && method.Name == "Update" && method.Parameters.Count == 0;
    }
    public override bool IsNewMethod(MethodReference method) { return false; }
    public override bool IsNewClass(TypeReference type) { return false; }
    public override bool isNewField(FieldReference field) { return false; }
    public override void AddNewMethod(MethodReference method) { }
    public override void AddNewClass(TypeReference type) { }
    public override void AddNewField(FieldReference field) { }
}

static class StartupCompiler
{
    public static void Main(string[] args)
    {
        var game = AssemblyDefinition.ReadAssembly(args[0]);
        var resolver = (BaseAssemblyResolver)game.MainModule.AssemblyResolver;
        resolver.AddSearchDirectory(Path.GetDirectoryName(Path.GetFullPath(args[0])));
        var core = AssemblyDefinition.ReadAssembly(args[1]);
        var translator = new CodeTranslator();
        translator.Process(game, core, new StartupConfigure(), ProcessMode.Patch);
        translator.Serialize(args[2]);
    }
}
