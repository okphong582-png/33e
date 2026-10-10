using System;
using UnityEngine;
namespace COW.GamePlay
{
    public partial class SceneEditBoxSelectTool
    {
        // Screen coordinates only. Never retain native bone wrappers across samples.
        public static Vector2[] MzBonePoints;
        public static bool[] MzBoneValid;
        public static int MzVisibleLimit(){return MzSwitch[3]||MzSwitch[7]||MzSwitch[9]?6:12;}
        public static void MzSampleBone(Camera camera,int index,Transform bone)
        {
            MzBoneValid[index]=false;
            if(bone==null)return;
            Vector2 point;if(MzProject(camera,bone.position,out point)){MzBonePoints[index]=point;MzBoneValid[index]=true;}
        }
        public static void MzBoneEdge(int first,int second)
        {
            if(!MzBoneValid[first]||!MzBoneValid[second])return;
            var a=MzBonePoints[first];var b=MzBonePoints[second];MzLine(a.x,a.y,b.x,b.y,1.5f);
        }
        public static void MzSampleSkeleton(Camera camera,Player player,Vector2 head,Vector2 root)
        {
            if(MzBonePoints==null){MzBonePoints=new Vector2[11];MzBoneValid=new bool[11];}
            MzBonePoints[0]=head;MzBonePoints[1]=root;MzBoneValid[0]=true;MzBoneValid[1]=true;
            MzSampleBone(camera,2,player.NeckBone);MzSampleBone(camera,3,player.ArmBoneLeft);MzSampleBone(camera,4,player.HandBoneLeft);
            MzSampleBone(camera,5,player.ArmBoneRight);MzSampleBone(camera,6,player.HandBoneRight);MzSampleBone(camera,7,player.LegBoneLeft);
            MzSampleBone(camera,8,player.FootBoneLeft);MzSampleBone(camera,9,player.LegBoneRight);MzSampleBone(camera,10,player.FootBoneRight);
            MzBoneEdge(0,2);MzBoneEdge(2,1);MzBoneEdge(2,3);MzBoneEdge(3,4);MzBoneEdge(2,5);MzBoneEdge(5,6);
            MzBoneEdge(1,7);MzBoneEdge(7,8);MzBoneEdge(1,9);MzBoneEdge(9,10);
        }
    }
}
