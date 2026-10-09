package vn.mizze.androidviet;
import android.app.Application;
public final class MizzeApp extends Application {
    private LicenseClient license;
    @Override public void onCreate() { super.onCreate(); license = new LicenseClient(this); }
    public LicenseClient license() { return license; }
}
