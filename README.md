# Mizze Kernel — Free Fire VN 1.134.1

Application display: Mizze Kernel. Dark/silver UI and supplied Mizze artwork.
Target: com.garena.ffvn / FreeFireVN, build 2019121262.
Unity UUID: e50b0e3a-d931-385b-9e4c-9ffde6d1b923.
License: existing Mizze signed V4 records and Firebase Direct V6 leases.
The prior Tserver SDK is not linked or required.

Build: Theos on macOS, iPhoneOS18.6.sdk, ldid; make -f Makefile.app package.
Regression tests and IPA checks are in .github/workflows/build.yml.
The build artifact has not been tested on a physical iPhone; build success does
not establish gameplay compatibility or measured ESP frame rate.
Original kernel/runtime compatibility limits still apply.

Original upstream notes and credits are preserved below.

# FilzaJailedDS
Filza Jailed Darksword, support iOS 17.0-26.0.1 (except 18.7.2-18.7.7). This repo open source the tweak inject into the Filza iPA (4.0.0 and back, 4.0.2 seems crash something)

About iPhone 17 series and iPad M5: SUPPORT ETA SOON!👌

Note: I just change the name due to requested. But i think jailed is okay then

# Credit
- Thanks to [Duy Tran](https://github.com/khanhduytran0) for the sandbox hook token
- Thanks to [wh1te4ever](https://github.com/wh1te4ever/) for the super details [darksword-kfun](https://github.com/wh1te4ever/darksword-kexploit-fun) with offset/XPF
- Thanks to [opa334](https://github.com/opa334/) for the XPF/krw
- Thanks to [CrazyMind90](https://github.com/crazymind90/) for idea how to get sbx token with krw only
- Thanks to [roootdev](https://github.com/rooootdev) for sandbox elevate in [lara](https://github.com/rooootdev/lara)
- And me :D
