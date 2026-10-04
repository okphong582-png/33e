#include "AutoFire.h"
#if defined(__aarch64__) || defined(__arm64__)
#include "AutoFireRemoteLayout.h"
#include "SilentAimRemoteMapping.h"
#include "SilentAimWeapon.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>
extern "C" const unsigned char AutoFireRemoteStart[], AutoFireRemoteEnd[];
namespace {
constexpr uint64_t Getter=0x5616118, Start=0x5C179E8, Stop=0x5C222EC;
constexpr uint64_t PlayerUpdate=0x5660700, NetworkUpdate=0x5A4BEC0;
constexpr uint64_t UpdateSlot=0x138+26*16, StartSlot=0x138+182*16, StopSlot=0x138+213*16;
std::recursive_mutex mutex;
mach_port_t task=MACH_PORT_NULL;
int pid=-1;
uint64_t module=0, allocation=0, installedSlot=0, dwellTarget=0, dwellLocal=0;
uint32_t sequence=0;
double dwellSince=0, retryAt=0;
int retryState=9;
bool ReadBytes(uint64_t a, void *v, size_t n) {
    mach_vm_size_t actual=0;
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_read_overwrite(task,a,n,(mach_vm_address_t)v,&actual)==KERN_SUCCESS && actual==n;
}
template<class T> bool Read(uint64_t a,T &v) { return ReadBytes(a,&v,sizeof(v)); }
bool WriteBytes(uint64_t a,const void *v,size_t n) {
    return task!=MACH_PORT_NULL && isVaildPtr(a) &&
        mach_vm_write(task,a,(pointer_t)v,(mach_msg_type_number_t)n)==KERN_SUCCESS;
}
template<class T> bool Write(uint64_t a,const T &v) { return WriteBytes(a,&v,sizeof(v)); }
uint64_t StateAddress() { return allocation+AUTO_PAGE; }
void Clear() {
    dwellTarget=dwellLocal=0; dwellSince=0;
    if (allocation) {
        const uint32_t odd=(sequence+1)|1u, off=0;
        sequence=odd+1;
        Write(StateAddress()+AUTO_SEQUENCE,odd);
        Write(StateAddress()+AUTO_ENABLED,off);
        Write(StateAddress()+AUTO_SEQUENCE,sequence);
    }
    // Keep the callback mapped/installed so its next game tick can release an
    // owned fire hold. Unhooking immediately could leave the weapon firing.
}
template<size_t N> bool Fingerprint(uint64_t a,uint32_t expected) {
    std::array<uint8_t,N> bytes{}; if(!Read(a,bytes))return false;
    uint32_t h=0x811C9DC5;for(uint8_t b:bytes)h=(h^b)*0x01000193u;
    return h==expected;
}
bool Writable(uint64_t a) {
    mach_vm_address_t r=a;mach_vm_size_t n=0;natural_t depth=0;
    vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
    return a%8==0 && mach_vm_region_recurse(task,&r,&n,&depth,(vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS &&
        !info.is_submap && r<=a && a-r<=n && n-(a-r)>=8 && (info.protection&VM_PROT_WRITE);
}
bool Attach(uint64_t base) {
#ifdef MIZZE_INJECTED
    const mach_port_t candidate=mach_task_self();
#else
    const mach_port_t candidate=get_task;
#endif
    int candidatePID=-1;
    if(candidate==MACH_PORT_NULL || pid_for_task(candidate,&candidatePID)!=KERN_SUCCESS){Clear();return false;}
    if(task==candidate && pid==candidatePID && module==base)return true;
    Clear();
    if(task!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),task);
    task=MACH_PORT_NULL;allocation=installedSlot=0;sequence=0;retryAt=0;
    if(mach_port_mod_refs(mach_task_self(),candidate,MACH_PORT_RIGHT_SEND,1)!=KERN_SUCCESS)return false;
    task=candidate;pid=candidatePID;module=base;return true;
}
uint64_t Clock() {
    Dl_info info{};const void *clock=(const void *)&mach_absolute_time;
    if(!dladdr(clock,&info)||!info.dli_fname||!info.dli_fbase)return 0;
    const char *name=std::strrchr(info.dli_fname,'/');
    const uint64_t base=get_image_base_address(task,name?name+1:info.dli_fname);
    if(!base)return 0;
    const uint64_t a=base+((uintptr_t)clock-(uintptr_t)info.dli_fbase);
    std::array<uint8_t,32> bytes{};
    return Read(a,bytes)&&!std::memcmp(bytes.data(),clock,bytes.size())?a:0;
}
bool Adopt(uint64_t a,uint64_t original) {
    if(!isVaildPtr(a)||a%AUTO_PAGE)return false;
    std::array<uint8_t,AUTO_PAGE> code{};AutoFireRemote::State state{};
    if(!Read(a,code)||std::memcmp(code.data(),AutoFireRemoteStart,code.size())||
        !Read(a+AUTO_PAGE,state)||state.magic!=AutoFireRemote::Magic||state.original!=original||
        state.getter!=module+Getter||state.start!=module+Start||state.stop!=module+Stop||state.clock!=Clock())return false;
    allocation=a;sequence=state.sequence&~1u;Clear();return true;
}
int Install(uint64_t slot,uint64_t original) {
    if(installedSlot && installedSlot!=slot)return 9;
    uint64_t current=0;if(!Read(slot,current))return 9;
    if(installedSlot && current==allocation)return 8;
    if(current!=original){if(!allocation&&Adopt(current,original)){installedSlot=slot;return 8;}return 9;}
    if(!allocation){
        const uint64_t clock=Clock();if(!clock)return 9;
        const auto mapping=SilentAimMapping::Map(task,AutoFireRemoteStart,AutoFireRemoteEnd);
        if(!mapping.address)return 10;
        AutoFireRemote::State state;state.original=original;state.clock=clock;
        state.getter=module+Getter;state.start=module+Start;state.stop=module+Stop;
        if(!Write(mapping.address+AUTO_PAGE,state)){mach_vm_deallocate(task,mapping.address,2*AUTO_PAGE);return 10;}
        allocation=mapping.address;
    }
    if(!Writable(slot))return 10;
#ifdef MIZZE_INJECTED
    uint64_t expected=original;
    if(!__atomic_compare_exchange_n((uint64_t *)slot,&expected,allocation,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 9;
#else
    if(task_suspend(task)!=KERN_SUCCESS)return 10;
    const bool ok=Read(slot,current)&&current==original&&Write(slot,allocation);
    task_resume(task);if(!ok)return 10;
#endif
    installedSlot=slot;return 8;
}
}
void AutoFireClear(){std::lock_guard<std::recursive_mutex> guard(mutex);Clear();}
uint64_t AutoFireStartCount(){std::lock_guard<std::recursive_mutex> guard(mutex);uint64_t n=0;if(allocation)Read(StateAddress()+AUTO_STARTS,n);return n;}
int AutoFireUpdate(uint64_t base,uint64_t match,uint64_t local,uint64_t target){
    std::lock_guard<std::recursive_mutex> guard(mutex);
    if(!target){Clear();return 7;}
    if(!Attach(base)){Clear();return 10;}
    uint8_t localKnock=1, targetKnock=1;
    if(getMatch(getMatchGame(base))!=match||getLocalPlayer(match)!=local||
        get_CurHP(local)<=0||get_CurHP(target)<=0||
        !Read(local+kKnocked,localKnock)||localKnock||!Read(target+kKnocked,targetKnock)||targetKnock||
        isLocalTeamMate(local,target)||!getAimVisibility(target)){Clear();return 7;}
    const double now=CACurrentMediaTime();
    if(now<retryAt)return retryState;
    if(target!=dwellTarget || local!=dwellLocal){Clear();dwellTarget=target;dwellLocal=local;dwellSince=now;}
    if(now-dwellSince<0.18)return 7;
    uint64_t klass=0,update=0,weaponClass=0,start=0,stop=0;
    const uint64_t weapon=SilentAimWeapon::OnHand(local,[](uint64_t a,auto &v){return Read(a,v);},[](uint64_t a){return isVaildPtr(a);});
    if(!Read(local,klass)||!Read(klass+UpdateSlot,update)||!weapon||!Read(weapon,weaponClass)||
        !Read(weaponClass+StartSlot,start)||start!=base+Start||!Read(weaponClass+StopSlot,stop)||stop!=base+Stop||
        !Fingerprint<0xCC>(base+Getter,0xC5E012EE)||!Fingerprint<0x5A8>(base+Start,0x9AD8096C)||
        !Fingerprint<0x1E4>(base+Stop,0xA2F105A1)){
        Clear();retryAt=now+1;retryState=9;return 9;
    }
    uint64_t original=update;
    if(installedSlot && update==allocation){AutoFireRemote::State state{};if(!Read(StateAddress(),state)){Clear();return 9;}original=state.original;}
    else if(update!=base+PlayerUpdate && update!=base+NetworkUpdate){
        AutoFireRemote::State state{};
        if(!Read(update+AUTO_PAGE,state)){Clear();return 9;}original=state.original;
    }
    if(!((original==base+PlayerUpdate&&Fingerprint<0x100>(original,0xC902032E))||
         (original==base+NetworkUpdate&&Fingerprint<0x100>(original,0x4B4A9AE9)))){Clear();return 9;}
    const int result=Install(klass+UpdateSlot,original);
    if(result!=8){Clear();retryAt=now+1;retryState=result;return result;}
    mach_timebase_info_data_t tb{};
    if(mach_timebase_info(&tb)!=KERN_SUCCESS||!tb.numer||!tb.denom){Clear();return 9;}
    struct Publication {uint32_t enabled;uint64_t deadline,local,match,weapon;} __attribute__((packed));
    const Publication p{1,mach_absolute_time()+100000000ULL*tb.denom/tb.numer,local,match,weapon};
    const uint32_t odd=(sequence+1)|1u;sequence=odd+1;
    const bool ok=Write(StateAddress()+AUTO_SEQUENCE,odd)&&
        WriteBytes(StateAddress()+AUTO_ENABLED,&p,sizeof(p))&&Write(StateAddress()+AUTO_SEQUENCE,sequence);
    if(!ok){Clear();return 10;}return 8;
}
#else
void AutoFireClear(){}
uint64_t AutoFireStartCount(){return 0;}
int AutoFireUpdate(uint64_t,uint64_t,uint64_t,uint64_t){return 9;}
#endif
