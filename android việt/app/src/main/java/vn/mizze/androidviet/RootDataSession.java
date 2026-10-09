package vn.mizze.androidviet;

import android.content.Context;
import android.os.SystemClock;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/** Owns a bounded root helper; permission and a valid key are required before launch. */
final class RootDataSession implements AutoCloseable {
    private static volatile String status="Chưa khởi động bộ đọc thử.";
    private static volatile boolean featuresReady;
    private static volatile long sampledAt;
    private static volatile boolean playersReady,aimReady;
    private static volatile JSONObject frame=new JSONObject();
    private static volatile long frameAt;
    private static volatile int viewportWidth,viewportHeight;
    private volatile boolean closed;
    private volatile Process process;
    private BufferedWriter control;
    private long sentDeadline;
    private String sentConfig="";
    private final android.content.SharedPreferences prefs;
    private final String apk;
    private final LicenseClient license;
    RootDataSession(Context context,LicenseClient license){this.apk=context.getApplicationInfo().sourceDir;this.license=license;this.prefs=context.getSharedPreferences("menu",Context.MODE_PRIVATE);}
    static String status(){return status;}
    static boolean featuresReady(){return BuildConfig.ROOT_EDITION&&featuresReady&&SystemClock.elapsedRealtime()-sampledAt<2500;}
    static boolean playersReady(){return BuildConfig.ROOT_EDITION&&playersReady&&SystemClock.elapsedRealtime()-frameAt<500;}
    static boolean aimReady(){return playersReady()&&aimReady;}
    static JSONObject frame(){return playersReady()?frame:null;}
    static void viewport(int width,int height){viewportWidth=width;viewportHeight=height;}
    static int capabilityMask(){return (featuresReady()?1:0)|(playersReady()?2:0)|(aimReady()?4:0);}
    private void reset(){featuresReady=false;playersReady=false;aimReady=false;frame=new JSONObject();
        var edit=prefs.edit();for(String key:AndroidGameData.ACTIVE_KEYS)edit.putBoolean(key,false);edit.apply();}
    private static String quote(String value){return "'"+value.replace("'","'\"'\"'")+"'";}
    void start(){
        if(!BuildConfig.ROOT_EDITION||!RootAccess.granted()||!license.authorized())return;
        reset();
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
                    while((c=input.read())!=-1){
                        if(c=='\n'){
                            try{JSONObject data=new JSONObject(line.toString());String next=data.optString("message","");
                                if(data.optString("state").equals("local_player"))next+="\nTên đọc được: "+data.optString("name").replaceAll("[\\p{Cntrl}]","");
                                if(!next.isEmpty()&&!closed){status=next+"\n"+data.optString("featureStatus","");featuresReady=data.optBoolean("featuresReady");sampledAt=SystemClock.elapsedRealtime();
                                    JSONObject nextFrame=data.optJSONObject("frame");long sample=nextFrame==null?0:nextFrame.optLong("sampleUptime");
                                    long now=SystemClock.elapsedRealtime();boolean fresh=sample>0&&sample<=now&&now-sample<500;
                                    frame=nextFrame==null?new JSONObject():nextFrame;playersReady=fresh&&data.optBoolean("playersReady");aimReady=playersReady&&data.optBoolean("aimReady");frameAt=sample;
                                }
                            }catch(Exception ignored){/* su diagnostics are not player data. */}
                            line.setLength(0);
                        }else{if(line.length()>=262144)throw new IOException("Helper output too large");line.append((char)c);}
                    }
                }
                if(!closed){reset();}
                if(!closed)status="Bộ đọc đã dừng; kiểm tra quyền root/SELinux và mở lại menu.";
            }catch(Exception e){if(!closed){reset();status="Không khởi động được bộ đọc Root trên máy này.";}}
            finally{if(active!=null)active.destroy();synchronized(this){control=null;process=null;}}
        },"root-game-reader");reader.setDaemon(true);reader.start();
    }
    synchronized void renew(){
        if(closed||control==null)return;
        long deadline=license.leaseDeadline();
        if(deadline<=SystemClock.elapsedRealtime()){close();return;}
        try{
            if(deadline!=sentDeadline){control.write("LEASE "+deadline+"\n");sentDeadline=deadline;}
            String next=new JSONObject().put("noReload",prefs.getBoolean("ShootNoReload",false))
                .put("fastFire",prefs.getBoolean("FastFire",false)).put("speed",prefs.getBoolean("RunSpeed",false))
                .put("speedValue",prefs.getFloat("RunSpeedValue",6))
                .put("head",prefs.getBoolean("AimHead",false)).put("neck",prefs.getBoolean("AimNeck",false))
                .put("fire",prefs.getBoolean("AimbotFire",false)).put("scope",prefs.getBoolean("AimbotScope",false))
                .put("always",prefs.getBoolean("AimHipAlways",false)).put("both",prefs.getBoolean("AimFireAndScope",false))
                .put("fov",prefs.getFloat("FovSize",40)).put("distance",prefs.getFloat("ESPMaxDistance",150))
                .put("width",viewportWidth).put("height",viewportHeight).toString();
            if(!next.equals(sentConfig)){control.write("CONFIG "+next+"\n");sentConfig=next;}
            control.flush();
        }
        catch(Exception e){close();}
    }
    @Override public synchronized void close(){
        if(closed)return;closed=true;reset();status="Bộ đọc đã dừng.";
        try{if(control!=null){control.write("STOP\n");control.flush();control.close();}}catch(IOException ignored){}
        Process active=process;
        if(active!=null){Thread cleanup=new Thread(()->{try{if(!active.waitFor(3,TimeUnit.SECONDS))active.destroyForcibly();}catch(InterruptedException e){Thread.currentThread().interrupt();}},"root-reader-stop");cleanup.setDaemon(true);cleanup.start();}
    }
}
