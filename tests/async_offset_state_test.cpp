#include "../esp/Core/AsyncOffsetState.h"
#include <cassert>

int main() {
    AsyncOffsetState state;
    assert(state.begin(0));
    // Simulate ten seconds of 60 Hz render calls during a slow request.
    // None starts a duplicate request or invents an offset.
    for (int frame = 1; frame <= 600; ++frame) {
        assert(state.value == 0);
        assert(!state.begin(frame / 60.0));
    }
    state.finish(0, 10);
    assert(!state.pending);
    assert(!state.begin(19.99));
    assert(state.begin(20));
    state.finish(0xb8, 21);
    assert(state.value == 0xb8);
    assert(!state.begin(100));
    assert(!state.pending);
}
