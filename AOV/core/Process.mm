#include "Process.h"
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/loader.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <unistd.h>
#include <string>
namespace aov {
static double now(){timeval t{};gettimeofday(&t,nullptr);return t.tv_sec+t.tv_usec*1e-6;}
void Process::reset(){camera.forget();if(owned&&task)mach_port_deallocate(mach_task_self(),task); task=0;owned=false;image=0;pid=0;}
bool Process::copy(uint64_t address,void *out,size_t size){
    if(!task||!address||size==0||size>65536||address>0x00007fffffffffffULL-size)return false;
    static_assert(sizeof(vm_address_t)==8,"AOV supports ARM64 address spaces");
    vm_size_t got=0;
    return vm_read_overwrite(task,static_cast<vm_address_t>(address),size,reinterpret_cast<vm_address_t>(out),&got)==KERN_SUCCESS&&got==size;
}
bool Process::store(uint64_t address,const void *value,size_t size){
    if(!task||!value||address<0x10000||size==0||size>16||address>0x00007fffffffffffULL-size)return false;
    return vm_write(task,static_cast<vm_address_t>(address),reinterpret_cast<vm_offset_t>(value),static_cast<mach_msg_type_number_t>(size))==KERN_SUCCESS;
}
void Process::restoreCamera(){if(image&&camera.applied())camera.update(*this,image,1.f);}
bool Process::accepts(uint64_t header){
    mach_header_64 h{};if(!read(header,h)||h.magic!=MH_MAGIC_64||h.cputype!=CPU_TYPE_ARM64||h.ncmds>512||h.sizeofcmds>65536)return false;
    std::vector<uint8_t> commands(h.sizeofcmds);if(!copy(header+sizeof(h),commands.data(),commands.size()))return false;
    size_t p=0;
    for(uint32_t n=0;n<h.ncmds;n++){
        if(p+sizeof(load_command)>commands.size())return false;
        load_command c{};std::memcpy(&c,commands.data()+p,sizeof(c));
        if(c.cmdsize<sizeof(c)||p+c.cmdsize>commands.size())return false;
        if(c.cmd==LC_UUID&&c.cmdsize>=sizeof(uuid_command))return !std::memcmp(commands.data()+p+8,uuid.data(),16);
        p+=c.cmdsize;
    }return false;
}
bool Process::findImage(){
#if AOV_INJECTED
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const char *name=_dyld_get_image_name(i);
        if(name&&std::string(name).find("/UnityFramework.framework/UnityFramework")!=std::string::npos){
            uint64_t header=reinterpret_cast<uint64_t>(_dyld_get_image_header(i));
            if(accepts(header)){image=header;return true;}connection=State::unsupported;return false;
        }
    }
#else
    task_dyld_info_data_t dyld{};mach_msg_type_number_t count=TASK_DYLD_INFO_COUNT;
    if(task_info(task,TASK_DYLD_INFO,reinterpret_cast<task_info_t>(&dyld),&count)!=KERN_SUCCESS)return false;
    struct Infos {uint32_t version,count;uint64_t array;};Infos infos{};
    if(!read(dyld.all_image_info_addr,infos)||infos.count>4096||!infos.array)return false;
    for(uint32_t i=0;i<infos.count;i++){
        struct Image {uint64_t header,path,date;};Image entry{};
        if(!read(infos.array+i*sizeof(entry),entry))return false;
        char path[1024]{};
        // Read page-safe chunks; paths near a page boundary need not have 1024 mapped bytes.
        bool ended=false;size_t p=0;
        while(p<sizeof(path)-1){size_t n=std::min<size_t>(64,4096-((entry.path+p)&4095));if(!copy(entry.path+p,path+p,n))break;if(std::memchr(path+p,0,n)){ended=true;break;}p+=n;}
        if(ended&&std::string(path).find("/UnityFramework.framework/UnityFramework")!=std::string::npos){
            if(accepts(entry.header)){image=entry.header;return true;}connection=State::unsupported;return false;
        }
    }
#endif
    return false;
}
Snapshot Process::update(bool enemies,bool showMonsters,float zoom){
    Snapshot result;
    zoom=zoomMultiplier(zoom);
    if(!enemies&&!showMonsters&&zoom==1.f&&!camera.applied())return result;
    if(task){uint32_t magic=0;if(image&&!read(image,magic))reset();}
    if(!image&&now()-lastConnect>1){
        lastConnect=now();reset();connection=State::disconnected;
#if AOV_INJECTED
        task=mach_task_self();pid=getpid();
#else
        int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0};size_t bytes=0;
        if(sysctl(mib,4,nullptr,&bytes,nullptr,0)==0&&bytes<=sizeof(kinfo_proc)*8192){
            std::vector<kinfo_proc> entries(bytes/sizeof(kinfo_proc)+32);bytes=entries.size()*sizeof(kinfo_proc);
            if(sysctl(mib,4,entries.data(),&bytes,nullptr,0)==0)for(size_t i=0;i<bytes/sizeof(kinfo_proc);i++)if(!strcmp(entries[i].kp_proc.p_comm,"kgvn")){pid=entries[i].kp_proc.p_pid;break;}
        }
        if(pid){if(task_for_pid(mach_task_self(),pid,&task)==KERN_SUCCESS)owned=true;else{task=0;connection=State::denied;}}
#endif
        if(task)findImage();
    }
    if(!image){result.state=connection;result.zoom=zoom>1.f?ZoomState::waiting:ZoomState::off;return result;}
    auto zoomState=camera.update(*this,image,zoom);
    if(enemies||showMonsters)result=Reader(*this).sample(image,enemies,showMonsters);
    result.zoom=zoomState;return result;
}
}
