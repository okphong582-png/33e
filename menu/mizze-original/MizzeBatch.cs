using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        public static Mesh MzMesh;
        public static Material MzMaterial;
        public static Vector3[] MzVertices;
        public static Color[] MzVertexColors;
        public static int[] MzIndices;
        public static int[] MzQuadCounts;
        public static int MzQuadCount;
        public static bool MzBatchReady,MzBatchDirty;
        public static float MzBatchRetry;
        public static void MzBatchInit()
        {
            if(MzVertices==null){MzVertices=new Vector3[2048];MzVertexColors=new Color[2048];MzIndices=new int[3072];var indices=MzIndices;
                for(int i=0;i<512;i++){int v=i*4,t=i*6;indices[t]=v;indices[t+1]=v+1;indices[t+2]=v+2;indices[t+3]=v;indices[t+4]=v+2;indices[t+5]=v+3;}}
            if(MzMesh!=null&&MzMaterial!=null){MzBatchReady=true;return;}MzBatchReady=false;if(Time.realtimeSinceStartup<MzBatchRetry)return;MzBatchRetry=Time.realtimeSinceStartup+5;
            Material material=null;Mesh mesh=null;try{
                var shader=Shader.Find("Hidden/Internal-Colored");if(shader==null)return;
                material=new Material(shader);material.SetInt("_SrcBlend",5);material.SetInt("_DstBlend",10);material.SetInt("_Cull",0);material.SetInt("_ZWrite",0);material.SetInt("_ZTest",8);
                mesh=new Mesh();mesh.MarkDynamic();if(MzMaterial!=null)UnityEngine.Object.Destroy(MzMaterial);if(MzMesh!=null)UnityEngine.Object.Destroy(MzMesh);MzMaterial=material;MzMesh=mesh;MzBatchReady=true;MzNextEsp=0;
            }catch(Exception){if(material!=null)UnityEngine.Object.Destroy(material);if(mesh!=null)UnityEngine.Object.Destroy(mesh);MzBatchReady=false;}
        }
        public static void MzQuad(Vector3 a,Vector3 b,Vector3 c,Vector3 d)
        {
            if(!MzBatchReady||MzQuadCount>=512)return;int v=MzQuadCount++*4;var points=MzVertices;var colors=MzVertexColors;Color color=GUI.color;
            points[v]=a;points[v+1]=b;points[v+2]=c;points[v+3]=d;colors[v]=color;colors[v+1]=color;colors[v+2]=color;colors[v+3]=color;MzBatchDirty=true;
        }
        public static void MzBatchFailed()
        {
            if(MzMesh!=null)UnityEngine.Object.Destroy(MzMesh);if(MzMaterial!=null)UnityEngine.Object.Destroy(MzMaterial);MzMesh=null;MzMaterial=null;MzBatchReady=false;MzBatchRetry=Time.realtimeSinceStartup+5;MzNextEsp=0;
        }
        public static bool MzDrawBatch()
        {
            if(!MzBatchReady||MzMesh==null||MzMaterial==null)return false;if(MzQuadCount==0)return true;
            try{
                if(MzBatchDirty){MzMesh.Clear();MzMesh.SetVertices(MzVertices,0,MzQuadCount*4);MzMesh.SetColors(MzVertexColors,0,MzQuadCount*4);MzMesh.SetTriangles(MzIndices,0,MzQuadCount*6,0,true,0);MzBatchDirty=false;}
                if(!MzMaterial.SetPass(0)){MzBatchFailed();return false;}
                GL.PushMatrix();try{GL.LoadPixelMatrix(0,Screen.width,Screen.height,0);Graphics.DrawMeshNow(MzMesh,Matrix4x4.identity);}finally{GL.PopMatrix();}return true;
            }catch(Exception){MzBatchFailed();return false;}
        }
    }
}
