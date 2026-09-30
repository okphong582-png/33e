#include "../esp/Core/MatchDelay.h"
#include "../esp/Core/AimSelection.h"
#include <cassert>
#include <initializer_list>
int main() {
    MatchDelay gate;
    assert(!gate.update(1, 0));
    assert(!gate.update(1, 59.99));
    assert(gate.update(1, 60));
    assert(gate.update(1, 180));
    assert(!gate.update(2, 180));
    assert(gate.update(2, 240));
    assert(!gate.update(0, 241));
    assert(!gate.update(2, 242));
    assert(!gate.update(2, NAN));
    assert(!gate.update(2, 300));
    assert(!gate.update(2, 299));
    assert(!gate.update(2, 358));
    assert(gate.update(2, 359));
    for (int raw : {0, 1, 2, 255, 0, -1, 0, 1, 0}) {
        bool firing = AimSelection::FiringState(raw);
        assert(firing == (raw > 0));
        assert(AimSelection::Triggered(true, false, firing, false, false) == firing);
    }
}
