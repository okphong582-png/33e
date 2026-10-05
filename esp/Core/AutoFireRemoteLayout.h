#pragma once
#define AUTO_PAGE 0x4000
#define AUTO_EFFECT_ENTRY 16
#define AUTO_TRACER_ENTRY 32
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
#define AUTO_INTERVAL 120
#define AUTO_ELAPSED 128
#define AUTO_SILENT_GATE 136
#define AUTO_EFFECT_ORIGINAL 144
#define AUTO_EFFECT_SKIPS 152
#define AUTO_TRACER_ORIGINAL 160
#define AUTO_TRACER_SKIPS 168
#define AUTO_METADATA_INIT 176
#define AUTO_TRACER_TYPEINFO 184
#define AUTO_METADATA_READY 192
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace AutoFireRemote {
inline constexpr uint64_t Magic = 0x4155544f46495238ULL; // AUTOFIR8: local tracer presentation gate
struct State {
    uint64_t original=0, clock=0, getter=0, start=0, stop=0;
    uint32_t sequence=0, enabled=0;
    uint64_t deadline=0, local=0, match=0, weapon=0, held=0;
    uint32_t busy=0, padding=0;
    uint64_t starts=0, magic=Magic, ticks=0;
    uint64_t interval=0;
    float elapsed=0;
    uint32_t reserved=0;
    uint64_t silentGate=0;
    uint64_t effectOriginal=0, effectSkips=0;
    uint64_t tracerOriginal=0, tracerSkips=0, metadataInit=0, tracerTypeInfo=0;
    uint32_t metadataReady=0, padding2=0;
};
static_assert(offsetof(State, sequence)==AUTO_SEQUENCE);
static_assert(offsetof(State, enabled)==AUTO_ENABLED);
static_assert(offsetof(State, held)==AUTO_HELD);
static_assert(offsetof(State, starts)==AUTO_STARTS);
static_assert(offsetof(State, magic)==AUTO_MAGIC);
static_assert(offsetof(State, ticks)==AUTO_TICKS);
static_assert(offsetof(State, interval)==AUTO_INTERVAL);
static_assert(offsetof(State, elapsed)==AUTO_ELAPSED);
static_assert(offsetof(State, silentGate)==AUTO_SILENT_GATE);
static_assert(offsetof(State, effectOriginal)==AUTO_EFFECT_ORIGINAL);
static_assert(offsetof(State, effectSkips)==AUTO_EFFECT_SKIPS);
static_assert(offsetof(State, tracerOriginal)==AUTO_TRACER_ORIGINAL);
static_assert(offsetof(State, tracerSkips)==AUTO_TRACER_SKIPS);
static_assert(offsetof(State, metadataInit)==AUTO_METADATA_INIT);
static_assert(offsetof(State, tracerTypeInfo)==AUTO_TRACER_TYPEINFO);
static_assert(offsetof(State, metadataReady)==AUTO_METADATA_READY);
}
#endif
