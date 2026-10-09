#include "../core/BallReader.h"
#include <cassert>
#include <functional>
#include <iostream>
#include <limits>
#include <map>
struct Mock: fcm::Memory {
    std::map<uint64_t,uint8_t> bytes;
    std::function<void(uint64_t)> onRead;
    unsigned writes=0;
    bool copy(uint64_t a,void *out,size_t n)override{
        if(onRead)onRead(a);
        auto p=static_cast<uint8_t *>(out);
        for(size_t i=0;i<n;i++){auto v=bytes.find(a+i);if(v==bytes.end())return false;p[i]=v->second;}
        return true;
    }
    bool store(uint64_t,const void *,size_t)override{writes++;return false;}
    template<class T>void seed(uint64_t a,const T &v){auto p=reinterpret_cast<const uint8_t *>(&v);for(size_t i=0;i<sizeof(v);i++)bytes[a+i]=p[i];}
};
static fcm::Matrix identity(){fcm::Matrix m;m.v[0]=m.v[5]=m.v[10]=m.v[15]=1;return m;}
static bool near(float a,float b){return std::fabs(a-b)<1e-5f;}
int main(){
    auto view=identity(),projection=identity();projection.v[11]=-1;projection.v[15]=0;
    auto p=fcm::projectBall({0,0,-10,1},view,projection);assert(p.visible&&near(p.x,.5f)&&near(p.y,.5f));
    p=fcm::projectBall({5,2,-10,1},view,projection);assert(p.visible&&near(p.x,.75f)&&near(p.y,.4f));
    assert(!fcm::projectBall({0,0,1,1},view,projection).visible);
    assert(!fcm::projectBall({11,0,-10,1},view,projection).visible);
    assert(!fcm::projectBall({0,-11,-10,1},view,projection).visible);
    assert(!fcm::projectBall({0,0,0,1},view,projection).visible);
    assert(!fcm::projectBall({std::numeric_limits<float>::quiet_NaN(),0,-10,1},view,projection).visible);
    auto broken=projection;broken.v[0]=std::numeric_limits<float>::infinity();
    assert(!fcm::projectBall({0,0,-10,1},view,broken).visible);
    broken=projection;broken.v[11]=broken.v[15]=0;
    assert(!fcm::projectBall({0,0,-10,1},view,broken).visible);
    // A quarter-turn camera must project a world point on its new forward axis.
    auto rotated=identity();rotated.v[0]=rotated.v[10]=0;rotated.v[2]=-1;rotated.v[8]=1;
    p=fcm::projectBall({10,0,0,1},rotated,projection);assert(p.visible&&near(p.x,.5f));
    view.v[12]=-5;p=fcm::projectBall({5,0,-10,1},view,projection);assert(p.visible&&near(p.x,.5f));view=identity();
    constexpr uint64_t image=0x100000000,registry=0x120000000,scene=0x121000000,table=0x122000000;
    constexpr uint64_t wrapper=0x123000000,data=0x124000000,balls=0x125000000,ball=0x126000000;
    constexpr uint64_t writer=0x127000000,history=0x128000000,manager=0x129000000,camera=0x130000000,storage=0x131000000;
    Mock m;m.seed(image+0xa263b60,registry);m.seed(registry,scene);m.seed(registry+8,table);
    m.seed<int32_t>(scene+0x226d8,2);m.seed(table+34*32+0x20,wrapper);m.seed(wrapper+8,data);
    m.seed(data+0x38,balls);m.seed(balls+2*8,ball);m.seed(ball+0x90,writer);m.seed(writer+0x230,history);
    m.seed<int32_t>(history+0x9610,601);m.seed(history+64+0x10,fcm::Vec4{5,2,-10,1});
    m.seed(image+0xa2bf528,manager);m.seed<int32_t>(manager+0x40,3);m.seed(manager+3*8,camera);
    m.seed(camera,image+0x529d148);m.seed(camera+8,storage);m.seed(storage,projection);m.seed(storage+0x40,view);
    fcm::BallReader reader(m);p=reader.sample(image);assert(p.visible&&near(p.x,.75f)&&near(p.y,.4f)&&m.writes==0);
    m.seed<int32_t>(scene+0x226d8,12);assert(!reader.sample(image).visible);m.seed<int32_t>(scene+0x226d8,2);
    m.seed<int32_t>(manager+0x40,4);assert(!reader.sample(image).visible);m.seed<int32_t>(manager+0x40,3);
    m.seed<int32_t>(history+0x9610,-1);assert(!reader.sample(image).visible);m.seed<int32_t>(history+0x9610,601);
    m.seed(camera,image+0x1234);assert(!reader.sample(image).visible);m.seed(camera,image+0x529d148);
    m.seed<uint64_t>(writer+0x230,history+1);assert(!reader.sample(image).visible);m.seed(writer+0x230,history);
    auto saved=m.bytes;m.bytes.erase(storage+12);assert(!reader.sample(image).visible);m.bytes=saved;
    // Scene replacement, camera replacement, and a new history frame invalidate stale lines.
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed(registry,scene+0x1000);};
    assert(!reader.sample(image).visible);m.onRead={};m.bytes=saved;
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed(manager+3*8,camera+0x1000);};
    assert(!reader.sample(image).visible);m.onRead={};m.bytes=saved;
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed<int32_t>(history+0x9610,602);};
    assert(!reader.sample(image).visible);m.onRead={};m.bytes=saved;
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed(writer+0x230,history+0x1000);};
    assert(!reader.sample(image).visible);m.onRead={};m.bytes=saved;
    assert(reader.sample(image).visible&&m.writes==0);
    // Regular matches have no Lua practice scene. Native match consumers use ball 0.
    m.seed<uint64_t>(image+0xa263b60,0);m.seed(image+0xa3f4318,table);
    m.seed<int32_t>(table+34*32+0x18,1);m.seed(balls,ball);
    assert(reader.sample(image).visible&&m.writes==0);
    m.seed<uint64_t>(image+0xa3f4318,0);assert(reader.sample(image).issue==fcm::BallIssue::source);m.seed(image+0xa3f4318,table);
    m.seed<int32_t>(table+34*32+0x18,0);assert(reader.sample(image).issue==fcm::BallIssue::source);
    m.seed<int32_t>(table+34*32+0x18,2);assert(reader.sample(image).issue==fcm::BallIssue::source);m.seed<int32_t>(table+34*32+0x18,1);
    m.seed<uint64_t>(balls,0);assert(reader.sample(image).issue==fcm::BallIssue::ball);m.seed(balls,ball);
    m.seed<int32_t>(history+0x9610,-1);assert(reader.sample(image).issue==fcm::BallIssue::history);m.seed<int32_t>(history+0x9610,601);
    m.seed<int32_t>(manager+0x40,4);assert(reader.sample(image).issue==fcm::BallIssue::camera);m.seed<int32_t>(manager+0x40,3);
    auto matchSaved=m.bytes;
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed<uint64_t>(image+0xa3f4318,0);};
    assert(reader.sample(image).issue==fcm::BallIssue::changing);m.onRead={};m.bytes=matchSaved;
    m.onRead=[&](uint64_t a){if(a==storage+0x40)m.seed<int32_t>(table+34*32+0x18,0);};
    assert(reader.sample(image).issue==fcm::BallIssue::changing);m.onRead={};m.bytes=matchSaved;
    assert(reader.sample(image).visible&&m.writes==0);
    std::cout<<"FC Mobile ball projection and stale-sample rejection passed\n";
}
