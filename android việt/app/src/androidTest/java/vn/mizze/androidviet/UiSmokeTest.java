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
    private void screenshot(String name) throws Exception {
        InstrumentationRegistry.getInstrumentation().waitForIdleSync();Thread.sleep(250);
        Bitmap bitmap=InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();assertNotNull(bitmap);
        File file=new File(activity.getActivity().getExternalFilesDir(null),name+".png");
        try(var output=new FileOutputStream(file)){assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG,100,output));}bitmap.recycle();
    }
    @Test public void loginRequiresKeyAndStartIsLocked() throws Exception {
        activity.runOnUiThread(()->{
            View root=activity.getActivity().getWindow().getDecorView();
            assertNotNull(find(root,"Tập trung.\nChơi theo ý bạn."));
            assertFalse(find(root,"Start · Mở bảng điều khiển").isEnabled());
            find(root,"Đăng nhập").performClick();
            assertNotNull(find(root,"Vui lòng nhập key hợp lệ."));
        });screenshot("login");
    }
    @Test public void menuTabsShowRealCapabilityAndSettingsPersist() throws Exception {
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
}
