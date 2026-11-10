#pragma once
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace HHAim {
struct Vec3 { float x,y,z; };
struct Quaternion { float x,y,z,w; };
struct Candidate { uint64_t id; Vec3 head,hip; float x,y,meters; bool visible; };

inline bool finite(Vec3 v) {
    return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z);
}
inline Vec3 neck(Vec3 head,Vec3 hip) {
    if(!finite(head))return {0,0,0};
    if(!finite(hip))return head;
    const float dx=head.x-hip.x,dy=head.y-hip.y,dz=head.z-hip.z;
    const float length=std::sqrt(dx*dx+dy*dy+dz*dz);
    if(!std::isfinite(length)||length<0.2f||length>1.5f)return head;
    const float ratio=std::min(0.10f,length*0.12f)/length;
    return {head.x-dx*ratio,head.y-dy*ratio,head.z-dz*ratio};
}
inline uint64_t select(const Candidate *candidates,size_t count,float width,float height,
                       float radius,float maxMeters,uint64_t previous) {
    if(!candidates||!std::isfinite(width)||!std::isfinite(height)||width<=0||height<=0||
       !std::isfinite(radius)||radius<=0||!std::isfinite(maxMeters)||maxMeters<=0)return 0;
    uint64_t choice=0;float best=std::numeric_limits<float>::max();
    for(size_t i=0;i<count;i++){
        const auto &c=candidates[i];
        if(!c.id||!c.visible||!finite(c.head)||!finite(c.hip)||
           !std::isfinite(c.x)||!std::isfinite(c.y)||!std::isfinite(c.meters)||
           c.x<0||c.x>width||c.y<0||c.y>height||c.meters<=0||c.meters>maxMeters)continue;
        const float dx=c.x-width*0.5f,dy=c.y-height*0.5f;
        const float dist=std::sqrt(dx*dx+dy*dy);
        if(dist>radius)continue;
        const float score=0.75f*(dist/radius)+0.25f*(c.meters/maxMeters)-
                          (c.id==previous?0.025f:0.f);
        if(score<best||(score==best&&c.id<choice)){best=score;choice=c.id;}
    }
    return choice;
}
inline bool look(Vec3 origin,Vec3 target,Quaternion &out) {
    if(!finite(origin)||!finite(target))return false;
    float fx=target.x-origin.x,fy=target.y-origin.y,fz=target.z-origin.z;
    const float length=std::sqrt(fx*fx+fy*fy+fz*fz);
    if(!std::isfinite(length)||length<0.01f)return false;
    fx/=length;fy/=length;fz/=length;
    // A cross product with world up gives the right basis vector.
    float rx=fz,ry=0,rz=-fx;
    const float rightLength=std::sqrt(rx*rx+rz*rz);
    if(rightLength<0.001f){rx=1;ry=0;rz=0;}
    else {rx/=rightLength;rz/=rightLength;}
    const float ux=fy*rz-fz*ry,uy=fz*rx-fx*rz,uz=fx*ry-fy*rx;
    const float trace=rx+uy+fz;
    Quaternion q{};
    if(trace>0){const float s=std::sqrt(trace+1.f)*2.f;
        q.w=s*.25f;q.x=(uz-fy)/s;q.y=(fx-rz)/s;q.z=(ry-ux)/s;
    }else if(rx>uy&&rx>fz){const float s=std::sqrt(1.f+rx-uy-fz)*2.f;
        q.w=(uz-fy)/s;q.x=s*.25f;q.y=(ux+ry)/s;q.z=(fx+rz)/s;
    }else if(uy>fz){const float s=std::sqrt(1.f+uy-rx-fz)*2.f;
        q.w=(fx-rz)/s;q.x=(ux+ry)/s;q.y=s*.25f;q.z=(fy+uz)/s;
    }else{const float s=std::sqrt(1.f+fz-rx-uy)*2.f;
        q.w=(ry-ux)/s;q.x=(fx+rz)/s;q.y=(fy+uz)/s;q.z=s*.25f;
    }
    const float norm=std::sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w);
    if(!std::isfinite(norm)||norm<0.5f)return false;
    out={q.x/norm,q.y/norm,q.z/norm,q.w/norm};
    return true;
}
} // namespace HHAim
