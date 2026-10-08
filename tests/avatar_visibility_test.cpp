#include "../esp/Core/AvatarVisibility.h"
#include <cassert>
#include <vector>
#include <cstring>
int main() {
    constexpr uint64_t base=0x100000,player=base+0x100,manager=base+0x3000;
    constexpr uint64_t avatar=base+0x4000,klass=base+0x5000,name=base+0x6000,ns=base+0x6100;
    std::vector<uint8_t> memory(0x8000);
    const auto valid=[&](uint64_t a){return a>=base&&a<base+memory.size();};
    const auto read=[&](uint64_t a,void *v,size_t n){
        if(!valid(a)||n>memory.size()-(a-base))return false;
        std::memcpy(v,memory.data()+a-base,n);return true;
    };
    const auto put=[&](uint64_t a,auto v){std::memcpy(memory.data()+a-base,&v,sizeof(v));};
    put(player+MIZZE_PLAYER_770,manager);put(manager+0x138,avatar);put(avatar,klass);
    put(klass+0x10,name);put(klass+0x18,ns);
    std::memcpy(memory.data()+name-base,"UmaAvatarSimple",sizeof("UmaAvatarSimple"));
    std::memcpy(memory.data()+ns-base,"UMA.Simple",sizeof("UMA.Simple"));
    const auto visible=[&]{return AvatarVisibility::IsVisible(player,read,valid);};
    put(avatar+0x101,uint8_t(1));assert(visible());
    put(avatar+0x101,uint8_t(0));assert(!visible());
    put(avatar+0x101,uint8_t(2));assert(!visible());
    // A legacy LevelSwingSpider reference must not override avatar visibility.
    put(player+MIZZE_PLAYER_A50,base+0x7000);put(base+0x7010,uint32_t(1));assert(!visible());
    put(avatar+0x101,uint8_t(1));memory[name-base]='X';assert(!visible());
    memory[name-base]='U';memory[ns-base]='X';assert(!visible());
    memory[ns-base]='U';assert(visible());put(manager+0x138,uint64_t(0));assert(!visible());
    put(manager+0x138,avatar);put(avatar,uint64_t(base+memory.size()-8));assert(!visible());
}
