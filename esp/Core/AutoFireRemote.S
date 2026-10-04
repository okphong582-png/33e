#include "AutoFireRemoteLayout.h"
#ifdef __APPLE__
.section __TEXT,__autofire,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _AutoFireRemoteStart
.globl _AutoFireRemoteEnd
_AutoFireRemoteStart:
    // Weapon.MAMFDNEJAPF(self, float dt, float time, MethodInfo*).
    // Player.PostUpdate calls this virtual slot even while the gun is idle.
    // Preserve the caller ABI and issue input only for the current local gun.
    stp x29, x30, [sp, #-112]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp d0, d1, [sp, #80]
    adr x19, .LautoState
    mov x20, x0
    mov x21, x1
    ldr x25, [x19, #AUTO_LOCAL]
    cbz x25, .LautoTail
    ldr x8, [x20, #0x60]
    cmp x8, x25
    b.ne .LautoTail
    ldr x8, [x19, #AUTO_WEAPON]
    cmp x8, x20
    b.eq .LautoRelevant
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x20
    b.ne .LautoTail
.LautoRelevant:
    ldr w8, [x19, #AUTO_ENABLED]
    ldr x9, [x19, #AUTO_HELD]
    orr x8, x8, x9
    cbz x8, .LautoTail          // OFF with no owned hold: no native getter work
    ldr x8, [x19, #AUTO_TICKS]
    add x8, x8, #1
    str x8, [x19, #AUTO_TICKS]
    add x8, x19, #AUTO_BUSY
    ldaxr w9, [x8]
    cbnz w9, .LautoReserved
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, .LautoTail
    mov x0, x25
    mov x1, #0
    ldr x8, [x19, #AUTO_GET_WEAPON]
    blr x8
    mov x22, x0
    // Only use a current weapon. Never dereference a saved weapon after a swap.
    cbz x22, .LautoForget
    cmp x22, x20
    b.ne .LautoForget
    ldr x8, [x22, #0x60]
    cmp x8, x25
    b.ne .LautoForget
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.eq .LautoSnapshot
    str xzr, [x19, #AUTO_HELD]
.LautoSnapshot:
    add x8, x19, #AUTO_SEQUENCE
    ldar w23, [x8]
    tbnz w23, #0, .LautoRelease
    ldr w8, [x19, #AUTO_ENABLED]
    cbz w8, .LautoRelease
    ldr x8, [x19, #AUTO_WEAPON]
    cmp x8, x22
    b.ne .LautoRelease
    ldr x8, [x19, #AUTO_MATCH]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0xD8]
    cmp x8, x25
    b.ne .LautoRelease
    add x8, x25, #0x1000
    ldrb w8, [x8, #0x258]
    cbnz w8, .LautoRelease
    ldr x24, [x19, #AUTO_DEADLINE]
    ldr x8, [x19, #AUTO_CLOCK]
    blr x8
    cmp x0, x24
    b.hi .LautoRelease
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    // A shot event is not a persistent trigger. Leave manual fire alone, but
    // repeat owned shots at Weapon.LDKCJEMDAMC's native interval, as the game's
    // firing-state ticks do. PRI21 == 2 must not suppress our next owned shot.
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.eq .LautoCadence
    ldr x8, [x25, #0x70]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0x10]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0xC8]
    cbz x8, .LautoRelease
    ldrh w8, [x8, #0x18]
    cmp w8, #2
    b.eq .LautoUnlock
    str wzr, [sp, #96]        // first shot has no carried cadence time
    b .LautoMethods
.LautoCadence:
    ldr s0, [sp, #80]          // caller's dt, saved before any native call
    fcmp s0, #0.0
    b.vs .LautoRelease
    b.le .LautoUnlock
    fmov s1, #1.0
    fcmp s0, s1
    b.gt .LautoRelease         // reject invalid/stale simulation deltas
    ldr s1, [x19, #AUTO_ELAPSED]
    fadd s0, s0, s1
    str s0, [x19, #AUTO_ELAPSED]
    mov x0, x22
    mov x1, #0
    ldr x8, [x19, #AUTO_INTERVAL]
    blr x8
    fmov w8, s0
    ubfx w8, w8, #23, #8
    cmp w8, #255
    b.eq .LautoRelease         // reject NaN/infinite native intervals
    fcmp s0, #0.0
    b.vs .LautoRelease
    b.le .LautoRelease
    ldr s1, [x19, #AUTO_ELAPSED]
    fcmp s1, s0
    b.lt .LautoUnlock
    // Keep the fractional firing time instead of
    // discarding it every shot, capped at dt. Still at most one shot per tick.
    fsub s1, s1, s0
    ldr s2, [sp, #80]
    fmin s1, s1, s2
    str s1, [sp, #96]
    // The interval method may run a hotfix. Recheck publication after it.
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
.LautoMethods:
    // Ensure the weapon still uses the statically verified input methods.
    ldr x8, [x22]
    ldr x9, [x8, #0xC98]       // virtual 182: ALJMFCJMDCF()
    ldr x10, [x19, #AUTO_START]
    cmp x9, x10
    b.ne .LautoRelease
    ldr x9, [x8, #0xE88]       // virtual 213: NFFJEBKJCAK()
    ldr x10, [x19, #AUTO_STOP]
    cmp x9, x10
    b.ne .LautoRelease
    ldr x26, [x19, #AUTO_SILENT_GATE]
    cbz x26, .LautoRelease
    stlr x22, [x26]            // only this native shot may bypass manual PRI21
    mov x0, x22
    ldr x1, [x8, #0xCA0]
    ldr x8, [x19, #AUTO_START]
    blr x8
    stlr xzr, [x26]
    ldr w8, [sp, #96]
    str w8, [x19, #AUTO_ELAPSED]
    str x22, [x19, #AUTO_HELD]
    ldr x8, [x19, #AUTO_STARTS]
    add x8, x8, #1
    str x8, [x19, #AUTO_STARTS]
    b .LautoUnlock
.LautoRelease:
    str wzr, [x19, #AUTO_ELAPSED]
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.ne .LautoUnlock
    str xzr, [x19, #AUTO_HELD]
    ldr x8, [x22]
    ldr x9, [x8, #0xE88]
    ldr x10, [x19, #AUTO_STOP]
    cmp x9, x10
    b.ne .LautoUnlock
    mov x0, x22
    ldr x1, [x8, #0xE90]
    blr x9
    b .LautoUnlock
.LautoForget:
    str xzr, [x19, #AUTO_HELD]
    str wzr, [x19, #AUTO_ELAPSED]
.LautoUnlock:
    add x8, x19, #AUTO_BUSY
    stlr wzr, [x8]
    b .LautoTail
.LautoReserved:
    clrex
.LautoTail:
    ldr x16, [x19, #AUTO_ORIGINAL]
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    br x16
    .org AUTO_PAGE, 0
_AutoFireRemoteEnd:
.LautoState:
