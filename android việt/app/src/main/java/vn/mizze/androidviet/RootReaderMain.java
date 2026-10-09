package vn.mizze.androidviet;

import android.os.SystemClock;
import org.json.JSONObject;
import java.io.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Read-only root helper, launched with app_process. No game writes or injected calls. */
public final class RootReaderMain {
    private static final long FACADE_CACHE=0xAC1E768L, MATCH_GAME_CACHE=0xAC232A0L;
    private static volatile long lease;
    private static boolean pointer(long p){return p>=0x10000 && p<0x0001000000000000L && (p&7)==0;}
    private record Mapping(long start,long end,String permissions,String file){}
    private static List<Mapping> maps(int pid)throws Exception{
        ArrayList<Mapping> result=new ArrayList<>();
        try(BufferedReader in=new BufferedReader(new FileReader("/proc/"+pid+"/maps"))){String line;while((line=in.readLine())!=null){
            String[] p=line.trim().split(" +",6);if(p.length<5)continue;String[] range=p[0].split("-");
            result.add(new Mapping(Long.parseUnsignedLong(range[0],16),Long.parseUnsignedLong(range[1],16),p[1],p.length==6?p[5]:""));
        }}return result;
    }
    private static int gamePid(){
        File[] files=new File("/proc").listFiles();if(files==null)return 0;
        for(File file:files){if(!file.getName().matches("[0-9]+"))continue;
            try(var in=new FileInputStream(new File(file,"cmdline"))){byte[] b=new byte[128];int n=in.read(b);if(n<=0)continue;int end=0;while(end<n&&b[end]!=0)end++;
                if(new String(b,0,end,StandardCharsets.UTF_8).equals("com.dts.freefireth"))return Integer.parseInt(file.getName());
            }catch(Exception ignored){}
        }return 0;
    }
    private static final class Memory implements AutoCloseable {
        final FileInputStream input;final FileChannel channel;final List<Mapping> ranges;
        Memory(int pid)throws Exception{ranges=maps(pid);input=new FileInputStream("/proc/"+pid+"/mem");channel=input.getChannel();}
        byte[] read(long address,int count)throws Exception{
            if(count<0||count>4096)throw new IOException("Invalid read size");boolean valid=false;
            for(Mapping m:ranges)if(m.permissions().startsWith("r")&&address>=m.start()&&address<=m.end()-count){valid=true;break;}
            if(!valid)throw new IOException("Address outside readable mapping");
            ByteBuffer buffer=ByteBuffer.allocate(count);int done=0;
            while(done<count){int n=channel.read(buffer,address+done);if(n<=0)throw new EOFException();done+=n;}return buffer.array();
        }
        long ptr(long address)throws Exception{return ByteBuffer.wrap(read(address,8)).order(ByteOrder.LITTLE_ENDIAN).getLong();}
        int i32(long address)throws Exception{return ByteBuffer.wrap(read(address,4)).order(ByteOrder.LITTLE_ENDIAN).getInt();}
        String ascii(long address)throws Exception{byte[] data=read(address,96);int n=0;while(n<data.length&&data[n]!=0)n++;return new String(data,0,n,StandardCharsets.UTF_8);}
        boolean instanceOf(long object,long expected)throws Exception{
            if(!pointer(object)||!pointer(expected))return false;long actual=ptr(object);
            int targetDepth=read(expected+0x130,1)[0]&255,depth=read(actual+0x130,1)[0]&255;
            return targetDepth>0&&depth>=targetDepth&&ptr(ptr(actual+0xC8)+(targetDepth-1)*8L)==expected;
        }
        String managedString(long address)throws Exception{if(!pointer(address))return "";
            long type=ptr(address);if(!ascii(ptr(type+16)).equals("String")||!ascii(ptr(type+24)).equals("System"))throw new IOException("Not a managed string");int n=i32(address+16);if(n<0||n>128)throw new IOException("Invalid string length");return new String(read(address+20,n*2),StandardCharsets.UTF_16LE);}
        long libraryBase(){
            for(Mapping m:ranges){if(!m.permissions().startsWith("r") || !(m.file().contains("libil2cpp.so")||m.file().contains("com.dts.freefireth")||m.file().contains("config.arm64")))continue;
                try{byte[] header=read(m.start(),64);if(header[0]!=0x7f||header[1]!='E'||header[2]!='L'||header[3]!='F'||header[4]!=2)continue;
                    if(ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN).getShort(18)!=183)continue;
                    long base=m.start();
                    // Exact Android 1.132.1 ARM64 instructions, not offsets copied from iOS.
                    if(i32(base+0x71BCD10L)!=0xF81E0FFE||i32(base+0x6F2797CL)!=0xF9424A60)continue;
                    if(ptr(base+0xA5C7F60L+80)!=43627 || ptr(base+0xA5C7F60L+48)!=103553)continue;
                    return base;
                }catch(Exception ignored){}
            }return 0;
        }
        public void close()throws IOException{input.close();}
    }
    private static JSONObject snapshot()throws Exception{
        int pid=gamePid();if(pid==0)return new JSONObject().put("state","waiting_game").put("message","Chưa mở Free Fire thường.");
        try(Memory memory=new Memory(pid)){
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
            return new JSONObject().put("state","local_player").put("message","Đọc được chuỗi tên theo profile thử · Chưa kiểm chứng ESP/Aim.")
                .put("pid",pid).put("name",name).put("sampleUptime",SystemClock.elapsedRealtime());
        }
    }
    public static void main(String[] args){
        if(!BuildConfig.ROOT_EDITION){System.out.println("{\"state\":\"unsupported\"}");return;}
        // A dead parent cannot leave a persistent root helper behind: lease is bounded to 30 seconds.
        lease=SystemClock.elapsedRealtime()+3000;
        Thread control=new Thread(()->{try(BufferedReader in=new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8))){String line;
            while((line=in.readLine())!=null){if(line.equals("STOP")){lease=0;return;}if(line.startsWith("LEASE ")){
                long requested=Long.parseLong(line.substring(6));lease=Math.min(requested,SystemClock.elapsedRealtime()+30000);
            }}lease=0;
        }catch(Exception e){lease=0;}},"lease");control.setDaemon(true);control.start();
        while(SystemClock.elapsedRealtime()<lease){
            try{System.out.println(snapshot().toString());}
            catch(Exception e){System.out.println("{\"state\":\"read_denied\",\"message\":\"Không đọc được bộ nhớ game (quyền hoặc SELinux).\"}");}
            System.out.flush();try{Thread.sleep(1000);}catch(InterruptedException e){break;}
        }
    }
}
