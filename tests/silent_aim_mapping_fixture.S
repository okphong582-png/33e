#include "../esp/Core/SilentAimRemoteLayout.h"
.section __TEXT,__silent,regular,pure_instructions
.p2align 14
.globl _SilentAimMappingFixtureStart
.globl _SilentAimMappingFixtureEnd
_SilentAimMappingFixtureStart:
#if defined(__aarch64__) || defined(__arm64__)
    adr x8, Lstate
    ldr w0, [x8]
    ret
#elif defined(__x86_64__)
    movl Lstate(%rip), %eax
    ret
#else
#error Unsupported mapping test architecture
#endif
.org SILENT_REMOTE_PAGE, 0
_SilentAimMappingFixtureEnd:
Lstate:
