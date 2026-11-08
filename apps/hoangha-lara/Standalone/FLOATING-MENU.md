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

## 1.5.1 — startup and UI scheduling fix

The supplied FreeFire crash log records CODESIGNING / Invalid Page in
libsystem_kernel __getpid during launch (about 3.5 seconds after launch).
The image UUID matches the FF TH 1.132.1 reader. This is not evidence of a
bad box coordinate or an unsupported game UUID, and the exact protection/PAC
failure is not diagnosed solely by that stack.

Version 1.5 incorrectly opened a game RemoteCall session even with ESP disabled.
1.5.1 creates no game reader/session or geometry calls until ESP is explicitly
enabled. Disabling ESP clears the canvas and disconnects that reader. Failed
connections are not continuously recreated; toggle off/on to start a new attempt.

The default menu loop polls shared flags at 10 Hz. Interactive calls for menu
visibility and control state reuse prepared invocations. Bounds checks run once
per five seconds, box sampling at 5 Hz and active-game geometry at 0.5 Hz. An
empty/unchanged canvas does not issue repeated visibility/path writes.

The fix removes the demonstrated automatic game-connection path during Start.
It does not repair the underlying RemoteCall / Invalid Page fault when ESP is
explicitly enabled. Physical-device confirmation of Start/menu stability and
further investigation of enabled ESP are still required. Kernel and RemoteCall
implementations are unchanged. The scheduler tests prove disabled ESP executes
zero game work in the app loop; they do not execute a protected iOS process.
