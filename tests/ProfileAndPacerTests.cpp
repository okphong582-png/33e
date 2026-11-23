#include "../esp/esp/MizzeImageProfile.h"
#include "../esp/esp/MizzeFramePacer.h"
#include <cassert>
#include <vector>
#include <limits>
#include <cstdio>
static void put(std::vector<uint8_t>& b, size_t n, uint32_t v) { std::memcpy(b.data()+n,&v,4); }
int main() {
    std::vector<uint8_t> b(56);
    put(b,0,0xfeedfacf); put(b,4,0x0100000c); put(b,16,1); put(b,20,24);
    put(b,32,0x1b); put(b,36,24); std::memcpy(b.data()+40,MizzeVN::UnityUUID,16);
    assert(MizzeVN::matches(b.data(),b.size()));
    auto reject = [&](std::vector<uint8_t> v) { assert(!MizzeVN::matches(v.data(),v.size())); };
    for (size_t n=0;n<56;++n) assert(!MizzeVN::matches(b.data(),n));
    auto v=b; v[40]^=1; reject(v); v=b; put(v,36,0); reject(v);
    v=b; put(v,36,25); reject(v); v=b; put(v,20,0xffffffff); reject(v);
    v=b; put(v,16,0xffffffff); reject(v); v=b; put(v,32,0x19); reject(v);
    v=b; put(v,4,7); reject(v);
    MizzeFramePacer pacer;
    assert(pacer.observe(.002,60)==60);
    for(int i=0;i<100;++i) { double hz=pacer.observe(.05,60); assert(hz>=30 && hz<=60); }
    assert(pacer.observe(.05,60)==30);
    for(int i=0;i<100;++i) pacer.observe(.002,60);
    assert(pacer.observe(.002,60)>59);
    assert(pacer.observe(.002,40)<=40);
    assert(pacer.observe(std::numeric_limits<double>::quiet_NaN(),60)==60);
    puts("PASS: exact UUID, malformed/truncated Mach-O, frame budget and recovery");
}
