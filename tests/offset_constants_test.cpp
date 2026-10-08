#include "../esp/drawing_view/offset.h"
#include <cassert>
#include <iostream>

int main() {
    for (int frame = 0; frame < 10000; ++frame) {
#ifdef MIZZE_GAME_MAX
        assert(kGameFacadeTypeInfo == 0xBE93418);
        assert(kHeadNode == 0x6A8);
        assert(kHipNode == 0x6B0);
        assert(kAimRotation == 0x61C);
        assert(kAimRotationAux == 0x630);
        assert(kAvatarManager == 0x778);
        assert(kKnocked == 0x1270);
#else
        assert(kGameFacadeTypeInfo == 0xBB46A50);
        assert(kHeadNode == 0x6A0);
        assert(kHipNode == 0x6A8);
        assert(kAimRotation == 0x614);
        assert(kAimRotationAux == 0x628);
        assert(kAvatarManager == 0x770);
        assert(kKnocked == 0x1258);
#endif
        assert(kCurrentGame == 0);
        assert(kTransformIndex == 0x40);
        assert(OFF64(0xFFFFFFFFFFFFFFFFULL) == 0xFFFFFFFFFFFFFFFFULL);
    }
    std::cout << "Cached offsets: all checks passed\n";
}
