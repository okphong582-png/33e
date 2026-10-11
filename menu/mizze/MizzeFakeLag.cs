namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        // Suspended after device crash reports. No frame hold hooks or Transform writes.
        public static string MzLagMessage;
        public static void MzLagStop(){if(MzSwitch!=null&&MzSwitch.Length>17)MzSwitch[17]=false;}
        public static void MzLagPulse(){MzLagStop();MzLagMessage="Fakelag tạm dừng · Ưu tiên ổn định";}
    }
}
