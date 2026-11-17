#include "../sources/InjectedBootstrapPolicy.h"
#include "../sources/InjectedStartupPolicy.h"
#include <cassert>
#include <cstdio>
#include <limits>

using InjectedStartup::Bootstrap;
using InjectedStartup::Gate;

int main() {
    Bootstrap state;
    Bootstrap::Generation oldTicket, currentTicket, ignored;
    assert(!state.schedule(ignored)); // No work before activation.
    state.restart(2);
    assert(state.schedule(oldTicket));
    assert(!state.schedule(ignored)); // Notifications cannot fork retry chains.

    // Resume before a pre-background callback runs. That callback must neither
    // attach UI nor clear the slot belonging to the resumed activation.
    state.cancel();
    state.restart(2);
    assert(state.schedule(currentTicket));
    assert(!state.beginAttempt(oldTicket));
    assert(!state.schedule(ignored));
    assert(state.beginAttempt(currentTicket));
    assert(!state.beginAttempt(currentTicket));
    assert(state.schedule(currentTicket));
    assert(state.beginAttempt(currentTicket));
    assert(!state.schedule(ignored)); // Exactly two attempts, then wait for activation.

    state.restart(1);
    assert(state.schedule(currentTicket));
    state.cancel(); // Successful attachment or backgrounding cancels queued work.
    assert(!state.beginAttempt(currentTicket));
    assert(!state.schedule(ignored));
    state.restart(0);
    assert(!state.schedule(ignored));

    // A long splash screen may exhaust retries; a later window event recovers.
    state.restart(60);
    for (unsigned i=0;i<60;++i) {
        assert(state.schedule(currentTicket));
        assert(state.beginAttempt(currentTicket));
    }
    assert(!state.schedule(ignored));
    state.restart(60);
    assert(state.schedule(currentTicket));
    assert(state.beginAttempt(currentTicket));

    Gate gate;
    assert(!gate.ready(true,true,1,800,400,10));
    assert(!gate.ready(true,true,1,800,400,10.74));
    assert(gate.ready(true,true,1,800,400,10.75));
    gate.reset(); // Resuming must wait a fresh stable interval.
    assert(!gate.ready(true,true,1,800,400,30));
    assert(gate.ready(true,true,1,800,400,30.75));
    assert(!gate.ready(true,true,1,400,800,31)); // Rotation.
    assert(!gate.ready(true,true,2,400,800,32)); // A different host window.
    assert(!gate.ready(false,true,2,400,800,33));
    assert(!gate.ready(true,true,2,400,800,34));
    assert(gate.ready(true,true,2,400,800,34.75));
    assert(!gate.ready(true,false,2,400,800,35)); // Host transition.
    assert(!gate.ready(true,true,0,400,800,36));
    assert(!gate.ready(true,true,2,0,800,37));
    assert(!gate.ready(true,true,2,400,800,std::numeric_limits<double>::quiet_NaN()));
    assert(!gate.ready(true,true,2,400,800,40));
    assert(!gate.ready(true,true,2,400,800,39)); // Monotonic clock reset.
    assert(gate.ready(true,true,2,400,800,39.75));
    std::puts("PASS: stale callbacks, coalescing, cancellation, retry limits, recovery, host stability");
}
