# Floating menu prototype — 1.4

Start creates a 58×58 logo button and a hidden 280×180 test menu in SpringBoard.
The user-provided PNG is clipped to a circle by UIKit. Tap toggles the menu;
the close button hides the menu; the pan recognizer moves and clamps the bubble.
The test menu contains only MIZZE, hoangha and a close control.

The previous full-screen text window is removed. New windows retain their small
frames, do not become key windows, and are checked for unexpected full-screen
expansion; an expanded window is hidden. This is intended to leave events outside
the bubble/menu to the underlying windows. Actual cross-app touch routing still
requires validation on the user's iPhone.

UIKit callbacks use retained NSInvocation targets that reset individual bytes
in fixed-size NSMutableData. The app reads those shared bytes at 20 Hz and only
updates UIKit when needed. Pan queries and frame updates reuse invocations.
The interaction loop runs on the existing serial worker queue. Silent audio
keeps the app eligible for background execution; no microphone access is used.
Stop ends the loop, hides both windows, frees cached buffers, and closes the
RemoteCall session. Per-launch stage logs remain available using the Log button.

The kernel exploit and RemoteCall implementation are unchanged. The existing
iPhone XS / iOS 18.5 / 22F76 kernelcache remains bundled. This prototype has no
game ESP, aim or memory-editing controls.

Validation: local Objective-C syntax checks; Apple arm64e build and code-signing
validation in CI; artifact CRC, architecture, resource and kernel hashes.
No physical-device touch/drag validation has been performed by the build agent.
