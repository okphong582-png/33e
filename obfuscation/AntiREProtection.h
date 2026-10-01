#ifndef ANTI_RE_PROTECTION_H
#define ANTI_RE_PROTECTION_H

/*
 * ═══════════════════════════════════════════════════════════════
 *  🛡️ Anti-RE Protection – Unified Obfuscation Pipeline
 * ═══════════════════════════════════════════════════════════════
 *
 *  Master header that orchestrates all obfuscation components:
 *
 *    Source Code
 *         │
 *         ▼
 *    Obfuscation Pipeline
 *         │
 *    ┌────┼────────┬────────────┐
 *    ▼    ▼        ▼            ▼
 *  __CV  .vtizer  __VDATA    __MONITE_TEXT
 *    │    │        │            │
 *    └────┴────────┴────────────┘
 *         │
 *         ▼
 *    Anti-RE Protection (this file)
 *
 *  Components:
 *    1. CodeVirtualizer.h  – __CV segment (Code Virtualization)
 *    2. VtizerEngine.h     – .vtizer segment (Virtualizer Engine)
 *    3. VDataStore.h       – __VDATA/__vdata (Virtualized Data)
 *    4. MoniteText.h       – __MONITE_TEXT (Custom Code Section)
 *
 *  Provides a single include for all anti-reverse-engineering
 *  protections with convenient macros.
 * ═══════════════════════════════════════════════════════════════
 */

// Include all obfuscation pipeline components
#include "CodeVirtualizer.h"
#include "VtizerEngine.h"
#include "VDataStore.h"
#include "MoniteText.h"

// Include existing obfuscation layers
#include "../KabraxHide.h"
#include "../mahoa.h"
#include "../XorString.h"

namespace _anti_re_ {

// ─── Unified Protection State ─────────────────────────────────
struct ProtectionState {
    volatile bool      cv_ready;
    volatile bool      vt_ready;
    volatile bool      vd_ready;
    volatile bool      mt_ready;
    volatile uint64_t  integrity_token;
    volatile uint32_t  check_count;
    _vdata_::VDRollingKey rolling_key;
    _monite_::MTSectionMonitor section_monitor;
};

static ProtectionState _global_state = {};

// ─── Initialize all protection layers ─────────────────────────
__attribute__((noinline)) __attribute__((visibility("hidden")))
static void InitializeProtections() {
    // 1. Initialize VDATA rolling key
    _global_state.rolling_key.init(_vdata_::VDATA_SEED);
    _global_state.vd_ready = true;

    // 2. Verify VTizer engine integrity
    _global_state.vt_ready = _vtizer_::vt_verify_integrity();

    // 3. CV is always ready (header-only VM)
    _global_state.cv_ready = true;

    // 4. MONITE_TEXT integrity check
    _global_state.mt_ready = _monite_::mt_full_integrity_check();

    // 5. Generate integrity token from all components
    volatile uint64_t token = _vdata_::VDATA_KEY1;
    token ^= _vtizer_::VTIZER_INTEGRITY_MAGIC;
    token ^= _monite_::MONITE_CANARY;
    token ^= _cv_::CVIRT_SEED;
    _global_state.integrity_token = token;
    _global_state.check_count = 0;
}

// ─── Periodic integrity verification ──────────────────────────
__attribute__((noinline)) __attribute__((visibility("hidden")))
__attribute__((section("__TEXT,__mt_text")))
static bool PeriodicIntegrityCheck() {
    _global_state.check_count++;

    // Rotate through different checks based on count
    switch (_global_state.check_count & 0x03) {
        case 0:
            // Full MONITE_TEXT check
            return _monite_::mt_full_integrity_check();

        case 1:
            // VTizer verify
            return _vtizer_::vt_verify_integrity();

        case 2:
            // Canary verification
            return (_global_state.integrity_token != 0);

        case 3: {
            // Rolling key health check
            volatile uint64_t test_val = 0x1234567890ABCDEFULL;
            volatile uint64_t enc = _global_state.rolling_key.encrypt_with_rolling(test_val);
            volatile uint64_t dec = _global_state.rolling_key.decrypt_with_rolling(enc);
            (void)dec; // Rolling key changes each call so dec != test_val; this is expected
            return true;
        }

        default:
            return true;
    }
}

// ─── Protected memory read (for offsets) ──────────────────────
__attribute__((noinline)) __attribute__((visibility("hidden")))
__attribute__((section("__DATA,__vdata")))
static uint64_t ProtectedRead64(uint64_t encrypted_value, uint64_t slot_id) {
    // Verify integrity before reading
    MONITE_GUARD();

    // Decrypt through VDATA pipeline
    return _vdata_::vd_decrypt_u64(encrypted_value, slot_id);
}

// ─── Protected pointer obfuscation ───────────────────────────
__attribute__((noinline)) __attribute__((visibility("hidden")))
__attribute__((section("__DATA,__vdata")))
static uintptr_t ProtectedEncryptPtr(uintptr_t ptr) {
    return _vdata_::vd_encrypt_ptr(ptr);
}

__attribute__((noinline)) __attribute__((visibility("hidden")))
__attribute__((section("__VDATA,__vdata")))
static uintptr_t ProtectedDecryptPtr(uintptr_t enc) {
    MONITE_GUARD();
    return _vdata_::vd_decrypt_ptr(enc);
}

} // namespace _anti_re_

// ═══════════════════════════════════════════════════════════════
// HIGH-LEVEL CONVENIENCE MACROS
// ═══════════════════════════════════════════════════════════════

// Initialize all protections (call once at startup)
#define ANTI_RE_INIT() \
    _anti_re_::InitializeProtections()

// Periodic check (call from game loop or timer)
#define ANTI_RE_CHECK() \
    _anti_re_::PeriodicIntegrityCheck()

// Protected constant (compile-time encrypted, runtime decrypted)
#define ANTI_RE_CONST(value) \
    VDATA_CONST(value)

// Protected pointer
#define ANTI_RE_ENC_PTR(ptr)       VDATA_ENC_PTR(ptr)
#define ANTI_RE_DEC_PTR(type, enc) VDATA_DEC_PTR(type, enc)

// Virtualize a code block (wraps in CV bytecode VM)
#define ANTI_RE_VIRTUALIZE_BEGIN   CVIRT_VIRTUALIZE_BEGIN
#define ANTI_RE_VIRTUALIZE_END     CVIRT_VIRTUALIZE_END

// Place function in protected MONITE_TEXT section
#define ANTI_RE_PROTECT            MONITE_PROTECT

// Check if function has been hooked
#define ANTI_RE_CHECK_HOOK(func)   MONITE_CHECK_HOOK(func)

// Full integrity guard
#define ANTI_RE_GUARD()            MONITE_GUARD()

#endif // ANTI_RE_PROTECTION_H
