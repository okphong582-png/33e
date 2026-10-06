using System;
using System.Runtime.InteropServices;

namespace Mizze.CSharpMenu
{
    // UI-only API. All game reads and feature updates remain in the native backend.
    public interface IMenuBackend
    {
        bool Ready { get; }
        bool GetFlag(string key);
        void SetFlag(string key, bool value);
        float GetValue(string key);
        void SetValue(string key, float value);
    }

    public sealed class NativeBackend : IMenuBackend
    {
        [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl)]
        private static extern int MizzeMenuBridgeVersion();
        [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern int MizzeMenuGetFlag(string key);
        [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern int MizzeMenuSetFlag(string key, int value);
        [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern float MizzeMenuGetValue(string key);
        [DllImport("__Internal", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern int MizzeMenuSetValue(string key, float value);
        private bool ready;
        public bool Ready { get { return ready; } }
        public NativeBackend()
        {
            try { ready = MizzeMenuBridgeVersion() == 1; }
            catch (DllNotFoundException) { ready = false; }
            catch (EntryPointNotFoundException) { ready = false; }
        }
        public bool GetFlag(string key) { return ready && MizzeMenuGetFlag(key) == 1; }
        public void SetFlag(string key, bool value)
        {
            if (!ready || MizzeMenuSetFlag(key, value ? 1 : 0) != 0)
                throw new InvalidOperationException("Backend chưa nhận cài đặt");
        }
        public float GetValue(string key) { return ready ? MizzeMenuGetValue(key) : float.NaN; }
        public void SetValue(string key, float value)
        {
            if (!ready || MizzeMenuSetValue(key, value) != 0)
                throw new InvalidOperationException("Backend chưa nhận giá trị");
        }
    }
}
