#pragma once
#include <cstdint>
#include <cstddef>
#include <cstring>

namespace MizzeVN {
constexpr uint8_t UnityUUID[16] = {0xe5,0x0b,0x0e,0x3a,0xd9,0x31,0x38,0x5b,
                                 0x9e,0x4c,0x9f,0xfd,0xe6,0xd1,0xb9,0x23};
inline uint32_t word(const uint8_t *p) { uint32_t v; std::memcpy(&v, p, 4); return v; }
inline size_t headerBytes(const uint8_t *p, size_t n) {
    if (!p || n < 32 || word(p) != 0xfeedfacf || word(p + 4) != 0x0100000c) return 0;
    const uint32_t commands = word(p + 16), bytes = word(p + 20);
    if (!commands || commands > 2048 || bytes < 24 || bytes > 65536 || commands > bytes / 8) return 0;
    return 32 + bytes;
}
inline bool matches(const uint8_t *p, size_t n) {
    const size_t end = headerBytes(p, n);
    if (!end || n < end) return false;
    size_t offset = 32;
    bool found = false;
    for (uint32_t i = 0; i < word(p + 16); ++i) {
        if (offset > end || end - offset < 8) return false;
        const uint32_t command = word(p + offset), bytes = word(p + offset + 4);
        if (bytes < 8 || (bytes & 7) || bytes > end - offset) return false;
        if (command == 0x1b) {
            if (found || bytes != 24 || std::memcmp(p + offset + 8, UnityUUID, 16)) return false;
            found = true;
        }
        offset += bytes;
    }
    return found && offset == end;
}
}
