#include "../esp/Core/SilentAimDirection.h"
#include "../esp/Core/AimSelection.h"
#include <cassert>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <utility>
#include <vector>

using namespace SilentAimDirection;
int main() {
    Point direction{};
    assert(Toward({2, 3, 4}, {5, 3, 8}, direction));
    assert(std::fabs(direction.x - 0.6f) < 0.00001f);
    assert(std::fabs(direction.z - 0.8f) < 0.00001f);
    assert(direction.y == 0);
    assert(!Toward({1, 2, 3}, {1, 2, 3}, direction));
    assert(!Toward({NAN, 2, 3}, {1, 2, 3}, direction));
    assert(!Toward({1, 2, 3}, {1, INFINITY, 3}, direction));
    const float max = std::numeric_limits<float>::max();
    assert(Toward({-max, 0, 0}, {max, 0, 0}, direction));
    assert((direction == Point{1, 0, 0}));
    assert(Fresh(1, 1.14));
    assert(!Fresh(1, 1.16) && !Fresh(1, 0.9) && !Fresh(NAN, 2));

    // Every visible corner is selectable even outside the ordinary FOV;
    // offscreen, behind-camera and ineligible targets remain excluded.
    for (auto size : {std::pair<float, float>{1000, 500}, {500, 1000}}) {
        for (float x : {0.0f, size.first}) for (float y : {0.0f, size.second}) {
            AimSelection::Selection s;
            s.consider(1, x, y, 1, size.first, size.second, ViewportRadius(size.first, size.second), true);
            assert(s.target == 1);
        }
        AimSelection::Selection s;
        s.consider(1, -1, 5, 1, size.first, size.second, ViewportRadius(size.first, size.second), true);
        s.consider(2, 5, 5, -1, size.first, size.second, ViewportRadius(size.first, size.second), true);
        s.consider(3, 5, 5, 1, size.first, size.second, ViewportRadius(size.first, size.second), false);
        assert(!s.target);
    }
    assert(ViewportRadius(0, 500) == 0 && ViewportRadius(NAN, 500) == 0);

    for (int readFailure = 0; readFailure < 2; ++readFailure)
    for (int writeFailure = 0; writeFailure < 2; ++writeFailure)
    for (int replaced = 0; replaced < 2; ++replaced)
    for (int gameChanges = 0; gameChanges < 2; ++gameChanges) {
        const Point original{0, 0, 1}, desired{1, 0, 0}, gameValue{0, 1, 0};
        Point memory = original;
        bool current = true;
        int calls = 0;
        std::vector<Point> writes;
        const bool changed = Dispatch(desired,
            [&](Point &p) { p = memory; return !readFailure; },
            [&](Point p) { if (writeFailure) return false; memory = p; writes.push_back(p); return true; },
            [&] { return current; },
            [&] {
                ++calls;
                assert(memory == ((!readFailure && !writeFailure) ? desired : original));
                if (replaced) current = false;
                if (gameChanges) memory = gameValue;
            });
        assert(calls == 1 && changed == (!readFailure && !writeFailure));
        if (gameChanges) assert(memory == gameValue);
        else if (changed && replaced) assert(memory == desired);
        else assert(memory == original);
        assert(writes.size() == (changed ? (replaced || gameChanges ? 1u : 2u) : 0u));
    }
    // Unwinding must restore an owned input before propagating the exception.
    Point memory{0, 0, 1};
    try {
        Dispatch({1, 0, 0}, [&](Point &p) { p = memory; return true; },
            [&](Point p) { memory = p; return true; }, [] { return true; },
            [] { throw std::runtime_error("native handler failed"); });
        assert(false);
    } catch (const std::runtime_error &) { assert((memory == Point{0, 0, 1})); }
    std::cout << "Silent shot direction, dispatch ownership and viewport selection passed\n";
}
