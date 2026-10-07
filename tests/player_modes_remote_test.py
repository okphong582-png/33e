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
BASE, STATE, NATIVE, RETURN, STACK = 0x100000, 0x104000, 0x1a0000, 0x1b0000, 0x600000
LOCAL, ENEMY, OTHER, MATCH = 0x200000, 0x210000, 0x220000, 0x400000
FUNCTIONS = ['ORIGINAL', 'POST_ORIGINAL', 'CLOCK', 'CURRENT_MATCH', 'GET_POS', 'SET_POS', 'HP', 'VEHICLE', 'PARACHUTE', 'WAIT_SYNC', 'FORCE_POS', 'GET_ROT', 'SET_ROT', 'IS_CHILD', 'MODEL', 'LOCAL_POS', 'SET_LOCAL_POS', 'CHILD_COUNT', 'GET_CHILD', 'GET_SPEED', 'SET_SPEED', 'GET_ENABLED', 'SET_ENABLED', 'LATE_ORIGINAL', 'WORLD_ROT', 'SET_WORLD_ROT']
GAME=0x470000
LATE_BASE=0x480000
CCT,CCT_CLASS=0x430000,0x431000
MODEL,NODE,ROOT=0x433000,0x434000,0x435000
E_MODEL,E_ROOT,E_NODE,ANIMATOR,ANIM_SYSTEM=0x438000,0x439000,0x43a000,0x43b000,0x43c000


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]

def multiply(a,b):
    x,y,z,w=a;X,Y,Z,W=b
    return tuple(f32(v) for v in (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z))


class Simulation:
    def __init__(self, flags=3, height=3.0, physical=True):
        self.uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        self.uc.mem_map(BASE, 0xc0000)
        self.uc.mem_map(LOCAL, 0x280000)
        self.uc.mem_map(STACK, 0x10000)
        self.uc.mem_map(LATE_BASE,0x8000)
        self.uc.mem_write(BASE, CODE)
        self.uc.mem_write(LATE_BASE,CODE)
        self.functions = {name: NATIVE+i*0x100 for i, name in enumerate(FUNCTIONS)}
        self.native = {address: name for name, address in self.functions.items()}
        for name, address in self.functions.items():
            self.uc.mem_write(address, b'\xc0\x03\x5f\xd6')
            self.q(name, address)
        self.current_match, self.current_local, self.now = MATCH, LOCAL, 100
        self.q('LATE_SHARED',STATE);self.late_rotation=None
        self.ptr(LATE_BASE+0x4000+OFF['MODES_LATE_SHARED'],STATE)
        self.ptr(LATE_BASE+0x4000+OFF['MODES_LATE_ORIGINAL'],self.functions['LATE_ORIGINAL'])
        self.positions = {LOCAL: (0, 10, 0), ENEMY: (20, 10, 20), OTHER: (40, 10, 40)}
        self.authoritative = dict(self.positions)
        self.health, self.special = {}, {}
        self.events, self.original_seen, self.writes = [], [], []
        self.action = None
        self.gravity_step=0.0;self.force_writes=[];self.cct_position=self.positions[LOCAL]
        self.delta = (1, 0, 2)
        self.ptr(MATCH+0xd8, LOCAL)
        self.q('MATCH', MATCH); self.q('LOCAL', LOCAL); self.q('DEADLINE', 110)
        self.w('SEQUENCE', 2); self.w('EPOCH', 1); self.w('FLAGS', flags)
        self.w('COUNT', 1); self.ptr(STATE+OFF['MODES_PLAYERS'], ENEMY)
        self.uc.mem_write(STATE+OFF['MODES_HEIGHT'], struct.pack('<f', height))
        self.ptr(LOCAL+0x268,CCT);self.ptr(CCT,CCT_CLASS);self.ptr(CCT+0x1c8,0x432000)
        self.q('FLY_CCT',CCT);self.q('FLY_CLASS',CCT_CLASS)
        self.w('FLY_KIND',1 if physical else 2)
        self.uc.mem_write(LOCAL+0x260,bytes([int(physical)]))
        # Root can equal the physical entity, while BoneRoot is a separate child.
        self.ptr(LOCAL+0x6c8,ROOT);self.ptr(LOCAL+0x6d0,NODE);self.ptr(NODE+0x10,MODEL)
        self.ptr(LOCAL+0x58,ROOT);self.ptr(MODEL+0x10,0x436000);self.ptr(ROOT+0x10,0x437000)
        self.rotation=(0.0,0.0,0.0,1.0);self.rotation_writes=[];self.native_rotations=[];self.child=True
        self.parent_rotation=(0,0,0,1)
        self.pose_enabled=False;self.bone_child=True;self.children={};self.bone_rotations={};self.bone_positions={}
        self.bone_writes=[];self.animator_speed=.75;self.animator_enabled=True;self.animator_writes=[];self.native_bones=[]
        self.uc.mem_write(STATE+OFF['MODES_SPIN_SIN'],struct.pack('<ff',math.sqrt(.5),math.sqrt(.5)))
        self.ptr(LOCAL+0x4d8,CCT);self.ptr(CCT+0x10,0x432000)
        self.uc.hook_add(UC_HOOK_CODE, self.hook)

    def ptr(self, address, value):
        self.uc.mem_write(address, struct.pack('<Q', value))

    def enable_pose(self, count=8):
        self.pose_enabled=True
        self.ptr(ENEMY+0x6d0,E_NODE);self.ptr(E_NODE+0x10,E_MODEL)
        self.ptr(ENEMY+0x58,E_ROOT);self.ptr(ENEMY+0x760,ANIM_SYSTEM);self.ptr(ANIM_SYSTEM+0x28,ANIMATOR)
        for obj in [E_MODEL,E_ROOT,ANIMATOR]:self.ptr(obj+0x10,0x123000)
        bones=[E_MODEL]+[0x440000+i*0x100 for i in range(count-1)]
        for i,bone in enumerate(bones):
            self.ptr(bone+0x10,0x123000)
            self.children[bone]=bones[i+1:i+2]
            self.bone_rotations[bone]=(0,0,0,1)
            self.bone_positions[bone]=(0,f32(i*.1),0)
        return bones

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
        if name=='LATE_ORIGINAL':
            assert player==GAME and uc.reg_read(UC_ARM64_REG_X1)==0x1234
            self.native_rotations.append(self.rotation)
            # The native late animation can overwrite a pose applied at PostUpdate.
            if self.late_rotation is not None:self.rotation=self.late_rotation
        elif name in ('ORIGINAL', 'POST_ORIGINAL'):
            assert name == ('POST_ORIGINAL' if self.post else 'ORIGINAL'), 'Correct original for each phase'
            assert player == self.player and uc.reg_read(UC_ARM64_REG_X1) == 0x1234
            assert uc.reg_read(UC_ARM64_REG_D0) == 0x3d800000 and uc.reg_read(UC_ARM64_REG_D1) == 0x41200000
            self.original_seen.append(self.positions[player])
            if player==LOCAL:self.native_rotations.append(self.rotation)
            if player==ENEMY and self.pose_enabled:
                self.native_bones.append((dict(self.bone_rotations),dict(self.bone_positions),self.animator_speed,self.animator_enabled))
                for i,bone in enumerate(self.bone_rotations):
                    angle=(len(self.native_bones)+i)*.07
                    self.bone_rotations[bone]=(f32(math.sin(angle)),0,0,f32(math.cos(angle)))
                    self.bone_positions[bone]=(f32(angle),f32(i*.1),0)
            # Local motion uses the normal transform. Remote interpolation uses
            # the continually advancing incoming state, independent of visuals.
            source = self.positions[player] if player == LOCAL else self.authoritative[player]
            # PostUpdate has its own late incoming motion/vertical jump. Local
            # post timing only observes the pose; Fly must not be undone.
            delta = (0,self.gravity_step,0) if self.post and player == LOCAL else (
                (self.delta[0],self.gravity_step,self.delta[2]) if player==LOCAL else self.delta)
            normal = tuple(f32(v+d) for v, d in zip(source, delta))
            self.positions[player] = normal
            if player==LOCAL:self.cct_position=normal
            if player != LOCAL: self.authoritative[player] = normal
        elif name == 'CLOCK': uc.reg_write(UC_ARM64_REG_X0, self.now)
        elif name == 'CURRENT_MATCH':
            assert player == 0
            uc.reg_write(UC_ARM64_REG_X0, self.current_match)
        elif name == 'FORCE_POS':
            assert player==CCT and uc.reg_read(UC_ARM64_REG_X1)==0
            value=tuple(struct.unpack('<f',struct.pack('<I',uc.reg_read(reg)))[0]
                        for reg in (UC_ARM64_REG_S0,UC_ARM64_REG_S1,UC_ARM64_REG_S2))
            assert all(math.isfinite(v) for v in value)
            self.cct_position=value;self.force_writes.append(value)
        elif name == 'IS_CHILD':
            parent=uc.reg_read(UC_ARM64_REG_X1)
            assert (player==MODEL and parent==ROOT) or (player==E_MODEL and parent==E_ROOT) or (player in self.bone_rotations and parent==E_MODEL)
            uc.reg_write(UC_ARM64_REG_X0,int(self.child if player==MODEL else self.bone_child))
        elif name=='MODEL':
            assert uc.reg_read(UC_ARM64_REG_X1)==0
            node=struct.unpack('<Q',uc.mem_read(player+0x6d0,8))[0]
            transform=struct.unpack('<Q',uc.mem_read(node+0x10,8))[0] if node else 0
            uc.reg_write(UC_ARM64_REG_X0,transform)
        elif name in ('GET_SPEED','SET_SPEED','GET_ENABLED','SET_ENABLED'):
            assert player==ANIMATOR
            if name=='GET_SPEED':uc.reg_write(UC_ARM64_REG_S0,struct.unpack('<I',struct.pack('<f',self.animator_speed))[0])
            elif name=='GET_ENABLED':uc.reg_write(UC_ARM64_REG_X0,int(self.animator_enabled))
            elif name=='SET_SPEED':
                self.animator_speed=struct.unpack('<f',struct.pack('<I',uc.reg_read(UC_ARM64_REG_S0)))[0]
                self.animator_writes.append(('speed',self.animator_speed))
            else:
                assert uc.reg_read(UC_ARM64_REG_X2)==0
                self.animator_enabled=bool(uc.reg_read(UC_ARM64_REG_X1));self.animator_writes.append(('enabled',self.animator_enabled))
        elif name in ('CHILD_COUNT','GET_CHILD'):
            assert player in self.children
            if name=='CHILD_COUNT':uc.reg_write(UC_ARM64_REG_X0,len(self.children[player]))
            else:
                assert uc.reg_read(UC_ARM64_REG_X2)==0
                uc.reg_write(UC_ARM64_REG_X0,self.children[player][uc.reg_read(UC_ARM64_REG_X1)])
        elif name in ('LOCAL_POS','SET_LOCAL_POS'):
            assert player in self.bone_positions and uc.reg_read(UC_ARM64_REG_X1)==0
            regs=(UC_ARM64_REG_S0,UC_ARM64_REG_S1,UC_ARM64_REG_S2)
            if name=='LOCAL_POS':
                for reg,value in zip(regs,self.bone_positions[player]):uc.reg_write(reg,struct.unpack('<I',struct.pack('<f',value))[0])
            else:
                self.bone_positions[player]=tuple(struct.unpack('<f',struct.pack('<I',uc.reg_read(reg)))[0] for reg in regs)
                self.bone_writes.append((player,'position'))
        elif name in ('WORLD_ROT','SET_WORLD_ROT'):
            assert player==MODEL and uc.reg_read(UC_ARM64_REG_X1)==0
            regs=(UC_ARM64_REG_S0,UC_ARM64_REG_S1,UC_ARM64_REG_S2,UC_ARM64_REG_S3)
            if name=='WORLD_ROT':
                rotation=multiply(self.parent_rotation,self.rotation)
                for reg,value in zip(regs,rotation):uc.reg_write(reg,struct.unpack('<I',struct.pack('<f',value))[0])
            else:
                world=tuple(struct.unpack('<f',struct.pack('<I',uc.reg_read(reg)))[0] for reg in regs)
                inverse=tuple(-v for v in self.parent_rotation[:3])+(self.parent_rotation[3],)
                self.rotation=multiply(inverse,world);self.rotation_writes.append(self.rotation)
        elif name in ('GET_ROT','SET_ROT'):
            assert (player==MODEL or player in self.bone_rotations) and uc.reg_read(UC_ARM64_REG_X1)==0
            if name=='GET_ROT':
                rotation=self.rotation if player==MODEL else self.bone_rotations[player]
                for reg,value in zip((UC_ARM64_REG_S0,UC_ARM64_REG_S1,UC_ARM64_REG_S2,UC_ARM64_REG_S3),rotation):
                    uc.reg_write(reg,struct.unpack('<I',struct.pack('<f',value))[0])
            else:
                rotation=tuple(struct.unpack('<f',struct.pack('<I',uc.reg_read(reg)))[0]
                    for reg in (UC_ARM64_REG_S0,UC_ARM64_REG_S1,UC_ARM64_REG_S2,UC_ARM64_REG_S3))
                if player==MODEL:self.rotation=rotation;self.rotation_writes.append(rotation)
                else:self.bone_rotations[player]=rotation;self.bone_writes.append((player,'rotation'))
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
                if player==LOCAL and self.w('FLY_KIND')==2:self.cct_position=value
        if name not in ('GET_POS', 'SET_POS', 'GET_ROT','WORLD_ROT','LOCAL_POS','GET_SPEED'):
            uc.reg_write(UC_ARM64_REG_D0, 0); uc.reg_write(UC_ARM64_REG_D1, 0)
        for reg in (UC_ARM64_REG_X8, UC_ARM64_REG_X9, UC_ARM64_REG_X10, UC_ARM64_REG_X11, UC_ARM64_REG_X12, UC_ARM64_REG_X13):
            uc.reg_write(reg, 0xdeadbeef)

    def run(self, player, interface=False, wrapped=True, post=False, late=False):
        self.player = player
        self.post = post
        if player not in self.positions:
            self.positions[player] = (50, 10, 50); self.authoritative[player] = self.positions[player]
        initial_busy, first_call = self.w('BUSY'), len(self.events)
        self.uc.reg_write(UC_ARM64_REG_X0, GAME if late else player); self.uc.reg_write(UC_ARM64_REG_X1, 0x1234)
        self.uc.reg_write(UC_ARM64_REG_D0, 0x3d800000); self.uc.reg_write(UC_ARM64_REG_D1, 0x41200000)
        self.uc.reg_write(UC_ARM64_REG_SP, STACK+0x8000); self.uc.reg_write(UC_ARM64_REG_X30, RETURN)
        saved = {reg: 0xfff000+i for i, reg in enumerate((UC_ARM64_REG_X19, UC_ARM64_REG_X20, UC_ARM64_REG_X21,
            UC_ARM64_REG_X22, UC_ARM64_REG_X23, UC_ARM64_REG_X24, UC_ARM64_REG_X25, UC_ARM64_REG_X26,
            UC_ARM64_REG_X27, UC_ARM64_REG_X28, UC_ARM64_REG_X29))}
        for reg, value in saved.items(): self.uc.reg_write(reg, value)
        entry = LATE_BASE+OFF['MODES_LATE_ENTRY'] if late else (BASE+OFF['MODES_POST_ENTRY'] if post else BASE)
        if interface or post:
            # Actual metadata: IEntityTicker starts at class vtable slot 4;
            # OnUpdate is interface method 1, hence class slot 5 (0x188).
            # Patching only ordinary slot 26 does not affect this dispatch.
            # Stable distinct dispatch thunks: Unicorn caches translated code,
            # so rewriting one thunk from Update to PostUpdate can execute the
            # previous phase even though memory contains the new instruction.
            klass, entry = 0x420000, BASE+0xb8000+(0x10 if post else 0)
            self.ptr(player, klass)
            self.ptr(klass+0x188, BASE if wrapped else self.functions['ORIGINAL'])
            self.ptr(klass+0x2d8, BASE)
            self.ptr(klass+0xc18, BASE+OFF['MODES_POST_ENTRY'] if wrapped else self.functions['POST_ORIGINAL'])
            load = 0xf9460d08 if post else 0xf940c508 # ldr x8,[x8,#0xc18] / #0x188
            self.uc.mem_write(entry, struct.pack('<III', 0xf9400008, load, 0xd61f0100))
        # Full subtree capture performs bounded duplicate checks for up to 128
        # nodes; keep a finite budget, scaled for that intentionally larger path.
        self.uc.emu_start(entry, RETURN, count=250000 if self.pose_enabled else 10000)
        assert self.uc.reg_read(UC_ARM64_REG_PC) == RETURN, 'Callback did not return'
        assert self.uc.reg_read(UC_ARM64_REG_SP) == STACK+0x8000
        assert all(self.uc.reg_read(reg) == value for reg, value in saved.items()), 'Callee-saved ABI'
        expected='LATE_ORIGINAL' if late else ('POST_ORIGINAL' if post else 'ORIGINAL')
        assert self.events[first_call:].count(expected)==1
        assert not any(name in self.events[first_call:] for name in ('ORIGINAL','POST_ORIGINAL','LATE_ORIGINAL') if name!=expected)
        assert self.uc.reg_read(UC_ARM64_REG_X0)==(GAME if late else player)
        assert self.w('BUSY') == initial_busy


# Smooth modest ascent, horizontal movement and a fixed altitude in BOTH phases.
for physical in [False,True]:
    s=Simulation(flags=2,physical=physical)
    for step in range(240):
        if step==1:s.gravity_step=-0.25
        s.run(LOCAL);s.run(LOCAL,post=True)
        assert s.positions[LOCAL]==s.cct_position
    assert s.positions[LOCAL][1]==13
    assert len(s.force_writes)==(480 if physical else 0)
    count=len(s.writes);s.uc.mem_write(LOCAL+0x260,bytes([int(not physical)]));s.run(LOCAL)
    assert len(s.writes)==count
for reason in ['object','class','native','kind']:
    s=Simulation(flags=2,physical=False)
    if reason=='object':s.ptr(LOCAL+0x4d8,0)
    elif reason=='class':s.ptr(CCT,CCT_CLASS+0x100)
    elif reason=='native':s.ptr(CCT+0x10,0)
    else:s.w('FLY_KIND',9)
    s.run(LOCAL);assert not s.writes
s=Simulation(flags=2)
s.run(LOCAL,interface=True,wrapped=False);assert not s.force_writes
base=s.positions[LOCAL][1];previous=base
for step in range(240):
    if step==1:s.gravity_step=-0.25
    s.run(LOCAL,interface=True);s.run(LOCAL,post=True)
    assert previous<=s.positions[LOCAL][1]<=base+3
    assert s.positions[LOCAL][1]-previous<=0.125001
    assert s.positions[LOCAL]==s.cct_position
    previous=s.positions[LOCAL][1]
assert previous==base+3 and len(s.force_writes)==480
# Height adjustment is smooth and never adds another height per tick.
s.uc.mem_write(STATE+OFF['MODES_HEIGHT'],struct.pack('<f',1.0))
previous=s.positions[LOCAL][1]
for _ in range(100):
    s.run(LOCAL);assert 0<=previous-s.positions[LOCAL][1]<=0.062501
    previous=s.positions[LOCAL][1]
assert previous==base+1
count=len(s.force_writes);s.w('FLAGS',0);s.run(LOCAL)
assert len(s.force_writes)==count and s.positions[LOCAL][1]==previous-0.25
# Fresh enable starts at the current position and rises by one bounded step.
s.w('FLAGS',2);old=s.positions[LOCAL][1];s.run(LOCAL)
assert s.positions[LOCAL][1]==old-0.25+0.0625
# Bounded height, bad controllers and malformed positions fail closed.
for height in [1.0,3.0,4.0,5.0,6.0]:
    s=Simulation(flags=2,height=height)
    for _ in range(160):s.run(LOCAL)
    assert s.positions[LOCAL][1]==10+height
for height in [math.nan,math.inf,-math.inf,-1.0,0.75,6.01,1000]:
    s=Simulation(flags=2,height=height);s.run(LOCAL)
    assert not s.writes and not s.force_writes
for reason in ['cct','class','transform']:
    s=Simulation(flags=2)
    if reason=='cct':s.ptr(LOCAL+0x268,0)
    elif reason=='class':s.ptr(CCT,CCT_CLASS+0x100)
    else:s.ptr(CCT+0x1c8,0)
    s.run(LOCAL);assert not s.force_writes and not s.writes
for value in [math.nan,math.inf,-math.inf,1000001]:
    for axis in [0,1,2]:
        s=Simulation(flags=2);position=list(s.positions[LOCAL]);position[axis]=value
        s.positions[LOCAL]=tuple(position);s.run(LOCAL);assert not s.force_writes

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
assert s.positions[LOCAL][1]==10.0625
assert s.positions[OTHER] == (41, 10, 42) and not any(player == OTHER for player, _ in s.writes)
s = Simulation(flags=1); s.run(LOCAL); assert not s.writes
s = Simulation(flags=2); s.run(ENEMY); assert not s.writes

# New corrections win over stale restore data, including local teleports.
s = Simulation(flags=2); s.run(LOCAL); s.positions[LOCAL] = (100, 15, 100); s.run(LOCAL)
assert s.original_seen[-1] == (100, 15, 100)
assert s.positions[LOCAL]==(101,15.0625,102), 'Large native corrections establish a fresh base'
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

# Sustained large incoming motion and unrelated Fly toggles keep one anchor.
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
    assert s.positions[LOCAL] == (2,10.0625,4) and s.q('APPLIES') == applies, reason

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

# Regression: a late presentation update can overwrite an OnUpdate-only hold.
s = Simulation(flags=1); s.run(ENEMY); anchor = s.positions[ENEMY]
s.delta = (3, 1.5, 2)
s.run(ENEMY, post=True, wrapped=False)
assert s.positions[ENEMY] != anchor and s.q('POST_TICKS') == 0
s.run(ENEMY, post=True)
assert s.positions[ENEMY] == anchor and s.q('POST_TICKS') == 1
# Both real frame phases reuse one anchor across running and vertical jumping.
for step in range(120):
    s.delta = (2, 1.5 if step % 2 else -1.5, 3)
    s.run(ENEMY, interface=True)
    assert s.positions[ENEMY] == anchor
    s.positions[ENEMY] = s.authoritative[ENEMY]
    s.run(ENEMY, post=True)
    assert s.positions[ENEMY] == anchor
assert s.q('POST_TICKS') == 121
s.w('FLAGS', 0); s.run(ENEMY, post=True)
assert s.positions[ENEMY] == s.authoritative[ENEMY] and s.positions[ENEMY] != anchor
# A fresh enable captures the latest pose, not an old hold's anchor.
s.w('FLAGS', 1); s.w('EPOCH', 2); s.run(ENEMY, post=True)
new_anchor = s.positions[ENEMY]; assert new_anchor != anchor
s.run(ENEMY); assert s.positions[ENEMY] == new_anchor
# Shared-state ownership/lease/torn publication guards also apply after PostUpdate.
for reason in ['off', 'lease', 'match', 'dead', 'busy', 'race']:
    s = Simulation(flags=1); s.run(ENEMY)
    if reason == 'off': s.w('FLAGS', 0)
    elif reason == 'lease': s.now = 111
    elif reason == 'match': s.current_match = MATCH+0x2000
    elif reason == 'dead': s.health[ENEMY] = 0
    elif reason == 'busy': s.w('BUSY', 1)
    else:
        stage = [False]
        def post_race(name, sim):
            if name == 'POST_ORIGINAL': stage[0] = True
            if name == 'GET_POS' and stage[0]: sim.w('SEQUENCE', 4)
        s.action = post_race
    before = s.q('APPLIES'); s.run(ENEMY, post=True)
    assert s.q('APPLIES') == before, reason
# Local PostUpdate applies the same altitude, without recapturing a base.
s=Simulation(flags=3);s.run(LOCAL);before=s.positions[LOCAL][1]
s.run(LOCAL,post=True);assert s.positions[LOCAL][1]==before+0.0625 and s.q('POST_TICKS')==1
s.run(LOCAL);assert s.positions[LOCAL][1]==before+0.125
# Toggling enemy modes cannot restart the local ascent.
for i in range(200):
    s.w('FLAGS',3 if i%2 else 2);s.w('EPOCH',i+2);s.run(LOCAL)
assert s.positions[LOCAL][1]==13
# Unlisted teammates continue their ordinary PostUpdate.
s = Simulation(flags=1); s.run(OTHER, post=True)
assert not s.writes and s.positions[OTHER] == s.authoritative[OTHER]
print('Player modes ARM64: two frame phases, running/jumping hold, height, latest release, guards and ABI passed')

# Local spin must be a render-only child pose, restored before native updates.
s=Simulation(flags=4);s.run(LOCAL);assert not s.rotation_writes
s.run(LOCAL,post=True);assert not s.rotation_writes, 'PostUpdate is not the final animation phase'
s.late_rotation=(0,0,0,1)
s.run(LOCAL,late=True)
assert all(abs(a-b)<1e-6 for a,b in zip(s.rotation,(0,math.sqrt(.5),0,math.sqrt(.5))))
assert not s.writes and not s.force_writes
for _ in range(20):s.run(LOCAL);s.run(LOCAL,late=True)
assert all(pose==(0,0,0,1) for pose in s.native_rotations)
s.w('FLAGS',0);s.run(LOCAL)
assert s.rotation==(0,0,0,1) and not s.q('SPIN_PLAYER')
s=Simulation(flags=4);s.rotation=(math.sqrt(.5),0,0,math.sqrt(.5))
s.run(LOCAL,late=True)
assert all(abs(a-b)<1e-6 for a,b in zip(s.rotation,(.5,.5,-.5,.5)))
# Unity may normalize or negate the same quaternion representation.
s.rotation=tuple(-v for v in s.rotation);s.w('FLAGS',0);s.run(LOCAL)
assert all(abs(a-b)<1e-6 for a,b in zip(s.rotation,(math.sqrt(.5),0,0,math.sqrt(.5))))
s=Simulation(flags=4)
s.uc.mem_write(STATE+OFF['MODES_SPIN_SIN'],struct.pack('<ff',float('nan'),1))
s.run(LOCAL,late=True);assert not s.rotation_writes
s=Simulation(flags=4);s.run(ENEMY,post=True);assert not s.rotation_writes
s.run(LOCAL,late=True);assert s.q('LATE_TICKS')==1 and s.q('SPIN_APPLIES')==1 and s.w('SPIN_STATUS')==4
s=Simulation(flags=4);s.w('BUSY',1);s.run(LOCAL,late=True);assert not s.rotation_writes and s.q('LATE_TICKS')==0
s=Simulation(flags=4);s.w('SEQUENCE',3);s.run(LOCAL,late=True);assert not s.rotation_writes
s=Simulation(flags=4);s.q('LOCAL',0);s.run(LOCAL,late=True);assert not s.rotation_writes
for reason in ['root','missing','not_child','dead','knocked','lease','match','race','nan']:
    s=Simulation(flags=4)
    if reason=='root':s.ptr(NODE+0x10,ROOT)
    elif reason=='missing':s.ptr(MODEL+0x10,0)
    elif reason=='not_child':s.child=False
    elif reason=='dead':s.health[LOCAL]=0
    elif reason=='knocked':s.uc.mem_write(LOCAL+0x1258,b'\x01')
    elif reason=='lease':s.now=111
    elif reason=='match':s.current_match=MATCH+0x2000
    elif reason=='nan':s.rotation=(float('nan'),0,0,1)
    else:
        def spin_race(name,sim):
            if name=='GET_ROT':sim.w('SEQUENCE',4)
        s.action=spin_race
    s.run(LOCAL,late=True);assert not s.rotation_writes,reason
s=Simulation(flags=4);s.run(LOCAL,late=True);s.rotation=(0,0,0,-1)
s.w('FLAGS',0);s.run(LOCAL);assert s.rotation==(0,0,0,-1) # Native animation wins.
s=Simulation(flags=4);s.run(LOCAL,late=True);before=len(s.rotation_writes)
s.uc.mem_write(LOCAL+0x60,struct.pack('<I',1));s.w('FLAGS',0);s.run(LOCAL)
assert len(s.rotation_writes)==before # Recycled player does not receive saved pose.
for flags in [5,6,7]:
    s=Simulation(flags=flags);s.run(LOCAL);s.run(LOCAL,late=True)
    assert s.rotation_writes
    if flags&1:s.run(ENEMY,post=True);assert s.writes
print('Visual spin ARM64: child-only render phase, native restoration, independent modes and guards passed')

# Imported skeletons have tilted local axes. World-up yaw must leave the standing
# body's up vector unchanged, at every phase, regardless of parent orientation.
for parent in [(math.sqrt(.5),0,0,math.sqrt(.5)),(0,0,math.sqrt(.5),math.sqrt(.5)),(.5,.5,.5,.5)]:
    for angle in [0,math.pi/4,math.pi/2,math.pi,3*math.pi/2,2*math.pi]:
        s=Simulation(flags=4);s.parent_rotation=parent
        base=tuple(-v for v in parent[:3])+(parent[3],)
        s.rotation=base
        yaw=(0,math.sin(angle/2),0,math.cos(angle/2))
        s.uc.mem_write(STATE+OFF['MODES_SPIN_SIN'],struct.pack('<ff',yaw[1],yaw[3]))
        s.run(LOCAL,late=True)
        shown=multiply(parent,s.rotation)
        assert abs(sum(a*b for a,b in zip(shown,yaw)))>0.99999
        # Rotation matrix's up column remains world-up: no pitch or roll.
        x,y,z,w=shown
        up=(2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w))
        assert all(abs(a-b)<1e-5 for a,b in zip(up,(0,1,0)))
        # Changing parent yaw after the displayed pose cannot rewind that parent.
        s.parent_rotation=multiply((0,.5,0,math.sqrt(.75)),parent)
        s.w('FLAGS',0);s.run(LOCAL)
        assert abs(sum(a*b for a,b in zip(s.rotation,base)))>0.99999
print('Horizontal spin: world-up yaw, tilted import axes, full turns and local restoration passed')

# Complete held pose, not just the player position: head, arms, fingers and legs.
s=Simulation(flags=1);bones=s.enable_pose();s.run(ENEMY,post=True)
anchor_rot=dict(s.bone_rotations);anchor_pos=dict(s.bone_positions)
assert s.animator_speed==0 and not s.animator_enabled
for i in range(8):
    s.run(ENEMY);s.run(ENEMY,post=True)
    assert s.bone_rotations==anchor_rot and s.bone_positions==anchor_pos
    assert s.animator_speed==0 and not s.animator_enabled
assert all(speed==.75 and enabled for _,_,speed,enabled in s.native_bones)
# Normal pose processing keeps progressing behind the visual freeze.
assert s.native_bones[-1][0]!=s.native_bones[1][0]
s.w('FLAGS',0);s.run(ENEMY)
assert s.animator_speed==.75 and s.animator_enabled
assert s.bone_rotations!=anchor_rot and s.bone_positions!=anchor_pos
s=Simulation(flags=1);s.enable_pose();s.animator_speed=.25;s.animator_enabled=False
s.run(ENEMY);s.w('FLAGS',0);s.run(ENEMY)
assert s.animator_speed==.25 and not s.animator_enabled # Preserve native disabled state.
s=Simulation(flags=1);s.enable_pose();s.run(ENEMY);anchor=dict(s.bone_rotations)
s.w('EPOCH',2);s.run(ENEMY);assert s.bone_rotations!=anchor # New scope recaptures.
for reason in ['cycle','overflow','missing','reparent','race','nan']:
    s=Simulation(flags=1);bones=s.enable_pose(129 if reason=='overflow' else 8)
    if reason=='cycle':s.children[bones[-1]]=[E_MODEL]
    elif reason=='missing':s.ptr(bones[-1]+0x10,0)
    elif reason=='reparent':s.bone_child=False
    else:
        def pose_failure(name,sim):
            if name=='LOCAL_POS' and reason=='race':sim.w('SEQUENCE',4)
            if name=='GET_ROT' and reason=='nan':sim.bone_rotations[bones[-1]]=(float('nan'),0,0,1)
        s.action=pose_failure
    s.run(ENEMY,post=True)
    assert not s.animator_writes and not s.bone_writes,reason
s=Simulation(flags=1);s.enable_pose(128);s.run(ENEMY,post=True)
assert len(s.bone_writes)==256 and s.animator_speed==0 # Entire bounded hierarchy.
s=Simulation(flags=1);s.enable_pose();s.run(ENEMY);before=len(s.animator_writes)
s.uc.mem_write(ENEMY+0x60,struct.pack('<I',99));s.w('FLAGS',0);s.run(ENEMY)
assert len(s.animator_writes)==before # No restore into a recycled entity.
print('Frozen pose ARM64: all descendant positions/rotations, Animator pause/release, epochs and bounds passed')
