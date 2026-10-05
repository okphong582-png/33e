"""Execute the shipped ARM64 Ghost callbacks, with native game methods stubbed.

Checks client ABI, owner/lease guards and reversible scalar serialization only.
This cannot establish server acceptance or the opponent's rendered position.
"""
import math
import pathlib
import re
import struct
import sys
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import *


def read_code(path):
    data = pathlib.Path(path).read_bytes()
    code = None
    if data[:4] == b'\x7fELF':
        offset, = struct.unpack_from('<Q', data, 40)
        size, count, strings = struct.unpack_from('<HHH', data, 58)
        sections = [struct.unpack_from('<IIQQQQIIQQ', data, offset+i*size) for i in range(count)]
        names = data[sections[strings][4]:sections[strings][4]+sections[strings][5]]
        for s in sections:
            assert not (s[1] in (4, 9) and s[5]), 'No runtime relocations allowed'
            if names[s[0]:].split(b'\0', 1)[0] == b'.text':
                assert s[8] == 0x4000
                code = data[s[4]:s[4]+s[5]]
    else:
        p = 32
        for _ in range(struct.unpack_from('<I', data, 16)[0]):
            command, size = struct.unpack_from('<II', data, p)
            if command == 0x19:
                for i in range(struct.unpack_from('<I', data, p+64)[0]):
                    s = struct.unpack_from('<16s16sQQIIIIIIII', data, p+72+i*80)
                    if s[0].rstrip(b'\0') == b'__ghost':
                        assert s[1].rstrip(b'\0') == b'__TEXT'
                        assert s[2] == 0 and s[5] == 14 and s[7] == 0
                        code = data[s[4]:s[4]+s[3]]
            p += size
    assert code is not None and len(code) == 0x4000
    return code


CODE = read_code(sys.argv[1])
HEADER = (pathlib.Path(__file__).parent.parent / 'esp/Core/GhostRemoteLayout.h').read_text()
OFF = {k: int(v, 0) for k, v in re.findall(r'^#define GHOST_(\w+) (0x[0-9a-fA-F]+|\d+)$', HEADER, re.M)}
BASE, STATE, NATIVE, RETURN, STACK = 0x100000, 0x104000, 0x120000, 0x123000, 0x300000
MATCH, LOCAL, PACKET, AXIS_PACKET = 0x200000, 0x210000, 0x220000, 0x230000
BODY, POS, VEL, AXIS_BODY, VECTORS = 0x240000, 0x250000, 0x260000, 0x270000, 0x280000
BODY_CLASS, POS_CLASS, VEL_CLASS, AXIS_CLASS = 0x2c0000, 0x2c0100, 0x2c0200, 0x2c0300
GUARDS = ['WAIT_SYNC', 'VEHICLE', 'CATAPULT', 'CANNON', 'CHAIR', 'CHAIR_ALT',
          'PARACHUTE', 'STROP', 'RAIL', 'SEESAW', 'PLATFORM']
FUNCTIONS = ['TICK', 'POSITION', 'AXIS', 'CLOCK', 'CURRENT_MATCH', 'GET_POS', 'SET_POS', 'HP'] + GUARDS


def f32(v):
    return struct.unpack('<f', struct.pack('<f', v))[0]


def encoded(position):
    bias = struct.unpack('<f', struct.pack('<I', 0x38d1b717))[0]
    return tuple(round(f32(f32(f32(v)+bias)*1000)) for v in position)


class Simulation:
    def __init__(self, position=(12.345, -2.5, 80.125)):
        self.uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        self.uc.mem_map(BASE, 0x30000)
        self.uc.mem_map(MATCH, 0xd0000)
        self.uc.mem_map(STACK, 0x10000)
        self.uc.mem_write(BASE, CODE)
        self.functions = {name: NATIVE+i*0x100 for i, name in enumerate(FUNCTIONS)}
        self.native = {v: k for k, v in self.functions.items()}
        for name, address in self.functions.items():
            self.uc.mem_write(address, b'\xc0\x03\x5f\xd6')
            self.q(name, address)
        self.now, self.hp, self.current_match = 100, 100, MATCH
        self.guards = {name: 0 for name in GUARDS}
        self.local_position = tuple(f32(v) for v in position)
        self.calls, self.observed, self.teleports = [], [], []
        self.action = None
        self.kind = None
        for name, value in [('SEQUENCE', 2), ('COMMAND', 1), ('EPOCH', 1)]:
            self.w(name, value)
        for name, value in [('DEADLINE', 110), ('MATCH', MATCH), ('LOCAL', LOCAL),
                            ('PACKET', PACKET), ('AXIS_PACKET', AXIS_PACKET),
                            ('BODY_CLASS', BODY_CLASS), ('POS_CLASS', POS_CLASS),
                            ('VEL_CLASS', VEL_CLASS), ('AXIS_CLASS', AXIS_CLASS)]:
            self.q(name, value)
        self.ptr(MATCH+0xd8, LOCAL)
        self.ptr(MATCH+0x660, PACKET)
        self.ptr(MATCH+0x668, AXIS_PACKET)
        # Fill whole pooled objects to detect writes to unrelated IDs/state.
        for i, address in enumerate([PACKET, AXIS_PACKET, BODY, POS, VEL, AXIS_BODY] +
                                    [VECTORS+j*0x100 for j in range(4)]):
            self.uc.mem_write(address, bytes((n+i*17)%256 for n in range(0x80)))
        self.ptr(PACKET+0x18, BODY)
        self.ptr(AXIS_PACKET+0x18, AXIS_BODY)
        self.ptr(BODY, BODY_CLASS)
        self.ptr(BODY+0x18, POS)
        self.ptr(BODY+0x30, VEL)
        self.ptr(POS, POS_CLASS)
        self.ptr(VEL, VEL_CLASS)
        self.ptr(AXIS_BODY, AXIS_CLASS)
        for i in range(4):
            self.ptr(AXIS_BODY+0x18+i*8, VECTORS+i*0x100)
            self.ptr(VECTORS+i*0x100, POS_CLASS)
        self.uc.hook_add(UC_HOOK_CODE, self.hook)

    def ptr(self, address, value):
        self.uc.mem_write(address, struct.pack('<Q', value))

    def q(self, name, value=None):
        address = STATE+OFF[name]
        if value is not None:
            self.ptr(address, value)
        return struct.unpack('<Q', self.uc.mem_read(address, 8))[0]

    def w(self, name, value=None):
        address = STATE+OFF[name]
        if value is not None:
            self.uc.mem_write(address, struct.pack('<I', value))
        return struct.unpack('<I', self.uc.mem_read(address, 4))[0]

    def anchor(self):
        return struct.unpack('<fff', self.uc.mem_read(STATE+OFF['ANCHOR'], 12))

    def ints(self, address):
        return struct.unpack('<iii', self.uc.mem_read(address+0x14, 12))

    def game_bytes(self):
        return bytes(self.uc.mem_read(MATCH, 0xd0000))

    def hook(self, uc, address, size, _):
        name = self.native.get(address)
        if name is None:
            return
        self.calls.append(name)
        if self.action:
            self.action(name, self)
        x0, x1, x2 = (uc.reg_read(r) for r in (UC_ARM64_REG_X0, UC_ARM64_REG_X1, UC_ARM64_REG_X2))
        if name in ('TICK', 'POSITION', 'AXIS'):
            assert name == self.kind
            assert (x0, x1, x2) == self.args, (name, x0, x1, x2, self.args)
            if name == 'TICK':
                assert uc.reg_read(UC_ARM64_REG_D0) == 0x3d800000
                assert uc.reg_read(UC_ARM64_REG_D1) == 0x41200000
                assert self.w('BUSY') == 0 or self.initial_busy
            elif name == 'POSITION':
                self.observed.append((self.ints(POS), bytes(uc.mem_read(VEL+0x12, 6)),
                                      bytes(uc.mem_read(BODY+0x38, 2)), self.game_bytes()))
            else:
                vectors = [struct.unpack('<Q', uc.mem_read(AXIS_BODY+0x18+i*8, 8))[0] for i in range(4)]
                self.observed.append(tuple(self.ints(vector) if vector else None for vector in vectors))
        elif name == 'CLOCK':
            uc.reg_write(UC_ARM64_REG_X0, self.now)
        elif name == 'CURRENT_MATCH':
            assert self.kind == 'TICK' and x0 == 0
            uc.reg_write(UC_ARM64_REG_X0, self.current_match)
        else:
            assert self.kind == 'TICK' and (x0, x1) == (LOCAL, 0), name
            if name == 'HP':
                uc.reg_write(UC_ARM64_REG_X0, self.hp & 0xffffffff)
            elif name in GUARDS:
                uc.reg_write(UC_ARM64_REG_X0, self.guards[name])
            elif name == 'GET_POS':
                for reg, value in zip((UC_ARM64_REG_S0, UC_ARM64_REG_S1, UC_ARM64_REG_S2), self.local_position):
                    uc.reg_write(reg, struct.unpack('<I', struct.pack('<f', value))[0])
            elif name == 'SET_POS':
                value = tuple(struct.unpack('<f', struct.pack('<I', uc.reg_read(reg)))[0]
                              for reg in (UC_ARM64_REG_S0, UC_ARM64_REG_S1, UC_ARM64_REG_S2))
                self.teleports.append(value)
                self.local_position = value
        # Native methods may clobber caller-saved scratch registers.
        for reg in (UC_ARM64_REG_X8, UC_ARM64_REG_X9, UC_ARM64_REG_X10, UC_ARM64_REG_X11, UC_ARM64_REG_X12):
            uc.reg_write(reg, 0xdeadbeef)

    def run(self, kind='TICK', self_object=None):
        self.kind = kind
        self.initial_busy = self.w('BUSY')
        entry = BASE + {'TICK': 0, 'POSITION': 0x1000, 'AXIS': 0x2000}[kind]
        self.args = (self_object or {'TICK': MATCH, 'POSITION': PACKET, 'AXIS': AXIS_PACKET}[kind], 0x1234, 0x5678)
        for reg, value in zip((UC_ARM64_REG_X0, UC_ARM64_REG_X1, UC_ARM64_REG_X2), self.args):
            self.uc.reg_write(reg, value)
        self.uc.reg_write(UC_ARM64_REG_D0, 0x3d800000)
        self.uc.reg_write(UC_ARM64_REG_D1, 0x41200000)
        self.uc.reg_write(UC_ARM64_REG_SP, STACK+0x8000)
        self.uc.reg_write(UC_ARM64_REG_X30, RETURN)
        saved = {reg: 0xfff000+i for i, reg in enumerate((UC_ARM64_REG_X19, UC_ARM64_REG_X20,
                 UC_ARM64_REG_X21, UC_ARM64_REG_X22, UC_ARM64_REG_X23, UC_ARM64_REG_X24,
                 UC_ARM64_REG_X25, UC_ARM64_REG_X26, UC_ARM64_REG_X27, UC_ARM64_REG_X28, UC_ARM64_REG_X29))}
        for reg, value in saved.items():
            self.uc.reg_write(reg, value)
        start = len(self.calls)
        self.uc.emu_start(entry, RETURN, count=3000)
        assert self.uc.reg_read(UC_ARM64_REG_PC) == RETURN, 'Callback failed to return'
        assert self.uc.reg_read(UC_ARM64_REG_SP) == STACK+0x8000
        for reg, value in saved.items():
            assert self.uc.reg_read(reg) == value, (kind, reg)
        assert self.calls[start:].count(kind) == 1, 'Original must run exactly once'
        assert self.w('BUSY') == self.initial_busy
        assert self.w('OUT_SEQUENCE') % 2 == 0
        if kind != 'TICK':
            assert all(name in (kind, 'CLOCK') for name in self.calls[start:]), 'Unity API on serializer thread'


s = Simulation()
s.run()
assert s.w('ACTIVE') and s.anchor() == s.local_position
anchor = s.anchor()
s.local_position = (50, 20, 100)
s.run()
assert s.anchor() == anchor and s.calls.count('GET_POS') == 1
before = s.game_bytes()
s.run('POSITION')
assert s.game_bytes() == before, 'Pooled message changed after serialization'
frozen, velocity, pose, observed_bytes = s.observed[-1]
assert frozen == encoded(anchor) and velocity == bytes(6)
expected = bytearray(before)
expected[POS-MATCH+0x14:POS-MATCH+0x20] = struct.pack('<iii', *encoded(anchor))
expected[VEL-MATCH+0x12:VEL-MATCH+0x18] = bytes(6)
assert observed_bytes == expected, 'Unrelated ID/channel/firing/rotation fields changed'
s.uc.mem_write(BODY+0x38, b'\x09\x02')
before = s.game_bytes()
s.run('POSITION')
assert s.observed[-1][2] == pose and s.game_bytes() == before
s.run('AXIS')
assert s.observed[-1] == ((0, 0, 0),)*4 and s.game_bytes() == before
assert s.q('PACKETS') == 2 and s.q('AXES') == 1
s.w('COMMAND', 2); s.w('EPOCH', 2)
s.run()
assert s.teleports == [anchor] and not s.w('ACTIVE') and not s.q('ANCHOR_MATCH')
s.run()
assert s.teleports == [anchor] and s.q('RETURNS') == 1
s.run('POSITION')
assert s.observed[-1][0] == s.ints(POS) and s.game_bytes() == before

# Multiple fields can reference the same pooled vector; restore exact originals.
s = Simulation(); s.run()
for i in range(4): s.ptr(AXIS_BODY+0x18+i*8, VECTORS)
before = s.game_bytes(); s.run('AXIS')
assert s.observed[-1] == ((0, 0, 0),)*4 and s.game_bytes() == before

# Pause/lease failures retain the captured anchor and resume it, never recapture.
for guard in GUARDS + ['lease', 'sequence']:
    s = Simulation(); s.run(); anchor = s.anchor()
    s.local_position = (90, 2, 7)
    if guard in GUARDS: s.guards[guard] = 1
    elif guard == 'lease': s.now = 111
    else: s.w('SEQUENCE', 3)
    s.run(); assert not s.w('ACTIVE') and s.q('ANCHOR_MATCH') == MATCH
    before = s.game_bytes(); s.run('POSITION'); assert s.game_bytes() == before
    assert s.q('PACKETS') == 0 and s.observed[-1][0] == s.ints(POS)
    s.guards = {name: 0 for name in GUARDS}; s.now = 100; s.w('SEQUENCE', 4)
    s.run(); assert s.w('ACTIVE') and s.anchor() == anchor and s.calls.count('GET_POS') == 1

# Return waits out unsupported movement; then executes only once.
s = Simulation(); s.run(); s.w('COMMAND', 2); s.w('EPOCH', 2); s.guards['VEHICLE'] = 1
s.run(); assert not s.teleports
s.guards['VEHICLE'] = 0; s.run(); s.run(); assert len(s.teleports) == 1

# Death, replaced owners and cancel discard rather than teleport a stale entity.
for failure in ['dead', 'negative_hp', 'knocked', 'match', 'local', 'cancel']:
    s = Simulation(); s.run(); s.w('COMMAND', 2)
    if failure == 'dead': s.hp = 0
    elif failure == 'negative_hp': s.hp = -1
    elif failure == 'knocked': s.uc.mem_write(LOCAL+0x1258, b'\x01')
    elif failure == 'match': s.current_match = MATCH+0x1000
    elif failure == 'local': s.ptr(MATCH+0xd8, LOCAL+0x2000)
    else: s.w('COMMAND', 0)
    s.run(); assert not s.w('ACTIVE') and not s.q('ANCHOR_MATCH') and not s.teleports

# Serializer-only races and ownership/class/null/busy guards are read-only bypasses.
for kind in ['POSITION', 'AXIS']:
    for failure in ['self', 'root', 'body_class', 'vector_class', 'null', 'local', 'knocked',
                    'busy', 'sequence', 'epoch', 'lease', 'cancel', 'race']:
        s = Simulation(); s.run(); self_object = None
        body, root = (BODY, PACKET) if kind == 'POSITION' else (AXIS_BODY, AXIS_PACKET)
        if failure == 'self': self_object = root+0x1000
        elif failure == 'root': s.ptr(MATCH+(0x660 if kind == 'POSITION' else 0x668), root+0x1000)
        elif failure == 'body_class': s.ptr(body, BODY_CLASS+0x800)
        elif failure == 'vector_class': s.ptr(POS if kind == 'POSITION' else VECTORS, POS_CLASS+0x800)
        elif failure == 'null': s.ptr(body+0x18, 0)
        elif failure == 'local': s.ptr(MATCH+0xd8, LOCAL+0x2000)
        elif failure == 'knocked': s.uc.mem_write(LOCAL+0x1258, b'\x01')
        elif failure == 'busy': s.w('BUSY', 1)
        elif failure == 'sequence': s.w('SEQUENCE', 3)
        elif failure == 'epoch': s.w('EPOCH', 2)
        elif failure == 'lease': s.now = 111
        elif failure == 'cancel': s.w('COMMAND', 0)
        else: s.action = lambda name, sim: sim.w('SEQUENCE', 4) if name == 'CLOCK' else None
        before = s.game_bytes()
        s.run(kind, self_object)
        assert s.game_bytes() == before and s.q('PACKETS' if kind == 'POSITION' else 'AXES') == 0, (kind, failure)

# Capturing a torn command must not publish an anchor or make a Unity write.
for native in ['CLOCK', 'GET_POS']:
    s = Simulation()
    s.action = lambda name, sim, native=native: sim.w('SEQUENCE', 4) if name == native else None
    s.run(); assert not s.w('ACTIVE') and not s.q('ANCHOR_MATCH') and not s.teleports

# Finite checks and quantization near half-way values, including negative positions.
for value in [math.nan, math.inf, -math.inf, 1000001, -1000001]:
    for axis in range(3):
        position = [1, 2, 3]; position[axis] = value
        s = Simulation(position); s.run()
        assert not s.w('ACTIVE') and not s.q('ANCHOR_MATCH')
for position in [(0, 0, 0), (.0004, -.0006, .0014), (-999999, 1000000, -.5)]:
    s = Simulation(position); s.run(); s.run('POSITION')
    assert s.observed[-1][0] == encoded(position)

# Non-owner updates do not capture; a new epoch captures a new location.
s = Simulation(); s.run(self_object=MATCH+0x1000)
assert not s.w('ACTIVE') and not s.calls.count('GET_POS')
s.run(); s.local_position = (1, 2, 3); s.w('EPOCH', 2); s.run()
assert s.anchor() == (1, 2, 3) and s.calls.count('GET_POS') == 2
s = Simulation(); s.run(); s.w('COMMAND', 2); s.w('EPOCH', 3); s.run()
assert not s.teleports and not s.q('ANCHOR_MATCH'), 'Cancelled epoch must never return'
print('Ghost ARM64: capture, reversible serialization, return, ownership, races and ABI passed')
