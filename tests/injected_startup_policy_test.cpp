#include "../sources/InjectedStartupPolicy.h"
#include <cassert>
#include <limits>
int main() {
    InjectedStartup::Gate gate;
    assert(!gate.ready(true,false,1,844,390,0));
    assert(!gate.ready(true,true,1,844,390,1));
    assert(!gate.ready(true,true,1,844,390,1.5));
    assert(gate.ready(true,true,1,844,390,1.75));
    assert(!gate.ready(true,true,1,390,844,2)); // rotation
    assert(gate.ready(true,true,1,390,844,2.75));
    assert(!gate.ready(false,true,1,390,844,3));
    assert(!gate.ready(true,true,1,390,844,4)); // foreground resumes
    assert(gate.ready(true,true,1,390,844,4.75));
    assert(!gate.ready(true,true,2,390,844,5)); // another host window
    assert(gate.ready(true,true,2,390,844,5.75));
    assert(!gate.ready(true,true,2,390,844,5)); // clock reset
    assert(!gate.ready(true,true,2,std::numeric_limits<double>::quiet_NaN(),844,6));
    assert(!gate.ready(true,true,0,390,844,7));
    assert(!gate.ready(true,true,2,390,844,8));
    assert(gate.ready(true,true,2,390,844,8.75));
}
