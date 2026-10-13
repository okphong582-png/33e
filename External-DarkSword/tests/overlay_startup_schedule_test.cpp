#include "../Features/Games/FreeFire/OverlayStartupSchedule.h"
#include <cassert>
#include <limits>
#include <iostream>
using MizzeOverlayStartup::Schedule;
int main() {
    Schedule s;
    assert(!s.begin(std::numeric_limits<double>::quiet_NaN()));
    assert(s.begin(100));s.finish(false,true);
    for(int tick=1;tick<20;tick++)assert(!s.begin(100+tick*.05));
    assert(s.begin(101));s.finish(true,false);
    assert(!s.begin(200));
    s.reset();assert(s.begin(200));s.finish(false,false);assert(!s.begin(201));
    s.reset();
    for(unsigned i=0;i<Schedule::maxAttempts;i++){assert(s.begin(300+i));s.finish(false,true);}
    assert(!s.begin(1000));
    s.reset();assert(s.begin(1001));s.finish(true,false);
    std::cout<<"PASS startup schedule: missing-window retry, 1 Hz bound, 15-attempt limit, success/terminal stop and explicit restart.\n";
}
