#pragma once
#define AUTO_PAGE 0x4000
#define AUTO_ORIGINAL 0
#define AUTO_CLOCK 8
#define AUTO_GET_WEAPON 16
#define AUTO_START 24
#define AUTO_STOP 32
#define AUTO_SEQUENCE 40
#define AUTO_ENABLED 44
#define AUTO_DEADLINE 48
#define AUTO_LOCAL 56
#define AUTO_MATCH 64
#define AUTO_WEAPON 72
#define AUTO_HELD 80
#define AUTO_BUSY 88
#define AUTO_STARTS 96
#define AUTO_MAGIC 104
#define AUTO_TICKS 112
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace AutoFireRemote {
inline constexpr uint64_t Magic = 0x4155544f46495232ULL; // AUTOFIR2: weapon update callback
struct State {
    uint64_t original=0, clock=0, getter=0, start=0, stop=0;
    uint32_t sequence=0, enabled=0;
    uint64_t deadline=0, local=0, match=0, weapon=0, held=0;
    uint32_t busy=0, padding=0;
    uint64_t starts=0, magic=Magic, ticks=0;
};
static_assert(offsetof(State, sequence)==AUTO_SEQUENCE);
static_assert(offsetof(State, enabled)==AUTO_ENABLED);
static_assert(offsetof(State, held)==AUTO_HELD);
static_assert(offsetof(State, starts)==AUTO_STARTS);
static_assert(offsetof(State, magic)==AUTO_MAGIC);
static_assert(offsetof(State, ticks)==AUTO_TICKS);
}
#endif
