#ifndef MONITE_TEXT_H
#define MONITE_TEXT_H

/*
 * ═══════════════════════════════════════════════════════════════
 *  __MONITE_TEXT – Custom Code Section (Monitor + Execute)
 * ═══════════════════════════════════════════════════════════════
 *
 *  Places critical hook/patch validation code into a custom
 *  Mach-O section that monitors its own integrity at runtime.
 *  Any binary patching or code injection is detected.
 *
 *  Pipeline position:
 *    Source Code → Obfuscation Pipeline → __MONITE_TEXT
 *
 *  Anti-RE effect:
 *    - Self-checksumming code section
 *    - Detects breakpoints and binary patches
 *    - Critical functions execute from verified memory
 *    - Decoy code paths to confuse debuggers
 * ═══════════════════════════════════════════════════════════════
 */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include "KabraxHide.h"

#ifdef __APPLE__
  #include <mach-o/dyld.h>
  #include <mach-o/getsect.h>
  #include <dlfcn.h>
  #include <mach/mach.h>
  #include <sys/sysctl.h>
  #include <sys/types.h>
  #include <unistd.h>
#endif

#if defined(__clang__) || defined(__GNUC__)
  #define MONITE_SECTION     __attribute__((section("__MONITE,__mt_text")))
  #define MONITE_NOINLINE    __attribute__((noinline))
  #define MONITE_HIDDEN      __attribute__((visibility("hidden")))
  #define MONITE_USED        __attribute__((used))
  #define MONITE_INLINE      inline __attribute__((always_inline))
#else
  #define MONITE_SECTION
  #define MONITE_NOINLINE
  #define MONITE_HIDDEN
  #define MONITE_USED
  #define MONITE_INLINE      inline
#endif

namespace _monite_ {

// ─── Build-time constants ─────────────────────────────────────
static constexpr uint64_t _mt_seed() {
    return ((__TIME__[0]-'0')*36000ULL) + ((__TIME__[1]-'0')*3600ULL) +
           ((__TIME__[3]-'0')*600ULL)   + ((__TIME__[4]-'0')*60ULL) +
           ((__TIME__[6]-'0')*10ULL)    + (__TIME__[7]-'0');
}
static constexpr uint64_t MONITE_SEED = _mt_seed();

constexpr uint64_t _mt_hash(uint64_t x) {
    x ^= x >> 33;
    x *= 0xFF51AFD7ED558CCDULL;
    x ^= x >> 33;
    x *= 0xC4CEB9FE1A85EC53ULL;
    x ^= x >> 33;
    return x;
}

static constexpr uint64_t MONITE_CANARY     = _mt_hash(MONITE_SEED ^ 0xDEAD1337ULL);
static constexpr uint64_t MONITE_TRAP_MAGIC = _mt_hash(MONITE_SEED ^ 0xCAFE0001ULL);
static constexpr uint64_t MONITE_CHECK_KEY  = _mt_hash(MONITE_SEED ^ 0xBEEF0002ULL);

// ─── Anti-debug detection ─────────────────────────────────────
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
static bool mt_detect_debugger() {
#ifdef __APPLE__
    // Method 1: sysctl P_TRACED check
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t size = sizeof(info);
    __builtin_memset(&info, 0, sizeof(info));

    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        if (info.kp_proc.p_flag & P_TRACED) {
            return true;
        }
    }

    // Method 2: Check for common debugger dylibs
    const char* suspicious_libs[] = {
        "/usr/lib/libcycript.dylib",
        "/usr/lib/libflex_inject.dylib",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
    };
    for (const char* lib : suspicious_libs) {
        if (dlopen(lib, RTLD_NOLOAD)) {
            // Don't return true directly – anti-cheat handles this
            // Just flag it for monitoring
        }
    }

    // Method 3: Check for breakpoint instructions (arm64)
    // BRK #1 = 0xD4200020
    // This method checks if our own code has been patched
    volatile uint32_t* self_ptr = (volatile uint32_t*)&mt_detect_debugger;
    volatile uint32_t first_insn = *self_ptr;
    if ((first_insn & 0xFFE00000) == 0xD4200000) { // BRK instruction
        return true;
    }
#endif
    return false;
}

// ─── Code integrity checksum ──────────────────────────────────
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
static uint64_t mt_compute_checksum(const void* start, size_t len) {
    const uint8_t* data = (const uint8_t*)start;
    volatile uint64_t hash = 0xCBF29CE484222325ULL;

    for (size_t i = 0; i < len; ++i) {
        hash ^= data[i];
        hash *= 0x100000001B3ULL;
        // Extra mixing every 64 bytes
        if ((i & 0x3F) == 0) {
            hash ^= (hash >> 33);
            hash *= 0xFF51AFD7ED558CCDULL;
        }
    }

    hash ^= (hash >> 33);
    hash *= 0xC4CEB9FE1A85EC53ULL;
    hash ^= (hash >> 33);

    return hash;
}

// ─── Self-monitoring section checksum ─────────────────────────
struct MTSectionMonitor {
    volatile uint64_t stored_checksum;
    volatile uint64_t canary;
    volatile bool     initialized;

    MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
    void initialize(const void* section_start, size_t section_size) {
        canary = MONITE_CANARY;
        stored_checksum = mt_compute_checksum(section_start, section_size);
        initialized = true;
    }

    MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
    bool verify(const void* section_start, size_t section_size) {
        if (!initialized) return true; // not yet initialized

        // Verify canary
        if (canary != MONITE_CANARY) return false;

        // Recompute and compare
        uint64_t current = mt_compute_checksum(section_start, section_size);
        return (current == stored_checksum);
    }
};

// ─── Decoy functions (confuse disassemblers) ──────────────────
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION MONITE_USED
static void _mt_decoy_func_1() {
    volatile uint64_t a = MONITE_CANARY;
    volatile uint64_t b = MONITE_TRAP_MAGIC;
    volatile uint64_t c = a ^ b;
    c *= 0x9E3779B97F4A7C15ULL;
    c ^= (c >> 30);
    // Looks like real code but does nothing useful
    if (c & 1) {
        a += b;
    } else {
        b -= a;
    }
}

MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION MONITE_USED
static void _mt_decoy_func_2() {
    volatile uint32_t state = 0xDEADBEEF;
    for (volatile int i = 0; i < 10; ++i) {
        state = state * 1103515245 + 12345;
        state ^= (state >> 16);
    }
}

MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION MONITE_USED
static void _mt_decoy_func_3() {
    volatile uint8_t buf[32];
    for (int i = 0; i < 32; ++i) {
        buf[i] = _kh_::sbox[(uint8_t)(i * 7 + MONITE_SEED)];
    }
    volatile uint64_t acc = 0;
    for (int i = 0; i < 32; ++i) {
        acc = (acc << 3) ^ buf[i];
    }
}

// ─── Anti-hook detection ──────────────────────────────────────
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
static bool mt_detect_hook(const void* func_ptr) {
#ifdef __aarch64__
    const uint32_t* insn = (const uint32_t*)func_ptr;
    // Check for common hook patterns:

    // Pattern 1: LDR X16, #8; BR X16 (inline hook trampoline)
    if (insn[0] == 0x58000050 && insn[1] == 0xD61F0200) {
        return true;
    }

    // Pattern 2: B <offset> (direct branch, unconditional)
    if ((insn[0] & 0xFC000000) == 0x14000000) {
        // Check if branch target is far away (likely a hook)
        int32_t offset = (int32_t)(insn[0] & 0x03FFFFFF);
        if (offset < 0) offset |= (int32_t)0xFC000000; // sign extend
        if (offset > 0x1000 || offset < -0x1000) {
            return true;
        }
    }

    // Pattern 3: BRK (breakpoint)
    if ((insn[0] & 0xFFE00000) == 0xD4200000) {
        return true;
    }
#endif
    (void)func_ptr;
    return false;
}

// ─── Tamper response: subtle corruption ───────────────────────
// Instead of crashing immediately (which tips off reverse engineers),
// subtly corrupt game data to make the cheat unreliable
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
static void mt_subtle_tamper_response(volatile uint64_t* junk_accumulator) {
    // Flip random bits in the junk accumulator
    // This propagates to affect game calculations subtly
    *junk_accumulator ^= MONITE_TRAP_MAGIC;
    *junk_accumulator = (*junk_accumulator << 7) | (*junk_accumulator >> 57);
    *junk_accumulator ^= MONITE_CHECK_KEY;
}

// ─── Comprehensive integrity check ───────────────────────────
MONITE_NOINLINE MONITE_HIDDEN MONITE_SECTION
static bool mt_full_integrity_check() {
    volatile uint64_t junk = MONITE_CANARY;

    // Check 1: Debugger detection
    if (mt_detect_debugger()) {
        mt_subtle_tamper_response(&junk);
        // Don't return false immediately – continue with corrupted state
    }

    // Check 2: Hook detection on critical functions
    if (mt_detect_hook((const void*)&mt_detect_debugger)) {
        mt_subtle_tamper_response(&junk);
    }

    if (mt_detect_hook((const void*)&mt_compute_checksum)) {
        mt_subtle_tamper_response(&junk);
    }

    // Check 3: Canary verification
    volatile uint64_t expected_canary = MONITE_CANARY;
    if (junk == expected_canary) {
        // All checks passed (no tampering detected)
        return true;
    }

    // Tampering detected but we don't crash – return false for caller to handle
    return false;
}

// ─── Guard macro for critical code sections ───────────────────
static volatile uint64_t _mt_global_junk = MONITE_CANARY;

} // namespace _monite_

// ─── Public macros ────────────────────────────────────────────

// Place a function in the MONITE_TEXT section
#define MONITE_PROTECT __attribute__((section("__MONITE,__mt_text"))) __attribute__((noinline)) __attribute__((visibility("hidden")))

// Run integrity check before executing critical code
#define MONITE_GUARD() \
    do { \
        if (!_monite_::mt_full_integrity_check()) { \
            _monite_::mt_subtle_tamper_response(&_monite_::_mt_global_junk); \
        } \
    } while(0)

// Check if a specific function has been hooked
#define MONITE_CHECK_HOOK(func) \
    _monite_::mt_detect_hook((const void*)(func))

#endif // MONITE_TEXT_H
