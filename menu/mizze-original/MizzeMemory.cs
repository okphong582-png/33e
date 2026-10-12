using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static bool MzGuiActive,MzMemoryBusy,MzMemoryPaused,MzMemoryTrimmed;
        public static int MzGuiThread,MzMemoryCollections,MzMemoryFaults,MzMemoryPressure;
        public static long MzMemoryBaseline,MzMemoryLast,MzMemoryPeak,MzMemoryBefore,MzMemoryAfter,MzMemoryFreed;
        public static float MzMemoryNext,MzMemoryNextCollect;
        public static void MzMemoryTrim()
        {
            if(MzRects!=null)MzClearCommands();MzClearLabels();MzRestoreSilent();
            if(MzBackgroundFrames!=null)for(int i=0;i<MzBackgroundFrames.Length;i++){var texture=MzBackgroundFrames[i];MzBackgroundFrames[i]=null;if(texture!=null)UnityEngine.Object.Destroy(texture);}
            MzBackgroundFrames=null;MzBackgroundEncoded=null;MzBackgroundLoaded=0;MzBackgroundFailed=true;MzMemoryTrimmed=true;
        }
        public static void MzMemoryComplete(long bytes,float now)
        {
            MzMemoryAfter=bytes;if(bytes<=0)return;
            MzMemoryFreed=MzMemoryBefore>bytes?MzMemoryBefore-bytes:0;MzMemoryBaseline=bytes;
            if(bytes>=805306368L&&MzMemoryFreed<16777216L){
                MzMemoryPressure++;if(bytes>=1073741824L||MzMemoryPressure>=2){MzMemoryTrim();MzMemoryPaused=true;}
            }else MzMemoryPressure=0;
            if(bytes<402653184L){
                MzMemoryPaused=false;if(MzMemoryTrimmed){MzMemoryTrimmed=false;MzBackgroundFailed=false;MzBackgroundNextLoad=now+.5f;}
            }
            MzMemoryNextCollect=now+(MzMemoryFreed<16777216L?30:8);
        }
        public static void MzMemoryStep(long bytes,float now)
        {
            if(MzGuiActive||MzBuilding||MzDrawingEsp||MzMemoryBusy||MzGuiThread==0||
               System.Threading.Thread.CurrentThread.ManagedThreadId!=MzGuiThread||bytes<=0||!MzFinite(now))return;
            MzMemoryLast=bytes;if(bytes>MzMemoryPeak)MzMemoryPeak=bytes;
            bool first=MzMemoryBaseline==0;if(first||bytes<MzMemoryBaseline)MzMemoryBaseline=bytes;
            if(bytes<402653184L&&MzMemoryPaused){MzMemoryPaused=false;MzMemoryPressure=0;MzNextEsp=0;if(MzMemoryTrimmed){MzMemoryTrimmed=false;MzBackgroundFailed=false;}}
            long growth=bytes-MzMemoryBaseline;
            if(bytes<268435456L||(!first&&growth<50331648L&&bytes<536870912L)||now<MzMemoryNextCollect)return;
            MzMemoryBusy=true;MzMemoryBefore=bytes;MzMemoryNextCollect=now+8;
            try{COW.GcUtil.Collect(ManualGCReason.MemoryUtilCollect);MzMemoryCollections++;MzMemoryComplete(GC.GetTotalMemory(false),now);}
            catch(Exception){MzMemoryFaults++;MzMemoryNextCollect=now+30;}
            finally{MzMemoryBusy=false;}
        }
        public static void MzMemoryPulse()
        {
            // Existing bootstrap callbacks only. Never collect in OnGUI or make
            // menu initialization depend on memory, authorization or thread timing.
            if(MzGuiActive||MzMemoryBusy||MzGuiThread==0)return;
            try{float now=Time.realtimeSinceStartup;if(!MzFinite(now)||now<MzMemoryNext)return;if(System.Threading.Thread.CurrentThread.ManagedThreadId!=MzGuiThread)return;MzMemoryNext=now+1;MzMemoryStep(GC.GetTotalMemory(false),now);}catch(Exception){MzMemoryFaults++;}
        }
    }
}
