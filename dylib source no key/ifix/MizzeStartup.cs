using System;
using System.Reflection;
using UnityEngine;

[assembly: AssemblyVersion("0.86.0.518")]

namespace GCommon
{
    // Binding declaration. IFix resolves the real method in the game.
    public static class IL2CPPOptimize
    {
        public static int GetPositionIndex(MethodBase method) { return -1; }
    }
}

namespace COW
{
    public class COWGameEntry
    {
        private void Update()
        {
            var flags = BindingFlags.Instance | BindingFlags.Public |
                BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
            Type entryType = typeof(COWGameEntry);
            MethodInfo original = entryType.GetMethod("Update", flags);
            Type wrapperType = entryType.Assembly.GetType("IFix.ILFixDynamicMethodWrapper");
            FieldInfo wrapperField = wrapperType == null ? null : wrapperType.GetField(
                "wrapperArray", BindingFlags.Public | BindingFlags.Static);
            Array table = wrapperField == null ? null : wrapperField.GetValue(null) as Array;
            int slot = original == null ? -1 : GCommon.IL2CPPOptimize.GetPositionIndex(original);
            if (slot < 0 || table == null || slot >= table.Length) return;
            object redirect = table.GetValue(slot);
            if (redirect == null) return;

            table.SetValue(null, slot);
            bool signaled = false;
            try
            {
                try { original.Invoke(this, null); }
                catch (TargetInvocationException error) { throw error.InnerException ?? error; }
                try
                {
                    var marker = new GameObject("__mizze_nokey_vn_startup_ed95");
                    UnityEngine.Object.DontDestroyOnLoad(marker);
                    signaled = true;
                }
                catch (Exception) { }
            }
            finally
            {
                // A second attempt is allowed only while our slot is still vacant.
                if (!signaled && object.ReferenceEquals(wrapperField.GetValue(null), table)
                    && table.GetValue(slot) == null)
                    table.SetValue(redirect, slot);
            }
        }
    }
}
