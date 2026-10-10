package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;import java.util.*;
public class TargetLifeReaderTest {
 static final long PLAYER=0x20000,CONTROL=0x30000,NODE=0x40000;
 static class Memory implements TargetLifeReader.Memory {
  Map<Long,Long> p=new HashMap<>();int pose;boolean controller=true,node=true;
  Memory(){p.put(PLAYER+0x1D48,CONTROL);p.put(CONTROL+0x10,PLAYER);p.put(CONTROL+0x20,NODE);p.put(NODE+0x18,PLAYER);}
  public long pointer(long at){return p.getOrDefault(at,0L);}public int integer(long at){return pose;}public boolean controller(long object){return controller;}public boolean poseNode(long object){return node;}
 }
 @Test public void knockedDownTargetIsExcludedEvenWithPositiveHp()throws Exception{var m=new Memory();m.pose=8;assertFalse(TargetLifeReader.canAim(m,PLAYER));}
 @Test public void standingAndCrouchingRemainEligible()throws Exception{var m=new Memory();assertTrue(TargetLifeReader.canAim(m,PLAYER));m.pose=1;assertTrue(TargetLifeReader.canAim(m,PLAYER));}
 @Test public void targetKnockedAfterSelectionIsRejectedOnSecondRead()throws Exception{var m=new Memory();assertTrue(TargetLifeReader.canAim(m,PLAYER));m.pose=8;assertFalse(TargetLifeReader.canAim(m,PLAYER));}
 @Test public void unreadableOrWrongOwnerIsExcluded()throws Exception{var m=new Memory();m.p.put(NODE+0x18,0x50000L);assertFalse(TargetLifeReader.canAim(m,PLAYER));m=new Memory();m.node=false;assertFalse(TargetLifeReader.canAim(m,PLAYER));}
}
