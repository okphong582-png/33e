package vn.mizze.androidviet;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.View;

final class CrossCheck extends View {
    private final Ui ui;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private boolean checked;
    CrossCheck(Context context,boolean value) { super(context);ui=new Ui(context);checked=value;setMinimumWidth(ui.dp(34));setMinimumHeight(ui.dp(34));setContentDescription(value?"Bật":"Tắt"); }
    void setChecked(boolean value) { checked=value;setContentDescription(value?"Bật":"Tắt");invalidate(); }
    @Override protected void onDraw(Canvas c) {
        super.onDraw(c);float pad=ui.dp(1);float r=ui.dp(8);
        paint.setStyle(Paint.Style.FILL);paint.setColor(checked?0x2275DBBA:ui.surface());
        c.drawRoundRect(pad,pad,getWidth()-pad,getHeight()-pad,r,r,paint);
        paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(ui.dp(1));paint.setColor(checked?Ui.MINT:ui.border());
        c.drawRoundRect(pad,pad,getWidth()-pad,getHeight()-pad,r,r,paint);
        if(checked){paint.setColor(Ui.MINT);paint.setStrokeWidth(ui.dp(2));paint.setStrokeCap(Paint.Cap.ROUND);
            c.drawLine(getWidth()*.34f,getHeight()*.34f,getWidth()*.66f,getHeight()*.66f,paint);
            c.drawLine(getWidth()*.66f,getHeight()*.34f,getWidth()*.34f,getHeight()*.66f,paint);}
    }
}
