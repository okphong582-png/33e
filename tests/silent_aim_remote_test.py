"""Emulate the actual copied ARM64 handler, including ABI and restoration.

clang --target=aarch64-linux-gnu -c esp/Core/SilentAimRemote.S -o /tmp/silent-remote.o
python3 tests/silent_aim_remote_test.py /tmp/silent-remote.o
clang --target=arm64-apple-ios16.5 -c esp/Core/SilentAimRemote.S -o /tmp/silent-remote-ios.o
python3 tests/silent_aim_remote_test.py /tmp/silent-remote-ios.o
"""
import math
import struct
import sys
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import (
    UC_ARM64_REG_PC, UC_ARM64_REG_SP, UC_ARM64_REG_X0, UC_ARM64_REG_X1,
    UC_ARM64_REG_X19, UC_ARM64_REG_X20, UC_ARM64_REG_X21, UC_ARM64_REG_X22,
    UC_ARM64_REG_X23, UC_ARM64_REG_X24, UC_ARM64_REG_X25, UC_ARM64_REG_X26,
    UC_ARM64_REG_X27, UC_ARM64_REG_X28, UC_ARM64_REG_X29, UC_ARM64_REG_X30,
)

def code_from_elf(data):
    assert data[:6] == b"\x7fELF\x02\x01"
    offset, = struct.unpack_from("<Q", data, 40)
    size, count, strings = struct.unpack_from("<HHH", data, 58)
    sections = [struct.unpack_from("<IIQQQQIIQQ", data, offset + i * size) for i in range(count)]
    names = data[sections[strings][4]:sections[strings][4]+sections[strings][5]]
    code = None
    for section in sections:
        name = names[section[0]:].split(b"\0", 1)[0]
        assert not (section[1] in (4, 9) and section[5]), "Copied code must have no relocations"
        if name == b".text":
            code = data[section[4]:section[4]+section[5]]
    assert code is not None and len(code) == 0x4000
    return code

def code_from_macho(data):
    magic, cpu, _, filetype, commands, _, _, _ = struct.unpack_from("<IiiIIIII", data)
    assert magic == 0xFEEDFACF and cpu == 0x0100000C and filetype == 1
    offset, code, symbols = 32, None, {}
    for _ in range(commands):
        command, size = struct.unpack_from("<II", data, offset)
        if command == 0x19:  # LC_SEGMENT_64
            count, = struct.unpack_from("<I", data, offset + 64)
            for i in range(count):
                section = struct.unpack_from("<16s16sQQIIIIIIII", data, offset + 72 + i * 80)
                if section[0].rstrip(b"\0") != b"__silent":
                    continue
                assert section[1].rstrip(b"\0") == b"__TEXT"
                assert section[2] == 0 and section[3] == 0x4000
                assert section[5] == 14, "Copied code must be page-aligned"
                assert section[7] == 0, "Copied code must have no relocations"
                code = data[section[4]:section[4]+section[3]]
        elif command == 2:  # LC_SYMTAB
            table, count, strings, _ = struct.unpack_from("<IIII", data, offset + 8)
            for i in range(count):
                name, _, _, _, value = struct.unpack_from("<IBBHQ", data, table + i * 16)
                name = data[strings+name:].split(b"\0", 1)[0]
                symbols[name] = value
        offset += size
    assert code is not None and len(code) == 0x4000
    assert symbols[b"_SilentAimRemoteStart"] == 0
    assert symbols[b"_SilentAimRemoteEnd"] == 0x4000
    return code

data = open(sys.argv[1], "rb").read()
CODE = code_from_elf(data) if data[:4] == b"\x7fELF" else code_from_macho(data)
BASE, STATE, ORIGINAL, CLOCK, STOP = 0x100000, 0x104000, 0x120000, 0x120100, 0x120200
LOCAL, HANDLER, WEAPON, INFO, INFO_CLASS, MATCH = 0x200000, 0x210000, 0x220000, 0x230000, 0x240000, 0x250000
POOL, ENTRIES, ENTRY, STACK, METHOD = 0x260000, 0x270000, 0x280000, 0x300000, 0xAABBCC
SAVED = [UC_ARM64_REG_X19, UC_ARM64_REG_X20, UC_ARM64_REG_X21, UC_ARM64_REG_X22,
         UC_ARM64_REG_X23, UC_ARM64_REG_X24, UC_ARM64_REG_X25, UC_ARM64_REG_X26,
         UC_ARM64_REG_X27, UC_ARM64_REG_X28, UC_ARM64_REG_X29]

def case(*, enabled=1, sequence=2, now=100, deadline=110, firing=2,
         knocked=0, busy=0, owner=LOCAL, match_local=LOCAL, handler=HANDLER,
         info_class=INFO_CLASS, head=(3., 4., 0.), origin=(0., 0., 0.),
         body=(0., 0., 2.), head_percent=100, phase=0,
         direction=(0., 0., 1.), original_action=None, clock_action=None, dispatches=1, auto_weapon=0):
    uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
    uc.mem_map(BASE, 0x30000)
    uc.mem_map(LOCAL, 0x90000)
    uc.mem_map(STACK, 0x10000)
    uc.mem_write(BASE, CODE)
    uc.mem_write(ORIGINAL, b"\xc0\x03\x5f\xd6") # ret
    uc.mem_write(CLOCK, b"\xc0\x03\x5f\xd6")
    def u64(a, v): uc.mem_write(a, struct.pack("<Q", v))
    def u32(a, v): uc.mem_write(a, struct.pack("<I", v))
    def point(a, v): uc.mem_write(a, struct.pack("<fff", *v))
    u64(STATE, ORIGINAL); u64(STATE+8, CLOCK)
    u32(STATE+16, sequence); u32(STATE+20, enabled); u64(STATE+24, deadline)
    u64(STATE+32, LOCAL); u64(STATE+40, handler); u64(STATE+48, info_class)
    point(STATE+56, head); u32(STATE+80, busy); u64(STATE+96, MATCH)
    point(STATE+104, body); u32(STATE+116, head_percent); u32(STATE+120, phase)
    u64(STATE+128, auto_weapon)
    u64(HANDLER+0x10, WEAPON); u64(HANDLER+0x28, INFO)
    u64(WEAPON+0x60, owner); u64(WEAPON+0x80, HANDLER); u64(INFO, INFO_CLASS)
    u64(MATCH+0xD8, match_local); uc.mem_write(LOCAL+0x1258, bytes([knocked]))
    u64(LOCAL+0x70, POOL); u64(POOL+0x10, ENTRIES); u64(ENTRIES+0xC8, ENTRY)
    uc.mem_write(ENTRY+0x18, struct.pack("<H", firing))
    point(INFO+0x40, direction); point(INFO+0x4C, origin)
    uc.reg_write(UC_ARM64_REG_X0, HANDLER); uc.reg_write(UC_ARM64_REG_X1, METHOD)
    uc.reg_write(UC_ARM64_REG_X30, STOP); uc.reg_write(UC_ARM64_REG_SP, STACK+0x8000)
    saved = {r:0xABC000+i for i, r in enumerate(SAVED)}
    for r, v in saved.items(): uc.reg_write(r, v)
    calls, observed = [], []
    def hook(uc, address, size, _):
        if address == CLOCK:
            if clock_action: clock_action(uc, u32)
            uc.reg_write(UC_ARM64_REG_X0, now)
        elif address == ORIGINAL:
            calls.append((uc.reg_read(UC_ARM64_REG_X0), uc.reg_read(UC_ARM64_REG_X1)))
            observed.append(struct.unpack("<fff", uc.mem_read(INFO+0x40, 12)))
            if original_action: original_action(uc, u64, point)
    uc.hook_add(UC_HOOK_CODE, hook)
    for _ in range(dispatches):
        uc.reg_write(UC_ARM64_REG_X0, HANDLER); uc.reg_write(UC_ARM64_REG_X1, METHOD)
        uc.reg_write(UC_ARM64_REG_X30, STOP)
        uc.emu_start(BASE, STOP, count=2000)
        assert uc.reg_read(UC_ARM64_REG_PC) == STOP, "Callback did not return"
        assert uc.reg_read(UC_ARM64_REG_SP) == STACK+0x8000
        assert all(uc.reg_read(r) == v for r, v in saved.items()), "Callee-saved registers corrupted"
    assert calls == [(HANDLER, METHOD)]*dispatches, calls
    redirects, = struct.unpack("<Q", uc.mem_read(STATE+72, 8))
    live_busy, = struct.unpack("<I", uc.mem_read(STATE+80, 4))
    assert live_busy == busy, "Dispatch lock leaked"
    restored = struct.unpack("<fff", uc.mem_read(INFO+0x40, 12))
    return observed[0] if dispatches==1 else observed, restored, redirects

seen, restored, redirects = case()
assert all(math.isclose(v, w, abs_tol=1e-6) for v, w in zip(seen, (.6, .8, 0.)))
assert restored == (0., 0., 1.) and redirects == 1
seen, restored, redirects = case(head_percent=0, body=(2., 0., 0.))
assert seen == (1., 0., 0.) and restored == (0., 0., 1.) and redirects == 1
seen, restored, redirects = case(firing=0, auto_weapon=WEAPON)
assert redirects == 1 and restored == (0., 0., 1.)
assert case(firing=0, auto_weapon=WEAPON+8)[2] == 0
for arguments in [dict(enabled=0), dict(sequence=3), dict(now=111), dict(firing=0),
                  dict(head_percent=101), dict(head_percent=0,body=(float("nan"),0.,0.)),
                  dict(knocked=1), dict(busy=1), dict(owner=LOCAL+8),
                  dict(match_local=LOCAL+8), dict(handler=HANDLER+8), dict(info_class=INFO_CLASS+8),
                  dict(head=(float("nan"), 0., 0.)), dict(origin=(float("inf"), 0., 0.)),
                  dict(head=(.001, 0., 0.)), dict(head=(0., 0., 0.)),
                  dict(clock_action=lambda uc, write: write(STATE+16, 4))]:
    seen, restored, redirects = case(**arguments)
    assert seen == restored == (0., 0., 1.) and redirects == 0, arguments
for arguments in [dict(enabled=0),dict(sequence=3),dict(now=111),dict(knocked=1),
                  dict(owner=LOCAL+8),dict(match_local=LOCAL+8),dict(busy=1)]:
    assert case(firing=0, auto_weapon=WEAPON, **arguments)[2] == 0, arguments

seen, restored, redirects = case(head=(3e38, 0., 0.), origin=(-3e38, 0., 0.))
assert seen == (1., 0., 0.) and restored == (0., 0., 1.) and redirects == 1
seen, restored, _ = case(original_action=lambda uc, ptr, point: point(INFO+0x40, (.2, .3, .4)))
assert all(math.isclose(v, w, abs_tol=1e-6) for v, w in zip(restored, (.2, .3, .4)))
seen, restored, _ = case(original_action=lambda uc, ptr, point: ptr(HANDLER+0x28, INFO+0x100))
assert seen == restored, "Replaced aiming-info must not be restored"
seen, restored, _ = case(original_action=lambda uc, ptr, point: ptr(HANDLER+0x10, WEAPON+0x100))
assert seen == restored, "Replaced weapon must not be restored"
for percent in [0,25,75,100]:
    seen,restored,redirects=case(head_percent=percent,phase=50,body=(2.,0.,0.),dispatches=100)
    heads=sum(math.isclose(p[1],.8,abs_tol=1e-6) for p in seen)
    assert heads==percent and redirects==100 and restored==(0.,0.,1.)
print("ARM64 remote direction callback: ABI, publication, expiry, ownership and restoration passed.")
