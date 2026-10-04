#include "../esp/Core/SilentAimRemoteLayout.h"
#include "../esp/Core/SilentAimWeapon.h"
#include <cassert>
#include <cstring>
#include <unordered_map>

int main() {
    using namespace SilentAimRemote;
    State state{};
    assert(state.magic == Magic && state.enabled == 0 && state.redirects == 0 && state.busy == 0);
    assert(sizeof(State) == 128);
    assert(state.headPercent == 75 && state.phase == 50);
    std::unordered_map<uint64_t, uint64_t> memory;
    const uint64_t local = 0x100000, manager = 0x200000, regular = 0x300000, combined = 0x400000;
    memory[local + 0x740] = manager;
    memory[manager + 0x30] = local;
    memory[manager + 0x148] = 0;
    memory[manager + 0xA0] = regular;
    memory[manager + 0xA8] = combined;
    memory[regular + 0x60] = local;
    memory[combined + 0x60] = local;
    auto read = [&](uint64_t a, auto &v) {
        const auto i = memory.find(a);
        if (i == memory.end()) return false;
        std::memcpy(&v, &i->second, sizeof(v));
        return true;
    };
    auto valid = [](uint64_t a) { return a >= 0x100000; };
    auto weapon = [&] { return SilentAimWeapon::OnHand(local, read, valid); };
    assert(weapon() == regular);
    memory[manager + 0x148] = 1;
    assert(weapon() == combined);
    memory[combined + 0x60] = local + 8;
    assert(weapon() == 0);
    memory[combined + 0x60] = local;
    memory[manager + 0x148] = 2;
    assert(weapon() == 0);
    memory[manager + 0x148] = 0;
    memory[manager + 0x30] = local + 8;
    assert(weapon() == 0);
    memory[manager + 0x30] = local;
    memory.erase(manager + 0xA0);
    assert(weapon() == 0);
    memory[local + 0x740] = 0;
    assert(weapon() == 0);
}
