package vn.mizze.androidviet;

import android.app.*;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.content.res.Configuration;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.view.*;
import android.widget.*;

public final class OverlayService extends Service implements LicenseClient.Listener, SharedPreferences.OnSharedPreferenceChangeListener {
    static final String STOP = "vn.mizze.androidviet.STOP";
    private final Handler main=new Handler(Looper.getMainLooper());
    private LicenseClient license;
    private Ui ui;
    private RootDataSession rootData;
    private WindowManager manager;
    private View overlay;
    private EspView esp;
    private WindowManager.LayoutParams espParams;
    private WindowManager.LayoutParams params;
    private boolean expanded=true;
    private int page,x=16,y=24;
    @Override public void onCreate(){
        super.onCreate();ui=new Ui(this);license=((MizzeApp)getApplication()).license();manager=(WindowManager)getSystemService(WINDOW_SERVICE);
        license.addListener(this);ui.prefs.registerOnSharedPreferenceChangeListener(this);
    }
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null&&STOP.equals(intent.getAction())){stopSelf();return START_NOT_STICKY;}
        if(!license.authorized() || !Settings.canDrawOverlays(this) || (BuildConfig.ROOT_EDITION&&!RootAccess.granted())){stopSelf();return START_NOT_STICKY;}
        NotificationManager nm=(NotificationManager)getSystemService(NOTIFICATION_SERVICE);
        nm.createNotificationChannel(new NotificationChannel("menu","Menu Android Việt",NotificationManager.IMPORTANCE_LOW));
        PendingIntent open=PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,OverlayService.class).setAction(STOP),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        Notification notification=new Notification.Builder(this,"menu").setSmallIcon(R.drawable.ic_mizze)
            .setContentTitle(BuildConfig.ROOT_EDITION?"Android Việt · Root":"Android Việt · No Root")
            .setContentText("Menu nổi đang chạy · Xem trạng thái trong Thiết lập").setContentIntent(open).setOngoing(true)
            .addAction(new Notification.Action.Builder(null,"Dừng menu",stop).build()).build();
        if(Build.VERSION.SDK_INT>=34)startForeground(1,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);else startForeground(1,notification);
        if(BuildConfig.ROOT_EDITION&&rootData==null){rootData=new RootDataSession(this,license);rootData.start();}
        expanded=true;showEsp();showOverlay();RootDataSession.listenFrames(()->main.post(render));main.removeCallbacks(guard);main.removeCallbacks(render);main.post(render);main.post(guard);return START_NOT_STICKY;
    }
    private final Runnable guard=new Runnable(){@Override public void run(){
        if(!license.authorized()||!Settings.canDrawOverlays(OverlayService.this)){stopSelf();return;}
        if(rootData!=null)rootData.renew();
        if(overlay instanceof MenuPanel)((MenuPanel)overlay).refreshDataStatus();
        main.postDelayed(this,500);
    }};
    private org.json.JSONObject renderedFrame;
    private final Runnable render=new Runnable(){@Override public void run(){main.removeCallbacks(this);org.json.JSONObject current=RootDataSession.frame();if(esp!=null&&current!=renderedFrame){renderedFrame=current;esp.postInvalidateOnAnimation();}main.postDelayed(this,ui.prefs.getBoolean("BalancedRender",false)?33:250);}};
    private void showEsp(){
        if(!BuildConfig.ROOT_EDITION||esp!=null)return;
        esp=new EspView(this);espParams=new WindowManager.LayoutParams(-1,-1,WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE|WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,PixelFormat.TRANSLUCENT);
        espParams.gravity=Gravity.TOP|Gravity.START;espParams.alpha=.75f;
        if(Build.VERSION.SDK_INT>=28)espParams.layoutInDisplayCutoutMode=WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        if(Build.VERSION.SDK_INT>=30)espParams.setFitInsetsTypes(0);
        if(ui.prefs.getBoolean("AnLive",false))espParams.flags|=WindowManager.LayoutParams.FLAG_SECURE;
        try{manager.addView(esp,espParams);}catch(RuntimeException e){esp=null;stopSelf();}
    }
    private DisplayMetrics metrics(){DisplayMetrics dm=new DisplayMetrics();manager.getDefaultDisplay().getMetrics(dm);return dm;}
    private void showOverlay(){
        removeOverlay();ui=new Ui(this);DisplayMetrics dm=metrics();
        int width=expanded?Math.min(ui.dp(410),dm.widthPixels-ui.dp(16)):ui.dp(52);
        int height=expanded?Math.min(ui.dp(540),dm.heightPixels-ui.dp(32)):ui.dp(52);
        int flags=WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL;
        if(ui.prefs.getBoolean("AnLive",false))flags|=WindowManager.LayoutParams.FLAG_SECURE;
        params=new WindowManager.LayoutParams(Math.max(ui.dp(180),width),Math.max(ui.dp(200),height),WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,flags,PixelFormat.TRANSLUCENT);
        if(!expanded){params.width=width;params.height=height;}
        params.gravity=Gravity.TOP|Gravity.START;params.x=x;params.y=y;clamp();
        if(expanded){
            MenuPanel panel=new MenuPanel(this,new MenuPanel.Host(){
                public void closeMenu(){page=((MenuPanel)overlay).page();expanded=false;showOverlay();}
                public void settingsChanged(){updateSecure();}
                public void stop(){stopSelf();}
            },page);overlay=panel;drag(panel.header,null);
        }else{
            Button bubble=ui.button("m",()->{expanded=true;showOverlay();});bubble.setTextSize(27);bubble.setBackground(ui.card(ui.surface(),16));bubble.setContentDescription("Mở menu Mizze");overlay=bubble;
            drag(bubble,()->{expanded=true;showOverlay();});
        }
        try{manager.addView(overlay,params);}
        catch(RuntimeException e){overlay=null;Toast.makeText(this,"Không thể mở menu nổi. Kiểm tra quyền hiển thị trên ứng dụng khác.",Toast.LENGTH_LONG).show();stopSelf();}
    }
    private void updateSecure(){
        if(esp!=null){if(ui.prefs.getBoolean("AnLive",false))espParams.flags|=WindowManager.LayoutParams.FLAG_SECURE;else espParams.flags&=~WindowManager.LayoutParams.FLAG_SECURE;
            try{manager.updateViewLayout(esp,espParams);}catch(RuntimeException e){stopSelf();}}
        if(overlay==null||params==null)return;
        if(ui.prefs.getBoolean("AnLive",false))params.flags|=WindowManager.LayoutParams.FLAG_SECURE;else params.flags&=~WindowManager.LayoutParams.FLAG_SECURE;
        try{manager.updateViewLayout(overlay,params);}catch(RuntimeException e){stopSelf();}
    }
    private void clamp(){DisplayMetrics dm=metrics();params.x=Math.max(0,Math.min(params.x,Math.max(0,dm.widthPixels-params.width)));params.y=Math.max(0,Math.min(params.y,Math.max(0,dm.heightPixels-params.height-ui.dp(24))));x=params.x;y=params.y;}
    private void drag(View view,Runnable tap){view.setOnTouchListener(new View.OnTouchListener(){
        float downX,downY;int oldX,oldY;boolean moved;
        @Override public boolean onTouch(View v,MotionEvent event){
            switch(event.getActionMasked()){
                case MotionEvent.ACTION_DOWN:downX=event.getRawX();downY=event.getRawY();oldX=params.x;oldY=params.y;moved=false;return true;
                case MotionEvent.ACTION_MOVE:float dx=event.getRawX()-downX,dy=event.getRawY()-downY;
                    if(Math.abs(dx)+Math.abs(dy)>ui.dp(5))moved=true;
                    if(moved){params.x=oldX+Math.round(dx);params.y=oldY+Math.round(dy);clamp();try{manager.updateViewLayout(overlay,params);}catch(RuntimeException e){stopSelf();}}return true;
                case MotionEvent.ACTION_UP:if(!moved&&tap!=null)v.performClick();return true;
                case MotionEvent.ACTION_CANCEL:return true;
                default:return false;
            }
        }
    });}
    private void removeOverlay(){if(overlay!=null){try{manager.removeView(overlay);}catch(RuntimeException ignored){}overlay=null;}}
    @Override public void onLicenseChanged(){if(!license.authorized()){Toast.makeText(this,license.message(),Toast.LENGTH_LONG).show();stopSelf();}}
    @Override public void onSharedPreferenceChanged(SharedPreferences prefs,String key){
        if(rootData!=null)rootData.renew();
        if(esp!=null)esp.postInvalidateOnAnimation();
        if("AnLive".equals(key))updateSecure();
        if("DarkTheme".equals(key)){if(overlay instanceof MenuPanel)page=((MenuPanel)overlay).page();showOverlay();}
    }
    @Override public void onConfigurationChanged(Configuration config){super.onConfigurationChanged(config);if(overlay instanceof MenuPanel)page=((MenuPanel)overlay).page();showOverlay();}
    @Override public void onDestroy(){RootDataSession.listenFrames(null);main.removeCallbacksAndMessages(null);if(esp!=null){try{manager.removeView(esp);}catch(RuntimeException ignored){}esp=null;}if(rootData!=null)rootData.close();removeOverlay();license.removeListener(this);ui.prefs.unregisterOnSharedPreferenceChangeListener(this);stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();}
    @Override public IBinder onBind(Intent intent){return null;}
}
