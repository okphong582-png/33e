#pragma once
#include <cstdint>

// Best-effort restoration: never write a remembered value into a new object
// or overwrite a value that the game changed after our patch.
template<class T> struct RiskField {
    uint64_t object = 0;
    T original{}, applied{};
    bool changed = false;
    void forget() { object = 0; changed = false; }
    template<class Read, class Write, class Valid, class Modify>
    void update(uint64_t current, bool enabled, Read read, Write write, Valid valid, Modify modify) {
        if (object != current) { forget(); object = current; }
        if (!current || (!enabled && !changed)) return;
        T value{};
        if (!read(value)) return;
        if (!enabled) {
            if (value != applied || write(original)) changed = false;
            return;
        }
        if (changed && value == applied) return;
        changed = false;
        if (!valid(value)) return;
        T desired = modify(value);
        if (desired == value) return;
        if (write(desired)) { original = value; applied = desired; changed = true; }
    }
};
