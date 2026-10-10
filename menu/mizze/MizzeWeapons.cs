using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static PlayerAttributes MzWeaponAttributes;
        public static bool MzFastApplied,MzAmmoApplied,MzOldFreeAmmo,MzOldNoReload;
        public static float MzOldFireScale,MzAppliedFireScale,MzFireMultiplier,MzNextWeapon;
        public static string MzWeaponMessage;
        public static void MzRestoreWeapon()
        {
            var attributes=MzWeaponAttributes;
            try{if(attributes!=null&&MzFastApplied&&attributes.FireIntervalScale==MzAppliedFireScale)attributes.FireIntervalScale=MzOldFireScale;}catch(Exception){}
            try{if(attributes!=null&&MzAmmoApplied){if(attributes.IsAmmoFree)attributes.IsAmmoFree=MzOldFreeAmmo;if(attributes.ShootNoReload)attributes.ShootNoReload=MzOldNoReload;}}catch(Exception){}
            MzWeaponAttributes=null;MzFastApplied=false;MzAmmoApplied=false;
        }
        public static void MzWeaponPoll()
        {
            if(!MzSwitch[15]&&!MzSwitch[16]){if(MzWeaponAttributes!=null||MzFastApplied||MzAmmoApplied)MzRestoreWeapon();MzWeaponMessage="Bật chức năng khi đang trong trận";return;}
            if(!MzAuthorized()){MzRestoreWeapon();MzWeaponMessage="Cần khóa hợp lệ";return;}
            float now=Time.realtimeSinceStartup;if(now<MzNextWeapon)return;MzNextWeapon=now+.1f;
            try{
                var match=COW.GameFacade.CurrentMatch();var player=COW.GameFacade.GetLocalPlayerOrObServer();
                if(match==null||player==null||!player.IsLocalPlayer()||player.CurHP<=0){MzRestoreWeapon();MzWeaponMessage="Chờ nhân vật trong trận";return;}
                var attributes=player.get_Attributes();if(attributes==null){MzRestoreWeapon();MzWeaponMessage="Chưa có thuộc tính vũ khí";return;}
                if(attributes!=MzWeaponAttributes){MzRestoreWeapon();MzWeaponAttributes=attributes;}
                if(MzSwitch[15]){
                    float current=attributes.FireIntervalScale;
                    // A native buff update becomes the new baseline, never multiply our own value again.
                    if(!MzFastApplied||current!=MzAppliedFireScale){MzOldFireScale=current;MzFastApplied=false;}
                    if(MzFinite(MzOldFireScale)&&MzOldFireScale>0&&MzOldFireScale<=10){
                        float value=MzOldFireScale/Mathf.Clamp(MzFireMultiplier,1,3);if(value<.05f)value=.05f;
                        MzAppliedFireScale=value;MzFastApplied=true;if(current!=value)attributes.FireIntervalScale=value;
                    }
                }else if(MzFastApplied){if(attributes.FireIntervalScale==MzAppliedFireScale)attributes.FireIntervalScale=MzOldFireScale;MzFastApplied=false;}
                if(MzSwitch[16]){
                    if(!MzAmmoApplied){MzOldFreeAmmo=attributes.IsAmmoFree;MzOldNoReload=attributes.ShootNoReload;MzAmmoApplied=true;}
                    if(!attributes.IsAmmoFree)attributes.IsAmmoFree=true;if(!attributes.ShootNoReload)attributes.ShootNoReload=true;
                }else if(MzAmmoApplied){if(attributes.IsAmmoFree)attributes.IsAmmoFree=MzOldFreeAmmo;if(attributes.ShootNoReload)attributes.ShootNoReload=MzOldNoReload;MzAmmoApplied=false;}
                MzWeaponMessage=MzSwitch[15]&&!MzFastApplied?"Hệ số vũ khí chưa hợp lệ":"Đã áp dụng trên nhân vật hiện tại";
            }catch(Exception){MzRestoreWeapon();MzWeaponMessage="Không đọc được vũ khí hiện tại";}
        }
        public static void MzWeaponPanel(float x,float y)
        {
            MzToggle(15,x,y,"Bắn nhanh");MzToggle(16,x,y+44,"Không nạp đạn");
            MzTint(.94f,.96f,.98f,MzOpenAnim);MzText(x,y+104,354,"Tốc độ bắn");
            for(int i=0;i<3;i++){float rate=i==0?1.5f:i==1?2:3;bool active=MzFireMultiplier==rate;MzTint(.10f,active?.32f:.17f,active?.25f:.19f,.65f*MzOpenAnim);MzFill(x+i*120,y+139,114,38,11);MzTint(.9f,1,.96f,MzOpenAnim);MzCenter(x+i*120,y+139,114,38,i==0?"1,5×":i==1?"2×":"3×");if(MzTap(x+i*120,y+139,114,38)){MzFireMultiplier=rate;MzNextWeapon=0;MzWeaponPoll();}}
            MzTint(.79f,.85f,.91f,MzOpenAnim);MzMessage(x,y+194,354,68,MzWeaponMessage??"Chỉ áp dụng khi đang trong trận");
            MzTint(.65f,.73f,.81f,MzOpenAnim);MzMessage(x,y+264,354,56,"Fakelag: chưa được hỗ trợ trên bản iOS này");
        }
    }
}
