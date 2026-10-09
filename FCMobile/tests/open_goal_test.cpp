#include "../core/OpenGoal.h"
#include <cassert>
#include <functional>
#include <iostream>
#include <map>
struct Mock: fcm::Memory {
    std::map<uint64_t,uint8_t> bytes;
    bool writable=true,denyVerification=false;
    unsigned writes=0;
    uint64_t lastWrite=0;
    size_t lastSize=0;
    std::function<void(uint64_t)> onRead;
    bool copy(uint64_t a,void *out,size_t n)override{
        if(onRead)onRead(a);
        if(denyVerification&&a==lastWrite){denyVerification=false;return false;}
        auto p=static_cast<uint8_t *>(out);
        for(size_t i=0;i<n;i++){auto v=bytes.find(a+i);if(v==bytes.end())return false;p[i]=v->second;}
        return true;
    }
    bool store(uint64_t a,const void *v,size_t n)override{
        if(!writable)return false;
        writes++;lastWrite=a;lastSize=n;auto p=static_cast<const uint8_t *>(v);
        for(size_t i=0;i<n;i++)bytes[a+i]=p[i];
        return true;
    }
    template<class T>void seed(uint64_t a,const T &v){auto p=reinterpret_cast<const uint8_t *>(&v);for(size_t i=0;i<sizeof(v);i++)bytes[a+i]=p[i];}
};
int main(){
    constexpr uint64_t image=0x100000000,registry=0x120000000,table=0x121000000,wrapper=0x122000000,object=0x123000000,next=0x124000000;
    Mock m;fcm::OpenGoal goal;
    assert(goal.update(m,image,false)==fcm::State::off&&m.writes==0);
    assert(goal.update(m,image,true)==fcm::State::waiting&&m.writes==0);
    m.seed(image+0xa263b60,registry);m.seed(registry+8,table);m.seed(table+123*32+0x20,wrapper);m.seed(wrapper+8,object);
    m.seed<uint8_t>(object,2);assert(goal.update(m,image,true)==fcm::State::unsupported&&m.writes==0);
    m.seed<uint8_t>(object,0);m.seed<uint8_t>(object+1,0x5a);m.writable=false;
    assert(goal.update(m,image,true)==fcm::State::denied&&!goal.applied());
    m.writable=true;assert(goal.update(m,image,true)==fcm::State::ready&&goal.applied());
    assert(m.bytes[object]==1&&m.bytes[object+1]==0x5a&&m.lastWrite==object&&m.lastSize==1);
    unsigned writes=m.writes;assert(goal.update(m,image,true)==fcm::State::ready&&m.writes==writes);
    m.writable=false;assert(goal.update(m,image,false)==fcm::State::denied&&goal.applied());m.writable=true;
    m.seed<uint64_t>(registry+8,0);assert(goal.update(m,image,false)==fcm::State::waiting&&goal.applied());m.seed(registry+8,table);
    assert(goal.update(m,image,false)==fcm::State::off&&!goal.applied()&&m.bytes[object]==0);
    // An already-enabled game flag is reported without taking ownership or writing.
    m.seed<uint8_t>(object,1);writes=m.writes;
    assert(goal.update(m,image,true)==fcm::State::ready&&!goal.applied()&&m.writes==writes);
    assert(goal.update(m,image,false)==fcm::State::off&&m.bytes[object]==1&&m.writes==writes);
    m.seed<uint8_t>(object,0);assert(goal.update(m,image,true)==fcm::State::ready);
    m.seed<uint8_t>(object,0);writes=m.writes;assert(goal.update(m,image,false)==fcm::State::off&&m.writes==writes);
    assert(goal.update(m,image,true)==fcm::State::ready);
    m.seed(wrapper+8,next);m.seed<uint8_t>(next,0);writes=m.writes;
    assert(goal.update(m,image,false)==fcm::State::off&&m.writes==writes&&m.bytes[next]==0);
    // Successful write followed by an unreadable verification still needs restoration.
    m.denyVerification=true;assert(goal.update(m,image,true)==fcm::State::denied&&goal.applied()&&m.bytes[next]==1);
    assert(goal.update(m,image,false)==fcm::State::off&&m.bytes[next]==0);
    // Reject a new component appearing between the value read and the write.
    writes=m.writes;m.onRead=[&](uint64_t a){if(a==next)m.seed(wrapper+8,object);};
    assert(goal.update(m,image,true)==fcm::State::waiting&&m.writes==writes);m.onRead={};
    m.seed(wrapper+8,next);assert(goal.update(m,image,true)==fcm::State::ready);
    assert(goal.update(m,image,false)==fcm::State::off&&m.bytes[next]==0);
    std::cout<<"FC Mobile Open Goal ownership, restoration and stale-root rejection passed\n";
}
