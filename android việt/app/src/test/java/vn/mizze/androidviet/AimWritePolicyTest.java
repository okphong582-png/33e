package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;
public class AimWritePolicyTest {
 @Test public void silentNeverFallsBackToCameraEvenWithBothPointsSelected(){assertFalse(AimWritePolicy.normal(true,true,true));assertFalse(AimWritePolicy.normal(true,false,true));assertFalse(AimWritePolicy.normal(false,true,true));}
 @Test public void noModeMeansNoWrites(){assertFalse(AimWritePolicy.normal(false,false,false));assertFalse(AimWritePolicy.normal(false,false,true));}
 @Test public void normalHeadAndNeckRemainAvailable(){assertTrue(AimWritePolicy.normal(true,false,false));assertTrue(AimWritePolicy.normal(false,true,false));}
}
