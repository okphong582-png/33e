#pragma once
#include <cstdint>
#include <mach/mach.h>

uint64_t KernelProcessIdentity();
bool KernelAimWriteReady();
mach_port_t KernelCopyTaskPort(uint64_t module, kern_return_t *error);
