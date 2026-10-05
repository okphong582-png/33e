#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace PlayerModesControl {
constexpr uint32_t AimLag=1, Burrow=2, FakeLag=4, Teleport=8;
constexpr float DefaultDepth=2.0f, MinimumDepth=1.0f, MaximumDepth=2.25f;
constexpr double ScopeGrace=0.18;
constexpr uint64_t LeaseNanoseconds=1000000000ULL;
inline float Depth(float value) {
    return std::isfinite(value) ? std::max(MinimumDepth,std::min(value,MaximumDepth)) : DefaultDepth;
}
struct State {
    double scopeUntil=0;
    bool scoped=false;
    void Reset(){scopeUntil=0;scoped=false;}
    uint32_t Flags(uint32_t wanted,bool scope,double now) {
        if(!(wanted&AimLag))scopeUntil=0;
        else if(scope)scopeUntil=now+ScopeGrace;
        scoped=(wanted&AimLag)&&scopeUntil>0&&now<scopeUntil;
        return (wanted&Burrow)|(((wanted&FakeLag)||scoped)?1u:0u);
    }
};
inline bool NewEpoch(uint64_t oldMatch,uint64_t oldLocal,uint32_t oldFlags,
                     uint64_t match,uint64_t local,uint32_t flags) {
    // Burrow and depth changes do not release an unrelated enemy hold.
    return match!=oldMatch||local!=oldLocal||((flags^oldFlags)&1u);
}
}
