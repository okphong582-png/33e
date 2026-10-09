#pragma once
#include "ShotSettings.h"
#include <mach/mach.h>
#include <vector>
#include <algorithm>
namespace fcm {
class Process final:public Memory {
    task_t task=MACH_PORT_NULL;
    bool owned=false;
    int pid=0;
    uint64_t image=0;
    double lastConnect=-10;
    State connection=State::disconnected;
    ShotSettings shot;
    bool findImage();
    bool accepts(uint64_t header);
    void reset();
public:
    ~Process()override{restoreShot();reset();}
    bool copy(uint64_t,void *,size_t)override;
    bool store(uint64_t,const void *,size_t)override;
    State update(bool enabled);
    void restoreShot();
};
}
