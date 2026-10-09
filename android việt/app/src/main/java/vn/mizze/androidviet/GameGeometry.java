package vn.mizze.androidviet;

import java.io.IOException;
import java.util.HashSet;

/** Unity column-major matrices and bounded TransformData traversal. No Android dependency. */
final class GameGeometry {
    record V(float x,float y,float z){
        V add(V b){return new V(x+b.x,y+b.y,z+b.z);} V sub(V b){return new V(x-b.x,y-b.y,z-b.z);} V scale(float k){return new V(x*k,y*k,z*k);}
        float length(){return (float)Math.sqrt(x*x+y*y+z*z);} boolean valid(){return Float.isFinite(x)&&Float.isFinite(y)&&Float.isFinite(z)&&Math.max(Math.max(Math.abs(x),Math.abs(y)),Math.abs(z))<100000;}
    }
    record Q(float x,float y,float z,float w){
        float norm(){return (float)Math.sqrt(x*x+y*y+z*z+w*w);} boolean valid(){float n=norm();return Float.isFinite(n)&&n>.95f&&n<1.05f;}
        V rotate(V v){V t=cross(new V(x,y,z),v).scale(2);return v.add(t.scale(w)).add(cross(new V(x,y,z),t));}
    }
    record TRS(V translation,Q rotation,V scale){}
    interface Hierarchy {TRS node(int index)throws Exception; int parent(int index)throws Exception;}
    static V world(Hierarchy h,int index)throws Exception {
        if(index<0||index>8192)throw new IOException("Transform index out of range");
        HashSet<Integer> visited=new HashSet<>();visited.add(index);V p=h.node(index).translation();
        if(!p.valid())throw new IOException("Invalid local position");
        for(int depth=0;depth<64;depth++){
            int parent=h.parent(index);if(parent==-1)return p;
            if(parent<0||parent>8192||!visited.add(parent))throw new IOException("Invalid transform hierarchy");
            TRS t=h.node(parent);if(!t.translation().valid()||!t.scale().valid()||!t.rotation().valid())throw new IOException("Invalid parent TRS");
            p=t.translation().add(t.rotation().rotate(new V(p.x*t.scale.x,p.y*t.scale.y,p.z*t.scale.z)));
            if(!p.valid())throw new IOException("Invalid world position");index=parent;
        }throw new IOException("Transform depth limit");
    }
    static V cross(V a,V b){return new V(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x);}
    static float dot(V a,V b){return a.x*b.x+a.y*b.y+a.z*b.z;}
    static Q look(V direction){
        float n=direction.length();if(!direction.valid()||n<.001f)return null;
        V f=direction.scale(1/n),r=cross(new V(0,1,0),f);float rn=r.length();if(rn<.001f)return null;r=r.scale(1/rn);V u=cross(f,r);
        float tr=r.x+u.y+f.z,x,y,z,w;
        if(tr>0){float s=(float)Math.sqrt(tr+1)*2;w=.25f*s;x=(u.z-f.y)/s;y=(f.x-r.z)/s;z=(r.y-u.x)/s;}
        else if(r.x>u.y&&r.x>f.z){float s=(float)Math.sqrt(1+r.x-u.y-f.z)*2;w=(u.z-f.y)/s;x=.25f*s;y=(u.x+r.y)/s;z=(f.x+r.z)/s;}
        else if(u.y>f.z){float s=(float)Math.sqrt(1+u.y-r.x-f.z)*2;w=(f.x-r.z)/s;x=(u.x+r.y)/s;y=.25f*s;z=(f.y+u.z)/s;}
        else{float s=(float)Math.sqrt(1+f.z-r.x-u.y)*2;w=(r.y-u.x)/s;x=(f.x+r.z)/s;y=(f.y+u.z)/s;z=.25f*s;}
        Q q=new Q(x,y,z,w);float qn=q.norm();return Float.isFinite(qn)&&qn>.001f?new Q(x/qn,y/qn,z/qn,w/qn):null;
    }
    static float[] multiply(float[] a,float[] b){float[] c=new float[16];for(int col=0;col<4;col++)for(int row=0;row<4;row++)for(int k=0;k<4;k++)c[col*4+row]+=a[k*4+row]*b[col*4+k];return c;}
    static float[] project(V p,float[] matrix){
        float w=matrix[3]*p.x+matrix[7]*p.y+matrix[11]*p.z+matrix[15];if(!Float.isFinite(w)||w<=.001f)return null;
        float x=.5f+.5f*(matrix[0]*p.x+matrix[4]*p.y+matrix[8]*p.z+matrix[12])/w;
        float y=.5f-.5f*(matrix[1]*p.x+matrix[5]*p.y+matrix[9]*p.z+matrix[13])/w;
        return Float.isFinite(x)&&Float.isFinite(y)&&Math.abs(x)<8&&Math.abs(y)<8?new float[]{x,y}:null;
    }
    static V neck(V head,V hip){V d=head.sub(hip);float n=d.length();return n>=.2f&&n<=1.5f?head.sub(d.scale(Math.min(.10f,n*.12f)/n)):head;}
    static boolean trigger(boolean always,boolean fireMode,boolean scopeMode,boolean both,boolean firing,boolean scope){return always||(both?firing&&scope:fireMode&&firing||scopeMode&&scope);}
    static float centerDistance(float[] point,float width,float height){if(point==null||width<=0||height<=0)return Float.POSITIVE_INFINITY;return (float)Math.hypot((point[0]-.5f)*width,(point[1]-.5f)*height);}
}
