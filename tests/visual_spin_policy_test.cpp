#include "../esp/Core/VisualSpinPolicy.h"
#include "../esp/Core/PlayerModesControlPolicy.h"
#include <cassert>
#include <limits>
int main(){
    using namespace VisualSpin;
    Phase a,b;a.Step(0,0.5f);b.Step(0,0.5f);
    for(int i=1;i<=60;++i)a.Step(i/60.0,0.5f);
    for(int i=1;i<=30;++i)b.Step(i/30.0,0.5f);
    assert(std::abs(a.turns-.5)<1e-6 && std::abs(a.turns-b.turns)<1e-6);
    assert(std::abs(a.Sin()-1)<1e-6 && std::abs(a.Cos())<1e-6);
    a.Step(10,3);assert(std::abs(a.turns-.5)<1e-6); // Background gap cannot jump the pose.
    a.Step(9,3);assert(std::abs(a.turns-.5)<1e-6); // Clock reset.
    a.Reset();a.Step(0,1);for(int i=1;i<=120;++i)a.Step(i/60.0,1);
    assert(a.turns<1e-6 || a.turns>1-1e-6);
    assert(Speed(-1)==.1f && Speed(99)==3 && Speed(.2f)==.2f);
    assert(Speed(std::numeric_limits<float>::quiet_NaN())==DefaultSpeed);
    PlayerModesControl::State modes;
    assert(modes.Flags(PlayerModesControl::Spin,false,1)==4);
    assert(modes.Flags(PlayerModesControl::Spin|PlayerModesControl::Fly,false,1)==6);
    assert(modes.Flags(PlayerModesControl::Spin|PlayerModesControl::FakeLag,false,1)==5);
    assert(!PlayerModesControl::NewEpoch(1,2,3,1,2,7));
}
