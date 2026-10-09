#pragma once
#include <cmath>
#include <cstdint>

namespace fcm {
// Own one menu gesture; unrelated fingers must not release or activate it.
class TouchState {
    bool active_ = false, dragged_ = false;
    int64_t identity_ = 0;
    double x_ = 0, y_ = 0, lastEvent_ = 0;
public:
    void cancel() { active_ = false; dragged_ = false; }
    bool begin(int64_t identity, double x, double y, double now) {
        if (!std::isfinite(x) || !std::isfinite(y)) return false;
        // Recover if a private HID stream dropped its lift/cancel packet.
        if (active_ && now - lastEvent_ < 3.0) return false;
        active_ = true; dragged_ = false; identity_ = identity;
        x_ = x; y_ = y; lastEvent_ = now; return true;
    }
    bool owns(int64_t identity) const { return active_ && identity == identity_; }
    bool move(int64_t identity, double x, double y, double now) {
        if (!owns(identity) || !std::isfinite(x) || !std::isfinite(y)) return false;
        if (std::hypot(x - x_, y - y_) > 9.0) dragged_ = true;
        lastEvent_ = now; return true;
    }
    bool dragged() const { return dragged_; }
    bool finish(int64_t identity, bool cancelled, bool inside) {
        if (!owns(identity)) return false;
        const bool activate = !cancelled && !dragged_ && inside;
        cancel(); return activate;
    }
};
}
