#include "../esp/drawing_view/offset.h"
#include <cassert>
#include <iostream>

int main() {
    for (int frame = 0; frame < 10000; ++frame) {
        assert(kGameFacadeTypeInfo == 0xBB46A50);
        assert(kCurrentGame == 0);
        assert(kHeadNode == 0x6A0);
        assert(kHipNode == 0x6A8);
        assert(kTransformIndex == 0x40);
        assert(kAimRotation == 0x614);
        assert(kAimRotationAux == 0x628);
        assert(kAvatarManager == 0x770);
        assert(kKnocked == 0x1258);
        assert(OFF64(0xFFFFFFFFFFFFFFFFULL) == 0xFFFFFFFFFFFFFFFFULL);
    }
    std::cout << "Cached offsets: all checks passed\n";
}
