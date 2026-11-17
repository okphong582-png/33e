.section __DATA_CONST,__const
.p2align 3
.private_extern _mizze_ifix_start
.private_extern _mizze_ifix_end
.globl _mizze_ifix_start
.globl _mizze_ifix_end
_mizze_ifix_start:
.incbin "ifix/Assembly-CSharp-patch.bytes"
_mizze_ifix_end:
