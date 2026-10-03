#include "../esp/Core/GamePRI.h"
#include "../esp/Core/AimSelection.h"
#include <cassert>
#include <cstring>
#include <iostream>
#include <map>
#include <vector>

struct Memory {
    static constexpr uint64_t player = 0x100000000;
    static constexpr uint64_t pool = player + 0x1000;
    static constexpr uint64_t entries = player + 0x2000;
    static constexpr uint64_t entry = player + 0x3000;
    std::map<uint64_t, std::vector<uint8_t>> values;
    std::vector<uint64_t> reads;
    uint64_t failedAddress = 0;

    template <typename T> void put(uint64_t address, T value) {
        auto &bytes = values[address];
        bytes.resize(sizeof(T));
        std::memcpy(bytes.data(), &value, sizeof(T));
    }
    static uint64_t slot(int index) {
        return entries + kDataPoolEntriesBase + index * kDataPoolEntryStride;
    }
    Memory() {
        put(player + kDataPool, pool);
        put(pool + kDataPoolInner, entries);
        put(slot(GamePRI::FiringIndex), entry);
    }
    bool sample(int index, uint16_t &value) {
        return GamePRI::TryUInt16(player, index,
            [this](uint64_t address, void *buffer, size_t size) {
                reads.push_back(address);
                const auto found = values.find(address);
                if (address == failedAddress || found == values.end() ||
                    found->second.size() != size) return false;
                std::memcpy(buffer, found->second.data(), size);
                return true;
            },
            [](uint64_t address) { return address >= player && address < player + 0x10000; },
            value);
    }
};

int main() {
    // The actual game's getter requests PRI index 21 and compares with 2.
    assert(GamePRI::FiringIndex == 21);
    assert(GamePRI::FiringActiveValue == 2);
    assert(!GamePRI::Firing(-1));
    for (uint16_t raw : {0, 1, 2, 3, 255, 256, 65535}) {
        Memory memory;
        memory.put(Memory::entry + kDataPoolValue, raw);
        // Changing the AvatarManager address between matches must have no effect.
        memory.put(Memory::player + kAvatarManager, uint64_t(0x12345600 + raw));
        uint16_t result = 99;
        assert(memory.sample(GamePRI::FiringIndex, result) && result == raw);
        assert(GamePRI::Firing(result) == (raw == 2));
        assert((memory.reads == std::vector<uint64_t>{Memory::player + kDataPool,
            Memory::pool + kDataPoolInner, Memory::slot(21), Memory::entry + kDataPoolValue}));
    }
    // A burst starts from idle without opening scope and stops on release.
    Memory burst;
    for (uint16_t raw : {0, 2, 2, 0, 2, 0}) {
        burst.put(Memory::entry + kDataPoolValue, raw);
        uint16_t result = 99;
        assert(burst.sample(GamePRI::FiringIndex, result));
        assert(AimSelection::Triggered(true, true, GamePRI::Firing(result), false, false)
               == (raw == 2));
        assert(AimSelection::Triggered(true, true, GamePRI::Firing(result), true, false)
               == (raw == 2));
    }
    // A failed read at any level is unavailable, not a stale firing sample.
    for (uint64_t address : {Memory::player + kDataPool, Memory::pool + kDataPoolInner,
                            Memory::slot(21), Memory::entry + kDataPoolValue}) {
        Memory memory;
        memory.put(Memory::entry + kDataPoolValue, uint16_t(2));
        memory.failedAddress = address;
        uint16_t result = 99;
        assert(!memory.sample(GamePRI::FiringIndex, result));
        assert(result == 99);
    }
    // Never follow null pointers or read an out-of-range PRI slot.
    for (uint64_t address : {Memory::player + kDataPool, Memory::pool + kDataPoolInner,
                            Memory::slot(21)}) {
        Memory memory;
        memory.put(address, uint64_t(0));
        uint16_t result = 99;
        assert(!memory.sample(GamePRI::FiringIndex, result));
    }
    for (int index : {-1, 33}) {
        Memory memory;
        uint16_t result = 99;
        assert(!memory.sample(index, result) && memory.reads.empty());
    }
    // Existing HP and scope PRI reads retain their original layout and values.
    Memory memory;
    for (int index : {0, 12}) {
        const uint64_t valueEntry = Memory::player + 0x4000 + index * 0x100;
        memory.put(Memory::slot(index), valueEntry);
        memory.put(valueEntry + kDataPoolValue, uint16_t(index == 0 ? 200 : 1));
        uint16_t result = 0;
        assert(memory.sample(index, result));
        assert(result == (index == 0 ? 200 : 1));
    }
    std::cout << "Game PRI: firing state, transitions and failed reads passed\n";
}
