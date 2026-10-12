using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static PlayerAttributes MzExtrasOwner;
        public static bool MzRunApplied,MzFireApplied;
        public static float MzRunOriginal,MzRunWritten,MzRunBase,MzFireOriginal,MzFireWritten,MzExtrasNext;
        public static int MzRunLevel,MzFireLevel;
        public static string MzExtrasError;
        public static float MzRunFactor(){return MzRunLevel==0?1.25f:MzRunLevel==1?1.5f:2f;}
        public static float MzFireFactor(){return MzFireLevel==0?1.5f:MzFireLevel==1?2f:3f;}
        public static void MzExtrasRestore()
        {
            var a=MzExtrasOwner;
            if(a!=null){
                try{if(MzRunApplied&&a.ForceSetRunAndDashSpeed==MzRunWritten)a.ForceSetRunAndDashSpeed=MzRunOriginal;}catch(Exception){}
                try{if(MzFireApplied&&a.FireIntervalScale==MzFireWritten)a.FireIntervalScale=MzFireOriginal;}catch(Exception){}
            }
            MzExtrasOwner=null;MzRunApplied=false;MzFireApplied=false;MzRunBase=0;
        }
        public static void MzExtrasPoll()
        {
            if(MzSwitch==null||!MzAuthorized()||(!MzSwitch[15]&&!MzSwitch[16])){MzExtrasRestore();return;}
            float now=Time.realtimeSinceStartup;if(now<MzExtrasNext)return;MzExtrasNext=now+.1f;
            try{
                if(COW.GameFacade.CurrentMatch()==null){MzExtrasRestore();return;}
                var p=COW.GameFacade.GetLocalPlayerOrObServer();
                if(p==null||!p.IsLocalPlayer()||p.CurHP<=0){MzExtrasRestore();return;}
                var a=p.Attributes;if(a==null){MzExtrasRestore();return;}
                if(!System.Object.ReferenceEquals(a,MzExtrasOwner)){MzExtrasRestore();MzExtrasOwner=a;}
                // This native field is read by GetSpeedByType only for Run/Dash.
                // Capture actual speed before applying the override; never compound it.
                if(MzSwitch[15]){
                    float current=a.ForceSetRunAndDashSpeed;
                    if(!MzRunApplied||current!=MzRunWritten){
                        MzRunOriginal=current;MzRunBase=a.GetSpeedByType(PIOEKCEKPNI.Run);
                        if(!MzFinite(MzRunBase)||MzRunBase<=0){MzRunApplied=false;MzExtrasError="Chưa đọc được tốc độ chạy";return;}
                    }
                    MzRunWritten=MzRunBase*MzRunFactor();a.ForceSetRunAndDashSpeed=MzRunWritten;MzRunApplied=true;
                }else if(MzRunApplied){if(a.ForceSetRunAndDashSpeed==MzRunWritten)a.ForceSetRunAndDashSpeed=MzRunOriginal;MzRunApplied=false;}
                if(MzSwitch[16]){
                    float current=a.FireIntervalScale;
                    if(!MzFireApplied||current!=MzFireWritten)MzFireOriginal=current;
                    if(!MzFinite(MzFireOriginal)||MzFireOriginal<=0){MzFireApplied=false;MzExtrasError="Chưa đọc được nhịp bắn";return;}
                    MzFireWritten=Mathf.Clamp(MzFireOriginal/MzFireFactor(),.05f,10);a.FireIntervalScale=MzFireWritten;MzFireApplied=true;
                }else if(MzFireApplied){if(a.FireIntervalScale==MzFireWritten)a.FireIntervalScale=MzFireOriginal;MzFireApplied=false;}
                MzExtrasError=null;
            }catch(Exception){MzExtrasRestore();MzExtrasNext=now+2;MzExtrasError="Tạm dừng · Không đọc được người chơi";}
        }
        public static void MzExtrasPanel(float x,float y)
        {
            MzToggle(15,x,y,"Chạy nhanh");MzToggle(16,x,y+108,"Bắn nhanh");
            for(int i=0;i<3;i++){
                bool selected=MzRunLevel==i;MzTint(1,1,1,(selected?.19f:.06f)*MzOpenAnim);MzFill(x+i*120,y+49,114,38,19);
                MzTint(.93f,.97f,1,MzOpenAnim);MzCenter(x+i*120,y+49,114,38,i==0?"×1,25":i==1?"×1,5":"×2");
                if(MzTap(x+i*120,y+49,114,38)){MzRunLevel=i;MzExtrasNext=0;MzExtrasPoll();}
                selected=MzFireLevel==i;MzTint(1,1,1,(selected?.19f:.06f)*MzOpenAnim);MzFill(x+i*120,y+157,114,38,19);
                MzTint(.93f,.97f,1,MzOpenAnim);MzCenter(x+i*120,y+157,114,38,i==0?"×1,5":i==1?"×2":"×3");
                if(MzTap(x+i*120,y+157,114,38)){MzFireLevel=i;MzExtrasNext=0;MzExtrasPoll();}
            }
            MzTint(.72f,.79f,.86f,MzOpenAnim);MzMessage(x+8,y+222,338,80,MzExtrasError??"Tác dụng trong trận. Máy chủ có thể giới hạn tốc độ.");
        }
    }
}
