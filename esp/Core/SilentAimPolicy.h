#pragma once
#include <algorithm>
#include <cmath>
#include "SilentAimDirection.h"
namespace SilentAimPolicy {
inline uint32_t HeadPercent(float value) {
    return std::isfinite(value) ? static_cast<uint32_t>(std::clamp(value, 0.0f, 100.0f)+0.5f) : 75;
}
struct Config { float fov, distance; };
inline Config Automatic(bool scoping) { return scoping ? Config{12,120} : Config{18,80}; }
// Balanced head/body distribution over actual eligible handler dispatches.
// Render ticks, bypassed dispatches and stale snapshots never advance phase.
inline bool Head(uint32_t percent, uint32_t phase, uint32_t &next) {
    next = phase%100 + std::min(percent,100u);
    const bool head = next>=100;
    if (head) next-=100;
    return head;
}
inline SilentAimDirection::Point Chest(SilentAimDirection::Point head, SilentAimDirection::Point hip) {
    return {hip.x+(head.x-hip.x)*0.4f, hip.y+(head.y-hip.y)*0.4f, hip.z+(head.z-hip.z)*0.4f};
}
}
