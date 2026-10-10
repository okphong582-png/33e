package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;import java.util.*;
public class LocalFireReaderTest {
 static final long BASE=0x10000000,PLAYER=0x20000000,STORAGE=0x30000000,WEAPON=0x40000000,KLASS=0x50000000,MACHINE=0x60000000,STATE=0x70000000;
 static class Memory implements LocalFireReader.Memory {
  Map<Long,Long> p=new HashMap<>();Map<Long,Integer> v=new HashMap<>();boolean matches=true;
  Memory(){p.put(PLAYER+0x740,STORAGE);p.put(STORAGE+0xA0,WEAPON);p.put(WEAPON,KLASS);p.put(KLASS+0xED8,BASE+0x7479358);p.put(WEAPON+0x90,MACHINE);p.put(MACHINE+0x18,STATE);p.put(BASE+0xA741C20,0x80000000L);p.put(0x80000000L,0x90000000L);p.put(BASE+0xA72E9C8,0xA0000000L);p.put(0xA0000000L,0xB0000000L);p.put(0xB00000B8L,0xC0000000L);}
  public long pointer(long at){return p.getOrDefault(at,0L);}public int integer(long at){return v.getOrDefault(at,0);}public int byteValue(long at){return integer(at);}public boolean instance(long object,long klass){return matches&&object==WEAPON&&klass==0x90000000L;}
 }
 @Test public void localGunFiresWithoutReplicatedPri()throws Exception{var m=new Memory();m.v.put(STATE+0x10,3);assertTrue(LocalFireReader.firing(m,BASE,PLAYER));m.v.put(STATE+0x10,0);assertFalse(LocalFireReader.firing(m,BASE,PLAYER));}
 @Test public void globalBooleanModeUsesMachineFlag()throws Exception{var m=new Memory();m.v.put(0xC000191DL,1);m.v.put(MACHINE+0x20,1);assertTrue(LocalFireReader.firing(m,BASE,PLAYER));m.v.put(MACHINE+0x20,0);m.v.put(STATE+0x10,3);assertFalse(LocalFireReader.firing(m,BASE,PLAYER));}
 @Test public void alternateHandUsesAlternateWeapon()throws Exception{var m=new Memory();m.v.put(STORAGE+0x148,1);m.v.put(STATE+0x10,3);assertFalse(LocalFireReader.firing(m,BASE,PLAYER));m.p.put(STORAGE+0xA8,WEAPON);assertTrue(LocalFireReader.firing(m,BASE,PLAYER));}
 @Test public void unknownOverrideAndWrongClassNeverFire()throws Exception{var m=new Memory();m.p.put(KLASS+0xED8,BASE+0x123456);assertFalse(LocalFireReader.firing(m,BASE,PLAYER));m.p.put(KLASS+0xED8,BASE+0x7479358);m.v.put(STATE+0x10,3);m.matches=false;assertFalse(LocalFireReader.firing(m,BASE,PLAYER));}
 @Test public void nativeStateMaskExcludesIdleAndReload(){for(int state:new int[]{3,4,5,6,7,10,11,12,13,14,15,16,17})assertTrue("state "+state,LocalFireReader.gunState(state));for(int state:new int[]{-1,0,1,2,8,9,18,30})assertFalse("state "+state,LocalFireReader.gunState(state));}
 @Test public void verifiedDirectFlagOverride()throws Exception{var m=new Memory();m.p.put(KLASS+0xED8,BASE+0x7499544);m.v.put(WEAPON+0x988,1);assertTrue(LocalFireReader.firing(m,BASE,PLAYER));m.v.put(WEAPON+0x988,0);assertFalse(LocalFireReader.firing(m,BASE,PLAYER));}
}
