package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;
public class FrameFreshnessTest {
 @Test public void acceptsCurrentOrientation(){assertTrue(FrameFreshness.accepts(100,120,2,2,1920,1080,1920,1080));}
 @Test public void rejectsFrameFromBeforeRotation(){assertFalse(FrameFreshness.accepts(100,120,1,2,1080,1920,1920,1080));}
 @Test public void rejectsWrongViewportEvenWithCurrentEpoch(){assertFalse(FrameFreshness.accepts(100,120,2,2,1080,1920,1920,1080));}
 @Test public void rejectsStaleAndFutureSamples(){assertFalse(FrameFreshness.accepts(100,350,2,2,1920,1080,1920,1080));assertFalse(FrameFreshness.accepts(130,120,2,2,1920,1080,1920,1080));}
}
