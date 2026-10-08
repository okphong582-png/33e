#pragma once
#include "Reader.h"
#include "CameraZoom.h"
#include <mach/mach.h>
namespace aov {
class Process final: public Memory {
    task_t task=MACH_PORT_NULL;
    bool owned=false;
    int pid=0;
    uint64_t image=0;
    double lastConnect=-10;
    State connection=State::disconnected;
    CameraZoom camera;
    bool findImage();
    bool accepts(uint64_t header);
    void reset();
public:
    ~Process() override { restoreCamera();reset(); }
    bool copy(uint64_t address,void *out,size_t size) override;
    bool store(uint64_t address,const void *value,size_t size) override;
    Snapshot update(bool enemies,bool showMonsters,float zoom=1.f);
    void restoreCamera();
};
}
