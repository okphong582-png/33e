#include "../esp/Core/VirtualHookRegistry.h"
#include "../esp/Core/SilentAimNativePolicy.h"
#include "../esp/Core/GameImageSelection.h"
#include "../esp/drawing_view/OverlayGeometry.h"
#include "../sources/MizzeMenuLayout.h"
#include <cassert>
#include <cstring>
#include <map>
#include <cstdio>

int main() {
    int head=1,body=2;const int *target=nullptr;
    {
        SilentAimNative::ScopedTarget<int> outer(target,head);assert(*target==1);
        { SilentAimNative::ScopedTarget<int> nested(target,body);assert(*target==2); }
        assert(*target==1);
    }
    assert(!target);
    using R=VirtualHooks::Registry<2>;R hooks;
    std::map<uint64_t,uint64_t> memory{{0x1000,0xA000},{0x2000,0xB000},{0x3000,0xC000}};
    bool writable=true,failExchange=false;
    auto read=[&](uint64_t a,uint64_t &v){auto p=memory.find(a);if(p==memory.end())return false;v=p->second;return true;};
    auto canWrite=[&](uint64_t){return writable;};
    auto exchange=[&](uint64_t a,uint64_t &e,uint64_t v){if(failExchange){e=0xDEAD;return false;}if(memory[a]!=e){e=memory[a];return false;}memory[a]=v;return true;};
    assert(hooks.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::Installed);
    assert(hooks.install(0x2000,0xB000,0xF000,read,canWrite,exchange)==R::Result::Installed);
    assert(hooks.original(0x1000)==0xA000 && hooks.original(0x2000)==0xB000);
    assert(hooks.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::Existing);
    assert(hooks.install(0x3000,0xC000,0xF000,read,canWrite,exchange)==R::Result::Full);
    memory[0x2000]=0xEEEE; // Another owner replaces a slot after installation.
    assert(hooks.restoreAll(read,canWrite,exchange));
    assert(memory[0x1000]==0xA000 && memory[0x2000]==0xEEEE);
    assert(hooks.original(0x1000)==0xA000); // In-flight callback still has original.
    assert(hooks.install(0x2000,0xB000,0xF000,read,canWrite,exchange)==R::Result::Conflict);
    for(int i=0;i<100;++i){
        assert(hooks.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::Installed);
        assert(hooks.restoreAll(read,canWrite,exchange));
    }
    R failures;writable=false;
    assert(failures.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::ReadOnly);
    writable=true;failExchange=true;
    assert(failures.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::Conflict);
    assert(!failures.original(0x1000));failExchange=false;
    assert(failures.install(0x1000,0xA000,0xF000,read,canWrite,exchange)==R::Result::Installed);
    writable=false;assert(!failures.restoreAll(read,canWrite,exchange));
    writable=true;assert(failures.restoreAll(read,canWrite,exchange));
    // A child handler has a different name but retains the base virtual method.
    std::map<uint64_t,uint64_t> parents{{0x100058,0x200000},{0x200058,0}};
    auto parentRead=[&](uint64_t a,uint64_t &v){auto i=parents.find(a);if(i==parents.end())return false;v=i->second;return true;};
    auto text=[](uint64_t a,const char *expected){
        const char *actual=a==0x100010?"ABOKFAOHJDB":a==0x200010?"MDPBNKPCGNG":
            (a==0x100018||a==0x200018)?"COW.GamePlay":"";
        return std::strcmp(actual,expected)==0;
    };
    assert(SilentAimNative::Derives(0x100000,"MDPBNKPCGNG",parentRead,text));
    parents[0x100058]=0x100000;
    assert(!SilentAimNative::Derives(0x100000,"MDPBNKPCGNG",parentRead,text));
    assert(!SilentAimNative::Derives(0,"MDPBNKPCGNG",parentRead,text));
    assert(GameImageSelection::UnityFramework("/game/Frameworks/UnityFramework.framework/UnityFramework"));
    assert(!GameImageSelection::UnityFramework("/game/FreeFire"));
    assert(!GameImageSelection::UnityFramework("/game/UnityFramework.fake"));
    assert(!GameImageSelection::UnityFramework(nullptr));
    assert(OverlayGeometry::OnScreen(400,200,10,800,400));
    assert(!OverlayGeometry::OnScreen(400,200,-10,800,400)); // Behind camera.
    assert(!OverlayGeometry::OnScreen(-1,200,10,800,400)); // Off left.
    assert(!OverlayGeometry::OnScreen(801,200,10,800,400)); // Off right.
    assert(!OverlayGeometry::OnScreen(400,401,10,800,400));
    const auto layout=MizzeMenuLayout::Measure(844,390);
    assert(layout.width<=350 && layout.height<=316 && layout.contentWidth>230);
    const auto small=MizzeMenuLayout::Measure(280,240);
    assert(small.width<=264 && small.height<=224);
    std::puts("PASS: per-class originals, CAS ownership, OFF/in-flight callbacks, re-enable, inheritance, Unity-only loading, front-only ESP, compact sizing");
}
