#include "../esp/Core/KernelTableAddress.h"

int main() {
    using KernelMemory::ValidTableAddress;
    if (!ValidTableAddress(UINT64_C(0x123450000))) return 1;
    if (!ValidTableAddress(UINT64_C(0xfffffff012340000))) return 2;
    if (ValidTableAddress(0)) return 3;
    if (ValidTableAddress(UINT64_C(0xfffffff012340001))) return 4;
    if (ValidTableAddress(UINT64_C(0x10000000000000))) return 5;
    if (ValidTableAddress(UINT64_C(0x8000000012340000))) return 6;
    if (!ValidTableAddress(UINT64_C(0x123450080))) return 7;
    if (!ValidTableAddress(UINT64_C(0xfffffff012340080))) return 8;
    return 0;
}
