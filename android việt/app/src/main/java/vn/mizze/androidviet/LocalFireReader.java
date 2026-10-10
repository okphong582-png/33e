package vn.mizze.androidviet;
/** Mirrors the verified local Player.IsFiring path without calling code inside the game. */
final class LocalFireReader {
 private static boolean valid(long p){return p>=0x10000&&p<0x0001000000000000L&&(p&7)==0;}
 interface Memory {long pointer(long at)throws Exception;int integer(long at)throws Exception;int byteValue(long at)throws Exception;boolean instance(long object,long klass)throws Exception;}
 static boolean firing(Memory m,long base,long player)throws Exception{
  long storage=m.pointer(player+0x740);if(!valid(storage))return false;
  int alternate=m.byteValue(storage+0x148);if(alternate>1)return false;
  long weapon=m.pointer(storage+(alternate==1?0xA8:0xA0));
  long cache=m.pointer(base+0xA741C20L),weaponClass=valid(cache)?m.pointer(cache):0;
  if(!valid(weapon)||!m.instance(weapon,weaponClass))return false;
  long klass=m.pointer(weapon),getter=m.pointer(klass+0xED8);boolean active;
  if(getter==base+0x7479358L){
   long machine=m.pointer(weapon+0x90);if(!valid(machine))return false;
   long globalsCache=m.pointer(base+0xA72E9C8L),globals=m.pointer(globalsCache),statics=m.pointer(globals+0xB8);
   if(m.byteValue(statics+0x191D)!=0)active=m.byteValue(machine+0x20)!=0;
   else{long state=m.pointer(machine+0x18);if(!valid(state))return false;active=gunState(m.integer(state+0x10));}
  }else if(getter==base+0x7499544L)active=m.byteValue(weapon+0x988)!=0;
  else return false; // Unverified virtual overrides are never treated as firing.
  return active&&m.pointer(player+0x740)==storage&&m.byteValue(storage+0x148)==alternate
    &&m.pointer(storage+(alternate==1?0xA8:0xA0))==weapon;
 }
 static boolean gunState(int state){int index=state-3;return index>=0&&index<13&&((0x1F9F>>>index)&1)!=0||(state&~1)==16;}
}
