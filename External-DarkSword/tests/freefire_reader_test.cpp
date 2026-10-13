#include "../Features/Games/FreeFire/FreeFireReader.h"
#include <cassert>
#include <iostream>
#include <map>
#include <vector>
#include <limits>

struct Memory {
    std::map<uint64_t,std::vector<uint8_t>> blocks;
    uint64_t next=0x200000;size_t reads=0;uint64_t fail=0,versionAddress=0;bool mutateVersion=false;int versionReads=0;
    uint64_t alloc(size_t n=0x3000) {const auto a=next;next+=0x4000;blocks[a]=std::vector<uint8_t>(n);return a;}
    uint8_t *at(uint64_t a,size_t n) {auto i=blocks.upper_bound(a);if(i==blocks.begin())return nullptr;--i;const auto offset=a-i->first;return offset<=i->second.size()&&n<=i->second.size()-offset?i->second.data()+offset:nullptr;}
    template<class T>void set(uint64_t a,T v) {auto p=at(a,sizeof(v));assert(p);std::memcpy(p,&v,sizeof(v));}
    bool read(uint64_t a,void *p,size_t n) {reads++;if(a==fail)return false;auto src=at(a,n);if(!src)return false;std::memcpy(p,src,n);if(a==versionAddress&&mutateVersion&&++versionReads==2){const int changed=99;std::memcpy(p,&changed,sizeof(changed));}return true;}
};
struct Fixture {
    Memory m;uint64_t base=0x100000000,statics,game,match,local,dict,entries,cameraInner,enemy,headIndices=0;
    Fixture() {
        m.blocks[base]=std::vector<uint8_t>(64);
        m.set(base,uint32_t(0xfeedfacf));m.set(base+4,uint32_t(0x100000c));m.set(base+16,uint32_t(1));m.set(base+20,uint32_t(24));
        m.set(base+32,uint32_t(0x1b));m.set(base+36,uint32_t(24));m.set(base+40,FreeFireESP::UUID);
        const auto type=m.alloc();statics=m.alloc();game=m.alloc();match=m.alloc();dict=m.alloc();entries=m.alloc();const auto controller=m.alloc(),camera=m.alloc();cameraInner=m.alloc();
        m.blocks[base+FreeFireESP::FacadeTypeInfo]=std::vector<uint8_t>(8);
        m.set(base+FreeFireESP::FacadeTypeInfo,type);m.set(type+0xb8,statics);m.set(statics+8,game);m.set(game+0x90,match);m.set(match+0x148,dict);
        m.set(dict+0x18,entries);m.set(dict+0x20,int32_t(1));m.set(dict+0x24,int32_t(7));m.versionAddress=dict+0x24;m.set(entries+0x18,uint64_t(256));
        m.set(game+0xd8,controller);m.set(controller+0x20,camera);m.set(camera+0x10,cameraInner);
        const std::array<float,16> identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};m.set(cameraInner+0x80,identity);m.set(cameraInner+0xc0,identity);
        local=player(1,200);m.set(match+0xd8,local);enemy=player(2,150);entry(0,enemy);
    }
    uint64_t transform(FreeFireESP::Vec3 position,uint64_t *indexOut=nullptr) {
        const auto transform=m.alloc(),inner=m.alloc(),matrix=m.alloc(),list=m.alloc(),indices=m.alloc();
        m.set(transform+0x10,inner);m.set(inner+0x38,matrix);m.set(inner+0x40,int32_t(0));m.set(matrix+0x18,list);m.set(matrix+0x20,indices);
        FreeFireESP::Transform t{};t.position[0]=position.x;t.position[1]=position.y;t.position[2]=position.z;t.rotation[3]=1;t.scale[0]=t.scale[1]=t.scale[2]=1;m.set(list,t);m.set(indices,int32_t(-1));if(indexOut)*indexOut=indices;return transform;
    }
    uint64_t player(uint8_t team,uint16_t hp) {
        const auto player=m.alloc(),pool=m.alloc(),poolEntries=m.alloc(),hpEntry=m.alloc(),head=m.alloc(),foot=m.alloc();
        m.set(player+0x410,team);m.set(player+0x70,pool);m.set(pool+0x10,poolEntries);m.set(poolEntries+0x20,hpEntry);m.set(hpEntry+0x18,hp);
        m.set(player+0x6a0,head);m.set(player+0x6d8,foot);m.set(head+0x10,transform({0,.6f,1},&headIndices));m.set(foot+0x10,transform({0,-.6f,1}));return player;
    }
    void entry(int i,uint64_t player,int32_t hash=1) {const auto a=entries+0x20+24ull*i;m.set(a,hash);m.set(a+16,player);}
};
int main() {
    int checks=0;auto check=[&](bool ok){assert(ok);++checks;};
    Fixture f;auto read=[&](uint64_t a,void *p,size_t n){return f.m.read(a,p,n);};FreeFireESP::Reader<decltype(read)> reader(read);FreeFireESP::Frame frame;
    check(reader.supports(f.base));check(reader.snapshot(f.base,1000,800,frame));check(frame.count==1);check(frame.targets[0].id==f.enemy);check(std::abs(frame.targets[0].h-480)<.01f);check(std::abs(frame.targets[0].headX-500)<.01f);
    auto wrong=FreeFireESP::UUID;wrong[0]^=1;f.m.set(f.base+40,wrong);check(!reader.supports(f.base));f.m.set(f.base+40,FreeFireESP::UUID);
    f.m.set(f.base+36,uint32_t(0));check(!reader.supports(f.base));f.m.set(f.base+36,uint32_t(24));
    f.m.set(f.dict+0x20,int32_t(6));f.entry(1,f.local);f.entry(2,f.player(1,200));f.entry(3,f.player(2,0));f.entry(4,f.enemy);f.entry(5,f.player(2,100),-1);
    check(reader.snapshot(f.base,1000,800,frame)&&frame.count==1);check(!reader.snapshot(f.base,0,800,frame)&&frame.count==0);
    f.m.mutateVersion=true;f.m.versionReads=0;check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);f.m.mutateVersion=false;
    f.m.set(f.entries+0x18,uint64_t(1000000));const auto before=f.m.reads;check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);check(f.m.reads-before<40);f.m.set(f.entries+0x18,uint64_t(256));
    f.m.fail=f.cameraInner+0x80;check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);f.m.fail=0;
    f.m.set(f.cameraInner+0x80,std::numeric_limits<float>::quiet_NaN());check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);f.m.set(f.cameraInner+0x80,1.f);
    f.m.set(f.statics+8,uint64_t(0));f.m.set(f.statics,f.game);check(reader.snapshot(f.base,1000,800,frame)&&frame.count==1);
    f.m.set(f.statics,uint64_t(0));check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);f.m.set(f.statics+8,f.game);
    // A corrupt transform parent cycle must drop that target, never spin.
    f.m.set(f.dict+0x20,int32_t(1));uint64_t headNode=0,trans=0,inner=0,matrix=0,indices=0;
    check(f.m.read(f.enemy+0x6a0,&headNode,8)&&f.m.read(headNode+0x10,&trans,8)&&f.m.read(trans+0x10,&inner,8)&&f.m.read(inner+0x38,&matrix,8)&&f.m.read(matrix+0x20,&indices,8));
    f.m.set(indices,int32_t(0));check(reader.snapshot(f.base,1000,800,frame)&&frame.count==0);f.m.set(indices,int32_t(-1));
    // Bound a dense roster to 32 targets and retain no frame history.
    for(int i=0;i<40;i++)f.entry(i,f.player(2,100));f.m.set(f.dict+0x20,int32_t(40));check(reader.snapshot(f.base,1000,800,frame)&&frame.count==32);
    for(int i=0;i<120;i++)check(reader.snapshot(f.base,1000,800,frame)&&frame.count==32);
    f.m.set(f.dict+0x20,int32_t(-1));check(!reader.snapshot(f.base,1000,800,frame)&&frame.count==0);
    std::cout<<"PASS "<<checks<<" FF reader checks: UUID, projection, teams/HP, duplicates, failed reads, roster mutation, transform cycles and bounded dense frames.\n";
}
