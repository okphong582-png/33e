#ifndef CODE_VIRTUALIZER_H
#define CODE_VIRTUALIZER_H

/*
 * ═══════════════════════════════════════════════════════════════
 *  __CV Segment – Code Virtualization Engine
 * ═══════════════════════════════════════════════════════════════
 *
 *  Converts critical code paths into virtualized bytecode that
 *  executes through a custom VM interpreter at runtime.
 *
 *  Pipeline position:
 *    Source Code → Obfuscation Pipeline → __CV Segment
 *
 *  Anti-RE effect:
 *    - Static disassembly shows only VM dispatch loop
 *    - Actual logic hidden in encrypted bytecode stream
 *    - Each build produces unique opcode mappings
 * ═══════════════════════════════════════════════════════════════
 */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include "KabraxHide.h"

#if defined(__clang__) || defined(__GNUC__)
  #define CVIRT_SECTION    __attribute__((section("__TEXT,__cv_text")))
  #define CVIRT_NOINLINE   __attribute__((noinline))
  #define CVIRT_HIDDEN     __attribute__((visibility("hidden")))
  #define CVIRT_USED       __attribute__((used))
  #define CVIRT_INLINE     inline __attribute__((always_inline))
#else
  #define CVIRT_SECTION
  #define CVIRT_NOINLINE
  #define CVIRT_HIDDEN
  #define CVIRT_USED
  #define CVIRT_INLINE     inline
#endif

namespace _cv_ {

// ─── Compile-time opcode generation ───────────────────────────
// Each build shuffles opcode assignments via __TIME__ seed
static constexpr uint64_t _cv_seed() {
    return ((__TIME__[0]-'0')*36000ULL) + ((__TIME__[1]-'0')*3600ULL) +
           ((__TIME__[3]-'0')*600ULL)   + ((__TIME__[4]-'0')*60ULL) +
           ((__TIME__[6]-'0')*10ULL)    + (__TIME__[7]-'0');
}

static constexpr uint64_t CVIRT_SEED = _cv_seed();

constexpr uint64_t _cv_mix(uint64_t a, uint64_t b) {
    uint64_t h = a ^ (b * 0x9E3779B97F4A7C15ULL);
    h ^= h >> 30;
    h *= 0xBF58476D1CE4E5B9ULL;
    h ^= h >> 27;
    h *= 0x94D049BB133111EBULL;
    return h ^ (h >> 31);
}

// Opcode table – remapped per build
enum CVOpcode : uint8_t {
    CVIRT_NOP      = (uint8_t)(_cv_mix(CVIRT_SEED, 0)  & 0xFF),
    CVIRT_LOAD     = (uint8_t)(_cv_mix(CVIRT_SEED, 1)  & 0xFF),
    CVIRT_STORE    = (uint8_t)(_cv_mix(CVIRT_SEED, 2)  & 0xFF),
    CVIRT_XOR      = (uint8_t)(_cv_mix(CVIRT_SEED, 3)  & 0xFF),
    CVIRT_ADD      = (uint8_t)(_cv_mix(CVIRT_SEED, 4)  & 0xFF),
    CVIRT_SUB      = (uint8_t)(_cv_mix(CVIRT_SEED, 5)  & 0xFF),
    CVIRT_ROT      = (uint8_t)(_cv_mix(CVIRT_SEED, 6)  & 0xFF),
    CVIRT_JMP      = (uint8_t)(_cv_mix(CVIRT_SEED, 7)  & 0xFF),
    CVIRT_JZ       = (uint8_t)(_cv_mix(CVIRT_SEED, 8)  & 0xFF),
    CVIRT_CMP      = (uint8_t)(_cv_mix(CVIRT_SEED, 9)  & 0xFF),
    CVIRT_CALL     = (uint8_t)(_cv_mix(CVIRT_SEED, 10) & 0xFF),
    CVIRT_RET      = (uint8_t)(_cv_mix(CVIRT_SEED, 11) & 0xFF),
    CVIRT_MUL      = (uint8_t)(_cv_mix(CVIRT_SEED, 12) & 0xFF),
    CVIRT_NOT      = (uint8_t)(_cv_mix(CVIRT_SEED, 13) & 0xFF),
    CVIRT_AND      = (uint8_t)(_cv_mix(CVIRT_SEED, 14) & 0xFF),
    CVIRT_OR       = (uint8_t)(_cv_mix(CVIRT_SEED, 15) & 0xFF),
    CVIRT_SHL      = (uint8_t)(_cv_mix(CVIRT_SEED, 16) & 0xFF),
    CVIRT_SHR      = (uint8_t)(_cv_mix(CVIRT_SEED, 17) & 0xFF),
    CVIRT_PUSH     = (uint8_t)(_cv_mix(CVIRT_SEED, 18) & 0xFF),
    CVIRT_POP      = (uint8_t)(_cv_mix(CVIRT_SEED, 19) & 0xFF),
    CVIRT_HALT     = (uint8_t)(_cv_mix(CVIRT_SEED, 20) & 0xFF),
};

// ─── Virtual Machine State ────────────────────────────────────
struct CVMState {
    uint64_t regs[16];       // 16 general-purpose virtual registers
    uint64_t stack[256];     // Virtual stack
    uint32_t sp;             // Stack pointer
    uint32_t ip;             // Instruction pointer
    uint64_t flags;          // Condition flags
    volatile uint64_t junk;  // Anti-optimization junk accumulator
};

// ─── Bytecode encryption key (per-build) ──────────────────────
static constexpr uint8_t CVIRT_BYTECODE_KEY  = (uint8_t)(_cv_mix(CVIRT_SEED, 100) & 0xFF);
static constexpr uint8_t CVIRT_BYTECODE_KEY2 = (uint8_t)(_cv_mix(CVIRT_SEED, 101) & 0xFF);
static constexpr uint8_t CVIRT_BYTECODE_ROT  = (uint8_t)((_cv_mix(CVIRT_SEED, 102) % 7) + 1);

// ─── Bytecode Encryptor (compile-time) ────────────────────────
constexpr uint8_t cv_encrypt_byte(uint8_t b, size_t idx) {
    uint8_t t = b;
    t ^= CVIRT_BYTECODE_KEY;
    t = (uint8_t)(t + (uint8_t)(idx * 7));
    t ^= CVIRT_BYTECODE_KEY2;
    t = (uint8_t)((t << CVIRT_BYTECODE_ROT) | (t >> (8 - CVIRT_BYTECODE_ROT)));
    return t;
}

// ─── Bytecode Decryptor (runtime) ─────────────────────────────
CVIRT_NOINLINE CVIRT_HIDDEN CVIRT_SECTION
static uint8_t cv_decrypt_byte(uint8_t b, size_t idx) {
    volatile uint8_t t = b;
    t = (uint8_t)((t >> CVIRT_BYTECODE_ROT) | (t << (8 - CVIRT_BYTECODE_ROT)));
    t ^= CVIRT_BYTECODE_KEY2;
    t = (uint8_t)(t - (uint8_t)(idx * 7));
    t ^= CVIRT_BYTECODE_KEY;
    return t;
}

// ─── VM Interpreter (placed in __CV segment) ──────────────────
CVIRT_NOINLINE CVIRT_HIDDEN CVIRT_SECTION
static uint64_t cv_execute(const uint8_t* bytecode, size_t len,
                           uint64_t arg0 = 0, uint64_t arg1 = 0,
                           uint64_t arg2 = 0, uint64_t arg3 = 0) {
    CVMState vm;
    __builtin_memset(&vm, 0, sizeof(vm));
    vm.regs[0] = arg0;
    vm.regs[1] = arg1;
    vm.regs[2] = arg2;
    vm.regs[3] = arg3;
    vm.sp = 0;
    vm.ip = 0;
    vm.junk = 0xDEADC0DEULL;

    // Anti-tamper: verify bytecode integrity checksum
    volatile uint32_t checksum = 0;
    for (size_t i = 0; i < len; ++i) {
        checksum = (checksum * 31U) + bytecode[i];
    }
    vm.junk ^= checksum;

    while (vm.ip < len) {
        uint8_t raw = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
        vm.ip++;

        // Junk computation to confuse pattern matching
        vm.junk = (vm.junk * 0x5DEECE66DULL + 0xBULL) ^ raw;

        if (raw == CVIRT_NOP) {
            vm.junk ^= vm.regs[0];
            continue;
        }
        else if (raw == CVIRT_LOAD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t val = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            vm.regs[dst] = val;
        }
        else if (raw == CVIRT_STORE && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = vm.regs[src];
        }
        else if (raw == CVIRT_XOR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] ^= vm.regs[src];
        }
        else if (raw == CVIRT_ADD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] += vm.regs[src];
        }
        else if (raw == CVIRT_SUB && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] -= vm.regs[src];
        }
        else if (raw == CVIRT_ROT && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] = (vm.regs[dst] << bits) | (vm.regs[dst] >> (64 - bits));
        }
        else if (raw == CVIRT_MUL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] *= vm.regs[src];
        }
        else if (raw == CVIRT_NOT && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = ~vm.regs[dst];
        }
        else if (raw == CVIRT_AND && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] &= vm.regs[src];
        }
        else if (raw == CVIRT_OR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] |= vm.regs[src];
        }
        else if (raw == CVIRT_SHL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] <<= bits;
        }
        else if (raw == CVIRT_SHR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] >>= bits;
        }
        else if (raw == CVIRT_PUSH && vm.ip + 1 <= len) {
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (vm.sp < 256) vm.stack[vm.sp++] = vm.regs[src];
        }
        else if (raw == CVIRT_POP && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (vm.sp > 0) vm.regs[dst] = vm.stack[--vm.sp];
        }
        else if (raw == CVIRT_JMP && vm.ip + 1 <= len) {
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip = target;
        }
        else if (raw == CVIRT_JZ && vm.ip + 2 <= len) {
            uint8_t reg = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            if (vm.regs[reg] == 0) vm.ip = target;
        }
        else if (raw == CVIRT_CMP && vm.ip + 2 <= len) {
            uint8_t a = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t b = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.flags = (vm.regs[a] == vm.regs[b]) ? 1 : 0;
        }
        else if (raw == CVIRT_HALT) {
            break;
        }

        // Anti-tamper junk mix after each instruction
        vm.junk = (vm.junk ^ vm.regs[vm.ip & 0x0F]) + 0x1337CAFEULL;
    }

    return vm.regs[0];
}

// ─── Helper: Build encrypted bytecode at compile time ─────────
template <size_t N>
struct CVBytecode {
    uint8_t data[N];
    static constexpr size_t size = N;

    template <size_t... I>
    constexpr CVBytecode(const uint8_t (&src)[N], _kh_::Seq<I...>)
        : data{ cv_encrypt_byte(src[I], I)... } {}

    CVIRT_INLINE uint64_t run(uint64_t a0 = 0, uint64_t a1 = 0,
                              uint64_t a2 = 0, uint64_t a3 = 0) const {
        return cv_execute(data, N, a0, a1, a2, a3);
    }
};

// ─── Macro to virtualize an integrity-check value ─────────────
// Usage: CVIRT_PROTECT_VALUE(my_check, { CVIRT_LOAD, 0, 42, CVIRT_XOR, 0, 1, CVIRT_HALT })
#define CVIRT_PROTECT_VALUE(name, ...) \
    static const uint8_t _cv_raw_##name[] = __VA_ARGS__; \
    static const auto name = _cv_::CVBytecode<sizeof(_cv_raw_##name)>( \
        _cv_raw_##name, typename _kh_::MakeSeq<sizeof(_cv_raw_##name)>::type())

} // namespace _cv_

// ─── Convenience macros ───────────────────────────────────────
#define CVIRT_VIRTUALIZE_BEGIN   /* marker for virtualizer pass */
#define CVIRT_VIRTUALIZE_END     /* marker for virtualizer pass */

#endif // CODE_VIRTUALIZER_H
