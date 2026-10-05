#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace PlayerModesInstall {
// IEntityTicker.OnUpdate is a separate interface entry in the supplied metadata.
// Its implementation also occupies the ordinary Player.OnUpdate virtual entry.
constexpr std::array<uint64_t, 2> Slots = {0x138 + 5 * 16, 0x138 + 26 * 16};

template<class Read, class Exchange>
bool Bind(uint64_t klass, uint64_t original, uint64_t callback, Read read, Exchange exchange) {
    std::array<uint64_t, Slots.size()> before{};
    for (std::size_t i=0; i<Slots.size(); ++i) {
        if (!read(klass+Slots[i], before[i]) ||
            (before[i]!=original && before[i]!=callback)) return false;
    }
    for (std::size_t i=0; i<Slots.size(); ++i) {
        if (before[i]==callback) continue;
        if (exchange(klass+Slots[i], before[i], callback)) continue;
        // Roll back only writes owned by this attempt; leave another writer alone.
        for (std::size_t j=0; j<i; ++j)
            if (before[j]!=callback) exchange(klass+Slots[j], callback, before[j]);
        return false;
    }
    return true;
}
}
