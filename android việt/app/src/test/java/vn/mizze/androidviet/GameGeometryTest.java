package vn.mizze.androidviet;
import org.junit.Test;
import static org.junit.Assert.*;

public class GameGeometryTest {
    private static GameGeometry.V v(float x,float y,float z){return new GameGeometry.V(x,y,z);}
    private static void near(GameGeometry.V expected,GameGeometry.V actual){assertEquals(expected.x(),actual.x(),.0001f);assertEquals(expected.y(),actual.y(),.0001f);assertEquals(expected.z(),actual.z(),.0001f);}
    @Test public void hierarchyAppliesScaleRotationThenTranslation()throws Exception{
        var q=new GameGeometry.Q(0,0,(float)Math.sqrt(.5),(float)Math.sqrt(.5));
        var h=new GameGeometry.Hierarchy(){public GameGeometry.TRS node(int i){return i==0?new GameGeometry.TRS(v(1,0,0),new GameGeometry.Q(0,0,0,1),v(1,1,1)):new GameGeometry.TRS(v(10,5,0),q,v(2,3,1));}public int parent(int i){return i==0?1:-1;}};
        near(v(10,7,0),GameGeometry.world(h,0));
    }
    @Test(expected=java.io.IOException.class) public void cyclicHierarchyIsRejected()throws Exception{GameGeometry.world(new GameGeometry.Hierarchy(){public GameGeometry.TRS node(int i){return new GameGeometry.TRS(v(1,0,0),new GameGeometry.Q(0,0,0,1),v(1,1,1));}public int parent(int i){return 1-i;}},0);}
    @Test(expected=java.io.IOException.class) public void invalidParentIsRejected()throws Exception{GameGeometry.world(new GameGeometry.Hierarchy(){public GameGeometry.TRS node(int i){return new GameGeometry.TRS(v(1,0,0),new GameGeometry.Q(0,0,0,1),v(1,1,1));}public int parent(int i){return 9000;}},0);}
    @Test public void projectionUsesColumnMajorOrderAndRejectsBehindCamera(){
        float[] p={1,0,0,0,0,1,0,0,0,0,1,1,0,0,0,0};assertArrayEquals(new float[]{.75f,.25f},GameGeometry.project(v(1,1,2),p),.0001f);assertNull(GameGeometry.project(v(1,1,-2),p));
        float[] identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};assertArrayEquals(p,GameGeometry.multiply(p,identity),.0001f);
        float[] view=identity.clone();view[12]=-2;assertArrayEquals(new float[]{.5f,.5f},GameGeometry.project(v(2,0,2),GameGeometry.multiply(p,view)),.0001f);
    }
    @Test public void lookRotationFacesActualTargetWithoutRoll(){for(GameGeometry.V direction:new GameGeometry.V[]{v(0,0,1),v(1,0,0),v(0,0,-1),v(1,1,1)}){var q=GameGeometry.look(direction);assertNotNull(q);assertTrue(q.valid());near(direction.scale(1/direction.length()),q.rotate(v(0,0,1)));}assertNull(GameGeometry.look(v(0,0,0)));assertNull(GameGeometry.look(v(Float.NaN,0,1)));}
    @Test public void neckStaysWithinTenCentimetersOfHead(){var head=v(0,1.6f,0);var hip=v(0,.9f,0);assertTrue(head.sub(GameGeometry.neck(head,hip)).length()<=.1001f);near(head,GameGeometry.neck(head,v(0,-10,0)));}
    @Test public void combinedTriggerRequiresBothStates(){assertFalse(GameGeometry.trigger(false,true,true,true,true,false));assertTrue(GameGeometry.trigger(false,false,false,true,true,true));assertFalse(GameGeometry.trigger(false,false,false,false,true,true));assertTrue(GameGeometry.trigger(false,true,false,false,true,false));assertTrue(GameGeometry.trigger(true,false,false,true,false,false));}
    @Test public void fovUsesActualViewportAspect(){assertEquals(100,GameGeometry.centerDistance(new float[]{.6f,.5f},1000,500),.001f);assertEquals(50,GameGeometry.centerDistance(new float[]{.5f,.6f},1000,500),.001f);assertTrue(Float.isInfinite(GameGeometry.centerDistance(null,1000,500)));}
}
