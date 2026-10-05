"""Execute shipped player-update callbacks; no live server/physics claim."""
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
        for section in sections:
            assert not (section[1] in (4, 9) and section[5]), 'No runtime relocations'
            if names[section[0]:].split(b'\0', 1)[0] == b'.text':
                assert section[8] == 0x4000
                code = data[section[4]:section[4]+section[5]]
    else:
        p = 32
        for _ in range(struct.unpack_from('<I', data, 16)[0]):
            command, size = struct.unpack_from('<II', data, p)
            if command == 0x19:
                for i in range(struct.unpack_from('<I', data, p+64)[0]):
                    section = struct.unpack_from('<16s16sQQIIIIIIII', data, p+72+i*80)
                    if section[0].rstrip(b'\0') == b'__playermodes':
                        assert section[1].rstrip(b'\0') == b'__TEXT'
                        assert section[2] == 0 and section[5] == 14 and section[7] == 0
                        code = data[section[4]:section[4]+section[3]]
            p += size
    assert code is not None and len(code) == 0x4000
    return code


CODE = read_code(sys.argv[1])
HEADER = (pathlib.Path(__file__).parent.parent / 'esp/Core/PlayerModesLayout.h').read_text()
OFF = {name: int(value, 0) for name, value in re.findall(r'^#define ((?:MODES|ROW)_\w+) (0x[\da-fA-F]+|\d+)$', HEADER, re.M)}
BASE, STATE, NATIVE, RETURN, STACK = 0x100000, 0x104000, 0x120000, 0x130000, 0x600000
LOCAL, ENEMY, OTHER, MATCH = 0x200000, 0x210000, 0x220000, 0x400000
FUNCTIONS = ['ORIGINAL', 'CLOCK', 'CURRENT_MATCH', 'GET_POS', 'SET_POS', 'HP', 'VEHICLE', 'PARACHUTE', 'WAIT_SYNC']


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


class Simulation:
    def __init__(self, flags=3, depth=2.0):
        self.uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        self.uc.mem_map(BASE, 0x40000)
        self.uc.mem_map(LOCAL, 0x240000)
        self.uc.mem_map(STACK, 0x10000)
        self.uc.mem_write(BASE, CODE)
        self.functions = {name: NATIVE+i*0x100 for i, name in enumerate(FUNCTIONS)}
        self.native = {address: name for name, address in self.functions.items()}
        for name, address in self.functions.items():
            self.uc.mem_write(address, b'\xc0\x03\x5f\xd6')
            self.q(name, address)
        self.current_match, self.current_local, self.now = MATCH, LOCAL, 100
        self.positions = {LOCAL: (0, 10, 0), ENEMY: (20, 10, 20), OTHER: (40, 10, 40)}
        self.authoritative = dict(self.positions)
        self.health, self.special = {}, {}
        self.events, self.original_seen, self.writes = [], [], []
        self.action = None
        self.delta = (1, 0, 2)
        self.ptr(MATCH+0xd8, LOCAL)
        self.q('MATCH', MATCH); self.q('LOCAL', LOCAL); self.q('DEADLINE', 110)
        self.w('SEQUENCE', 2); self.w('EPOCH', 1); self.w('FLAGS', flags)
        self.w('COUNT', 1); self.ptr(STATE+OFF['MODES_PLAYERS'], ENEMY)
        self.uc.mem_write(STATE+OFF['MODES_DEPTH'], struct.pack('<f', depth))
        self.uc.hook_add(UC_HOOK_CODE, self.hook)

    def ptr(self, address, value):
        self.uc.mem_write(address, struct.pack('<Q', value))

    def q(self, name, value=None):
        address = STATE+OFF['MODES_'+name]
        if value is not None: self.ptr(address, value)
        return struct.unpack('<Q', self.uc.mem_read(address, 8))[0]

    def w(self, name, value=None):
        address = STATE+OFF['MODES_'+name]
        if value is not None: self.uc.mem_write(address, struct.pack('<I', value))
        return struct.unpack('<I', self.uc.mem_read(address, 4))[0]

    def hook(self, uc, address, size, _):
        name = self.native.get(address)
        if not name: return
        self.events.append(name)
        if self.action: self.action(name, self)
        player = uc.reg_read(UC_ARM64_REG_X0)
        if name == 'ORIGINAL':
            assert player == self.player and uc.reg_read(UC_ARM64_REG_X1) == 0x1234
            assert uc.reg_read(UC_ARM64_REG_D0) == 0x3d800000 and uc.reg_read(UC_ARM64_REG_D1) == 0x41200000
            self.original_seen.append(self.positions[player])
            # Local motion uses the normal transform. Remote interpolation uses
            # the continually advancing incoming state, independent of visuals.
            source = self.positions[player] if player == LOCAL else self.authoritative[player]
            normal = tuple(f32(v+d) for v, d in zip(source, self.delta))
            self.positions[player] = normal
            if player != LOCAL: self.authoritative[player] = normal
        elif name == 'CLOCK': uc.reg_write(UC_ARM64_REG_X0, self.now)
        elif name == 'CURRENT_MATCH':
            assert player == 0
            uc.reg_write(UC_ARM64_REG_X0, self.current_match)
        else:
            assert player == self.player and uc.reg_read(UC_ARM64_REG_X1) == 0, name
            if name == 'HP': uc.reg_write(UC_ARM64_REG_X0, self.health.get(player, 100) & 0xffffffff)
            elif name in ('VEHICLE', 'PARACHUTE', 'WAIT_SYNC'):
                uc.reg_write(UC_ARM64_REG_X0, self.special.get((player, name), 0))
            elif name == 'GET_POS':
                for reg, value in zip((UC_ARM64_REG_S0, UC_ARM64_REG_S1, UC_ARM64_REG_S2), self.positions[player]):
                    uc.reg_write(reg, struct.unpack('<I', struct.pack('<f', value))[0])
            elif name == 'SET_POS':
                value = tuple(struct.unpack('<f', struct.pack('<I', uc.reg_read(reg)))[0]
                              for reg in (UC_ARM64_REG_S0, UC_ARM64_REG_S1, UC_ARM64_REG_S2))
                assert all(math.isfinite(v) for v in value)
                self.writes.append((player, value))
                self.positions[player] = value
        if name not in ('GET_POS', 'SET_POS'):
            uc.reg_write(UC_ARM64_REG_D0, 0); uc.reg_write(UC_ARM64_REG_D1, 0)
        for reg in (UC_ARM64_REG_X8, UC_ARM64_REG_X9, UC_ARM64_REG_X10, UC_ARM64_REG_X11, UC_ARM64_REG_X12, UC_ARM64_REG_X13):
            uc.reg_write(reg, 0xdeadbeef)

    def run(self, player, interface=False, wrapped=True):
        self.player = player
        if player not in self.positions:
            self.positions[player] = (50, 10, 50); self.authoritative[player] = self.positions[player]
        initial_busy, first_call = self.w('BUSY'), len(self.events)
        self.uc.reg_write(UC_ARM64_REG_X0, player); self.uc.reg_write(UC_ARM64_REG_X1, 0x1234)
        self.uc.reg_write(UC_ARM64_REG_D0, 0x3d800000); self.uc.reg_write(UC_ARM64_REG_D1, 0x41200000)
        self.uc.reg_write(UC_ARM64_REG_SP, STACK+0x8000); self.uc.reg_write(UC_ARM64_REG_X30, RETURN)
        saved = {reg: 0xfff000+i for i, reg in enumerate((UC_ARM64_REG_X19, UC_ARM64_REG_X20, UC_ARM64_REG_X21,
            UC_ARM64_REG_X22, UC_ARM64_REG_X23, UC_ARM64_REG_X24, UC_ARM64_REG_X25, UC_ARM64_REG_X26,
            UC_ARM64_REG_X27, UC_ARM64_REG_X28, UC_ARM64_REG_X29))}
        for reg, value in saved.items(): self.uc.reg_write(reg, value)
        entry = BASE
        if interface:
            # Actual metadata: IEntityTicker starts at class vtable slot 4;
            # OnUpdate is interface method 1, hence class slot 5 (0x188).
            # Patching only ordinary slot 26 does not affect this dispatch.
            klass, entry = 0x420000, BASE+0x18000
            self.ptr(player, klass)
            self.ptr(klass+0x188, BASE if wrapped else self.functions['ORIGINAL'])
            self.ptr(klass+0x2d8, BASE)
            self.uc.mem_write(entry, struct.pack('<III', 0xf9400008, 0xf940c508, 0xd61f0100))
        self.uc.emu_start(entry, RETURN, count=10000)
        assert self.uc.reg_read(UC_ARM64_REG_PC) == RETURN, 'Callback did not return'
        assert self.uc.reg_read(UC_ARM64_REG_SP) == STACK+0x8000
        assert all(self.uc.reg_read(reg) == value for reg, value in saved.items()), 'Callee-saved ABI'
        assert self.events[first_call:].count('ORIGINAL') == 1
        assert self.w('BUSY') == initial_busy


# No downward accumulation, full native movement, and return at current X/Z.
s = Simulation(flags=2); s.run(LOCAL, interface=True, wrapped=False)
assert s.q('TICKS') == 0 and s.q('APPLIES') == 0 and s.positions[LOCAL][1] == 10
s.run(LOCAL, interface=True)
assert s.q('TICKS') == 1 and s.q('APPLIES') == 1 and math.isclose(s.positions[LOCAL][1], 8.0, abs_tol=1e-6)
s.w('FLAGS', 0); s.run(LOCAL, interface=True)
assert s.positions[LOCAL][1] == 10, 'Interface release must restore normal height'

s = Simulation(flags=2)
for step in range(100):
    s.run(LOCAL)
    assert s.original_seen[-1] == (step, 10, step*2), 'Physics update received a lowered transform'
    assert math.isclose(s.positions[LOCAL][1], 8.0, abs_tol=1e-6)
    assert s.positions[LOCAL][0] == step+1 and s.positions[LOCAL][2] == (step+1)*2
s.w('FLAGS', 0); s.run(LOCAL)
assert s.positions[LOCAL] == (101, 10, 202) and s.q('APPLIES') == 100
s.run(LOCAL); assert s.positions[LOCAL] == (102, 10, 204)

# Horizontal native movement between updates can carry the same lowered Y.
# Restore only our height offset without losing the newly moved X/Z.
s = Simulation(flags=2); s.run(LOCAL, interface=True)
for _ in range(100):
    x, y, z = s.positions[LOCAL]
    s.positions[LOCAL] = (x+0.5, y, z+0.5)
    s.run(LOCAL, interface=True)
    assert s.original_seen[-1] == (x+0.5, 10, z+0.5)
    assert s.positions[LOCAL] == (x+1.5, 8.0, z+2.5)
s.w('FLAGS', 0); s.run(LOCAL, interface=True)
assert s.positions[LOCAL][1] == 10
# Native application independently rejects corrupt/unbounded input depths.
for depth in [1.0, 1.5, 2.0, 2.25]:
    s = Simulation(flags=2, depth=depth)
    for _ in range(100):
        s.run(LOCAL)
        assert s.original_seen[-1][1] == 10 and s.positions[LOCAL][1] == 10-depth
    # Depth changes while ON restore the previous offset before applying the new.
    s.uc.mem_write(STATE+OFF['MODES_DEPTH'], struct.pack('<f', 2.0)); s.run(LOCAL)
    assert s.positions[LOCAL][1] == 8
    s.w('FLAGS', 0); s.run(LOCAL); assert s.positions[LOCAL][1] == 10
for depth in [math.nan, math.inf, -math.inf, -1.0, 0.75, 2.26, 1000.0]:
    s = Simulation(flags=2, depth=depth); s.run(LOCAL)
    assert not s.writes and s.q('APPLIES') == 0
for value in [math.nan, math.inf, -math.inf, 1000001]:
    for axis in [0, 2]:
        s = Simulation(flags=2); s.run(LOCAL)
        position = list(s.positions[LOCAL]); position[axis] = value
        s.positions[LOCAL] = tuple(position)
        before = len(s.writes); s.run(LOCAL)
        assert len(s.writes) == before, 'Height restore must not write invalid outside X/Z'

# A scoped visual stays anchored; incoming state and original updates advance.
s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
for _ in range(20): s.run(ENEMY); assert s.positions[ENEMY] == anchor
assert s.authoritative[ENEMY] == (41, 10, 62)
s.w('FLAGS', 0); s.w('EPOCH', 2); s.run(ENEMY)
assert s.positions[ENEMY] == (42, 10, 64), 'Release must use latest interpolation, not the old anchor'
s.w('FLAGS', 1); s.w('EPOCH', 3); s.run(ENEMY)
assert s.positions[ENEMY] == (43, 10, 66)

# Real fixed/interpolation ticks can advance the transform outside our wrapper.
# Small ordinary motion must keep the visual anchor, and must never restore an
# outdated normal position over the newly arrived state.
s = Simulation(flags=1); s.run(ENEMY, interface=True); anchor = s.positions[ENEMY]
for _ in range(20):
    s.positions[ENEMY] = tuple(f32(v+0.1) for v in s.authoritative[ENEMY])
    s.authoritative[ENEMY] = s.positions[ENEMY]
    normal = s.positions[ENEMY]
    count = len(s.writes)
    s.run(ENEMY, interface=True)
    assert s.original_seen[-1] == normal and s.positions[ENEMY] == anchor
    assert len(s.writes) == count+1, 'Do not restore stale state after an outside update'
s.w('FLAGS', 0); s.run(ENEMY, interface=True)
assert s.positions[ENEMY] == s.authoritative[ENEMY] and s.positions[ENEMY] != anchor

# Reused entity pointers with a new native UniqueID never revive the old anchor,
# even when the replacement spawns within the ordinary-motion threshold.
s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
s.uc.mem_write(ENEMY+0x60, struct.pack('<I', 2))
s.positions[ENEMY] = (22, 10, 23); s.authoritative[ENEMY] = s.positions[ENEMY]
before = len(s.writes); s.run(ENEMY)
assert s.original_seen[-1] == (22, 10, 23) and s.positions[ENEMY] != anchor
assert len(s.writes) == before+1

# Both roles can coexist, and neither role spills to teammates/unlisted actors.
s = Simulation(flags=3); s.run(LOCAL); s.run(ENEMY); s.run(OTHER)
assert math.isclose(s.positions[LOCAL][1], 8.0, abs_tol=1e-6)
assert s.positions[OTHER] == (41, 10, 42) and not any(player == OTHER for player, _ in s.writes)
s = Simulation(flags=1); s.run(LOCAL); assert not s.writes
s = Simulation(flags=2); s.run(ENEMY); assert not s.writes

# New corrections win over stale restore data, including local teleports.
s = Simulation(flags=2); s.run(LOCAL); s.positions[LOCAL] = (100, 15, 100); s.run(LOCAL)
assert s.original_seen[-1] == (100, 15, 100)
assert s.positions[LOCAL][0] == 101 and math.isclose(s.positions[LOCAL][1], 13.0, abs_tol=1e-6)
s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
s.positions[ENEMY] = (100, 10, 100); s.authoritative[ENEMY] = s.positions[ENEMY]
writes = len(s.writes); s.run(ENEMY)
assert s.positions[ENEMY] == anchor and len(s.writes) == writes+1, 'Distance alone must not release the same held entity'
s.w('FLAGS', 0); s.run(ENEMY)
assert s.positions[ENEMY] == (102, 10, 104), 'Release still uses latest incoming state'

# A publication race must skip torn data without forgetting a valid anchor.
for native in [None, 'CLOCK', 'GET_POS']:
    s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
    if native is None: s.w('SEQUENCE', 3)
    else:
        stage = [False]
        def publish_race(name, sim):
            if name == 'ORIGINAL': stage[0] = True
            if name == native and stage[0]: sim.w('SEQUENCE', 4)
        s.action = publish_race
    before = s.q('APPLIES'); s.run(ENEMY)
    assert s.q('APPLIES') == before
    s.action = None; s.w('SEQUENCE', 6); s.run(ENEMY)
    assert s.positions[ENEMY] == anchor, 'Concurrent publication must not release the anchor'

# Sustained large incoming motion and unrelated Burrow toggles keep one anchor.
s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
for step in range(200):
    s.positions[ENEMY] = (100+step*10, 10, 100+step*10)
    s.authoritative[ENEMY] = s.positions[ENEMY]
    s.w('FLAGS', 3 if step % 2 else 1)
    s.run(ENEMY, interface=True)
    assert s.positions[ENEMY] == anchor
s.w('FLAGS', 0); s.run(ENEMY)
assert s.positions[ENEMY] == s.authoritative[ENEMY] and s.positions[ENEMY] != anchor

# Native force sync and special movement continue while remote visuals stay held.
for reason in ['VEHICLE', 'PARACHUTE', 'WAIT_SYNC']:
    s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
    s.special[(ENEMY, reason)] = 1
    for _ in range(10): s.run(ENEMY); assert s.positions[ENEMY] == anchor
    s.w('FLAGS', 0); s.run(ENEMY)
    assert s.positions[ENEMY] == s.authoritative[ENEMY] and s.positions[ENEMY] != anchor

# OFF, expired/odd snapshots and unsupported movement release a held override.
for reason in ['off', 'lease', 'sequence', 'vehicle', 'parachute', 'sync']:
    s = Simulation(flags=2); s.run(LOCAL)
    if reason == 'off': s.w('FLAGS', 0)
    elif reason == 'lease': s.now = 111
    elif reason == 'sequence': s.w('SEQUENCE', 3)
    else: s.special[(LOCAL, {'vehicle': 'VEHICLE', 'parachute': 'PARACHUTE', 'sync': 'WAIT_SYNC'}[reason])] = 1
    applies = s.q('APPLIES'); s.run(LOCAL)
    assert s.positions[LOCAL] == (2, 10, 4) and s.q('APPLIES') == applies, reason

# Changed owners/death never write old coordinates into a new context.
for reason in ['match', 'local', 'dead', 'negative_hp', 'knocked', 'busy', 'count']:
    s = Simulation(flags=1); s.run(ENEMY)
    if reason == 'match': s.current_match = MATCH+0x2000
    elif reason == 'local': s.ptr(MATCH+0xd8, LOCAL+0x2000)
    elif reason == 'dead': s.health[ENEMY] = 0
    elif reason == 'negative_hp': s.health[ENEMY] = -1
    elif reason == 'knocked': s.uc.mem_write(ENEMY+0x1258, b'\x01')
    elif reason == 'busy': s.w('BUSY', 1)
    else: s.w('COUNT', 65)
    writes = len(s.writes); applies = s.q('APPLIES'); s.run(ENEMY)
    assert s.q('APPLIES') == applies, reason
    if reason not in ('knocked', 'count'): assert len(s.writes) == writes, reason

# Publication changes during native calls cannot apply a torn snapshot.
for native in ['CLOCK', 'GET_POS']:
    s = Simulation(flags=2)
    s.action = lambda name, sim, native=native: sim.w('SEQUENCE', 4) if name == native else None
    s.run(LOCAL); assert not s.writes and s.q('APPLIES') == 0
for value in [math.nan, math.inf, -math.inf, 1000001]:
    s = Simulation(flags=2); s.positions[LOCAL] = (1, value, 1); s.run(LOCAL)
    assert not s.writes
s = Simulation(flags=2); s.positions[LOCAL] = (0, 0, 0); s.delta = (0, 0, 0); s.run(LOCAL)
assert not s.writes, 'Missing-transform zero sentinel must bypass the setter'

# Fixed capacity never writes past its state page, and release frees entries.
s = Simulation(flags=1)
players = [0x210000+i*0x2000 for i in range(64)]
s.w('COUNT', 64)
for i, player in enumerate(players): s.ptr(STATE+OFF['MODES_PLAYERS']+i*8, player)
for player in players: s.run(player)
assert s.q('APPLIES') == 64
extra = 0x310000; s.ptr(STATE+OFF['MODES_PLAYERS'], extra); s.run(extra)
assert s.q('APPLIES') == 64, 'Full capacity must bypass'
s.w('FLAGS', 0)
for player in players: s.run(player)
s.w('FLAGS', 1); s.w('EPOCH', 2); s.run(extra)
assert s.q('APPLIES') == 65
print('Player modes ARM64: bounded depth, latest-state release, roles, corrections, expiry and ABI passed')
