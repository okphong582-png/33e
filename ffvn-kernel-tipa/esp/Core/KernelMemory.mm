#include "KabraxHide.h"
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <mach-o/dyld_images.h>
#include <mach/task_info.h>
#include <algorithm>
#include <limits.h>
#include <sys/sysctl.h>
#include <signal.h>
#include <unistd.h>
#include <cstring>
#include <mutex>
#include <vector>
#include "pid.h"
#include "VnProfile.h"
#include "KernelMemory.h"
#include "KernelTableAddress.h"
#import "HUDHelper.h"

// Backend ABI recovered from hi.tipa, SHA256 70953e69...6fe84caf2.
// The task/map/pmap chain is checked before the game's UUID is inspected.
namespace {
struct Backend {
    void *library = nullptr;
    uint64_t (*findProcess)(pid_t) = nullptr;
    uint64_t (*processTask)(uint64_t) = nullptr;
    uint64_t (*readPointer)(uint64_t) = nullptr;
    uint64_t (*read64)(uint64_t) = nullptr;
    int (*readVirtual)(uint64_t, const void *, void *, size_t) = nullptr;
    int (*readProcess)(uint64_t, const void *, void *, size_t) = nullptr;
    int (*writeVirtual)(uint64_t, const void *, const void *, size_t) = nullptr;
    bool ready = false;
};
struct Target {
    pid_t pid = 0;
    uint64_t process = 0, map = 0, table = 0, base = 0, pmap = 0, tableOffset = 0;
    bool tableVerified = false;
};
Backend backend;
struct KernelLayout {
    uint64_t taskMap = 0x28, mapPmap = 0x40, pmapTtep = 8;
    uint64_t mapHeader = 0x10, headerLinks = 0, headerCount = 0x20;
    uint64_t entryLinks = 0, linksNext = 8, linksMin = 0x10, linksMax = 0x18;
} layout;
Target target;
std::mutex stateMutex;
bool scanRunning = false;
CFAbsoluteTime nextScan = 0;

void reportStatus(NSString *message) {
    HUDUpdateKernelStatus(message);
}

void loadKernelLayout() {
    auto serialize = reinterpret_cast<void *(*)()>(dlsym(backend.library, KH_STR("jbinfo_get_serialized")));
    auto getValue = reinterpret_cast<void *(*)(void *, const char *)>(dlsym(RTLD_DEFAULT, KH_STR("xpc_dictionary_get_value")));
    auto getNumber = reinterpret_cast<uint64_t (*)(void *, const char *)>(dlsym(RTLD_DEFAULT, KH_STR("xpc_dictionary_get_uint64")));
    auto release = reinterpret_cast<void (*)(void *)>(dlsym(RTLD_DEFAULT, KH_STR("xpc_release")));
    if (!serialize || !getValue || !getNumber || !release) return;
    void *information = serialize();
    if (!information) return;
    struct Field { const char *name; uint64_t *offset; } fields[] = {
        {"kernelStruct.task.map", &layout.taskMap},
        {"kernelStruct.vm_map.pmap", &layout.mapPmap},
        {"kernelStruct.pmap.ttep", &layout.pmapTtep},
        {"kernelStruct.vm_map.hdr", &layout.mapHeader},
        {"kernelStruct.vm_map_header.links", &layout.headerLinks},
        {"kernelStruct.vm_map_header.nentries", &layout.headerCount},
        {"kernelStruct.vm_map_entry.links", &layout.entryLinks},
        {"kernelStruct.vm_map_links.next", &layout.linksNext},
        {"kernelStruct.vm_map_links.min", &layout.linksMin},
        {"kernelStruct.vm_map_links.max", &layout.linksMax}
    };
    for (const auto &field : fields) {
        if (!getValue(information, field.name)) continue;
        uint64_t offset = getNumber(information, field.name);
        if (offset <= 0x2000 && !(offset & 3) && (offset || *field.offset == 0)) *field.offset = offset;
    }
    release(information);
}

bool kernelPointer(uint64_t address) { return address >= 0xffff000000000000ULL && !(address & 7); }
bool userRange(uint64_t address, size_t length) {
    return length && address >= 0x100000 && address < 0x1000000000000ULL &&
           length <= 0x1000000000000ULL - address;
}

NSArray<NSString *> *libraryCandidates() {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
    auto addRoot = [&](NSString *root) {
        [paths addObject:[root stringByAppendingPathComponent:KH_NS("usr/lib/libjailbreak.dylib")]];
        [paths addObject:[root stringByAppendingPathComponent:KH_NS("usr/lib/libjailbreak.roothide.dylib")]];
        [paths addObject:[root stringByAppendingPathComponent:KH_NS("basebin/libjailbreak.dylib")]];
    };
    addRoot([NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:KH_NS(".jbroot")]);
    NSFileManager *files = NSFileManager.defaultManager;
    for (NSString *container in @[KH_NS("/var/containers/Bundle/Application"), KH_NS("/var/mobile/Containers/Shared/AppGroup")]) {
        NSArray<NSString *> *entries = [files contentsOfDirectoryAtPath:container error:nil];
        for (NSString *entry in entries) {
            if ([entry hasPrefix:KH_NS(".jbroot-")])
                addRoot([container stringByAppendingPathComponent:entry]);
        }
    }
    [paths addObjectsFromArray:@[KH_NS("/var/jb/usr/lib/libjailbreak.dylib"),
        KH_NS("/var/jb/basebin/libjailbreak.dylib"), KH_NS("/var/jb/usr/lib/libjailbreak.roothide.dylib"),
        KH_NS("/usr/lib/libjailbreak.dylib"), KH_NS("/.jbroot/usr/lib/libjailbreak.dylib")]];
    NSString *bundled = [NSBundle.mainBundle pathForResource:KH_NS("libjailbreak") ofType:KH_NS("dylib")];
    if (bundled.length) [paths addObject:bundled];
    return paths.array;
}

bool loadBackendLibrary() {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *lastFailure = nil;
    bool foundFile = false;
    for (NSString *path in libraryCandidates()) {
        if (![files fileExistsAtPath:path]) continue;
        foundFile = true;
        dlerror();
        void *library = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
        if (library) {
            // RootHide variants may expose a different subset of the API.
            if (dlsym(library, KH_STR("proc_find")) && dlsym(library, KH_STR("proc_task")) && dlsym(library, KH_STR("vreadbuf"))) {
                backend.library = library;
                            return true;
            }
            lastFailure = [NSString stringWithFormat:KH_NS("%@ thiếu proc_find/proc_task/vreadbuf."), path];
            dlclose(library);
            continue;
        }
        const char *error = dlerror();
        NSString *detail = error ? [NSString stringWithUTF8String:error] : KH_NS("dlopen không trả lý do");
        if (detail.length > 320) detail = [detail substringToIndex:320];
        lastFailure = [NSString stringWithFormat:KH_NS("%@\n%@"), path, detail];
    }
    reportStatus(foundFile ? [KH_NS("Kernel không nạp được thư viện đã tìm thấy.\n") stringByAppendingString:lastFailure ?: KH_NS("")] :
        KH_NS("Kernel chưa tìm thấy libjailbreak trong .jbroot, .jbroot-* hoặc /var/jb. Kiểm tra trạng thái jailbreak trong Dopamine."));
    return false;
}

bool initializeBackend() {
    if (backend.ready) return true;
    if (getuid() != 0) { reportStatus(KH_NS("Kernel lỗi — HUD chưa có quyền root.")); return false; }
    if (!backend.library && !loadBackendLibrary()) return false;
    auto initialize = reinterpret_cast<int (*)()>(dlsym(backend.library, KH_STR("jbdInitPPLRW")));
    if (!initialize || initialize() != 0) { reportStatus(KH_NS("Kernel lỗi — jbdInitPPLRW chưa khởi tạo được.")); return false; }
    backend.findProcess = reinterpret_cast<decltype(backend.findProcess)>(dlsym(backend.library, KH_STR("proc_find")));
    backend.processTask = reinterpret_cast<decltype(backend.processTask)>(dlsym(backend.library, KH_STR("proc_task")));
    backend.readPointer = reinterpret_cast<decltype(backend.readPointer)>(dlsym(backend.library, KH_STR("kread_ptr")));
    backend.read64 = reinterpret_cast<decltype(backend.read64)>(dlsym(backend.library, KH_STR("kread64")));
    backend.readVirtual = reinterpret_cast<decltype(backend.readVirtual)>(dlsym(backend.library, KH_STR("vreadbuf")));
    backend.readProcess = reinterpret_cast<decltype(backend.readProcess)>(dlsym(backend.library, KH_STR("proc_vreadbuf")));
    backend.writeVirtual = reinterpret_cast<decltype(backend.writeVirtual)>(dlsym(backend.library, KH_STR("vwritebuf")));
    backend.ready = backend.findProcess && backend.processTask && backend.readPointer &&
                    backend.read64 && backend.readVirtual;
    if (backend.ready) loadKernelLayout();
    else reportStatus(KH_NS("Kernel lỗi — libjailbreak thiếu hàm đọc bắt buộc."));
    return backend.ready;
}

bool readTarget(const Target &context, uint64_t address, void *output, size_t length) {
    if (!output || !userRange(address, length)) return false;
    const void *source = reinterpret_cast<const void *>(address);
    if (context.tableVerified && backend.readVirtual(context.table, source, output, length) == 0) return true;
    if (backend.readProcess && context.process && backend.readProcess(context.process, source, output, length) == 0) return true;
    if (!backend.readProcess && context.table && backend.readVirtual(context.table, source, output, length) == 0) return true;
    memset(output, 0, length);
    return false;
}

bool validTable(uint64_t table) {
    return KernelMemory::ValidTableAddress(table);
}

bool verifyTable(Target &context) {
    // Compare the same loaded Unity header through the provider and raw vreadbuf.
    // A plausible physical address alone does not authorize a game write.
    mach_header_64 header{};
    if (backend.readProcess(context.process, reinterpret_cast<const void *>(context.base), &header, sizeof(header)) ||
        header.magic != MH_MAGIC_64 || header.sizeofcmds > 65536) return false;
    std::vector<uint8_t> expected(sizeof(header) + header.sizeofcmds);
    std::vector<uint8_t> actual(expected.size());
    if (backend.readProcess(context.process, reinterpret_cast<const void *>(context.base), expected.data(), expected.size())) return false;
    const uint64_t offsets[] = {layout.mapPmap, 0x40, 0x48, 0x50};
    for (uint64_t offset : offsets) {
        uint64_t pmap = backend.readPointer(context.map + offset);
        if (!kernelPointer(pmap)) continue;
        const uint64_t tableOffsets[] = {layout.pmapTtep, 0};
        for (uint64_t tableOffset : tableOffsets) {
            uint64_t table = backend.readPointer(pmap + tableOffset);
            if (!validTable(table)) continue;
            if (backend.readVirtual(table, reinterpret_cast<const void *>(context.base), actual.data(), actual.size()) ||
                expected != actual) continue;
            context.pmap = pmap;
            context.table = table;
            context.tableOffset = tableOffset;
            context.tableVerified = true;
            return true;
        }
    }
    context.table = 0;
    return false;
}

bool matchingImage(const Target &context, uint64_t address) {
    mach_header_64 header{};
    if (!readTarget(context, address, &header, sizeof(header)) || header.magic != MH_MAGIC_64 ||
        header.cputype != CPU_TYPE_ARM64 || header.filetype != MH_DYLIB ||
        header.sizeofcmds > 65536 || header.ncmds > 512 || header.sizeofcmds < sizeof(uuid_command)) return false;
    std::vector<uint8_t> commands(header.sizeofcmds);
    if (!readTarget(context, address + sizeof(header), commands.data(), commands.size())) return false;
    size_t offset = 0;
    for (uint32_t index = 0; index < header.ncmds; ++index) {
        if (offset + sizeof(load_command) > commands.size()) return false;
        load_command command{};
        memcpy(&command, commands.data() + offset, sizeof(command));
        if (command.cmdsize < sizeof(command) || command.cmdsize > commands.size() - offset) return false;
        if (command.cmd == LC_UUID) {
            if (command.cmdsize != sizeof(uuid_command)) return false;
            uuid_command uuid{};
            memcpy(&uuid, commands.data() + offset, sizeof(uuid));
            return memcmp(uuid.uuid, VnProfile::UnityUUID, sizeof(uuid.uuid)) == 0;
        }
        offset += command.cmdsize;
    }
    return false;
}

Target discover(pid_t pid) {
    Target context;
    context.pid = pid;
    context.process = backend.findProcess(pid);
    if (!kernelPointer(context.process)) { reportStatus(KH_NS("Kernel lỗi — proc_find chưa tìm được FFVN.")); return {}; }
    uint64_t task = backend.processTask(context.process);
    if (!kernelPointer(task)) { reportStatus(KH_NS("Kernel lỗi — chưa lấy được task của FFVN.")); return {}; }
    context.map = backend.readPointer(task + layout.taskMap);
    if (!kernelPointer(context.map)) { reportStatus(KH_NS("Kernel lỗi — chưa đọc được vm_map.")); return {}; }
    context.pmap = backend.readPointer(context.map + layout.mapPmap);
    context.tableOffset = layout.pmapTtep;
    if (kernelPointer(context.pmap)) context.table = backend.readPointer(context.pmap + layout.pmapTtep);
    if (!validTable(context.table)) {
        context.table = 0;
        if (!backend.readProcess) {
            reportStatus([NSString stringWithFormat:KH_NS("Kernel chưa lấy được TTEP, proc_vreadbuf không có. pmap offset=0x%llx, TTEP offset=0x%llx."), layout.mapPmap, layout.pmapTtep]);
            return {};
        }
    }
    const uint64_t header = context.map + layout.mapHeader;
    const uint64_t sentinel = header + layout.headerLinks;
    uint64_t entry = backend.readPointer(sentinel + layout.linksNext);
    const uint32_t count = static_cast<uint32_t>(backend.read64(header + layout.headerCount));
    if (!count || count > 32768) { reportStatus(KH_NS("Kernel lỗi — danh sách vùng nhớ chưa hợp lệ.")); return {}; }
    uint32_t readableHeaders = 0;
    for (uint32_t index = 0; index < count && entry != sentinel; ++index) {
        if (!kernelPointer(entry) || kill(pid, 0) != 0) return {};
        const uint64_t links = entry + layout.entryLinks;
        const uint64_t start = backend.read64(links + layout.linksMin);
        const uint64_t end = backend.read64(links + layout.linksMax);
        uint32_t magic = 0;
        if (end > start && userRange(start, sizeof(magic)) && readTarget(context, start, &magic, sizeof(magic)))
            ++readableHeaders;
        if (end > start && userRange(start, end - start) && matchingImage(context, start)) {
            if (backend.findProcess(pid) != context.process) return {};
            context.base = start;
            if (backend.readProcess) verifyTable(context);
            else context.tableVerified = true; // UUID matched using raw vreadbuf.
            reportStatus(context.tableVerified ? KH_NS("Đã đọc Unity FFVN và xác minh TTEP qua vreadbuf.") :
                KH_NS("Đã đọc Unity FFVN qua proc_vreadbuf. Chưa xác minh TTEP để ghi aim."));
            return context;
        }
        const uint64_t next = backend.readPointer(links + layout.linksNext);
        if (next == entry) return {};
        entry = next;
    }
    reportStatus(readableHeaders ? KH_NS("Kernel đọc được game, chưa thấy UUID Unity FFVN 1.134.1 đã đối chiếu.") :
                                  KH_NS("Kernel chưa đọc được dữ liệu game qua vreadbuf."));
    return {};
}
}

// Legacy remote-code installers can detect that this backend has no Mach task port.
mach_port_t get_task = MACH_PORT_NULL;

uint64_t KernelProcessIdentity() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return target.base ? target.process : 0;
}

bool KernelAimWriteReady() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return target.base && target.tableVerified && backend.writeVirtual;
}

mach_port_t KernelCopyTaskPort(uint64_t module, kern_return_t *error) {
    Target context;
    { std::lock_guard<std::mutex> lock(stateMutex); context = target; }
    *error = KERN_INVALID_ARGUMENT;
    if (!context.base || context.base != module || context.pid <= 0) return MACH_PORT_NULL;
    mach_port_t port = MACH_PORT_NULL;
    *error = task_for_pid(mach_task_self(), context.pid, &port);
    if (*error != KERN_SUCCESS) return MACH_PORT_NULL;
    int pid = -1;
    *error = pid_for_task(port, &pid);
    if (*error != KERN_SUCCESS || pid != context.pid || backend.findProcess(pid) != context.process) {
        mach_port_deallocate(mach_task_self(), port);
        if (*error == KERN_SUCCESS) *error = KERN_INVALID_ARGUMENT;
        return MACH_PORT_NULL;
    }
    return port;
}

pid_t GetGameProcesspid(char *name) {
    if (!name || !name[0]) return -1;
    int query[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    size_t length = 0;
    if (sysctl(query, 3, nullptr, &length, nullptr, 0) || !length || length > 32 * 1024 * 1024) return -1;
    std::vector<uint8_t> records(length);
    if (sysctl(query, 3, records.data(), &length, nullptr, 0)) return -1;
    for (size_t offset = 0; offset + sizeof(kinfo_proc) <= length; offset += sizeof(kinfo_proc)) {
        const auto *process = reinterpret_cast<const kinfo_proc *>(records.data() + offset);
        if (strncmp(process->kp_proc.p_comm, name, sizeof(process->kp_proc.p_comm)) == 0) return process->kp_proc.p_pid;
    }
    return -1;
}

uintptr_t GetGameModule_Base(char *name) {
    if (!name || strcmp(name, "FreeFireVN")) return 0;
    std::lock_guard<std::mutex> guard(stateMutex);
    if (target.pid && kill(target.pid, 0) != 0) target = {};
    if (scanRunning || CFAbsoluteTimeGetCurrent() < nextScan) return target.base;
    scanRunning = true;
    nextScan = CFAbsoluteTimeGetCurrent() + 2;
    static dispatch_queue_t queue = dispatch_queue_create("mizze.ffvn.kernel.scan", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        @autoreleasepool {
            Target found;
            if (initializeBackend()) {
                pid_t pid = GetGameProcesspid(const_cast<char *>("FreeFireVN"));
                if (pid > 0) {
                    Target previous;
                    { std::lock_guard<std::mutex> lock(stateMutex); previous = target; }
                    if (previous.pid == pid && previous.base && backend.findProcess(pid) == previous.process) {
                        found = previous;
                        if (!found.tableVerified && backend.readProcess && verifyTable(found))
                            reportStatus(KH_NS("Đã xác minh lại TTEP của FFVN qua vreadbuf."));
                    } else found = discover(pid);
                } else reportStatus(KH_NS("Đang chờ tiến trình FreeFireVN. Hãy mở game."));
            }
            std::lock_guard<std::mutex> lock(stateMutex);
            if (found.base && found.base != target.base) NSLog(KH_NS("[Kernel] FFVN Unity UUID matched at 0x%llx"), found.base);
            target = found;
            scanRunning = false;
        }
    });
    return target.base;
}

bool _read(long address, void *output, int length) {
    if (length <= 0 || !output) return false;
    Target context;
    { std::lock_guard<std::mutex> lock(stateMutex); context = target; }
    if (!context.base || kill(context.pid, 0) != 0) { memset(output, 0, length); return false; }
    return readTarget(context, static_cast<uint64_t>(address), output, static_cast<size_t>(length));
}

bool _write(long address, const void *input, int length) {
    if (length <= 0 || !input || !userRange(address, length)) return false;
    Target context;
    { std::lock_guard<std::mutex> lock(stateMutex); context = target; }
    if (!context.base || !context.tableVerified || !backend.writeVirtual || kill(context.pid, 0) != 0 ||
        backend.findProcess(context.pid) != context.process) return false;
    if (backend.readPointer(context.pmap + context.tableOffset) != context.table) return false;
    return backend.writeVirtual(context.table, reinterpret_cast<const void *>(address), input, length) == 0;
}

mach_port_t get_task_for_PID(pid_t) { return MACH_PORT_NULL; }
static bool ReadTaskImagePath(mach_port_t task, mach_vm_address_t address,
                          char *buffer, size_t capacity) {
    if (!buffer || capacity < 2 || !isVaildPtr(address)) return false;
    size_t offset = 0;
    while (offset < capacity - 1) {
        // Avoid crossing even a 4 KB page boundary while looking for the NUL.
        const size_t pageRemaining = 4096 - ((address + offset) & 4095);
        const size_t amount = std::min((size_t)128, std::min(capacity - 1 - offset, pageRemaining));
        mach_vm_size_t actual = 0;
        kern_return_t kr = mach_vm_read_overwrite(task, address + offset, amount,
                                                (mach_vm_address_t)(buffer + offset), &actual);
        if (kr != KERN_SUCCESS || actual != amount) return false;
        if (memchr(buffer + offset, '\0', amount)) return true;
        offset += amount;
    }
    buffer[capacity - 1] = '\0';
    return false;
}


struct dyld_image_info64 {
    mach_vm_address_t    imageLoadAddress;
    mach_vm_address_t    imageFilePath;
    mach_vm_size_t       imageFileModDate;
};

struct dyld_all_image_infos64 {
    uint32_t version;
    uint32_t infoArrayCount;
    mach_vm_address_t infoArray;
    dyld_image_notifier  notification;
    bool                 processDetachedFromSharedRegion;
    bool libSystemInitialized;
    mach_vm_address_t            dyldImageLoadAddress;
    mach_vm_address_t            jitInfo;
    mach_vm_address_t            dyldVersion;
    mach_vm_address_t            errorMessage;
    uint64_t                    terminationFlags;
    mach_vm_address_t            coreSymbolicationShmPage;
    uint64_t                    systemOrderFlag;
    uint64_t                    uuidArrayCount;
    mach_vm_address_t            uuidArray;
    mach_vm_address_t            dyldAllImageInfosAddress;
    uint64_t                    initialImageCount;
    uint64_t                    errorKind;
    mach_vm_address_t            errorClientOfDylibPath;
    mach_vm_address_t            errorTargetDylibPath;
    mach_vm_address_t            errorSymbol;
    uint64_t                    sharedCacheSlide;
};

mach_vm_address_t get_image_base_address(mach_port_t task, const char *image_name) {
    task_dyld_info_data_t dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, KH_STR("task_info failed: %s\n"), mach_error_string(kr));
        return 0;
    }

    struct dyld_all_image_infos64 infos{};
    mach_vm_size_t read_size = 0;
    kr = mach_vm_read_overwrite(task, dyld_info.all_image_info_addr, sizeof(infos),
                               (mach_vm_address_t)&infos, &read_size);
    if (kr != KERN_SUCCESS || read_size != sizeof(infos)) {
        return 0;
    }

    uint32_t image_count = infos.infoArrayCount;
    mach_vm_address_t info_array_addr = infos.infoArray;
    // dyld may be rebuilding this table during app launch. Retry later instead
    // of allocating an unbounded size or interpreting a partial table.
    if (!image_name || !image_name[0] || image_count == 0 || image_count > 4096 ||
        !isVaildPtr(info_array_addr)) return 0;
    vm_size_t image_info_size = image_count * sizeof(struct dyld_image_info64);
    std::vector<dyld_image_info64> image_infos(image_count);

    read_size = 0;
    kr = mach_vm_read_overwrite(task, info_array_addr, image_info_size,
                               (mach_vm_address_t)image_infos.data(), &read_size);
    if (kr != KERN_SUCCESS || read_size != image_info_size) {
        return 0;
    }

    for (uint32_t i = 0; i < image_count; ++i) {
        char path_buffer[PATH_MAX] = {0};
        if (ReadTaskImagePath(task, image_infos[i].imageFilePath, path_buffer, sizeof(path_buffer)) &&
            strstr(path_buffer, image_name)) {
            mach_vm_address_t base = image_infos[i].imageLoadAddress;
            return base;
        }
    }

    return 0;
}
