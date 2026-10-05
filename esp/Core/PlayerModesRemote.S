#include "PlayerModesLayout.h"
#ifdef __APPLE__
.section __TEXT,__playermodes,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _PlayerModesRemoteStart
.globl _PlayerModesRemoteEnd
// Wrap virtual OnUpdate(self, dt, time, MethodInfo). Incoming interpolation,
// health, weapon and animation logic still run; no outgoing packets are hooked.
_PlayerModesRemoteStart:
    stp x29, x30, [sp, #-144]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d0, d1, [sp, #96]
    adr x19, .LmodesState
    mov x20, x0
    mov x21, x1
    add x8, x19, #MODES_BUSY
    ldaxr w9, [x8]
    cbnz w9, .Lreserved
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, .Ltail
    mov x22, #0
    mov x26, #0
    add x8, x19, #MODES_ROWS
    mov w9, #MODES_CAPACITY
.LfindRow:
    ldr x10, [x8, #ROW_PLAYER]
    cmp x10, x20
    b.eq .LfoundRow
    cbnz x10, .LnextRow
    cmp x26, #0
    csel x26, x8, x26, eq
.LnextRow:
    add x8, x8, #MODES_ROW_SIZE
    subs w9, w9, #1
    b.ne .LfindRow
    b .Loriginal
.LfoundRow:
    mov x22, x8
    ldr w8, [x22, #ROW_MODE]
    cbz w8, .Loriginal
    // Restore only an unchanged visual override for the same living context.
    // A newly arrived correction/teleport wins over our saved real position.
    mov x0, #0
    ldr x8, [x19, #MODES_CURRENT_MATCH]
    blr x8
    cbz x0, .LdropBefore
    ldr x8, [x22, #ROW_MATCH]
    cmp x0, x8
    b.ne .LdropBefore
    ldr x8, [x0, #0xD8]
    ldr x9, [x22, #ROW_LOCAL]
    cmp x8, x9
    b.ne .LdropBefore
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_HP]
    blr x8
    cmp w0, #0
    b.le .LdropBefore
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_GET_POS]
    blr x8
    fmov w8, s0
    fmov w9, s1
    fmov w10, s2
    ldp w11, w12, [x22, #ROW_SHOWN]
    ldr w13, [x22, #(ROW_SHOWN+8)]
    cmp w8, w11
    b.ne .Loriginal
    cmp w9, w12
    b.ne .Loriginal
    cmp w10, w13
    b.ne .Loriginal
    ldp s0, s1, [x22, #ROW_REAL]
    ldr s2, [x22, #(ROW_REAL+8)]
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_SET_POS]
    blr x8
    ldr x8, [x19, #MODES_RESTORES]
    add x8, x8, #1
    str x8, [x19, #MODES_RESTORES]
    b .Loriginal
.LdropBefore:
    str xzr, [x22, #ROW_PLAYER]
    str wzr, [x22, #ROW_MODE]
    mov x26, x22
    mov x22, #0
.Loriginal:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldr x8, [x19, #MODES_ORIGINAL]
    blr x8
    ldr x8, [x19, #MODES_TICKS]
    add x8, x8, #1
    str x8, [x19, #MODES_TICKS]
    add x8, x19, #MODES_SEQUENCE
    ldar w24, [x8]
    tbnz w24, #0, .Ldrop
    ldr w25, [x19, #MODES_FLAGS]
    cbz w25, .Ldrop
    cmp w25, #3
    b.hi .Ldrop
    ldr x8, [x19, #MODES_CLOCK]
    blr x8
    ldr x8, [x19, #MODES_DEADLINE]
    cmp x0, x8
    b.hi .Ldrop
    ldr x27, [x19, #MODES_MATCH]
    ldr x28, [x19, #MODES_LOCAL]
    cbz x27, .Ldrop
    cbz x28, .Ldrop
    mov x0, #0
    ldr x8, [x19, #MODES_CURRENT_MATCH]
    blr x8
    cmp x0, x27
    b.ne .Ldrop
    ldr x8, [x27, #0xD8]
    cmp x8, x28
    b.ne .Ldrop
    add x8, x28, #0x1000
    ldrb w8, [x8, #0x258]
    cbnz w8, .Ldrop
    cmp x20, x28
    b.ne .Lenemy
    tbz w25, #1, .Ldrop
    mov w25, #2
    b .Lhealth
.Lenemy:
    tbz w25, #0, .Ldrop
    ldr w9, [x19, #MODES_COUNT]
    cbz w9, .Ldrop
    cmp w9, #MODES_CAPACITY
    b.hi .Ldrop
    add x8, x19, #MODES_PLAYERS
.LfindEnemy:
    ldr x10, [x8], #8
    cmp x10, x20
    b.eq .LenemyFound
    subs w9, w9, #1
    b.ne .LfindEnemy
    b .Ldrop
.LenemyFound:
    mov w25, #1
.Lhealth:
    add x8, x20, #0x1000
    ldrb w8, [x8, #0x258]
    cbnz w8, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_HP]
    blr x8
    cmp w0, #0
    b.le .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_VEHICLE]
    blr x8
    cbnz w0, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_PARACHUTE]
    blr x8
    cbnz w0, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_WAIT_SYNC]
    blr x8
    cbnz w0, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_GET_POS]
    blr x8
    // Finite world coordinates, bounded before applying the shallow offset.
    mov w8, #0x2400
    movk w8, #0x4974, lsl #16
    fmov s3, w8
    fabs s4, s0
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    fabs s4, s1
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    fabs s4, s2
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    add x8, x19, #MODES_SEQUENCE
    ldar w8, [x8]
    cmp w8, w24
    b.ne .Ldrop
    cbnz x22, .LhaveRow
    cbz x26, .Lunlock
    mov x22, x26
.LhaveRow:
    stp s0, s1, [x22, #ROW_REAL]
    str s2, [x22, #(ROW_REAL+8)]
    cmp w25, #2
    b.eq .Lburrow
    // Keep the first position in this scoped epoch; normal interpolation has
    // already advanced, so latest real coordinates remain available on release.
    ldr w8, [x22, #ROW_MODE]
    cmp w8, #1
    b.ne .LcaptureShown
    ldr w8, [x22, #ROW_EPOCH]
    ldr w9, [x19, #MODES_EPOCH]
    cmp w8, w9
    b.ne .LcaptureShown
    ldr x8, [x22, #ROW_MATCH]
    cmp x8, x27
    b.ne .LcaptureShown
    ldr x8, [x22, #ROW_LOCAL]
    cmp x8, x28
    b.ne .LcaptureShown
    ldp s0, s1, [x22, #ROW_SHOWN]
    ldr s2, [x22, #(ROW_SHOWN+8)]
    b .Lapply
.Lburrow:
    // Always offset the fresh normal position, never the previous lowered one.
    // Do not disable gravity or collisions, or replace the physics controller.
    mov w8, #0x6666
    movk w8, #0x3ee6, lsl #16 // 0.45 m
    fmov s3, w8
    fsub s1, s1, s3
.LcaptureShown:
    stp s0, s1, [x22, #ROW_SHOWN]
    str s2, [x22, #(ROW_SHOWN+8)]
.Lapply:
    str x20, [x22, #ROW_PLAYER]
    str x27, [x22, #ROW_MATCH]
    str x28, [x22, #ROW_LOCAL]
    ldr w8, [x19, #MODES_EPOCH]
    str w8, [x22, #ROW_EPOCH]
    str w25, [x22, #ROW_MODE]
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_SET_POS]
    blr x8
    ldr x8, [x19, #MODES_APPLIES]
    add x8, x8, #1
    str x8, [x19, #MODES_APPLIES]
    b .Lunlock
.Ldrop:
    cbz x22, .Lunlock
    str xzr, [x22, #ROW_PLAYER]
    str wzr, [x22, #ROW_MODE]
.Lunlock:
    add x8, x19, #MODES_BUSY
    stlr wzr, [x8]
    b .Lreturn
.Lreserved:
    clrex
.Ltail:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldr x8, [x19, #MODES_ORIGINAL]
    blr x8
.Lreturn:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #144
    ret
.org MODES_PAGE, 0
_PlayerModesRemoteEnd:
.LmodesState:
