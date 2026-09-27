#pragma once
#include <cmath>
#include <cstdint>
#include <limits>

namespace AimSelection {
inline float Radius(float width, float height, float percent) {
    if (!std::isfinite(percent)) percent = 40;
    percent = std::fmax(5.0f, std::fmin(150.0f, percent));
    return std::fmin(width, height) * percent / 100.0f;
}
inline bool Triggered(bool fireEnabled, bool scopeEnabled, bool firing, bool scoping) {
    return (fireEnabled && firing) || (scopeEnabled && scoping);
}
inline bool BooleanState(uint32_t raw) { return raw == 1; }
// Rendering-camera visibility alone does not establish an unobstructed target.
// Missing, partial or unreadable flags are not eligible for aim.
inline bool VisibleForAim(bool readOK, uint32_t flags, uint32_t cameraMask, uint32_t pvsMask) {
    return readOK && (flags & cameraMask) == cameraMask && (flags & pvsMask) == pvsMask;
}

// A valid retained target wins over a new target closer to the crosshair.
struct Selection {
    uint64_t previous = 0;
    uint64_t target = 0;
    float bestDistanceSquared = std::numeric_limits<float>::max();
    bool retained = false;

    void consider(uint64_t id, float x, float y, float depth,
                  float width, float height, float radius, bool eligible) {
        if (!eligible || !id || !std::isfinite(x) || !std::isfinite(y) ||
            !std::isfinite(depth) || depth <= 0.001f ||
            !std::isfinite(width) || !std::isfinite(height) || !std::isfinite(radius) ||
            width <= 0 || height <= 0 || radius <= 0 ||
            x < 0 || x > width || y < 0 || y > height) return;
        const float dx = x - width * 0.5f, dy = y - height * 0.5f;
        const float distanceSquared = dx * dx + dy * dy;
        const bool same = id == previous;
        const float limit = radius; // Retention never extends beyond the visible FOV.
        if (distanceSquared > limit * limit) return;
        if (same || (!retained && (distanceSquared < bestDistanceSquared ||
            (distanceSquared == bestDistanceSquared && id < target)))) {
            target = id;
            bestDistanceSquared = distanceSquared;
            retained = same;
        }
    }
};
}
