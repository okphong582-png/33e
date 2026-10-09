#pragma once
#include "ShotSettings.h"
#include "ComponentRoot.h"
namespace fcm {
// Experimental native OpenGoalShootingLogic toggle, not a ball-physics redirect.
class OpenGoal {
    uint64_t object_=0;
    uint8_t original_=0;
    int32_t mode_=0;
    bool applied_=false;
    static bool resolve(Memory &m,uint64_t image,uint64_t &object){
        ComponentRoot root;
        if(!resolveComponent(m,image,123,root)||!root.unchanged(m))return false;
        object=root.object;return true;
    }
public:
    bool applied()const{return applied_;}
    void forget(){object_=0;applied_=false;}
    State update(Memory &m,uint64_t image,bool enabled){
        if(!enabled&&!applied_)return State::off;
        uint64_t object=0;
        if(!resolve(m,image,object))return State::waiting;
        int32_t mode=0;
        if(!m.read(object+0xc4,mode))return State::waiting;
        if(object_&&(object_!=object||mode_!=mode))forget();
        uint8_t value=0;
        if(!m.read(object,value))return State::waiting;
        if(value>1)return State::unsupported;
        uint64_t checked=0;int32_t checkedMode=0;
        if(!resolve(m,image,checked)||checked!=object||!m.read(object+0xc4,checkedMode)||checkedMode!=mode)return State::waiting;
        if(!enabled){
            if(!applied_)return State::off;
            if(value!=1){forget();return State::off;}
            if(!m.store(object,&original_,1))return State::denied;
            if(!m.read(object,value)||value!=original_)return State::denied;
            forget();return State::off;
        }
        if(value==1)return State::ready; // Already enabled by the game: take no write ownership.
        object_=object;mode_=mode;original_=value;
        const uint8_t desired=1;
        if(!m.store(object,&desired,1))return State::denied;
        applied_=true; // Preserve restoration even if the verification read fails.
        if(!m.read(object,value)||value!=desired)return State::denied;
        return State::ready;
    }
};
}
