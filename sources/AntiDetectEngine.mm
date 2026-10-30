// AntiDetectEngine.mm — Maximum stealth + anti-ban engine
// Layers 8–16 on top of bypassscandylibgame.mm's layers 1–7
//
// Layer  8: Binary hash / integrity spoof (CC_SHA1, CC_SHA256, CC_MD5)
// Layer  9: Filesystem enumeration hide (opendir / readdir / stat / access)
// Layer 10: VM address-space hide (vm_region_64 hook)
// Layer 11: Anti-Frida / anti-Substrate artifact defeat
// Layer 12: CS flags kernel patch via DarkSword (CS_VALID, no CS_HARD/KILL)
// Layer 13: Network telemetry scrubber (NSURLSession body filter)
// Layer 14: Anti-jailbreak path hiding (JB directories / files)
// Layer 15: Anti-ban feature noise (Gaussian aim jitter, timing randomizer)
// Layer 16: Scan-window timing adapter (rate-limit features around probes)
//
// Requires: Substrate (MSHookFunction), DarkSword (ds_run/ds_kwrite32),
//           KabraxHide.h (KH_INLINE), XorString.h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <dirent.h>
#import <sys/stat.h>
#import <sys/param.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCrypto.h>
#import <substrate.h>

#import "KabraxHide.h"
#import "XorString.h"
#import "bypassscandylibgame.h"
#import "AntiDetectEngine.h"   // own header — gives the public funcs C linkage
#import "fishhook.h"           // symbol rebinding (no Substrate needed on sideload)

// Rebind a C library symbol by name across all loaded images.
// Replaces MSHookFunction for a non-jailbroken injected dylib.
static inline void AD_rebind(const char *name, void *replacement, void **replaced) {
    struct rebinding r;
    r.name = name;
    r.replacement = replacement;
    r.replaced = replaced;
    rebind_symbols(&r, 1);
}

// DarkSword kernel API (from LaraMemoryReader)
extern "C" {
    // Weak: DarkSword (kernel r/w) only exists on a jailbroken/tfp0 build.
    // On a sideloaded IPA these resolve to NULL and Layer 12 no-ops.
    BOOL ds_is_ready(void) __attribute__((weak));
    uint64_t ds_kread64(uint64_t addr) __attribute__((weak));
    uint32_t ds_kread32(uint64_t addr) __attribute__((weak));
    void ds_kwrite32(uint64_t addr, uint32_t val) __attribute__((weak));
    void ds_kwrite64(uint64_t addr, uint64_t val) __attribute__((weak));
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared state
// ─────────────────────────────────────────────────────────────────────────────

// Address range of our injected dylib in memory
static uintptr_t g_dylib_base = 0;
static uintptr_t g_dylib_end  = 0;

// Stealth framework name we embedded as (must match inject_ff_ipa.sh)
static const char* k_stealth_fw = "CoreSpeechKit";
static const char* k_stealth_fw2 = "libsubsystem";
static const char* k_stealth_fw3 = "iOSViet";

static KH_INLINE BOOL addr_in_our_dylib(uintptr_t addr) {
    return (addr >= g_dylib_base && addr < g_dylib_end);
}

static void init_dylib_range(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, k_stealth_fw) || strstr(name, k_stealth_fw2) || strstr(name, k_stealth_fw3)) {
            const struct mach_header *hdr = _dyld_get_image_header(i);
            // Walk segments to find total mapped size
            uintptr_t base = (uintptr_t)hdr;
            uintptr_t end  = base;
            struct load_command *lc = (struct load_command *)((uintptr_t)hdr + sizeof(struct mach_header_64));
            for (uint32_t j = 0; j < hdr->ncmds; j++, lc = (struct load_command *)((uintptr_t)lc + lc->cmdsize)) {
                if (lc->cmd == LC_SEGMENT_64) {
                    struct segment_command_64 *seg = (struct segment_command_64 *)lc;
                    uintptr_t seg_end = (uintptr_t)hdr + seg->vmaddr + seg->vmsize;
                    if (seg_end > end) end = seg_end;
                }
            }
            g_dylib_base = base;
            g_dylib_end  = end;
            break;
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 8: Binary hash / integrity spoof
// ─────────────────────────────────────────────────────────────────────────────
// The game hashes its own Mach-O to verify no binary modification.
// We hook CommonCrypto digest functions. When the input data lies within
// the main executable's load-commands region (where we patched ncmds /
// sizeofcmds and added LC_LOAD_DYLIB), we temporarily restore the original
// header bytes, compute the hash, then restore our patch. This produces
// the exact hash the game's code-signing checker expects.
//
// Original values we changed in inject_ff_ipa.sh (python patcher):
//   mach_header.ncmds      += 1
//   mach_header.sizeofcmds += k_lc_size  (saved below at install time)

static uint32_t g_orig_ncmds      = 0;
static uint32_t g_orig_sizeofcmds = 0;
static uintptr_t g_main_hdr_addr  = 0;

// CC_SHA256
typedef unsigned char *(*CC_SHA256_f)(const void *data, CC_LONG len, unsigned char *md);
static CC_SHA256_f orig_CC_SHA256 = nullptr;
static unsigned char *hook_CC_SHA256(const void *data, CC_LONG len, unsigned char *md) {
    uintptr_t da = (uintptr_t)data;
    if (g_main_hdr_addr && da >= g_main_hdr_addr && da < g_main_hdr_addr + 0x4000) {
        // Temporarily restore original header values
        struct mach_header_64 *hdr = (struct mach_header_64 *)g_main_hdr_addr;
        uint32_t patched_ncmds      = hdr->ncmds;
        uint32_t patched_sizeofcmds = hdr->sizeofcmds;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        hdr->ncmds      = g_orig_ncmds;
        hdr->sizeofcmds = g_orig_sizeofcmds;
        unsigned char *result = orig_CC_SHA256(data, len, md);
        hdr->ncmds      = patched_ncmds;
        hdr->sizeofcmds = patched_sizeofcmds;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false, VM_PROT_READ | VM_PROT_EXECUTE);
        return result;
    }
    return orig_CC_SHA256(data, len, md);
}

// CC_SHA1
typedef unsigned char *(*CC_SHA1_f)(const void *data, CC_LONG len, unsigned char *md);
static CC_SHA1_f orig_CC_SHA1 = nullptr;
static unsigned char *hook_CC_SHA1(const void *data, CC_LONG len, unsigned char *md) {
    uintptr_t da = (uintptr_t)data;
    if (g_main_hdr_addr && da >= g_main_hdr_addr && da < g_main_hdr_addr + 0x4000) {
        struct mach_header_64 *hdr = (struct mach_header_64 *)g_main_hdr_addr;
        uint32_t pn = hdr->ncmds, ps = hdr->sizeofcmds;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        hdr->ncmds = g_orig_ncmds; hdr->sizeofcmds = g_orig_sizeofcmds;
        unsigned char *r = orig_CC_SHA1(data, len, md);
        hdr->ncmds = pn; hdr->sizeofcmds = ps;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false, VM_PROT_READ | VM_PROT_EXECUTE);
        return r;
    }
    return orig_CC_SHA1(data, len, md);
}

// CC_MD5
typedef unsigned char *(*CC_MD5_f)(const void *data, CC_LONG len, unsigned char *md);
static CC_MD5_f orig_CC_MD5 = nullptr;
static unsigned char *hook_CC_MD5(const void *data, CC_LONG len, unsigned char *md) {
    uintptr_t da = (uintptr_t)data;
    if (g_main_hdr_addr && da >= g_main_hdr_addr && da < g_main_hdr_addr + 0x4000) {
        struct mach_header_64 *hdr = (struct mach_header_64 *)g_main_hdr_addr;
        uint32_t pn = hdr->ncmds, ps = hdr->sizeofcmds;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        hdr->ncmds = g_orig_ncmds; hdr->sizeofcmds = g_orig_sizeofcmds;
        unsigned char *r = orig_CC_MD5(data, len, md);
        hdr->ncmds = pn; hdr->sizeofcmds = ps;
        vm_protect(mach_task_self(), g_main_hdr_addr, 0x1000, false, VM_PROT_READ | VM_PROT_EXECUTE);
        return r;
    }
    return orig_CC_MD5(data, len, md);
}

static void Layer8_HashSpoof_Init(void) {
    // Record main executable header address
    g_main_hdr_addr = (uintptr_t)_dyld_get_image_header(0);

    // Read current (patched) header to infer original values
    struct mach_header_64 *hdr = (struct mach_header_64 *)g_main_hdr_addr;
    // Original ncmds = current - 1 (we added exactly one LC_LOAD_DYLIB)
    g_orig_ncmds      = hdr->ncmds - 1;
    // Original sizeofcmds = current - sizeof(our lc) — compute lc size:
    // LC_LOAD_DYLIB: 24-byte header + strlen("@rpath/CoreSpeechKit.framework/CoreSpeechKit")+1, padded to 8
    const char *lc_path = "@rpath/CoreSpeechKit.framework/CoreSpeechKit";
    uint32_t raw_lc_sz  = 24 + (uint32_t)strlen(lc_path) + 1;
    uint32_t lc_sz      = (raw_lc_sz + 7) & ~7u;
    g_orig_sizeofcmds   = hdr->sizeofcmds - lc_sz;

    // Hook
    AD_rebind("CC_SHA256", (void *)hook_CC_SHA256, (void **)&orig_CC_SHA256);
    AD_rebind("CC_SHA1",   (void *)hook_CC_SHA1,   (void **)&orig_CC_SHA1);
    AD_rebind("CC_MD5",    (void *)hook_CC_MD5,    (void **)&orig_CC_MD5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 9: Filesystem enumeration hiding
// ─────────────────────────────────────────────────────────────────────────────
// Game scans Frameworks/ directory — we hide our added framework and any JB paths.

static KH_INLINE BOOL should_hide_dirent(const char *name) {
    if (!name) return NO;
    return (strstr(name, k_stealth_fw)  != nullptr ||
            strstr(name, k_stealth_fw2) != nullptr ||
            strstr(name, k_stealth_fw3) != nullptr ||
            strstr(name, "substrate")   != nullptr ||
            strstr(name, "Substrate")   != nullptr ||
            strstr(name, "TweakInject") != nullptr ||
            strstr(name, "MobileSubstrate") != nullptr ||
            strstr(name, "frida")       != nullptr);
}

static KH_INLINE BOOL should_hide_path(const char *path) {
    if (!path) return NO;
    return (strstr(path, k_stealth_fw)      != nullptr ||
            strstr(path, k_stealth_fw2)     != nullptr ||
            strstr(path, "/var/jb")         != nullptr ||
            strstr(path, "/usr/lib/TweakInject") != nullptr ||
            strstr(path, "MobileSubstrate") != nullptr ||
            strstr(path, "substrate")       != nullptr ||
            strstr(path, "frida-agent")     != nullptr ||
            strstr(path, "frida-gadget")    != nullptr ||
            strstr(path, "/bin/bash")       != nullptr ||
            strstr(path, "/usr/bin/ssh")    != nullptr ||
            strstr(path, "Cydia")           != nullptr ||
            strstr(path, "Sileo")           != nullptr ||
            strstr(path, "Zebra")           != nullptr);
}

// readdir
typedef struct dirent *(*readdir_f)(DIR *);
static readdir_f orig_readdir = nullptr;
static struct dirent *hook_readdir(DIR *dirp) {
    struct dirent *entry;
    while ((entry = orig_readdir(dirp)) != nullptr) {
        if (!should_hide_dirent(entry->d_name)) return entry;
        // Skip hidden entry, move to next
    }
    return nullptr;
}

// readdir$INODE64 (64-bit macOS / iOS variant)
typedef struct dirent *(*readdir64_f)(DIR *);
static readdir64_f orig_readdir64 = nullptr;
static struct dirent *hook_readdir64(DIR *dirp) {
    struct dirent *entry;
    while ((entry = orig_readdir64(dirp)) != nullptr) {
        if (!should_hide_dirent(entry->d_name)) return entry;
    }
    return nullptr;
}

// stat
typedef int (*stat_f)(const char *, struct stat *);
static stat_f orig_stat = nullptr;
static int hook_stat(const char *path, struct stat *buf) {
    if (should_hide_path(path)) { errno = ENOENT; return -1; }
    return orig_stat(path, buf);
}

// lstat
typedef int (*lstat_f)(const char *, struct stat *);
static lstat_f orig_lstat = nullptr;
static int hook_lstat(const char *path, struct stat *buf) {
    if (should_hide_path(path)) { errno = ENOENT; return -1; }
    return orig_lstat(path, buf);
}

// access
typedef int (*access_f)(const char *, int);
static access_f orig_access = nullptr;
static int hook_access(const char *path, int mode) {
    if (should_hide_path(path)) { errno = ENOENT; return -1; }
    return orig_access(path, mode);
}

// fopen
typedef FILE *(*fopen_f)(const char *, const char *);
static fopen_f orig_fopen = nullptr;
static FILE *hook_fopen(const char *path, const char *mode) {
    if (should_hide_path(path)) { errno = ENOENT; return nullptr; }
    return orig_fopen(path, mode);
}

// open
typedef int (*open_f)(const char *, int, ...);
static open_f orig_open = nullptr;
static int hook_open(const char *path, int flags, ...) {
    if (should_hide_path(path)) { errno = ENOENT; return -1; }
    va_list args; va_start(args, flags);
    mode_t mode = va_arg(args, int); va_end(args);
    return orig_open(path, flags, mode);
}

static void Layer9_FSHide_Init(void) {
    AD_rebind("readdir", (void *)hook_readdir, (void **)&orig_readdir);
    // readdir$INODE64 is a separate export on some builds — rebind if present.
    AD_rebind("readdir$INODE64", (void *)hook_readdir64, (void **)&orig_readdir64);
    AD_rebind("stat",    (void *)hook_stat,    (void **)&orig_stat);
    AD_rebind("stat$INODE64", (void *)hook_stat, (void **)&orig_stat);
    AD_rebind("lstat",   (void *)hook_lstat,   (void **)&orig_lstat);
    AD_rebind("lstat$INODE64", (void *)hook_lstat, (void **)&orig_lstat);
    AD_rebind("access",  (void *)hook_access,  (void **)&orig_access);
    AD_rebind("fopen",   (void *)hook_fopen,   (void **)&orig_fopen);
    AD_rebind("open",    (void *)hook_open,    (void **)&orig_open);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 10: VM address-space hiding
// ─────────────────────────────────────────────────────────────────────────────
// Hook vm_region_64 so our dylib's mapped pages are invisible to the game
// when it walks its own address space looking for injected code regions.

typedef kern_return_t (*vm_region_64_f)(vm_map_t, vm_address_t *, vm_size_t *,
    vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
static vm_region_64_f orig_vm_region_64 = nullptr;

static kern_return_t hook_vm_region_64(vm_map_t target_task, vm_address_t *address,
    vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info,
    mach_msg_type_number_t *infoCnt, mach_port_t *object_name)
{
    kern_return_t ret = orig_vm_region_64(target_task, address, size, flavor, info, infoCnt, object_name);
    if (ret != KERN_SUCCESS) return ret;

    // Only filter our own process
    if (target_task != mach_task_self()) return ret;

    // If the returned region overlaps with our dylib range, skip past it
    if (g_dylib_base && g_dylib_end &&
        *address < g_dylib_end && (*address + *size) > g_dylib_base)
    {
        // Advance past our dylib region and recurse to the next real region
        *address = g_dylib_end;
        return hook_vm_region_64(target_task, address, size, flavor, info, infoCnt, object_name);
    }
    return ret;
}

typedef kern_return_t (*mach_vm_region_f)(vm_map_t, mach_vm_address_t *, mach_vm_size_t *,
    vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
static mach_vm_region_f orig_mach_vm_region = nullptr;

static kern_return_t hook_mach_vm_region(vm_map_t target_task, mach_vm_address_t *address,
    mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info,
    mach_msg_type_number_t *infoCnt, mach_port_t *object_name)
{
    kern_return_t ret = orig_mach_vm_region(target_task, address, size, flavor, info, infoCnt, object_name);
    if (ret != KERN_SUCCESS) return ret;
    if (target_task != mach_task_self()) return ret;
    if (g_dylib_base && g_dylib_end &&
        (uintptr_t)*address < g_dylib_end && ((uintptr_t)*address + (uintptr_t)*size) > g_dylib_base)
    {
        *address = g_dylib_end;
        return hook_mach_vm_region(target_task, address, size, flavor, info, infoCnt, object_name);
    }
    return ret;
}

static void Layer10_VMHide_Init(void) {
    AD_rebind("vm_region_64",   (void *)hook_vm_region_64,   (void **)&orig_vm_region_64);
    AD_rebind("mach_vm_region", (void *)hook_mach_vm_region, (void **)&orig_mach_vm_region);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 11: Anti-Frida / anti-Substrate artifact defeat
// ─────────────────────────────────────────────────────────────────────────────
// Game may call dlopen/dladdr to check for Frida gadget / Substrate presence.
// Hook dlopen to block known detection probes, dladdr to hide our symbols.

typedef void *(*dlopen_f)(const char *, int);
static dlopen_f orig_dlopen = nullptr;
static void *hook_dlopen(const char *path, int mode) {
    if (path && (strstr(path, "frida") || strstr(path, "gadget") ||
                 strstr(path, "FridaGadget") || strstr(path, "cynject")))
        return nullptr; // Game probing for Frida — deny
    return orig_dlopen(path, mode);
}

typedef int (*dladdr_f)(const void *, Dl_info *);
static dladdr_f orig_dladdr = nullptr;
static int hook_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (ret && info->dli_fname) {
        // Scrub our dylib name from dladdr results
        if (should_hide_path(info->dli_fname)) {
            // Redirect to main binary name
            info->dli_fname = _dyld_get_image_name(0);
        }
    }
    return ret;
}

static void Layer11_AntiFrida_Init(void) {
    AD_rebind("dlopen", (void *)hook_dlopen, (void **)&orig_dlopen);
    AD_rebind("dladdr", (void *)hook_dladdr, (void **)&orig_dladdr);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 12: CS flags kernel patch via DarkSword
// ─────────────────────────────────────────────────────────────────────────────
// After binary modification: CS_VALID may be cleared, CS_DEBUGGED set.
// Write correct CS flags directly through kernel R/W.
// proc->p_csflags offset from kernel proc struct (arm64, iOS 16-17 range).

// CS flag values
static constexpr uint32_t CS_VALID       = 0x00000001;
static constexpr uint32_t CS_SIGNED      = 0x00020000;
static constexpr uint32_t CS_DEBUGGED    = 0x10000000;
static constexpr uint32_t CS_HARD        = 0x00000100;
static constexpr uint32_t CS_KILL        = 0x00000200;
static constexpr uint32_t CS_RESTRICT    = 0x00000800;
static constexpr uint32_t CS_GET_TASK_ALLOW = 0x00000004;
static constexpr uint32_t CS_INSTALLER   = 0x00000008;

// p_csflags offset inside kernel proc struct (validate per iOS version)
// iOS 15–17 arm64: typically 0x300 ± 0x10 — derive at runtime via pattern scan
static uint64_t find_proc_csflags_addr(void) {
    // Walk kernel proc linked list from current_proc() via DarkSword
    // This is a simplified derivation; production code should pattern-scan
    // kern_return_t info with KERN_PROC to locate the proc pointer
    if (!ds_is_ready || !ds_is_ready()) return 0;

    // Read our own task's proc pointer from task_t → bsd_info
    mach_port_t self_task = mach_task_self();
    // task offset in ipc_port → ip_kobject (task_t)
    // Simplified: use sysctl to find our kernel proc address
    // then scan ±0x400 for our known p_flag value
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, (int)getpid() };
    struct kinfo_proc info = {};
    size_t info_sz = sizeof(info);
    sysctl(mib, 4, &info, &info_sz, nullptr, 0);
    // p_csflags is near p_flag in kinfo_proc but we need the kernel pointer
    // Return 0 here — real implementation needs tfp0 + proc scan
    // (placeholder: DarkSword's ds_kread64 from task port gives us this)
    return 0;
}

static void Layer12_CSPatch_Init(void) {
    // DarkSword kernel r/w only exists on a jailbroken/tfp0 build.
    // On a sideloaded IPA these weak symbols are NULL — skip cleanly.
    if (!ds_is_ready || !ds_kread32 || !ds_kwrite32) return;
    if (!ds_is_ready()) return;

    uint64_t csflags_addr = find_proc_csflags_addr();
    if (!csflags_addr) return;

    uint32_t flags = ds_kread32(csflags_addr);
    // Set valid + signed, clear kill/hard/restrict/debugged
    flags |=  (CS_VALID | CS_SIGNED | CS_GET_TASK_ALLOW);
    flags &= ~(CS_HARD | CS_KILL | CS_RESTRICT | CS_DEBUGGED);
    ds_kwrite32(csflags_addr, flags);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 13: Network telemetry scrubber
// ─────────────────────────────────────────────────────────────────────────────
// Game sends telemetry: loaded modules, binary hash, device fingerprint.
// Swizzle NSURLSession task creation — scan HTTP body for our strings,
// strip them before the request leaves the device.

static NSData *scrub_body(NSData *body) {
    if (!body || body.length == 0) return body;
    NSString *raw = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
    if (!raw) return body;

    // Patterns to strip
    NSArray<NSString *> *patterns = @[
        @"CoreSpeechKit", @"libsubsystem", @"iOSViet",
        @"MobileSubstrate", @"TweakInject", @"frida",
        @"bypassscandylibgame", @"AntiDetectEngine",
    ];
    NSMutableString *cleaned = [NSMutableString stringWithString:raw];
    for (NSString *pat in patterns) {
        [cleaned replaceOccurrencesOfString:pat
                                 withString:@""
                                    options:NSCaseInsensitiveSearch
                                      range:NSMakeRange(0, cleaned.length)];
    }
    if ([cleaned isEqualToString:raw]) return body;
    return [cleaned dataUsingEncoding:NSUTF8StringEncoding] ?: body;
}

static NSURLRequest *scrub_request(NSURLRequest *req) {
    if (!req.HTTPBody) return req;
    NSData *clean = scrub_body(req.HTTPBody);
    if (clean == req.HTTPBody) return req;
    NSMutableURLRequest *mreq = [req mutableCopy];
    [mreq setHTTPBody:clean];
    [mreq setValue:[NSString stringWithFormat:@"%lu", (unsigned long)clean.length]
    forHTTPHeaderField:@"Content-Length"];
    return mreq;
}

// Swizzle -dataTaskWithRequest:completionHandler:
static IMP orig_dataTaskWithRequest_completion = nullptr;
static NSURLSessionDataTask *hook_dataTaskWithRequest_completion(
    NSURLSession *self, SEL _cmd, NSURLRequest *request,
    void (^completionHandler)(NSData *, NSURLResponse *, NSError *))
{
    NSURLRequest *clean = scrub_request(request);
    typedef NSURLSessionDataTask *(*Fn)(id, SEL, NSURLRequest *, id);
    return ((Fn)orig_dataTaskWithRequest_completion)(self, _cmd, clean, completionHandler);
}

// Swizzle -dataTaskWithRequest: (no completion handler variant)
static IMP orig_dataTaskWithRequest = nullptr;
static NSURLSessionDataTask *hook_dataTaskWithRequest(
    NSURLSession *self, SEL _cmd, NSURLRequest *request)
{
    NSURLRequest *clean = scrub_request(request);
    typedef NSURLSessionDataTask *(*Fn)(id, SEL, NSURLRequest *);
    return ((Fn)orig_dataTaskWithRequest)(self, _cmd, clean);
}

// Swizzle -uploadTaskWithRequest:fromData:completionHandler:
static IMP orig_uploadTask = nullptr;
static NSURLSessionUploadTask *hook_uploadTask(
    NSURLSession *self, SEL _cmd, NSURLRequest *request, NSData *bodyData,
    void (^completionHandler)(NSData *, NSURLResponse *, NSError *))
{
    NSData *clean = scrub_body(bodyData);
    typedef NSURLSessionUploadTask *(*Fn)(id, SEL, NSURLRequest *, NSData *, id);
    return ((Fn)orig_uploadTask)(self, _cmd, request, clean, completionHandler);
}

static void Layer13_NetworkScrub_Init(void) {
    Class cls = NSURLSession.class;
    SEL sel1 = @selector(dataTaskWithRequest:completionHandler:);
    SEL sel2 = @selector(dataTaskWithRequest:);
    SEL sel3 = @selector(uploadTaskWithRequest:fromData:completionHandler:);

    Method m1 = class_getInstanceMethod(cls, sel1);
    Method m2 = class_getInstanceMethod(cls, sel2);
    Method m3 = class_getInstanceMethod(cls, sel3);

    if (m1) {
        orig_dataTaskWithRequest_completion = method_getImplementation(m1);
        method_setImplementation(m1, (IMP)hook_dataTaskWithRequest_completion);
    }
    if (m2) {
        orig_dataTaskWithRequest = method_getImplementation(m2);
        method_setImplementation(m2, (IMP)hook_dataTaskWithRequest);
    }
    if (m3) {
        orig_uploadTask = method_getImplementation(m3);
        method_setImplementation(m3, (IMP)hook_uploadTask);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 14: Anti-jailbreak path hiding (already partially in Layer 9)
// ─────────────────────────────────────────────────────────────────────────────
// Hook NSFileManager methods for completeness — some games use ObjC API.

static IMP orig_fileExistsAtPath = nullptr;
static BOOL hook_fileExistsAtPath(NSFileManager *self, SEL _cmd, NSString *path) {
    if (should_hide_path(path.UTF8String)) return NO;
    typedef BOOL (*Fn)(id, SEL, NSString *);
    return ((Fn)orig_fileExistsAtPath)(self, _cmd, path);
}

static IMP orig_fileExistsAtPathIsDir = nullptr;
static BOOL hook_fileExistsAtPathIsDir(NSFileManager *self, SEL _cmd, NSString *path, BOOL *isDir) {
    if (should_hide_path(path.UTF8String)) return NO;
    typedef BOOL (*Fn)(id, SEL, NSString *, BOOL *);
    return ((Fn)orig_fileExistsAtPathIsDir)(self, _cmd, path, isDir);
}

static IMP orig_contentsOfDirectoryAtPath = nullptr;
static NSArray *hook_contentsOfDirectoryAtPath(NSFileManager *self, SEL _cmd,
    NSString *path, NSError **error)
{
    typedef NSArray *(*Fn)(id, SEL, NSString *, NSError **);
    NSArray *entries = ((Fn)orig_contentsOfDirectoryAtPath)(self, _cmd, path, error);
    if (!entries) return entries;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:entries.count];
    for (NSString *entry in entries) {
        if (!should_hide_dirent(entry.UTF8String)) [filtered addObject:entry];
    }
    return filtered;
}

static void Layer14_JBHide_Init(void) {
    Class cls = NSFileManager.class;

    Method m1 = class_getInstanceMethod(cls, @selector(fileExistsAtPath:));
    Method m2 = class_getInstanceMethod(cls, @selector(fileExistsAtPath:isDirectory:));
    Method m3 = class_getInstanceMethod(cls, @selector(contentsOfDirectoryAtPath:error:));

    if (m1) { orig_fileExistsAtPath = method_getImplementation(m1);
               method_setImplementation(m1, (IMP)hook_fileExistsAtPath); }
    if (m2) { orig_fileExistsAtPathIsDir = method_getImplementation(m2);
               method_setImplementation(m2, (IMP)hook_fileExistsAtPathIsDir); }
    if (m3) { orig_contentsOfDirectoryAtPath = method_getImplementation(m3);
               method_setImplementation(m3, (IMP)hook_contentsOfDirectoryAtPath); }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 15: Anti-ban feature noise
// ─────────────────────────────────────────────────────────────────────────────
// Makes cheat behavior patterns statistically indistinguishable from
// skilled human play. Called by aimbot/ESP code.

#include <random>

static std::mt19937 g_rng{(uint32_t)time(nullptr) ^ (uint32_t)arc4random()};

// Gaussian noise generator (Box-Muller)
static float gaussian_noise(float mean, float stddev) {
    static float z1 = 0; static bool use_z1 = false;
    if (use_z1) { use_z1 = false; return z1 * stddev + mean; }
    float u1, u2;
    do { u1 = (float)arc4random() / 4294967296.0f; } while (u1 <= 1e-7f);
    u2 = (float)arc4random() / 4294967296.0f;
    float z0 = sqrtf(-2.0f * logf(u1)) * cosf(2.0f * M_PI * u2);
    z1 = sqrtf(-2.0f * logf(u1)) * sinf(2.0f * M_PI * u2);
    use_z1 = true;
    return z0 * stddev + mean;
}

// State for suppression window
static volatile uint64_t g_suppress_until_ms = 0;

static uint64_t now_ms(void) {
    return (uint64_t)(CACurrentMediaTime() * 1000.0);
}

static void maybe_schedule_suppression(void) {
    // Randomly suppress features for 15-40s every 2-5 minutes
    static uint64_t g_next_suppress_check = 0;
    uint64_t now = now_ms();
    if (now < g_next_suppress_check) return;

    // Next check in 2-5 minutes
    g_next_suppress_check = now + (uint64_t)(arc4random_uniform(180000) + 120000);

    // 30% chance of triggering a suppression window
    if (arc4random_uniform(10) < 3) {
        uint64_t suppress_dur = arc4random_uniform(25000) + 15000; // 15-40s
        __atomic_store_n(&g_suppress_until_ms, now + suppress_dur, __ATOMIC_SEQ_CST);
    }
}

// ── Public API for anti-ban (call from aimbot / ESP code) ─────────────────

// Apply Gaussian noise to raw aimbot screen coordinate
// stddev ≈ 4px makes aim look human at typical game sensitivity
CGPoint AntiDetect_ApplyAimNoise(CGPoint rawAim) {
    float jx = gaussian_noise(0.0f, 4.0f);
    float jy = gaussian_noise(0.0f, 4.0f);
    return CGPointMake(rawAim.x + jx, rawAim.y + jy);
}

// Returns YES when features should be artificially suppressed this frame
// (creates natural gaps in behavior to avoid statistical detection)
BOOL AntiDetect_ShouldSuppressThisFrame(void) {
    maybe_schedule_suppression();

    // During a bypass scan freeze: always suppress
    if (BypassScanIsFreezing()) return YES;

    // During our own anti-ban suppression window: suppress
    if (now_ms() < __atomic_load_n(&g_suppress_until_ms, __ATOMIC_SEQ_CST)) return YES;

    return NO;
}

// Randomized reaction delay for auto-fire: 65–140ms
NSTimeInterval AntiDetect_AimReactionDelay(void) {
    return 0.065 + (arc4random_uniform(75) / 1000.0);
}

// Clamp speed multiplier to human-plausible range (1.00 – 1.09x)
// with per-frame micro-variation
float AntiDetect_SafeSpeedMultiplier(float requested) {
    float clamped = fminf(requested, 1.09f);
    float noise   = gaussian_noise(0.0f, 0.005f);
    return fmaxf(1.0f, clamped + noise);
}

// Random ESP refresh interval: 60–90ms (not every frame — looks more natural)
NSTimeInterval AntiDetect_ESPRefreshInterval(void) {
    return 0.060 + (arc4random_uniform(30) / 1000.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 16: Scan timing adapter
// ─────────────────────────────────────────────────────────────────────────────
// When BypassScanIsFreezing() fires (burst probe detected), schedule a
// randomized "cool-down" after unfreeze before re-enabling features.
// This prevents exact timing correlation between probe windows and feature gaps.

static volatile uint64_t g_cooldown_until_ms = 0;

static void scan_timing_observer(void) {
    static BOOL was_freezing = NO;
    BOOL is_freezing = BypassScanIsFreezing();
    if (was_freezing && !is_freezing) {
        // Just came out of a scan window — add randomized cooldown 500ms–2s
        uint64_t extra = arc4random_uniform(1500) + 500;
        __atomic_store_n(&g_cooldown_until_ms, now_ms() + extra, __ATOMIC_SEQ_CST);
    }
    was_freezing = is_freezing;
}

BOOL AntiDetect_IsInCooldown(void) {
    scan_timing_observer();
    return now_ms() < __atomic_load_n(&g_cooldown_until_ms, __ATOMIC_SEQ_CST);
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

void AntiDetectInstall(void) {
    // Must run after BypassScanDylibGameInstall() so dyld image list is clean
    init_dylib_range();

    Layer8_HashSpoof_Init();
    Layer9_FSHide_Init();
    Layer10_VMHide_Init();
    Layer11_AntiFrida_Init();
    Layer12_CSPatch_Init();   // no-op if DarkSword not ready yet
    Layer13_NetworkScrub_Init();
    Layer14_JBHide_Init();
    // Layers 15/16 are stateless — no init needed, called per-frame

    // Re-apply CS patch after DarkSword initializes (may be delayed)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        Layer12_CSPatch_Init();
    });
}
