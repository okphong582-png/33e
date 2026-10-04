#include "../esp/Core/WeaponFeatures.h"
#include <cassert>
#include <iostream>
#include <vector>

using namespace WeaponFeatures;

struct Fixture {
    static constexpr uint64_t Base = 0x100000;
    static constexpr uint64_t Player = Base + 0x1000;
    static constexpr uint64_t Attributes = Base + 0x3000;
    static constexpr uint64_t Klass = Base + 0x5000;
    std::vector<uint8_t> memory = std::vector<uint8_t>(0x10000, 0);
    Context context{1, Base + 0x7000, Player};
    Controller controller;
    uint64_t failedRead = 0;
    bool failWrites = false;
    bool changeBeforeWrite = false;
    int reads = 0, writes = 0;
    std::vector<uint64_t> writtenAddresses;

    Fixture() {
        put(Player + PlayerAttributesOffset, Attributes);
        put(Attributes, Klass);
        put(Attributes + AttributesPlayerOffset, Player);
        put(Klass + 0x10, Base + 0x6000);
        put(Klass + 0x18, Base + 0x6100);
        const char name[] = "PlayerAttributes", namespc[] = "COW.GamePlay";
        std::memcpy(memory.data() + 0x6000, name, sizeof(name));
        std::memcpy(memory.data() + 0x6100, namespc, sizeof(namespc));
        put<uint8_t>(Attributes + ShootNoReloadOffset, 0);
        put<float>(Attributes + FireIntervalScaleOffset, 1.0f);
    }
    template <typename T> void put(uint64_t address, T value) {
        assert(address >= Base && address - Base + sizeof(T) <= memory.size());
        std::memcpy(memory.data() + address - Base, &value, sizeof(T));
    }
    template <typename T> T get(uint64_t address) const {
        T value{};
        assert(address >= Base && address - Base + sizeof(T) <= memory.size());
        std::memcpy(&value, memory.data() + address - Base, sizeof(T));
        return value;
    }
    bool valid(uint64_t address) const { return address >= Base && address - Base < memory.size(); }
    void tick(bool noReload, bool fastFire) {
        controller.Update(context, noReload, fastFire,
            [&](uint64_t address, void *buffer, size_t length) {
                ++reads;
                if (address == failedRead || !valid(address) || !valid(address + length - 1)) return false;
                std::memcpy(buffer, memory.data() + address - Base, length);
                return true;
            },
            [&](uint64_t address, const void *buffer, size_t length) {
                if (failWrites) return false;
                assert(valid(address) && valid(address + length - 1));
                assert((address == Attributes + ShootNoReloadOffset && length == sizeof(uint8_t)) ||
                       (address == Attributes + FireIntervalScaleOffset && length == sizeof(float)));
                ++writes;
                writtenAddresses.push_back(address);
                std::memcpy(memory.data() + address - Base, buffer, length);
                return true;
            },
            [&](uint64_t address) { return valid(address); },
            [&] {
                Context live = context;
                if (changeBeforeWrite) ++live.player;
                return live;
            });
    }
    uint8_t noReload() const { return get<uint8_t>(Attributes + ShootNoReloadOffset); }
    float scale() const { return get<float>(Attributes + FireIntervalScaleOffset); }
};

int main() {
    {
        Fixture f;
        f.tick(false, false);
        assert(f.reads == 0 && f.writes == 0);
        f.put<uint8_t>(Fixture::Attributes + 0x110, 0xA5);
        f.put<float>(Fixture::Attributes + 0xD8, 3.0f);
        f.put<float>(Fixture::Attributes + 0x208, 7.0f);
        f.tick(true, true);
        assert(f.noReload() == 1 && f.scale() == 0.5f && f.writes == 2);
        for (int i = 0; i < 300; ++i) f.tick(true, true);
        assert(f.scale() == 0.5f && f.writes == 2);
        f.tick(false, true);
        assert(f.noReload() == 0 && f.scale() == 0.5f);
        f.tick(false, false);
        assert(f.scale() == 1.0f && !f.controller.HasChanges());
        assert(f.get<uint8_t>(Fixture::Attributes + 0x110) == 0xA5);
        assert(f.get<float>(Fixture::Attributes + 0xD8) == 3.0f);
        assert(f.get<float>(Fixture::Attributes + 0x208) == 7.0f);
    }
    {
        Fixture f;
        f.put<uint8_t>(Fixture::Attributes + ShootNoReloadOffset, 1);
        f.put<float>(Fixture::Attributes + FireIntervalScaleOffset, 2.0f);
        f.tick(true, true);
        assert(f.noReload() == 1 && f.scale() == 1.0f && f.writes == 1);
        f.tick(false, false);
        assert(f.noReload() == 1 && f.scale() == 2.0f);
    }
    {
        Fixture f;
        f.tick(true, true);
        f.put<float>(Fixture::Attributes + FireIntervalScaleOffset, 1.5f);
        f.tick(true, true);
        assert(f.scale() == 0.75f);
        f.tick(false, false);
        assert(f.scale() == 1.5f);
        f.tick(false, true);
        f.put<float>(Fixture::Attributes + FireIntervalScaleOffset, 3.0f);
        f.tick(false, false);
        assert(f.scale() == 3.0f); // Preserve a newer game-owned value.
    }
    {
        Fixture f;
        f.failWrites = true;
        f.tick(true, true);
        assert(f.writes == 0 && f.noReload() == 0 && f.scale() == 1.0f);
        assert(!f.controller.HasChanges());
        f.failWrites = false;
        f.tick(true, true);
        f.failWrites = true;
        f.tick(false, false);
        assert(f.noReload() == 1 && f.scale() == 0.5f && f.controller.HasChanges());
        f.failWrites = false;
        f.tick(false, false);
        assert(f.noReload() == 0 && f.scale() == 1.0f && !f.controller.HasChanges());
    }
    {
        Fixture f;
        f.tick(true, true);
        f.failedRead = Fixture::Klass + 0x10;
        f.tick(true, true);
        f.failedRead = 0;
        f.tick(true, true);
        assert(f.scale() == 0.5f && f.writes == 2);
        f.failedRead = Fixture::Attributes + FireIntervalScaleOffset;
        f.tick(false, false);
        assert(f.scale() == 0.5f && f.controller.HasChanges());
        f.failedRead = 0;
        f.tick(false, false);
        assert(f.scale() == 1.0f && !f.controller.HasChanges());
    }
    {
        Fixture f;
        f.changeBeforeWrite = true;
        f.tick(true, true);
        assert(f.writes == 0 && f.noReload() == 0 && f.scale() == 1.0f);
        f.changeBeforeWrite = false;
        f.tick(true, true);
        ++f.context.task; // Reused addresses in a different task must not be restored.
        f.tick(false, false);
        assert(f.writes == 2 && !f.controller.HasChanges());
    }
    {
        Fixture f;
        f.tick(true, true);
        f.context = {}; // Leaving a match must not write to its old player.
        f.tick(false, false);
        assert(f.writes == 2);
        f.context = {1, Fixture::Base + 0x7000, Fixture::Player};
        f.tick(false, false);
        assert(f.noReload() == 0 && f.scale() == 1.0f);
    }
    {
        Fixture f;
        f.put<uint64_t>(Fixture::Attributes + AttributesPlayerOffset, Fixture::Player + 8);
        f.tick(true, true);
        assert(f.writes == 0);
        f.put(Fixture::Attributes + AttributesPlayerOffset, Fixture::Player);
        f.memory[0x6000] = 'X'; // Wrong IL2CPP class.
        f.tick(true, true);
        assert(f.writes == 0);
        f.memory[0x6000] = 'P';
        f.memory[0x6100] = 'X'; // Same class name in another namespace.
        f.tick(true, true);
        assert(f.writes == 0);
    }
    for (float invalid : {0.0f, -1.0f, 100.0f, std::numeric_limits<float>::infinity(),
                          std::numeric_limits<float>::quiet_NaN()}) {
        Fixture f;
        f.put<float>(Fixture::Attributes + FireIntervalScaleOffset, invalid);
        f.put<uint8_t>(Fixture::Attributes + ShootNoReloadOffset, 7);
        f.tick(true, true);
        assert(f.writes == 0);
    }
    {
        Fixture f;
        f.put<float>(Fixture::Attributes + FireIntervalScaleOffset, 0.05f);
        f.tick(false, true);
        assert(f.scale() == 0.05f && f.writes == 0);
        uint64_t value = 0;
        bool readCalled = false;
        assert(!ReadField(std::numeric_limits<uint64_t>::max() - 3, 8, value,
            [&](uint64_t, void *, size_t) { readCalled = true; return true; },
            [](uint64_t) { return true; }));
        assert(!readCalled);
    }
    std::cout << "Weapon features: ownership, reversible values and failed I/O checks passed\n";
}
