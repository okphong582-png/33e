package vn.mizze.androidviet;

import android.os.Handler;
import android.os.Looper;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/** Explicit, bounded root request. No background auto-grant or SELinux changes. */
final class RootAccess {
    interface Callback { void complete(boolean granted, String detail); }
    private static final java.util.concurrent.ExecutorService REQUESTS = Executors.newSingleThreadExecutor();
    private static volatile boolean granted;
    private static volatile String detail = "Chưa cấp quyền root.";
    private static volatile String maps = "";
    private static final String PROBE = "id -u; p=$(pidof com.dts.freefireth); p=\"${p%% *}\"; case \"$p\" in ''|*[!0-9]*) echo MIZZE_GAME_NOT_RUNNING;; *) echo MIZZE_PID=$p; cat /proc/$p/maps 2>/dev/null | grep -m 4 libil2cpp.so;; esac; true";
    static boolean granted() { return BuildConfig.ROOT_EDITION && granted; }
    static String detail() { return detail; }
    static String maps() { return maps; }
    static void request(Callback callback) {
        if (!BuildConfig.ROOT_EDITION) { callback.complete(false, "Bản No Root không yêu cầu quyền root."); return; }
        REQUESTS.execute(() -> {
            boolean ok=false;String status="Không tìm thấy su/Magisk. Hãy dùng bản No Root nếu máy chưa root.";
            Process process=null;
            var reader=Executors.newSingleThreadExecutor();
            try {
                process=new ProcessBuilder("su","-c",PROBE).redirectErrorStream(true).start();
                final Process active=process;
                var output=reader.submit(()->{
                    ByteArrayOutputStream bytes=new ByteArrayOutputStream();byte[] buffer=new byte[1024];int n;
                    try(var in=active.getInputStream()) { while((n=in.read(buffer))!=-1) { if(bytes.size()+n>32768) throw new IllegalStateException("Root output too large"); bytes.write(buffer,0,n); } }
                    return bytes.toString(StandardCharsets.UTF_8.name());
                });
                if(!process.waitFor(60,TimeUnit.SECONDS)) { process.destroyForcibly();status="Hết thời gian chờ. Hãy cho phép quyền trong Magisk rồi thử lại."; }
                else {
                    String text=output.get(2,TimeUnit.SECONDS);
                    String[] lines=text.trim().split("\r?\n");
                    ok=process.exitValue()==0 && lines.length>0 && lines[0].trim().equals("0");
                    if(ok) {
                        maps=text;
                        status=text.contains("MIZZE_GAME_NOT_RUNNING")?"Đã cấp root · Chưa mở Free Fire thường.":
                            text.contains("libil2cpp.so")?"Đã cấp root · Đọc được bản đồ libil2cpp.so.":"Đã cấp root · Chưa đọc được libil2cpp.so (game/SELinux).";
                    } else status="Quyền root bị từ chối. Hãy cấp quyền cho bản Root trong Magisk/SuperSU.";
                }
            } catch(Exception e) { /* A missing su or denied command is a capability result. */ }
            finally {if(process!=null)process.destroy();reader.shutdownNow();}
            granted=ok;detail=status;
            boolean result=ok;String message=status;
            new Handler(Looper.getMainLooper()).post(()->callback.complete(result,message));
        });
    }
}
