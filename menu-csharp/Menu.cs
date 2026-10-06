using UnityEngine;

namespace Mizze.CSharpMenu
{
    // Unity source component, not a drop-in IFix .bytes file.
    // A matching game IFix build must supply the host/bootstrap binding.
    public sealed class Menu : MonoBehaviour
    {
        public IMenuBackend Backend;
        private bool open = true;
        private int tab;
        private Vector2 scroll;
        private Rect panel = new Rect(24, 64, 340, 430);
        private readonly Color mint = new Color(0.46f, 0.86f, 0.73f, 1);
        private readonly Color coal = new Color(0.08f, 0.1f, 0.12f, 0.97f);
        private readonly string[] tabs = { "Aim", "ESP", "Khác" };
        private void Awake() { if (Backend == null) Backend = new NativeBackend(); }
        private void OnGUI()
        {
            Color color = GUI.color, background = GUI.backgroundColor;
            try
            {
                if (!open)
                {
                    GUI.backgroundColor = mint;
                    if (GUI.Button(new Rect(18, 70, 66, 44), "Menu")) open = true;
                    return;
                }
                panel.width = Mathf.Min(340, Screen.width - 16);
                panel.height = Mathf.Min(430, Screen.height - 16);
                panel.x = Mathf.Clamp(panel.x, 0, Screen.width - panel.width);
                panel.y = Mathf.Clamp(panel.y, 0, Screen.height - panel.height);
                GUI.backgroundColor = coal;
                panel = GUI.Window(73129, panel, DrawWindow, "MIZZE");
            }
            finally { GUI.color = color; GUI.backgroundColor = background; }
        }
        private void DrawWindow(int id)
        {
            if (GUI.Button(new Rect(panel.width - 50, 3, 44, 30), "×")) open = false;
            GUILayout.Space(10);
            tab = GUILayout.Toolbar(tab, tabs, GUILayout.Height(40));
            bool enabled = GUI.enabled;
            try
            {
                if (Backend == null || !Backend.Ready)
                {
                    GUILayout.Label("Chưa kết nối backend");
                    return;
                }
                scroll = GUILayout.BeginScrollView(scroll);
                try
                {
                    if (tab == 0)
                    {
                        Flag("Silent Aim", "SilentAim"); Flag("AimKill", "AutoFire");
                        Flag("Aimlag", "AimLag"); Flag("Đổi súng AimKill", "AutoSwapWeapon");
                        Number("FOV", Backend.GetFlag("SilentAim") ? "SilentFovSize" : "FovSize", 5, 48);
                        Number("Tỷ lệ HS", "SilentHeadPercent", 0, 100);
                        Flag("Vòng FOV", "ShowFov"); Flag("Bắn nhanh", "FastFire");
                        Flag("Không nạp đạn", "ShootNoReload");
                    }
                    else if (tab == 1)
                    {
                        Flag("Khung", "Box"); Flag("Khung 3D", "Box3D");
                        Flag("Tên", "Name"); Flag("Máu", "Health");
                        Flag("Dây", "Line"); Flag("Khoảng cách", "Dis");
                        Flag("Xương", "Skeleton"); Number("Tầm ESP", "ESPMaxDistance", 50, 500);
                    }
                    else
                    {
                        Flag("Ghost", "GhostMode"); Flag("Fly", "Fly");
                        Number("Độ cao", "FlyHeight", 1, 6);
                        Flag("FakeLag", "FakeLag"); Flag("Speed", "RunSpeed");
                        Number("Tốc độ", "RunSpeedValue", 0.1f, 30);
                        Flag("Ẩn nút nổi", "HideFeatureButtons");
                    }
                }
                finally { GUILayout.EndScrollView(); }
            }
            finally { GUI.enabled = enabled; GUI.DragWindow(new Rect(0, 0, panel.width - 56, 32)); }
        }
        private void Flag(string title, string key)
        {
            bool current = Backend.GetFlag(key);
            GUI.backgroundColor = current ? mint : coal;
            if (GUILayout.Button((current ? "[X]  " : "[ ]  ") + title, GUILayout.Height(42)))
                Backend.SetFlag(key, !current);
        }
        private void Number(string title, string key, float min, float max)
        {
            float current = Backend.GetValue(key);
            if (float.IsNaN(current) || float.IsInfinity(current)) return;
            GUILayout.Label(title + "  " + current.ToString("0.#"));
            float next = GUILayout.HorizontalSlider(current, min, max, GUILayout.Height(26));
            if (Mathf.Abs(next - current) > 0.001f) Backend.SetValue(key, next);
        }
    }
}
