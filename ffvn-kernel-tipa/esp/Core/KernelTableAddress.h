#pragma once
#include <stdint.h>

namespace KernelMemory {
// Dopamine vtophys accepts a physical TTEP or a kernel virtual TTE address.
inline bool ValidTableAddress(uint64_t address) {
    const bool physical = address < (UINT64_C(1) << 52);
    const bool kernelVirtual = address >= UINT64_C(0xffff000000000000);
    // vtophys indexes uint64_t entries from this root. Do not require a
    // full page boundary: compact root tables can begin within a page.
    return address && !(address & 7) && (physical || kernelVirtual);
}
}
