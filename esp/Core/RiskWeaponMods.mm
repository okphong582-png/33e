#include "RiskWeaponMods.h"
#include "RiskField.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <cmath>

// Experimental, UNVERIFIED layouts. The supplied offsets do not establish
// their owning types. These checks reject implausible data, not wrong layouts.
// Hypotheses: PlayerAttributes+0xD9 is a boolean, Weapon+0x208 a float interval.
static RiskField<uint8_t> reloadField;
static RiskField<float> fireField;
static uint64_t lastMatch = 0, lastPlayer = 0;
static mach_port_t lastTask = MACH_PORT_NULL;

template<class T, class Valid, class Modify>
static void TickField(RiskField<T> &field, uint64_t player, uint64_t parentOffset,
                      uint64_t fieldOffset, bool enabled, Valid valid, Modify modify) {
    if (!enabled && !field.changed) return;
    uint64_t object = ReadAddr<uint64_t>(player + parentOffset);
    if (!isVaildPtr(object)) object = 0;
    field.update(object, enabled,
        [&](T &v) { return _read((long)(object + fieldOffset), &v, sizeof(T)); },
        [&](T v) {
            if (ReadAddr<uint64_t>(player + parentOffset) != object) return false;
            return WriteAddr<T>(object + fieldOffset, v);
        }, valid, modify);
}

void RiskWeaponUpdate(uint64_t match, uint64_t player, bool noReload, bool fastFire) {
    if (match != lastMatch || player != lastPlayer || get_task != lastTask) {
        reloadField.forget(); fireField.forget();
        lastMatch = match; lastPlayer = player; lastTask = get_task;
    }
    if (!isVaildPtr(player) || !isVaildPtr(match)) return;
    TickField(reloadField, player, kPlayerAttributes, kShootNoReload, noReload,
        [](uint8_t value) { return value <= 1; },
        [](uint8_t) { return uint8_t(1); });
    TickField(fireField, player, kWeaponOnHand, kFastFireOff, fastFire,
        [](float value) { return std::isfinite(value) && value >= 0.04f && value <= 5.0f; },
        [](float value) { return value * 0.5f; });
}

void RiskWeaponStop() {
    // Restore only if the same live match still owns the same local player.
    if (get_task == lastTask && isVaildPtr(lastMatch) &&
        getLocalPlayer(lastMatch) == lastPlayer) {
        RiskWeaponUpdate(lastMatch, lastPlayer, false, false);
    }
    reloadField.forget(); fireField.forget();
    lastMatch = lastPlayer = 0;
}
