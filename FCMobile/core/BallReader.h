#pragma once
#include "ShotSettings.h"
#include <cmath>
namespace fcm {
struct Vec4 {float x=0,y=0,z=0,w=1;};
struct Matrix {std::array<float,16> v{};};
struct BallSnapshot {bool visible=false;float x=0,y=0;};
struct Snapshot {State state=State::off;State shot=State::off;State aim=State::off;bool aimChanged=false;BallSnapshot ball;};
inline bool pointer(uint64_t p){return p>=0x10000&&p<0x0000800000000000ULL&&(p&7)==0;}
inline bool finite(const Matrix &m){for(float v:m.v)if(!std::isfinite(v)||std::fabs(v)>1e7f)return false;return true;}
inline Vec4 transform(const Matrix &m,const Vec4 &p){
    return {m.v[0]*p.x+m.v[4]*p.y+m.v[8]*p.z+m.v[12]*p.w,
            m.v[1]*p.x+m.v[5]*p.y+m.v[9]*p.z+m.v[13]*p.w,
            m.v[2]*p.x+m.v[6]*p.y+m.v[10]*p.z+m.v[14]*p.w,
            m.v[3]*p.x+m.v[7]*p.y+m.v[11]*p.z+m.v[15]*p.w};
}
inline BallSnapshot projectBall(const Vec4 &p,const Matrix &view,const Matrix &projection){
    BallSnapshot out;
    if(!finite(view)||!finite(projection)||!std::isfinite(p.x)||!std::isfinite(p.y)||!std::isfinite(p.z)||
       std::fabs(p.x)>1e6f||std::fabs(p.y)>1e6f||std::fabs(p.z)>1e6f)return out;
    auto camera=transform(view,{p.x,p.y,p.z,1});
    // Match the native render camera: front-facing points have negative camera Z.
    if(!std::isfinite(camera.z)||camera.z>=-1e-5f)return out;
    auto clip=transform(projection,camera);
    if(!std::isfinite(clip.w)||std::fabs(clip.w)<1e-5f)return out;
    float x=clip.x/clip.w,y=clip.y/clip.w;
    if(!std::isfinite(x)||!std::isfinite(y)||x<-1||x>1||y<-1||y>1)return out;
    out.visible=true;out.x=(x+1)*.5f;out.y=(1-y)*.5f;return out;
}
class BallReader {
    Memory &m;
    bool ptr(uint64_t address,uint64_t &p){return m.read(address,p)&&pointer(p);}
public:
    explicit BallReader(Memory &memory):m(memory){}
    BallSnapshot sample(uint64_t image){
        uint64_t registry=0,scene=0,table=0,wrapper=0,data=0,balls=0,ball=0,writer=0,history=0;
        int32_t id=-1,frame=-1;
        if(!ptr(image+0xa263b60,registry)||!ptr(registry,scene)||!ptr(registry+8,table)||
           !m.read(scene+0x226d8,id)||id<0||id>=12||
           !ptr(table+34*32+0x20,wrapper)||!ptr(wrapper+8,data)||!ptr(data+0x38,balls)||
           !ptr(balls+uint64_t(id)*8,ball)||!ptr(ball+0x90,writer)||!ptr(writer+0x230,history)||
           !m.read(history+0x9610,frame)||frame<0)return {};
        Vec4 position{};
        if(!m.read(history+uint64_t(frame%600)*64+0x10,position))return {};
        uint64_t manager=0,camera=0,storage=0,vtable=0;int32_t index=-1;
        if(!ptr(image+0xa2bf528,manager)||!m.read(manager+0x40,index)||index<0||index>=4||
           !ptr(manager+uint64_t(index)*8,camera)||!m.read(camera,vtable)||vtable!=image+0x529d148||
           !ptr(camera+8,storage))return {};
        Matrix view,projection;
        if(!m.read(storage,projection)||!m.read(storage+0x40,view))return {};
        // Reject a sample if the scene, active ball, history slot or camera changed mid-read.
        uint64_t registry2=0,scene2=0,table2=0,wrapper2=0,data2=0,balls2=0,ball2=0;
        uint64_t writer2=0,history2=0,manager2=0,camera2=0,storage2=0;int32_t id2=-1,frame2=-1,index2=-1;
        if(!m.read(image+0xa263b60,registry2)||registry2!=registry||!m.read(registry,scene2)||scene2!=scene||
           !m.read(registry+8,table2)||table2!=table||!m.read(table+34*32+0x20,wrapper2)||wrapper2!=wrapper||
           !m.read(wrapper+8,data2)||data2!=data||!m.read(data+0x38,balls2)||balls2!=balls||
           !m.read(balls+uint64_t(id)*8,ball2)||ball2!=ball||!m.read(ball+0x90,writer2)||writer2!=writer||
           !m.read(writer+0x230,history2)||history2!=history||
           !m.read(scene+0x226d8,id2)||id2!=id||!m.read(history+0x9610,frame2)||frame2!=frame||
           !m.read(image+0xa2bf528,manager2)||manager2!=manager||!m.read(manager+0x40,index2)||index2!=index||
           !m.read(manager+uint64_t(index)*8,camera2)||camera2!=camera||!m.read(camera+8,storage2)||storage2!=storage)return {};
        return projectBall(position,view,projection);
    }
};
}
