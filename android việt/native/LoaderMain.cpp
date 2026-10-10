#include "Injector/KittyInjector.hpp"
#include <fstream>
#include <sstream>
#include <limits.h>
#include <cstdlib>

static uint64_t startTime(int pid) {
    std::ifstream in("/proc/"+std::to_string(pid)+"/stat");std::string line;std::getline(in,line);
    const auto end=line.rfind(')');if(end==std::string::npos)return 0;
    std::istringstream fields(line.substr(end+2));std::string value;
    for(int i=0;i<=19;++i)if(!(fields>>value))return 0;
    return std::strtoull(value.c_str(),nullptr,10);
}
int main(int argc,char** argv) {
    if(getuid()!=0||argc!=4)return 1;
    const int pid=std::atoi(argv[1]);const auto identity=std::strtoull(argv[2],nullptr,10);
    if(pid<=1||!identity||startTime(pid)!=identity||KittyMemoryEx::getProcessName(pid)!="com.dts.freefireth")return 2;
    char canonical[PATH_MAX]{};if(!realpath(argv[3],canonical))return 3;
    std::string library=canonical;
    if(library.size()<20||library.substr(library.size()-18)!="libmizze_silent.so")return 3;
    KittyMemoryMgr memory{};
    memory.trace=KittyTraceMgr(pid,0,true);
    // A failed helper must not kill the game. No EXITKILL, launch/watch, hiding,
    // memfd loading, SELinux modifications or automatic game restarts.
    if(!memory.trace.seize(PTRACE_O_TRACESYSGOOD))return 4;
    struct Detach {KittyMemoryMgr& memory;~Detach(){memory.trace.detach();}} detach{memory};
    if(!memory.trace.stop()||startTime(pid)!=identity)return 4;
    if(!memory.initialize(pid,EK_MEM_OP_SYSCALL,true))return 5;
    inject_elf_config_t config{};config.sdk=KittyUtils::Android::getSDK();config.timeout=2000;
    config.seize=true;config.package="com.dts.freefireth";config.selinux_state=Utils::selinux_state();
    KittyInjector injector;
    if(!injector.init(&memory,config))return 6;
    bool emulated=false;if(!injector.validateElf(library,nullptr,&emulated)||emulated)return 7;
    if(startTime(pid)!=identity)return 2;
    return injector.inject(library).is_valid()?0:8;
}
