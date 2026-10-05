#include "../esp/Core/PlayerModesControlPolicy.h"
#include <cassert>
#include <limits>

int main() {
    using namespace PlayerModesControl;
    State state;
    // Aimlag requires ADS, tolerates a short unread/transition, then releases.
    assert(state.Flags(AimLag,false,10)==0);
    assert(state.Flags(AimLag,true,10.1)==1);
    assert(state.Flags(AimLag,false,10.15)==1);
    assert(state.Flags(AimLag,false,10.3)==0);
    // FakeLag holds without ADS; releasing it returns to Aimlag's actual scope.
    assert(state.Flags(FakeLag,false,11)==1&&!state.scoped);
    assert(state.Flags(AimLag|FakeLag,false,11.1)==1);
    assert(state.Flags(AimLag,false,11.2)==0);
    assert(state.Flags(AimLag,true,12)==1);
    assert(state.Flags(AimLag|FakeLag,false,12.05)==1);
    assert(state.Flags(AimLag,false,12.1)==1);
    assert(state.Flags(AimLag,false,12.3)==0);
    // Explicitly disabling Aimlag has no scope grace; Burrow remains independent.
    assert(state.Flags(AimLag|Burrow,true,13)==3);
    assert(state.Flags(Burrow,false,13.01)==2);
    assert(state.Flags(Burrow|FakeLag,false,13.02)==3);
    state.Reset();assert(state.Flags(AimLag,false,13.03)==0);
    assert(state.Flags(Teleport,false,14)==0);
    assert(state.Flags(Teleport|FakeLag,false,14.1)==1);
    assert(state.Flags(Teleport|Burrow,false,14.2)==2);
    // A long ADS session with intermittent false samples and feature toggles
    // must not produce release edges or recapture epochs.
    state.Reset();uint32_t old=1;
    for(int i=0;i<3600;++i){
        const double now=20+i/60.0;
        const uint32_t wanted=AimLag|(i%2?Burrow:0u)|(i%3?FakeLag:0u);
        const uint32_t flags=state.Flags(wanted,i%10!=9,now);
        assert(flags&1u);assert(!NewEpoch(100,200,old,100,200,flags));old=flags;
    }
    // Local feature toggles must not recapture an already held enemy.
    assert(!NewEpoch(100,200,1,100,200,3));
    assert(!NewEpoch(100,200,3,100,200,1));
    assert(NewEpoch(100,200,1,100,200,0));
    assert(NewEpoch(100,200,0,100,200,1));
    assert(NewEpoch(100,200,1,101,200,1));
    assert(NewEpoch(100,200,1,100,201,1));
    // Saved preferences cannot publish non-finite or unbounded depth.
    assert(Depth(2)==2&&Depth(2.25f)==2.25f&&Depth(1)==1);
    assert(Depth(-100)==1&&Depth(100)==2.25f);
    assert(Depth(std::numeric_limits<float>::quiet_NaN())==2);
    assert(Depth(std::numeric_limits<float>::infinity())==2);
    assert(LeaseNanoseconds==1000000000ULL);
}
