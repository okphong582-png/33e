package vn.mizze.androidviet;

import android.os.SystemClock;
import org.json.JSONObject;
import java.io.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Root helper: bounded reads and validated PlayerAttributes writes; no injected calls. */
public final class RootReaderMain {
    private static final long FACADE_CACHE=0xAC1E768L, MATCH_GAME_CACHE=0xAC232A0L;
    private static volatile long lease;
    private static volatile JSONObject frameConfig=new JSONObject();
    private static volatile RootFeatureController.Config config=RootFeatureController.Config.off();
    private static final RootFeatureController features=new RootFeatureController();
    private static Memory sessionMemory;
    private static long mappingsAt;
    private static void releaseMemory(){if(sessionMemory!=null){try{sessionMemory.close();}catch(IOException ignored){}sessionMemory=null;}}

    static boolean pointer(long p){return p>=0x10000 && p<0x0001000000000000L && (p&7)==0;}
    private record Mapping(long start,long end,String permissions,String file){}
    private static List<Mapping> maps(int pid)throws Exception{
        ArrayList<Mapping> result=new ArrayList<>();
        try(BufferedReader in=new BufferedReader(new FileReader("/proc/"+pid+"/maps"))){String line;while((line=in.readLine())!=null){
            String[] p=line.trim().split(" +",6);if(p.length<5)continue;String[] range=p[0].split("-");
            result.add(new Mapping(Long.parseUnsignedLong(range[0],16),Long.parseUnsignedLong(range[1],16),p[1],p.length==6?p[5]:""));
        }}return result;
    }
    static int gamePid(){
        File[] files=new File("/proc").listFiles();if(files==null)return 0;
        for(File file:files){if(!file.getName().matches("[0-9]+"))continue;
            try(var in=new FileInputStream(new File(file,"cmdline"))){byte[] b=new byte[128];int n=in.read(b);if(n<=0)continue;int end=0;while(end<n&&b[end]!=0)end++;
                if(new String(b,0,end,StandardCharsets.UTF_8).equals("com.dts.freefireth"))return Integer.parseInt(file.getName());
            }catch(Exception ignored){}
        }return 0;
    }
    static final class Memory implements AutoCloseable {
        final int pid;final long start;final FileInputStream input;final FileChannel channel;final List<Mapping> ranges;
        RandomAccessFile output;FileChannel writer;private long cachedLibrary,cachedUnity;final Set<Long> verifiedNodes=new HashSet<>();private final Map<Long,String> labels=new java.util.concurrent.ConcurrentHashMap<>();
        private boolean mapped(long address,int count,boolean writable){
            int lo=0,hi=ranges.size()-1;while(lo<=hi){int mid=(lo+hi)>>>1;Mapping r=ranges.get(mid);if(address<r.start())hi=mid-1;else if(address>=r.end())lo=mid+1;else return count>=0&&address<=r.end()-count&&r.permissions().startsWith(writable?"rw":"r");}return false;
        }
        Memory(int pid)throws Exception{this.pid=pid;this.start=processStart(pid);ranges=maps(pid);input=new FileInputStream("/proc/"+pid+"/mem");channel=input.getChannel();}
        byte[] read(long address,int count)throws Exception{
            if(count<0||count>4096)throw new IOException("Invalid read size");
            if(!mapped(address,count,false))throw new IOException("Address outside readable mapping");
            ByteBuffer buffer=ByteBuffer.allocate(count);int done=0;
            while(done<count){int n=channel.read(buffer,address+done);if(n<=0)throw new EOFException();done+=n;}return buffer.array();
        }
        void enableWrites()throws IOException{if(writer==null){output=new RandomAccessFile("/proc/"+pid+"/mem","rw");writer=output.getChannel();}}
        void write(long address,int size,int bits)throws Exception{
            if(!mapped(address,size,true)||size!=1&&size!=4)throw new IOException("Not a writable data mapping");
            enableWrites();ByteBuffer data=ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN);if(size==1)data.put((byte)bits);else data.putInt(bits);data.flip();
            int written=0;while(data.hasRemaining()){int n=writer.write(data,address+written);if(n<=0)throw new IOException("Short write");written+=n;}
        }
        void writeQuaternion(long address,GameGeometry.Q q)throws Exception{
            if(q==null||!q.valid())throw new IOException("Invalid quaternion");
            if(!mapped(address,16,true))throw new IOException("Quaternion outside data mapping");enableWrites();
            ByteBuffer data=ByteBuffer.allocate(16).order(ByteOrder.LITTLE_ENDIAN).putFloat(q.x()).putFloat(q.y()).putFloat(q.z()).putFloat(q.w());data.flip();
            int done=0;while(data.hasRemaining()){int n=writer.write(data,address+done);if(n<=0)throw new IOException("Short quaternion write");done+=n;}
        }
        long unityBase(){if(cachedUnity!=0)return cachedUnity;for(Mapping range:ranges){if(!range.permissions().startsWith("r")||!(range.file().contains("libunity.so")||range.file().contains("com.dts.freefireth")||range.file().contains("config.arm64")))continue;
            try{byte[] h=read(range.start(),64);if(h[0]!=0x7f||h[1]!='E'||h[2]!='L'||h[3]!='F'||h[4]!=2||ByteBuffer.wrap(h).order(ByteOrder.LITTLE_ENDIAN).getShort(18)!=183)continue;
                long b=range.start();if(i32(b+0x693054)==0xF9401C14&&i32(b+0xB79844)==0x91020260&&i32(b+0xB79904)==0x91030260&&i32(b+0x691590)==0xA941A408)return cachedUnity=b;
            }catch(Exception ignored){}
        }return 0;}
        long ptr(long address)throws Exception{return ByteBuffer.wrap(read(address,8)).order(ByteOrder.LITTLE_ENDIAN).getLong();}
        int i32(long address)throws Exception{return ByteBuffer.wrap(read(address,4)).order(ByteOrder.LITTLE_ENDIAN).getInt();}
        String ascii(long address)throws Exception{String cached=labels.get(address);if(cached!=null)return cached;byte[] data=read(address,96);int n=0;while(n<data.length&&data[n]!=0)n++;String value=new String(data,0,n,StandardCharsets.UTF_8);if(labels.size()<4096)labels.put(address,value);return value;}
        boolean instanceOf(long object,long expected)throws Exception{
            if(!pointer(object)||!pointer(expected))return false;long actual=ptr(object);
            int targetDepth=read(expected+0x130,1)[0]&255,depth=read(actual+0x130,1)[0]&255;
            return targetDepth>0&&depth>=targetDepth&&ptr(ptr(actual+0xC8)+(targetDepth-1)*8L)==expected;
        }
        String managedString(long address)throws Exception{if(!pointer(address))return "";
            long type=ptr(address);if(!ascii(ptr(type+16)).equals("String")||!ascii(ptr(type+24)).equals("System"))throw new IOException("Not a managed string");int n=i32(address+16);if(n<0||n>128)throw new IOException("Invalid string length");return new String(read(address+20,n*2),StandardCharsets.UTF_16LE);}
        long libraryBase(){
            if(cachedLibrary!=0)return cachedLibrary;
            for(Mapping m:ranges){if(!m.permissions().startsWith("r") || !(m.file().contains("libil2cpp.so")||m.file().contains("com.dts.freefireth")||m.file().contains("config.arm64")))continue;
                try{byte[] header=read(m.start(),64);if(header[0]!=0x7f||header[1]!='E'||header[2]!='L'||header[3]!='F'||header[4]!=2)continue;
                    if(ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN).getShort(18)!=183)continue;
                    long base=m.start();
                    // Exact Android 1.132.1 ARM64 instructions, not offsets copied from iOS.
                    if(i32(base+0x71BCD10L)!=0xF81E0FFE||i32(base+0x6F2797CL)!=0xF9424A60)continue;
                    if(ptr(base+0xA5C7F60L+80)!=43627 || ptr(base+0xA5C7F60L+48)!=103553)continue;
                    return cachedLibrary=base;
                }catch(Exception ignored){}
            }return 0;
        }
        public void close()throws IOException{try{if(output!=null)output.close();}finally{input.close();}}
    }
    static long processStart(int pid)throws Exception{
        String stat;try(BufferedReader in=new BufferedReader(new FileReader("/proc/"+pid+"/stat"))){stat=in.readLine();}
        return Long.parseLong(stat.substring(stat.lastIndexOf(')')+2).split(" +")[19]);
    }
    static long[] context(Memory m,long base)throws Exception{
        long klass=m.ptr(base+FACADE_CACHE);
        if(!pointer(klass)||!m.ascii(m.ptr(klass+16)).equals("GameFacade")||!m.ascii(m.ptr(klass+24)).equals("COW"))return null;
        long statics=m.ptr(klass+0xB8),game=pointer(statics)?m.ptr(statics):0;
        if(!m.instanceOf(game,m.ptr(base+MATCH_GAME_CACHE)))return null;
        long match=m.ptr(game+0x90),player=pointer(match)?m.ptr(match+0xD8):0;
        return pointer(player)?new long[]{game,match,player}:null;
    }
    private static RootFeatureController.Identity attributes(Memory m,long base)throws Exception{
        if(processStart(m.pid)!=m.start)return null;
        long[] live=context(m,base);if(live==null)return null;
        long attrs=m.ptr(live[2]+0x768);if(!pointer(attrs)||m.ptr(attrs+0x20)!=live[2])return null;
        long klass=m.ptr(attrs);
        if(!m.ascii(m.ptr(klass+16)).equals("PlayerAttributes")||!m.ascii(m.ptr(klass+24)).equals("COW.GamePlay"))return null;
        return new RootFeatureController.Identity(m.pid,m.start,base,live[1],live[2],attrs,klass);
    }
    private static boolean featureSignatures(Memory m,long base)throws Exception{
        return m.i32(base+0x6F089C8L)==0xF943B674&&m.i32(base+0x7C25C10L)==0xBD425A60&&
            m.i32(base+0x7C25C68L)==0xBD025A68&&m.i32(base+0x7C21838L)==0xBD43CA80&&m.i32(base+0x744FC84L)==0x39444408;
    }
    private static RootFeatureController.Memory access(Memory m,long base,boolean restoring){return new RootFeatureController.Memory(){
        public RootFeatureController.Identity identity()throws Exception{return attributes(m,base);}
        public int read(long address,int size)throws Exception{return size==1?m.read(address,1)[0]&255:m.i32(address);}
        public void write(long address,int size,int bits)throws Exception{if(!restoring&&SystemClock.elapsedRealtime()>=lease)throw new IOException("Lease expired");m.write(address,size,bits);}
    };}
    private static JSONObject snapshot()throws Exception{
        int pid=sessionMemory==null?gamePid():sessionMemory.pid;
        if(sessionMemory!=null){try{if(processStart(pid)!=sessionMemory.start){releaseMemory();pid=gamePid();}}catch(Exception e){releaseMemory();pid=gamePid();}}
        if(pid==0)return new JSONObject().put("state","waiting_game").put("message","Chưa mở Free Fire thường.");
        if(sessionMemory==null||SystemClock.elapsedRealtime()-mappingsAt>2000){releaseMemory();sessionMemory=new Memory(pid);mappingsAt=SystemClock.elapsedRealtime();}
        {Memory memory=sessionMemory;
            long base=memory.libraryBase();if(base==0)return new JSONObject().put("state","profile_mismatch").put("message","Chưa khớp thư viện Android 1.132.1 ARM64; không đọc theo offset.");
            long klass=memory.ptr(base+FACADE_CACHE);
            if(!pointer(klass))return new JSONObject().put("state","waiting_class").put("message","Chờ GameFacade được khởi tạo.");
            if(!memory.ascii(memory.ptr(klass+16)).equals("GameFacade")||!memory.ascii(memory.ptr(klass+24)).equals("COW"))
                return new JSONObject().put("state","class_mismatch").put("message","Class GameFacade không khớp; đã dừng đọc.");
            long statics=memory.ptr(klass+0xB8),game=pointer(statics)?memory.ptr(statics):0;
            long matchGameClass=memory.ptr(base+MATCH_GAME_CACHE);
            if(!memory.instanceOf(game,matchGameClass))return new JSONObject().put("state","waiting_match").put("message","Chờ CurrentGame là MatchGame.");
            long match=pointer(game)?memory.ptr(game+0x90):0,player=pointer(match)?memory.ptr(match+0xD8):0;
            if(!pointer(player))return new JSONObject().put("state","waiting_match").put("message","Đã khớp thư viện; chờ nhân vật trong trận.").put("pid",pid);
            String name=memory.managedString(memory.ptr(player+0x490));
            String featureStatus="Chờ PlayerAttributes để mở chức năng.";boolean ready=false;
            try{
                if(featureSignatures(memory,base)&&attributes(memory,base)!=null){
                    RootFeatureController.Identity identity=attributes(memory,base);
                    int reload=memory.read(identity.attributes()+0x111,1)[0]&255;
                    float fire=Float.intBitsToFloat(memory.i32(identity.attributes()+0x258)),run=Float.intBitsToFloat(memory.i32(identity.attributes()+0x3C8));
                    if(reload>1||!Float.isFinite(fire)||fire<.05f||fire>16||!Float.isFinite(run)||run<0||run>1000)throw new IOException("Invalid attributes fields");
                    memory.enableWrites();ready=true;
                    RootFeatureController.Config desired=SystemClock.elapsedRealtime()<lease?config:RootFeatureController.Config.off();
                    featureStatus=features.update(access(memory,base,!desired.noReload()&&!desired.fastFire()&&!desired.speed()),desired);
                }
            }catch(Exception e){featureStatus="Chưa áp dụng được chức năng: quyền ghi, giá trị hoặc PlayerAttributes không khớp.";}

            JSONObject frame=new JSONObject();String frameStatus="Chờ danh sách người chơi/camera Android.";
            try{JSONObject desiredFrame=frameConfig;frame=new RootGameFrameReader(memory,base,game,match,player).read(desiredFrame,()->lease,()->frameConfig==desiredFrame);frameStatus="ESP: đã đọc "+frame.optInt("playerCount")+" người chơi, camera/xương/HP.\n"+frame.optString("aimStatus");}
            catch(Exception e){frameStatus="ESP/Aim: "+e.getMessage();}
            if(name.isEmpty())return new JSONObject().put("state","waiting_name").put("message","Chờ tên người chơi trong trận.");
            return new JSONObject().put("state","local_player").put("message","Đã đọc Local Name trong trận.")
                .put("pid",pid).put("name",name).put("sampleUptime",SystemClock.elapsedRealtime())
                .put("featuresReady",ready).put("featureStatus",featureStatus+"\n"+frameStatus)
                .put("frame",frame).put("playersReady",frame.optBoolean("playersReady")).put("aimReady",frame.optBoolean("aimReady")).put("silentReady",frame.optBoolean("silentReady"));
        }
    }
    public static void main(String[] args){
        if(!BuildConfig.ROOT_EDITION){System.out.println("{\"state\":\"unsupported\"}");return;}
        if(android.system.Os.getuid()!=0){System.out.println("{\"state\":\"root_required\",\"message\":\"Helper chưa có uid 0; cần cấp quyền root.\"}");return;}
        // A dead parent cannot leave a persistent root helper behind: lease is bounded to 30 seconds.
        lease=SystemClock.elapsedRealtime()+3000;
        Thread control=new Thread(()->{try(BufferedReader in=new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8))){String line;
            while((line=in.readLine())!=null){if(line.length()>4096){lease=0;return;}if(line.equals("STOP")){lease=0;return;}
            if(line.startsWith("CONFIG ")){JSONObject c=new JSONObject(line.substring(7));if(!c.optBoolean("silent"))AimPulse.clear();frameConfig=c;config=new RootFeatureController.Config(c.optBoolean("noReload"),c.optBoolean("fastFire"),c.optBoolean("speed"),(float)c.optDouble("speedValue",6));}
            if(line.startsWith("LEASE ")){
                long requested=Long.parseLong(line.substring(6));lease=Math.min(requested,SystemClock.elapsedRealtime()+30000);
            }}lease=0;
        }catch(Exception e){lease=0;}},"lease");control.setDaemon(true);control.start();
        while(SystemClock.elapsedRealtime()<lease){
            long cycle=SystemClock.elapsedRealtime();
            try{System.out.println(snapshot().toString());}
            catch(Exception e){releaseMemory();System.out.println("{\"state\":\"read_denied\",\"message\":\"Không đọc được bộ nhớ game (quyền hoặc SELinux).\"}");}
            System.out.flush();try{Thread.sleep(Math.max(1,(frameConfig.optBoolean("balanced")?33:16)-(SystemClock.elapsedRealtime()-cycle)));}catch(InterruptedException e){break;}
        }
        AimPulse.stop();
        config=RootFeatureController.Config.off();
        frameConfig=new JSONObject();
        try{snapshot();}catch(Exception ignored){}
        for(int attempt=0;attempt<3&&features.changed();attempt++){
            try{snapshot();Thread.sleep(100);}catch(Exception ignored){}
        }
        releaseMemory();
    }
}
