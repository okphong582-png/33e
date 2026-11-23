#pragma once
#include <cmath>
#include <algorithm>

struct MizzeFramePacer {
    double averageSeconds = 0;
    double observe(double seconds, double requestedHz) {
        if (!std::isfinite(requestedHz)) requestedHz = 60;
        requestedHz = std::max(30.0, std::min(60.0, requestedHz));
        if (!std::isfinite(seconds) || seconds <= 0) return requestedHz;
        averageSeconds = averageSeconds == 0 ? seconds : averageSeconds * 0.9 + seconds * 0.1;
        // Leave room for input and IPC; never replay missed timer ticks.
        return std::max(30.0, std::min(requestedHz, 1.0 / (averageSeconds * 1.25)));
    }
};
