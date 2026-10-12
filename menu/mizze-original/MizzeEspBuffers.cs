using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static string[] MzDistanceLabels,MzNameLabels;
        public static Player[] MzNameOwners;
        public static float[] MzNameNext;
        public static int MzLabelCount;
        public static void MzLabelsInit()
        {
            if(MzDistanceLabels!=null)return;
            MzDistanceLabels=new string[501];for(int i=0;i<501;i++)MzDistanceLabels[i]=i.ToString()+" m";
            MzNameLabels=new string[16];MzNameOwners=new Player[16];MzNameNext=new float[16];
        }
        public static string MzCachedName(Player p,int slot)
        {
            if(slot<0||slot>=16)return null;
            if(!System.Object.ReferenceEquals(MzNameOwners[slot],p)||MzEspSampleStarted>=MzNameNext[slot]){
                string name=p.NickName;if(name!=null&&name.Length>24)name=name.Substring(0,24);
                MzNameLabels[slot]=name;MzNameOwners[slot]=p;MzNameNext[slot]=MzEspSampleStarted+1;
            }
            if(MzLabelCount<=slot)MzLabelCount=slot+1;return MzNameLabels[slot];
        }
        public static void MzTrimLabels(int count)
        {
            for(int i=count;i<MzLabelCount;i++){MzNameOwners[i]=null;MzNameLabels[i]=null;MzNameNext[i]=0;}if(count<MzLabelCount)MzLabelCount=count;
        }
        public static void MzClearLabels(){MzTrimLabels(0);
        }
        public static void MzDrawSolidFallback()
        {
            var saved=GUI.matrix;var color=GUI.color;
            try{
                int count=MzQuadCount;if(count>96)count=96;
                for(int i=0;i<count;i++){
                    int v=i*4;var a=MzVertices[v];var b=MzVertices[v+1];var d=MzVertices[v+3];
                    float dx=b.x-a.x,dy=b.y-a.y,hx=d.x-a.x,hy=d.y-a.y;
                    float width=Mathf.Sqrt(dx*dx+dy*dy),height=Mathf.Sqrt(hx*hx+hy*hy);
                    if(!MzFinite(width)||!MzFinite(height)||width<=0||height<=0)continue;
                    GUI.color=MzVertexColors[v];
                    if(dy==0&&hx==0){GUI.matrix=MzIdentity;GUI.DrawTexture(new Rect(a.x,a.y,width,height),MzWhite);}
                    else {GUI.matrix=Matrix4x4.TRS(a,Quaternion.Euler(0,0,Mathf.Atan2(dy,dx)*57.29578f),new Vector3(1,1,1));GUI.DrawTexture(new Rect(0,0,width,height),MzWhite);}
                }
            }finally{GUI.matrix=saved;GUI.color=color;}
        }
    }
}
