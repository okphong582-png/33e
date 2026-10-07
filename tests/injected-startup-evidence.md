# TrollFools startup hardening

Reported symptom: some injected games terminate during loading just before the
key screen appears. No iOS crash report/device model was supplied, so the actual
exception or signal is not yet identified.

The injected initializer now waits for an active, attached host root controller
with no active presentation/dismissal/transition, and an unchanged window and
size for 0.75 seconds. Scene/window changes and backgrounding reset the gate.
Retries remain bounded and UI work stays on the main queue.

The license screen is an inline key panel instead of a startup UIAlertController.
Showing it does not make the overlay key or automatically focus a keyboard.
Only tapping the field takes keyboard focus; submitting returns focus to the
game. The overlay controller uses the host's supported orientation mask instead
of an independent default mask. Successful verification enters the overlay
without another alert presentation. License validation and device binding are
unchanged.

`injected_startup_policy_test.cpp` checks missing/transitioning hosts, a stable
window, rotation, background/foreground, a replacement window, invalid geometry
and a clock reset. CI also compiles the UIKit implementation and retains the
existing host-window and duplicate-owner tests. These checks do not confirm that
every reported device crash is fixed; a physical retest or crash report is needed.
