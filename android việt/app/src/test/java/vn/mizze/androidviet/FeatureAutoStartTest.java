package vn.mizze.androidviet;
import org.junit.Test;
import java.util.Arrays;
import static org.junit.Assert.*;
public class FeatureAutoStartTest {
    @Test public void waitsForActualBackendAndStartsEachOnlyOnce(){var policy=new FeatureAutoStart();assertEquals(0,policy.claim(0).length);assertArrayEquals(new String[]{"ShootNoReload","FastFire","RunSpeed"},policy.claim(1));assertEquals(0,policy.claim(1).length);assertTrue(Arrays.asList(policy.claim(3)).contains("TracerLine"));assertEquals(0,policy.claim(3).length);assertTrue(Arrays.asList(policy.claim(7)).contains("AimHead"));}
    @Test public void temporaryDataLossDoesNotUndoManualOff(){var policy=new FeatureAutoStart();policy.claim(7);assertEquals(0,policy.claim(0).length);assertEquals(0,policy.claim(7).length);}
    @Test public void unsupportedAimModesAreNeverAutomaticallyRequested(){var keys=Arrays.asList(new FeatureAutoStart().claim(7));assertFalse(keys.contains("SilentAim"));assertFalse(keys.contains("AimNeck"));assertFalse(keys.contains("AutoFireFloating"));assertFalse(keys.contains("AimHipAlways"));}
}
