#pragma once
#include <cmath>

namespace MizzeOverlayStartup {
// Only a missing host window is retryable. View creation and framework-loading
// failures stop until a new connection so a timer cannot multiply WebViews.
class Schedule {
    unsigned attempts_ = 0;
    double next_ = 0;
    bool stopped_ = false;
public:
    static constexpr unsigned maxAttempts = 15;
    void reset() { attempts_ = 0; next_ = 0; stopped_ = false; }
    bool begin(double now) {
        if (!std::isfinite(now) || stopped_ || attempts_ >= maxAttempts || now < next_) return false;
        ++attempts_;
        next_ = now + 1.0;
        return true;
    }
    void finish(bool ready, bool retryable) { if (ready || !retryable) stopped_ = true; }
};
}
