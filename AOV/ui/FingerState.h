#pragma once
#include <array>
#include <cstdint>

namespace aov {
enum class FingerPhase { none, began, moved, ended, cancelled };
// Per-finger state: lifting a joystick finger cannot release a menu tap.
class FingerState {
    struct Slot { uint64_t id=0; bool down=false; };
    std::array<Slot,16> slots_{};
public:
    FingerPhase update(uint64_t id, bool down, bool cancel) {
        Slot *slot=nullptr;
        for(auto &s:slots_)if(s.down&&s.id==id){slot=&s;break;}
        if(cancel||!down){
            if(!slot)return FingerPhase::none;
            slot->down=false;
            return cancel?FingerPhase::cancelled:FingerPhase::ended;
        }
        if(slot)return FingerPhase::moved;
        for(auto &s:slots_)if(!s.down){s={id,true};return FingerPhase::began;}
        return FingerPhase::none;
    }
};
}
