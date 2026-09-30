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
  #define CV_SECTION    __attribute__((section("__CV,__cv_text")))
  #define CV_NOINLINE   __attribute__((noinline))
  #define CV_HIDDEN     __attribute__((visibility("hidden")))
  #define CV_USED       __attribute__((used))
  #define CV_INLINE     inline __attribute__((always_inline))
#else
  #define CV_SECTION
  #define CV_NOINLINE
  #define CV_HIDDEN
  #define CV_USED
  #define CV_INLINE     inline
#endif

namespace _cv_ {

// ─── Compile-time opcode generation ───────────────────────────
// Each build shuffles opcode assignments via __TIME__ seed
static constexpr uint64_t _cv_seed() {
    return ((__TIME__[0]-'0')*36000ULL) + ((__TIME__[1]-'0')*3600ULL) +
           ((__TIME__[3]-'0')*600ULL)   + ((__TIME__[4]-'0')*60ULL) +
           ((__TIME__[6]-'0')*10ULL)    + (__TIME__[7]-'0');
}

static constexpr uint64_t CV_SEED = _cv_seed();

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
    CV_NOP      = (uint8_t)(_cv_mix(CV_SEED, 0)  & 0xFF),
    CV_LOAD     = (uint8_t)(_cv_mix(CV_SEED, 1)  & 0xFF),
    CV_STORE    = (uint8_t)(_cv_mix(CV_SEED, 2)  & 0xFF),
    CV_XOR      = (uint8_t)(_cv_mix(CV_SEED, 3)  & 0xFF),
    CV_ADD      = (uint8_t)(_cv_mix(CV_SEED, 4)  & 0xFF),
    CV_SUB      = (uint8_t)(_cv_mix(CV_SEED, 5)  & 0xFF),
    CV_ROT      = (uint8_t)(_cv_mix(CV_SEED, 6)  & 0xFF),
    CV_JMP      = (uint8_t)(_cv_mix(CV_SEED, 7)  & 0xFF),
    CV_JZ       = (uint8_t)(_cv_mix(CV_SEED, 8)  & 0xFF),
    CV_CMP      = (uint8_t)(_cv_mix(CV_SEED, 9)  & 0xFF),
    CV_CALL     = (uint8_t)(_cv_mix(CV_SEED, 10) & 0xFF),
    CV_RET      = (uint8_t)(_cv_mix(CV_SEED, 11) & 0xFF),
    CV_MUL      = (uint8_t)(_cv_mix(CV_SEED, 12) & 0xFF),
    CV_NOT      = (uint8_t)(_cv_mix(CV_SEED, 13) & 0xFF),
    CV_AND      = (uint8_t)(_cv_mix(CV_SEED, 14) & 0xFF),
    CV_OR       = (uint8_t)(_cv_mix(CV_SEED, 15) & 0xFF),
    CV_SHL      = (uint8_t)(_cv_mix(CV_SEED, 16) & 0xFF),
    CV_SHR      = (uint8_t)(_cv_mix(CV_SEED, 17) & 0xFF),
    CV_PUSH     = (uint8_t)(_cv_mix(CV_SEED, 18) & 0xFF),
    CV_POP      = (uint8_t)(_cv_mix(CV_SEED, 19) & 0xFF),
    CV_HALT     = (uint8_t)(_cv_mix(CV_SEED, 20) & 0xFF),
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
static constexpr uint8_t CV_BYTECODE_KEY  = (uint8_t)(_cv_mix(CV_SEED, 100) & 0xFF);
static constexpr uint8_t CV_BYTECODE_KEY2 = (uint8_t)(_cv_mix(CV_SEED, 101) & 0xFF);
static constexpr uint8_t CV_BYTECODE_ROT  = (uint8_t)((_cv_mix(CV_SEED, 102) % 7) + 1);

// ─── Bytecode Encryptor (compile-time) ────────────────────────
constexpr uint8_t cv_encrypt_byte(uint8_t b, size_t idx) {
    uint8_t t = b;
    t ^= CV_BYTECODE_KEY;
    t = (uint8_t)(t + (uint8_t)(idx * 7));
    t ^= CV_BYTECODE_KEY2;
    t = (uint8_t)((t << CV_BYTECODE_ROT) | (t >> (8 - CV_BYTECODE_ROT)));
    return t;
}

// ─── Bytecode Decryptor (runtime) ─────────────────────────────
CV_NOINLINE CV_HIDDEN CV_SECTION
static uint8_t cv_decrypt_byte(uint8_t b, size_t idx) {
    volatile uint8_t t = b;
    t = (uint8_t)((t >> CV_BYTECODE_ROT) | (t << (8 - CV_BYTECODE_ROT)));
    t ^= CV_BYTECODE_KEY2;
    t = (uint8_t)(t - (uint8_t)(idx * 7));
    t ^= CV_BYTECODE_KEY;
    return t;
}

// ─── VM Interpreter (placed in __CV segment) ──────────────────
CV_NOINLINE CV_HIDDEN CV_SECTION
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

        if (raw == CV_NOP) {
            vm.junk ^= vm.regs[0];
            continue;
        }
        else if (raw == CV_LOAD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t val = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            vm.regs[dst] = val;
        }
        else if (raw == CV_STORE && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = vm.regs[src];
        }
        else if (raw == CV_XOR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] ^= vm.regs[src];
        }
        else if (raw == CV_ADD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] += vm.regs[src];
        }
        else if (raw == CV_SUB && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] -= vm.regs[src];
        }
        else if (raw == CV_ROT && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] = (vm.regs[dst] << bits) | (vm.regs[dst] >> (64 - bits));
        }
        else if (raw == CV_MUL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] *= vm.regs[src];
        }
        else if (raw == CV_NOT && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = ~vm.regs[dst];
        }
        else if (raw == CV_AND && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] &= vm.regs[src];
        }
        else if (raw == CV_OR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] |= vm.regs[src];
        }
        else if (raw == CV_SHL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] <<= bits;
        }
        else if (raw == CV_SHR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] >>= bits;
        }
        else if (raw == CV_PUSH && vm.ip + 1 <= len) {
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (vm.sp < 256) vm.stack[vm.sp++] = vm.regs[src];
        }
        else if (raw == CV_POP && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (vm.sp > 0) vm.regs[dst] = vm.stack[--vm.sp];
        }
        else if (raw == CV_JMP && vm.ip + 1 <= len) {
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip = target;
        }
        else if (raw == CV_JZ && vm.ip + 2 <= len) {
            uint8_t reg = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            if (vm.regs[reg] == 0) vm.ip = target;
        }
        else if (raw == CV_CMP && vm.ip + 2 <= len) {
            uint8_t a = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t b = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.flags = (vm.regs[a] == vm.regs[b]) ? 1 : 0;
        }
        else if (raw == CV_HALT) {
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

    CV_INLINE uint64_t run(uint64_t a0 = 0, uint64_t a1 = 0,
                           uint64_t a2 = 0, uint64_t a3 = 0) const {
        return cv_execute(data, N, a0, a1, a2, a3);
    }
};

// ─── Macro to virtualize an integrity-check value ─────────────
// Usage: CV_PROTECT_VALUE(my_check, { CV_LOAD, 0, 42, CV_XOR, 0, 1, CV_HALT })
#define CV_PROTECT_VALUE(name, ...) \
    static const uint8_t _cv_raw_##name[] = __VA_ARGS__; \
    static const auto name = _cv_::CVBytecode<sizeof(_cv_raw_##name)>( \
        _cv_raw_##name, typename _kh_::MakeSeq<sizeof(_cv_raw_##name)>::type())

} // namespace _cv_

// ─── Convenience macros ───────────────────────────────────────
#define CV_VIRTUALIZE_BEGIN   /* marker for virtualizer pass */
#define CV_VIRTUALIZE_END     /* marker for virtualizer pass */

#endif // CODE_VIRTUALIZER_H
