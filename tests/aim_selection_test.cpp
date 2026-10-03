#include "../esp/Core/AimSelection.h"
#include <cassert>
#include <iostream>

using AimSelection::Selection;
int main() {
    using AimSelection::Triggered;
    for (int raw : {0, 1, 2, 255, 0, -1, 0, 1, 0}) {
        bool firing = AimSelection::FiringState(raw);
        assert(firing == (raw == 1));
        assert(Triggered(true, false, firing, false, false) == firing);
    }
    for (int enabled = 0; enabled < 2; ++enabled)
    for (int scope = 0; scope < 2; ++scope)
    for (int always = 0; always < 2; ++always) {
        assert(Triggered(enabled, scope, false, false, always) == (enabled && always));
        assert(Triggered(enabled, scope, true, false, always) == bool(enabled));
        assert(Triggered(enabled, scope, false, true, always) == bool(enabled ? always : scope));
        assert(Triggered(enabled, scope, true, true, always) == bool(enabled || scope));
    }
    // Releasing fire must stop immediately; the next shot activates again.
    for (bool firing : {false, true, true, false, true, false})
        assert(Triggered(true, false, firing, false, false) == firing);
    // Scope state must not suppress fire activation when scope aim is disabled.
    for (bool firing : {false, true, true, false, true, false})
        assert(Triggered(true, false, firing, true, false) == firing);
    // Default scope toggle and even a stuck scope state cannot turn Only Shot into Always.
    for (bool scoping : {false, true})
    for (int raw : {-1, 0, 1, 2, 255, 1, 0})
        assert(Triggered(true, true, AimSelection::FiringState(raw), scoping, false) == (raw == 1));
    // Opening scope before a burst must neither be required nor keep aim running
    // after release. A scope-state drop during the burst must not interrupt fire aim.
    struct ShotFrame { int raw; bool scoping; bool expected; };
    for (const auto frame : {ShotFrame{0, true, false}, ShotFrame{1, true, true},
                            ShotFrame{1, false, true}, ShotFrame{0, true, false},
                            ShotFrame{1, false, true}, ShotFrame{-1, true, false}}) {
        assert(Triggered(true, true, AimSelection::FiringState(frame.raw),
                         frame.scoping, false) == frame.expected);
        assert(!Triggered(false, false, AimSelection::FiringState(frame.raw),
                          frame.scoping, true));
    }
    assert(!AimSelection::BooleanState(0));
    assert(AimSelection::BooleanState(1));
    assert(!AimSelection::BooleanState(2));
    assert(!AimSelection::BooleanState(255));
    assert(!AimSelection::BooleanState(65535));
    assert(!AimSelection::ScopeState(0));
    assert(AimSelection::ScopeState(1));
    assert(AimSelection::ScopeState(2));
    assert(Triggered(false, true, false, AimSelection::ScopeState(2)));
    assert(!Triggered(true, true, false, false));
    assert(Triggered(true, true, true, false));
    assert(Triggered(true, true, false, true));
    assert(!Triggered(false, false, true, true));
    assert(!Triggered(true, false, false, true));
    assert(!Triggered(false, true, true, false));
    auto add = [](Selection &s, uint64_t id, float x, bool eligible = true) {
        s.consider(id, x, 250, 1, 1000, 500, 100, eligible);
    };
    Selection nearest;
    add(nearest, 1, 560); add(nearest, 2, 510);
    assert(nearest.target == 2);
    Selection sticky; sticky.previous = 1;
    add(sticky, 2, 501); add(sticky, 1, 590); add(sticky, 3, 500);
    assert(sticky.target == 1 && sticky.retained);
    Selection reverse; reverse.previous = 1;
    add(reverse, 1, 590); add(reverse, 3, 500);
    assert(reverse.target == 1);
    Selection lost; lost.previous = 1;
    add(lost, 1, 590, false); add(lost, 2, 510);
    assert(lost.target == 2 && !lost.retained);
    Selection strictBoundary; strictBoundary.previous = 1;
    add(strictBoundary, 1, 601);
    assert(strictBoundary.target == 0);
    add(strictBoundary, 1, 600);
    assert(strictBoundary.target == 1);
    Selection shrink; shrink.previous = 1;
    shrink.consider(1, 560, 250, 1, 1000, 500, 50, true);
    assert(shrink.target == 0);
    assert(AimSelection::Radius(1000, 500, 40) == 200);
    assert(AimSelection::Radius(500, 1000, 40) == 200);
    assert(AimSelection::Radius(1000, 500, 150) == 240);
    assert(AimSelection::Radius(500, 1000, 150) == 240);
    assert(AimSelection::Radius(500, 500, INFINITY) == 200);
    Selection outOfRange; outOfRange.previous = 1;
    add(outOfRange, 1, 651); add(outOfRange, 2, 620);
    assert(outOfRange.target == 0);
    Selection invalid;
    invalid.consider(1, 500, 250, -1, 1000, 500, 100, true);
    invalid.consider(2, NAN, 250, 1, 1000, 500, 100, true);
    invalid.consider(3, 500, INFINITY, 1, 1000, 500, 100, true);
    invalid.consider(4, -1, 250, 1, 1000, 500, 1000, true);
    add(invalid, 0, 500);
    assert(invalid.target == 0);
    Selection emptyFrame; emptyFrame.previous = 1;
    assert(emptyFrame.target == 0);
    Selection tie;
    add(tie, 2, 500); add(tie, 1, 500);
    assert(tie.target == 1);
    std::cout << "Aim selection: all checks passed\n";
}
