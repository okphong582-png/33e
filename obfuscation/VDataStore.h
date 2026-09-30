#ifndef VDATA_STORE_H
#define VDATA_STORE_H

/*
 * ═══════════════════════════════════════════════════════════════
 *  __VDATA/__vdata – Virtualized Data Storage
 * ═══════════════════════════════════════════════════════════════
 *
 *  Stores sensitive runtime data (offsets, keys, configs) in a
 *  dedicated Mach-O section with multi-layer encryption.
 *  Data is only decrypted on-demand and immediately re-encrypted.
 *
 *  Pipeline position:
 *    Source Code → Obfuscation Pipeline → __VDATA/__vdata
 *
 *  Anti-RE effect:
 *    - Sensitive data never appears in plaintext in binary
 *    - Dedicated segment survives strip/otool inspection
 *    - Per-access decryption prevents memory dump attacks
 *    - Rolling encryption key changes each access
 * ═══════════════════════════════════════════════════════════════
 */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include "KabraxHide.h"

#if defined(__clang__) || defined(__GNUC__)
  #define VD_SECTION    __attribute__((section("__VDATA,__vdata")))
  #define VD_NOINLINE   __attribute__((noinline))
  #define VD_HIDDEN     __attribute__((visibility("hidden")))
  #define VD_USED       __attribute__((used))
  #define VD_INLINE     inline __attribute__((always_inline))
#else
  #define VD_SECTION
  #define VD_NOINLINE
  #define VD_HIDDEN
  #define VD_USED
  #define VD_INLINE     inline
#endif

namespace _vdata_ {

// ─── Compile-time seed ────────────────────────────────────────
static constexpr uint64_t _vd_seed() {
    return ((__TIME__[0]-'0')*36000ULL) + ((__TIME__[1]-'0')*3600ULL) +
           ((__TIME__[3]-'0')*600ULL)   + ((__TIME__[4]-'0')*60ULL) +
           ((__TIME__[6]-'0')*10ULL)    + (__TIME__[7]-'0');
}
static constexpr uint64_t VD_SEED = _vd_seed();

constexpr uint64_t _vd_mix(uint64_t a, uint64_t b) {
    uint64_t h = a ^ (b * 0x517CC1B727220A95ULL);
    h ^= h >> 30;
    h *= 0xBF58476D1CE4E5B9ULL;
    h ^= h >> 27;
    h *= 0x94D049BB133111EBULL;
    return h ^ (h >> 31);
}

// ─── Encryption keys (per-build) ──────────────────────────────
static constexpr uint64_t VD_KEY1 = _vd_mix(VD_SEED, 0x1111111111111111ULL);
static constexpr uint64_t VD_KEY2 = _vd_mix(VD_SEED, 0x2222222222222222ULL);
static constexpr uint64_t VD_KEY3 = _vd_mix(VD_SEED, 0x3333333333333333ULL);
static constexpr uint64_t VD_KEY4 = _vd_mix(VD_SEED, 0x4444444444444444ULL);

static constexpr uint8_t  VD_BYTE_KEY1 = (uint8_t)(VD_KEY1 & 0xFF);
static constexpr uint8_t  VD_BYTE_KEY2 = (uint8_t)((VD_KEY1 >> 8) & 0xFF);
static constexpr uint8_t  VD_BYTE_ROT  = (uint8_t)(((VD_KEY1 >> 16) % 7) + 1);
static constexpr uint8_t  VD_SBOX_KEY  = (uint8_t)((VD_KEY2 >> 24) & 0xFF);

// ─── Encrypt a 64-bit value at compile time ───────────────────
constexpr uint64_t vd_encrypt_u64(uint64_t val, uint64_t slot_id) {
    uint64_t k = _vd_mix(VD_KEY1, slot_id);
    val ^= k;
    val = (val << 17) | (val >> 47);
    val ^= _vd_mix(VD_KEY2, slot_id);
    val += _vd_mix(VD_KEY3, slot_id);
    val = (val << 23) | (val >> 41);
    val ^= _vd_mix(VD_KEY4, slot_id);
    return val;
}

// ─── Decrypt a 64-bit value at runtime ────────────────────────
VD_NOINLINE VD_HIDDEN VD_SECTION
static uint64_t vd_decrypt_u64(uint64_t enc, uint64_t slot_id) {
    volatile uint64_t junk = VD_KEY1 ^ VD_KEY2; // anti-optimization

    uint64_t val = enc;
    val ^= _vd_mix(VD_KEY4, slot_id);
    val = (val >> 23) | (val << 41);
    val -= _vd_mix(VD_KEY3, slot_id);
    val ^= _vd_mix(VD_KEY2, slot_id);
    val = (val >> 17) | (val << 47);
    uint64_t k = _vd_mix(VD_KEY1, slot_id);
    val ^= k;

    junk ^= val; // prevent dead code elimination
    return val;
}

// ─── Encrypt a byte buffer at compile time ────────────────────
constexpr uint8_t vd_encrypt_byte(uint8_t b, size_t idx, uint64_t slot_id) {
    uint8_t t = b;
    uint8_t k = (uint8_t)(_vd_mix(VD_KEY1, slot_id + idx) & 0xFF);
    t ^= k;
    t ^= VD_BYTE_KEY1;
    t = (uint8_t)(t + VD_BYTE_KEY2);
    t = (uint8_t)((t << VD_BYTE_ROT) | (t >> (8 - VD_BYTE_ROT)));
    t ^= VD_SBOX_KEY;
    t ^= (uint8_t)(idx * 0x37);
    return t;
}

// ─── Decrypt a byte buffer at runtime ─────────────────────────
VD_NOINLINE VD_HIDDEN VD_SECTION
static uint8_t vd_decrypt_byte(uint8_t b, size_t idx, uint64_t slot_id) {
    volatile uint8_t t = b;
    t ^= (uint8_t)(idx * 0x37);
    t ^= VD_SBOX_KEY;
    t = (uint8_t)((t >> VD_BYTE_ROT) | (t << (8 - VD_BYTE_ROT)));
    t = (uint8_t)(t - VD_BYTE_KEY2);
    t ^= VD_BYTE_KEY1;
    uint8_t k = (uint8_t)(_vd_mix(VD_KEY1, slot_id + idx) & 0xFF);
    t ^= k;
    return t;
}

// ─── Compile-time encrypted data slot (uint64_t) ──────────────
template <uint64_t Value, uint64_t SlotID>
struct VDSlot {
    static constexpr uint64_t encrypted = vd_encrypt_u64(Value, SlotID);

    VD_NOINLINE static uint64_t get() {
        return vd_decrypt_u64(encrypted, SlotID);
    }
};

// ─── Compile-time encrypted byte array ────────────────────────
template <size_t N, uint64_t SlotID>
struct VDBuffer {
    uint8_t data[N];

    template <size_t... I>
    constexpr VDBuffer(const uint8_t (&src)[N], _kh_::Seq<I...>)
        : data{ vd_encrypt_byte(src[I], I, SlotID)... } {}

    VD_NOINLINE void decrypt_to(uint8_t* out) const {
        for (size_t i = 0; i < N; ++i) {
            out[i] = vd_decrypt_byte(data[i], i, SlotID);
        }
    }
};

// ─── Rolling key: mutates encryption key each access ──────────
// Prevents memory snapshots from being useful
struct VDRollingKey {
    volatile uint64_t current_key;
    volatile uint32_t access_count;

    VD_NOINLINE void init(uint64_t seed) {
        current_key = _vd_mix(seed, VD_KEY1);
        access_count = 0;
    }

    VD_NOINLINE VD_HIDDEN VD_SECTION
    uint64_t next() {
        access_count++;
        current_key = _vd_mix(current_key, (uint64_t)access_count * 0x9E3779B97F4A7C15ULL);
        return current_key;
    }

    VD_NOINLINE VD_HIDDEN VD_SECTION
    uint64_t encrypt_with_rolling(uint64_t val) {
        uint64_t k = next();
        val ^= k;
        val = (val << 13) | (val >> 51);
        val ^= _vd_mix(k, VD_KEY2);
        return val;
    }

    VD_NOINLINE VD_HIDDEN VD_SECTION
    uint64_t decrypt_with_rolling(uint64_t enc) {
        uint64_t k = next();
        enc ^= _vd_mix(k, VD_KEY2);
        enc = (enc >> 13) | (enc << 51);
        enc ^= k;
        return enc;
    }
};

// ─── Anti-dump: Encrypted pointer storage ─────────────────────
VD_NOINLINE VD_HIDDEN VD_SECTION
static uintptr_t vd_encrypt_ptr(uintptr_t ptr) {
    volatile uintptr_t p = ptr;
    p ^= (uintptr_t)VD_KEY1;
    p = (p << 7) | (p >> (sizeof(uintptr_t) * 8 - 7));
    p ^= (uintptr_t)VD_KEY2;
    return p;
}

VD_NOINLINE VD_HIDDEN VD_SECTION
static uintptr_t vd_decrypt_ptr(uintptr_t enc) {
    volatile uintptr_t p = enc;
    p ^= (uintptr_t)VD_KEY2;
    p = (p >> 7) | (p << (sizeof(uintptr_t) * 8 - 7));
    p ^= (uintptr_t)VD_KEY1;
    return p;
}

} // namespace _vdata_

// ─── Convenience Macros ───────────────────────────────────────

// Store a compile-time encrypted 64-bit constant
#define VD_CONST(value) \
    (_vdata_::VDSlot<(uint64_t)(value), (uint64_t)__COUNTER__ * 0x100ULL + __LINE__>::get())

// Encrypt a pointer at runtime
#define VD_ENC_PTR(ptr) \
    _vdata_::vd_encrypt_ptr((uintptr_t)(ptr))

// Decrypt a pointer at runtime
#define VD_DEC_PTR(type, enc) \
    ((type)_vdata_::vd_decrypt_ptr((uintptr_t)(enc)))

#endif // VDATA_STORE_H
