# Hoangha 1.3

The observed SpringBoard crash occurs in objc_retainAutoreleaseReturnValue on
the main thread, with the fault address 0x401 and UIColor clearColor in the
register context. That address matches Lara's synthetic RemoteCall return trap.
This points to ARC caller inspection during the previous direct UIKit calls.

UIKit operations now execute through NSInvocation on the main thread, providing
a Foundation call frame for the target method. The app no longer uses the
whole-operation doRemoteCallSyncOnMainThread wrapper or CAMetalDrawable-based
CGRect marshalling. Scalars, CGRect and CGFloat arguments are copied through
NSInvocation instead.

Kernel and RemoteCall core files are unchanged. The existing iPhone XS / 22F76
kernelcache preparation remains. A failed kernel start cannot be repeated within
the same app session. The Log button exports a small per-launch stage journal.

Validation: Objective-C syntax checks locally; Apple arm64e compilation,
codesign validation and final architecture verification in CI. Device validation
is still required; this change is a candidate fix for the observed crash.

User diagnostic files and local backups are not included in the repository.
