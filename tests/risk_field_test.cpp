#include "../esp/Core/RiskField.h"
#include <cassert>
#include <cmath>
int main() {
    RiskField<float> field;
    float memory = 0.2f;
    int writes = 0;
    bool readable = true, writable = true;
    auto read = [&](float &v) { v = memory; return readable; };
    auto write = [&](float v) { if (!writable) return false; memory = v; ++writes; return true; };
    auto valid = [](float v) { return std::isfinite(v) && v >= 0.04f && v <= 5; };
    auto modify = [](float v) { return v / 2; };
    auto tick = [&](uint64_t owner, bool enabled) { field.update(owner, enabled, read, write, valid, modify); };
    tick(1, false); assert(writes == 0);
    readable = false; tick(1, true); assert(writes == 0);
    readable = true; writable = false; tick(1, true); assert(!field.changed);
    writable = true; tick(1, true); assert(memory == 0.1f && writes == 1);
    for (int i = 0; i < 100; ++i) tick(1, true);
    assert(writes == 1); // No repeated halving or per-frame write spam.
    writable = false; tick(1, false); assert(field.changed);
    writable = true; tick(1, false); assert(memory == 0.2f && !field.changed);
    tick(1, true); memory = 0.3f; tick(1, false);
    assert(memory == 0.3f); // Do not overwrite game-owned updates on disable.
    tick(1, true); memory = 0.4f; tick(2, false);
    assert(memory == 0.4f && !field.changed); // Never restore into a new weapon.
    int before = writes;
    memory = NAN; tick(2, true); assert(writes == before);
    memory = -1; tick(2, true); assert(writes == before);
    tick(0, true); assert(writes == before);
    RiskField<uint8_t> boolean;
    uint8_t byte = 2;
    auto br = [&](uint8_t &v) { v = byte; return true; };
    auto bw = [&](uint8_t v) { byte = v; return true; };
    auto bv = [](uint8_t v) { return v <= 1; };
    auto bm = [](uint8_t) { return uint8_t(1); };
    boolean.update(1, true, br, bw, bv, bm); assert(byte == 2);
    byte = 0; boolean.update(1, true, br, bw, bv, bm); assert(byte == 1);
    boolean.update(1, false, br, bw, bv, bm); assert(byte == 0);
}
