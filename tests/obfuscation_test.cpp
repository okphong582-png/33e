#include "../obfuscation/AntiREProtection.h"
#include <array>
#include <cassert>
#include <thread>
#include <vector>
#include <cstdio>

uint64_t fixture_encoded();
uint64_t fixture_seed();

static uint64_t execute(std::initializer_list<uint8_t> raw, uint64_t a, uint64_t b, bool& valid) {
    std::vector<uint8_t> encoded;
    for (uint8_t byte : raw) encoded.push_back(_cv_::cv_encrypt_byte(byte, encoded.size()));
    return _cv_::cv_execute(encoded.data(), encoded.size(), a, b, 0, 0, &valid);
}
int main() {
    using namespace _cv_;
    assert(fixture_seed() == _obf_::BuildSeed);
    assert(_vdata_::vd_decrypt_u64(fixture_encoded(),77) == 0x123456789ABCDEF0ULL);
    bool valid = false;
    for (unsigned a = 0; a < 21; ++a)
        for (unsigned b = 0; b < a; ++b) assert(cv_opcode(a) != cv_opcode(b));
    assert(execute({CVIRT_ADD,0,1,CVIRT_HALT},UINT64_MAX,2,valid) == 1 && valid);
    assert(execute({CVIRT_ROT,0,0,CVIRT_HALT},0xFEDCBA9876543210ULL,0,valid) == 0xFEDCBA9876543210ULL && valid);
    assert(execute({CVIRT_ROT,0,64,CVIRT_HALT},77,0,valid) == 77 && valid);
    assert(execute({CVIRT_MUL,0,1,CVIRT_SHR,0,1,CVIRT_HALT},6,7,valid) == 21 && valid);
    assert(execute({CVIRT_JZ,0,6,CVIRT_LOAD,0,9,CVIRT_HALT},0,0,valid) == 0 && valid);
    assert(execute({CVIRT_JZ,0,6,CVIRT_LOAD,0,9,CVIRT_HALT},1,0,valid) == 9 && valid);
    assert(execute({CVIRT_XOR,0,1,CVIRT_NOT,0,CVIRT_HALT},0x1234,0x4321,valid) == ~(uint64_t(0x1234)^0x4321) && valid);
    assert(execute({CVIRT_CALL,3,CVIRT_HALT,CVIRT_ADD,0,1,CVIRT_RET},7,8,valid) == 15 && valid);
    assert(execute({CVIRT_PUSH,0,CVIRT_LOAD,0,99,CVIRT_POP,0,CVIRT_RET},12,0,valid) == 12 && valid);
    execute({CVIRT_ADD,0},1,2,valid); assert(!valid);
    execute({CVIRT_LOAD,0,12},1,2,valid); assert(!valid);
    execute({CVIRT_JMP,0},1,2,valid); assert(!valid); // Infinite loop bounded.
    execute({CVIRT_JMP,255,CVIRT_HALT},1,2,valid); assert(!valid);
    execute({CVIRT_POP,0,CVIRT_HALT},1,2,valid); assert(!valid);
    execute({CVIRT_PUSH,0,CVIRT_JMP,0},1,2,valid); assert(!valid); // Stack overflow.
    assert(_cv_::cv_execute(nullptr,5,0,0,0,0,&valid) == 0 && !valid);
    uint8_t invalid = 0;
    bool found = false;
    for (unsigned i = 0; i < 256; ++i) {
        bool known = false;
        for (unsigned op = 0; op < 21; ++op) known |= i == cv_opcode(op);
        if (!known) { invalid = i; found = true; break; }
    }
    assert(found); execute({invalid},0,0,valid); assert(!valid);

    for (unsigned byte = 0; byte < 256; ++byte) for (size_t index : {size_t(0),size_t(1),size_t(4095)}) {
        assert(cv_decrypt_byte(cv_encrypt_byte(byte,index),index) == byte);
        assert(_vdata_::vd_decrypt_byte(_vdata_::vd_encrypt_byte(byte,index,42),index,42) == byte);
    }
    for (uint64_t value : {uint64_t(0),uint64_t(1),UINT64_MAX,uint64_t(0xFEDCBA9876543210ULL)}) {
        for (uint64_t slot : {uint64_t(0),uint64_t(77),UINT64_MAX})
            assert(_vdata_::vd_decrypt_u64(_vdata_::vd_encrypt_u64(value,slot),slot) == value);
        assert(_vdata_::vd_decrypt_ptr(_vdata_::vd_encrypt_ptr(value)) == uintptr_t(value));
    }
    constexpr uint8_t bytes[] = {0,1,128,255};
    constexpr _vdata_::VDBuffer<4,99> buffer{bytes,_obf_::MakeSeq<4>::type()};
    uint8_t decoded[4] = {9,9,9,9};
    assert(!buffer.decrypt_to(nullptr)); assert(!buffer.decrypt_to(decoded,3));
    assert(decoded[0] == 9 && buffer.decrypt_to(decoded));
    for (size_t i = 0; i < 4; ++i) assert(decoded[i] == bytes[i]);

    _vdata_::VDRollingKey rolling;
    uint64_t output = 88;
    assert(!rolling.open({},output) && output == 88);
    assert(!rolling.seal(7).sequence);
    rolling.init(42);
    auto first = rolling.seal(123), second = rolling.seal(456);
    assert(rolling.open(second,output) && output == 456);
    assert(rolling.open(first,output) && output == 123);
    auto damaged = first; damaged.encrypted ^= 1;
    output = 88; assert(!rolling.open(damaged,output) && output == 88);
    damaged = first; damaged.sequence ^= 1; assert(!rolling.open(damaged,output));
    damaged = first; damaged.tag ^= 1; assert(!rolling.open(damaged,output));
    auto legacy = rolling.encrypt_with_rolling(777); rolling.next();
    assert(rolling.decrypt_with_rolling(legacy) == 777);
    rolling.init(43); assert(!rolling.open(first,output));

    uint64_t registers[16] = {UINT64_MAX,2}; volatile uint64_t junk = 0;
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_ADD,registers,1,&junk,&valid) == 1 && valid);
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_SUB,registers,1,&junk,&valid) == UINT64_MAX && valid);
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_MUL,registers,1,&junk,&valid) == UINT64_MAX-1 && valid);
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_XOR,registers,1,&junk,&valid) == ((UINT64_MAX-1)^uint64_t(2)));
    assert(valid);
    _vtizer_::vt_dispatch(_vtizer_::VT_ADD,registers,0x1000,&junk,&valid); assert(!valid);
    _vtizer_::vt_dispatch(_vtizer_::VT_ADD,nullptr,0,&junk,&valid); assert(!valid);
    _vtizer_::vt_dispatch(6^_vtizer_::VTIZER_XOR_LAYER1,registers,0,&junk,&valid); assert(!valid);
    registers[0] = 2;
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_SUB,registers,0,&junk,&valid) == 0 && valid);
    registers[0] = 0x0102030405060708ULL;
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_NOT,registers,0,&junk,&valid) == ~0x0102030405060708ULL && valid);
    uint64_t expected_sbox = 0;
    for (unsigned i = 0; i < 8; ++i) expected_sbox |= uint64_t(_obf_::sbox[(registers[0]>>(i*8))&255])<<(i*8);
    assert(_vtizer_::vt_dispatch(_vtizer_::VT_SBOX,registers,0,&junk,&valid) == expected_sbox && valid);
    uint8_t operations[] = {_vtizer_::VT_ADD,_vtizer_::VT_NOT};
    uint64_t arguments[] = {0,0};
    assert(_vtizer_::vt_run_sequence(operations,arguments,2,5) == ~uint64_t(10));
    assert(_vtizer_::vt_verify_integrity());

    _monite_::MTSectionMonitor monitor;
    uint8_t own[] = {1,2,3,4};
    assert(!monitor.verify() && !monitor.init(nullptr,4));
    assert(!monitor.init(own,_monite_::MONITE_MAX_SECTION+1));
    assert(monitor.init(own,4) && monitor.verify());
    assert(!monitor.verify(reinterpret_cast<void*>(1),4));
    assert(!monitor.verify(own,3));
    own[2] ^= 1;
    assert(!monitor.verify() && !monitor.init(own,4));
    own[2] ^= 1; assert(monitor.verify());
    assert(!ANTI_RE_CHECK());
    std::vector<std::thread> threads;
    for (unsigned thread = 0; thread < 8; ++thread) threads.emplace_back([&,thread] {
        assert(ANTI_RE_INIT());
        for (uint64_t i = 0; i < 500; ++i) {
            uint64_t expected = (uint64_t(thread)<<32)|i;
            auto packet = rolling.seal(expected);
            uint64_t actual = 0;
            assert(rolling.open(packet,actual) && actual == expected);
            if (i % 100 == 0) assert(ANTI_RE_CHECK());
        }
    });
    for (auto& thread : threads) thread.join();
    assert(_monite_::monitors().count ==
#ifdef __APPLE__
           5
#else
           1
#endif
    );
    assert(ANTI_RE_INIT() && ANTI_RE_CHECK());
    puts("Own-code protection: VM bounds, data round trips, tampering and concurrency passed.");
}
