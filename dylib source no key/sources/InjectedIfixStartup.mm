#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <cstdint>
#include <cstring>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <string>
#include <vector>
#include "InjectedIfixStartup.h"

extern "C" const uint8_t mizze_ifix_start[], mizze_ifix_end[];
uintptr_t GetGameModule_Base(char *);

namespace {
struct Domain;
struct Assembly;
struct Image;
struct Class;
struct Type;
struct Method;
struct Field;
struct Object;
struct Array;
struct Exception;

struct Runtime {
    Domain *(*domain_get)();
    const Assembly **(*domain_get_assemblies)(const Domain *, size_t *);
    const Image *(*assembly_get_image)(const Assembly *);
    const char *(*image_get_name)(const Image *);
    Class *(*class_from_name)(const Image *, const char *, const char *);
    const Method *(*class_get_methods)(Class *, void **);
    const char *(*method_get_name)(const Method *);
    uint32_t (*method_get_param_count)(const Method *);
    const Type *(*method_get_param)(const Method *, uint32_t);
    char *(*type_get_name)(const Type *);
    Object *(*type_get_object)(const Type *);
    Object *(*method_get_object)(const Method *, Class *);
    Object *(*object_new)(const Class *);
    Array *(*array_new)(Class *, uintptr_t);
    uint32_t (*array_object_header_size)();
    uintptr_t (*array_length)(Array *);
    Object *(*runtime_invoke)(const Method *, void *, void **, Exception **);
    void *(*object_unbox)(Object *);
    Object *(*string_new)(const char *);
    uint32_t (*gchandle_new)(Object *, bool);
    void (*gchandle_free)(uint32_t);
    Field *(*class_get_field_from_name)(Class *, const char *);
    void (*field_static_get_value)(Field *, void *);
    void (*field_static_set_value)(Field *, void *);
    void (*gc_wbarrier_set_field)(Object *, void **, void *);
    void (*format_exception)(Exception *, char *, int);
    void (*free)(void *);

    bool bind(void *image) {
#define BIND(name) name = reinterpret_cast<decltype(name)>(dlsym(image, "il2cpp_" #name)); if (!name) return false
        BIND(domain_get); BIND(domain_get_assemblies); BIND(assembly_get_image); BIND(image_get_name);
        BIND(class_from_name); BIND(class_get_methods); BIND(method_get_name);
        BIND(method_get_param_count); BIND(method_get_param); BIND(type_get_name);
        BIND(type_get_object); BIND(method_get_object); BIND(object_new); BIND(array_new);
        BIND(array_object_header_size); BIND(array_length); BIND(runtime_invoke);
        BIND(object_unbox); BIND(string_new); BIND(gchandle_new); BIND(gchandle_free);
        BIND(class_get_field_from_name); BIND(field_static_get_value);
        BIND(field_static_set_value); BIND(gc_wbarrier_set_field); BIND(format_exception); BIND(free);
#undef BIND
        return true;
    }

    const Method *find(Class *owner, const char *name, uint32_t count, const char *first = nullptr) {
        if (!owner) return nullptr;
        void *iter = nullptr;
        while (const auto *candidate = class_get_methods(owner, &iter)) {
            if (strcmp(method_get_name(candidate), name) || method_get_param_count(candidate) != count)
                continue;
            if (first) {
                char *type = type_get_name(method_get_param(candidate, 0));
                bool same = type && strcmp(first, type) == 0;
                if (type) free(type);
                if (!same) continue;
            }
            return candidate;
        }
        return nullptr;
    }

    Object *invoke(const Method *method, void *instance, void **args, std::string &error) {
        if (!method || !error.empty()) return nullptr;
        Exception *exception = nullptr;
        auto *result = runtime_invoke(method, instance, args, &exception);
        if (exception) {
            char message[512] = {};
            format_exception(exception, message, sizeof(message));
            error = message[0] ? message : "Managed IFix exception";
            return nullptr;
        }
        return result;
    }
} runtime;

struct Roots {
    std::vector<uint32_t> handles;
    template <typename T> T *add(T *object) {
        if (object) handles.push_back(runtime.gchandle_new(reinterpret_cast<Object *>(object), false));
        return object;
    }
    ~Roots() { for (auto handle : handles) runtime.gchandle_free(handle); }
};

constexpr uintptr_t kEntryRva = 0x504f078;
constexpr uint8_t kEntryBytes[] = {0xe9,0x23,0xbc,0x6d,0xf6,0x57,0x01,0xa9,
                                   0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9};
constexpr char kMarker[] = "__mizze_nokey_vn_startup_ed95";
constexpr size_t kMaxSlots = 1 << 20;
constexpr unsigned kMaxTicks = 240;
NSTimer *timer;
void (*menuReady)();
void *unityHandle;
const Method *findMarker;
const Method *destroyMarker;
Field *wrapperField;
uint32_t vmRoot;
uint32_t redirectRoot;
Object *ownedRedirect;
size_t slot;
size_t arrayHeader;
unsigned ticks;
unsigned loads;
bool installed;

Array *table() {
    Array *result = nullptr;
    runtime.field_static_get_value(wrapperField, &result);
    return result;
}

Object **slots(Array *array) {
    return reinterpret_cast<Object **>(reinterpret_cast<uint8_t *>(array) + arrayHeader);
}

void setSlot(Array *array, size_t index, Object *value) {
    runtime.gc_wbarrier_set_field(reinterpret_cast<Object *>(array),
        reinterpret_cast<void **>(slots(array) + index), value);
}

bool bindUnity(std::string &error) {
    if (unityHandle) return true;
    char process[] = "FreeFireVN";
    uintptr_t base = GetGameModule_Base(process); // Validates bundle and Unity UUID.
    if (!base) return false;
    if (memcmp(reinterpret_cast<const void *>(base + kEntryRva), kEntryBytes, sizeof(kEntryBytes))) {
        error = "COWGameEntry.Update fingerprint mismatch";
        return false;
    }
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        if (reinterpret_cast<uintptr_t>(_dyld_get_image_header(i)) != base) continue;
        auto *handle = dlopen(_dyld_get_image_name(i), RTLD_NOW | RTLD_NOLOAD);
        if (!handle) return false;
        if (!runtime.bind(handle)) {
            dlclose(handle);
            error = "Missing IL2CPP exports";
            return false;
        }
        unityHandle = handle;
        return true;
    }
    return false;
}

bool install(std::string &error) {
    auto *domain = runtime.domain_get();
    if (!domain) return false;
    size_t count = 0;
    auto **assemblies = runtime.domain_get_assemblies(domain, &count);
    if (!assemblies || count > 2048) return false;
    const Image *game = nullptr, *core = nullptr, *corlib = nullptr, *engine = nullptr;
    for (size_t i = 0; i < count; ++i) {
        auto *image = runtime.assembly_get_image(assemblies[i]);
        auto *name = image ? runtime.image_get_name(image) : nullptr;
        if (!name) continue;
        if (!strcmp(name, "Assembly-CSharp.dll")) game = image;
        else if (!strcmp(name, "IFix.Core.dll")) core = image;
        else if (!strcmp(name, "mscorlib.dll")) corlib = image;
        else if (!strcmp(name, "UnityEngine.CoreModule.dll")) engine = image;
    }
    if (!game || !core || !corlib || !engine) return false;

    auto *optimize = runtime.find(runtime.class_from_name(core, "IFix.Core", "PatchManager"), "OptimizeLoad", 4);
    auto *helper = runtime.class_from_name(game, "GCommon", "IL2CPPOptimize");
    auto *index = runtime.find(helper, "GetPositionIndex", 1);
    auto *log = runtime.find(helper, "DebugLogInIFix", 1);
    auto *entry = runtime.find(runtime.class_from_name(game, "COW", "COWGameEntry"), "Update", 0);
    auto *create = runtime.find(runtime.class_from_name(corlib, "System", "Delegate"), "CreateDelegate", 2, "System.Type");
    auto *streamClass = runtime.class_from_name(corlib, "System.IO", "MemoryStream");
    auto *streamCtor = runtime.find(streamClass, ".ctor", 1, "System.Byte[]");
    auto *byteClass = runtime.class_from_name(corlib, "System", "Byte");
    auto *wrapper = runtime.class_from_name(game, "IFix", "ILFixDynamicMethodWrapper");
    wrapperField = wrapper ? runtime.class_get_field_from_name(wrapper, "wrapperArray") : nullptr;
    findMarker = runtime.find(runtime.class_from_name(engine, "UnityEngine", "GameObject"), "Find", 1, "System.String");
    destroyMarker = runtime.find(runtime.class_from_name(engine, "UnityEngine", "Object"), "Destroy", 1, "UnityEngine.Object");
    if (!optimize || !entry || !index || !log || !create || !streamCtor || !byteClass ||
        !wrapperField || !findMarker || !destroyMarker) {
        error = "IFix or Unity method signature mismatch";
        return false;
    }

    Roots roots;
    auto *reflectEntry = roots.add(runtime.method_get_object(entry, nullptr));
    void *positionArgs[] = {reflectEntry};
    auto *position = reflectEntry ? roots.add(runtime.invoke(index, nullptr, positionArgs, error)) : nullptr;
    auto *value = position ? static_cast<int32_t *>(runtime.object_unbox(position)) : nullptr;
    if (!value || *value < 0 || static_cast<size_t>(*value) >= kMaxSlots) {
        error = "Update IFix slot is invalid";
        return false;
    }
    slot = static_cast<size_t>(*value);
    arrayHeader = runtime.array_object_header_size();
    if (arrayHeader < 3 * sizeof(void *) || arrayHeader > 128 || arrayHeader % sizeof(void *)) {
        error = "Managed array header is invalid";
        return false;
    }
    auto *before = roots.add(table());
    size_t beforeLength = before ? runtime.array_length(before) : 0;
    if (beforeLength > kMaxSlots) {
        error = "Existing IFix table exceeds supported size";
        return false;
    }
    // Never replace a redirect already owned by the game at this slot.
    if (slot < beforeLength && slots(before)[slot]) return false;

    auto bindDelegate = [&](uint32_t parameter, const Method *target) {
        auto *type = roots.add(runtime.type_get_object(runtime.method_get_param(optimize, parameter)));
        auto *method = roots.add(runtime.method_get_object(target, nullptr));
        void *args[] = {type, method};
        return type && method ? roots.add(runtime.invoke(create, nullptr, args, error)) : nullptr;
    };
    auto *logger = bindDelegate(0, log);
    auto *resolver = bindDelegate(1, index);
    const auto size = reinterpret_cast<uintptr_t>(mizze_ifix_end) - reinterpret_cast<uintptr_t>(mizze_ifix_start);
    if (!logger || !resolver || size < 8 || size > 64 * 1024) {
        error = "Unable to bind IFix delegates or invalid embedded payload";
        return false;
    }
    auto *bytes = roots.add(runtime.array_new(byteClass, size));
    auto *stream = roots.add(runtime.object_new(streamClass));
    if (!bytes || !stream) {
        error = "Unable to allocate IFix MemoryStream";
        return false;
    }
    memcpy(reinterpret_cast<uint8_t *>(bytes) + arrayHeader, mizze_ifix_start, size);
    void *streamArgs[] = {bytes};
    runtime.invoke(streamCtor, stream, streamArgs, error);
    if (!error.empty()) return false;

    bool checkNew = true;
    void *loadArgs[] = {logger, resolver, stream, &checkNew};
    auto *vm = roots.add(runtime.invoke(optimize, nullptr, loadArgs, error));
    auto *after = roots.add(table());
    const size_t afterLength = after ? runtime.array_length(after) : 0;
    if (!vm || !after || afterLength > kMaxSlots || slot >= afterLength || !slots(after)[slot]) {
        if (after != before) runtime.field_static_set_value(wrapperField, &before);
        else if (slot < beforeLength && slots(before)[slot]) setSlot(before, slot, nullptr);
        if (error.empty()) error = "IFix did not install the startup redirect";
        return false;
    }
    if (before && before != after) {
        if (beforeLength > afterLength) {
            setSlot(before, slot, slots(after)[slot]);
            runtime.field_static_set_value(wrapperField, &before);
        } else {
            for (size_t i = 0; i < beforeLength; ++i)
                if (i != slot && slots(before)[i]) setSlot(after, i, slots(before)[i]);
        }
    }
    ownedRedirect = slots(after)[slot];
    redirectRoot = runtime.gchandle_new(ownedRedirect, false);
    vmRoot = runtime.gchandle_new(vm, false);
    ++loads;
    return true;
}

void tick() {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    std::string error;
    if (++ticks <= kMaxTicks && bindUnity(error)) {
        if (!installed) installed = install(error);
        if (installed) {
            Roots roots;
            auto *name = roots.add(runtime.string_new(kMarker));
            void *findArgs[] = {name};
            auto *marker = name ? roots.add(runtime.invoke(findMarker, nullptr, findArgs, error)) : nullptr;
            if (marker) {
                void *destroyArgs[] = {marker};
                runtime.invoke(destroyMarker, nullptr, destroyArgs, error);
                [timer invalidate];
                timer = nil;
                NSLog(@"[Mizze] IFix Update completed; starting NoKey overlay");
                if (menuReady) menuReady();
                return;
            }
            auto *current = table();
            if (error.empty() && (!current || slot >= runtime.array_length(current) ||
                                  slots(current)[slot] != ownedRedirect)) {
                // An official patch can replace the table between load and Update.
                // Try again only if the game's replacement leaves Update unclaimed.
                runtime.gchandle_free(redirectRoot);
                runtime.gchandle_free(vmRoot);
                redirectRoot = 0;
                vmRoot = 0;
                ownedRedirect = nullptr;
                installed = false;
                if (loads >= 3) error = "The game replaced the IFix startup redirect";
            }
        }
    }
    if (ticks >= kMaxTicks || !error.empty()) {
        if (installed) {
            auto *current = table();
            if (current && slot < runtime.array_length(current) && slots(current)[slot] == ownedRedirect)
                setSlot(current, slot, nullptr);
        }
        if (redirectRoot) runtime.gchandle_free(redirectRoot);
        if (vmRoot) runtime.gchandle_free(vmRoot);
        redirectRoot = vmRoot = 0;
        ownedRedirect = nullptr;
        [timer invalidate];
        timer = nil;
        NSLog(@"[Mizze] IFix startup stopped: %s",
              error.empty() ? "Timed out waiting for the Update hook" : error.c_str());
    }
}
}

void MizzeStartIfixStartup(void (*ready)()) {
    if (timer || ![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.garena.ffvn"]) return;
    menuReady = ready;
    timer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *) { tick(); }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}
