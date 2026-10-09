package vn.mizze.androidviet;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.*;
import java.text.DateFormat;
import java.util.Date;

public final class MainActivity extends Activity implements LicenseClient.Listener {
    private Ui ui;
    private LicenseClient license;
    private TextView status, subtitle;
    private EditText key;
    private Button login, start, logout;
    private boolean starting;
    private boolean builtDark;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);ui=new Ui(this);license=((MizzeApp)getApplication()).license();build();
        license.addListener(this);license.startWatching();update();
    }
    private void build(){
        ui=new Ui(this);builtDark=ui.dark();getWindow().setStatusBarColor(ui.bg());getWindow().setNavigationBarColor(ui.bg());
        ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);scroll.setBackgroundColor(ui.bg());
        scroll.setClipToPadding(false);scroll.setPadding(0,ui.dp(24),0,ui.dp(24));
        scroll.setOnApplyWindowInsetsListener((v,insets)->{
            if(Build.VERSION.SDK_INT>=30){android.graphics.Insets bar=insets.getInsets(android.view.WindowInsets.Type.systemBars() | android.view.WindowInsets.Type.ime());v.setPadding(bar.left,bar.top+ui.dp(16),bar.right,bar.bottom+ui.dp(16));}
            return insets;
        });
        LinearLayout outer=ui.column();outer.setGravity(Gravity.CENTER);outer.setPadding(ui.dp(24),0,ui.dp(24),0);
        LinearLayout wrap=ui.column();int width=Math.min(getResources().getDisplayMetrics().widthPixels-ui.dp(48),ui.dp(410));outer.addView(wrap,new LinearLayout.LayoutParams(width,-2));
        TextView brand=ui.bold("mizze /",18,ui.text());ui.add(wrap,brand,42,12);
        LinearLayout card=ui.column();card.setPadding(ui.dp(24),ui.dp(24),ui.dp(24),ui.dp(20));card.setBackground(ui.card(ui.surface(),22));ui.add(wrap,card,-2,18);
        TextView monogram=ui.label("m",27,Ui.MINT);monogram.setGravity(Gravity.CENTER);monogram.setBackground(ui.shape(0x2075DBBA,12));
        LinearLayout.LayoutParams mp=new LinearLayout.LayoutParams(ui.dp(50),ui.dp(50));mp.bottomMargin=ui.dp(18);card.addView(monogram,mp);
        TextView eyebrow=ui.bold("FREE FIRE · PERSONAL SPACE",9,ui.muted());eyebrow.setLetterSpacing(.12f);ui.add(card,eyebrow,20,7);
        TextView title=ui.bold("Tập trung.\nChơi theo ý bạn.",30,ui.text());title.setLineSpacing(0,1.06f);ui.add(card,title,-2,12);
        subtitle=ui.label("Nhập key để mở không gian điều khiển của bạn.",13,ui.muted());ui.add(card,subtitle,-2,18);
        View line=new View(this);line.setBackgroundColor(ui.border());ui.add(card,line,1,16);
        LinearLayout features=ui.row();for(String text:new String[]{"ESP\nMảnh & dịu","FOCUS\nTheo hướng","MENU\nTối giản"}){
            TextView chip=ui.label(text,11,ui.muted());chip.setGravity(Gravity.CENTER);chip.setLineSpacing(ui.dp(4),1);chip.setBackground(ui.shape(ui.raised(),10));
            LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(0,ui.dp(52),1);p.setMargins(ui.dp(3),0,ui.dp(3),0);features.addView(chip,p);
        }ui.add(card,features,52,20);
        ui.add(card,ui.bold("KEY TRUY CẬP",10,ui.muted()),20,8);
        key=new EditText(this);key.setSingleLine(true);key.setHint("Nhập key của bạn");key.setTextSize(14);key.setTextColor(ui.text());key.setHintTextColor(ui.muted());
        key.setTypeface(Typeface.MONOSPACE);key.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
        key.setBackground(ui.card(ui.raised(),12));key.setPadding(ui.dp(15),0,ui.dp(15),0);key.setImeOptions(android.view.inputmethod.EditorInfo.IME_ACTION_GO);
        key.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);key.setContentDescription("Nhập key của bạn");ui.add(card,key,50,12);
        key.setOnEditorActionListener((v,action,event)->{if(action==android.view.inputmethod.EditorInfo.IME_ACTION_GO){submit();return true;}return false;});
        login=ui.button("Đăng nhập",this::submit);login.setBackground(ui.shape(Ui.MINT,13));login.setTextColor(ui.bg());ui.add(card,login,50,10);
        start=ui.button("Start · Mở bảng điều khiển",this::startMenu);ui.add(card,start,50,10);
        logout=ui.button("Đăng xuất",()->{stopService(new Intent(this,OverlayService.class));license.logout();});ui.add(card,logout,40,6);
        status=ui.label("",12,ui.muted());status.setTextIsSelectable(true);ui.add(card,status,-2,10);
        TextView edition=ui.bold(BuildConfig.ROOT_EDITION?"ROOT · Free Fire thường":"NO ROOT · Free Fire thường",10,Ui.MINT);ui.add(card,edition,22,0);
        TextView footer=ui.label("Ít nhiễu hơn. Nhiều tập trung hơn.",10,ui.muted());footer.setGravity(Gravity.CENTER);ui.add(wrap,footer,24,8);
        LinearLayout theme=ui.row();TextView caption=ui.label("Giao diện tối",12,ui.muted());theme.addView(caption,new LinearLayout.LayoutParams(0,ui.dp(40),1));
        Switch toggle=new Switch(this);toggle.setChecked(ui.dark());toggle.setContentDescription("Giao diện tối");theme.addView(toggle);
        toggle.setOnCheckedChangeListener((b,on)->{ui.prefs.edit().putBoolean("DarkTheme",on).apply();build();update();});ui.add(wrap,theme,40,8);
        TextView detail=ui.label(AndroidGameData.description(),11,ui.muted());detail.setGravity(Gravity.CENTER);ui.add(wrap,detail,-2,0);
        scroll.addView(outer,new ScrollView.LayoutParams(-1,-1));setContentView(scroll);applySecure();
    }
    private void submit(){
        if(license.busy())return;((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(key.getWindowToken(),0);
        String raw=key.getText().toString();key.setText("");license.login(raw);
    }
    private void startMenu(){
        if(starting || !license.authorized())return;
        if(!Settings.canDrawOverlays(this)){
            try{startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:"+getPackageName())));}
            catch(Exception e){new AlertDialog.Builder(this).setMessage("Mở Cài đặt → Ứng dụng → Android Việt → Hiển thị trên ứng dụng khác, rồi bấm Start lại.").setPositiveButton("OK",null).show();}
            status.setText("Cho phép hiển thị trên ứng dụng khác, quay lại rồi nhấn Start.");return;
        }
        if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},10);
        if(BuildConfig.ROOT_EDITION){
            starting=true;update();status.setText("Đang xin quyền root. Chọn Cho phép trong Magisk/SuperSU…");
            RootAccess.request((ok,detail)->{starting=false;if(isFinishing()||isDestroyed())return;update();status.setText(detail);if(ok)launchOverlay();});
        }else launchOverlay();
    }
    private void launchOverlay(){
        if(!license.authorized()){update();return;}
        try{startForegroundService(new Intent(this,OverlayService.class));status.setText("Menu đang mở. Chạm × để thu gọn, chạm m để mở lại.");}
        catch(Exception e){status.setText("Android chưa cho phép mở menu nổi. Kiểm tra quyền rồi nhấn Start lại.");}
    }
    private void applySecure(){if(ui.prefs.getBoolean("AnLive",false))getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);}
    private void update(){
        boolean auth=license.authorized();login.setEnabled(!license.busy()&&!starting);login.setAlpha(login.isEnabled()?1:.5f);login.setText(license.busy()?"Đang xác thực…":"Đăng nhập");
        start.setEnabled(auth&&!starting);start.setAlpha(start.isEnabled()?1:.4f);logout.setVisibility(license.hasSavedKey()||auth?View.VISIBLE:View.GONE);
        key.setEnabled(!license.busy()&&!starting);status.setText(license.message());
        subtitle.setText(auth?"Phiên đã xác thực · Hết hạn "+DateFormat.getDateTimeInstance(DateFormat.SHORT,DateFormat.SHORT).format(new Date(license.expiresAt())):"Nhập key để mở không gian điều khiển của bạn.");
        applySecure();
    }
    @Override public void onLicenseChanged(){update();}
    @Override protected void onResume(){super.onResume();if(license!=null){if(ui.dark()!=builtDark)build();applySecure();license.refresh();update();}}
    @Override protected void onDestroy(){license.removeListener(this);super.onDestroy();}
}
