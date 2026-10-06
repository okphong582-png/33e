# Aimlag dylib

This separate target contains Aimlag and FakeLag only. It links no ESP renderer,
aim controller, automatic-fire adapter, Ghost adapter, or full app/menu sources.
It shares the existing player-presentation adapter with the main project.

- Tap the one floating FakeLag button to toggle FakeLag.
- Hold it to open the two-option Aimlag / FakeLag menu.
- Drag to move the button. Aimlag applies while scoped; FakeLag applies without
  needing to scope. Both retain enemy presentation locally; they don't freeze
  opponents on the server.

Build from this folder: `make clean package FINALPACKAGE=1 FOR_RELEASE=1`.
Output: `aimlag/packages/Aimlag.dylib`. No TIPA or standalone application target.
Use it by itself; loading the full dylib alongside it can compete for callbacks.
