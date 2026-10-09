#pragma once
#include <array>
#include <cstdint>
#include <cstring>
#include <cstddef>
namespace fcm {
inline constexpr std::array<uint8_t,16> uuid={0xd4,0x6e,0xb4,0x7f,0xf9,0xe8,0x30,0x33,0x95,0x0b,0x05,0x13,0xab,0x05,0xf6,0xc0};
enum class State {off,disconnected,unsupported,denied,waiting,ready};
class Memory {
public:
    virtual ~Memory()=default;
    virtual bool copy(uint64_t,void *,size_t)=0;
    virtual bool store(uint64_t,const void *,size_t)=0;
    template<class T> bool read(uint64_t a,T &v){return copy(a,&v,sizeof(v));}
};
// GcShotErrorUser, proven by named getter/setter and pre-match consumer.
// This changes the game's setting. It does not promise a goal or defeat a keeper.
class ShotSettings {
    uint64_t object_=0;
    uint8_t original_=0;
    bool applied_=false;
    static bool pointer(uint64_t p){return p>=0x10000&&p<0x0000800000000000ULL&&(p&7)==0;}
public:
    bool applied()const{return applied_;}
    void forget(){object_=0;applied_=false;}
    State update(Memory &m,uint64_t image,bool enabled){
        uint64_t manager=0,settings=0;
        if(!m.read(image+0xa25d478,manager)||!pointer(manager)||!m.read(manager+0x48,settings)||!pointer(settings)){
            // The game may be between screens; retain the pending restoration.
            return enabled||applied_?State::waiting:State::off;
        }
        if(object_&&object_!=settings)forget(); // Never restore into a freed/replaced object.
        std::array<uint8_t,2> field{};
        if(!m.read(settings+0x1ce,field))return State::waiting;
        if(field[0]>100||field[1]>1)return State::unsupported;
        if(!enabled){
            if(!applied_)return State::off;
            // Respect another owner changing the setting after our last write.
            if(field[0]!=0){forget();return State::off;}
            const std::array<uint8_t,2> restore={original_,1};
            if(!m.store(settings+0x1ce,restore.data(),restore.size())||!m.read(settings+0x1ce,field)||field!=restore)return State::denied;
            forget();return State::off;
        }
        if(!applied_){object_=settings;original_=field[0];}
        else if(field[0]!=0)original_=field[0];
        const std::array<uint8_t,2> desired={0,1};
        if(field[0]!=0){
            if(!m.store(settings+0x1ce,desired.data(),desired.size()))return State::denied;
            applied_=true; // Retain original even if verification subsequently fails.
        }else applied_=true;
        if(!m.read(settings+0x1ce,field)||field[0]!=0)return State::denied;
        return State::ready;
    }
};
}
