// MSHookFunctionChecker.m
#import "MSHookFunctionChecker.h"
#import <mach/mach.h>

// MARK: - ARM64 instruction decoding

typedef NS_ENUM(NSInteger, MSHookInstructionType) {
    MSHookInstructionTypeUnknown,
    MSHookInstructionTypeLdrX16,
    MSHookInstructionTypeBrX16,
    MSHookInstructionTypeAdrpX17,
    MSHookInstructionTypeAddX17,
    MSHookInstructionTypeBrX17
};

/// Sign-extend a 33-bit integer to 64 bits.
static inline int64_t signExtend33(int64_t value) {
    if (value & (1ULL << 32)) {
        // Set all bits above bit 32.
        value |= 0xFFFFFFFE00000000ULL;
    }
    return value;
}

/// Compute the page base for an ADRP instruction.
static uint64_t getAdrpPageBase(const void *functionAddr) {
    uint32_t arm = *(const uint32_t *)functionAddr;

    // Immediate field: immlo (bits 30:29) and immhi (bits 23:5)
    uint32_t immlo = (arm >> 29) & 0x3;
    uint32_t immhiMask = (((uint32_t)1 << 19) - 1) << 5; // bits 23:5
    uint32_t immhi = (arm & immhiMask) >> 5;

    int64_t imm = (int64_t)((immhi << 2) | immlo) << 12;
    imm = signExtend33(imm);

    // PC of the ADRP is the page address of the instruction.
    uintptr_t pcBase = ((uintptr_t)functionAddr >> 12) << 12;
    return (uint64_t)((int64_t)pcBase + imm);
}

/**
 Decode an AArch64 instruction at `functionAddr`.

 @param functionAddr Address of the instruction (4 bytes).
 @param outPageBase  If non‑NULL and the instruction is ADRP, receives the
                     computed page base.
 @param outPageOffset If non‑NULL and the instruction is ADD (x17), receives
                      the computed page offset.
 @return The instruction type.
 */
static MSHookInstructionType MSHookDecodeInstruction(const void *functionAddr,
                                                     uint64_t * _Nullable outPageBase,
                                                     uint64_t * _Nullable outPageOffset) {
    uint32_t arm = *(const uint32_t *)functionAddr;

    // ldr xt, #imm  (C4.4.5 and C6.2.84)
    uint32_t ldr_register_literal = (arm & 0xFF000000) >> 24;
    if (ldr_register_literal == 0x58) { // 0b01011000
        uint32_t rt = arm & 0x1F;
        uint32_t imm19 = (arm & ((((uint32_t)1 << 19) - 1) << 5)) >> 5;
        if (rt == 16 && (imm19 << 2) == 8) {
            return MSHookInstructionTypeLdrX16;
        }
    }

    // br (branch to register)
    if ((arm >> 10) == 0x3587C0) { // 0b1101011000011111000000
        uint32_t br_rn = (arm & (0x1F << 5)) >> 5;
        if (br_rn == 16) return MSHookInstructionTypeBrX16;
        if (br_rn == 17) return MSHookInstructionTypeBrX17;
    }

    // adrp (C6.2.10)
    if ((arm >> 31) == 1 && ((arm >> 24) & 0x1F) == 16) {
        uint32_t rd = arm & 0x1F;
        if (rd == 17) {
            uint64_t pageBase = getAdrpPageBase(functionAddr);
            if (outPageBase) *outPageBase = pageBase;
            return MSHookInstructionTypeAdrpX17;
        }
    }

    // add (C4.2.1 and C6.2.4)
    if ((arm >> 24) == 0x91) { // 0b10010001
        uint32_t add_rn = (arm & (0x1F << 5)) >> 5;
        uint32_t add_rd = arm & 0x1F;
        uint32_t add_imm12 = (arm & ((((uint32_t)1 << 12) - 1) << 10)) >> 10;
        uint64_t imm = 0;
        uint32_t shift = (arm & (0x3 << 22)) >> 22;
        if (shift == 0) {
            imm = add_imm12;
        } else if (shift == 1) {
            imm = (uint64_t)add_imm12 << 12;
        } else {
            return MSHookInstructionTypeUnknown; // Undefined shift
        }
        if (add_rn == 17 && add_rd == 17) {
            if (outPageOffset) *outPageOffset = imm;
            return MSHookInstructionTypeAddX17;
        }
    }

    return MSHookInstructionTypeUnknown;
}

// MARK: - MSHookFunctionChecker implementation

@implementation MSHookFunctionChecker

+ (BOOL)amIMSHooked:(void *)functionAddr {
    if (!functionAddr) return NO;

    MSHookInstructionType first = MSHookDecodeInstruction(functionAddr, NULL, NULL);

    switch (first) {
        case MSHookInstructionTypeLdrX16: {
            void *secondAddr = (uint8_t *)functionAddr + 4;
            MSHookInstructionType second = MSHookDecodeInstruction(secondAddr, NULL, NULL);
            return (second == MSHookInstructionTypeBrX16);
        }
        case MSHookInstructionTypeAdrpX17: {
            void *secondAddr = (uint8_t *)functionAddr + 4;
            void *thirdAddr  = (uint8_t *)functionAddr + 8;
            MSHookInstructionType second = MSHookDecodeInstruction(secondAddr, NULL, NULL);
            MSHookInstructionType third  = MSHookDecodeInstruction(thirdAddr, NULL, NULL);
            return (second == MSHookInstructionTypeAddX17 && third == MSHookInstructionTypeBrX17);
        }
        default:
            return NO;
    }
}

+ (void *)denyMSHook:(void *)functionAddr {
    if (![self amIMSHooked:functionAddr]) {
        return NULL;
    }

    // Determine the size of replaced instructions and the original function start.
    MSHookInstructionType first = MSHookDecodeInstruction(functionAddr, NULL, NULL);
    uint8_t *origFunctionBeginAddr = (uint8_t *)functionAddr;

    switch (first) {
        case MSHookInstructionTypeLdrX16:
            origFunctionBeginAddr += 16;
            break;
        case MSHookInstructionTypeAdrpX17:
            origFunctionBeginAddr += 12;
            break;
        default:
            // Should never happen (already confirmed hooked).
            return NULL;
    }

    // Iterate over VM regions looking for the original code.
    vm_region_basic_info_64_t regionInfo;
    mach_msg_type_number_t regionInfoCount = VM_REGION_BASIC_INFO_64;
    vm_address_t vmRegionAddress = 1;
    vm_size_t vmRegionSize = 0;
    mach_port_t objectName = MACH_PORT_NULL;

    while (1) {
        if (vmRegionAddress == 0) {
            return NULL; // invalid region address
        }

        kern_return_t kr = vm_region_64(mach_task_self_,
                                        &vmRegionAddress,
                                        &vmRegionSize,
                                        VM_REGION_BASIC_INFO_64,
                                        (vm_region_info_t)&regionInfo,
                                        &regionInfoCount,
                                        &objectName);
        if (kr != KERN_SUCCESS) {
            return NULL; // no more regions or error
        }

        // Only interested in executable regions (READ + EXECUTE).
        if (regionInfo->protection != (VM_PROT_READ | VM_PROT_EXECUTE)) {
            vmRegionAddress += vmRegionSize;
            continue;
        }

        if (first == MSHookInstructionTypeLdrX16) {
            // Cydia Substrate style: the trampoline may be anywhere in the region.
            vm_address_t vmRegionProcedureAddr = vmRegionAddress;
            vm_address_t vmRegionInstAddr = vmRegionAddress;
            vm_address_t vmRegionEndAddress = vmRegionAddress + vmRegionSize;

            while (vmRegionEndAddress >= vmRegionInstAddr) {
                vmRegionInstAddr += 4;
                void *instructionAddr = (void *)(uintptr_t)vmRegionInstAddr;
                if (!instructionAddr) continue;

                // Skip zero pointers (unused slots).
                if (*(void **)instructionAddr == NULL) {
                    vmRegionProcedureAddr = vmRegionInstAddr + 4;
                    continue;
                }

                MSHookInstructionType instr = MSHookDecodeInstruction(instructionAddr, NULL, NULL);
                if (instr == MSHookInstructionTypeLdrX16) {
                    void *nextAddr = (uint8_t *)instructionAddr + 4;
                    MSHookInstructionType nextInstr = MSHookDecodeInstruction(nextAddr, NULL, NULL);
                    if (nextInstr == MSHookInstructionTypeBrX16) {
                        // Check the stored original address at (instructionAddr + 8).
                        void *storedAddr = *(void **)((uint8_t *)instructionAddr + 8);
                        if (storedAddr == origFunctionBeginAddr) {
                            return (void *)(uintptr_t)(vmRegionProcedureAddr + 4);
                        }
                    }
                }
            }
        } else if (first == MSHookInstructionTypeAdrpX17) {
            // Substitute style: the trampoline is near the beginning of the region.
            for (int i = 3; i < 20; i++) {
                void *instructionAddr = (void *)(uintptr_t)(vmRegionAddress + i * 4);
                if (!instructionAddr) continue;

                uint64_t pageBase = 0, pageOffset = 0;
                MSHookInstructionType instr = MSHookDecodeInstruction(instructionAddr, &pageBase, NULL);
                if (instr == MSHookInstructionTypeAdrpX17) {
                    void *nextAddr = (uint8_t *)instructionAddr + 4;
                    MSHookInstructionType nextInstr = MSHookDecodeInstruction(nextAddr, NULL, &pageOffset);
                    if (nextInstr == MSHookInstructionTypeAddX17) {
                        void *thirdAddr = (uint8_t *)instructionAddr + 8;
                        MSHookInstructionType thirdInstr = MSHookDecodeInstruction(thirdAddr, NULL, NULL);
                        if (thirdInstr == MSHookInstructionTypeBrX17) {
                            if (pageBase + pageOffset == (uintptr_t)origFunctionBeginAddr) {
                                return (void *)(uintptr_t)vmRegionAddress;
                            }
                        }
                    }
                }
            }
        }

        vmRegionAddress += vmRegionSize;
    }
}

@end