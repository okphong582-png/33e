# Dopamine / rootless installation

This package loads the same authenticated overlay through the jailbreak's tweak
loader. It does not patch or re-sign the App Store game's executable/frameworks.
The TrollFools dylib and standalone TIPA remain separate outputs.

1. Eject the injected library from the game in TrollFools first. Open the game
   once to confirm it launches normally without injection.
2. Download the `.deb` in the `Mizze-Dopamine` GitHub Actions artifact and open it
   in Sileo. Install the package while the jailbreak is active.
3. Close and reopen the game. Wait about 9–10 seconds for the key panel, then use
   your normal key. The menu and features are the same as the injected build.

The package filters only `com.dts.freefireth` and `com.dts.freefiremax` and installs
its files beneath `/var/jb`. It requires iOS 15+ and a working tweak loader
providing `mobilesubstrate` (as ElleKit does in Dopamine). Installing the package
does not change jailbreak-wide trust/signature settings.

Build from the repository root:

```sh
make clean package BUILD_KIND=dylib FINALPACKAGE=1 FOR_RELEASE=1 \
  THEOS_PACKAGE_SCHEME=rootless THEOS_LAYOUT_DIR=jailbreak/layout \
  THEOS_PACKAGE_DIR_NAME=packages/dopamine MIZZE_OUTPUT_DIR=packages/dopamine
python3 tools/verify_jailbreak_package.py packages/dopamine/*.deb
```

Compatibility evidence: the official TrollFools source invokes CoreTrust signing
for both the inserted dylib and the modified host Mach-O, while standard
TrollStore excludes iOS 16.7.x releases other than 16.7 RC. This makes the loader
and signing route a candidate for immediate launch failures on the reported Lite
setup; it does not prove the exception without a device report.

- https://github.com/Lessica/TrollFools/blob/main/TrollFools/InjectorV3%2BInject.swift
- https://github.com/opa334/TrollStore#installing-trollstore
- https://theos.dev/docs/rootless

CI verifies the actual package architecture, install paths, filter, staged
signature and minimal dependencies. A physical device retest is still required
to confirm the reported startup crash is resolved.
