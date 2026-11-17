#pragma once
#include <cstdint>

namespace VnProfile {
// UnityFramework UUID for Free Fire VN 1.134.1 (build 2019121262).
inline constexpr uint8_t UnityUUID[16] = {
    0xe5, 0x0b, 0x0e, 0x3a, 0xd9, 0x31, 0x38, 0x5b,
    0x9e, 0x4c, 0x9f, 0xfd, 0xe6, 0xd1, 0xb9, 0x23
};

constexpr uint64_t Rva(uint64_t baseline) {
    switch (baseline) {
        case 0xBB46A50: return 0xBB4D150; // GameFacade metadata slot in CurrentMatch
        case 0x5616118: return 0x5617A14; // Player.GetWeaponOnHand
        case 0x5AC970C: return 0x5ACB12C; // Weapon manager getter called by GetWeaponOnHand
        case 0x5C59B94: return 0x5C5B5B8; // Common fire, virtual slot 17
        case 0x56A5F94: return 0x56A788C; // Player.get_AimStartPostion
        case 0x5C5D36C: return 0x5C5ED90; // Direction modifier, virtual slot 11
        case 0x5C5D370: return 0x5C5ED94; // Modifier fingerprint starts after first instruction
        default: return 0;
    }
}

constexpr uint32_t Hash(uint32_t baseline) {
    switch (baseline) {
        case 0xC5E012EE: return 0xAB912477;
        case 0x93FD3984: return 0x30BA7C3C;
        case 0xDFE8FAC6: return 0x0E24739C;
        case 0xA1643E14: return 0x4F82305F;
        case 0x10B69D75: return 0xC43ECED8;
        default: return 0;
    }
}
}
