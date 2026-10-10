package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;
public class PriValuesTest {
 @Test public void firingIgnoresAdjacentByte(){assertEquals(1,PriValues.width(21));assertTrue(PriValues.firing(PriValues.decode(21,new byte[]{2,(byte)0xFF})));}
 @Test public void scopeIgnoresAdjacentByte(){assertEquals(1,PriValues.width(12));assertEquals(0,PriValues.decode(12,new byte[]{0,(byte)0xFF}));assertEquals(1,PriValues.decode(12,new byte[]{1,0}));}
 @Test public void hpRetainsUnsignedSixteenBits(){assertEquals(2,PriValues.width(0));assertEquals(500,PriValues.decode(0,new byte[]{(byte)0xF4,1}));}
 @Test public void idleAndReloadAreNotFiring(){assertFalse(PriValues.firing(0));assertFalse(PriValues.firing(1));assertFalse(PriValues.firing(3));}
 @Test public void teamRetainsUnsignedByte(){assertEquals(255,PriValues.decode(34,new byte[]{(byte)255,1}));}
}
