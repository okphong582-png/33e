# TrollFools startup hardening

Reported symptom: some injected games terminate during loading just before the
key screen appears, including an iPhone X on iOS 16.7.16. The user declined to
collect a crash report, so the actual exception or signal is not identified.

The f3283ec release artifact was inspected directly: arm64 (not arm64e), iOS 13
minimum, valid SHA-256 code page hashes, no Substrate dependency, and 18 loader
initializers. This excludes an unsigned artifact or an arm64e-only slice as
explanations for that inspected file; it does not identify the device failure.

The unused `JunkBlob` is now constant-initialized instead of generating a runtime
initializer per translation unit. Offset configuration strings are decoded on
first use instead of constructing Foundation objects during dyld initialization.
The injected build drops unused framework links and uses an app-relative dylib
identity. Packaging exports only the staged signed image, and CI checks its code
page hashes and permits only the actually needed public framework dependencies.

The injected initializer enqueues setup after eight seconds, then waits for an active, attached host root controller
with no active presentation/dismissal/transition, and an unchanged window and
size for 0.75 seconds. Scene/window changes and backgrounding reset the gate.
Retries remain bounded and UI work stays on the main queue. Own-code protection
scans start only after successful license verification.

The overlay is a child controller inside the existing host view, with a
passthrough container for touches. It does not create another UIWindow, change
the game root controller, or request another scene. Failed attachment cleans up
containment and balances appearance transitions before retrying.

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
existing host-window and duplicate-owner tests. `injected_overlay_attachment_test.mm`
executes the actual containment helper against UIKit stubs, checking host focus,
duplicate attachment, failure cleanup and retry. The artifact contract test
rejects unexpected framework links, stale install names and modified signed pages.
These checks do not confirm that
every reported device crash is fixed; a physical retest or crash report is needed.
