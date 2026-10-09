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
    private boolean serviceRunning(android.content.Context context){
        var manager=(android.app.ActivityManager)context.getSystemService(android.content.Context.ACTIVITY_SERVICE);
        for(var service:manager.getRunningServices(100))if(service.service.getClassName().equals(OverlayService.class.getName()))return true;
        return false;
    }
}
