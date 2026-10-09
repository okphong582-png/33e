package vn.mizze.androidviet;

import java.io.IOException;
import java.util.Objects;

/** Only validated PlayerAttributes data fields are writable. Never patches executable code. */
final class RootFeatureController {
    record Identity(int pid,long start,long base,long match,long player,long attributes,long klass){}
    record Config(boolean noReload,boolean fastFire,boolean speed,float speedValue){
        static Config off(){return new Config(false,false,false,6);}
        Config { if(!Float.isFinite(speedValue))speedValue=6;speedValue=Math.max(.1f,Math.min(30,speedValue)); }
    }
    interface Memory {
        Identity identity() throws Exception;
        int read(long address,int size) throws Exception;
        void write(long address,int size,int bits) throws Exception;
    }
    private static final class Patch {
        boolean changed;int original,written;
        void forget(){changed=false;}
    }
    private Identity saved;
    private final Patch reload=new Patch(),fire=new Patch(),run=new Patch();
    boolean changed(){return reload.changed||fire.changed||run.changed;}
    private void forget(){reload.forget();fire.forget();run.forget();saved=null;}
    private void update(Memory memory,Identity identity,Patch patch,int offset,int size,boolean enabled,int kind,float value)throws Exception{
        if(!enabled&&!patch.changed)return;
        long address=identity.attributes()+offset;
        int current=memory.read(address,size);float number=Float.intBitsToFloat(current);
        if(kind==0?current<0||current>1:!Float.isFinite(number)||number<(kind==1?.05f:0)||number>(kind==1?16:1000))throw new IOException("Invalid field value");
        int desired;
        if(enabled){
            if(!patch.changed)patch.original=current;
            desired=kind==0?1:Float.floatToRawIntBits(kind==1?Math.max(.05f,Float.intBitsToFloat(patch.original)*.5f):value);
        }else{
            if(current==patch.original){patch.forget();return;}
            // A changed game value belongs to the game. Restore only the last value this helper wrote.
            if(current!=patch.written){patch.forget();return;}
            desired=patch.original;
        }
        if(current==desired)return;
        if(!Objects.equals(identity,memory.identity()))throw new IOException("Player context changed");
        patch.written=desired;patch.changed=true;
        memory.write(address,size,desired);
        // Confirmation uses a second read. Failed/short writes remain retryable and never report applied.
        if(memory.read(address,size)!=desired)throw new IOException("Read-back mismatch");
        if(!enabled)patch.forget();
    }
    String update(Memory memory,Config config)throws Exception{
        Identity identity=memory.identity();if(identity==null)throw new IOException("Missing validated PlayerAttributes");
        if(saved!=null&&!saved.equals(identity))forget(); // Never restore through a different PID, match or object.
        saved=identity;
        update(memory,identity,reload,0x111,1,config.noReload(),0,0);
        update(memory,identity,fire,0x258,4,config.fastFire(),1,0);
        update(memory,identity,run,0x3C8,4,config.speed(),2,config.speedValue());
        return (config.noReload()?"Không nạp đạn: giá trị đã xác nhận":"Không nạp đạn: tắt")+" · "+
            (config.fastFire()?"Bắn nhanh: giá trị đã xác nhận":"Bắn nhanh: tắt")+" · "+
            (config.speed()?"Speed: giá trị đã xác nhận "+config.speedValue()+" m/s":"Speed: tắt");
    }
}
