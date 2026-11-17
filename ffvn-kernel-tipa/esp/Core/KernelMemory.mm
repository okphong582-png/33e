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
Target target;
std::mutex stateMutex;
bool scanRunning = false;
CFAbsoluteTime nextScan = 0;

bool kernelPointer(uint64_t address) { return address >= 0xffff000000000000ULL && !(address & 7); }
bool userRange(uint64_t address, size_t length) {
    return length && address >= 0x100000 && address < 0x1000000000000ULL &&
           length <= 0x1000000000000ULL - address;
}

bool initializeBackend() {
    if (backend.ready) return true;
    if (getuid() != 0) { NSLog(@"[Kernel] HUD must run as root"); return false; }
    if (!backend.library) {
        NSArray<NSString *> *paths = @[@"/var/jb/usr/lib/libjailbreak.dylib",
            @"/var/jb/basebin/libjailbreak.dylib", @"/var/jb/usr/lib/libjailbreak.roothide.dylib",
            @"/usr/lib/libjailbreak.dylib", @"/.jbroot/usr/lib/libjailbreak.dylib"];
        for (NSString *path in paths) {
            backend.library = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            if (backend.library) break;
        }
    }
    if (!backend.library) { NSLog(@"[Kernel] libjailbreak unavailable"); return false; }
    auto initialize = reinterpret_cast<int (*)()>(dlsym(backend.library, "jbdInitPPLRW"));
    if (!initialize || initialize() != 0) { NSLog(@"[Kernel] jbdInitPPLRW failed"); return false; }
    backend.findProcess = reinterpret_cast<decltype(backend.findProcess)>(dlsym(backend.library, "proc_find"));
    backend.processTask = reinterpret_cast<decltype(backend.processTask)>(dlsym(backend.library, "proc_task"));
    backend.readPointer = reinterpret_cast<decltype(backend.readPointer)>(dlsym(backend.library, "kread_ptr"));
    backend.read64 = reinterpret_cast<decltype(backend.read64)>(dlsym(backend.library, "kread64"));
    backend.readVirtual = reinterpret_cast<decltype(backend.readVirtual)>(dlsym(backend.library, "vreadbuf"));
    backend.writeVirtual = reinterpret_cast<decltype(backend.writeVirtual)>(dlsym(backend.library, "vwritebuf"));
    backend.ready = backend.findProcess && backend.processTask && backend.readPointer &&
                    backend.read64 && backend.readVirtual;
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
    if (!kernelPointer(context.process)) return {};
    uint64_t task = backend.processTask(context.process);
    if (!kernelPointer(task)) return {};
    context.map = backend.readPointer(task + 0x28);
    if (!kernelPointer(context.map)) return {};
    uint64_t pmap = backend.readPointer(context.map + 0x40);
    if (!kernelPointer(pmap)) return {};
    context.table = backend.read64(pmap + 8);
    if (!context.table || (context.table & 0xfff) || context.table >= (1ULL << 52)) return {};
    const uint64_t sentinel = context.map + 0x10;
    uint64_t entry = backend.readPointer(sentinel + 8);
    const uint32_t count = static_cast<uint32_t>(backend.read64(context.map + 0x30));
    if (!count || count > 32768) return {};
    for (uint32_t index = 0; index < count && entry != sentinel; ++index) {
        if (!kernelPointer(entry) || kill(pid, 0) != 0) return {};
        const uint64_t start = backend.read64(entry + 0x10);
        const uint64_t end = backend.read64(entry + 0x18);
        if (end > start && userRange(start, end - start) && matchingImage(context, start)) {
            if (backend.findProcess(pid) != context.process) return {};
            context.base = start;
            return context;
        }
        const uint64_t next = backend.readPointer(entry + 8);
        if (next == entry) return {};
        entry = next;
    }
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
                }
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
