#include "SilentDirection.h"
#include <jni.h>
#include <atomic>
#include <mutex>
#include <thread>
#include <string>
#include <fstream>
#include <cstdio>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/uio.h>
#include <sys/syscall.h>
#include <poll.h>
#include <time.h>

namespace {
constexpr uint64_t Magic=0x31544e454c49534dULL;
constexpr uint64_t HandlerRva=0x74AAB14;
constexpr uint64_t SlotOffset=0x138+17*16;
struct Packet {
    uint64_t magic;uint32_t version,size;
    uint64_t sequence,base,game,match,local,target,sample,lease;
    silent::Point point;uint32_t flags;
};
struct Reply {uint64_t magic,sequence,redirects;uint32_t ready,error;};
static_assert(sizeof(Packet)==96&&sizeof(Reply)==32);
static_assert(offsetof(Packet,sequence)==16&&offsetof(Packet,base)==24&&offsetof(Packet,target)==56);
static_assert(offsetof(Packet,sample)==64&&offsetof(Packet,lease)==72&&offsetof(Packet,point)==80&&offsetof(Packet,flags)==92);
Packet snapshot{};
std::mutex snapshotMutex;
std::recursive_mutex dispatchMutex;
std::atomic<uint64_t> original{},redirects{},restoreFailures{};
uint64_t installedSlot{};
uint32_t lastError{};
using Handler=void(*)(uint64_t,const void*);
uint64_t now() {timespec t{};clock_gettime(CLOCK_BOOTTIME,&t);return uint64_t(t.tv_sec)*1000+t.tv_nsec/1000000;}
bool address(uint64_t p,size_t size) {return p>=0x10000&&p<0x0001000000000000ULL&&size<=0x0001000000000000ULL-p;}
bool readBytes(uint64_t at,void* data,size_t size) {
    if(!address(at,size))return false;
    iovec local{data,size},remote{reinterpret_cast<void*>(at),size};
    return syscall(__NR_process_vm_readv,getpid(),&local,1,&remote,1,0)==ssize_t(size);
}
template<class T> bool read(uint64_t at,T& v) {return readBytes(at,&v,sizeof(v));}
uint64_t ptr(uint64_t at) {uint64_t p{};return read(at,p)?p:0;}
uint32_t word(uint64_t at) {uint32_t v{};return read(at,v)?v:UINT32_MAX;}
int byte(uint64_t at) {uint8_t v{};return read(at,v)?v:-1;}
bool text(uint64_t at,const char* expected) {
    char buffer[64]{};size_t length=std::strlen(expected)+1;
    return length<=sizeof(buffer)&&readBytes(at,buffer,length)&&!std::memcmp(buffer,expected,length);
}
bool klassNamed(uint64_t klass,const char* name,const char* ns) {
    return text(ptr(klass+16),name)&&text(ptr(klass+24),ns);
}
bool named(uint64_t object,const char* name,const char* ns) {return klassNamed(ptr(object),name,ns);}
bool instance(uint64_t object,uint64_t expected) {
    const auto actual=ptr(object);const int depth=byte(actual+0x130),wanted=byte(expected+0x130);
    return wanted>0&&wanted<=32&&depth>=wanted&&depth<=32&&ptr(ptr(actual+0xC8)+(wanted-1)*8)==expected;
}
bool isA(uint64_t object,const char* name,const char* ns) {
    const auto klass=ptr(object),chain=ptr(klass+0xC8);const int depth=byte(klass+0x130);
    if(depth<1||depth>32||!chain)return false;
    for(int i=0;i<depth;++i)if(klassNamed(ptr(chain+i*8),name,ns))return true;
    return false;
}
int pri(uint64_t player,int index) {
    const auto pool=ptr(player+0x70);const bool unsafe=named(pool,"PRIDataPoolUnsafe","GCommon");
    if(!unsafe&&!named(pool,"PRIDataPool","GCommon"))return -1;
    const auto array=ptr(pool+0x10);const auto count=word(pool+0x18),length=ptr(array+0x18);
    if(count<=uint32_t(index)||count>4096||length<=uint32_t(index)||length>4096)return -1;
    const auto entry=ptr(array+0x20+index*8);if(!entry)return -1;
    const auto at=unsafe?ptr(entry+0x18):entry+0x18;
    if(index==12||index==21||index==34)return byte(at);
    uint16_t value{};return read(at,value)?int(value):-1;
}
bool alive(uint64_t player) {
    const int hp=pri(player,0),max=pri(player,1);
    const auto controller=ptr(player+0x1D48),node=ptr(controller+0x20);
    const auto pose=word(node+0x10);
    return hp>0&&max>=hp&&max<=10000&&named(controller,"GFLBFKKDAMK","")&&
        ptr(controller+0x10)==player&&isA(node,"EIILAKAAIOP","")&&ptr(node+0x18)==player&&pose<39&&pose!=8;
}
uint64_t weapon(uint64_t player) {
    const auto storage=ptr(player+0x740);const int alternate=byte(storage+0x148);
    if(alternate<0||alternate>1)return 0;
    const auto w=ptr(storage+(alternate?0xA8:0xA0));
    return ptr(w+0x60)==player?w:0;
}
bool firing(uint64_t base,uint64_t player,uint64_t w) {
    const auto expected=ptr(ptr(base+0xA741C20));if(!instance(w,expected))return false;
    const auto getter=ptr(ptr(w)+0xED8);
    if(getter==base+0x7499544)return byte(w+0x988)==1;
    if(getter!=base+0x7479358)return false;
    const auto machine=ptr(w+0x90);if(!machine)return false;
    const auto globals=ptr(ptr(base+0xA72E9C8)),statics=ptr(globals+0xB8);
    const int mode=byte(statics+0x191D);if(mode<0)return false;
    if(mode)return byte(machine+0x20)==1;
    const auto state=word(ptr(machine+0x18)+0x10);const auto index=state-3;
    return (index<13&&((0x1F9F>>index)&1))||(state&~1U)==16;
}
bool profile(uint64_t base) {
    uint8_t handler[0x300]{};if(!read(base+HandlerRva,handler))return false;
    uint32_t hash=0x811C9DC5;for(auto value:handler)hash=(hash^value)*0x01000193U;
    // Exact Android instructions. No offsets or executable code are copied from iOS.
    return hash==0xC4129ED7&&word(base+0x74AAC3C)==0xF8428E88&&word(base+0x74AAC48)==0x2D482508&&
        word(base+0x74AAC4C)==0xBD40490A&&word(base+0x7466FB0)==0xF8080E74&&
        word(base+0x6F157F8)==0xF94EA660&&word(base+0x70DA738)==0xF9401260&&
        word(base+0x70DCF54)==0xB9401260&&word(base+0x74793B8)==0xF9404A60;
}
bool member(uint64_t match,uint64_t local,uint64_t target) {
    const auto dictionary=ptr(match+0x148),entries=ptr(dictionary+0x18);
    if(!named(dictionary,"Dictionary`2","System.Collections.Generic"))return false;
    const auto count=word(dictionary+0x20),version=word(dictionary+0x2C);
    if(count<1||count>256||ptr(entries+0x18)<count||ptr(entries+0x18)>4096)return false;
    bool hasLocal=false,hasTarget=false;
    for(uint32_t i=0;i<count;++i){const auto entry=entries+0x20+i*24;
        if(int32_t(word(entry))<0)continue;const auto player=ptr(entry+16);
        hasLocal|=player==local;hasTarget|=player==target;
    }
    return hasLocal&&hasTarget&&ptr(match+0x148)==dictionary&&ptr(dictionary+0x18)==entries&&word(dictionary+0x2C)==version;
}
bool context(const Packet& p) {
    const auto facade=ptr(p.base+0xAC1E768),statics=ptr(facade+0xB8);
    return isA(ptr(statics),"MatchGame","COW")&&ptr(statics)==p.game&&
        ptr(p.game+0x90)==p.match&&ptr(p.match+0xD8)==p.local&&byte(p.local+0x420)==1;
}
bool writable(uint64_t at,size_t size) {
    std::ifstream maps("/proc/self/maps");std::string line;
    while(std::getline(maps,line)){unsigned long long lo{},hi{};char mode[5]{};
        if(std::sscanf(line.c_str(),"%llx-%llx %4s",&lo,&hi,mode)==3&&at>=lo&&at<hi&&size<=hi-at)
            return mode[0]=='r'&&mode[1]=='w';
    }return false;
}
void redirect(uint64_t handler,const void* method) {
    std::lock_guard<std::recursive_mutex> dispatchGuard(dispatchMutex);
    const auto call=reinterpret_cast<Handler>(original.load());if(!call)return;
    Packet p{};{std::lock_guard<std::mutex> guard(snapshotMutex);p=snapshot;}
    if(!(p.flags&1)||!p.target||!silent::fresh(p.sample,p.lease,now())){call(handler,method);return;}
    const auto w=ptr(handler+0x10),info=ptr(handler+0x28);
    const int localTeam=pri(p.local,34),targetTeam=pri(p.target,34);
    const bool fire=firing(p.base,p.local,w),scope=pri(p.local,12)==1;
    const bool trigger=(p.flags&8)||((p.flags&2)&&fire)||((p.flags&4)&&scope)||((p.flags&16)&&fire&&scope);
    silent::Point origin{},desired{};
    if(!(p.flags&1)||!p.target||!silent::fresh(p.sample,p.lease,now())||!context(p)||!trigger||!fire||
        !member(p.match,p.local,p.target)||!isA(p.target,"Player","COW.GamePlay")||!alive(p.local)||!alive(p.target)||
        localTeam<0||targetTeam<0||(localTeam>0&&localTeam==targetTeam)||weapon(p.local)!=w||
        ptr(w+0x80)!=handler||!named(info,"CGKJLKPMGDJ","COW.GamePlay")||
        !read(info+0x4C,origin)||!silent::toward(origin,p.point,desired)) {call(handler,method);return;}
    bool current=false;{std::lock_guard<std::mutex> guard(snapshotMutex);current=snapshot.sequence==p.sequence&&(snapshot.flags&1);}
    if(!current){call(handler,method);return;}
    const auto owned=[&]{return ptr(handler+0x28)==info&&ptr(handler+0x10)==w&&ptr(w+0x80)==handler;};
    const auto write=[&](silent::Point v){iovec local{&v,sizeof(v)},remote{reinterpret_cast<void*>(info+0x40),sizeof(v)};
        return syscall(__NR_process_vm_writev,getpid(),&local,1,&remote,1,0)==ssize_t(sizeof(v));};
    const auto result=silent::dispatch(desired,[&](silent::Point& v){return read(info+0x40,v);},write,owned,[&]{call(handler,method);});
    if(result.redirected)redirects.fetch_add(1);if(result.restoreFailed)restoreFailures.fetch_add(1);
}
void uninstall() {
    std::lock_guard<std::recursive_mutex> guard(dispatchMutex);
    if(!installedSlot)return;
    if(writable(installedSlot,8)){auto expected=reinterpret_cast<uint64_t>(&redirect);
        if(__atomic_compare_exchange_n(reinterpret_cast<uint64_t*>(installedSlot),&expected,original.load(),false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST)||expected!=reinterpret_cast<uint64_t>(&redirect))installedSlot=0;
    }
}
void clear() {{std::lock_guard<std::mutex> guard(snapshotMutex);snapshot={};}uninstall();}
bool update(const Packet& p) {
    if(p.magic!=Magic||p.version!=1||p.size!=sizeof(Packet)||(p.flags&~31)||!p.sequence||
        !silent::fresh(p.sample,p.lease,now())||!(p.flags&1)){clear();lastError=0;return false;}
    if(!profile(p.base)){clear();lastError=1;return false;}
    if(!context(p)){clear();lastError=2;return false;}
    const auto w=weapon(p.local),h=ptr(w+0x80),klass=ptr(h),slot=klass+SlotOffset;
    if(!w||ptr(h+0x10)!=w||!named(h,"MDPBNKPCGNG","COW.GamePlay")){clear();lastError=3;return false;}
    std::lock_guard<std::recursive_mutex> guard(dispatchMutex);
    if(installedSlot&&installedSlot!=slot)uninstall();
    if(installedSlot&&installedSlot!=slot){lastError=4;return false;}
    if(!installedSlot){
        if(!writable(slot,8)){lastError=4;return false;}
        auto expected=p.base+HandlerRva;original.store(expected);
        if(!__atomic_compare_exchange_n(reinterpret_cast<uint64_t*>(slot),&expected,reinterpret_cast<uint64_t>(&redirect),false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST)){lastError=4;return false;}
        installedSlot=slot;
    }
    if(ptr(slot)!=reinterpret_cast<uint64_t>(&redirect)){clear();lastError=4;return false;}
    {std::lock_guard<std::mutex> snapshotGuard(snapshotMutex);snapshot=p;}
    lastError=0;return true;
}
bool receive(int fd,void* output,size_t length) {
    auto* data=static_cast<char*>(output);size_t offset=0;
    while(offset<length){pollfd event{fd,POLLIN,0};const int ready=poll(&event,1,50);
        if(ready==0){Packet p{};{std::lock_guard<std::mutex> guard(snapshotMutex);p=snapshot;}
            if(!silent::fresh(p.sample,p.lease,now()))clear();continue;}
        if(ready<0||!(event.revents&POLLIN))return false;
        const auto n=recv(fd,data+offset,length-offset,0);if(n<=0)return false;offset+=size_t(n);
    }return true;
}
void serve() {
    const int server=socket(AF_UNIX,SOCK_STREAM|SOCK_CLOEXEC,0);if(server<0)return;
    sockaddr_un addr{};addr.sun_family=AF_UNIX;
    const std::string name="mizze.silent.v1."+std::to_string(getpid());
    std::memcpy(addr.sun_path+1,name.data(),name.size());
    if(bind(server,reinterpret_cast<sockaddr*>(&addr),offsetof(sockaddr_un,sun_path)+1+name.size())||listen(server,1)){close(server);return;}
    for(;;){const int fd=accept4(server,nullptr,nullptr,SOCK_CLOEXEC);if(fd<0)continue;
        ucred peer{};socklen_t size=sizeof(peer);
        if(getsockopt(fd,SOL_SOCKET,SO_PEERCRED,&peer,&size)||peer.uid!=0){close(fd);continue;}
        uint64_t previous=0;Packet p{};
        while(receive(fd,&p,sizeof(p))){
            if(p.sequence<=previous){clear();break;}previous=p.sequence;
            bool ready=update(p);if(restoreFailures.load()){clear();ready=false;lastError=5;}
            Reply reply{Magic,p.sequence,redirects.load(),uint32_t(ready),lastError};
            if(send(fd,&reply,sizeof(reply),MSG_NOSIGNAL)!=ssize_t(sizeof(reply)))break;
        }clear();close(fd);
    }
}
}
extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM*,void* key) {
    if(key!=reinterpret_cast<void*>(1337))return JNI_VERSION_1_6;
    char name[64]{};FILE* in=fopen("/proc/self/cmdline","rb");if(!in)return JNI_VERSION_1_6;
    fread(name,1,sizeof(name)-1,in);fclose(in);
    if(std::strcmp(name,"com.dts.freefireth"))return JNI_VERSION_1_6;
    static std::atomic<bool> started{false};if(!started.exchange(true))std::thread(serve).detach();
    return JNI_VERSION_1_6;
}
