#include "../esp/Core/AimModePolicy.h"
#include <cassert>
#include <limits>
#include <iostream>

int main() {
    using namespace AimModePolicy;
    // Columns: neither action, scope only, fire only, fire+scope.
    const bool expected[5][4]={{false,false,false,false},{false,false,true,true},
        {false,true,false,true},{true,true,true,true},{false,false,false,true}};
    for (int mode=0;mode<5;++mode)
        for (int input=0;input<4;++input)
            assert(Triggered(ReadActivation(mode),input&2,input&1)==expected[mode][input]);
    // Opening another type's controls never inherits the previous active condition.
    for (Type type : {Type::Head,Type::Neck,Type::Silent})
        assert(!Triggered(AfterTypeSelection(type),true,true));
    for (float invalid : {-1.f,5.f,1.5f,std::numeric_limits<float>::quiet_NaN(),
            std::numeric_limits<float>::infinity()})
        assert(!Triggered(ReadActivation(invalid),true,true));
    assert(ReadType(1)==Type::Neck && ReadType(2)==Type::Silent);
    assert(ReadType(std::numeric_limits<float>::quiet_NaN())==Type::Head);
    std::cout<<"Explicit aim activation: all action combinations passed\n";
}
