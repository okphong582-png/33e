using System;
using System.Text;
using System.Security.Cryptography;
using System.Globalization;
using UnityEngine;
using UnityEngine.Networking;
using SimpleJSON;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static string MzKeyHash,MzDeviceHash,MzLicenseMessage;
        public static UnityWebRequest MzRequest;
        public static TouchScreenKeyboard MzKeyboard;
        public static int MzRequestStage;
        public static float MzRequestStarted,MzLeaseDeadline,MzNextRefresh;
        public static bool MzClaimAttempted,MzCanClaim;
        public static string MzHash(string value){byte[] digest=SHA256.Create().ComputeHash(Encoding.UTF8.GetBytes(value));return BitConverter.ToString(digest).Replace("-","").ToLowerInvariant();}
        public static void MzLicenseInit()
        {
            string device=SystemInfo.deviceUniqueIdentifier;if(String.IsNullOrEmpty(device)||device=="n/a"){MzLicenseMessage="Không đọc được mã thiết bị";return;}
            MzDeviceHash=MzHash("mizze-ifix-device-v1:"+device);MzKeyHash=PlayerPrefs.GetString("Mizze.IFix.KeyHash","");MzLicenseMessage="Nhập khóa Mizze để kích hoạt";if(MzHex(MzKeyHash)){MzCanClaim=false;MzBeginRead();}
        }
        public static bool MzHex(string s){if(s==null||s.Length!=64)return false;for(int i=0;i<s.Length;i++){char c=s[i];if(!(c>='0'&&c<='9')&&!(c>='a'&&c<='f'))return false;}return true;}
        public static bool MzAuthorized(){return MzLeaseDeadline>0&&Time.realtimeSinceStartup<MzLeaseDeadline;}
        public static string MzKeyUrl(){return "https://appchatai-313e3-default-rtdb.firebaseio.com/licensesV4/"+MzKeyHash+".json";}
        public static void MzStartRequest(UnityWebRequest request,int stage){MzRequest=request;MzRequestStage=stage;MzRequestStarted=Time.realtimeSinceStartup;request.timeout=6;request.SetRequestHeader("Cache-Control","no-cache, no-store");request.SendWebRequest();}
        public static void MzBeginRead(){if(MzRequest!=null||!MzHex(MzKeyHash)||!MzHex(MzDeviceHash))return;MzLicenseMessage="Đang kiểm tra khóa…";MzStartRequest(UnityWebRequest.Get(MzKeyUrl()),1);}
        public static bool MzMissing(JSONNode n){return System.Object.ReferenceEquals(n,null)||n.IsNull||n.Tag==JSONNodeType.None;}
        public static void MzReject(string message){MzLeaseDeadline=0;MzLicenseMessage=message;MzRestoreSilent();MzNextRefresh=Time.realtimeSinceStartup+5;}
        public static void MzCheckRecord(string json,string serverDate)
        {
            var record=JSONNode.Parse(json);if(MzMissing(record)){MzReject("Khóa không tồn tại hoặc đã bị xóa");return;}if(!record.IsObject){MzReject("Dữ liệu khóa sai định dạng object");return;}
            var protocol=record["protocol"];var enabled=record["enabled"];var expires=record["expiresAt"];
            if(MzMissing(protocol)||!protocol.IsNumber||protocol.AsDouble!=4||MzMissing(enabled)||!enabled.IsBoolean||MzMissing(expires)||!expires.IsNumber){MzReject("Dữ liệu khóa không hợp lệ");return;}
            if(!enabled.AsBool){MzReject("Khóa đã bị khóa");return;}if(String.IsNullOrEmpty(serverDate)){MzReject("Không xác minh được giờ máy chủ");return;}
            DateTime clock;if(!DateTime.TryParse(serverDate,CultureInfo.InvariantCulture,DateTimeStyles.AdjustToUniversal|DateTimeStyles.AssumeUniversal,out clock)){MzReject("Giờ máy chủ không hợp lệ");return;}
            double now=(clock-new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc)).TotalMilliseconds+1000+(Time.realtimeSinceStartup-MzRequestStarted)*1000;
            double expiry=expires.AsDouble;if(Double.IsNaN(expiry)||Double.IsInfinity(expiry)||expiry<=now){MzReject("Khóa đã hết hạn");return;}
            var locked=record["lock"];
            if(!MzMissing(locked)){if(!locked.IsObject){MzReject("Trường lock sai định dạng. Quản trị viên cần kiểm tra khóa");return;}var until=locked["until"];var notice=locked["message"];if(MzMissing(until)||!until.IsNumber||Double.IsNaN(until.AsDouble)||Double.IsInfinity(until.AsDouble)||until.AsDouble<0||MzMissing(notice)||!notice.IsString||notice.Value.Length>500){MzReject("Trường lock thiếu until/message hợp lệ");return;}if(until.AsDouble==0||until.AsDouble>now){MzReject(notice.Value.Length>0?notice.Value:"Tài khoản đã bị khóa");return;}}
            var binding=record["binding"];
            if(MzMissing(binding)){
                MzLeaseDeadline=0;if(!MzCanClaim||MzClaimAttempted){MzReject("Khóa chưa gắn máy. Nhập lại để kích hoạt");return;}MzClaimAttempted=true;
                string body="{\"deviceHash\":\""+MzDeviceHash+"\",\"version\":1,\"claimedAt\":{\".sv\":\"timestamp\"}}";var request=UnityWebRequest.Put(MzKeyUrl().Replace(".json","/binding.json"),Encoding.UTF8.GetBytes(body));request.SetRequestHeader("Content-Type","application/json");request.SetRequestHeader("if-match","null_etag");MzLicenseMessage="Đang gắn khóa với máy…";MzStartRequest(request,2);return;
            }
            var device=binding["deviceHash"];var version=binding["version"];var claimed=binding["claimedAt"];
            if(MzMissing(device)||!device.IsString||!MzHex(device.Value)||MzMissing(version)||!version.IsNumber||version.AsDouble!=1||MzMissing(claimed)||!claimed.IsNumber||Double.IsNaN(claimed.AsDouble)||Double.IsInfinity(claimed.AsDouble)||claimed.AsDouble<=0){MzReject("Dữ liệu gắn máy không hợp lệ");return;}
            if(device.Value!=MzDeviceHash){MzReject("Khóa đã gắn máy khác. Quản trị viên cần gỡ máy cũ");return;}
            MzLeaseDeadline=Time.realtimeSinceStartup+Mathf.Clamp((float)((expiry-now)/1000),0,30);MzNextRefresh=Time.realtimeSinceStartup+10;MzLicenseMessage="Đã xác thực khóa Mizze";PlayerPrefs.SetString("Mizze.IFix.KeyHash",MzKeyHash);
        }
        public static void MzLicensePoll()
        {
            try {
                if(MzKeyboard!=null){var status=MzKeyboard.status;if(status==TouchScreenKeyboard.Status.Done){string key=MzKeyboard.text;MzKeyboard=null;if(MzRequest!=null){MzRequest.Dispose();MzRequest=null;}MzKeyHash="";MzLeaseDeadline=0;MzRestoreSilent();if(key==null||key.Trim().Length<8||key.Trim().Length>128)MzReject("Khóa phải có 8–128 ký tự");else{MzKeyHash=MzHash(key.Trim().ToUpperInvariant());MzClaimAttempted=false;MzCanClaim=true;MzBeginRead();}}else if(status==TouchScreenKeyboard.Status.Canceled||status==TouchScreenKeyboard.Status.LostFocus)MzKeyboard=null;}
                var request=MzRequest;if(request!=null&&request.isDone){int stage=MzRequestStage;long code=request.responseCode;string error=request.error;string data=request.downloadHandler==null?null:request.downloadHandler.text;string date=request.GetResponseHeader("Date");MzRequest=null;request.Dispose();if(stage==2){MzBeginRead();return;}if(code!=200||error!=null||data==null||data.Length>32768){MzReject(code==401||code==403?"Máy chủ từ chối khóa. Kiểm tra Rules":"Không kết nối được máy chủ khóa");return;}MzCheckRecord(data,date);}
                if(MzKeyboard==null&&MzRequest==null&&MzHex(MzKeyHash)&&Time.realtimeSinceStartup>=MzNextRefresh)MzBeginRead();
            }catch(Exception){if(MzRequest!=null){MzRequest.Dispose();MzRequest=null;}MzReject("Lỗi xác thực khóa. Thử lại");}
        }
        public static void MzKeyPanel(float x,float y)
        {
            MzTint(.075f,.075f,.085f,MzOpenAnim);MzFill(x,y,354,70,12);MzTint(.54f,1,.83f,MzOpenAnim);MzText(x+14,y+7,327,"KHÓA MIZZE");MzTint(.94f,.96f,.98f,MzOpenAnim);MzText(x+14,y+35,327,MzAuthorized()?"Đã kích hoạt":"Chưa kích hoạt");
            MzTint(.79f,.84f,.88f,MzOpenAnim);MzMessage(x+8,y+84,338,70,MzLicenseMessage??"Nhập khóa để bật ESP và ngắm");
            MzTint(.08f,.27f,.20f,MzOpenAnim);MzFill(x,y+166,354,46,12);MzTint(.83f,1,.91f,MzOpenAnim);MzCenter(x,y+166,354,46,MzRequest!=null?"Đang kiểm tra…":"Nhập khóa Mizze");if(MzRequest==null&&MzTap(x,y+166,354,46))MzKeyboard=TouchScreenKeyboard.Open("",TouchScreenKeyboardType.ASCIICapable,false,false,true,false,"Khóa Mizze",128);
            MzTint(.10f,.10f,.12f,MzOpenAnim);MzFill(x,y+224,354,42,11);MzTint(.92f,.95f,.98f,MzOpenAnim);MzCenter(x,y+224,354,42,"Kiểm tra lại khóa");if(MzTap(x,y+224,354,42))MzBeginRead();
            MzTint(.17f,.07f,.09f,MzOpenAnim);MzFill(x,y+278,354,38,10);MzTint(1,.73f,.79f,MzOpenAnim);MzCenter(x,y+278,354,38,"Đăng xuất");if(MzTap(x,y+278,354,38)){if(MzRequest!=null){MzRequest.Dispose();MzRequest=null;}MzKeyHash="";MzLeaseDeadline=0;PlayerPrefs.DeleteKey("Mizze.IFix.KeyHash");MzLicenseMessage="Đã đăng xuất";MzRestoreSilent();}
        }
    }
}
