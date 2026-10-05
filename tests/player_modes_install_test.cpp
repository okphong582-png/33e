#include "../esp/Core/PlayerModesInstallPolicy.h"
#include "../esp/Core/PlayerModesLayout.h"
#include <cassert>
#include <map>
#include <vector>

int main() {
    using namespace PlayerModesInstall;
    const uint64_t klass=0x100000;
    const auto native=Originals(0x5660700,0x569c1e4), callback=Callbacks(0x200000);
    std::map<uint64_t,uint64_t> memory;
    std::vector<uint64_t> writes;
    auto reset=[&](){memory.clear();writes.clear();for(size_t i=0;i<Slots.size();++i){memory[klass+Slots[i]]=native[i];memory[klass+Slots[i]+8]=0xabcdef;}};
    auto read=[&](uint64_t a,uint64_t &v){auto it=memory.find(a);if(it==memory.end())return false;v=it->second;return true;};
    auto exchange=[&](uint64_t a,uint64_t expected,uint64_t next){if(memory[a]!=expected)return false;memory[a]=next;writes.push_back(a);return true;};
    reset();assert(Slots[0]==0x188&&Slots[1]==0x2d8&&Slots[2]==0xc18);
    assert(callback[0]==callback[1]&&callback[2]==callback[0]+MODES_POST_ENTRY);
    assert(Bind(klass,native,callback,read,exchange));
    for(size_t i=0;i<Slots.size();++i){assert(memory[klass+Slots[i]]==callback[i]);assert(memory[klass+Slots[i]+8]==0xabcdef);}
    // Polling an installed callback must not rewrite/suspend it every HUD frame.
    writes.clear();assert(Bind(klass,native,callback,read,exchange));assert(writes.empty());
    // Another hook on either entry rejects the whole attempt before any writes.
    for(auto slot:Slots){reset();memory[klass+slot]=0xdeadbeef;assert(!Bind(klass,native,callback,read,exchange));assert(writes.empty());}
    for(auto slot:Slots){reset();memory.erase(klass+slot);assert(!Bind(klass,native,callback,read,exchange));assert(writes.empty());}
    // Any failed write restores previous entries and never touches MethodInfo.
    for(auto failed:Slots){
        reset();auto failWrite=[&](uint64_t a,uint64_t expected,uint64_t next){if(a==klass+failed)return false;return exchange(a,expected,next);};
        assert(!Bind(klass,native,callback,read,failWrite));
        for(size_t i=0;i<Slots.size();++i){assert(memory[klass+Slots[i]]==native[i]);assert(memory[klass+Slots[i]+8]==0xabcdef);}
    }
    // A competing write is preserved even if rollback cannot recover its slot.
    reset();auto raced=[&](uint64_t a,uint64_t expected,uint64_t next){if(a==klass+Slots[1]){memory[klass+Slots[0]]=0xdeadbeef;return false;}return exchange(a,expected,next);};
    assert(!Bind(klass,native,callback,read,raced));assert(memory[klass+Slots[0]]==0xdeadbeef);
    // Repair a partially installed class using the existing shared callback.
    reset();memory[klass+Slots[0]]=callback[0];assert(Bind(klass,native,callback,read,exchange));assert(writes.size()==2);
    // A conflicting PostUpdate pointer rejects BOTH update installs.
    reset();memory[klass+Slots[2]]=0xdeadbeef;assert(!Bind(klass,native,callback,read,exchange));assert(writes.empty());
}
