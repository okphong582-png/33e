#include "../core/ShotSettings.h"
#include <cassert>
#include <map>
#include <iostream>
struct Mock: fcm::Memory {
    std::map<uint64_t,uint8_t> bytes;
    bool writable=true;
    unsigned writes=0;
    bool copy(uint64_t a,void *out,size_t n)override{
        auto p=static_cast<uint8_t *>(out);for(size_t i=0;i<n;i++){if(!bytes.count(a+i))return false;p[i]=bytes[a+i];}return true;
    }
    bool store(uint64_t a,const void *v,size_t n)override{if(!writable)return false;writes++;seed(a,v,n);return true;}
    void seed(uint64_t a,const void *v,size_t n){auto p=static_cast<const uint8_t *>(v);for(size_t i=0;i<n;i++)bytes[a+i]=p[i];}
    template<class T>void seed(uint64_t a,T v){seed(a,&v,sizeof(v));}
};
int main(){
    constexpr uint64_t image=0x100000000,manager=0x120000000,object=0x130000000,next=0x140000000;
    Mock m;m.seed(image+0xa25d478,manager);m.seed(manager+0x48,object);m.seed<uint16_t>(object+0x1ce,50);
    fcm::ShotSettings s;
    assert(s.update(m,image,false)==fcm::State::off&&m.writes==0);
    m.writable=false;assert(s.update(m,image,true)==fcm::State::denied&&!s.applied());
    m.writable=true;assert(s.update(m,image,true)==fcm::State::ready&&m.bytes[object+0x1ce]==0);
    unsigned n=m.writes;assert(s.update(m,image,true)==fcm::State::ready&&m.writes==n);
    m.writable=false;assert(s.update(m,image,false)==fcm::State::denied&&s.applied());
    m.writable=true;assert(s.update(m,image,false)==fcm::State::off&&m.bytes[object+0x1ce]==50);
    assert(s.update(m,image,true)==fcm::State::ready);
    m.seed<uint64_t>(image+0xa25d478,0);assert(s.update(m,image,false)==fcm::State::waiting&&s.applied());
    m.seed(image+0xa25d478,manager);assert(s.update(m,image,false)==fcm::State::off&&m.bytes[object+0x1ce]==50);
    assert(s.update(m,image,true)==fcm::State::ready);
    m.seed(manager+0x48,next);m.seed<uint16_t>(next+0x1ce,65);n=m.writes;
    assert(s.update(m,image,false)==fcm::State::off&&m.writes==n&&m.bytes[next+0x1ce]==65);
    assert(s.update(m,image,true)==fcm::State::ready);
    m.seed<uint16_t>(next+0x1ce,75);assert(s.update(m,image,false)==fcm::State::off&&m.bytes[next+0x1ce]==75);
    m.seed<uint16_t>(next+0x1ce,255);n=m.writes;assert(s.update(m,image,true)==fcm::State::unsupported&&m.writes==n);
    std::cout<<"FC Mobile settings lifecycle passed\n";
}
