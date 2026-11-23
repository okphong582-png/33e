#include "../esp/esp/AimCoverGeometry.h"
#include <cassert>
#include <cstdio>

int main() {
    // The weapon's 30 m endpoint with no collision must not veto a 100 m target.
    assert(!AimCoverHitBlocksTarget(false, 0, 0, 0, 0, 0, 30, 0, 0, 100));
    // An actual wall on the same line still blocks the distant target.
    assert(AimCoverHitBlocksTarget(true, 0, 0, 0, 0, 0, 30, 0, 0, 100));
    // Ground or another off-axis collision is not cover for this target.
    assert(!AimCoverHitBlocksTarget(true, 0, 0, 0, 0, -3, 30, 0, 0, 100));
    // A hit behind the target cannot block it.
    assert(!AimCoverHitBlocksTarget(true, 0, 0, 0, 0, 0, 120, 0, 0, 100));
    // Invalid numerical input never turns into apparent cover.
    assert(!AimCoverHitBlocksTarget(true, 0, 0, 0, INFINITY, 0, 30, 0, 0, 100));
    std::puts("PASS: 30 m ray endpoint, real cover, off-axis hit, behind target, invalid input");
}
