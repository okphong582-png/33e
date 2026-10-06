#include "../esp/Core/GameLogic.h"
#include "../esp/Core/GamePRI.h"
#include <mach-o/dyld.h>
#include <cstring>

mach_port_t get_task=MACH_PORT_NULL;
static uint64_t verifiedModule=0;
bool _read(long address,void *buffer,int length) {
    if(!isVaildPtr(address)||length<=0)return false;
    mach_vm_size_t actual=0;
    return mach_vm_read_overwrite(mach_task_self(),address,length,(mach_vm_address_t)buffer,&actual)==KERN_SUCCESS&&actual==(unsigned)length;
}
bool _write(long address,const void *buffer,int length) {
    return isVaildPtr(address)&&length>0&&mach_vm_write(mach_task_self(),address,(pointer_t)buffer,length)==KERN_SUCCESS;
}
mach_vm_address_t get_image_base_address(mach_port_t task,const char *name) {
    if(task!=mach_task_self()||!name)return 0;
    for(uint32_t i=0;i<_dyld_image_count();++i){
        const char *image=_dyld_get_image_name(i);if(!image)continue;
        const char *file=std::strrchr(image,'/');file=file?file+1:image;
        if(!std::strcmp(file,name))return (mach_vm_address_t)_dyld_get_image_header(i);
    }
    return 0;
}
uint64_t AimlagModule() {return get_image_base_address(mach_task_self(),"UnityFramework");}
uint64_t getMatchGame(uint64_t base) {
    if(!isVaildPtr(base))return 0;
    // CurrentMatch is a verified static facade getter, without scene APIs.
    if(verifiedModule!=base){
        uint8_t bytes[0x1C8]{};uint32_t hash=0x811C9DC5;
        if(!_read(base+0x591B898,bytes,sizeof(bytes)))return 0;
        for(uint8_t byte:bytes)hash=(hash^byte)*0x01000193u;
        if(hash!=0x92F2568B)return 0;
        verifiedModule=base;
    }
    return ((uint64_t(*)(void *))(base+0x591B898))(nullptr);
}
uint64_t getMatch(uint64_t match) {return match;}
uint64_t getLocalPlayer(uint64_t match) {return isVaildPtr(match)?ReadAddr<uint64_t>(match+0xD8):0;}
int GetDataUInt16(uint64_t player,int index) {
    uint16_t value=0;
    return GamePRI::TryUInt16(player,index,[](uint64_t a,void *p,size_t n){return _read(a,p,(int)n);},
        [](uint64_t a){return isVaildPtr(a);},value)?value:0;
}
int get_CurHP(uint64_t player) {return GetDataUInt16(player,0);}
bool get_IsScoping(uint64_t player) {return GetDataUInt16(player,12)!=0;}
bool isLocalTeamMate(uint64_t local,uint64_t player) {
    COW_GamePlay_PlayerID_o first{},second{};
    return _read(local+0x408,&first,sizeof(first))&&_read(player+0x408,&second,sizeof(second))&&first.m_TeamID==second.m_TeamID;
}
