#include "../esp/Core/SilentAimSelection.h"
#include <cassert>
#include <limits>
using SilentAimSelection::Selection;
int main() {
    constexpr float w=1000, h=600, radius=108, limit=100;
    auto add=[](Selection &s, uint64_t id, float x, float meters, bool eligible=true) {
        s.consider(id,x,300,1,w,h,radius,meters,limit,eligible);
    };
    Selection s; add(s,1,510,90); add(s,2,510,15); assert(s.target==2);
    s={}; add(s,1,500,80); add(s,2,600,5); assert(s.target==1);
    s={}; s.previous=1; add(s,1,580,80); add(s,2,510,20); assert(s.target==2);
    s={}; s.previous=1; add(s,2,510,20); add(s,1,512,20); assert(s.target==1);
    s={}; s.previous=1; add(s,1,609,1); assert(!s.target);
    add(s,2,500,101); add(s,3,500,10,false); assert(!s.target);
    s.consider(4,500,300,-1,w,h,radius,5,limit,true); assert(!s.target);
    add(s,5,500,std::numeric_limits<float>::quiet_NaN()); assert(!s.target);
    s={}; add(s,2,510,20); add(s,1,510,20); assert(s.target==1);
    assert(SilentAimSelection::Radius(w,h,18)==radius);
    assert(SilentAimSelection::Radius(w,h,100)==180);
}
