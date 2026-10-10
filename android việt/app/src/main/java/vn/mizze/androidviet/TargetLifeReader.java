package vn.mizze.androidviet;
/** Knockdown is pose 8 in the verified Android Player state machine. Unknown state is excluded. */
final class TargetLifeReader {
 interface Memory {long pointer(long at)throws Exception;int integer(long at)throws Exception;boolean controller(long object)throws Exception;boolean poseNode(long object)throws Exception;}
 private static boolean valid(long p){return p>=0x10000&&p<0x0001000000000000L&&(p&7)==0;}
 static boolean canAim(Memory m,long player)throws Exception{
  long control=m.pointer(player+0x1D48);if(!valid(control)||!m.controller(control)||m.pointer(control+0x10)!=player)return false;
  long node=m.pointer(control+0x20);if(!valid(node)||!m.poseNode(node)||m.pointer(node+0x18)!=player)return false;
  int pose=m.integer(node+0x10);
  return pose>=0&&pose<39&&pose!=8&&m.pointer(player+0x1D48)==control&&m.pointer(control+0x20)==node;
 }
}
