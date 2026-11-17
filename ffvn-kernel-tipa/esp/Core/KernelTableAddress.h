#pragma once
#include <stdint.h>

namespace KernelMemory {
// Dopamine vtophys accepts a physical TTEP or a kernel virtual TTE address.
inline bool ValidTableAddress(uint64_t address) {
    const bool physical = address < (UINT64_C(1) << 52);
    const bool kernelVirtual = address >= UINT64_C(0xffff000000000000);
    return address && !(address & 0xfff) && (physical || kernelVirtual);
}
}
