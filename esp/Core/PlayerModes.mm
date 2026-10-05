#include "PlayerModes.h"
#if defined(__aarch64__) || defined(__arm64__)
#include "PlayerModesLayout.h"
#include "PlayerModesInstallPolicy.h"
#include "SilentAimRemoteMapping.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>
#include <vector>
extern "C" const unsigned char PlayerModesRemoteStart[], PlayerModesRemoteEnd[];
namespace {
constexpr uint64_t Slot=PlayerModesInstall::Slots[0];
struct Signature { uint64_t offset; size_t size; uint32_t hash; };
constexpr Signature signatures[] = {
    {0x5660700,0x844,0x4C79AF54},{0x5A4BEC0,0x654,0x7C4BDB69},
    {0x5A4C690,0x41C,0xE5A62294},{0x6B49D04,0x10C,0x5C6FFC2C},
    {0x6B49E10,0x104,0xAACE9654},{0x591B898,0x1C8,0x92F2568B},
    {0x56AA7C8,0x110,0x4478C55F},{0x561CA30,0xB4,0xABF31A13},
    {0x561C7C8,0x6C,0x7958F6CC},{0x5636F20,0x60,0x6E4B75FE},
    {0x6B4A924,0x8,0x64A6725A}
};
struct Session {
    uint64_t slot=0, allocation=0, original=0;
    uint32_t sequence=0;
    bool published=false;
    uint64_t state()const{return allocation+MODES_PAGE;}
};
std::recursive_mutex mutex;
mach_port_t task=MACH_PORT_NULL;
int pid=-1;
uint64_t module=0, ownerMatch=0, ownerLocal=0;
uint32_t wanted=0, epoch=0, previousFlags=0;
bool verified=false;
double retryAt=0;
int lastResult=1;
PlayerModesSnapshot snapshot{};
double lastSample=0, lastTickAt=0;
uint64_t sampledTicks=0;
std::vector<Session> sessions;
bool ReadBytes(uint64_t address,void *value,size_t size){
    mach_vm_size_t actual=0;
    return task!=MACH_PORT_NULL&&isVaildPtr(address)&&
        mach_vm_read_overwrite(task,address,size,(mach_vm_address_t)value,&actual)==KERN_SUCCESS&&actual==size;
}
template<class T>bool Read(uint64_t address,T &value){return ReadBytes(address,&value,sizeof(value));}
bool WriteBytes(uint64_t address,const void *value,size_t size){
    return task!=MACH_PORT_NULL&&isVaildPtr(address)&&
        mach_vm_write(task,address,(pointer_t)value,(mach_msg_type_number_t)size)==KERN_SUCCESS;
}
template<class T>bool Write(uint64_t address,const T &value){return WriteBytes(address,&value,sizeof(value));}
bool Publish(Session &session,const PlayerModesRemote::Input &input){
    uint32_t odd=(session.sequence+1)|1u;session.sequence=odd+1;session.published=true;
    return Write(session.state()+MODES_SEQUENCE,odd)&&
        Write(session.state()+MODES_FLAGS,input)&&Write(session.state()+MODES_SEQUENCE,session.sequence);
}
void Clear(){
    PlayerModesRemote::Input off{};off.epoch=++epoch;
    for(auto &session:sessions)if(session.published&&Publish(session,off))session.published=false;
    ownerMatch=ownerLocal=0;previousFlags=0;
    snapshot.burrow=snapshot.heldEnemies=0;snapshot.running=false;
    // Keep executable callbacks mapped while game threads may still use them.
    // Each callback restores its own held transform before its original update.
}
bool Attach(uint64_t base){
#ifdef MIZZE_INJECTED
    const mach_port_t candidate=mach_task_self();
#else
    const mach_port_t candidate=get_task;
#endif
    int candidatePID=-1;
    if(candidate==MACH_PORT_NULL||pid_for_task(candidate,&candidatePID)!=KERN_SUCCESS){Clear();return false;}
    if(task==candidate&&pid==candidatePID&&module==base)return true;
    Clear();
    if(task!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),task);
    task=MACH_PORT_NULL;sessions.clear();verified=false;retryAt=0;
    snapshot={};lastSample=lastTickAt=0;sampledTicks=0;
    if(mach_port_mod_refs(mach_task_self(),candidate,MACH_PORT_RIGHT_SEND,1)!=KERN_SUCCESS)return false;
    task=candidate;pid=candidatePID;module=base;return true;
}
bool Verify(){
    if(verified)return true;
    std::array<uint8_t,0x844> bytes{};
    for(const auto &signature:signatures){
        if(!ReadBytes(module+signature.offset,bytes.data(),signature.size)){
            snapshot.detail="không đọc được mã game";snapshot.failedOffset=signature.offset;return false;
        }
        uint32_t hash=0x811C9DC5;
        for(size_t i=0;i<signature.size;++i)hash=(hash^bytes[i])*0x01000193u;
        if(hash!=signature.hash){snapshot.detail="mã game khác bản đã kiểm tra";snapshot.failedOffset=signature.offset;return false;}
    }
    return verified=true;
}
uint64_t Clock(){
    const void *clock=(const void *)&mach_absolute_time;Dl_info info{};
    if(!dladdr(clock,&info)||!info.dli_fname||!info.dli_fbase)return 0;
    const char *name=std::strrchr(info.dli_fname,'/');
    const uint64_t base=get_image_base_address(task,name?name+1:info.dli_fname);
    std::array<uint8_t,32> bytes{};
    const uint64_t address=base+((uintptr_t)clock-(uintptr_t)info.dli_fbase);
    return base&&Read(address,bytes)&&!std::memcmp(bytes.data(),clock,bytes.size())?address:0;
}
bool Supported(uint64_t original){return original==module+0x5660700||original==module+0x5A4BEC0;}
bool Writable(uint64_t address){
    mach_vm_address_t region=address;mach_vm_size_t size=0;natural_t depth=0;
    vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
    return address%8==0&&mach_vm_region_recurse(task,&region,&size,&depth,(vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS&&
        !info.is_submap&&region<=address&&address-region<=size&&size-(address-region)>=8&&(info.protection&VM_PROT_WRITE);
}
Session *Find(uint64_t slot){for(auto &session:sessions)if(session.slot==slot)return &session;return nullptr;}
bool Adopt(uint64_t slot,uint64_t address){
    if(!isVaildPtr(address)||address%MODES_PAGE||sessions.size()>=16)return false;
    std::array<uint8_t,MODES_PAGE> code{};PlayerModesRemote::State state{};
    if(!Read(address,code)||std::memcmp(code.data(),PlayerModesRemoteStart,code.size())||
        !Read(address+MODES_PAGE,state)||state.magic!=PlayerModesRemote::Magic||!Supported(state.original)||
        state.clock!=Clock()||state.currentMatch!=module+0x591B898||state.getPos!=module+0x6B49D04||
        state.setPos!=module+0x6B49E10||state.hp!=module+0x56AA7C8||state.vehicle!=module+0x561CA30||
        state.parachute!=module+0x561C7C8||state.waitSync!=module+0x5636F20)return false;
    sessions.push_back({slot,address,state.original,state.sequence&~1u,true});
    epoch=state.input.epoch+1;
    PlayerModesRemote::Input off{};off.epoch=epoch;
    return Publish(sessions.back(),off);
}
int Install(uint64_t klass){
    uint64_t current=0;const uint64_t slot=klass+Slot;
    if(!Read(slot,current)){snapshot.detail="không đọc được nhịp nhân vật";return 9;}
    Session *session=Find(slot);
    if(!session&&!Supported(current)){
        if(!Adopt(slot,current)){snapshot.detail="loại nhân vật chưa hỗ trợ";return 9;}
        session=Find(slot);
    }
    if(session&&current!=session->original&&current!=session->allocation){snapshot.detail="nhịp nhân vật đã bị thay đổi";return 9;}
    if(!session){
        if(sessions.size()>=16)return 9;
        const uint64_t clock=Clock();if(!clock){snapshot.detail="không tìm được đồng hồ game";return 9;}
        const auto mapping=SilentAimMapping::Map(task,PlayerModesRemoteStart,PlayerModesRemoteEnd);
        if(!mapping.address){snapshot.detail=mapping.operation;return 10;}
        PlayerModesRemote::State state{};
        state.original=current;state.clock=clock;state.currentMatch=module+0x591B898;
        state.getPos=module+0x6B49D04;state.setPos=module+0x6B49E10;state.hp=module+0x56AA7C8;
        state.vehicle=module+0x561CA30;state.parachute=module+0x561C7C8;state.waitSync=module+0x5636F20;
        if(!Write(mapping.address+MODES_PAGE,state)){snapshot.detail="không ghi được trạng thái";mach_vm_deallocate(task,mapping.address,2*MODES_PAGE);return 10;}
        sessions.push_back({slot,mapping.address,current,0,false});session=&sessions.back();
    }
    // Publish both entries to the SAME state, so interface and concrete calls
    // share their restore/anchor rows. Never patch a method's instructions.
    uint64_t concrete=0;
    bool bound=true;
    for(auto offset:PlayerModesInstall::Slots){
        if(!Read(klass+offset,concrete)||(concrete!=session->original&&concrete!=session->allocation)){
            snapshot.detail="nhịp interface không khớp";return 9;
        }
        bound=bound&&concrete==session->allocation;
    }
    if(bound)return 8;
    for(auto offset:PlayerModesInstall::Slots)
        if(!Writable(klass+offset)){snapshot.detail="vùng nhịp nhân vật chỉ đọc";return 10;}
    bool ok=false;
#ifdef MIZZE_INJECTED
    ok=PlayerModesInstall::Bind(klass,session->original,session->allocation,
        [](uint64_t address,uint64_t &value){return Read(address,value);},
        [](uint64_t address,uint64_t expected,uint64_t replacement){
            return __atomic_compare_exchange_n((uint64_t *)address,&expected,replacement,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
        });
#else
    if(task_suspend(task)!=KERN_SUCCESS){snapshot.detail="không đồng bộ được nhịp game";return 10;}
    ok=PlayerModesInstall::Bind(klass,session->original,session->allocation,
        [](uint64_t address,uint64_t &value){return Read(address,value);},
        [](uint64_t address,uint64_t expected,uint64_t replacement){
            uint64_t live=0;return Read(address,live)&&live==expected&&Write(address,replacement);
        });
    task_resume(task);
#endif
    if(!ok){snapshot.detail="không ghi được nhịp nhân vật";return 10;}
    return 8;
}
void Sample(){
    const double now=CACurrentMediaTime();
    if(now-lastSample<0.2)return;
    lastSample=now;
    PlayerModesSnapshot next{};next.detail=snapshot.detail;next.failedOffset=snapshot.failedOffset;
    next.scoped=previousFlags&1u;next.skipped=snapshot.skipped;
    for(const auto &session:sessions){
        PlayerModesRemote::State state{};
        if(!Read(session.state(),state))continue;
        next.ticks+=state.ticks;next.applies+=state.applies;next.restores+=state.restores;
        for(const auto &row:state.rows){
            if(row.match!=ownerMatch||row.local!=ownerLocal||row.epoch!=epoch||!row.player)continue;
            if(row.mode==2&&(previousFlags&2u))++next.burrow;
            if(row.mode==1&&(previousFlags&1u))++next.heldEnemies;
        }
    }
    if(next.ticks!=sampledTicks){sampledTicks=next.ticks;lastTickAt=now;}
    next.running=lastTickAt>0&&now-lastTickAt<1.0;
    if(!next.running)next.burrow=next.heldEnemies=0;
    snapshot=next;
}
uint64_t Deadline(){
    mach_timebase_info_data_t timebase{};
    return mach_timebase_info(&timebase)==KERN_SUCCESS&&timebase.numer&&timebase.denom?
        mach_absolute_time()+250000000ULL*timebase.denom/timebase.numer:0;
}
}
void PlayerModesSetEnabled(bool burrow,bool aimLag){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    const uint32_t next=(burrow?2u:0u)|(aimLag?1u:0u);
    if(next!=wanted){Clear();wanted=next;retryAt=0;}
}
void PlayerModesCancel(){std::lock_guard<std::recursive_mutex> guard(mutex);Clear();}
int PlayerModesUpdate(uint64_t base){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(!wanted)return lastResult=1;
    if(!isVaildPtr(base)||!Attach(base)){Clear();return lastResult=10;}
    const uint64_t match=getMatch(getMatchGame(base)),local=getLocalPlayer(match);
    uint8_t knocked=1;
    if(!isVaildPtr(match)||!isVaildPtr(local)||get_CurHP(local)<=0||!Read(local+kKnocked,knocked)||knocked){Clear();return lastResult=11;}
    if(CACurrentMediaTime()<retryAt)return lastResult;
    snapshot.detail="";snapshot.failedOffset=0;snapshot.skipped=0;
    if(!Verify()){Clear();retryAt=CACurrentMediaTime()+1;return lastResult=9;}
    PlayerModesRemote::Input input{};
    input.flags=(wanted&2u)|((wanted&1u)&&get_IsScoping(local)?1u:0u);
    input.match=match;input.local=local;input.deadline=Deadline();
    if(match!=ownerMatch||local!=ownerLocal||input.flags!=previousFlags)++epoch;
    ownerMatch=match;ownerLocal=local;previousFlags=input.flags;
    input.epoch=epoch;
    std::array<uint64_t,MODES_CAPACITY+1> classes{};size_t classCount=0;
    auto addClass=[&](uint64_t player){
        uint64_t klass=0;if(!Read(player,klass)||!isVaildPtr(klass))return false;
        for(size_t i=0;i<classCount;++i)if(classes[i]==klass)return true;
        if(classCount==classes.size())return false;
        classes[classCount++]=klass;return true;
    };
    if((wanted&2u)&&!addClass(local)){Clear();return lastResult=9;}
    if(wanted&1u){
        uint64_t dictionary=0,entries=0;int count=-1,capacity=-1;
        if(!Read(match+kMatchPlayerDict,dictionary)||!Read(dictionary+kDictCount,count)||
            !Read(dictionary+kDictEntries,entries)||!Read(entries+kIl2CppArrayMaxLength,capacity)||
            capacity<=0||capacity>256||count<0||count>capacity){Clear();return lastResult=11;}
        std::array<uint8_t,256*kDictEntryStrideBytePlayer> bytes{};
        if(count&&!ReadBytes(entries+kIl2CppArrayItems,bytes.data(),count*kDictEntryStrideBytePlayer)){Clear();return lastResult=11;}
        for(int i=0;i<count&&input.count<MODES_CAPACITY;++i){
            const uint8_t *entry=bytes.data()+i*kDictEntryStrideBytePlayer;
            int32_t hash=-1;uint64_t player=0;std::memcpy(&hash,entry,4);std::memcpy(&player,entry+16,8);
            uint8_t knock=1;
            if(hash<0||!isVaildPtr(player)||player==local||get_CurHP(player)<=0||
                !Read(player+kKnocked,knock)||knock||isLocalTeamMate(local,player))continue;
            if(!addClass(player)){Clear();return lastResult=9;}
            input.players[input.count++]=player;
        }
    }
    std::array<bool,MODES_CAPACITY+1> installed{};
    uint64_t localClass=0;if(wanted&2u)Read(local,localClass);
    for(size_t i=0;i<classCount;++i){
        int result=Install(classes[i]);
        if(result==8){installed[i]=true;continue;}
        // One unsupported enemy must not disable the local Burrow callback or
        // other supported enemies. Memory/permission failures still abort.
        if(result==9&&classes[i]!=localClass)continue;
        Clear();retryAt=CACurrentMediaTime()+1;return lastResult=result;
    }
    uint32_t accepted=0;
    for(uint32_t i=0;i<input.count;++i){
        uint64_t klass=0;Read(input.players[i],klass);bool supported=false;
        for(size_t j=0;j<classCount;++j)if(classes[j]==klass&&installed[j]){supported=true;break;}
        if(supported)input.players[accepted++]=input.players[i];else ++snapshot.skipped;
    }
    if(!(wanted&2u)&&input.count&&!accepted){Clear();retryAt=CACurrentMediaTime()+1;return lastResult=9;}
    input.count=accepted;
    if(!snapshot.skipped)snapshot.detail="";
    input.epoch=epoch; // Adoption may have advanced an existing callback's epoch.
    if(!input.deadline){Clear();return lastResult=10;}
    for(auto &session:sessions)if(!Publish(session,input)){Clear();return lastResult=10;}
    Sample();
    return lastResult=8;
}
PlayerModesSnapshot PlayerModesRead(){std::lock_guard<std::recursive_mutex> guard(mutex);return snapshot;}
#else
void PlayerModesSetEnabled(bool,bool){}
void PlayerModesCancel(){}
int PlayerModesUpdate(uint64_t){return 9;}
PlayerModesSnapshot PlayerModesRead(){return {};}
#endif
