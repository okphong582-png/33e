# DarkSword memory backend

The menu uses Lara's kernel backend. No TrollStore task port or `task_for_pid`
is used to access the game.

`LaraMemoryReader` finds the process through `proc_find_by_name`, resolves its
task and VM map with Lara's helpers and offsets, and maps target user pages
through the existing `vmmapremotepage` implementation. Mach reads and writes
operate on that **local mapping in Lara's own task**. They do not acquire a
Mach task port for the game. Kernel reads are only used for kernel structures.

Transfers split at the device's VM page boundaries, release each mapping and
memory-entry port, and fail if mapping or copying fails. Failed reads clear the
destination. Multi-page writes can partially complete before failure.

Like the TIPA/dylib reader in `iOSViet/esp/Core/_0xPDFFFF27.mm`, module lookup
prefers UnityFramework and falls back to the actual executable. Here module
lookup inspects Mach-O headers and bounded load commands in the target VM map,
including `LC_ID_DYLIB`; it does not assume a fixed ASLR base.

## Device verification

1. Build with Xcode on macOS. FFMenuEngine is included in the lara target.
2. Run Lara's existing DarkSword setup and initialize kernel offsets. Starting
   the FF menu checks readiness and does not launch a separate exploit run.
3. Start FreeFire or FreeFireMax, then use Attach in the menu. Confirm the
   reported PID and module base against the running build.
4. Verify known values through `readMemoryAtAddress:buffer:size:`, including a
   buffer spanning two mapped pages. Check an unmapped address returns NO and
   clears the output buffer.
5. Exit/restart the game and confirm the old attachment is invalidated; attach
   again before reading the new process.
6. Check repeated reads do not accumulate mapped regions or Mach port rights.

The existing DarkSword VM mapper and its kernel offsets still require testing
on the actual supported device. Windows cannot build or run this iOS target.

## Menu window

When `mgr.dsready` becomes true, Lara opens the FF menu in a transparent UIWindow
attached to its foreground UIWindowScene. The FF button toggles the menu, and
empty space passes touches through to Lara's underlying UI. The Start button
can reopen it if initialization finished before the view appeared.

This window belongs to Lara. Its high window level does not make it a system
overlay across applications. Displaying the menu over Free Fire while Lara is
backgrounded is not implemented or validated by this change.

The overlay's `renderFrame` still has an empty entity list. This backend change
does not supply game-version-specific entity offsets, camera matrices or the
entity traversal needed to draw live ESP.
