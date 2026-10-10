package vn.mizze.androidviet;
import java.nio.*;
/** Versioned little-endian wire format shared with native/SilentNative.cpp. */
final class SilentProtocol {
    static final long MAGIC=0x31544e454c49534dL;
    static byte[] packet(long sequence,long base,long game,long match,long local,long target,long sample,long lease,GameGeometry.V point,int flags){
        return ByteBuffer.allocate(96).order(ByteOrder.LITTLE_ENDIAN).putLong(MAGIC).putInt(1).putInt(96)
            .putLong(sequence).putLong(base).putLong(game).putLong(match).putLong(local).putLong(target).putLong(sample).putLong(lease)
            .putFloat(point==null?0:point.x()).putFloat(point==null?0:point.y()).putFloat(point==null?0:point.z()).putInt(flags).array();
    }
    record Reply(long redirects,boolean ready,int error){}
    static Reply reply(byte[] bytes,long sequence){
        if(bytes.length!=32)throw new IllegalArgumentException("Native reply length");
        ByteBuffer data=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
        if(data.getLong()!=MAGIC||data.getLong()!=sequence)throw new IllegalArgumentException("Native reply identity");
        long redirects=data.getLong();int ready=data.getInt(),error=data.getInt();
        if(redirects<0||ready<0||ready>1||error<0||error>5||ready==1&&error!=0)throw new IllegalArgumentException("Native reply state");
        return new Reply(redirects,ready==1,error);
    }
}
