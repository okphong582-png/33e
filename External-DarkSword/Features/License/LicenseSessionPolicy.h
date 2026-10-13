#pragma once
#include <algorithm>
#include <cmath>

namespace LicenseSessionPolicy {
constexpr double LeaseSeconds = 30.0;
constexpr double RefreshSeconds = 8.0;
constexpr unsigned MaximumAttempts = 2;

inline bool RetryableStatus(long status) {
    return status == 0 || status == 408 || status == 429 ||
           (status >= 500 && status <= 599);
}

inline double Deadline(double requestStarted, double expiryMilliseconds, double serverNow) {
    if (!std::isfinite(requestStarted) || !std::isfinite(expiryMilliseconds) ||
        !std::isfinite(serverNow) || requestStarted < 0 || serverNow <= 0) return 0;
    const double remaining = expiryMilliseconds / 1000.0 - serverNow;
    return remaining > 0 ? requestStarted + std::min(LeaseSeconds, remaining) : 0;
}

inline bool Authorized(double deadline, double uptime) {
    return std::isfinite(deadline) && std::isfinite(uptime) && uptime >= 0 && uptime < deadline;
}
}
