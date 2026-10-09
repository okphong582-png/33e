package vn.mizze.androidviet;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import org.json.JSONObject;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import javax.net.ssl.HttpsURLConnection;

final class LicenseClient {
    interface Listener { void onLicenseChanged(); }
    private final SharedPreferences prefs;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ScheduledExecutorService worker = Executors.newSingleThreadScheduledExecutor();
    private final CopyOnWriteArrayList<Listener> listeners = new CopyOnWriteArrayList<>();
    private final String baseUrl, device;
    private volatile long deadline, expires;
    private volatile String message = "Kết nối mạng để xác thực key.";
    private volatile boolean busy;
    private int generation;
    private boolean watched;

    LicenseClient(Context context) {
        prefs = context.getSharedPreferences("license", Context.MODE_PRIVATE);
        String config;
        try (InputStream stream = context.getResources().openRawResource(R.raw.license_config)) {
            config = new JSONObject(readBounded(stream)).getString("databaseUrl");
            URL url = new URL(config);
            if (!url.getProtocol().equals("https") || url.getHost().isEmpty() || url.getQuery() != null ||
                    url.getRef() != null || url.getUserInfo() != null) throw new IllegalArgumentException();
        } catch (Exception e) { config = ""; }
        baseUrl = config.replaceAll("/+$", "");
        String id = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ANDROID_ID);
        device = id == null || id.isEmpty() ? "" : hash("mizze-android-device-v1:" + id);
    }
    static String hash(String value) {
        try {
            byte[] bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder();
            for (byte b : bytes) out.append(String.format(Locale.ROOT, "%02x", b & 255));
            return out.toString();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }
    static String normalize(String key) { return key.trim().toUpperCase(Locale.ROOT); }
    boolean authorized() { return SystemClock.elapsedRealtime() < deadline; }
    long leaseDeadline() { return authorized() ? deadline : 0; }
    boolean busy() { return busy; }
    String message() { return message; }
    long expiresAt() { return expires; }
    boolean hasSavedKey() { return prefs.getString("hash", "").matches("[0-9a-f]{64}"); }
    void addListener(Listener listener) { listeners.addIfAbsent(listener); }
    void removeListener(Listener listener) { listeners.remove(listener); }
    private void publish() { for (Listener listener : listeners) listener.onLicenseChanged(); }
    // Called only on the main thread; no saved lease survives process death.
    void startWatching() {
        if (watched) return;
        watched = true;
        main.post(tick);
        if (hasSavedKey()) refresh();
    }
    private final Runnable tick = new Runnable() {
        private long nextRefresh;
        @Override public void run() {
            long now = SystemClock.elapsedRealtime();
            if (deadline != 0 && !authorized()) {
                deadline = 0; message = "Phiên xác thực hết hạn. Kết nối mạng và đăng nhập lại."; publish();
            }
            if (now >= nextRefresh) { nextRefresh = now + 8000; if (hasSavedKey()) refresh(); }
            main.postDelayed(this, 500);
        }
    };
    void login(String rawKey) {
        if (busy) return;
        String normalized = normalize(rawKey);
        if (normalized.isEmpty() || normalized.length() > 256) { message = "Vui lòng nhập key hợp lệ."; publish(); return; }
        // Switching accounts must immediately revoke the previous overlay lease.
        generation++; deadline = 0; expires = 0;
        prefs.edit().remove("hash").apply();
        request(hash(normalized), true);
    }
    void refresh() { if (!busy && hasSavedKey()) request(prefs.getString("hash", ""), false); }
    void logout() {
        generation++; busy = false; deadline = 0; expires = 0;
        prefs.edit().remove("hash").apply(); message = "Đã đăng xuất."; publish();
    }
    private void request(String licenseHash, boolean allowBinding) {
        if (baseUrl.isEmpty() || device.isEmpty()) {
            deadline = 0; message = "Thiếu cấu hình máy chủ hoặc mã thiết bị Android."; publish(); return;
        }
        busy = true; int token = generation;
        if (!authorized()) message = "Đang xác thực…";
        publish();
        worker.execute(() -> {
            LicensePolicy.Result result = null; String failure = "Không kết nối được máy chủ. Kiểm tra mạng và thử lại.";
            boolean transientError = true;
            try {
                Reply reply = get(licenseHash);
                result = evaluate(reply, allowBinding);
                if (result.needsBinding()) { claim(licenseHash); result = evaluate(get(licenseHash), false); }
                transientError = false;
            } catch (ServerFailure e) { failure = e.getMessage(); transientError = e.retryable; }
              catch (Exception e) { /* No key, hashes or server responses in logs. */ }
            LicensePolicy.Result finalResult = result; String finalFailure = failure; boolean retryable = transientError;
            main.post(() -> {
                if (token != generation) return;
                busy = false;
                if (finalResult != null && finalResult.valid(SystemClock.elapsedRealtime())) {
                    deadline = finalResult.deadline(); expires = finalResult.expiresAt(); message = finalResult.message();
                    prefs.edit().putString("hash", licenseHash).apply();
                } else if (retryable && authorized()) {
                    message = "Mạng tạm gián đoạn; phiên hiện tại tối đa 30 giây.";
                } else {
                    deadline = 0; expires = 0;
                    message = finalResult == null ? finalFailure : finalResult.message();
                }
                publish();
            });
        });
    }
    private record Reply(int status, String body, long serverTime, long started) {}
    private static class ServerFailure extends Exception {
        final boolean retryable;
        ServerFailure(String message, boolean retryable) { super(message); this.retryable = retryable; }
    }
    private LicensePolicy.Result evaluate(Reply reply, boolean allowBinding) throws Exception {
        int status = reply.status();
        if (status != 200) throw new ServerFailure(status == 401 || status == 403 ?
            "Firebase từ chối truy cập. Người cấp key cần kiểm tra Rules." : "Máy chủ xác thực báo lỗi HTTP " + status,
            status == 408 || status == 429 || status >= 500);
        if (reply.body().trim().equals("null")) return LicensePolicy.denied("Key không tồn tại hoặc đã bị xóa.");
        JSONObject record;
        try { record = new JSONObject(reply.body()); }
        catch (Exception e) { return LicensePolicy.denied("Dữ liệu key không hợp lệ."); }
        return LicensePolicy.evaluate(record, device, reply.serverTime(), reply.started(), SystemClock.elapsedRealtime(), allowBinding);
    }
    private HttpsURLConnection connection(String suffix) throws Exception {
        HttpsURLConnection conn = (HttpsURLConnection)new URL(baseUrl + "/licensesV4/" + suffix).openConnection();
        conn.setConnectTimeout(5000); conn.setReadTimeout(5000); conn.setUseCaches(false);
        conn.setInstanceFollowRedirects(false);
        conn.setRequestProperty("Cache-Control", "no-cache, no-store");
        return conn;
    }
    private Reply get(String hash) throws Exception {
        long started = SystemClock.elapsedRealtime();
        HttpsURLConnection conn = connection(hash + ".json");
        try {
            int status = conn.getResponseCode();
            return new Reply(status, status == 200 ? readBounded(conn.getInputStream()) : "", conn.getHeaderFieldDate("Date", 0), started);
        } finally { conn.disconnect(); }
    }
    private void claim(String hash) throws Exception {
        HttpsURLConnection conn = connection(hash + "/binding.json");
        try {
            conn.setRequestMethod("PUT"); conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            conn.setRequestProperty("if-match", "null_etag");
            byte[] payload = new JSONObject().put("deviceHash", device).put("version", 1)
                .put("claimedAt", new JSONObject().put(".sv", "timestamp")).toString().getBytes(StandardCharsets.UTF_8);
            conn.setFixedLengthStreamingMode(payload.length);
            try (var out = conn.getOutputStream()) { out.write(payload); }
            conn.getResponseCode(); // Never authorize from a PUT; always re-read binding, including 412 races.
        } finally { conn.disconnect(); }
    }
    private static String readBounded(InputStream input) throws Exception {
        try (InputStream in = input; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[2048]; int n;
            while ((n = in.read(buffer)) != -1) { if (out.size() + n > 32768) throw new IllegalArgumentException("Response too large"); out.write(buffer, 0, n); }
            return out.toString(StandardCharsets.UTF_8.name());
        }
    }
}
