using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static long MzMemoryBaseline,MzMemoryLast,MzMemoryPeak,MzMemoryBefore,MzMemoryAfter,MzMemoryFreed;
        public static int MzMemoryCollections,MzMemoryFaults,MzMemoryPressure,MzMemoryTrims;
        public static float MzMemoryNext,MzMemoryNextCollect;
        public static bool MzMemoryBusy,MzMemoryPaused,MzMemoryBackgroundTrimmed;
        public static void MzMemoryTrim()
        {
            MzMemoryTrims++;if(MzRects!=null)MzClearCommands();MzClearLabels();
            MzRestoreSilent();MzRestoreWeapon();MzLagStop();
            if(MzBackgroundFrames!=null)for(int i=0;i<MzBackgroundFrames.Length;i++){var texture=MzBackgroundFrames[i];MzBackgroundFrames[i]=null;if(texture!=null)UnityEngine.Object.Destroy(texture);}
            MzBackgroundEncoded=null;MzBackgroundLoaded=0;MzBackgroundFailed=true;MzMemoryBackgroundTrimmed=true;
            if(MzRing!=null)UnityEngine.Object.Destroy(MzRing);if(MzHeadRing!=null)UnityEngine.Object.Destroy(MzHeadRing);MzRing=null;MzHeadRing=null;MzNextEsp=0;
        }
        public static void MzMemoryComplete(long after,float now)
        {
            if(!MzOnThread()||after<=0||!MzFinite(now))return;MzMemoryAfter=after;MzMemoryBaseline=after;MzMemoryFreed=MzMemoryBefore>after?MzMemoryBefore-after:0;
            MzMemoryPressure=after>=402653184L?1:0;
            // Repeated full GC cannot reclaim live objects. Back off and retain a
            // visible launcher; suspend heavy work only at sustained high usage.
            if(after>=805306368L&&MzMemoryFreed<16777216L){MzMemoryTrim();MzMemoryPaused=true;MzMemoryPressure=2;}
            else if(after<536870912L){MzMemoryPaused=false;if(MzMemoryBackgroundTrimmed){MzMemoryBackgroundTrimmed=false;MzBackgroundFailed=false;}}
            MzMemoryNextCollect=now+(MzMemoryFreed<16777216L?30:4);
        }
        public static void MzMemoryStep(long bytes,float now)
        {
            if(!MzGuiEntered||!MzOnThread()||MzInGui||MzInRender||MzBuilding||MzInSilent||MzLagBusy||MzBooting||MzMemoryBusy||bytes<=0||!MzFinite(now))return;
            MzMemoryLast=bytes;if(bytes>MzMemoryPeak)MzMemoryPeak=bytes;
            bool first=MzMemoryBaseline==0;if(first||bytes<MzMemoryBaseline)MzMemoryBaseline=bytes;
            if(bytes<536870912L&&MzMemoryPaused){MzMemoryPaused=false;MzMemoryPressure=0;MzNextEsp=0;if(MzMemoryBackgroundTrimmed){MzMemoryBackgroundTrimmed=false;MzBackgroundFailed=false;}}
            long growth=bytes-MzMemoryBaseline;
            if(bytes<268435456L||(!first&&growth<50331648L&&!MzMemoryPaused)||now<MzMemoryNextCollect)return;
            MzMemoryBusy=true;MzMemoryBefore=bytes;MzMemoryNextCollect=now+4;
            try{COW.GcUtil.Collect(ManualGCReason.MemoryUtilCollect);MzMemoryCollections++;MzMemoryComplete(GC.GetTotalMemory(false),now);}
            catch(Exception e){MzMemoryFaults++;MzMemoryNextCollect=now+30;MzLogFault("memory-collect",e);}
            finally{MzMemoryBusy=false;}
        }
        public static void MzMemoryPulse()
        {
            // Called only from the original startup/player callbacks, never from
            // OnGUI. It cannot delay initialization or require a valid license.
            if(!MzGuiEntered||MzInGui||MzMemoryBusy||!MzOnThread())return;
            float now=Time.realtimeSinceStartup;if(!MzFinite(now)||now<MzMemoryNext)return;MzMemoryNext=now+1;
            try{MzMemoryStep(GC.GetTotalMemory(false),now);}catch(Exception e){MzLogFault("memory-check",e);}
        }
    }
}
