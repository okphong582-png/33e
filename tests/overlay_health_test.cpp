#include "../esp/Core/OverlayHealth.h"
#include <cassert>
#include <cstdint>
#include <cstring>
#include <unordered_map>

int main() {
    std::unordered_map<uint64_t, uint64_t> ptr;
    std::unordered_map<uint64_t, uint16_t> value;
    const uint64_t player=0x100000, pool=0x200000, entries=0x300000,
                   current=0x400000, maximum=0x500000;
    ptr[player+kDataPool]=pool; ptr[pool+kDataPoolInner]=entries;
    ptr[entries+kDataPoolEntriesBase]=current;
    ptr[entries+kDataPoolEntriesBase+kDataPoolEntryStride]=maximum;
    value[current+kDataPoolValue]=42; value[maximum+kDataPoolValue]=100;
    auto read = [&](uint64_t address, void *out, size_t size) {
        if (size == sizeof(uint64_t)) {
            auto it=ptr.find(address); if (it==ptr.end()) return false;
            std::memcpy(out,&it->second,size); return true;
        }
        if (size == sizeof(uint16_t)) {
            auto it=value.find(address); if (it==value.end()) return false;
            std::memcpy(out,&it->second,size); return true;
        }
        return false;
    };
    auto valid=[](uint64_t address) { return address >= 0x100000; };
    float ratio=0;
    assert(OverlayHealth::Snapshot(player,read,valid,ratio));
    assert(ratio > .419f && ratio < .421f);
    assert(OverlayHealth::Band(.75f,25,50)==OverlayHealth::Color::Mint);
    assert(OverlayHealth::Band(.40f,25,50)==OverlayHealth::Color::Yellow);
    assert(OverlayHealth::Band(.10f,25,50)==OverlayHealth::Color::Red);
    value[maximum+kDataPoolValue]=0;
    assert(!OverlayHealth::Snapshot(player,read,valid,ratio));
    value[maximum+kDataPoolValue]=100;
    value[current+kDataPoolValue]=101;
    assert(!OverlayHealth::Snapshot(player,read,valid,ratio));
    value[current+kDataPoolValue]=42;
    bool replaced=false;
    auto replacingRead = [&](uint64_t a,void *out,size_t n) {
        const bool ok=read(a,out,n);
        if(a==maximum+kDataPoolValue) { ptr[player+kDataPool]=pool+8;replaced=true; }
        return ok;
    };
    assert(!OverlayHealth::Snapshot(player,replacingRead,valid,ratio));
    assert(replaced);
}
