package vn.mizze.androidviet;
import org.junit.Test;import static org.junit.Assert.*;
public class AimRotationControllerTest {
 static class Memory implements AimRotationController.Memory {
  AimRotationController.Identity id=new AimRotationController.Identity(42,99,0x20000,0x30000,0x40000);
  GameGeometry.Q normal=new GameGeometry.Q(0,0,0,1),aux=normal;int writes;long last;
  public AimRotationController.Identity identity(){return id;}
  public GameGeometry.Q read(long at){return at==0x30614?normal:aux;}
  public void write(long at,GameGeometry.Q q){assertEquals(id.player()+0x628,at);last=at;aux=q;writes++;}
 }
 @Test public void writesAuxiliaryWithoutMovingNormal()throws Exception{var m=new Memory();var p=new AimRotationController();var q=GameGeometry.look(new GameGeometry.V(1,0,1));p.apply(m,true,q);assertEquals(q,m.aux);assertEquals(new GameGeometry.Q(0,0,0,1),m.normal);assertEquals(0x30628,m.last);}
 @Test public void offRestoresCurrentCameraOnlyIfLastWriteStillOwned()throws Exception{var m=new Memory();var p=new AimRotationController();p.apply(m,true,GameGeometry.look(new GameGeometry.V(1,0,1)));m.normal=GameGeometry.look(new GameGeometry.V(-1,0,1));p.apply(m,false,null);assertEquals(m.normal,m.aux);}
 @Test public void doesNotOverwriteGameReset()throws Exception{var m=new Memory();var p=new AimRotationController();p.apply(m,true,GameGeometry.look(new GameGeometry.V(1,0,1)));m.aux=m.normal;p.apply(m,false,null);assertEquals(1,m.writes);}
 @Test public void processChangeNeverRestoresOldObject()throws Exception{var m=new Memory();var p=new AimRotationController();p.apply(m,true,GameGeometry.look(new GameGeometry.V(1,0,1)));m.id=new AimRotationController.Identity(43,100,0x50000,0x60000,0x40000);p.apply(m,false,null);assertEquals(1,m.writes);}
 @Test public void rejectedIdentityPreventsWrites()throws Exception{var m=new Memory();m.id=null;new AimRotationController().apply(m,true,GameGeometry.look(new GameGeometry.V(1,0,1)));assertEquals(0,m.writes);}
}
