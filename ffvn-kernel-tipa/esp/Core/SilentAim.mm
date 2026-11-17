#include "GameOffsets.h"
#include "SilentAim.h"
#include "SilentAimDirection.h"
#include "SilentAimPolicy.h"
#include "VirtualHookRegistry.h"
#include "SilentAimNativePolicy.h"

#if defined(MIZZE_INJECTED) && (defined(__aarch64__) || defined(__arm64__))
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <QuartzCore/QuartzCore.h>
#include <atomic>
#include <array>
#include <cstring>
#include <mutex>

namespace {
// These addresses and layouts are specific to the supplied 1.132.1 IPA.
constexpr uint64_t WeaponGetter = GameOffsets::Rva(0x5616118);
constexpr uint64_t HandlerMethod = GameOffsets::Rva(0x5C59B94);
constexpr uint64_t WeaponOwner = 0x60;
constexpr uint64_t WeaponHandler = 0x80;
constexpr uint64_t HandlerWeapon = 0x10;
constexpr uint64_t HandlerInfo = 0x28;
constexpr uint64_t InfoDirection = 0x40;
constexpr uint64_t InfoOrigin = 0x4C;
constexpr uint64_t HandlerSlot = 0x138 + 17 * 16;
constexpr uint64_t ModifierSlot = 0x138 + 11 * 16;
using NativeModifier = void (*)(uint64_t, SilentAimDirection::Point *, float, float, const void *);
using NativeHandler = void (*)(uint64_t, const void *);
using NativeWeaponGetter = uint64_t (*)(uint64_t, const void *);
using SilentAimDirection::Point;

struct Snapshot {
    uint64_t module = 0, match = 0, local = 0, target = 0;
    Point head;
    Point body;
    uint32_t headPercent = 75;
    double updated = 0;
};
std::mutex snapshotMutex;
std::recursive_mutex dispatchMutex;
Snapshot snapshot;
std::atomic<bool> enabled{false};
std::atomic<uint64_t> redirects{0};
// The original address stays available after OFF for dispatches already in flight.
std::atomic<uint64_t> originalHandler{0};
VirtualHooks::Registry<> hookRegistry;
uint64_t verifiedBase = 0;
SilentAimFailure lastFailure;
uint32_t headPhase = 50;
thread_local const Point *currentShotTarget = nullptr;
alignas(8) uint64_t autoShotWeapon = 0;

template <typename T> bool Read(uint64_t address, T &value) {
    return isVaildPtr(address) && _read((long)address, &value, sizeof(value));
}
bool ClassName(uint64_t object, const char *expected) {
    uint64_t klass = 0, name = 0;
    char buffer[32]{};
    if (!Read(object, klass) || !Read(klass + 0x10, name)) return false;
    const size_t length = std::strlen(expected) + 1;
    return length <= sizeof(buffer) && _read((long)name, buffer, (int)length) &&
        std::memcmp(buffer, expected, length) == 0;
}
template <size_t N> bool Fingerprint(uint64_t address, uint32_t expected) {
    std::array<uint8_t, N> bytes{};
    if (!Read(address, bytes)) return false;
    uint32_t hash = 0x811C9DC5;
    for (uint8_t byte : bytes) hash = (hash ^ byte) * 0x01000193u;
    return hash == GameOffsets::ExpectedHash(expected);
}
bool Fingerprints(uint64_t base) {
    // Check the whole getter and the handler through its direction reads;
    // common ARM64 prologue instructions alone do not identify a game build.
    return Fingerprint<0xCC>(base + WeaponGetter, 0xC5E012EE) &&
        Fingerprint<0x16C>(base + HandlerMethod, 0xDFE8FAC6);
}
bool WritablePointer(uint64_t address) {
    if (!isVaildPtr(address) || address % alignof(uint64_t)) return false;
    mach_vm_address_t region = address;
    mach_vm_size_t size = 0;
    natural_t depth = 0;
    vm_region_submap_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    return mach_vm_region_recurse(mach_task_self(), &region, &size, &depth,
        (vm_region_recurse_info_t)&info, &count) == KERN_SUCCESS &&
        region <= address && address - region <= size &&
        size - (address - region) >= sizeof(uint64_t) &&
        !info.is_submap && (info.protection & VM_PROT_WRITE);
}
bool ClassDerives(uint64_t object, const char *name) {
    uint64_t klass=0;
    if (!Read(object,klass)) return false;
    return SilentAimNative::Derives(klass,name,[](uint64_t a,uint64_t &v){return Read(a,v);},
        [](uint64_t address,const char *expected){
            uint64_t text=0; char buffer[64]{};
            const size_t length=std::strlen(expected)+1;
            return length<=sizeof(buffer) && Read(address,text) &&
                _read((long)text,buffer,(int)length) && std::memcmp(buffer,expected,length)==0;
        });
}
bool ExchangeSlot(uint64_t address,uint64_t &expected,uint64_t replacement) {
    return __atomic_compare_exchange_n(reinterpret_cast<uint64_t *>(address),&expected,
        replacement,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
}
uint64_t Original(uint64_t handler,uint64_t offset) {
    uint64_t klass=0;
    return Read(handler,klass) ? hookRegistry.original(klass+offset) : 0;
}
bool Current(const Snapshot &s, uint64_t weapon) {
    uint8_t localKnocked = 0, targetKnocked = 0;
    // A native shot/aim callback is the event. A sampled firing PRI can lag
    // behind the first shot; it must not veto a verified local callback.
    return enabled.load() && SilentAimDirection::Fresh(s.updated, CACurrentMediaTime()) &&
        getMatch(getMatchGame(s.module)) == s.match && getLocalPlayer(s.match) == s.local &&
        get_CurHP(s.local) > 0 && get_CurHP(s.target) > 0 && getAimVisibility(s.target) &&
        reinterpret_cast<NativeWeaponGetter>(s.module+WeaponGetter)(s.local,nullptr)==weapon &&
        !isLocalTeamMate(s.local, s.target) &&
        Read(s.local + kKnocked, localKnocked) && localKnocked == 0 &&
        Read(s.target + kKnocked, targetKnocked) && targetKnocked == 0;
}
void RedirectModifier(uint64_t handler,Point *direction,float spread,float range,const void *method) {
    std::lock_guard<std::recursive_mutex> guard(dispatchMutex);
    const auto original=reinterpret_cast<NativeModifier>(Original(handler,ModifierSlot));
    if (!original) return;
    original(handler,direction,spread,range,method);
#ifndef MIZZE_GAME_MAX
    Snapshot s; { std::lock_guard<std::mutex> lock(snapshotMutex); s=snapshot; }
    uint64_t weapon=0,owner=0;
    if (!direction || !s.target || !Read(handler+HandlerWeapon,weapon) ||
        !Read(weapon+WeaponOwner,owner) || owner!=s.local || !Current(s,weapon) ||
        ReadAddr<uint64_t>(weapon+WeaponHandler)!=handler) return;
    // TH's verified AimStartPostion is the origin used by the aiming query.
    // Override the native ref direction before raycast consumes it, rather
    // than changing only the already-computed result direction afterwards.
    using Origin=Point (*)(uint64_t,const void *);
    Point origin{}; uint64_t info=0;
    if (!Read(handler+HandlerInfo,info) || !ClassName(info,"CGKJLKPMGDJ") ||
        !Read(info+InfoOrigin,origin) || !SilentAimDirection::Finite(origin))
        origin=reinterpret_cast<Origin>(s.module+GameOffsets::Rva(0x56A5F94))(s.local,nullptr);
    uint32_t next=0;
    const Point target=currentShotTarget ? *currentShotTarget :
        (SilentAimPolicy::Head(s.headPercent,headPhase,next)?s.head:s.body);
    Point desired{},live{};
    if (Read(reinterpret_cast<uint64_t>(direction),live) && SilentAimDirection::Finite(live) &&
        SilentAimDirection::Toward(origin,target,desired) &&
        _write((long)direction,&desired,sizeof(desired))) {
        redirects.fetch_add(1);
    }
#endif
}

void RedirectHandler(uint64_t handler, const void *method) {
    std::lock_guard<std::recursive_mutex> dispatchGuard(dispatchMutex);
    const auto original = reinterpret_cast<NativeHandler>(Original(handler,HandlerSlot));
    if (!original) return; // Installation publishes this before replacing the slot.
    Snapshot s;
    { std::lock_guard<std::mutex> guard(snapshotMutex); s = snapshot; }
    uint64_t weapon = 0, owner = 0, info = 0;
    Point origin{}, desired{};
    uint32_t nextPhase = 0;
    const bool nested=currentShotTarget!=nullptr;
    const Point aimPoint = nested ? *currentShotTarget :
        (SilentAimPolicy::Head(s.headPercent, headPhase, nextPhase) ? s.head : s.body);
    if (!s.target || !Read(handler + HandlerWeapon, weapon) ||
        !Read(weapon + WeaponOwner, owner) || owner != s.local ||
        !Current(s, weapon) ||
        ReadAddr<uint64_t>(weapon + WeaponHandler) != handler ||
        !Read(handler + HandlerInfo, info) || !ClassName(info, "CGKJLKPMGDJ") ||
        !Read(info + InfoOrigin, origin) ||
        !SilentAimDirection::Toward(origin, aimPoint, desired)) {
        original(handler, method);
        return;
    }
    const bool changed = SilentAimDirection::Dispatch(desired,
        [&](Point &p) { return Read(info + InfoDirection, p); },
        [&](Point p) { return _write((long)(info + InfoDirection), &p, sizeof(p)); },
        [&] { return ReadAddr<uint64_t>(handler + HandlerInfo) == info &&
            ReadAddr<uint64_t>(handler + HandlerWeapon) == weapon; },
        [&] {
            SilentAimNative::ScopedTarget<Point> shot(currentShotTarget,aimPoint);
            original(handler, method);
        });
    // The earlier aiming callback prepares the next shot. Consume the head/body
    // phase only when this actual common-fire callback executes.
    if (!nested) headPhase = nextPhase;
    if (changed) redirects.fetch_add(1);
}
void Uninstall() {
    std::lock_guard<std::recursive_mutex> guard(dispatchMutex);
    hookRegistry.restoreAll([](uint64_t a,uint64_t &v){return Read(a,v);},WritablePointer,ExchangeSlot);
}
bool InstallSlot(uint64_t slot,uint64_t expected,uint64_t replacement) {
    const auto result=hookRegistry.install(slot,expected,replacement,
        [](uint64_t a,uint64_t &v){return Read(a,v);},WritablePointer,ExchangeSlot);
    if (result==VirtualHooks::Registry<>::Result::Installed ||
        result==VirtualHooks::Registry<>::Result::Existing) return true;
    lastFailure={result==VirtualHooks::Registry<>::Result::ReadOnly ? "vtable không ghi được" :
        "vtable đã thay đổi hoặc chưa hỗ trợ",result==VirtualHooks::Registry<>::Result::ReadOnly ? KERN_PROTECTION_FAILURE : 0};
    return false;
}

} // namespace

void SilentAimClearTarget() {
    std::lock_guard<std::mutex> guard(snapshotMutex);
    snapshot = {};
}
void SilentAimSetEnabled(bool value) {
    const bool previous = enabled.exchange(value);
    if (!value || previous != value) SilentAimClearTarget();
    if (!value) Uninstall();
}
uint64_t SilentAimRedirectCount() { return redirects.load(); }
uint64_t SilentAimAutoFireGate() {
    return enabled.load() && originalHandler.load() ? reinterpret_cast<uint64_t>(&autoShotWeapon) : 0;
}
SilentAimFailure SilentAimLastFailure() { std::lock_guard<std::recursive_mutex> guard(dispatchMutex); return lastFailure; }
int SilentAimUpdate(uint64_t base, uint64_t match, uint64_t local,
                    uint64_t target, const Vector3 &head, const Vector3 &body, uint32_t headPercent) {
    std::lock_guard<std::recursive_mutex> guard(dispatchMutex);
    SilentAimClearTarget();
    if (!enabled.load()) return 1;
    if (!isVaildPtr(base) || !isVaildPtr(match) || !isVaildPtr(local) ||
        getMatch(getMatchGame(base)) != match || getLocalPlayer(match) != local) { Uninstall(); return 9; }
    if (verifiedBase!=base) {
        if (!Fingerprints(base)) { lastFailure={"fingerprint game không khớp",0}; Uninstall(); return 9; }
#ifndef MIZZE_GAME_MAX
        if (!Fingerprint<0x100>(base+GameOffsets::Rva(0x56A5F94),0xA1643E14) ||
            !Fingerprint<0x100>(base+GameOffsets::Rva(0x5C5D370),0x10B69D75)) {
            lastFailure={"đường tính hướng không khớp",0}; return 9;
        }
#endif
        verifiedBase=base;
    }
    const uint64_t weapon = reinterpret_cast<NativeWeaponGetter>(base + WeaponGetter)(local, nullptr);
    uint64_t handler = 0, klass = 0, owner=0;
    if (!Read(weapon + WeaponOwner, owner) || owner != local ||
        !Read(weapon + WeaponHandler, handler) || !ClassDerives(handler,"MDPBNKPCGNG") ||
        !Read(handler, klass)) { lastFailure={"chờ handler vũ khí",0}; return 9; }
    uint64_t current=0;
    bool commonReady=false,modifierReady=false;
    const uint64_t slot=klass+HandlerSlot;
    if (Read(slot,current)) {
        const auto *record=hookRegistry.find(slot);
        const uint64_t expected=record ? record->original : current;
        if (expected==base+HandlerMethod)
            commonReady=InstallSlot(slot,expected,reinterpret_cast<uint64_t>(&RedirectHandler));
    }
#ifndef MIZZE_GAME_MAX
    const uint64_t modifierSlot=klass+ModifierSlot;
    if (Read(modifierSlot,current)) {
        const auto *record=hookRegistry.find(modifierSlot);
        const uint64_t expected=record ? record->original : current;
        if (expected==base+GameOffsets::Rva(0x5C5D36C))
            modifierReady=InstallSlot(modifierSlot,expected,reinterpret_cast<uint64_t>(&RedirectModifier));
    }
#endif
    if (!commonReady && !modifierReady) return 9;
    originalHandler.store(base+HandlerMethod);
    lastFailure={};
    if (!target || !SilentAimDirection::Finite({head.x, head.y, head.z}) ||
        !SilentAimDirection::Finite({body.x, body.y, body.z}) || headPercent>100) return 7;
    { std::lock_guard<std::mutex> guard(snapshotMutex);
      snapshot = {base, match, local, target, {head.x, head.y, head.z},
          {body.x, body.y, body.z}, headPercent, CACurrentMediaTime()}; }
    return 8;
}
#elif !defined(__aarch64__) && !defined(__arm64__)
void SilentAimSetEnabled(bool) {}
void SilentAimClearTarget() {}
uint64_t SilentAimRedirectCount() { return 0; }
uint64_t SilentAimAutoFireGate() { return 0; }
SilentAimFailure SilentAimLastFailure() { return {}; }
int SilentAimUpdate(uint64_t, uint64_t, uint64_t, uint64_t, const Vector3 &, const Vector3 &, uint32_t) { return 9; }
#endif
