package vn.mizze.androidviet;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

final class Ui {
    static final int MINT = Color.rgb(117,219,186);
    final Context context;
    final SharedPreferences prefs;
    Ui(Context context) { this.context = context; prefs = context.getSharedPreferences("menu", Context.MODE_PRIVATE); }
    int dp(float n) { return Math.round(n * context.getResources().getDisplayMetrics().density); }
    boolean dark() { return prefs.getBoolean("DarkTheme", true); }
    int bg() { return Color.rgb(dark()?14:245, dark()?14:245, dark()?14:245); }
    int surface() { return dark()?Color.rgb(24,24,24):Color.WHITE; }
    int raised() { return dark()?Color.rgb(32,32,32):Color.rgb(242,242,242); }
    int border() { return dark()?Color.rgb(49,49,49):Color.rgb(219,219,219); }
    int text() { return dark()?Color.rgb(237,237,237):Color.rgb(26,26,26); }
    int muted() { return dark()?Color.rgb(148,148,148):Color.rgb(107,107,107); }
    GradientDrawable shape(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable(); drawable.setColor(color); drawable.setCornerRadius(dp(radius)); return drawable;
    }
    GradientDrawable card(int color, int radius) { GradientDrawable d=shape(color,radius); d.setStroke(dp(1),border()); return d; }
    TextView label(String value, float size, int color) {
        TextView v = new TextView(context); v.setText(value); v.setTextSize(size); v.setTextColor(color);
        v.setFontFeatureSettings("kern"); v.setGravity(Gravity.CENTER_VERTICAL); return v;
    }
    TextView bold(String value,float size,int color) { TextView v=label(value,size,color);v.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));return v; }
    Button button(String value, Runnable action) {
        Button b = new Button(context); b.setText(value); b.setTextSize(14); b.setAllCaps(false); b.setTextColor(MINT);
        b.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL)); b.setBackground(shape(raised(),12));
        b.setMinHeight(0);b.setMinimumHeight(0); b.setPadding(dp(12),0,dp(12),0);
        b.setOnClickListener(v -> action.run()); return b;
    }
    LinearLayout column() { LinearLayout v=new LinearLayout(context);v.setOrientation(LinearLayout.VERTICAL);return v; }
    LinearLayout row() { LinearLayout v=new LinearLayout(context);v.setOrientation(LinearLayout.HORIZONTAL);v.setGravity(Gravity.CENTER_VERTICAL);return v; }
    void add(LinearLayout parent,View child,int height,int gap) {
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,height<0?height:dp(height));p.bottomMargin=dp(gap);parent.addView(child,p);
    }
}
