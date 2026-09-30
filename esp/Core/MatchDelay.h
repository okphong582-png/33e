#pragma once
#include <cmath>
#include <cstdint>
struct MatchDelay {
    uint64_t match = 0;
    double began = 0;
    bool ready = false;
    void reset() { match = 0; began = 0; ready = false; }
    bool update(uint64_t current, double now) {
        if (!current || !std::isfinite(now)) { reset(); return false; }
        if (match != current || now < began) { match = current; began = now; ready = false; }
        ready = now - began >= 60.0;
        return ready;
    }
};
