#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>

namespace WeaponFeatures {
// Free Fire 1.132.1: verified Player/PlayerAttributes fields and ARM64 getters.
constexpr uint64_t PlayerAttributesOffset = 0x768;
constexpr uint64_t AttributesPlayerOffset = 0x20;
constexpr uint64_t ShootNoReloadOffset = 0x111;
constexpr uint64_t FireIntervalScaleOffset = 0x258;

struct Context {
    uint64_t task = 0;
    uint64_t match = 0;
    uint64_t player = 0;
    bool operator==(const Context &other) const {
        return task == other.task && match == other.match && player == other.player;
    }
};

struct Identity {
    Context context;
    uint64_t attributes = 0;
    uint64_t klass = 0;
    bool operator==(const Identity &other) const {
        return context == other.context && attributes == other.attributes && klass == other.klass;
    }
};

template <typename T, typename Reader, typename Valid>
bool ReadField(uint64_t base, uint64_t offset, T &value, Reader read, Valid valid) {
    constexpr uint64_t tail = sizeof(T) - 1;
    const uint64_t limit = std::numeric_limits<uint64_t>::max();
    if (!valid(base) || offset > limit - base || tail > limit - (base + offset)) return false;
    const uint64_t address = base + offset;
    return valid(address) && valid(address + tail) && read(address, &value, sizeof(T));
}

template <size_t N, typename Reader, typename Valid>
bool NameEquals(uint64_t pointer, const char (&expected)[N], Reader read, Valid valid) {
    char name[N]{};
    return ReadField(pointer, 0, name, read, valid) && std::memcmp(name, expected, N) == 0;
}

template <typename Reader, typename Valid>
bool Resolve(Context context, Identity &out, Reader read, Valid valid) {
    if (!context.task || !valid(context.match) || !valid(context.player)) return false;
    uint64_t attributes = 0, klass = 0, owner = 0, name = 0, namespc = 0;
    if (!ReadField(context.player, PlayerAttributesOffset, attributes, read, valid) ||
        !ReadField(attributes, 0, klass, read, valid) ||
        !ReadField(attributes, AttributesPlayerOffset, owner, read, valid) || owner != context.player ||
        !ReadField(klass, 0x10, name, read, valid) ||
        !ReadField(klass, 0x18, namespc, read, valid) ||
        !NameEquals(name, "PlayerAttributes", read, valid) ||
        !NameEquals(namespc, "COW.GamePlay", read, valid)) return false;
    out = {context, attributes, klass};
    return true;
}

template <typename T>
class FieldPatch {
    T original_{};
    T written_{};
    bool changed_ = false;
public:
    bool Changed() const { return changed_; }
    void Forget() { changed_ = false; }

    template <typename Reader, typename Writer, typename Accept, typename Transform>
    void Update(bool enabled, Reader read, Writer write, Accept accept, Transform transform) {
        if (!enabled && !changed_) return;
        T current{};
        if (!read(current)) return; // Retry a transient read/restore failure next frame.
        if (!accept(current)) { Forget(); return; }
        if (!enabled) {
            // A buff or game update owns a different value; do not overwrite it.
            if (current != written_ || write(original_)) Forget();
            return;
        }
        if (!changed_ || current != written_) original_ = current;
        const T desired = transform(original_);
        if (!accept(desired) || desired == current) return;
        if (write(desired)) {
            written_ = desired;
            changed_ = true;
        }
    }
};

class Controller {
    Identity identity_{};
    bool identified_ = false;
    FieldPatch<uint8_t> noReload_;
    FieldPatch<float> fastFire_;
public:
    bool HasChanges() const { return noReload_.Changed() || fastFire_.Changed(); }
    void Forget() {
        identified_ = false;
        noReload_.Forget();
        fastFire_.Forget();
    }

    template <typename Reader, typename Writer, typename Valid, typename CurrentContext>
    void Update(Context context, bool noReload, bool fastFire,
                Reader read, Writer write, Valid valid, CurrentContext currentContext) {
        if (!noReload && !fastFire && !HasChanges()) return;
        Identity identity;
        // Keep the baseline over transient chain failures. Dropping it would
        // treat our existing 0.5x value as a new baseline on the next frame.
        if (!Resolve(context, identity, read, valid)) return;
        if (!identified_ || !(identity == identity_)) {
            // Never restore through an old player, process, or recycled object address.
            Forget();
            identity_ = identity;
            identified_ = true;
        }
        const auto stillCurrent = [&]() {
            Identity live;
            return Resolve(currentContext(), live, read, valid) && live == identity_;
        };
        noReload_.Update(noReload,
            [&](uint8_t &value) {
                return ReadField(identity.attributes, ShootNoReloadOffset, value, read, valid);
            },
            [&](uint8_t value) {
                return stillCurrent() && write(identity.attributes + ShootNoReloadOffset, &value, sizeof(value));
            },
            [](uint8_t value) { return value <= 1; },
            [](uint8_t) -> uint8_t { return 1; });
        fastFire_.Update(fastFire,
            [&](float &value) {
                return ReadField(identity.attributes, FireIntervalScaleOffset, value, read, valid);
            },
            [&](float value) {
                return stillCurrent() && write(identity.attributes + FireIntervalScaleOffset, &value, sizeof(value));
            },
            [](float value) { return std::isfinite(value) && value >= 0.05f && value <= 16.0f; },
            [](float value) { return std::max(0.05f, value * 0.5f); });
    }
};
} // namespace WeaponFeatures
