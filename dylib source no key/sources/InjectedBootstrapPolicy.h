#pragma once
#include <cstdint>

namespace InjectedStartup {
// Main-queue policy. A new activation invalidates every queued retry from the
// preceding activation. Stale callbacks must not consume the new retry slot.
class Bootstrap {
public:
    using Generation = std::uint64_t;

    void restart(unsigned attempts) {
        ++generation_;
        remaining_ = attempts;
        pending_ = false;
    }

    void cancel() { restart(0); }

    bool schedule(Generation &ticket) {
        if (pending_ || remaining_ == 0) return false;
        ticket = generation_;
        pending_ = true;
        return true;
    }

    bool beginAttempt(Generation ticket) {
        if (ticket != generation_ || !pending_ || remaining_ == 0) return false;
        pending_ = false;
        --remaining_;
        return true;
    }

private:
    Generation generation_ = 0;
    unsigned remaining_ = 0;
    bool pending_ = false;
};
}
