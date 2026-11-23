#pragma once

#include <cmath>

// A ray endpoint is not evidence of cover unless the game reported a collider.
// Even with a collider, only a hit very close to this target's line can block it.
inline bool AimCoverHitBlocksTarget(bool hasCollider,
                                   float originX, float originY, float originZ,
                                   float hitX, float hitY, float hitZ,
                                   float targetX, float targetY, float targetZ) {
    if (!hasCollider) return false;
    const float ex = targetX - originX, ey = targetY - originY, ez = targetZ - originZ;
    const float hx = hitX - originX, hy = hitY - originY, hz = hitZ - originZ;
    const float enemySq = ex * ex + ey * ey + ez * ez;
    const float hitSq = hx * hx + hy * hy + hz * hz;
    if (!std::isfinite(enemySq) || !std::isfinite(hitSq) || enemySq < 1.35f * 1.35f || hitSq < 0.30f * 0.30f) return false;
    const float enemyDistance = std::sqrt(enemySq);
    const float hitDistance = std::sqrt(hitSq);
    if (hitDistance + 1.10f >= enemyDistance) return false;
    const float projection = (hx * ex + hy * ey + hz * ez) / enemyDistance;
    if (projection <= 0.0f || projection >= enemyDistance) return false;
    const float lateralSq = hitSq - projection * projection;
    return lateralSq >= 0.0f && lateralSq <= 1.10f * 1.10f;
}
