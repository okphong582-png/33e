# Mizze FFVN kernel TIPA

Standalone HUD application for Free Fire VN 1.134.1, build 2019121262.

The primary reader follows the backend recovered from the supplied hi.tipa. It loads libjailbreak, initializes jbdInitPPLRW, resolves proc_find/proc_task and follows task + 0x28, vm_map + 0x40, pmap + 8. Game memory is read with vreadbuf and direct field writes use vwritebuf. Kernel initialization and Unity discovery run on a worker queue.

Unity discovery walks vm_map entries and accepts only UUID e50b0e3a-d931-385b-9e4c-9ffde6d1b923. VN game fields and native RVAs come from the supplied 1.134.1 game analysis. The game and reference TIPA are kept locally.

The existing UIKit HUD/menu and touch handling are reused. Root spawning requires a compatible TrollStore/jailbreak installation and a working libjailbreak provider. This build has no key login.

Silent uses kernel data reads/writes and requests its own Mach task port only for mapping signed callback code and installing/restoring the handler. The installer reports task permission, mapping, fingerprint and handler errors. Its VN weapon-manager RVA and fingerprint are validated against the supplied image. AutoFire, Ghost and PlayerModes remain disabled. Hardware Silent operation has not been verified.

Build with make clean stage, then python3 package_tipa.py. GitHub Actions exports the TIPA and verification.json. Install the TIPA through TrollStore and press Start.
