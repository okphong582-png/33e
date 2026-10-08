#include "../core/Reader.h"
#include <cassert>
#include <iostream>
#include <map>
using namespace aov;
struct FakeMemory : Memory {
    std::map<uint64_t,std::vector<uint8_t>> blocks;
    uint64_t next=0x10000,mutate=0;int reads=0;
    uint64_t allocate(size_t size=4096){uint64_t p=next;next+=8192;blocks[p].resize(size);return p;}
    bool copy(uint64_t p,void *out,size_t size)override {
        auto it=blocks.upper_bound(p);if(it==blocks.begin())return false;--it;
        if(p-it->first>it->second.size()||size>it->second.size()-(p-it->first))return false;
        std::memcpy(out,it->second.data()+p-it->first,size);
        if(p==mutate&&++reads>1){int changed=99;std::memcpy(out,&changed,size);}
        return true;
    }
    template<class T>void write(uint64_t p,T value){auto it=blocks.upper_bound(p);assert(it!=blocks.begin());--it;assert(p-it->first+sizeof(T)<=it->second.size());std::memcpy(it->second.data()+p-it->first,&value,sizeof(value));}
    uint64_t single(uint64_t slot){blocks[slot].resize(8);auto method=allocate(),owner=allocate(),context=allocate(),klass=allocate(),statics=allocate(),object=allocate();write(slot,method);write(method+methodContext,owner);write(owner+classContext,context);write(context+contextClass,klass);write(klass+staticFields,statics);write(statics,object);return object;}
    Handle makeActor(int type,int camp,int sub,int hp,uint32_t config){
        auto object=allocate(),value=allocate();uint32_t seq=123;
        write(object+actorSequence,seq);write(object+actorType,type);write(object+actorCamp,camp);write(object+actorSubType,sub);write(object+actorValues,value);write(object+actorConfig,config);
        struct Int3{int x,y,z;};write(object+actorLocation,Int3{1000,0,-10000});write(value+health,hp);write(value+maxHealth,100);return {seq,0,object};
    }
    uint64_t makeList(std::initializer_list<Handle> handles){auto list=allocate(),array=allocate();write(list+listItems,array);write(list+listSize,int(handles.size()));write(list+listVersion,1);write(array+arrayLength,uint64_t(handles.size()));int i=0;for(auto h:handles)write(array+arrayData+(i++)*sizeof(Handle),h);return list;}
};
int main(){
    FakeMemory m;constexpr uint64_t base=0x10000000;
    auto framework=m.single(base+frameworkMethod),camSystem=m.single(base+cameraMethod);
    auto manager=m.allocate(),host=m.allocate(),player=m.allocate(),camera=m.allocate(),native=m.allocate();
    m.write(framework+actorManager,manager);m.write(framework+hostLogic,host);m.write(host+hostPlayer,player);m.write(player+playerCamp,1);
    m.write(camSystem+mainCamera,camera);m.write(camera+nativeCamera,native);
    Matrix identity;for(int i=0;i<4;i++)identity.m[i*5]=1;
    m.write(native+viewMatrix,identity);m.write(native+projectionMatrix,identity);
    auto enemy=m.makeActor(0,2,0,75,101),teammate=m.makeActor(0,1,0,100,102),dead=m.makeActor(0,2,0,0,103),recycled=m.makeActor(0,2,0,100,104);recycled.sequence++;
    auto blue=m.makeActor(1,0,14,100,201),red=m.makeActor(1,0,15,100,202),soldierBlue=m.makeActor(1,0,0,100,203);m.write(soldierBlue.object+soldierType,uint8_t(50));
    auto h=m.makeList({enemy,teammate,dead,recycled}),b=m.makeList({blue,red,soldierBlue});m.write(manager+heroes,h);m.write(manager+monsters,b);
    Reader r(m);auto s=r.sample(base,true,true);assert(s.state==State::ready&&s.actors.size()==3);assert(s.actors[0].config==101&&!s.actors[0].blue);assert(s.actors[1].blue&&s.actors[2].blue);assert(s.actors[0].position.x==1);
    assert(r.sample(base,false,true).actors.size()==2);assert(r.sample(base,true,false).actors.size()==1);assert(r.sample(base,false,false).actors.empty());
    Point p;assert(project({0,0,-10},identity,identity,320,180,p)&&p.x==160&&p.y==90);assert(!project({0,0,1},identity,identity,320,180,p));assert(!project({100,0,-10},identity,identity,320,180,p));assert(!project({0,0,-10},identity,identity,0,180,p));
    Matrix bad=identity;bad.m[0]=std::numeric_limits<float>::quiet_NaN();assert(!validMatrix(bad));assert(!project({0,0,-10},identity,bad,320,180,p));
    m.write(h+listSize,100000);s=r.sample(base,true,true);assert(s.state==State::changing&&s.actors.empty());m.write(h+listSize,4);
    m.mutate=h+listVersion;s=r.sample(base,true,true);assert(s.state==State::changing&&s.actors.empty());m.mutate=0;
    m.write(player+playerCamp,0);assert(r.sample(base,true,true).actors.empty());m.write(player+playerCamp,1);
    m.write(native+viewMatrix,Matrix{});assert(r.sample(base,true,true).state==State::waiting);
    uint64_t invalid=UINT64_MAX;assert(!m.pointer(invalid));assert(!singleton(m,0xDEAD000));
    std::cout<<"AOV ESP: enemy/blue filtering, stale handles, changing lists and projection passed\n";
}
