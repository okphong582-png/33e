#pragma once
#include "ShotSettings.h"
namespace fcm {
// Experimental native OpenGoalShootingLogic toggle, not a ball-physics redirect.
class OpenGoal {
    uint64_t object_=0;
    uint8_t original_=0;
    bool applied_=false;
    static bool pointer(uint64_t p){return p>=0x10000&&p<0x0000800000000000ULL&&(p&7)==0;}
    static bool resolve(Memory &m,uint64_t image,uint64_t &object){
        uint64_t registry=0,table=0,wrapper=0;
        return m.read(image+0xa263b60,registry)&&pointer(registry)&&m.read(registry+8,table)&&pointer(table)&&
            m.read(table+123*32+0x20,wrapper)&&pointer(wrapper)&&m.read(wrapper+8,object)&&pointer(object);
    }
public:
    bool applied()const{return applied_;}
    void forget(){object_=0;applied_=false;}
    State update(Memory &m,uint64_t image,bool enabled){
        if(!enabled&&!applied_)return State::off;
        uint64_t object=0;
        if(!resolve(m,image,object))return State::waiting;
        if(object_&&object_!=object)forget();
        uint8_t value=0;
        if(!m.read(object,value))return State::waiting;
        if(value>1)return State::unsupported;
        uint64_t checked=0;
        if(!resolve(m,image,checked)||checked!=object)return State::waiting;
        if(!enabled){
            if(!applied_)return State::off;
            if(value!=1){forget();return State::off;}
            if(!m.store(object,&original_,1))return State::denied;
            if(!m.read(object,value)||value!=original_)return State::denied;
            forget();return State::off;
        }
        if(value==1)return State::ready; // Already enabled by the game: take no write ownership.
        object_=object;original_=value;
        const uint8_t desired=1;
        if(!m.store(object,&desired,1))return State::denied;
        applied_=true; // Preserve restoration even if the verification read fails.
        if(!m.read(object,value)||value!=desired)return State::denied;
        return State::ready;
    }
};
}
