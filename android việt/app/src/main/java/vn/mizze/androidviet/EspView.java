package vn.mizze.androidviet;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.*;
import android.view.View;
import org.json.*;

/** Touch-through surface. Coordinates come exclusively from the fresh root frame. */
final class EspView extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final SharedPreferences prefs;
    EspView(Context context){super(context);prefs=context.getSharedPreferences("menu",Context.MODE_PRIVATE);setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);}
    @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){super.onSizeChanged(w,h,oldw,oldh);RootDataSession.viewport(w,h);}
    private boolean enabled(String key){return prefs.getBoolean(key,false);}
    private float value(String key,float fallback){float v=prefs.getFloat(key,fallback);return Float.isFinite(v)?v:fallback;}
    private int color(String prefix){return Color.rgb(Math.round(Math.max(0,Math.min(1,value(prefix+"R",.46f)))*255),Math.round(Math.max(0,Math.min(1,value(prefix+"G",.86f)))*255),Math.round(Math.max(0,Math.min(1,value(prefix+"B",.73f)))*255));}
    private float[] point(JSONArray p){if(p==null||p.length()!=2)return null;float x=(float)p.optDouble(0,Double.NaN)*getWidth(),y=(float)p.optDouble(1,Double.NaN)*getHeight();return Float.isFinite(x)&&Float.isFinite(y)?new float[]{x,y}:null;}
    private void line(Canvas c,float[] a,float[] b){if(a!=null&&b!=null)c.drawLine(a[0],a[1],b[0],b[1],paint);}
    private void text(Canvas c,String value,float x,float y){paint.setStyle(Paint.Style.FILL);paint.setShadowLayer(2,0,1,Color.BLACK);c.drawText(value,x,y,paint);paint.clearShadowLayer();paint.setStyle(Paint.Style.STROKE);}
    @Override protected void onDraw(Canvas canvas){
        super.onDraw(canvas);JSONObject frame=RootDataSession.frame();if(frame==null)return;
        float density=getResources().getDisplayMetrics().density;
        paint.setStrokeWidth(Math.max(1,density));paint.setTextSize(12*density);paint.setTextAlign(Paint.Align.CENTER);paint.setStyle(Paint.Style.STROKE);
        if(enabled("ShowFov")){paint.setColor(color("FovColor"));canvas.drawCircle(getWidth()/2f,getHeight()/2f,Math.min(getWidth(),getHeight())*Math.max(5,Math.min(48,value("FovSize",40)))/100,paint);}
        if(enabled("AimTargetLine")){paint.setColor(color("FovColor"));line(canvas,new float[]{getWidth()/2f,getHeight()/2f},point(frame.optJSONArray("target")));}
        if(!enabled("ESPEnabled"))return;JSONArray players=frame.optJSONArray("players");if(players==null)return;
        int boxColor=color("BoxColor");
        for(int i=0;i<players.length();i++){
            JSONObject player=players.optJSONObject(i);if(player==null)continue;JSONObject bones=player.optJSONObject("bones");if(bones==null)continue;
            paint.setColor(boxColor);paint.setStyle(Paint.Style.STROKE);
            float[] head=point(bones.optJSONArray("head")),hip=point(bones.optJSONArray("hip")),left=point(bones.optJSONArray("leftFoot")),right=point(bones.optJSONArray("rightFoot"));
            if(head==null||hip==null)continue;
            if(enabled("TracerLine"))canvas.drawLine(getWidth()/2f,getHeight(),hip[0],hip[1],paint);
            float bottom=Math.max(left==null?hip[1]:left[1],right==null?hip[1]:right[1]),top=head[1]-4*density,height=bottom-top;
            if(height<=2||height>getHeight()*3)continue;float width=height*.42f,cx=(head[0]+hip[0])/2,leftX=cx-width/2,rightX=cx+width/2;
            if(enabled("Box")){
                if(enabled("Box3D")){JSONArray cube=player.optJSONArray("cube");if(cube!=null)for(int n=0;n<8;n++)for(int bit=1;bit<=4;bit*=2)if((n&bit)==0)line(canvas,point(cube.optJSONArray(n)),point(cube.optJSONArray(n|bit)));}
                else if(enabled("CleanESP")){float edge=Math.min(width,height)*.25f;for(float x:new float[]{leftX,rightX})for(float y:new float[]{top,bottom}){canvas.drawLine(x,y,x+(x==leftX?edge:-edge),y,paint);canvas.drawLine(x,y,x,y+(y==top?edge:-edge),paint);}}
                else canvas.drawRect(leftX,top,rightX,bottom,paint);
            }
            if(enabled("Skeleton")){
                String[][] segments={{"head","hip"},{"hip","leftFoot"},{"hip","rightFoot"},{"head","leftShoulder"},{"head","rightShoulder"},{"leftShoulder","leftElbow"},{"leftElbow","leftHand"},{"rightShoulder","rightElbow"},{"rightElbow","rightHand"}};
                for(String[] s:segments)line(canvas,point(bones.optJSONArray(s[0])),point(bones.optJSONArray(s[1])));
            }
            if(enabled("HeadRedDot")){paint.setColor(Color.RED);paint.setStyle(Paint.Style.FILL);canvas.drawCircle(head[0],head[1],3*density,paint);paint.setStyle(Paint.Style.STROKE);paint.setColor(boxColor);}
            if(enabled("Line")){JSONArray axes=player.optJSONArray("axes");if(axes!=null){int[] colors={Color.RED,Color.GREEN,Color.BLUE};for(int axis=0;axis<3;axis++){paint.setColor(colors[axis]);line(canvas,point(axes.optJSONArray(0)),point(axes.optJSONArray(axis+1)));}paint.setColor(boxColor);}}
            if(enabled("Name"))text(canvas,player.optString("name").replaceAll("[\\p{Cntrl}]",""),cx,top-5*density);
            if(enabled("Dis"))text(canvas,Math.round(player.optDouble("distance"))+" m",cx,bottom+14*density);
            if(enabled("Health")){int hp=player.optInt("hp"),max=player.optInt("maxHp");if(max>0){float fraction=Math.max(0,Math.min(1,hp/(float)max));float yellow=Math.max(0,Math.min(1,value("HealthYellowPercent",50)/100)),red=Math.min(yellow,Math.max(0,Math.min(1,value("HealthRedPercent",25)/100)));
                paint.setStyle(Paint.Style.FILL);paint.setColor(0xB0000000);canvas.drawRect(leftX-7*density,top,leftX-3*density,bottom,paint);paint.setColor(fraction<=red?Color.RED:fraction<=yellow?Color.YELLOW:Color.GREEN);canvas.drawRect(leftX-6*density,bottom-height*fraction,leftX-4*density,bottom,paint);paint.setStyle(Paint.Style.STROKE);
            }}
        }
    }
}
