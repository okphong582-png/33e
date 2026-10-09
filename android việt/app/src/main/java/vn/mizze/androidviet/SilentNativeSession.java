package vn.mizze.androidviet;

import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.os.SystemClock;
import org.json.JSONObject;
import java.io.*;
import java.util.concurrent.TimeUnit;

/** Root-only transport. Native readiness requires a reply from the installed shot callback. */
final class SilentNativeSession {
    private static String nativeDirectory="";
    private static SilentNativeSession active;
    private final int pid;private final long start;
    private long sequence,redirects;private LocalSocket socket;
    private volatile boolean loading,attempted;
    private volatile String status="Silent: chờ nạp module native.";
    private SilentNativeSession(int pid,long start){this.pid=pid;this.start=start;}
    static synchronized void configure(String directory){nativeDirectory=directory;}
    static synchronized void stop(){if(active!=null)active.disconnect();}
    static synchronized String status(){return active==null?"Silent đang tắt.":active.status;}
    static synchronized boolean update(RootReaderMain.Memory memory,long base,long game,long match,long local,long target,GameGeometry.V point,long sample,long lease,JSONObject config){
        if(!BuildConfig.ROOT_EDITION||!config.optBoolean("silent")){stop();return false;}
        if(active==null||active.pid!=memory.pid||active.start!=memory.start){stop();active=new SilentNativeSession(memory.pid,memory.start);}
        return active.send(base,game,match,local,target,point,sample,lease,config);
    }
    private void launch(){
        if(attempted||loading)return;attempted=true;loading=true;
        final File executable=new File(nativeDirectory,"libmizze_loader.so"),library=new File(nativeDirectory,"libmizze_silent.so");
        Thread worker=new Thread(()->{Process loader=null;
            try{
                if(!executable.isFile()||!library.isFile())throw new IOException("Missing native files");
                if(RootReaderMain.processStart(pid)!=start)throw new IOException("Game restarted");
                loader=new ProcessBuilder(executable.getAbsolutePath(),Integer.toString(pid),Long.toString(start),library.getAbsolutePath()).redirectErrorStream(true).start();
                final Process child=loader;
                Thread drain=new Thread(()->{try(InputStream in=child.getInputStream()){byte[] bytes=new byte[4096];while(in.read(bytes)!=-1){/* keep loader diagnostics out of the menu */}}catch(IOException ignored){}},"silent-loader-output");drain.setDaemon(true);drain.start();
                // Upstream remote calls have a 2-second timeout; this bounds the child as a whole.
                if(!loader.waitFor(15,TimeUnit.SECONDS)){status="Silent: bộ nạp quá thời gian; cần mở lại game/menu.";}
                else status=loader.exitValue()==0?"Silent: module đã nạp, chờ kết nối.":"Silent: máy chưa cho phép nạp module native (mã "+loader.exitValue()+").";
            }catch(Exception e){status="Silent: không nạp được module native trên máy này.";}
            finally{loading=false;}
        },"silent-native-loader");worker.setDaemon(true);worker.start();
    }
    private boolean send(long base,long game,long match,long local,long target,GameGeometry.V point,long sample,long lease,JSONObject config){
        try{
            if(RootReaderMain.processStart(pid)!=start)throw new IOException("Game restarted");
            if(socket==null){LocalSocket candidate=new LocalSocket();try{candidate.connect(new LocalSocketAddress("mizze.silent.v1."+pid,LocalSocketAddress.Namespace.ABSTRACT));candidate.setSoTimeout(100);socket=candidate;}catch(IOException e){candidate.close();launch();return false;}}
            int flags=1|(config.optBoolean("fire")?2:0)|(config.optBoolean("scope")?4:0)|(config.optBoolean("always")?8:0)|(config.optBoolean("both")?16:0);
            byte[] packet=SilentProtocol.packet(++sequence,base,game,match,local,target,sample,lease,point,flags);
            socket.getOutputStream().write(packet);byte[] response=new byte[32];int offset=0;
            while(offset<response.length){int count=socket.getInputStream().read(response,offset,response.length-offset);if(count<=0)throw new EOFException();offset+=count;}
            SilentProtocol.Reply reply=SilentProtocol.reply(response,sequence);
            redirects=reply.redirects();boolean ready=reply.ready();int error=reply.error();
            status=ready?"Silent: callback đã nối · "+redirects+" phát đã đổi hướng.":"Silent: chưa nối được callback (mã "+error+").";
            return ready&&sample<=SystemClock.elapsedRealtime()&&SystemClock.elapsedRealtime()-sample<=150;
        }catch(Exception e){disconnect();status="Silent: mất kết nối module; đã dừng yêu cầu đổi hướng.";return false;}
    }
    private void disconnect(){if(socket!=null){try{socket.close();}catch(IOException ignored){}socket=null;}}
}
