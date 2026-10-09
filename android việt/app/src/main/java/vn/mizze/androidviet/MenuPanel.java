package vn.mizze.androidviet;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.widget.*;
import java.util.Locale;

/** Native Android rendition of sources/_0xMO353DA.mm; game capability is explicit. */
final class MenuPanel extends LinearLayout {
    interface Host { void closeMenu(); void settingsChanged(); void stop(); }
    private final Ui ui;
    private final Host host;
    private final AndroidGameData data = new AndroidGameData();
    private final LinearLayout content;
    private final ScrollView scroll;
    private final Button[] tabs = new Button[4];
    final LinearLayout header;
    private int page;
    private int colorTarget;
    private TextView swatch;
    private int builtReady;
    MenuPanel(Context context,Host host,int initialPage) {
        super(context);this.host=host;ui=new Ui(context);page=initialPage;
        setOrientation(VERTICAL);setPadding(ui.dp(14),ui.dp(8),ui.dp(14),ui.dp(12));
        setBackground(ui.card(ui.surface(),18));setClipToOutline(true);setElevation(ui.dp(8));
        header=ui.row();TextView monogram=ui.bold("m",23,Ui.MINT);monogram.setGravity(Gravity.CENTER);
        monogram.setBackground(ui.shape(0x2075DBBA,10));header.addView(monogram,new LayoutParams(ui.dp(36),ui.dp(36)));
        LinearLayout title=ui.column();title.setPadding(ui.dp(10),0,0,0);
        title.addView(ui.bold("mizze",20,ui.text()));title.addView(ui.label("AIM / ESP",9,ui.muted()));
        header.addView(title,new LayoutParams(0,ui.dp(48),1));
        Button close=ui.button("×",host::closeMenu);close.setTextSize(26);close.setContentDescription("Thu gọn menu");header.addView(close,new LayoutParams(ui.dp(44),ui.dp(44)));
        ui.add(this,header,50,4);
        LinearLayout nav=ui.row();String[] names={"Aim","ESP","Màu sắc","Thiết lập"};
        for(int i=0;i<4;i++){final int index=i;tabs[i]=ui.button(names[i],()->{page=index;scrollTopAndBuild();});tabs[i].setTextSize(12);tabs[i].setPadding(0,0,0,0);
            LayoutParams p=new LayoutParams(0,ui.dp(44),1);p.setMargins(ui.dp(2),0,ui.dp(2),0);nav.addView(tabs[i],p);}
        ui.add(this,nav,44,6);
        scroll=new ScrollView(context);scroll.setFillViewport(false);content=ui.column();scroll.addView(content,new ScrollView.LayoutParams(-1,-2));
        addView(scroll,new LayoutParams(-1,0,1));build();
    }
    int page(){return page;}
    void refreshDataStatus(){int ready=RootDataSession.capabilityMask();if(ready!=builtReady){builtReady=ready;int y=scroll.getScrollY();build();scroll.post(()->scroll.scrollTo(0,y));}}
    private void scrollTopAndBuild(){build();scroll.post(()->scroll.scrollTo(0,0));}
    private void build(){
        builtReady=RootDataSession.capabilityMask();content.removeAllViews();swatch=null;
        for(int i=0;i<4;i++){tabs[i].setTextColor(i==page?Ui.MINT:ui.muted());tabs[i].setBackground(ui.shape(i==page?0x1875DBBA:Color.TRANSPARENT,9));tabs[i].setSelected(i==page);}
        switch(page){case 0->aim();case 1->esp();case 2->colors();default->settings();}
        TextView credit=ui.label("HoangHaDev",10,ui.muted());credit.setGravity(Gravity.CENTER);ui.add(content,credit,36,0);
    }
    private void section(String text){TextView v=ui.bold(text,14,Ui.MINT);v.setPadding(ui.dp(4),ui.dp(8),0,0);ui.add(content,v,40,0);}
    private void notice(String text){TextView v=ui.label(text,12,ui.muted());v.setPadding(ui.dp(8),ui.dp(6),ui.dp(8),ui.dp(6));ui.add(content,v,-2,8);}
    private void toggle(String title,String key,boolean fallback,boolean game){
        boolean available=!game || AndroidGameData.configurableAim(key) || data.available(key) || AndroidGameData.implemented(key)&&ui.prefs.getBoolean(key,fallback);boolean value=(!game||AndroidGameData.implemented(key)) && ui.prefs.getBoolean(key,fallback);
        LinearLayout row=ui.row();row.setPadding(ui.dp(14),0,ui.dp(12),0);row.setBackground(ui.shape(ui.raised(),10));
        TextView label=ui.label(title,14,ui.text());row.addView(label,new LayoutParams(0,-1,1));
        CrossCheck box=new CrossCheck(getContext(),value);row.addView(box,new LayoutParams(ui.dp(34),ui.dp(34)));
        row.setEnabled(available);box.setEnabled(available);row.setAlpha(available?1:.48f);
        row.setContentDescription(title+(available?"":" · Chưa sẵn sàng"));
        if(available)row.setOnClickListener(v->{boolean next=!ui.prefs.getBoolean(key,fallback);var edit=ui.prefs.edit().putBoolean(key,next);
            if(next&&(key.equals("AimHead")||key.equals("AimNeck")||key.equals("SilentAim"))
                &&!ui.prefs.getBoolean("AimbotFire",false)&&!ui.prefs.getBoolean("AimbotScope",false)&&!ui.prefs.getBoolean("AimHipAlways",false)&&!ui.prefs.getBoolean("AimFireAndScope",false))edit.putBoolean("AimbotFire",true);
            if(next&&key.equals("AimHead"))edit.putBoolean("AimNeck",false);if(next&&key.equals("AimNeck"))edit.putBoolean("AimHead",false);
            edit.apply();box.setChecked(next);host.settingsChanged();if(key.equals("AimHead")||key.equals("AimNeck")||key.equals("SilentAim")){int y=scroll.getScrollY();build();scroll.post(()->scroll.scrollTo(0,y));}});
        ui.add(content,row,54,8);
    }
    private void slider(String title,String key,float min,float max,float fallback,boolean game){
        LinearLayout row=ui.column();row.setPadding(ui.dp(14),ui.dp(8),ui.dp(14),0);row.setBackground(ui.shape(ui.raised(),10));
        TextView label=ui.label("",14,ui.text());row.addView(label,new LayoutParams(-1,ui.dp(26)));
        SeekBar seek=new SeekBar(getContext());seek.setMax(1000);seek.setProgress(Math.round((ui.prefs.getFloat(key,fallback)-min)*1000/(max-min)));
        seek.setProgressTintList(ColorStateList.valueOf(Ui.MINT));seek.setThumbTintList(ColorStateList.valueOf(ui.text()));seek.setContentDescription(title);
        Runnable update=()->{float value=min+(max-min)*seek.getProgress()/1000f;
            String formatted=max<=1?String.format(Locale.ROOT,"%.0f",value*255):String.format(Locale.ROOT,max<=6?"%.1f":"%.0f",value);
            label.setText(title+"   "+formatted);};update.run();
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onStartTrackingTouch(SeekBar s){}public void onStopTrackingTouch(SeekBar s){}
            public void onProgressChanged(SeekBar s,int n,boolean fromUser){if(fromUser){ui.prefs.edit().putFloat(key,min+(max-min)*n/1000f).apply();update.run();updateSwatch();}}});
        seek.setEnabled(!game || AndroidGameData.configurableAim(key) || data.available(key));row.setAlpha(seek.isEnabled()?1:.48f);row.addView(seek,new LayoutParams(-1,ui.dp(48)));ui.add(content,row,88,8);
    }
    private void gameToggle(String title,String key){toggle(title,key,false,true);}
    private void aim(){
        section("Loại aim");gameToggle("Aim đầu","AimHead");gameToggle("Aim cổ","AimNeck");gameToggle("Bật Silent Aim","SilentAim");
        section("Kích hoạt");gameToggle("Khi bắn","AimbotFire");gameToggle("Khi mở ngắm","AimbotScope");gameToggle("Luôn luôn","AimHipAlways");gameToggle("Fire + Scope (cùng lúc)","AimFireAndScope");
        gameToggle("Aimlag khi ngắm","AimLag");gameToggle("Dây tới mục tiêu","AimTargetLine");
        slider("FOV (%)","FovSize",5,48,40,true);slider("FOV Silent (%)","SilentFovSize",5,48,18,true);
        gameToggle("Hiện vòng FOV","ShowFov");gameToggle("AimKill","AutoFireFloating");slider("Tỷ lệ headshot (%)","SilentHeadPercent",0,100,75,true);
        section("Súng");gameToggle("Bắn nhanh (2×)","FastFire");gameToggle("Không nạp đạn","ShootNoReload");
        section("Nâng cao");gameToggle("Tự chọn tầm Silent","SilentAutoConfig");slider("Tầm chọn Silent (m)","SilentMaxDistance",10,150,100,true);
    }
    private void esp(){
        gameToggle("Bật ESP","ESPEnabled");Button preset=ui.button("Áp dụng ESP tối giản",()->{ui.prefs.edit().putBoolean("ESPEnabled",true).putBoolean("CleanESP",true).putBoolean("Name",true).putBoolean("Health",true).putBoolean("Dis",true).putBoolean("Box",true).putBoolean("TracerLine",true).putBoolean("Skeleton",false).putBoolean("Line",false).putBoolean("Box3D",false).putBoolean("HeadRedDot",false).apply();build();});preset.setEnabled(data.canReadPlayers());preset.setAlpha(data.canReadPlayers()?1:.48f);ui.add(content,preset,48,8);
        String[][] fields={{"Khung góc mảnh","CleanESP"},{"Tên người chơi","Name"},{"Thanh máu","Health"},{"Trục XYZ","Line"},{"Đường nối tới người chơi","TracerLine"},{"Khung người chơi","Box"},{"Xương người chơi","Skeleton"},{"Điểm đánh dấu đầu","HeadRedDot"},{"Khoảng cách","Dis"},{"Khung 3D (tắt = 2D)","Box3D"}};
        for(String[] f:fields)gameToggle(f[0],f[1]);slider("Tầm hiển thị ESP (m)","ESPMaxDistance",50,500,150,true);
        slider("Vàng khi máu ≤ (%)","HealthYellowPercent",10,90,50,true);slider("Đỏ khi máu ≤ (%)","HealthRedPercent",5,80,25,true);
    }
    private void colors(){
        notice("Màu áp dụng cho khung ESP và vòng FOV khi có dữ liệu game.");
        LinearLayout row=ui.row();for(int i=0;i<2;i++){final int selected=i;Button b=ui.button(i==0?"Box":"FOV",()->{colorTarget=selected;build();});b.setTextColor(i==colorTarget?Ui.MINT:ui.muted());row.addView(b,new LayoutParams(0,ui.dp(44),1));}ui.add(content,row,44,10);
        swatch=ui.bold("",14,Color.BLACK);swatch.setGravity(Gravity.CENTER);ui.add(content,swatch,40,10);
        String prefix=colorTarget==0?"BoxColor":"FovColor";String[] labels={"Đỏ","Lục","Lam"},suffix={"R","G","B"};float[] defaults={.46f,.86f,.73f};
        for(int i=0;i<3;i++)slider(labels[i],prefix+suffix[i],0,1,defaults[i],false);updateSwatch();
    }
    private void updateSwatch(){if(swatch==null)return;String prefix=colorTarget==0?"BoxColor":"FovColor";
        int r=Math.round(ui.prefs.getFloat(prefix+"R",.46f)*255),g=Math.round(ui.prefs.getFloat(prefix+"G",.86f)*255),b=Math.round(ui.prefs.getFloat(prefix+"B",.73f)*255);
        swatch.setBackground(ui.shape(Color.rgb(r,g,b),9));swatch.setText(String.format(Locale.ROOT,"#%02X%02X%02X",r,g,b));swatch.setTextColor(r*.299+g*.587+b*.114>153?Color.BLACK:Color.WHITE);
    }
    private void settings(){
        section("Khởi động");toggle("Tự bật khi vào trận","AutoFeatures",BuildConfig.ROOT_EDITION,false);section("Nút nổi");gameToggle("Ghost","GhostModeFloating");gameToggle("FakeLag","FakeLagFloating");gameToggle("Fly","FlyFloating");gameToggle("Ẩn nút chức năng","HideFeatureButtons");gameToggle("Nút Speed","RunSpeedFloating");
        section("Di chuyển");slider("Độ cao Fly (m)","FlyHeight",1,6,4,true);gameToggle("Speed","RunSpeed");
        slider("Tốc độ (m/s)","RunSpeedValue",.1f,30,6,true);
        section("Hiệu ứng nhân vật");gameToggle("Spin · chỉ mình thấy","VisualSpin");slider("Vòng / giây","VisualSpinSpeed",.1f,3,.5f,true);
        section("Giao diện Android");toggle("Ẩn khi chụp / quay","AnLive",false,false);toggle("Giao diện tối","DarkTheme",true,false);
        // No game renderer exists in the non-root adapter, so FPS must not claim to affect it.
        gameToggle("Tiết kiệm pin (30 FPS)","BalancedRender");
        Button stop=ui.button("Dừng menu",host::stop);ui.add(content,stop,48,8);
    }
}
