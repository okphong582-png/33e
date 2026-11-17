#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <sys/sysctl.h>
#include <signal.h>
#include <unistd.h>
#include <cstring>
#include <mutex>
#include <vector>
#include "pid.h"
#include "VnProfile.h"
#include "KernelMemory.h"
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
    int (*writeVirtual)(uint64_t, const void *, const void *, size_t) = nullptr;
    bool ready = false;
};
struct Target {
    pid_t pid = 0;
    uint64_t process = 0, map = 0, table = 0, base = 0;
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
    NSLog(@"[Kernel] %@", message);
    HUDUpdateKernelStatus(message);
}

void loadKernelLayout() {
    auto serialize = reinterpret_cast<void *(*)()>(dlsym(backend.library, "jbinfo_get_serialized"));
    auto getValue = reinterpret_cast<void *(*)(void *, const char *)>(dlsym(RTLD_DEFAULT, "xpc_dictionary_get_value"));
    auto getNumber = reinterpret_cast<uint64_t (*)(void *, const char *)>(dlsym(RTLD_DEFAULT, "xpc_dictionary_get_uint64"));
    auto release = reinterpret_cast<void (*)(void *)>(dlsym(RTLD_DEFAULT, "xpc_release"));
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
        [paths addObject:[root stringByAppendingPathComponent:@"usr/lib/libjailbreak.dylib"]];
        [paths addObject:[root stringByAppendingPathComponent:@"usr/lib/libjailbreak.roothide.dylib"]];
        [paths addObject:[root stringByAppendingPathComponent:@"basebin/libjailbreak.dylib"]];
    };
    addRoot([NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@".jbroot"]);
    NSFileManager *files = NSFileManager.defaultManager;
    for (NSString *container in @[@"/var/containers/Bundle/Application", @"/var/mobile/Containers/Shared/AppGroup"]) {
        NSArray<NSString *> *entries = [files contentsOfDirectoryAtPath:container error:nil];
        for (NSString *entry in entries) {
            if ([entry hasPrefix:@".jbroot-"])
                addRoot([container stringByAppendingPathComponent:entry]);
        }
    }
    [paths addObjectsFromArray:@[@"/var/jb/usr/lib/libjailbreak.dylib",
        @"/var/jb/basebin/libjailbreak.dylib", @"/var/jb/usr/lib/libjailbreak.roothide.dylib",
        @"/usr/lib/libjailbreak.dylib", @"/.jbroot/usr/lib/libjailbreak.dylib"]];
    NSString *bundled = [NSBundle.mainBundle pathForResource:@"libjailbreak" ofType:@"dylib"];
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
            if (dlsym(library, "proc_find") && dlsym(library, "proc_task") && dlsym(library, "vreadbuf")) {
                backend.library = library;
                NSLog(@"[Kernel] Loaded provider %@", path);
                return true;
            }
            lastFailure = [NSString stringWithFormat:@"%@ thiếu proc_find/proc_task/vreadbuf.", path];
            dlclose(library);
            continue;
        }
        const char *error = dlerror();
        NSString *detail = error ? [NSString stringWithUTF8String:error] : @"dlopen không trả lý do";
        if (detail.length > 320) detail = [detail substringToIndex:320];
        lastFailure = [NSString stringWithFormat:@"%@\n%@", path, detail];
    }
    reportStatus(foundFile ? [@"Kernel không nạp được thư viện đã tìm thấy.\n" stringByAppendingString:lastFailure ?: @""] :
        @"Kernel chưa tìm thấy libjailbreak trong .jbroot, .jbroot-* hoặc /var/jb. Kiểm tra trạng thái jailbreak trong Dopamine.");
    return false;
}

bool initializeBackend() {
    if (backend.ready) return true;
    if (getuid() != 0) { reportStatus(@"Kernel lỗi — HUD chưa có quyền root."); return false; }
    if (!backend.library && !loadBackendLibrary()) return false;
    auto initialize = reinterpret_cast<int (*)()>(dlsym(backend.library, "jbdInitPPLRW"));
    if (!initialize || initialize() != 0) { reportStatus(@"Kernel lỗi — jbdInitPPLRW chưa khởi tạo được."); return false; }
    backend.findProcess = reinterpret_cast<decltype(backend.findProcess)>(dlsym(backend.library, "proc_find"));
    backend.processTask = reinterpret_cast<decltype(backend.processTask)>(dlsym(backend.library, "proc_task"));
    backend.readPointer = reinterpret_cast<decltype(backend.readPointer)>(dlsym(backend.library, "kread_ptr"));
    backend.read64 = reinterpret_cast<decltype(backend.read64)>(dlsym(backend.library, "kread64"));
    backend.readVirtual = reinterpret_cast<decltype(backend.readVirtual)>(dlsym(backend.library, "vreadbuf"));
    backend.writeVirtual = reinterpret_cast<decltype(backend.writeVirtual)>(dlsym(backend.library, "vwritebuf"));
    backend.ready = backend.findProcess && backend.processTask && backend.readPointer &&
                    backend.read64 && backend.readVirtual;
    if (backend.ready) loadKernelLayout();
    else reportStatus(@"Kernel lỗi — libjailbreak thiếu hàm đọc bắt buộc.");
    NSLog(@"[Kernel] libjailbreak reader %@", backend.ready ? @"ready" : @"missing required symbols");
    return backend.ready;
}

bool readTarget(const Target &context, uint64_t address, void *output, size_t length) {
    if (!output || !context.table || !userRange(address, length)) return false;
    if (backend.readVirtual(context.table, reinterpret_cast<const void *>(address), output, length) == 0) return true;
    memset(output, 0, length);
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
    if (!kernelPointer(context.process)) { reportStatus(@"Kernel lỗi — proc_find chưa tìm được FFVN."); return {}; }
    uint64_t task = backend.processTask(context.process);
    if (!kernelPointer(task)) { reportStatus(@"Kernel lỗi — chưa lấy được task của FFVN."); return {}; }
    context.map = backend.readPointer(task + layout.taskMap);
    if (!kernelPointer(context.map)) { reportStatus(@"Kernel lỗi — chưa đọc được vm_map."); return {}; }
    uint64_t pmap = backend.readPointer(context.map + layout.mapPmap);
    if (!kernelPointer(pmap)) { reportStatus(@"Kernel lỗi — chưa đọc được pmap."); return {}; }
    context.table = backend.read64(pmap + layout.pmapTtep);
    if (!context.table || (context.table & 0xfff) || context.table >= (1ULL << 52)) {
        reportStatus(@"Kernel lỗi — bảng trang TTEP không hợp lệ."); return {};
    }
    const uint64_t header = context.map + layout.mapHeader;
    const uint64_t sentinel = header + layout.headerLinks;
    uint64_t entry = backend.readPointer(sentinel + layout.linksNext);
    const uint32_t count = static_cast<uint32_t>(backend.read64(header + layout.headerCount));
    if (!count || count > 32768) { reportStatus(@"Kernel lỗi — danh sách vùng nhớ chưa hợp lệ."); return {}; }
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
            reportStatus(@"Kernel đã đọc được Unity FFVN 1.134.1. Vào trận để kiểm tra ESP/aim.");
            return context;
        }
        const uint64_t next = backend.readPointer(links + layout.linksNext);
        if (next == entry) return {};
        entry = next;
    }
    reportStatus(readableHeaders ? @"Kernel đọc được game, chưa thấy UUID Unity FFVN 1.134.1 đã đối chiếu." :
                                  @"Kernel chưa đọc được dữ liệu game qua vreadbuf.");
    return {};
}
}

// Legacy remote-code installers can detect that this backend has no Mach task port.
mach_port_t get_task = MACH_PORT_NULL;

uint64_t KernelProcessIdentity() {
    std::lock_guard<std::mutex> lock(stateMutex);
    return target.base ? target.process : 0;
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
                    if (previous.pid == pid && previous.base && backend.findProcess(pid) == previous.process) found = previous;
                    else found = discover(pid);
                } else reportStatus(@"Đang chờ tiến trình FreeFireVN. Hãy mở game.");
            }
            std::lock_guard<std::mutex> lock(stateMutex);
            if (found.base && found.base != target.base) NSLog(@"[Kernel] FFVN Unity UUID matched at 0x%llx", found.base);
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
    if (!context.base || !backend.writeVirtual || kill(context.pid, 0) != 0 ||
        backend.findProcess(context.pid) != context.process) return false;
    return backend.writeVirtual(context.table, reinterpret_cast<const void *>(address), input, length) == 0;
}

mach_port_t get_task_for_PID(pid_t) { return MACH_PORT_NULL; }
mach_vm_address_t get_image_base_address(mach_port_t, const char *) {
    std::lock_guard<std::mutex> lock(stateMutex);
    return target.base;
}
