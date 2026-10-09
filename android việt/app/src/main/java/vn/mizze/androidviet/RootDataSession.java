package vn.mizze.androidviet;

import android.content.Context;
import android.os.SystemClock;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/** Owns a read-only helper; permission and a valid key are required before launch. */
final class RootDataSession implements AutoCloseable {
    private static volatile String status="Chưa khởi động bộ đọc thử.";
    private volatile boolean closed;
    private volatile Process process;
    private BufferedWriter control;
    private long sentDeadline;
    private final String apk;
    private final LicenseClient license;
    RootDataSession(Context context,LicenseClient license){this.apk=context.getApplicationInfo().sourceDir;this.license=license;}
    static String status(){return status;}
    private static String quote(String value){return "'"+value.replace("'","'\"'\"'")+"'";}
    void start(){
        if(!BuildConfig.ROOT_EDITION||!RootAccess.granted()||!license.authorized())return;
        status="Đang mở bộ đọc Root thử nghiệm…";
        Thread reader=new Thread(()->{
            Process active=null;
            try{
                active=new ProcessBuilder("su","-c","CLASSPATH="+quote(apk)+" exec /system/bin/app_process /system/bin vn.mizze.androidviet.RootReaderMain").redirectErrorStream(true).start();
                synchronized(this){
                    if(closed){active.destroy();return;}
                    process=active;control=new BufferedWriter(new OutputStreamWriter(active.getOutputStream(),StandardCharsets.UTF_8));renew();
                }
                try(Reader input=new InputStreamReader(active.getInputStream(),StandardCharsets.UTF_8)){
                    StringBuilder line=new StringBuilder();int c;
                    while(!closed&&(c=input.read())!=-1){
                        if(c=='\n'){
                            try{JSONObject data=new JSONObject(line.toString());String next=data.optString("message","");
                                if(data.optString("state").equals("local_player"))next+="\nTên đọc được: "+data.optString("name").replaceAll("[\\p{Cntrl}]","");
                                if(!next.isEmpty()&&!closed)status=next;
                            }catch(Exception ignored){/* su diagnostics are not player data. */}
                            line.setLength(0);
                        }else{if(line.length()>=4096)throw new IOException("Helper output too large");line.append((char)c);}
                    }
                }
                if(!closed)status="Bộ đọc đã dừng; kiểm tra quyền root/SELinux và mở lại menu.";
            }catch(Exception e){if(!closed)status="Không khởi động được bộ đọc Root trên máy này.";}
            finally{if(active!=null)active.destroy();synchronized(this){control=null;process=null;}}
        },"root-game-reader");reader.setDaemon(true);reader.start();
    }
    synchronized void renew(){
        if(closed||control==null)return;
        long deadline=license.leaseDeadline();
        if(deadline<=SystemClock.elapsedRealtime()){close();return;}
        if(deadline==sentDeadline)return;
        try{control.write("LEASE "+deadline+"\n");control.flush();sentDeadline=deadline;}
        catch(IOException e){close();}
    }
    @Override public synchronized void close(){
        if(closed)return;closed=true;status="Bộ đọc đã dừng.";
        try{if(control!=null){control.write("STOP\n");control.flush();control.close();}}catch(IOException ignored){}
        Process active=process;
        if(active!=null){active.destroy();Thread cleanup=new Thread(()->{try{if(!active.waitFor(2,TimeUnit.SECONDS))active.destroyForcibly();}catch(InterruptedException e){Thread.currentThread().interrupt();}},"root-reader-stop");cleanup.setDaemon(true);cleanup.start();}
    }
}
