"""Run the shipped ARM64 weapon-input callback with simulated native methods."""
import struct
import sys
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import *

def read_code(path, section):
    data = open(path, 'rb').read()
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
                count, = struct.unpack_from('<I', data, p+64)
                for i in range(count):
                    s = struct.unpack_from('<16s16sQQIIIIIIII', data, p+72+i*80)
                    if s[0].rstrip(b'\0') != section:
                        continue
                    assert s[1].rstrip(b'\0') == b'__TEXT'
                    assert s[2] == 0 and s[5] == 14 and s[7] == 0
                    code = data[s[4]:s[4]+s[3]]
            p += size
    assert code is not None and len(code) == 0x4000
    return code

code = read_code(sys.argv[1], b'__autofire')
silent_code = read_code(sys.argv[2], b'__silent') if len(sys.argv)>2 else None

def effect_case(enabled=1, sequence=2, now=100, local=True, current=True, owner=True,
                match=True, knocked=0, race=False):
    uc=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
    uc.mem_map(0x100000,0x40000);uc.mem_map(0x200000,0x50000);uc.mem_map(0x300000,0x10000)
    uc.mem_write(0x100000,code)
    def ptr(a,v):uc.mem_write(a,struct.pack('<Q',v))
    def word(a,v):uc.mem_write(a,struct.pack('<I',v))
    state,clock,original=0x104000,0x120100,0x120800
    uc.mem_write(clock,b'\xc0\x03\x5f\xd6');uc.mem_write(original,b'\xc0\x03\x5f\xd6')
    ptr(state+8,clock);ptr(state+144,original);word(state+40,sequence);word(state+44,enabled)
    ptr(state+48,110);ptr(state+56,0x200000);ptr(state+64,0x230000);ptr(state+72,0x210000)
    ptr(0x2300d8,0x200000 if match else 0x200008)
    ptr(0x210060,0x200000 if owner else 0x200008)
    uc.mem_write(0x201258,bytes([knocked]))
    args=(0x200000 if local else 0x200008,0x210000 if current else 0x210008,0x456)
    for reg,v in zip((UC_ARM64_REG_X0,UC_ARM64_REG_X1,UC_ARM64_REG_X2),args):uc.reg_write(reg,v)
    uc.reg_write(UC_ARM64_REG_SP,0x308000);uc.reg_write(UC_ARM64_REG_X30,0x130000)
    uc.reg_write(UC_ARM64_REG_X19,0x999);uc.reg_write(UC_ARM64_REG_X20,0x888)
    calls=[]
    def hook(uc,a,size,_):
        if a==clock:
            uc.reg_write(UC_ARM64_REG_X0,now)
            if race:word(state+40,sequence+2)
        elif a==original:
            assert tuple(uc.reg_read(r) for r in (UC_ARM64_REG_X0,UC_ARM64_REG_X1,UC_ARM64_REG_X2))==args
            assert uc.reg_read(UC_ARM64_REG_SP)==0x308000
            calls.append('effect')
    uc.hook_add(UC_HOOK_CODE,hook);uc.emu_start(0x100010,0x130000,count=1000)
    assert uc.reg_read(UC_ARM64_REG_PC)==0x130000 and uc.reg_read(UC_ARM64_REG_SP)==0x308000
    assert uc.reg_read(UC_ARM64_REG_X19)==0x999 and uc.reg_read(UC_ARM64_REG_X20)==0x888
    skips,=struct.unpack('<Q',uc.mem_read(state+152,8))
    return calls,skips

assert effect_case()==([],1)
for args in [dict(enabled=0),dict(sequence=3),dict(now=111),dict(local=False),dict(current=False),
             dict(owner=False),dict(match=False),dict(knocked=1),dict(race=True)]:
    assert effect_case(**args)==(['effect'],0),args

BASE, STATE, ORIGINAL, CLOCK, GETTER, START, END, RETURN = 0x100000, 0x104000, 0x120000, 0x120100, 0x120200, 0x120300, 0x120400, 0x120500

def tracer_case(enabled=1,sequence=2,now=100,current=True,owner=True,
                match=True,knocked=0,race=False):
    uc=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
    uc.mem_map(0x100000,0x40000);uc.mem_map(0x200000,0x80000);uc.mem_map(0x300000,0x10000)
    uc.mem_write(BASE,code)
    def ptr(a,v):uc.mem_write(a,struct.pack('<Q',v))
    def word(a,v):uc.mem_write(a,struct.pack('<I',v))
    original=0x120800
    for a in [CLOCK,original]:uc.mem_write(a,b'\xc0\x03\x5f\xd6')
    ptr(STATE+8,CLOCK);ptr(STATE+160,original)
    word(STATE+40,sequence);word(STATE+44,enabled)
    for a,v in [(48,110),(56,0x200000),(64,0x230000),(72,0x210000)]:ptr(STATE+a,v)
    ptr(0x210530,0x273000 if current else 0x273008)
    ptr(0x210060,0x200000 if owner else 0x200008)
    ptr(0x2300d8,0x200000 if match else 0x200008)
    uc.mem_write(0x201258,bytes([knocked]))
    xr=[UC_ARM64_REG_X0+i for i in range(8)]
    dr=[UC_ARM64_REG_D0+i for i in range(8)]
    args=[0x273000]+[0xABC00+i for i in range(1,8)]
    floats=[0x3F800000+i for i in range(8)]
    for r,v in zip(xr+dr,args+floats):uc.reg_write(r,v)
    uc.reg_write(UC_ARM64_REG_SP,0x308000);uc.reg_write(UC_ARM64_REG_X30,RETURN)
    uc.reg_write(UC_ARM64_REG_X19,0x999);uc.reg_write(UC_ARM64_REG_X20,0x888)
    calls=[]
    def hook(uc,a,size,_):
        if a==CLOCK:
            for r in xr+dr:uc.reg_write(r,0)
            uc.reg_write(UC_ARM64_REG_X0,now)
            if race:word(STATE+40,sequence+2)
        elif a==original:
            assert [uc.reg_read(r) for r in xr+dr]==args+floats
            assert uc.reg_read(UC_ARM64_REG_SP)==0x308000
            calls.append('tracer')
    uc.hook_add(UC_HOOK_CODE,hook);uc.emu_start(BASE+32,RETURN,count=1000)
    assert uc.reg_read(UC_ARM64_REG_PC)==RETURN and uc.reg_read(UC_ARM64_REG_SP)==0x308000
    assert uc.reg_read(UC_ARM64_REG_X19)==0x999 and uc.reg_read(UC_ARM64_REG_X20)==0x888
    return calls,struct.unpack('<Q',uc.mem_read(STATE+168,8))[0]

assert tracer_case()==([],1)
for args in [dict(enabled=0),dict(sequence=3),dict(now=111),dict(current=False),
             dict(owner=False),dict(match=False),dict(knocked=1),dict(race=True)]:
    assert tracer_case(**args)==(['tracer'],0),args
print('Local tracer suppression, OFF/remote/stale fallbacks and all argument registers passed')

INTERVAL = 0x120600
METADATA_INIT, TYPEINFO = 0x120900, 0x274000
SILENT_BASE, SILENT_STATE, SHOT = 0x110000, 0x114000, 0x120700
HANDLER, INFO, INFO_CLASS = 0x270000, 0x271000, 0x272000
LOCAL, WEAPON, CLASS, MATCH, POOL, ENTRIES, ENTRY, STACK = 0x200000, 0x210000, 0x220000, 0x230000, 0x240000, 0x250000, 0x260000, 0x300000

def case(*, enabled=1, held=0, sequence=2, now=100, deadline=110, firing=0,
         self=WEAPON, owner=LOCAL, weapon=WEAPON, snapshot_weapon=WEAPON,
         match_local=LOCAL, knocked=0, busy=0, start=START, stop=END, clock_action=None,
         steps=1, before_step=None, dt=0.0625, interval=0.25, elapsed=0, interval_action=None,
         gate=SILENT_STATE+128, silent_percent=None, cold_info=False, warm=False):
    uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
    uc.mem_map(BASE, 0x30000); uc.mem_map(LOCAL, 0x80000); uc.mem_map(STACK, 0x10000)
    uc.mem_write(BASE, code)
    for address in [ORIGINAL, CLOCK, GETTER, START, END, INTERVAL]: uc.mem_write(address, b'\xc0\x03\x5f\xd6')
    def ptr(a,v): uc.mem_write(a,struct.pack('<Q',v))
    def word(a,v): uc.mem_write(a,struct.pack('<I',v))
    for i,v in enumerate([ORIGINAL,CLOCK,GETTER,START,END]): ptr(STATE+i*8,v)
    word(STATE+40,sequence); word(STATE+44,enabled)
    for a,v in [(48,deadline),(56,LOCAL),(64,MATCH),(72,snapshot_weapon),(80,held)]: ptr(STATE+a,v)
    word(STATE+88,busy)
    ptr(STATE+120,INTERVAL)
    uc.mem_write(STATE+128,struct.pack('<f',elapsed))
    ptr(STATE+136,gate)
    if warm:
        ptr(STATE+176,METADATA_INIT);ptr(STATE+184,TYPEINFO)
        uc.mem_write(METADATA_INIT,b'\xc0\x03\x5f\xd6')
    ptr(WEAPON+0x60,owner); ptr(WEAPON,CLASS)
    ptr(CLASS+0xc98,start); ptr(CLASS+0xca0,0xABC); ptr(CLASS+0xe88,stop); ptr(CLASS+0xe90,0xDEF)
    ptr(MATCH+0xd8,match_local); uc.mem_write(LOCAL+0x1258,bytes([knocked]))
    ptr(LOCAL+0x70,POOL); ptr(POOL+0x10,ENTRIES); ptr(ENTRIES+0xc8,ENTRY)
    uc.mem_write(ENTRY+0x18,struct.pack('<H',firing))
    if silent_percent is not None:
        assert silent_code is not None
        uc.mem_write(SILENT_BASE,silent_code); uc.mem_write(SHOT,b'\xc0\x03\x5f\xd6')
        ptr(SILENT_STATE,SHOT); ptr(SILENT_STATE+8,CLOCK)
        word(SILENT_STATE+16,2); word(SILENT_STATE+20,1); ptr(SILENT_STATE+24,deadline)
        ptr(SILENT_STATE+32,LOCAL); ptr(SILENT_STATE+40,HANDLER); ptr(SILENT_STATE+48,0 if cold_info else INFO_CLASS)
        uc.mem_write(SILENT_STATE+56,struct.pack('<fff',3,4,0))
        ptr(SILENT_STATE+96,MATCH)
        uc.mem_write(SILENT_STATE+104,struct.pack('<fff',2,0,0))
        word(SILENT_STATE+116,silent_percent); word(SILENT_STATE+120,50)
        ptr(WEAPON+0x80,HANDLER); ptr(HANDLER+0x10,WEAPON); ptr(HANDLER+0x28,0 if cold_info else INFO)
        ptr(INFO_CLASS+0x10,INFO_CLASS+0x100); uc.mem_write(INFO_CLASS+0x100,b'CGKJLKPMGDJ\0')
        ptr(INFO,INFO_CLASS); uc.mem_write(INFO+0x40,struct.pack('<fff',0,0,1))
    uc.reg_write(UC_ARM64_REG_X0,self); uc.reg_write(UC_ARM64_REG_X1,0x1234)
    uc.reg_write(UC_ARM64_REG_SP,STACK+0x8000); uc.reg_write(UC_ARM64_REG_X30,RETURN)
    dt_bits, = struct.unpack('<I',struct.pack('<f',dt))
    uc.reg_write(UC_ARM64_REG_D0,dt_bits); uc.reg_write(UC_ARM64_REG_D1,0x41200000)
    saved = {r:0xFFF000+i for i,r in enumerate([UC_ARM64_REG_X19,UC_ARM64_REG_X20,
        UC_ARM64_REG_X21,UC_ARM64_REG_X22,UC_ARM64_REG_X23,UC_ARM64_REG_X24,
        UC_ARM64_REG_X25,UC_ARM64_REG_X26,UC_ARM64_REG_X27,UC_ARM64_REG_X28,UC_ARM64_REG_X29])}
    for r,v in saved.items(): uc.reg_write(r,v)
    calls=[]
    bullets=[]
    getter_calls=[]
    metadata_calls=[]
    def hook(uc,a,size,_):
        if a == METADATA_INIT:
            assert uc.reg_read(UC_ARM64_REG_X0)==TYPEINFO
            metadata_calls.append(a)
            uc.reg_write(UC_ARM64_REG_X0,0);uc.reg_write(UC_ARM64_REG_X1,0)
            uc.reg_write(UC_ARM64_REG_D0,0);uc.reg_write(UC_ARM64_REG_D1,0)
        elif a == ORIGINAL:
            assert uc.reg_read(UC_ARM64_REG_X0)==self and uc.reg_read(UC_ARM64_REG_X1)==0x1234
            assert uc.reg_read(UC_ARM64_REG_D0)==dt_bits and uc.reg_read(UC_ARM64_REG_D1)==0x41200000
            calls.append('update')
        elif a in [CLOCK,GETTER,START,END,INTERVAL]:
            if a==GETTER:
                assert uc.reg_read(UC_ARM64_REG_X0)==LOCAL
                getter_calls.append(a)
            if a in [START,END]:
                assert uc.reg_read(UC_ARM64_REG_X0)==WEAPON
                assert uc.reg_read(UC_ARM64_REG_X1)==(0xABC if a==START else 0xDEF)
                if a==START:
                    assert calls[-1]=='update', 'Native weapon update must precede every automatic shot'
                calls.append('start' if a==START else 'stop')
                assert struct.unpack('<Q',uc.mem_read(SILENT_STATE+128,8))[0]==(WEAPON if a==START else 0)
                # A native automatic shot may leave manual PRI21 idle.
                uc.mem_write(ENTRY+0x18,struct.pack('<H',2 if a==START and silent_percent is None else 0))
            if a==CLOCK and clock_action: clock_action(word)
            if a==INTERVAL:
                assert uc.reg_read(UC_ARM64_REG_X0)==WEAPON
                assert uc.reg_read(UC_ARM64_REG_X1)==0
                if interval_action: interval_action(word)
            uc.reg_write(UC_ARM64_REG_D0,0); uc.reg_write(UC_ARM64_REG_D1,0)
            uc.reg_write(UC_ARM64_REG_X1,0)
            uc.reg_write(UC_ARM64_REG_X0,weapon if a==GETTER else now)
            if a==INTERVAL:
                bits, = struct.unpack('<I',struct.pack('<f',interval))
                uc.reg_write(UC_ARM64_REG_S0,bits)
            if a==START and silent_percent is not None:
                if cold_info: ptr(HANDLER+0x28,INFO) # native shot constructs its first aiming record
                uc.reg_write(UC_ARM64_REG_X0,HANDLER); uc.reg_write(UC_ARM64_REG_X1,0x456)
                uc.reg_write(UC_ARM64_REG_PC,SILENT_BASE)
        elif a==SHOT:
            assert uc.reg_read(UC_ARM64_REG_X0)==HANDLER and uc.reg_read(UC_ARM64_REG_X1)==0x456
            bullets.append(struct.unpack('<fff',uc.mem_read(INFO+0x40,12)))
    uc.hook_add(UC_HOOK_CODE,hook)
    for step in range(steps):
        if before_step: before_step(step,word)
        uc.reg_write(UC_ARM64_REG_X0,self); uc.reg_write(UC_ARM64_REG_X1,0x1234)
        uc.reg_write(UC_ARM64_REG_X30,RETURN)
        uc.emu_start(BASE,RETURN,count=1000)
        assert uc.reg_read(UC_ARM64_REG_PC)==RETURN and calls.count('update')==step+1
        assert uc.reg_read(UC_ARM64_REG_SP)==STACK+0x8000
        assert all(uc.reg_read(r)==v for r,v in saved.items())
        assert struct.unpack('<Q',uc.mem_read(SILENT_STATE+128,8))[0]==0, 'Automatic-shot marker leaked'
        if silent_percent is not None:
            assert struct.unpack('<fff',uc.mem_read(INFO+0x40,12))==(0,0,1)
    if not enabled and not held: assert not getter_calls
    assert len(metadata_calls)==int(warm)
    assert struct.unpack('<I',uc.mem_read(STATE+192,4))[0]==int(warm)
    assert struct.unpack('<I',uc.mem_read(STATE+88,4))[0]==busy
    held_after,=struct.unpack('<Q',uc.mem_read(STATE+80,8))
    starts,=struct.unpack('<Q',uc.mem_read(STATE+96,8))
    ticks,=struct.unpack('<Q',uc.mem_read(STATE+112,8))
    if not before_step:
        relevant = self == WEAPON and owner == LOCAL and (snapshot_weapon == WEAPON or held == WEAPON)
        assert ticks == (steps if relevant and (enabled or held) else 0)
    return (calls,held_after,starts,bullets) if silent_percent is not None else (calls,held_after,starts)

assert case()==(['update','start'],WEAPON,1)
assert case(steps=10,warm=True)[2]==3
assert case(steps=10,warm=True,enabled=0)==(['update']*10,0,0)
assert case(firing=2)==(['update'],0,0)  # do not claim a manual hold
assert case(firing=2,held=WEAPON)==(['update'],WEAPON,0)
for args in [dict(enabled=0),dict(sequence=3),dict(now=111),dict(knocked=1),
             dict(match_local=LOCAL+8),dict(snapshot_weapon=WEAPON+8),
             dict(clock_action=lambda w:w(STATE+40,4))]:
    assert case(**args)==(['update'],0,0), args
    assert case(held=WEAPON,**args)==(['update','stop'],0,0), args
assert case(owner=LOCAL+8,held=WEAPON)==(['update'],WEAPON,0)
assert case(weapon=0,held=WEAPON)==(['update'],0,0)
assert case(start=START+4)==(['update'],0,0)
assert case(stop=END+4)==(['update'],0,0)
assert case(gate=0)==(['update'],0,0)
assert case(self=WEAPON+8,held=WEAPON)==(['update'],WEAPON,0)
assert case(busy=1,held=WEAPON)==(['update'],WEAPON,0)
assert case(weapon=WEAPON+0x100,held=WEAPON)==(['update'],0,0)
assert case(steps=3)==(['update','start','update','update'],WEAPON,1)
calls, held, starts = case(steps=10)
assert starts==3 and held==WEAPON and calls.count('update')==10
assert [i for i,c in enumerate(calls) if c=='start']==[1,6,11]
assert case(steps=10,interval=1)[2]==1  # slow gun cannot inherit fast-gun cadence
assert case(steps=40,interval=1)[2]==3  # repeat slow/one-shot gun, too
assert case(steps=6,interval=0.125)[2]==3
assert case(steps=100,interval=0.1)[2]==62  # preserve cadence between uneven frame/shot intervals
assert case(steps=100,interval=0.05)[2]==100  # 2x interval: bounded to one shot per tick
assert case(steps=10,interval=0.01,dt=0.5)[2]==10  # no looped catch-up burst after a stalled tick
assert case(firing=2,steps=10)==(['update']*10,0,0)  # never claim manual fire
assert case(firing=2,held=WEAPON,elapsed=0.1875)==(['update','start'],WEAPON,1)
for interval in [0,-1,float('nan'),float('inf')]:
    assert case(held=WEAPON,interval=interval)==(['update','stop'],0,0)
for dt in [float('nan'),float('inf'),2]:
    assert case(held=WEAPON,dt=dt)==(['update','stop'],0,0)
assert case(held=WEAPON,dt=0)==(['update'],WEAPON,0)
assert case(held=WEAPON,elapsed=0.25,interval_action=lambda w:w(STATE+40,4))==(['update','stop'],0,0)
assert case(steps=3,before_step=lambda i,w:w(STATE+44,0) if i==1 else None)==(
    ['update','start','update','stop','update'],0,1)
print('Auto fire sustained native cadence, manual fire, start/release, swaps, expiry and float ABI passed')
if silent_code is not None:
    cold_bullets = case(silent_percent=100,cold_info=True)[3]
    assert len(cold_bullets)==1 and abs(cold_bullets[0][1]-.8)<1e-6, 'First native shot must redirect without a manual primer'
    for percent in [0,25,75,100]:
        calls,held,starts,bullets=case(steps=397,silent_percent=percent)
        assert starts==len(bullets)==100 and held==WEAPON
        assert sum(p[1]>0.7 for p in bullets)==percent
        assert all(p==(1,0,0) or abs(p[0]-.6)<1e-6 and abs(p[1]-.8)<1e-6 for p in bullets)
    assert case(enabled=0,silent_percent=100)[3]==[]
    assert case(now=111,silent_percent=100)[3]==[]
    print('AutoFire -> Silent handler integration: 100 automatic shots follow HS/body ratios without manual PRI21')
