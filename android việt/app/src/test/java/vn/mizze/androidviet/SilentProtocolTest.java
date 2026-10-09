package vn.mizze.androidviet;
import org.junit.Test;
import static org.junit.Assert.*;
import java.nio.*;
public class SilentProtocolTest {
    @Test public void packetMatchesArm64Layout(){
        byte[] bytes=SilentProtocol.packet(7,10,20,30,40,50,100,200,new GameGeometry.V(1,2,3),19);
        ByteBuffer p=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
        assertEquals(96,bytes.length);assertEquals(SilentProtocol.MAGIC,p.getLong(0));
        assertEquals(1,p.getInt(8));assertEquals(96,p.getInt(12));assertEquals(7,p.getLong(16));
        assertEquals(10,p.getLong(24));assertEquals(50,p.getLong(56));assertEquals(100,p.getLong(64));assertEquals(200,p.getLong(72));
        assertEquals(1,p.getFloat(80),0);assertEquals(3,p.getFloat(88),0);assertEquals(19,p.getInt(92));
    }
    private byte[] response(long sequence,int ready,int error){return ByteBuffer.allocate(32).order(ByteOrder.LITTLE_ENDIAN).putLong(SilentProtocol.MAGIC).putLong(sequence).putLong(12).putInt(ready).putInt(error).array();}
    @Test public void readyNeedsMatchingAcknowledgement(){var reply=SilentProtocol.reply(response(7,1,0),7);assertTrue(reply.ready());assertEquals(12,reply.redirects());assertFalse(SilentProtocol.reply(response(7,0,4),7).ready());}
    @Test public void rejectsStaleAndInconsistentAcknowledgement(){
        assertThrows(IllegalArgumentException.class,()->SilentProtocol.reply(response(6,1,0),7));
        assertThrows(IllegalArgumentException.class,()->SilentProtocol.reply(response(7,1,4),7));
        assertThrows(IllegalArgumentException.class,()->SilentProtocol.reply(new byte[31],7));
    }
}
