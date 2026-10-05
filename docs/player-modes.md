# Player modes and compact controls

## Fly

Fly defaults off with a new preference, independent of the old Burrow setting.
Default height is 3 metres, adjustable from 1 to 5. The first eligible callback
captures the base altitude. Each OnUpdate and PostUpdate advances by at most
0.0625 metres toward base plus height, then holds that altitude. Height changes
use the same bounded adjustment. Enemy hold epochs do not recapture the base.
A native vertical correction greater than 4 metres captures a fresh base.

The controller follows Player.UsePhysicalCharacterController (0x260). Ordinary
matches can leave PhysicalCCT (0x268) empty and use CharacterController (0x4D8).
Both paths validate the instance, class and namespace; Unity controllers also
require a nonzero cached native pointer. The callback rechecks the selected
mode and exact instance/class before applying. Unity controllers use the
verified Entity transform setter. Physical controllers additionally call
their verified ForceSetPosition method
(0x646B648, size 0xB0, fingerprint 0x7C5E5F3F), then Entity.set_Position so the
physical controller and rendered position agree. Full method fingerprints and
signed callback installation guards remain required. Publication has a one-second
lease; malformed coordinates, stale owners, health, vehicle, parachute and
force-sync guards stop local enforcement.

Disabling Fly leaves descent to normal game physics. No gravity or collision
flags are changed. Bounded steps and simulation tests do not prove smooth flight
on an iPhone or acceptance of the position by the server.

## Aimlag and FakeLag

Aimlag holds supported enemy presentation while scoped, with 0.18 seconds of
scope transition tolerance. FakeLag holds without requiring scope. Both preserve
the original OnUpdate and PostUpdate calls, then apply the presentation anchor.
Their enemy hold is independent of Fly. UID, owner, publication and method guards
remain active. This is a client presentation override, not a server freeze or a
guarantee that skeletal animation stops.

## Menu

The expandable Loại aim row contains aim when firing, aim when scoped, always
aim, neck aim, Silent Aim, AimKill, Aimlag and FakeLag. Ordinary aim modes are
exclusive with Silent Aim/AimKill; AimKill enables Silent Aim. Existing FOV,
headshot and distance settings remain in the aim tab.

Toggle rows use 34-pixel square boxes displaying X when enabled. The entire
54-pixel row can be pressed with both UIKit events and routed TIPA touches.
AimKill, Ghost, Fly and FakeLag retain draggable floating buttons and the global
HideFeatureButtons preference. Teleport is removed from the menu, floating
buttons, public API and remote commands. Ghost's independent return behavior
is unchanged.

## Verification

Host policy and installation tests cover bounded height, scope transitions,
enemy ownership and signed callback restoration. ARM64 remote-code simulations
cover both update phases, bounded ascent and height changes, gravity steps,
physical/rendered position agreement, invalid controllers and coordinates,
stale publication, UID reuse, enemy holds and ABI preservation. Release CI builds
both TIPA and dylib. Device behavior still requires testing in the game.
