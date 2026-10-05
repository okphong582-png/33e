#include "../esp/Core/PlayerModesControlPolicy.h"
#include "../esp/Core/PlayerModesControllerPolicy.h"
#include <vector>
#include <cassert>
#include <limits>

int main() {
    // Ordinary matches may have no PhysicalCCT. Resolve the verified Unity
    // controller separately, without interpreting it as a PhysicalCCT layout.
    {
        std::vector<uint8_t> mem(0x10000);
        auto valid=[&](uint64_t a){return a>=0x1000&&a<mem.size();};
        auto read=[&](uint64_t a,void *p,size_t n){if(!valid(a)||a+n>mem.size())return false;std::memcpy(p,mem.data()+a,n);return true;};
        auto ptr=[&](uint64_t a,uint64_t v){std::memcpy(mem.data()+a,&v,8);};
        ptr(0x1000+0x4d8,0x2000);ptr(0x2000,0x3000);ptr(0x2000+0x10,0x6000);
        ptr(0x3000+0x10,0x4000);ptr(0x3000+0x18,0x4100);
        std::memcpy(mem.data()+0x4000,"CharacterController",20);std::memcpy(mem.data()+0x4100,"UnityEngine",12);
        PlayerModesController::Identity id;
        assert(PlayerModesController::Resolve(0x1000,id,read,valid)&&id.kind==2&&id.object==0x2000);
        ptr(0x2000+0x10,0);assert(!PlayerModesController::Resolve(0x1000,id,read,valid)&&!id.object);
        mem[0x1260]=1;ptr(0x1268,0x2000);ptr(0x2000+0x1c8,0x6000);
        std::memcpy(mem.data()+0x4000,"PhysicalCCT",12);std::memcpy(mem.data()+0x4100,"COW.GamePlay",13);
        assert(PlayerModesController::Resolve(0x1000,id,read,valid)&&id.kind==1);
        mem[0x4100]='X';assert(!PlayerModesController::Resolve(0x1000,id,read,valid));
        mem[0x1260]=2;assert(!PlayerModesController::Resolve(0x1000,id,read,valid));
    }
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
    // Explicitly disabling Aimlag has no scope grace; Fly remains independent.
    assert(state.Flags(AimLag|Fly,true,13)==3);
    assert(state.Flags(Fly,false,13.01)==2);
    assert(state.Flags(Fly|FakeLag,false,13.02)==3);
    state.Reset();assert(state.Flags(AimLag,false,13.03)==0);
    // A long ADS session with intermittent false samples and feature toggles
    // must not produce release edges or recapture epochs.
    state.Reset();uint32_t old=1;
    for(int i=0;i<3600;++i){
        const double now=20+i/60.0;
        const uint32_t wanted=AimLag|(i%2?Fly:0u)|(i%3?FakeLag:0u);
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
    // Saved preferences cannot publish non-finite or unbounded height.
    assert(Height(2)==2&&Height(2.25f)==2.25f&&Height(1)==1);
    assert(Height(-100)==1&&Height(100)==5);
    assert(Height(std::numeric_limits<float>::quiet_NaN())==3);
    assert(Height(std::numeric_limits<float>::infinity())==3);
    assert(LeaseNanoseconds==1000000000ULL);
}
