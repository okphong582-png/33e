using System;
namespace UnityEngine.Networking
{
    public class DownloadHandler {public string text {get{return "";}}}
    public class UnityWebRequest:IDisposable
    {
        public static UnityWebRequest Get(string u){return null;}public static UnityWebRequest Put(string u,byte[] b){return null;}
        public UnityWebRequestAsyncOperation SendWebRequest(){return null;}public void SetRequestHeader(string k,string v){}public string GetResponseHeader(string k){return null;}
        public int timeout {set{}}public bool isDone {get{return false;}}public long responseCode {get{return 0;}}public string error {get{return null;}}public DownloadHandler downloadHandler {get{return null;}}public void Dispose(){}
    }
    public class UnityWebRequestAsyncOperation {}
}
