# Hoangha Floating — 1.5 ESP Box

The existing SpringBoard floating logo opens a bounded menu with one ESP Box
switch. Start is labelled Bắt đầu and Stop is labelled Dừng. All menu controls
and box graphics are owned by the SpringBoard session. FreeFire is used as a
read-only data source and for its foreground scene geometry.

The drawing window is noninteractive at both UIWindow and root-view levels and
stays below the compact menu. CAShapeLayer receives bounded CGPath rectangles;
turning ESP off, losing valid data, backgrounding the game, changing orientation
or stopping the session clears the old path. No synthetic target boxes are used.

The existing FreeFireESP reader is pinned to the supplied TH 1.132.1 image UUID
C8DE7371-CBA7-3E7A-9E09-30B8E1B89073. It rejects other builds, bounds the roster
and transform traversal, filters teammates/dead targets and rechecks roster
identity/version. An incompatible build is reported in the floating menu. This
profile has static-image and synthetic-memory verification, not a confirmed
physical-device test of this app.

The game reader gets a separate existing RemoteCall session. Kernel setup,
RemoteCall implementation and their device restrictions are unchanged. The game
session is drained/destroyed before closing the SpringBoard session. The app
samples boxes at no more than 10 Hz and scene geometry at 2 Hz. The logo and menu
remain available when no compatible game data is found.

Windows use bounds, center and an orientation transform, rather than assigning
frame while rotated. Logical game coordinates map to the fixed screen space in
portrait and both landscape orientations. The launcher also declares landscape
support. Small-window bounds are still checked to avoid capturing touches with
an expanded interactive window.

CI runs the FF reader tests (synthetic memory, UUID, teams/HP, projection,
failed reads, roster mutation, cycles and dense frames) and orientation tests,
then compiles/links with Apple arm64e ABI, signs ad hoc and verifies the IPA.
The bundled XS / iOS 18.5 kernelcache is retained. Actual cross-app hit testing,
landscape direction and target boxes need validation on the user's iPhone.

Usage: Bắt đầu → open FF TH → tap the floating logo → enable ESP Box → enter a
match. If the UUID does not match, use the exact supported game build/profile;
there is no automatic reuse of offsets for a different version. Dừng hides all
windows and ends both sessions.
