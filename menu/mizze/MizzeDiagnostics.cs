using System;
using System.IO;
using System.Text;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static string[] MzSessionLines;
        public static int MzSessionCount,MzSessionHead;
        public static float MzNextSession;
        public static void MzSessionPulse()
        {
            if(!MzOnThread()||(!MzSwitch[0]&&!MzSwitch[17])){MzNextSession=0;return;}
            float now=Time.realtimeSinceStartup;if(!MzFinite(now))return;
            if(MzNextSession==0){MzNextSession=now+30;return;}if(now<MzNextSession)return;MzNextSession=now+30;
            try {
                if(MzSessionLines==null)MzSessionLines=new string[12];
                MzSessionLines[MzSessionHead]="t="+((int)now).ToString()+" managed="+GC.GetTotalMemory(false).ToString()+" commands="+MzCommandCount.ToString()+" gcAutoOff="+COW.GcUtil.AutoGcDisabled.ToString()+" gcCount="+COW.GcUtil.GcCount.ToString()+" menuGC="+MzMemoryCollections.ToString()+" gcBefore="+MzMemoryBefore.ToString()+" gcAfter="+MzMemoryAfter.ToString()+" backgrounds="+MzBackgroundLoaded.ToString()+" samplesFailed="+MzSampleFailures.ToString()+" drawFailed="+MzEspFailures.ToString()+" flVisible="+MzLagButtonVisible().ToString()+" flPaints="+MzLagUiPaints.ToString()+" flX="+((int)MzLagX).ToString()+" flY="+((int)MzLagY).ToString()+" lagTail="+MzLagTailCalls.ToString()+" lagWrites="+MzLagWrites.ToString();
                MzSessionHead=(MzSessionHead+1)%12;if(MzSessionCount<12)MzSessionCount++;
                var log=new StringBuilder(2048);log.Append("Mizze R2 session diagnostics; managed memory only, no native crash stack\n");
                int start=(MzSessionHead-MzSessionCount+12)%12;for(int i=0;i<MzSessionCount;i++){log.Append(MzSessionLines[(start+i)%12]);log.Append('\n');}
                string folder=Application.persistentDataPath;if(!String.IsNullOrEmpty(folder))File.WriteAllText(Path.Combine(folder,"Mizze-session.log"),log.ToString());
            }catch(Exception){}
        }
    }
}
