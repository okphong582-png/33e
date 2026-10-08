#include "../esp/Core/GameProfileFields.h"
#include "../esp/Core/GameProfileMethods.h"
#include <cassert>

int main() {
#ifdef MIZZE_GAME_MAX
    assert(MIZZE_PLAYER_614 == 0x61C);
    assert(MIZZE_PLAYER_740 == 0x748);
    assert(MIZZE_PLAYER_768 == 0x770);
    assert(MIZZE_PLAYER_1258 == 0x1270);
    assert(GameOffsets::DumpRva(0x8DE4904) == 0x8EB0D90);
    assert(GameOffsets::DumpRva(0x591B898) == 0x5D4D76C);
    assert(GameOffsets::DumpRva(0xBB46A50) == 0); // Missing native global must not reuse TH.
#else
    assert(MIZZE_PLAYER_614 == 0x614);
    assert(MIZZE_PLAYER_740 == 0x740);
    assert(MIZZE_PLAYER_768 == 0x768);
    assert(MIZZE_PLAYER_1258 == 0x1258);
    assert(GameOffsets::DumpRva(0x8DE4904) == 0x8DE4904);
#endif
    assert(GameOffsets::PlayerField(0x768) == MIZZE_PLAYER_768);
}
