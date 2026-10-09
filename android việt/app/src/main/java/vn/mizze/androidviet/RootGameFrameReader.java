package vn.mizze.androidviet;

import android.os.SystemClock;
import org.json.*;
import java.io.IOException;
import java.nio.*;
import java.util.*;
import static vn.mizze.androidviet.RootReaderMain.pointer;

/** External ARM64 reader for the supplied 1.132.1 APK. Every frame is disposable. */
final class RootGameFrameReader {
    private final RootReaderMain.Memory m; private final long base,game,match,local;
    private long playerClass;
    private static final AimRotationController silentController=new AimRotationController();
    private final TransformNodeReader.Memory nodeMemory;
    private final Map<Long,GameGeometry.V> positions=new HashMap<>();
    private final Map<Long,GameGeometry.TRS> trs=new HashMap<>();
    private final Map<Long,Integer> ancestry=new HashMap<>();
    RootGameFrameReader(RootReaderMain.Memory memory,long base,long game,long match,long local){this.m=memory;this.base=base;this.game=game;this.match=match;this.local=local;
        nodeMemory=new TransformNodeReader.Memory(){public long pointer(long address)throws Exception{return m.ptr(address);}public String string(long address)throws Exception{return m.ascii(address);}public int instruction(long address)throws Exception{return m.i32(address);}};
    }
    private static ByteBuffer bytes(byte[] b){return ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN);}
    private boolean named(long object,String name,String namespace)throws Exception{
        if(!pointer(object))return false;long k=m.ptr(object);return pointer(k)&&m.ascii(m.ptr(k+16)).equals(name)&&m.ascii(m.ptr(k+24)).equals(namespace);
    }
    private GameGeometry.V vec(ByteBuffer b,int at){return new GameGeometry.V(b.getFloat(at),b.getFloat(at+4),b.getFloat(at+8));}
    private GameGeometry.Q quaternion(long at)throws Exception{ByteBuffer b=bytes(m.read(at,16));return new GameGeometry.Q(b.getFloat(),b.getFloat(),b.getFloat(),b.getFloat());}
    private GameGeometry.V transform(long managed)throws Exception{
        if(positions.containsKey(managed))return positions.get(managed);
        if(!named(managed,"Transform","UnityEngine"))throw new IOException("Not a Transform");long nativePtr=m.ptr(managed+0x10);
        if(!pointer(nativePtr))throw new IOException("Missing native transform");long data=m.ptr(nativePtr+0x38);int index=m.i32(nativePtr+0x40);
        if(!pointer(data))throw new IOException("Missing TransformData");long matrices=m.ptr(data+0x18),parents=m.ptr(data+0x20);
        if(!pointer(matrices)||!pointer(parents))throw new IOException("Invalid TransformData buffers");
        GameGeometry.V result=GameGeometry.world(new GameGeometry.Hierarchy(){
            public GameGeometry.TRS node(int i)throws Exception{long at=matrices+i*48L;if(trs.containsKey(at))return trs.get(at);ByteBuffer b=bytes(m.read(at,48));GameGeometry.TRS value=new GameGeometry.TRS(vec(b,0),new GameGeometry.Q(b.getFloat(16),b.getFloat(20),b.getFloat(24),b.getFloat(28)),vec(b,32));trs.put(at,value);return value;}
            public int parent(int i)throws Exception{long at=parents+i*4L;if(ancestry.containsKey(at))return ancestry.get(at);int value=m.i32(at);ancestry.put(at,value);return value;}
        },index);
        if(data!=m.ptr(nativePtr+0x38)||index!=m.i32(nativePtr+0x40))throw new IOException("Transform changed during read");positions.put(managed,result);return result;
    }
    private GameGeometry.V bone(long player,int offset)throws Exception{
        long node=m.ptr(player+offset);return transform(TransformNodeReader.resolve(node,base,nodeMemory));
    }
    private GameGeometry.V maybeBone(long p,int offset){try{return bone(p,offset);}catch(Exception e){return null;}}
    private GameGeometry.V head(long p)throws Exception{try{return bone(p,0x6A0);}catch(Exception e){return bone(p,0xA00);}}
    private GameGeometry.V hip(long p)throws Exception{try{return bone(p,0x6A8);}catch(Exception e){return bone(p,0xA08);}}
    private int pri(long p,int index)throws Exception{
        long pool=m.ptr(p+0x70);boolean unsafe=named(pool,"PRIDataPoolUnsafe","GCommon");
        if(!unsafe&&!named(pool,"PRIDataPool","GCommon"))throw new IOException("Unknown PRI pool");
        int count=m.i32(pool+0x18);long array=m.ptr(pool+0x10);
        if(count<index+1||count>4096||!pointer(array)||m.ptr(array+0x18)<index+1||m.ptr(array+0x18)>4096)throw new IOException("Invalid PRI array");
        long entry=m.ptr(array+0x20+index*8L);if(!pointer(entry))throw new IOException("Missing PRI entry");
        long value=unsafe?m.ptr(entry+0x18):entry+0x18;
        return index==34?m.read(value,1)[0]&255:bytes(m.read(value,2)).getShort()&65535;
    }
    private float[] matrix(long at)throws Exception{ByteBuffer b=bytes(m.read(at,64));float[] a=new float[16];for(int i=0;i<16;i++){a[i]=b.getFloat();if(!Float.isFinite(a[i])||Math.abs(a[i])>100000)throw new IOException("Invalid camera matrix");}return a;}
    private void verify()throws Exception{
        if(m.unityBase()==0||m.i32(base+0x6FAE488L)!=0xF9435273||m.i32(base+0x6F2C8B0L)!=0xBD06166B||m.i32(base+0x82E78F0L)!=0x79403100)
            throw new IOException("Camera/bone/PRI signatures do not match");
        long k=m.ptr(local);int depth=m.read(k+0x130,1)[0]&255;long chain=m.ptr(k+0xC8);
        if(depth<1||depth>32||!pointer(chain))throw new IOException("Invalid player hierarchy");
        for(int i=0;i<depth;i++){long candidate=m.ptr(chain+i*8L);if(pointer(candidate)&&m.ascii(m.ptr(candidate+16)).equals("Player")&&m.ascii(m.ptr(candidate+24)).equals("COW.GamePlay")){playerClass=candidate;break;}}
        if(playerClass==0)throw new IOException("Local player class mismatch");
    }
    private JSONArray screen(GameGeometry.V v,float[] vp)throws JSONException{float[] p=v==null?null:GameGeometry.project(v,vp);return p==null?null:new JSONArray().put(p[0]).put(p[1]);}
    JSONObject read(JSONObject config,java.util.function.LongSupplier lease,java.util.function.BooleanSupplier unchanged)throws Exception{
        long started=SystemClock.elapsedRealtime();verify();
        long manager=m.ptr(game+0xD8),camera=pointer(manager)?m.ptr(manager+0x20):0;
        if(!named(camera,"Camera","UnityEngine"))throw new IOException("Waiting for game camera");long nativeCamera=m.ptr(camera+0x10);
        if(!pointer(nativeCamera))throw new IOException("Missing native camera");
        float[] view=matrix(nativeCamera+0x80),projection=matrix(nativeCamera+0xC0);
        // Affine view matrix, nonzero perspective focal lengths and clip W row.
        if(Math.abs(view[15]-1)>.05f||Math.abs(view[3])+Math.abs(view[7])+Math.abs(view[11])>.05f||Math.abs(projection[0])<.01f||Math.abs(projection[5])<.01f||Math.abs(projection[11])<.01f)throw new IOException("Camera not ready");
        float[] vp=GameGeometry.multiply(projection,view);GameGeometry.V cameraPos=transform(m.ptr(local+0x3E8));GameGeometry.V localHip=hip(local);
        if(!cameraPos.valid()||!localHip.valid()||cameraPos.sub(localHip).length()>100)throw new IOException("Camera/local position mismatch");
        long dictionary=m.ptr(match+0x148);
        if(!named(dictionary,"Dictionary`2","System.Collections.Generic"))throw new IOException("Missing player dictionary");
        int count=m.i32(dictionary+0x20),free=m.i32(dictionary+0x28),version=m.i32(dictionary+0x2C);long entries=m.ptr(dictionary+0x18);
        if(count<1||count>256||free<0||free>count||!pointer(entries)||m.ptr(entries+0x18)<count||m.ptr(entries+0x18)>4096)throw new IOException("Invalid player dictionary bounds");
        ArrayList<Long> players=new ArrayList<>();HashSet<Long> seen=new HashSet<>();boolean includesLocal=false;
        for(int i=0;i<count;i++){long entry=entries+0x20+i*24L;if(m.i32(entry)<0)continue;long p=m.ptr(entry+16);if(!pointer(p)||!m.instanceOf(p,playerClass)||!seen.add(p))throw new IOException("Player entry mismatch");players.add(p);includesLocal|=p==local;}
        if(!includesLocal||players.size()!=count-free)throw new IOException("Dictionary/local player mismatch");
        int team=pri(local,34),localHP=pri(local,0),maxHP=pri(local,1);if(team>255||maxHP<1||maxHP>10000||localHP>maxHP)throw new IOException("Local PRI values invalid");
        boolean firing=pri(local,21)==2,scope=pri(local,12)!=0;
        float width=(float)config.optDouble("width",0),height=(float)config.optDouble("height",0);
        boolean silent=config.optBoolean("silent");
        float fov=(float)Math.max(5,Math.min(48,config.optDouble(silent?"silentFov":"fov",silent?18:40))),radius=Math.min(width,height)*fov/100;
        float maxDistance=(float)Math.max(50,Math.min(500,config.optDouble(silent?"silentDistance":"distance",silent?100:150)));
        JSONArray output=new JSONArray();GameGeometry.V target=null;long targetPlayer=0;float[] targetScreen=null;float best=radius;
        for(long p:players){if(p==local)continue;
            try{
                int enemyTeam=pri(p,34),hp=pri(p,0),max=pri(p,1);if(enemyTeam>255||hp<=0||max<1||max>10000||hp>max||team>0&&team==enemyTeam)continue;
                GameGeometry.V h=head(p),hips=hip(p);float torso=h.sub(hips).length(),distance=hips.sub(localHip).length();
                if(!h.valid()||!hips.valid()||torso<.1f||torso>3||distance<.1f||distance>maxDistance)continue;
                GameGeometry.V left=maybeBone(p,0x6D8),right=maybeBone(p,0x6E0);if(left!=null&&left.sub(hips).length()>4)left=null;if(right!=null&&right.sub(hips).length()>4)right=null;
                JSONObject bones=new JSONObject().put("head",screen(h,vp)).put("hip",screen(hips,vp)).put("leftFoot",screen(left,vp)).put("rightFoot",screen(right,vp));
                int[] offsets={0x6C0,0x6C8,0x720,0x718,0x730,0x728};String[] names={"leftShoulder","rightShoulder","leftHand","rightHand","leftElbow","rightElbow"};
                if(config.optBoolean("skeleton",true))for(int i=0;i<offsets.length;i++){GameGeometry.V v=maybeBone(p,offsets[i]);if(v!=null&&v.sub(hips).length()<4)bones.put(names[i],screen(v,vp));}
                String name=config.optBoolean("name",true)?m.managedString(m.ptr(p+0x490)).replaceAll("[\\p{Cntrl}]",""):"";
                JSONArray axes=config.optBoolean("axes",true)?new JSONArray().put(screen(hips,vp)).put(screen(hips.add(new GameGeometry.V(.5f,0,0)),vp)).put(screen(hips.add(new GameGeometry.V(0,.5f,0)),vp)).put(screen(hips.add(new GameGeometry.V(0,0,.5f)),vp)):new JSONArray();
                JSONArray cube=new JSONArray();float bottom=Math.min(left==null?hips.y():left.y(),right==null?hips.y():right.y()),top=h.y()+.15f;
                if(config.optBoolean("cube",false))for(int corner=0;corner<8;corner++)cube.put(screen(new GameGeometry.V(hips.x()+((corner&1)==0?-.35f:.35f),(corner&2)==0?bottom:top,hips.z()+((corner&4)==0?-.25f:.25f)),vp));
                output.put(new JSONObject().put("name",name).put("hp",hp).put("maxHp",max).put("distance",distance).put("bones",bones).put("axes",axes).put("cube",cube));
                GameGeometry.V aim=config.optBoolean("neck")&&!config.optBoolean("head")?GameGeometry.neck(h,hips):h;float[] point=GameGeometry.project(aim,vp);
                float center=GameGeometry.centerDistance(point,width,height);if(center<best&&point[0]>=0&&point[0]<=1&&point[1]>=0&&point[1]<=1){best=center;target=aim;targetPlayer=p;targetScreen=point;}
            }catch(Exception ignored){/* One unloaded player never invalidates the dictionary or supplies fabricated data. */}
        }
        if(m.ptr(dictionary+0x18)!=entries||m.i32(dictionary+0x20)!=count||m.i32(dictionary+0x2C)!=version||m.ptr(match+0xD8)!=local||m.ptr(match+0x148)!=dictionary||RootReaderMain.processStart(m.pid)!=m.start)throw new IOException("Match changed during frame");
        long[] live=RootReaderMain.context(m,base);if(live==null||live[0]!=game||live[1]!=match||live[2]!=local)throw new IOException("Current match changed");
        // Alternate game aim mode takes a different setter path; do not write its normal field.
        long globalsCache=m.ptr(base+0xA72E9C8L),globals=pointer(globalsCache)?m.ptr(globalsCache):0,statics=pointer(globals)?m.ptr(globals+0xB8):0;
        boolean aimReady=pointer(statics)&&m.read(statics+0xE4,1)[0]==0&&quaternion(local+0x614).valid();
        boolean silentReady=aimReady&&m.read(local+0x420,1)[0]==1&&quaternion(local+0x628).valid()
            &&m.i32(base+0x6F8E15CL)==0xBD462A60&&m.i32(base+0x6F8E168L)==0xBD463663
            &&m.i32(base+0x6EF7240L)==0x39508260&&m.i32(base+0x6F8E1CCL)==0x3C814100
            &&m.i32(base+0x7480920L)==0x97EC35FC&&m.i32(base+0x7480980L)==0x94AD337D;
        String aimStatus="Aim: chờ mục tiêu trong FOV.";
        boolean enabled=config.optBoolean("head")||config.optBoolean("neck");
        if(aimReady){try{m.enableWrites();}catch(Exception e){aimReady=false;}}
        if(!aimReady)aimStatus="Aim: chưa khớp quyền ghi/rotation/chế độ game.";
        else if(!enabled)aimStatus="Aim đang tắt.";
        else if((!silent||silentReady)&&target!=null&&localHP>0&&(!silent||firing)&&GameGeometry.trigger(config.optBoolean("always"),config.optBoolean("fire"),config.optBoolean("scope"),config.optBoolean("both"),firing,scope)){
            // Re-read identity, target health/team and lease immediately before the only rotation write.
            if(SystemClock.elapsedRealtime()-started>300||SystemClock.elapsedRealtime()>=lease.getAsLong()||!unchanged.getAsBoolean())throw new IOException("Frame/lease expired before aim");
            int currentTeam=pri(targetPlayer,34);if(pri(targetPlayer,0)>0&&!(team>0&&team==currentTeam)&&m.instanceOf(targetPlayer,playerClass)&&m.ptr(match+0xD8)==local&&m.i32(dictionary+0x2C)==version){
                GameGeometry.Q rotation=GameGeometry.look(target.sub(cameraPos));if(rotation!=null){if(!silent)m.writeQuaternion(local+0x614,rotation);aimStatus="Aim: đã ghi rotation tới mục tiêu · cần kiểm tra trong trận.";}
            }
        }else if(enabled&&target!=null)aimStatus="Aim: đã chọn mục tiêu, chờ điều kiện bắn/ngắm.";
        final boolean writeSilent=silent&&silentReady&&enabled&&firing&&localHP>0&&target!=null
            &&GameGeometry.trigger(config.optBoolean("always"),config.optBoolean("fire"),config.optBoolean("scope"),config.optBoolean("both"),firing,scope);
        final long selected=targetPlayer;
        silentController.apply(new AimRotationController.Memory(){
            public AimRotationController.Identity identity()throws Exception{
                if((writeSilent&&SystemClock.elapsedRealtime()>=lease.getAsLong())||!unchanged.getAsBoolean()||RootReaderMain.processStart(m.pid)!=m.start)return null;
                long[] c=RootReaderMain.context(m,base);
                if(c==null||c[0]!=game||c[1]!=match||c[2]!=local||m.i32(dictionary+0x2C)!=version||m.read(local+0x420,1)[0]!=1)return null;
                if(writeSilent&&(SystemClock.elapsedRealtime()-started>150||pri(local,21)!=2||pri(selected,0)<=0||!m.instanceOf(selected,playerClass)||(team>0&&pri(selected,34)==team)))return null;
                return new AimRotationController.Identity(m.pid,m.start,match,local,m.ptr(local));
            }
            public GameGeometry.Q read(long at)throws Exception{return quaternion(at);}
            public void write(long at,GameGeometry.Q q)throws Exception{m.writeQuaternion(at,q);}
        },writeSilent,writeSilent?GameGeometry.look(target.sub(cameraPos)):null);
        return new JSONObject().put("players",output).put("width",width).put("height",height).put("viewportEpoch",config.optLong("viewportEpoch")).put("sampleUptime",started).put("playersReady",true).put("aimReady",aimReady).put("silentReady",silentReady).put("aimStatus",aimStatus)
            .put("target",targetScreen==null?JSONObject.NULL:new JSONArray().put(targetScreen[0]).put(targetScreen[1])).put("playerCount",players.size());
    }
}
