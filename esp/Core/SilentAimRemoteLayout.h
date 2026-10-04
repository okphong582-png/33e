#pragma once
#define SILENT_REMOTE_PAGE 0x4000
#define SILENT_REMOTE_ORIGINAL 0
#define SILENT_REMOTE_CLOCK 8
#define SILENT_REMOTE_SEQUENCE 16
#define SILENT_REMOTE_ENABLED 20
#define SILENT_REMOTE_DEADLINE 24
#define SILENT_REMOTE_LOCAL 32
#define SILENT_REMOTE_HANDLER 40
#define SILENT_REMOTE_INFO_CLASS 48
#define SILENT_REMOTE_HEAD 56
#define SILENT_REMOTE_REDIRECTS 72
#define SILENT_REMOTE_BUSY 80
#define SILENT_REMOTE_MAGIC 88
#define SILENT_REMOTE_MATCH 96

#ifndef __ASSEMBLER__
#include "SilentAimDirection.h"
#include <cstddef>
#include <cstdint>
namespace SilentAimRemote {
inline constexpr uint64_t Magic = 0x53494C454E543031ULL; // SILENT01, layout version 1
struct alignas(8) State {
    uint64_t original = 0, clock = 0;
    uint32_t sequence = 0, enabled = 0;
    uint64_t deadline = 0, local = 0, handler = 0, infoClass = 0;
    SilentAimDirection::Point head;
    uint32_t padding = 0;
    uint64_t redirects = 0;
    uint32_t busy = 0, padding2 = 0;
    uint64_t magic = Magic, match = 0;
};
static_assert(offsetof(State, original) == SILENT_REMOTE_ORIGINAL);
static_assert(offsetof(State, clock) == SILENT_REMOTE_CLOCK);
static_assert(offsetof(State, sequence) == SILENT_REMOTE_SEQUENCE);
static_assert(offsetof(State, enabled) == SILENT_REMOTE_ENABLED);
static_assert(offsetof(State, deadline) == SILENT_REMOTE_DEADLINE);
static_assert(offsetof(State, local) == SILENT_REMOTE_LOCAL);
static_assert(offsetof(State, handler) == SILENT_REMOTE_HANDLER);
static_assert(offsetof(State, infoClass) == SILENT_REMOTE_INFO_CLASS);
static_assert(offsetof(State, head) == SILENT_REMOTE_HEAD);
static_assert(offsetof(State, redirects) == SILENT_REMOTE_REDIRECTS);
static_assert(offsetof(State, busy) == SILENT_REMOTE_BUSY);
static_assert(offsetof(State, magic) == SILENT_REMOTE_MAGIC);
static_assert(offsetof(State, match) == SILENT_REMOTE_MATCH);
inline bool AllowsRemoteCode(uint32_t flags) {
    // Read-only CS_OPS_STATUS. Never attach a debugger or change signing flags.
    return (flags & 0x10000000u) && !(flags & (0x100u | 0x200u));
}
} // namespace SilentAimRemote
#endif
