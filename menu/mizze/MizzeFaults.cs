using System;
using System.IO;
using System.Text;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static bool MzGuiEntered,MzLauncherPainted;
        public static string MzStartupTrace;public static int MzStartupCount;
        public static void MzStartupLog(string stage)
        {
            if(MzStartupCount>=8)return;MzStartupCount++;
            try{MzStartupTrace=(MzStartupTrace??"Mizze R9 legacy startup\n")+DateTime.UtcNow.ToString("o")+" "+stage+"\n";string folder=Application.persistentDataPath;if(!String.IsNullOrEmpty(folder))File.WriteAllText(Path.Combine(folder,"Mizze-startup.log"),MzStartupTrace);}catch(Exception){}
        }
        public static string MzRuntimeError;
        public static bool MzErrorWritten;
        // One write after a managed fault, never disk I/O in a successful frame.
        // A native crash requires the iOS .ips report; it cannot pass through here.
        public static void MzLogFault(string stage,Exception error)
        {
            if(MzErrorWritten)return;MzErrorWritten=true;MzRuntimeError=stage+": "+error.GetType().Name;
            try{string folder=Application.persistentDataPath;if(!String.IsNullOrEmpty(folder))File.WriteAllText(Path.Combine(folder,"Mizze-error.log"),DateTime.UtcNow.ToString("o")+"\n"+stage+"\n"+error.ToString());}catch(Exception){}
        }
        public static string MzSafeName(string value)
        {
            if(value==null)return null;var result=new StringBuilder(32);int count=0;
            for(int i=0;i<value.Length&&count<24;i++){
                char c=value[i];if(c<32||c==127)continue;
                if(c>=0xD800&&c<=0xDBFF){if(i+1>=value.Length)continue;char next=value[i+1];if(next<0xDC00||next>0xDFFF)continue;result.Append(c);result.Append(next);i++;}
                else {if(c>=0xDC00&&c<=0xDFFF)continue;result.Append(c);}
                count++;
            }
            return result.ToString();
        }
    }
}
