#pragma once
#include "Reader.h"
namespace aov {
inline float zoomMultiplier(float value) {
    if(!std::isfinite(value))return 1.f;
    return std::round(std::clamp(value,1.f,4.f)*10.f)/10.f;
}
class CameraZoom {
    uint64_t object_=0,native_=0;
    float original_=0,last_=0;
    bool applied_=false;
    static bool usable(float value){return std::isfinite(value)&&std::abs(value)<10000.f;}
    bool set(Memory &m,uint64_t object,float value){
        if(!m.store(object+cameraAdditionZoom,&value,sizeof(value)))return false;
        uint8_t changed=1;
        return m.store(object+cameraDirty,&changed,sizeof(changed));
    }
public:
    bool applied()const{return applied_;}
    void forget(){object_=native_=0;original_=last_=0;applied_=false;}
    ZoomState update(Memory &m,uint64_t image,float multiplier){
        multiplier=zoomMultiplier(multiplier);
        if(multiplier==1.f&&!applied_)return ZoomState::off;
        auto system=singleton(m,image+cameraMethod);
        auto object=system?m.pointer(system+mobaCamera):0;
        auto native=object?m.pointer(object+nativeCamera):0;
        uint8_t started=0,dirty=0;
        float amount=0,addition=0;
        if(!object||!native||!m.read(object+cameraStarted,started)||started!=1||
           !m.read(object+cameraDirty,dirty)||dirty>1||!m.read(object+cameraZoomAmount,amount)||
           !m.read(object+cameraAdditionZoom,addition)||!usable(amount)||amount<=.01f||!usable(addition)){
            // No writes through a previous scene's object after it disappears.
            forget();return multiplier==1.f?ZoomState::off:ZoomState::waiting;
        }
        if(object!=object_||native!=native_){forget();object_=object;native_=native;original_=addition;}
        // Preserve changes made by the game while this feature is enabled.
        if(applied_&&std::abs(addition-last_)>.0001f){original_=addition;applied_=false;}
        if(!applied_)original_=addition;
        float target=multiplier==1.f?original_:(amount+original_)*multiplier-amount;
        if(!usable(target)||amount+original_<=.01f)return ZoomState::waiting;
        // Resolve the singleton again immediately before writing.
        if(singleton(m,image+cameraMethod)!=system||m.pointer(system+mobaCamera)!=object||m.pointer(object+nativeCamera)!=native){forget();return ZoomState::waiting;}
        if(std::abs(target-addition)>.0001f){
            float before=addition;
            if(!set(m,object,target)){
                // Undo a partial write if the dirty flag was denied.
                m.store(object+cameraAdditionZoom,&before,sizeof(before));
                float actual=0;
                if(m.read(object+cameraAdditionZoom,actual)&&std::abs(actual-target)<.0001f){last_=target;applied_=true;}
                return ZoomState::denied;
            }
        }
        last_=target;applied_=multiplier!=1.f;
        if(!applied_)forget();
        return multiplier==1.f?ZoomState::off:ZoomState::active;
    }
};
}
