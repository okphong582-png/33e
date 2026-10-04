#include "../esp/Core/SilentAimPolicy.h"
#include <cassert>
int main() {
    uint32_t phase=50, next=0;
    assert(SilentAimPolicy::Head(75,phase,next));
    assert(next==25);
    assert(SilentAimPolicy::Head(75,next,next));
    assert(next==0);
    assert(!SilentAimPolicy::Head(75,next,next));
    assert(next==75);
    assert(SilentAimPolicy::HeadPercent(-1)==0);
    assert(SilentAimPolicy::HeadPercent(150)==100);
    for (uint32_t percent : {0u,25u,75u,100u}) {
        uint32_t shots=0, accumulator=50;
        for (int i=0;i<100;++i) if (SilentAimPolicy::Head(percent,accumulator,accumulator))++shots;
        assert(shots==percent);
    }
    auto cfg=SilentAimPolicy::Automatic(true); assert(cfg.fov==12 && cfg.distance==120);
    auto body=SilentAimPolicy::Chest({0,10,0},{0,0,0}); assert(body.y>3.9f && body.y<4.1f);
}
