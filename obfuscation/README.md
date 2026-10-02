# Own-code protection for the injected dylib

The five headers remain part of `libsubsystem.dylib`. `InjectedProtection.mm`
uses them for explicit engine self-tests, encoded license configuration and
integrity monitoring of its own code sections and exact immutable data objects.

- `CodeVirtualizer.h`: unique per-build opcodes, bounded bytecode/stack/steps,
  reversible byte encoding, CALL/RET and error reporting.
- `VtizerEngine.h`: reversible handler IDs, checked operands and arithmetic.
- `VDataStore.h`: reversible constants/buffers/pointers and thread-safe sealed
  values. Each sealed value carries its decode sequence and a corruption tag.
  `open()` leaves output unchanged on failure. Legacy rolling methods support
  only the last encrypted value; use `seal()`/`open()` for concurrent storage.
- `MoniteText.h`: bounded checksums of registered, owned spans. A baseline
  cannot be overwritten by repeating initialization.
- `AntiREProtection.h`: once-only initialization and sticky health status.

The constructor only schedules existing UI setup. Protection starts on a
utility queue after overlay ownership is claimed and the game is active.
A timer checks at 15-second intervals while foregrounded. Failure logs a
status without killing the host, changing game data or corrupting keys.
The overlay owner still prevents duplicate menus when two copies are loaded.

Code is in executable `__TEXT` sections (`__cv_text`, `__vtizer`, `__vd_text`,
`__mt_text`); encoded constants are in `__DATA,__vdata`. The platform helper
has no dynamic global initializers. All translation units use the same
`OBFUSCATION_BUILD_SEED` supplied from the commit by the makefile.

These encodings are obfuscation, not cryptography. The section checksum
finds changes after its first snapshot; it cannot authenticate prepatched
code or prevent a determined runtime reader. License validation still
requires its existing HTTPS/server checks. The monitor checks only the
module returned by `dladdr`; Apple's `getsectiondata` includes the ASLR slide.
See [Apple's implementation](https://github.com/apple-oss-distributions/cctools/blob/main/libmacho/getsecbyname.c).

CI runs portable sanitizer and concurrency tests, native Mach-O section
registration on macOS, the existing startup/duplicate-owner/license tests,
and final arm64 image verification. A successful build does not replace a
launch test on the target iPhone/game.
