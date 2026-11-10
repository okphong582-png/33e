#include "HHSilentAim.h"
#include "SilentAimRemoteLayout.h"
#include "SilentAimRemoteMapping.h"
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <ptrauth.h>
#include <array>
#include <cmath>
#include <cstring>

extern "C" {
kern_return_t mach_vm_read_overwrite(vm_map_t,mach_vm_address_t,mach_vm_size_t,
                                      mach_vm_address_t,mach_vm_size_t *);
kern_return_t mach_vm_write(vm_map_t,mach_vm_address_t,pointer_t,mach_msg_type_number_t);
}

extern "C" const unsigned char SilentAimRemoteStart[], SilentAimRemoteEnd[];

namespace {
constexpr uint64_t WeaponGetter=0x5616118,ManagerGetter=0x5AC970C;
constexpr uint64_t HandlerMethod=0x5C59B94,HandlerSlot=0x138+17*16;
mach_port_t task=MACH_PORT_NULL;
pid_t attachedPID=0;
uint64_t image=0,allocation=0,installedSlot=0;
uint32_t sequence=0;
bool verified=false;
const char *failure="";

bool valid(uint64_t p){return p>0x10000&&p<0x80000000000ULL;}
bool readBytes(uint64_t address,void *out,size_t size){
 mach_vm_size_t actual=0;
 return task!=MACH_PORT_NULL&&valid(address)&&out&&size&&
  mach_vm_read_overwrite(task,address,size,(mach_vm_address_t)out,&actual)==KERN_SUCCESS&&actual==size;
}
bool writeBytes(uint64_t address,const void *data,size_t size){
 return task!=MACH_PORT_NULL&&valid(address)&&data&&size&&
  mach_vm_write(task,address,(pointer_t)data,(mach_msg_type_number_t)size)==KERN_SUCCESS;
}
template<class T>bool read(uint64_t address,T &out){return readBytes(address,&out,sizeof(out));}
template<class T>bool write(uint64_t address,const T &value){return writeBytes(address,&value,sizeof(value));}
bool pointer(uint64_t address,uint64_t &out){return read(address,out)&&valid(out)&&(out&7)==0;}
uint64_t stateAddress(){return allocation+SILENT_REMOTE_PAGE;}
bool publish(const SilentAimRemote::State &state){
 if(!allocation)return false;
 const uint32_t odd=(sequence+1)|1u;
 if(!write(stateAddress()+SILENT_REMOTE_SEQUENCE,odd))return false;
 sequence=odd+1;
 constexpr size_t start=SILENT_REMOTE_ENABLED,end=SILENT_REMOTE_REDIRECTS;
 if(!writeBytes(stateAddress()+start,(const uint8_t *)&state+start,end-start)||
    !writeBytes(stateAddress()+SILENT_REMOTE_MATCH,(const uint8_t *)&state+SILENT_REMOTE_MATCH,
       SILENT_REMOTE_HEAD_PERCENT+sizeof(uint32_t)-SILENT_REMOTE_MATCH))return false;
 return write(stateAddress()+SILENT_REMOTE_SEQUENCE,sequence);
}
void clear(){
 if(!allocation)return;
 SilentAimRemote::State state{};
 if(!read(stateAddress(),state))return;
 state.enabled=0;state.deadline=0;state.local=state.handler=state.infoClass=state.match=0;
 state.head={};state.body={};publish(state);
}
bool writable(uint64_t address){
 mach_vm_address_t region=address;mach_vm_size_t size=0;natural_t depth=0;
 vm_region_submap_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_SUBMAP_INFO_COUNT_64;
 return valid(address)&&(address&7)==0&&mach_vm_region_recurse(task,&region,&size,&depth,
  (vm_region_recurse_info_t)&info,&count)==KERN_SUCCESS&&region<=address&&
  address-region<=size&&size-(address-region)>=8&&!info.is_submap&&
  (info.protection&VM_PROT_WRITE);
}
void uninstall(){
 clear();
 if(!installedSlot||task==MACH_PORT_NULL)return;
 if(task_suspend(task)!=KERN_SUCCESS)return;
 uint64_t current=0;
 if(read(installedSlot,current)){
  if(current!=allocation||(writable(installedSlot)&&write(installedSlot,image+HandlerMethod)))installedSlot=0;
 }
 task_resume(task);
 // Leave the RX page mapped: a shot thread may still hold its address.
}
void detach(){
 if(task!=MACH_PORT_NULL){uninstall();mach_port_deallocate(mach_task_self(),task);}
 task=MACH_PORT_NULL;attachedPID=0;image=allocation=installedSlot=0;sequence=0;verified=false;
}
bool attach(pid_t pid,uint64_t base){
 if(task!=MACH_PORT_NULL&&attachedPID==pid&&image==base)return true;
 detach();
 mach_port_t candidate=MACH_PORT_NULL;
 if(pid<=0||task_for_pid(mach_task_self(),pid,&candidate)!=KERN_SUCCESS||candidate==MACH_PORT_NULL){failure="task_for_pid denied";return false;}
 int actual=0;
 if(pid_for_task(candidate,&actual)!=KERN_SUCCESS||actual!=pid){mach_port_deallocate(mach_task_self(),candidate);failure="task PID mismatch";return false;}
 task=candidate;attachedPID=pid;image=base;return true;
}
template<size_t N>bool fingerprint(uint64_t address,uint32_t expected){
 std::array<uint8_t,N> bytes{};if(!read(address,bytes))return false;
 uint32_t hash=0x811C9DC5;
 for(uint8_t b:bytes)hash=(hash^b)*0x01000193u;
 return hash==expected;
}
bool className(uint64_t object,const char *expected){
 uint64_t klass=0,name=0;char actual[32]{};size_t size=strlen(expected)+1;
 return size<=sizeof(actual)&&pointer(object,klass)&&read(klass+0x10,name)&&valid(name)&&
  readBytes(name,actual,size)&&memcmp(actual,expected,size)==0;
}
uint64_t remoteClock(){
 uint64_t address=(uint64_t)ptrauth_strip((void *)&mach_absolute_time,ptrauth_key_function_pointer);
 std::array<uint8_t,32> remote{};
 return read(address,remote)&&memcmp(remote.data(),(const void *)address,remote.size())==0?address:0;
}
bool adopt(uint64_t address){
 if(!valid(address)||address%SILENT_REMOTE_PAGE)return false;
 std::array<uint8_t,SILENT_REMOTE_PAGE> code{};SilentAimRemote::State state{};
 if(!read(address,code)||memcmp(code.data(),SilentAimRemoteStart,code.size())||
    !read(address+SILENT_REMOTE_PAGE,state)||state.magic!=SilentAimRemote::Magic||
    state.original!=image+HandlerMethod||state.clock!=remoteClock())return false;
 allocation=address;sequence=state.sequence&~1u;clear();return true;
}
bool allocate(){
 uint64_t clock=remoteClock();if(!clock){failure="remote clock mismatch";return false;}
 auto mapping=SilentAimMapping::Map(task,SilentAimRemoteStart,SilentAimRemoteEnd);
 if(!mapping.address){failure=mapping.operation;return false;}
 SilentAimRemote::State state{};state.original=image+HandlerMethod;state.clock=clock;
 std::array<uint8_t,SILENT_REMOTE_PAGE> code{};
 if(!read(mapping.address,code)||memcmp(code.data(),SilentAimRemoteStart,code.size())||
    !write(mapping.address+SILENT_REMOTE_PAGE,state)){
  mach_vm_deallocate(task,mapping.address,2*SILENT_REMOTE_PAGE);
  failure="remote code verification failed";return false;
 }
 allocation=mapping.address;return true;
}
bool install(uint64_t slot){
 if(installedSlot&&installedSlot!=slot)uninstall();
 if(installedSlot&&installedSlot!=slot){failure="old slot still installed";return false;}
 uint64_t current=0;if(!read(slot,current)){failure="shot slot unreadable";return false;}
 if(installedSlot&&current==allocation)return true;
 installedSlot=0;
 if(current!=image+HandlerMethod){
  if(!allocation&&adopt(current)){installedSlot=slot;return true;}
  failure="shot slot differs from native handler";return false;
 }
 if(!allocation&&!allocate())return false;
 if(task_suspend(task)!=KERN_SUCCESS){failure="cannot suspend game";return false;}
 bool okay=writable(slot)&&read(slot,current)&&current==image+HandlerMethod&&write(slot,allocation);
 task_resume(task);
 if(!okay){failure="cannot install shot hook";return false;}
 installedSlot=slot;return true;
}
bool hp(uint64_t player,uint16_t &health){
 uint64_t pool=0,entries=0,entry=0;
 return pointer(player+0x70,pool)&&pointer(pool+0x10,entries)&&
  pointer(entries+0x20,entry)&&read(entry+0x18,health);
}
bool eligible(uint64_t match,uint64_t local,uint64_t target){
 uint64_t type=0,statics=0,game=0,currentMatch=0,currentLocal=0;
 uint8_t localTeam=0,targetTeam=0,localKnock=1,targetKnock=1,visible=0;
 uint16_t localHP=0,targetHP=0;
 uint64_t manager=0,avatar=0,klass=0,name=0,ns=0;
 char classText[16]{},namespaceText[16]{};
 return pointer(image+0xbb46a50,type)&&pointer(type+0xb8,statics)&&
  (pointer(statics+8,game)||pointer(statics,game))&&pointer(game+0x90,currentMatch)&&
  currentMatch==match&&pointer(match+0xd8,currentLocal)&&currentLocal==local&&
  read(local+0x410,localTeam)&&read(target+0x410,targetTeam)&&localTeam!=targetTeam&&
  hp(local,localHP)&&localHP>0&&hp(target,targetHP)&&targetHP>0&&
  read(local+0x1258,localKnock)&&localKnock==0&&read(target+0x1258,targetKnock)&&targetKnock==0&&
  pointer(target+0x770,manager)&&pointer(manager+0x138,avatar)&&pointer(avatar,klass)&&
  read(klass+0x10,name)&&valid(name)&&read(klass+0x18,ns)&&valid(ns)&&
  readBytes(name,classText,16)&&readBytes(ns,namespaceText,11)&&
  strcmp(classText,"UmaAvatarSimple")==0&&strcmp(namespaceText,"UMA.Simple")==0&&
  read(avatar+0x101,visible)&&visible==1;
}
} // namespace

extern "C" void hh_silent_clear(void){clear();}
extern "C" void hh_silent_stop(void){detach();failure="";}
extern "C" const char *hh_silent_failure(void){return failure;}
extern "C" int hh_silent_update(pid_t pid,uint64_t base,uint64_t match,uint64_t local,
 uint64_t target,const float head[3],const float hip[3]){
 failure="";
 if(!valid(base)||!valid(match)||!valid(local)){clear();failure="invalid match identity";return 9;}
 if(!attach(pid,base))return 10;
 if(!verified){
  if(!fingerprint<0xCC>(base+WeaponGetter,0xC5E012EE)||
     !fingerprint<0xA0>(base+ManagerGetter,0x93FD3984)||
     !fingerprint<0x16C>(base+HandlerMethod,0xDFE8FAC6)){
   uninstall();failure="native fingerprint mismatch";return 9;
  }
  verified=true;
 }
 uint64_t manager=0,owner=0,weapon=0,handler=0,klass=0,info=0,infoClass=0;
 uint8_t combined=0;
 if(!pointer(local+0x740,manager)||!read(manager+0x30,owner)||owner!=local||
    !read(manager+0x148,combined)||combined>1||
    !pointer(manager+(combined?0xa8:0xa0),weapon)||!read(weapon+0x60,owner)||owner!=local||
    !pointer(weapon+0x80,handler)||!className(handler,"MDPBNKPCGNG")||
    !pointer(handler,klass)||!read(handler+0x28,info)||
    (info&&(!className(info,"CGKJLKPMGDJ")||!pointer(info,infoClass)))){
  uninstall();failure="weapon handler not verified";return 9;
 }
 if(!install(klass+HandlerSlot)){clear();return 10;}
 if(!target||!head||!hip||!eligible(match,local,target)){clear();return 7;}
 SilentAimDirection::Point h{head[0],head[1],head[2]},b{hip[0],hip[1],hip[2]};
 if(!SilentAimDirection::Finite(h)||!SilentAimDirection::Finite(b)){
  clear();failure="target position invalid";return 7;
 }
 b={b.x+(h.x-b.x)*0.4f,b.y+(h.y-b.y)*0.4f,b.z+(h.z-b.z)*0.4f};
 mach_timebase_info_data_t timebase{};
 if(mach_timebase_info(&timebase)!=KERN_SUCCESS||!timebase.numer||!timebase.denom){clear();failure="clock scale unavailable";return 10;}
 SilentAimRemote::State state{};state.enabled=1;state.local=local;state.handler=handler;
 state.infoClass=infoClass;state.head=h;state.match=match;state.body=b;state.headPercent=75;
 state.deadline=mach_absolute_time()+150000000ULL*timebase.denom/timebase.numer;
 if(!publish(state)){clear();failure="cannot publish target";return 10;}
 return 8;
}
