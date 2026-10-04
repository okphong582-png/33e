#include "SilentAim.h"
#if !defined(MIZZE_INJECTED) && (defined(__aarch64__) || defined(__arm64__))
#include "SilentAimRemoteLayout.h"
#include "SilentAimWeapon.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <mach/vm_attributes.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>

extern "C" {
extern const unsigned char SilentAimRemoteStart[], SilentAimRemoteEnd[];
kern_return_t mach_vm_allocate(vm_map_t, mach_vm_address_t *, mach_vm_size_t, int);
kern_return_t mach_vm_deallocate(vm_map_t, mach_vm_address_t, mach_vm_size_t);
kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t, boolean_t, vm_prot_t);
}

namespace {
constexpr uint64_t WeaponGetter = 0x5616118, HandlerMethod = 0x5C59B94;
constexpr uint64_t HandlerSlot = 0x138 + 17 * 16;
std::recursive_mutex controllerMutex;
bool enabled = false;
mach_port_t ownedTask = MACH_PORT_NULL;
int ownedPID = -1;
uint64_t module = 0, allocation = 0, installedSlot = 0;
uint32_t sequence = 0;
double nextInstallAttempt = 0;
int installFailure = 0;

bool ReadBytes(uint64_t address, void *buffer, size_t size) {
    mach_vm_size_t actual = 0;
    return ownedTask != MACH_PORT_NULL && isVaildPtr(address) &&
        mach_vm_read_overwrite(ownedTask, address, size, (mach_vm_address_t)buffer, &actual) == KERN_SUCCESS &&
        actual == size;
}
bool WriteBytes(uint64_t address, const void *buffer, size_t size) {
    return ownedTask != MACH_PORT_NULL && isVaildPtr(address) &&
        mach_vm_write(ownedTask, address, (pointer_t)buffer, (mach_msg_type_number_t)size) == KERN_SUCCESS;
}
template <typename T> bool Read(uint64_t address, T &value) { return ReadBytes(address, &value, sizeof(value)); }
template <typename T> bool Write(uint64_t address, const T &value) { return WriteBytes(address, &value, sizeof(value)); }
uint64_t StateAddress() { return allocation + SILENT_REMOTE_PAGE; }

bool Publish(const SilentAimRemote::State &state) {
    if (!allocation) return false;
    // Odd sequence makes dispatches bypass a partially written snapshot.
    const uint32_t odd = (sequence + 1) | 1u;
    if (!Write(StateAddress() + SILENT_REMOTE_SEQUENCE, odd)) return false;
    sequence = odd + 1;
    constexpr size_t start = SILENT_REMOTE_ENABLED, end = SILENT_REMOTE_REDIRECTS;
    if (!WriteBytes(StateAddress() + start, (const uint8_t *)&state + start, end - start) ||
        !Write(StateAddress() + SILENT_REMOTE_MATCH, state.match)) return false;
    return Write(StateAddress() + SILENT_REMOTE_SEQUENCE, sequence);
}
void Clear() {
    if (allocation) Publish({});
}
bool WritablePointer(uint64_t address) {
    if (!isVaildPtr(address) || address % 8) return false;
    mach_vm_address_t region = address;
    mach_vm_size_t size = 0;
    natural_t depth = 0;
    vm_region_submap_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    return mach_vm_region_recurse(ownedTask, &region, &size, &depth,
        (vm_region_recurse_info_t)&info, &count) == KERN_SUCCESS &&
        region <= address && address - region <= size && size - (address - region) >= 8 &&
        !info.is_submap && (info.protection & VM_PROT_WRITE);
}
struct Suspended {
    bool active;
    Suspended() : active(task_suspend(ownedTask) == KERN_SUCCESS) {}
    ~Suspended() { if (active) task_resume(ownedTask); }
};
void Uninstall() {
    Clear();
    if (!installedSlot) return;
    Suspended suspension;
    if (!suspension.active) return;
    uint64_t current = 0;
    if (!Read(installedSlot, current)) return;
    if (current != allocation || (WritablePointer(installedSlot) &&
        Write(installedSlot, module + HandlerMethod))) installedSlot = 0;
    // Published code remains mapped: a thread can still hold a cached address.
}
void Detach() {
    if (ownedTask != MACH_PORT_NULL) {
        Uninstall();
        mach_port_deallocate(mach_task_self(), ownedTask);
    }
    ownedTask = MACH_PORT_NULL; ownedPID = -1;
    module = allocation = installedSlot = 0; sequence = 0;
    nextInstallAttempt = 0; installFailure = 0;
}
bool Attach(uint64_t base) {
    int pid = -1;
    if (get_task == MACH_PORT_NULL || pid_for_task(get_task, &pid) != KERN_SUCCESS) { Detach(); return false; }
    if (ownedTask == get_task && ownedPID == pid && module == base) return true;
    Detach();
    if (mach_port_mod_refs(mach_task_self(), get_task, MACH_PORT_RIGHT_SEND, 1) != KERN_SUCCESS) return false;
    ownedTask = get_task; ownedPID = pid; module = base;
    return true;
}
template <size_t N> bool Fingerprint(uint64_t address, uint32_t expected) {
    std::array<uint8_t, N> bytes{};
    if (!Read(address, bytes)) return false;
    uint32_t hash = 0x811C9DC5;
    for (uint8_t byte : bytes) hash = (hash ^ byte) * 0x01000193u;
    return hash == expected;
}
bool ClassName(uint64_t object, const char *expected) {
    uint64_t klass = 0, name = 0;
    char buffer[32]{};
    const size_t size = std::strlen(expected) + 1;
    return size <= sizeof(buffer) && Read(object, klass) && Read(klass + 0x10, name) &&
        ReadBytes(name, buffer, size) && std::memcmp(buffer, expected, size) == 0;
}
uint64_t RemoteClock() {
    Dl_info info{};
    const void *clock = (const void *)&mach_absolute_time;
    if (!dladdr(clock, &info) || !info.dli_fname || !info.dli_fbase) return 0;
    const char *name = std::strrchr(info.dli_fname, '/');
    const uint64_t base = get_image_base_address(ownedTask, name ? name + 1 : info.dli_fname);
    if (!base) return 0;
    const uint64_t address = base + ((uintptr_t)clock - (uintptr_t)info.dli_fbase);
    std::array<uint8_t, 32> bytes{};
    return Read(address, bytes) && std::memcmp(bytes.data(), clock, bytes.size()) == 0 ? address : 0;
}
bool Adopt(uint64_t address) {
    if (!isVaildPtr(address) || address % SILENT_REMOTE_PAGE) return false;
    std::array<uint8_t, SILENT_REMOTE_PAGE> code{};
    SilentAimRemote::State state{};
    if (!Read(address, code) || std::memcmp(code.data(), SilentAimRemoteStart, code.size()) ||
        !Read(address + SILENT_REMOTE_PAGE, state) || state.magic != SilentAimRemote::Magic ||
        state.original != module + HandlerMethod || state.clock != RemoteClock()) return false;
    allocation = address; sequence = state.sequence & ~1u;
    Clear();
    return true;
}
int Allocate() {
    using Status = int (*)(pid_t, unsigned int, void *, size_t);
    const auto status = reinterpret_cast<Status>(dlsym(RTLD_DEFAULT, "csops"));
    uint32_t flags = 0;
    if (!status || status(ownedPID, 0, &flags, sizeof(flags)) != 0 ||
        !SilentAimRemote::AllowsRemoteCode(flags)) return 10;
    // Avoid changing the game's code-sign policy to obtain executable memory.
    const uint64_t clock = RemoteClock();
    if (!clock || SilentAimRemoteEnd - SilentAimRemoteStart != SILENT_REMOTE_PAGE) return 9;
    using CacheFlush = kern_return_t (*)(vm_map_t, mach_vm_address_t, mach_vm_size_t,
        vm_machine_attribute_t, vm_machine_attribute_val_t *);
    const auto flush = reinterpret_cast<CacheFlush>(dlsym(RTLD_DEFAULT, "mach_vm_machine_attribute"));
    if (!flush) return 10;
    mach_vm_address_t region = 0;
    constexpr mach_vm_size_t size = 2 * SILENT_REMOTE_PAGE;
    if (mach_vm_allocate(ownedTask, &region, size, VM_FLAGS_ANYWHERE) != KERN_SUCCESS) return 10;
    SilentAimRemote::State initial{};
    initial.original = module + HandlerMethod; initial.clock = clock;
    vm_machine_attribute_val_t cache = MATTR_VAL_CACHE_FLUSH;
    const bool ready = region % SILENT_REMOTE_PAGE == 0 &&
        WriteBytes(region, SilentAimRemoteStart, SILENT_REMOTE_PAGE) &&
        Write(region + SILENT_REMOTE_PAGE, initial) &&
        flush(ownedTask, region, SILENT_REMOTE_PAGE, MATTR_CACHE, &cache) == KERN_SUCCESS &&
        mach_vm_protect(ownedTask, region, SILENT_REMOTE_PAGE, false, VM_PROT_READ | VM_PROT_EXECUTE) == KERN_SUCCESS;
    if (!ready) { mach_vm_deallocate(ownedTask, region, size); return 10; }
    allocation = region;
    return 8;
}
int Install(uint64_t slot) {
    if (installedSlot && installedSlot != slot) Uninstall();
    if (installedSlot && installedSlot != slot) return 9;
    uint64_t current = 0;
    if (!Read(slot, current)) return 9;
    if (installedSlot && current == allocation) return 8;
    installedSlot = 0;
    if (current != module + HandlerMethod) {
        if (!allocation && Adopt(current)) { installedSlot = slot; return 8; }
        return 9; // An injected dylib or another handler owns this slot.
    }
    if (!allocation) { const int result = Allocate(); if (result != 8) return result; }
    Suspended suspension;
    if (!suspension.active || !WritablePointer(slot) || !Read(slot, current) ||
        current != module + HandlerMethod) return 10;
    if (!Write(slot, allocation)) return 10;
    installedSlot = slot;
    return 8;
}
bool Eligible(uint64_t match, uint64_t local, uint64_t target) {
    uint8_t localKnock = 0, targetKnock = 0;
    return getMatch(getMatchGame(module)) == match && getLocalPlayer(match) == local &&
        get_CurHP(local) > 0 && get_CurHP(target) > 0 && getAimVisibility(target) &&
        !isLocalTeamMate(local, target) && Read(local + kKnocked, localKnock) && !localKnock &&
        Read(target + kKnocked, targetKnock) && !targetKnock;
}
} // namespace

void SilentAimSetEnabled(bool value) {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    enabled = value;
    if (!value) Uninstall();
}
void SilentAimClearTarget() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    Clear();
}
uint64_t SilentAimRedirectCount() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    uint64_t value = 0;
    if (allocation) Read(StateAddress() + SILENT_REMOTE_REDIRECTS, value);
    return value;
}
int SilentAimUpdate(uint64_t base, uint64_t match, uint64_t local, uint64_t target, const Vector3 &head) {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    if (!enabled) return 1;
    if (!Attach(base)) return 10;
    if (!isVaildPtr(base) || !isVaildPtr(local) || !isVaildPtr(match) ||
        getMatch(getMatchGame(base)) != match || getLocalPlayer(match) != local ||
        !Fingerprint<0xCC>(base + WeaponGetter, 0xC5E012EE) ||
        !Fingerprint<0xA0>(base + SilentAimWeapon::ManagerGetter, 0x93FD3984) ||
        !Fingerprint<0x16C>(base + HandlerMethod, 0xDFE8FAC6)) { Uninstall(); return 9; }
    const uint64_t weapon = SilentAimWeapon::OnHand(local,
        [](uint64_t a, auto &v) { return Read(a, v); }, [](uint64_t a) { return isVaildPtr(a); });
    uint64_t handler = 0, klass = 0, info = 0, infoClass = 0;
    if (!weapon || !Read(weapon + 0x80, handler) || !ClassName(handler, "MDPBNKPCGNG") ||
        !Read(handler, klass) || !Read(handler + 0x28, info) || !ClassName(info, "CGKJLKPMGDJ") ||
        !Read(info, infoClass)) { Uninstall(); return 9; }
    if (installFailure && CACurrentMediaTime() < nextInstallAttempt) { Clear(); return installFailure; }
    const int result = Install(klass + HandlerSlot);
    if (result != 8) {
        Clear(); installFailure = result; nextInstallAttempt = CACurrentMediaTime() + 1.0;
        return result;
    }
    installFailure = 0;
    if (!target || !SilentAimDirection::Finite({head.x, head.y, head.z}) ||
        !Eligible(match, local, target)) { Clear(); return 7; }
    mach_timebase_info_data_t timebase{};
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || !timebase.numer || !timebase.denom) { Clear(); return 9; }
    SilentAimRemote::State state{};
    state.enabled = 1; state.local = local; state.handler = handler; state.infoClass = infoClass;
    state.head = {head.x, head.y, head.z}; state.match = match;
    state.deadline = mach_absolute_time() + 150000000ULL * timebase.denom / timebase.numer;
    return Publish(state) ? 8 : 9;
}
#endif
