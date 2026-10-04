#include "../esp/Core/SilentAimRemoteMapping.h"
#include <cassert>
#include <cstring>
#include <iostream>

extern "C" const unsigned char SilentAimMappingFixtureStart[], SilentAimMappingFixtureEnd[];
extern "C" kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, pointer_t, mach_msg_type_number_t);

int main() {
    using namespace SilentAimMapping;
    const auto self = mach_task_self();
    const auto start = SilentAimMappingFixtureStart;
    const auto end = SilentAimMappingFixtureEnd;
    assert(!Map(self, start + 4, end).address);
    assert(!Map(self, start, end - 4).address);
    const auto denied = Map(MACH_PORT_NULL, start, end);
    assert(!denied.address && denied.error != KERN_SUCCESS);

    mach_vm_address_t writable = 0;
    constexpr vm_prot_t rw = VM_PROT_READ | VM_PROT_WRITE;
    assert(mach_vm_map(self, &writable, SILENT_REMOTE_PAGE, SILENT_REMOTE_PAGE - 1,
        VM_FLAGS_ANYWHERE, MACH_PORT_NULL, 0, false, rw, rw, VM_INHERIT_NONE) == KERN_SUCCESS);
    const auto rejected = Map(self, reinterpret_cast<void *>(writable),
        reinterpret_cast<void *>(writable + SILENT_REMOTE_PAGE));
    assert(!rejected.address && rejected.error == KERN_PROTECTION_FAILURE);
    assert(mach_vm_deallocate(self, writable, SILENT_REMOTE_PAGE) == KERN_SUCCESS);

    for (unsigned i = 0; i < 8; ++i) {
        const auto mapping = Map(self, start, end);
        if (!mapping.address) std::cerr << mapping.operation << ": " << mapping.error << '\n';
        assert(mapping.address && mapping.error == KERN_SUCCESS);
        assert(std::memcmp(reinterpret_cast<void *>(mapping.address), start, SILENT_REMOTE_PAGE) == 0);
        vm_prot_t current = 0, maximum = 0;
        assert(Protection(self, mapping.address, current, maximum) == KERN_SUCCESS);
        assert(current == (VM_PROT_READ | VM_PROT_EXECUTE) && current == maximum);
        assert(Protection(self, mapping.address + SILENT_REMOTE_PAGE, current, maximum) == KERN_SUCCESS);
        assert(current == rw && maximum == rw);
        uint32_t value = 37 + i;
        assert(mach_vm_write(self, mapping.address + SILENT_REMOTE_PAGE,
            reinterpret_cast<pointer_t>(&value), sizeof(value)) == KERN_SUCCESS);
        // The signed fixture uses a PC-relative read from the adjacent state page.
        const auto callback = reinterpret_cast<uint32_t (*)()>(mapping.address);
        assert(callback() == value);
        assert(mach_vm_write(self, mapping.address, reinterpret_cast<pointer_t>(&value),
            sizeof(value)) != KERN_SUCCESS);
        assert(callback() == value);
        assert(mach_vm_deallocate(self, mapping.address, 2 * SILENT_REMOTE_PAGE) == KERN_SUCCESS);
    }
    std::cout << "Signed RX page mapping, adjacent RW state, execution and write rejection passed\n";
}
