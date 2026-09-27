#include "../sources/LicenseSessionPolicy.h"
#include <cassert>
#include <limits>

int main() {
    using namespace LicenseSessionPolicy;
    for (long status : {0L, 408L, 429L, 500L, 503L, 599L}) assert(RetryableStatus(status));
    for (long status : {200L, 301L, 400L, 401L, 403L, 404L, 600L}) assert(!RetryableStatus(status));

    const double now = 1800000000.0;
    const double uptime = 500.0;
    const double longExpiry = (now + 86400.0) * 1000.0;
    const double lease = Deadline(uptime, longExpiry, now);
    assert(lease == uptime + LeaseSeconds);
    assert(Authorized(lease, uptime));
    assert(Authorized(lease, lease - 0.001));
    assert(!Authorized(lease, lease));
    assert(!Authorized(lease, lease + 100));
    // HTTP retries do not change an already issued deadline.
    for (double retryTime : {uptime + 8.0, uptime + 16.0, uptime + 24.0, uptime + 30.0}) {
        assert(Authorized(lease, retryTime) == (retryTime < lease));
    }
    // A short key cannot acquire a lease longer than its remaining validity.
    assert(Deadline(uptime, (now + 3.0) * 1000.0, now) == uptime + 3.0);
    assert(Deadline(uptime, now * 1000.0, now) == 0);
    assert(Deadline(uptime, (now - 1.0) * 1000.0, now) == 0);
    assert(Deadline(uptime, -1, now) == 0);
    assert(Deadline(uptime, std::numeric_limits<double>::infinity(), now) == 0);
    assert(Deadline(uptime, std::numeric_limits<double>::quiet_NaN(), now) == 0);
    assert(!Authorized(std::numeric_limits<double>::quiet_NaN(), uptime));
    assert(!Authorized(std::numeric_limits<double>::infinity(), uptime));
    assert(!Authorized(lease, -1));
    return 0;
}
