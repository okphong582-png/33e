using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static long MzMemoryBaseline,MzMemoryLast,MzMemoryPeak,MzMemoryBefore,MzMemoryAfter;
        public static int MzMemoryCollections,MzMemoryFaults;
        public static float MzMemoryNext,MzMemoryNextCollect;
        public static bool MzMemoryBusy;
        public static void MzMemoryStep(long bytes,float now)
        {
            if(!MzOnThread()||MzMemoryBusy||bytes<=0||!MzFinite(now))return;
            MzMemoryLast=bytes;if(bytes>MzMemoryPeak)MzMemoryPeak=bytes;
            if(MzMemoryBaseline==0||bytes<MzMemoryBaseline)MzMemoryBaseline=bytes;
            // This is process-wide managed memory. Trigger only on measured pressure/growth;
            // the native game collector temporarily enables GC and restores its mode.
            if(bytes<268435456L||(bytes-MzMemoryBaseline<67108864L&&bytes<536870912L)||now<MzMemoryNextCollect)return;
            MzMemoryNextCollect=now+15;MzMemoryBusy=true;MzMemoryBefore=bytes;
            try{COW.GcUtil.Collect(ManualGCReason.MemoryUtilCollect);MzMemoryCollections++;MzMemoryAfter=GC.GetTotalMemory(false);if(MzMemoryAfter>0)MzMemoryBaseline=MzMemoryAfter;}
            catch(Exception e){MzMemoryFaults++;MzMemoryNextCollect=now+30;MzLogFault("memory-collect",e);}
            finally{MzMemoryBusy=false;}
        }
        public static void MzMemoryPulse()
        {
            if(!MzOnThread()||MzMemoryBusy)return;float now=Time.realtimeSinceStartup;if(!MzFinite(now)||now<MzMemoryNext)return;MzMemoryNext=now+2;
            try{MzMemoryStep(GC.GetTotalMemory(false),now);}catch(Exception e){MzLogFault("memory-check",e);}
        }
    }
}
