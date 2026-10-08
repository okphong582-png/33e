#pragma once
#include "Profile.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
#include <vector>
namespace aov {
struct Vec3 { float x=0,y=0,z=0; };
struct Point { float x=0,y=0; };
struct Matrix { float m[16]{}; };
struct Handle { uint32_t sequence=0, padding=0; uint64_t object=0; };
static_assert(sizeof(Handle)==16);
struct Actor { uint64_t address=0; uint32_t config=0; Vec3 position; int hp=0,maxHP=0; bool monster=false; };
enum class State { disconnected, denied, unsupported, waiting, ready, changing };
enum class ZoomState { off, waiting, active, denied };
struct Snapshot { State state=State::waiting; ZoomState zoom=ZoomState::off; Matrix view, projection; std::vector<Actor> actors; };
class Memory {
public:
    virtual ~Memory()=default;
    virtual bool copy(uint64_t address, void *out, size_t size)=0;
    virtual bool store(uint64_t address,const void *value,size_t size) { (void)address;(void)value;(void)size;return false; }
    template<class T> bool read(uint64_t p,T &v) {
        v={}; return p>=0x10000 && p<=0x00007fffffffffffULL-sizeof(T) && copy(p,&v,sizeof(T));
    }
    uint64_t pointer(uint64_t p) { uint64_t v=0; return read(p,v)&&v>=0x10000&&v<0x00007fffffffffffULL ? v : 0; }
};
inline uint64_t singleton(Memory &m,uint64_t slot) {
    auto method=m.pointer(slot); if(!method)return 0;
    auto owner=m.pointer(method+methodContext); if(!owner)return 0;
    auto context=m.pointer(owner+classContext); if(!context)return 0;
    auto klass=m.pointer(context+contextClass); if(!klass)return 0;
    auto statics=m.pointer(klass+staticFields); return statics?m.pointer(statics):0;
}
inline bool validMatrix(const Matrix &v) {
    float sum=0; for(float f:v.m){ if(!std::isfinite(f)||std::abs(f)>1e7f)return false; sum+=std::abs(f); }
    return sum>0.001f;
}
inline bool project(Vec3 p,const Matrix &v,const Matrix &q,float width,float height,Point &out) {
    if(width<=0||height<=0)return false;
    float a[4]={p.x,p.y,p.z,1},b[4]{},c[4]{};
    for(int r=0;r<4;r++)for(int k=0;k<4;k++)b[r]+=v.m[k*4+r]*a[k];
    // Unity view space looks along -Z. This also rejects behind-camera orthographic points.
    if(b[2]>=-0.01f)return false;
    for(int r=0;r<4;r++)for(int k=0;k<4;k++)c[r]+=q.m[k*4+r]*b[k];
    if(!std::isfinite(c[3])||c[3]<=0.0001f)return false;
    float x=c[0]/c[3],y=c[1]/c[3];
    if(!std::isfinite(x)||!std::isfinite(y)||std::abs(x)>1.1f||std::abs(y)>1.1f)return false;
    out={(x+1)*width*0.5f,(1-y)*height*0.5f}; return true;
}
class Reader {
    Memory &m;
    bool actor(const Handle &h,int camp,bool monster,Actor &out) {
        if(!h.object||!h.sequence)return false;
        uint32_t sequence=0; if(!m.read(h.object+actorSequence,sequence)||sequence!=h.sequence)return false;
        int type=-1,side=0;
        if(!m.read(h.object+actorType,type)||!m.read(h.object+actorCamp,side))return false;
        if(monster){
            if(type!=1)return false;
        } else if(type!=0||side<1||side>8||side==camp)return false;
        auto value=m.pointer(h.object+actorValues); if(!value)return false;
        if(!m.read(value+health,out.hp)||!m.read(value+maxHealth,out.maxHP)||out.hp<=0||out.maxHP<=0||out.hp>out.maxHP||out.maxHP>100000000)return false;
        struct Int3 { int32_t x,y,z; } p{};
        if(!m.read(h.object+actorLocation,p)||std::abs(int64_t(p.x))>100000000||std::abs(int64_t(p.y))>100000000||std::abs(int64_t(p.z))>100000000)return false;
        if(!m.read(h.object+actorConfig,out.config))return false;
        uint32_t after=0; if(!m.read(h.object+actorSequence,after)||after!=sequence)return false;
        out.address=h.object; out.position={p.x*0.001f,p.y*0.001f,p.z*0.001f}; out.monster=monster; return true;
    }
    bool list(uint64_t p,int camp,bool monster,std::vector<Actor> &out) {
        if(!p)return false;
        int count=0,version=0;
        if(!m.read(p+listSize,count)||count<0||count>(monster?256:64)||!m.read(p+listVersion,version))return false;
        if(count==0)return true;
        auto array=m.pointer(p+listItems); uint64_t capacity=0;
        if(!array||!m.read(array+arrayLength,capacity)||capacity<uint64_t(count)||capacity>4096)return false;
        std::vector<Handle> handles(size_t(count),Handle{});
        if(!m.copy(array+arrayData,handles.data(),handles.size()*sizeof(Handle)))return false;
        size_t start=out.size();
        for(const auto &h:handles){ Actor a; if(actor(h,camp,monster,a))out.push_back(a); }
        int after=0,afterCount=0;
        if(!m.read(p+listVersion,after)||after!=version||!m.read(p+listSize,afterCount)||afterCount!=count){ out.resize(start); return false; }
        return true;
    }
public:
    explicit Reader(Memory &memory):m(memory){}
    Snapshot sample(uint64_t base,bool enemies,bool showMonsters) {
        Snapshot out; if(!base||(!enemies&&!showMonsters))return out;
        auto framework=singleton(m,base+frameworkMethod),cameraSystem=singleton(m,base+cameraMethod);
        if(!framework||!cameraSystem)return out;
        auto manager=m.pointer(framework+actorManager),host=m.pointer(framework+hostLogic);
        auto player=host?m.pointer(host+hostPlayer):0;
        int camp=0; if(!manager||!player||!m.read(player+playerCamp,camp)||camp<1||camp>8)return out;
        auto camera=m.pointer(cameraSystem+mainCamera);auto native=camera?m.pointer(camera+nativeCamera):0;
        if(!native||!m.read(native+viewMatrix,out.view)||!m.read(native+projectionMatrix,out.projection)||!validMatrix(out.view)||!validMatrix(out.projection))return out;
        bool ok=true;
        if(enemies)ok=list(m.pointer(manager+heroes),camp,false,out.actors)&&ok;
        if(showMonsters)ok=list(m.pointer(manager+monsters),camp,true,out.actors)&&ok;
        if(!ok){out.actors.clear();out.state=State::changing;}else out.state=State::ready;
        return out;
    }
};
}
