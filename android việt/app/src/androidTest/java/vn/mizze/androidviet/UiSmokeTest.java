package vn.mizze.androidviet;

import android.graphics.Bitmap;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.rule.ActivityTestRule;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;
import java.io.File;
import java.io.FileOutputStream;

@RunWith(AndroidJUnit4.class)
public class UiSmokeTest {
    @Rule public ActivityTestRule<MainActivity> activity = new ActivityTestRule<>(MainActivity.class);
    private TextView find(View root,String text){
        if(root instanceof TextView && ((TextView)root).getText().toString().equals(text))return (TextView)root;
        if(root instanceof ViewGroup)for(int i=0;i<((ViewGroup)root).getChildCount();i++){TextView v=find(((ViewGroup)root).getChildAt(i),text);if(v!=null)return v;}return null;
    }
    private void screenshot(String name) throws Throwable {
        InstrumentationRegistry.getInstrumentation().waitForIdleSync();Thread.sleep(250);
        Bitmap bitmap=InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();assertNotNull(bitmap);
        File file=new File(activity.getActivity().getExternalFilesDir(null),name+".png");
        try(var output=new FileOutputStream(file)){assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG,100,output));}bitmap.recycle();
        // UTP removes app data, so capture directly into shared storage using single shell commands.
        String destination="/sdcard/Download/android-viet/"+activity.getActivity().getPackageName();
        String capture=destination+"/"+name+".png";
        shell("mkdir -p "+destination);shell("screencap -p "+capture);
        byte[] retained=shell("cat "+capture);
        assertTrue("Retained screenshot must be a PNG",retained.length>8&&retained[0]==(byte)0x89&&retained[1]=='P'&&retained[2]=='N'&&retained[3]=='G');
    }
    private byte[] shell(String command)throws Exception{
        try(var descriptor=InstrumentationRegistry.getInstrumentation().getUiAutomation().executeShellCommand(command);
            var input=new android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor);
            var output=new java.io.ByteArrayOutputStream()){
            byte[] buffer=new byte[4096];int n;while((n=input.read(buffer))!=-1){if(output.size()+n>8*1024*1024)throw new java.io.IOException("Shell output too large");output.write(buffer,0,n);}return output.toByteArray();
        }
    }
    @Test public void loginRequiresKeyAndStartIsLocked() throws Throwable {
        activity.runOnUiThread(()->{
            View root=activity.getActivity().getWindow().getDecorView();
            assertNotNull(find(root,"Tập trung.\nChơi theo ý bạn."));
            assertFalse(find(root,"Start · Mở bảng điều khiển").isEnabled());
            find(root,"Đăng nhập").performClick();
            assertNotNull(find(root,"Vui lòng nhập key hợp lệ."));
        });screenshot("login");
    }
    @Test public void menuTabsShowRealCapabilityAndSettingsPersist() throws Throwable {
        MainActivity screen=activity.getActivity();
        activity.runOnUiThread(()->{
            // Render a widget in the test Activity, without authorizing a production service.
            MenuPanel panel=new MenuPanel(screen,new MenuPanel.Host(){public void closeMenu(){}public void settingsChanged(){}public void stop(){}},0);
            screen.setContentView(panel);
            assertFalse(((View)find(panel,"Aim đầu").getParent()).isEnabled());
        });screenshot("menu-aim");
        activity.runOnUiThread(()->{View root=screen.getWindow().getDecorView();find(root,"ESP").performClick();assertFalse(((View)find(root,"Bật ESP").getParent()).isEnabled());});screenshot("menu-esp");
        activity.runOnUiThread(()->find(screen.getWindow().getDecorView(),"Màu sắc").performClick());screenshot("menu-colors");
        activity.runOnUiThread(()->{
            View root=screen.getWindow().getDecorView();find(root,"Thiết lập").performClick();
            boolean before=new Ui(screen).prefs.getBoolean("AnLive",false);
            ((View)find(root,"Ẩn khi chụp / quay").getParent()).performClick();
            assertEquals(!before,new Ui(screen).prefs.getBoolean("AnLive",false));
            ((View)find(root,"Ẩn khi chụp / quay").getParent()).performClick();
            assertFalse(((View)find(root,"Speed").getParent()).isEnabled());
        });screenshot("menu-settings");
    }

    @Test public void overlayRunsAndStopsOnLeaseExpiry() throws Throwable {
        var instrumentation=InstrumentationRegistry.getInstrumentation();
        var context=instrumentation.getTargetContext();
        // Test-only shell appop and in-memory lease fixture; no production bypass or live Firebase write.
        try(var descriptor=instrumentation.getUiAutomation().executeShellCommand("appops set "+context.getPackageName()+" SYSTEM_ALERT_WINDOW allow");
            var input=new android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor)) { while(input.read()!=-1){} }
        assertTrue(android.provider.Settings.canDrawOverlays(context));
        LicenseClient client=((MizzeApp)context.getApplicationContext()).license();
        var deadline=LicenseClient.class.getDeclaredField("deadline");deadline.setAccessible(true);
        var rootGranted=RootAccess.class.getDeclaredField("granted");rootGranted.setAccessible(true);
        activity.runOnUiThread(()->{
            try{deadline.setLong(client,android.os.SystemClock.elapsedRealtime()+15000);rootGranted.setBoolean(null,BuildConfig.ROOT_EDITION);}
            catch(Exception e){throw new AssertionError(e);}
            context.startForegroundService(new android.content.Intent(context,OverlayService.class));
        });
        Thread.sleep(1200);assertTrue(serviceRunning(context));screenshot("overlay");
        activity.runOnUiThread(()->{try{deadline.setLong(client,0);}catch(Exception e){throw new AssertionError(e);}});
        Thread.sleep(1200);assertFalse(serviceRunning(context));
        rootGranted.setBoolean(null,false);
    }
    @Test public void readerHelperRequiresRootAndHonorsFlavor() throws Throwable {
        var context=InstrumentationRegistry.getInstrumentation().getTargetContext();
        ProcessBuilder builder=new ProcessBuilder("/system/bin/app_process","/system/bin","vn.mizze.androidviet.RootReaderMain");
        builder.environment().put("CLASSPATH",context.getApplicationInfo().sourceDir);
        Process helper=builder.redirectErrorStream(true).start();
        var executor=java.util.concurrent.Executors.newSingleThreadExecutor();
        try{
            var line=executor.submit(()->{try(var input=new java.io.BufferedReader(new java.io.InputStreamReader(helper.getInputStream()))){String value;while((value=input.readLine())!=null){if(value.startsWith("{"))return value;}return "";}});
            var result=new org.json.JSONObject(line.get(5,java.util.concurrent.TimeUnit.SECONDS));
            assertEquals(BuildConfig.ROOT_EDITION?"root_required":"unsupported",result.getString("state"));
            helper.getOutputStream().close();
            assertTrue("Unprivileged helper must exit",helper.waitFor(3,java.util.concurrent.TimeUnit.SECONDS));
        }finally{helper.destroyForcibly();executor.shutdownNow();}
    }
    @Test public void supportedRootControlsRequireFreshBackend() throws Throwable {
        var ready=RootDataSession.class.getDeclaredField("featuresReady");ready.setAccessible(true);
        var sample=RootDataSession.class.getDeclaredField("sampledAt");sample.setAccessible(true);
        var screen=activity.getActivity();var prefs=new Ui(screen).prefs;
        try{
            // Capability fixture only; no game process or memory write is performed by this widget test.
            ready.setBoolean(null,true);sample.setLong(null,android.os.SystemClock.elapsedRealtime());
            activity.runOnUiThread(()->{
                MenuPanel panel=new MenuPanel(screen,new MenuPanel.Host(){public void closeMenu(){}public void settingsChanged(){}public void stop(){}},0);screen.setContentView(panel);
                View fast=(View)find(panel,"Bắn nhanh (2×)").getParent();assertEquals(BuildConfig.ROOT_EDITION,fast.isEnabled());
                assertFalse(((View)find(panel,"Aim đầu").getParent()).isEnabled());
                if(BuildConfig.ROOT_EDITION){fast.performClick();assertTrue(prefs.getBoolean("FastFire",false));fast.performClick();assertFalse(prefs.getBoolean("FastFire",true));}
                find(panel,"Thiết lập").performClick();assertEquals(BuildConfig.ROOT_EDITION,((View)find(panel,"Speed").getParent()).isEnabled());
            });screenshot("menu-supported-controls");
            sample.setLong(null,0);assertFalse(new AndroidGameData().available("FastFire"));
        }finally{ready.setBoolean(null,false);sample.setLong(null,0);prefs.edit().putBoolean("FastFire",false).putBoolean("ShootNoReload",false).putBoolean("RunSpeed",false).apply();}
    }
    private void resetViewportFixture()throws Exception{for(String key:new String[]{"viewportWidth","viewportHeight","viewportEpoch"}){var field=RootDataSession.class.getDeclaredField(key);field.setAccessible(true);if(key.equals("viewportEpoch"))field.setLong(null,0);else field.setInt(null,0);}}
    @Test public void espAndAimRequireFreshPlayerFrames()throws Throwable{
        resetViewportFixture();
        var players=RootDataSession.class.getDeclaredField("playersReady");players.setAccessible(true);
        var aiming=RootDataSession.class.getDeclaredField("aimReady");aiming.setAccessible(true);
        var at=RootDataSession.class.getDeclaredField("frameAt");at.setAccessible(true);
        var screen=activity.getActivity();var prefs=new Ui(screen).prefs;
        try{
            players.setBoolean(null,true);aiming.setBoolean(null,true);at.setLong(null,android.os.SystemClock.elapsedRealtime());
            activity.runOnUiThread(()->{
                MenuPanel panel=new MenuPanel(screen,new MenuPanel.Host(){public void closeMenu(){}public void settingsChanged(){}public void stop(){}},0);screen.setContentView(panel);
                assertEquals(BuildConfig.ROOT_EDITION,((View)find(panel,"Aim đầu").getParent()).isEnabled());
                assertFalse(((View)find(panel,"Bật Silent Aim").getParent()).isEnabled());
                if(BuildConfig.ROOT_EDITION){((View)find(panel,"Aim đầu").getParent()).performClick();assertTrue(prefs.getBoolean("AimHead",false));((View)find(panel,"Aim cổ").getParent()).performClick();assertFalse(prefs.getBoolean("AimHead",true));assertTrue(prefs.getBoolean("AimNeck",false));prefs.edit().putBoolean("AimNeck",false).apply();}
                find(panel,"ESP").performClick();assertEquals(BuildConfig.ROOT_EDITION,((View)find(panel,"Bật ESP").getParent()).isEnabled());
                if(BuildConfig.ROOT_EDITION){find(panel,"Áp dụng ESP tối giản").performClick();assertTrue(prefs.getBoolean("ESPEnabled",false));assertTrue(prefs.getBoolean("Name",false));assertTrue(prefs.getBoolean("Health",false));assertTrue(prefs.getBoolean("TracerLine",false));}
            });
            at.setLong(null,0);assertFalse(new AndroidGameData().available("ESPEnabled"));assertFalse(new AndroidGameData().available("AimHead"));assertNull(RootDataSession.frame());
        }finally{players.setBoolean(null,false);aiming.setBoolean(null,false);at.setLong(null,0);prefs.edit().putBoolean("ESPEnabled",false).putBoolean("TracerLine",false).putBoolean("AimHead",false).putBoolean("AimNeck",false).apply();}
    }
    @Test public void espSurfaceDrawsOnlyFreshFrames()throws Throwable{
        var players=RootDataSession.class.getDeclaredField("playersReady");players.setAccessible(true);
        var at=RootDataSession.class.getDeclaredField("frameAt");at.setAccessible(true);
        var data=RootDataSession.class.getDeclaredField("frame");data.setAccessible(true);
        var screen=activity.getActivity();var prefs=new Ui(screen).prefs;
        try{
            var bones=new org.json.JSONObject().put("head",new org.json.JSONArray("[0.5,0.2]")).put("hip",new org.json.JSONArray("[0.5,0.5]")).put("leftFoot",new org.json.JSONArray("[0.4,0.8]")).put("rightFoot",new org.json.JSONArray("[0.6,0.8]"));
            data.set(null,new org.json.JSONObject().put("players",new org.json.JSONArray().put(new org.json.JSONObject().put("bones",bones).put("hp",100).put("maxHp",200).put("name","TEST FIXTURE").put("distance",30))));
            players.setBoolean(null,true);at.setLong(null,android.os.SystemClock.elapsedRealtime());prefs.edit().putBoolean("ESPEnabled",true).putBoolean("Skeleton",true).putBoolean("Box",true).putBoolean("TracerLine",true).putBoolean("Name",false).putBoolean("ShowFov",false).putBoolean("AimTargetLine",false).apply();
            activity.runOnUiThread(()->{
                EspView view=new EspView(screen);view.layout(0,0,400,400);
                try{var epoch=RootDataSession.class.getDeclaredField("viewportEpoch");epoch.setAccessible(true);((org.json.JSONObject)data.get(null)).put("width",400).put("height",400).put("viewportEpoch",epoch.getLong(null));players.setBoolean(null,true);at.setLong(null,android.os.SystemClock.elapsedRealtime());}catch(Exception e){throw new AssertionError(e);}
                Bitmap bitmap=Bitmap.createBitmap(400,400,Bitmap.Config.ARGB_8888);view.draw(new android.graphics.Canvas(bitmap));
                assertEquals(BuildConfig.ROOT_EDITION,android.graphics.Color.alpha(bitmap.getPixel(200,160))>0);assertEquals(BuildConfig.ROOT_EDITION,android.graphics.Color.alpha(bitmap.getPixel(200,350))>0);bitmap.eraseColor(android.graphics.Color.TRANSPARENT);
                try{at.setLong(null,0);}catch(Exception e){throw new AssertionError(e);}view.draw(new android.graphics.Canvas(bitmap));assertEquals(0,android.graphics.Color.alpha(bitmap.getPixel(200,160)));bitmap.recycle();
            });
        }finally{players.setBoolean(null,false);at.setLong(null,0);data.set(null,new org.json.JSONObject());prefs.edit().putBoolean("ESPEnabled",false).putBoolean("Skeleton",false).putBoolean("Box",false).putBoolean("TracerLine",false).apply();}
    }
    private boolean serviceRunning(android.content.Context context){
        var manager=(android.app.ActivityManager)context.getSystemService(android.content.Context.ACTIVITY_SERVICE);
        for(var service:manager.getRunningServices(100))if(service.service.getClassName().equals(OverlayService.class.getName()))return true;
        return false;
    }
}
