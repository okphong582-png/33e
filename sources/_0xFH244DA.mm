//
//  FishHookChecker.m
//  AntiFishHook (ObjC)
//

#import "FishHookChecker.h"

#if defined(__arm64__)

#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>          // for vm_protect
#import <string.h>
#import <stdio.h>
#include <mach-o/nlist.h>
#include "KabraxHide.h"
// ----------------------------------------------------------------------
// ULEB128 / SLEB128 helpers
// ----------------------------------------------------------------------

static inline uint64_t readUleb128(uint8_t **ptr, uint8_t *end) {
    uint64_t result = 0;
    int bit = 0;
    uint8_t byte;
    do {
        NSCAssert(*ptr < end, @"malformed uleb128");
        byte = **ptr;
        result |= ((uint64_t)(byte & 0x7f)) << bit;
        bit += 7;
        (*ptr)++;
    } while (byte & 0x80);
    return result;
}

static inline int64_t readSleb128(uint8_t **ptr, uint8_t *end) {
    int64_t result = 0;
    int bit = 0;
    uint8_t byte;
    do {
        NSCAssert(*ptr < end, @"malformed sleb128");
        byte = **ptr;
        result |= ((int64_t)(byte & 0x7f)) << bit;
        bit += 7;
        (*ptr)++;
    } while (byte & 0x80);
    // sign extend negative numbers
    if (byte & 0x40) {
        result |= (-1LL << bit);
    }
    return result;
}

// ----------------------------------------------------------------------
// Forward declarations of internal helpers
// ----------------------------------------------------------------------

static BOOL lookExportedSymbol(NSString *symbol, NSString *imageName, void **symbolAddress);
static void * _Nullable lookExportedSymbolByTrieWalk(NSString *targetSymbol,
                                                      uint8_t *start, uint8_t *end,
                                                      uint8_t *location, NSString *currentSymbol);

// ----------------------------------------------------------------------
// SymbolFound helpers
// ----------------------------------------------------------------------

static const int kBindTypeThreadedRebase = 102;

static BOOL lookLazyBindSymbol(NSString *symbol,
                                void **symbolAddr,
                                uint8_t *lazyBindInfoCmd,
                                size_t lazyBindInfoSize,
                                NSArray<NSString *> *allLoadDylds)
{
    uint8_t *ptr = lazyBindInfoCmd;
    uint8_t *end = ptr + lazyBindInfoSize;
    int ordinal = -1;
    BOOL foundSymbol = NO;
    int addend = 0;
    int32_t type = 0;

    while (ptr < end) {
        uint8_t byte = *ptr;
        int32_t immediate = byte & BIND_IMMEDIATE_MASK;
        int32_t opcode = byte & BIND_OPCODE_MASK;
        ptr++;

        switch (opcode) {
            case BIND_OPCODE_DONE:
                continue;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                ordinal = immediate;
                break;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                ordinal = (int)readUleb128(&ptr, end);
                break;
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                ordinal = (immediate == 0) ? 0 : (BIND_OPCODE_MASK | immediate);
                break;
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM: {
                const char *name = (const char *)ptr;
                if ([[NSString stringWithUTF8String:name] isEqualToString:symbol]) {
                    foundSymbol = YES;
                }
                ptr += strlen(name) + 1; // skip string + trailing zero
                break;
            }
            case BIND_OPCODE_SET_TYPE_IMM:
                type = immediate;
                continue;
            case BIND_OPCODE_SET_ADDEND_SLEB:
                addend = (int)readSleb128(&ptr, end);
                break;
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
            case BIND_OPCODE_ADD_ADDR_ULEB:
                (void)readUleb128(&ptr, end);
                break;
            case BIND_OPCODE_DO_BIND:
                if (foundSymbol) goto found_lazy;
                continue;
            default:
                NSCAssert(NO, @"bad lazy bind opcode");
                return NO;
        }
    }

found_lazy:
    NSCAssert(ordinal <= (int)allLoadDylds.count, @"ordinal out of range");

    if (foundSymbol && ordinal >= 0 && allLoadDylds.count > 0 &&
        ordinal <= (int)allLoadDylds.count && type != kBindTypeThreadedRebase)
    {
        NSString *imageName = allLoadDylds[ordinal - 1];
        void *tmpAddr = NULL;
        if (lookExportedSymbol(symbol, imageName, &tmpAddr) && tmpAddr) {
            *symbolAddr = (uint8_t *)tmpAddr + addend;
            return YES;
        }
    }
    return NO;
}

static BOOL lookBindSymbol(NSString *symbol,
                            void **symbolAddr,
                            uint8_t *bindInfoCmd,
                            size_t bindInfoSize,
                            NSArray<NSString *> *allLoadDylds)
{
    uint8_t *ptr = bindInfoCmd;
    uint8_t *end = ptr + bindInfoSize;
    int ordinal = -1;
    BOOL foundSymbol = NO;
    int addend = 0;
    int32_t type = 0;

    while (ptr < end) {
        uint8_t byte = *ptr;
        int32_t immediate = byte & BIND_IMMEDIATE_MASK;
        int32_t opcode = byte & BIND_OPCODE_MASK;
        ptr++;

        switch (opcode) {
            case BIND_OPCODE_DONE:
                goto bind_end;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                ordinal = immediate;
                break;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                ordinal = (int)readUleb128(&ptr, end);
                break;
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                ordinal = (immediate == 0) ? 0 : (BIND_OPCODE_MASK | immediate);
                break;
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM: {
                const char *name = (const char *)ptr;
                if ([[NSString stringWithUTF8String:name] isEqualToString:symbol]) {
                    foundSymbol = YES;
                }
                ptr += strlen(name) + 1;
                break;
            }
            case BIND_OPCODE_SET_TYPE_IMM:
                type = immediate;
                continue;
            case BIND_OPCODE_SET_ADDEND_SLEB:
                addend = (int)readSleb128(&ptr, end);
                break;
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
            case BIND_OPCODE_ADD_ADDR_ULEB:
                (void)readUleb128(&ptr, end);
                break;
            case BIND_OPCODE_DO_BIND:
            case BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED:
                if (foundSymbol) goto bind_end;
                break;
            case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                if (foundSymbol) {
                    goto bind_end;
                } else {
                    (void)readUleb128(&ptr, end);
                }
                break;
            case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB:
                if (foundSymbol) {
                    goto bind_end;
                } else {
                    (void)readUleb128(&ptr, end); // count
                    (void)readUleb128(&ptr, end); // skip
                }
                break;
            case BIND_OPCODE_THREADED:
                switch (immediate) {
                    case BIND_SUBOPCODE_THREADED_SET_BIND_ORDINAL_TABLE_SIZE_ULEB:
                        (void)readUleb128(&ptr, end);
                        break;
                    case BIND_SUBOPCODE_THREADED_APPLY:
                        if (foundSymbol) {
                            NSCAssert(NO, @"maybe BIND_TYPE_THREADED_REBASE, unhandled");
                            return NO;
                        }
                        continue;
                    default:
                        NSCAssert(NO, @"bad bind subopcode");
                        return NO;
                }
                break;
            default:
                NSCAssert(NO, @"bad bind opcode");
                return NO;
        }
    }

bind_end:
    NSCAssert(ordinal <= (int)allLoadDylds.count, @"ordinal out of range");
    if (foundSymbol && ordinal >= 0 && allLoadDylds.count > 0 &&
        ordinal <= (int)allLoadDylds.count && type != kBindTypeThreadedRebase)
    {
        NSString *imageName = allLoadDylds[ordinal - 1];
        void *tmpAddr = NULL;
        if (lookExportedSymbol(symbol, imageName, &tmpAddr) && tmpAddr) {
            *symbolAddr = (uint8_t *)tmpAddr + addend;
            return YES;
        }
    }
    return NO;
}

static BOOL lookExportedSymbol(NSString *symbol, NSString *exportImageName, void **symbolAddress) {
    NSString *rpathImage = nil;
    if ([exportImageName containsString:@"@rpath"]) {
        rpathImage = [[exportImageName componentsSeparatedByString:@"/"] lastObject];
    }

    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        NSString *currentName = [NSString stringWithUTF8String:name];

        if (rpathImage) {
            if (![currentName containsString:rpathImage]) continue;
        } else {
            if (![currentName isEqualToString:exportImageName]) continue;
        }

        const struct mach_header *image = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);

        // Try to find directly
        void *addr = lookExportedSymbolByTrieWalk(symbol,
                                                  NULL, // will compute inside
                                                  NULL,
                                                  NULL,
                                                  nil);
        if (addr) {
            *symbolAddress = addr;
            return YES;
        }

        // Look at re-exported dylibs
        NSMutableArray<NSString *> *reexports = [NSMutableArray array];
        uint8_t *curCmd = (uint8_t *)image + sizeof(struct mach_header_64);
        for (uint32_t j = 0; j < image->ncmds; j++) {
            struct load_command *lc = (struct load_command *)curCmd;
            if (lc->cmd == LC_REEXPORT_DYLIB) {
                struct dylib_command *dc = (struct dylib_command *)lc;
                const char *dylibName = (const char *)curCmd + dc->dylib.name.offset;
                [reexports addObject:[NSString stringWithUTF8String:dylibName]];
            }
            curCmd += lc->cmdsize;
        }

        for (NSString *re in reexports) {
            if (lookExportedSymbol(symbol, re, symbolAddress)) {
                return YES;
            }
        }
        return NO;
    }
    return NO;
}

// Trie walk implementation
static void * _Nullable lookExportedSymbolByTrieWalk(NSString *targetSymbol,
                                                      uint8_t *start, uint8_t *end,
                                                      uint8_t *location, NSString *currentSymbol)
{
    // Initial entry: we'll handle the outer setup elsewhere
    // This internal recursive function expects start,end and a current node location
    uint8_t *ptr = location;
    while (ptr <= end) {
        uint64_t terminalSize = 0;
        if (*ptr < 128) {
            terminalSize = *ptr++;
        } else {
            terminalSize = readUleb128(&ptr, end);
        }

        if (terminalSize != 0) {
            // terminal node: check if symbol matches
            if ([currentSymbol isEqualToString:targetSymbol]) {
                return ptr; // pointer to flags
            }
            return NULL;
        }

        uint8_t *children = ptr + terminalSize;
        if (children >= end) return NULL;
        uint8_t childrenCount = *children;
        ptr = children + 1;

        for (uint8_t i = 0; i < childrenCount; i++) {
            const char *nodeLabel = (const char *)ptr;
            // advance past the node label string and its null terminator
            while (*ptr != 0) ptr++;
            ptr++; // skip the null

            uint64_t nodeOffset = readUleb128(&ptr, end);

            NSString *nodeStr = [NSString stringWithUTF8String:nodeLabel];
            NSString *tmpCurrent = [currentSymbol stringByAppendingString:nodeStr];

            if (![targetSymbol hasPrefix:tmpCurrent]) {
                continue;
            }

            if (nodeOffset != 0 && (start + nodeOffset) <= end) {
                uint8_t *newLoc = start + nodeOffset;
                void *res = lookExportedSymbolByTrieWalk(targetSymbol, start, end, newLoc, tmpCurrent);
                if (res) return res;
            }
        }
    }
    return NULL;
}

// Wrapper that sets up the trie walk for a given image
static void * _Nullable lookExportedSymbolInImage(NSString *symbol,
                                                  const struct mach_header *image,
                                                  intptr_t slide)
{
    struct segment_command_64 *linkeditCmd = NULL;
    struct dyld_info_command *dyldInfoCmd = NULL;
    struct linkedit_data_command *exportCmd = NULL;

    uint8_t *curCmd = (uint8_t *)image + sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < image->ncmds; i++) {
        struct load_command *lc = (struct load_command *)curCmd;
        switch (lc->cmd) {
            case LC_SEGMENT_64: {
                struct segment_command_64 *seg = (struct segment_command_64 *)lc;
                if (strcmp(seg->segname, SEG_LINKEDIT) == 0) {
                    linkeditCmd = seg;
                }
                break;
            }
            case LC_DYLD_INFO_ONLY:
            case LC_DYLD_INFO:
                dyldInfoCmd = (struct dyld_info_command *)lc;
                break;
            case LC_DYLD_EXPORTS_TRIE:
                exportCmd = (struct linkedit_data_command *)lc;
                break;
            default:
                break;
        }
        curCmd += lc->cmdsize;
    }

    BOOL hasDyldInfo = dyldInfoCmd && dyldInfoCmd->export_size != 0;
    BOOL hasExportTrie = exportCmd && exportCmd->datasize != 0;
    if (!linkeditCmd || (!hasDyldInfo && !hasExportTrie)) return NULL;

    uintptr_t linkeditBase = slide + linkeditCmd->vmaddr - linkeditCmd->fileoff;
    uint32_t exportOff = hasExportTrie ? exportCmd->dataoff : dyldInfoCmd->export_off;
    uint32_t exportSize = hasExportTrie ? exportCmd->datasize : dyldInfoCmd->export_size;

    uint8_t *exportedInfo = (uint8_t *)(linkeditBase + exportOff);
    uint8_t *start = exportedInfo;
    uint8_t *end = exportedInfo + exportSize;

    

uint8_t *loc = (uint8_t *)lookExportedSymbolByTrieWalk(
    symbol,
    start,
    end,
    start,
    @""
);

    if (!loc) return NULL;

    // read flags
    uint64_t flags = readUleb128(&loc, end);
    uint64_t kind = flags & EXPORT_SYMBOL_FLAGS_KIND_MASK;
    switch (kind) {
        case EXPORT_SYMBOL_FLAGS_KIND_REGULAR: {
            uintptr_t addr = (uintptr_t)image + readUleb128(&loc, end);
            return (void *)addr;
        }
        case EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL:
            if (flags & EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) return NULL;
            return (void *)((uintptr_t)image + readUleb128(&loc, end));
        case EXPORT_SYMBOL_FLAGS_KIND_ABSOLUTE:
            if (flags & EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER) return NULL;
            return (void *)(uintptr_t)readUleb128(&loc, end);
        default:
            return NULL;
    }
}

// MARK: - FishHook (replace logic)

static void replaceSymbolPointerAtSection(struct section_64 *section,
                                          struct nlist_64 *symtab,
                                          uint8_t *strtab,
                                          uint32_t *indirectsym,
                                          intptr_t slide,
                                          NSString *symbolName,
                                          void *newMethod,
                                          void **oldMethod)
{
    uint32_t *indirect = indirectsym + section->reserved1;
    void **sectionAddr = (void **)(slide + section->addr);

    for (uint32_t i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symIndex = indirect[i];
        if (symIndex == INDIRECT_SYMBOL_ABS || symIndex == INDIRECT_SYMBOL_LOCAL) {
            continue;
        }
        const char *name = (const char *)(strtab + symtab[symIndex].n_un.n_strx + 1);
        if ([[NSString stringWithUTF8String:name] isEqualToString:symbolName]) {
            if (oldMethod) *oldMethod = sectionAddr[i];
            kern_return_t kr = vm_protect(mach_task_self(),
                                          (vm_address_t)sectionAddr,
                                          section->size,
                                          FALSE,
                                          VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            if (kr == KERN_SUCCESS) {
                sectionAddr[i] = newMethod;
            }
            break;
        }
    }
}

static void replaceSymbolAtImage(const struct mach_header *image,
                                 intptr_t slide,
                                 NSString *symbol,
                                 void *newMethod,
                                 void **oldMethod)
{
    struct segment_command_64 *linkeditCmd = NULL;
    struct segment_command_64 *dataCmd = NULL;
    struct segment_command_64 *dataConstCmd = NULL;
    struct symtab_command *symtabCmd = NULL;
    struct dysymtab_command *dynsymtabCmd = NULL;

    uint8_t *curCmd = (uint8_t *)image + sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < image->ncmds; i++) {
        struct load_command *lc = (struct load_command *)curCmd;
        switch (lc->cmd) {
            case LC_SEGMENT_64: {
                struct segment_command_64 *seg = (struct segment_command_64 *)lc;
                if (strcmp(seg->segname, SEG_LINKEDIT) == 0) {
                    linkeditCmd = seg;
                } else if (strcmp(seg->segname, SEG_DATA) == 0) {
                    dataCmd = seg;
                } else if (strcmp(seg->segname, "__DATA_CONST") == 0) {
                    dataConstCmd = seg;
                }
                break;
            }
            case LC_SYMTAB:
                symtabCmd = (struct symtab_command *)lc;
                break;
            case LC_DYSYMTAB:
                dynsymtabCmd = (struct dysymtab_command *)lc;
                break;
            default:
                break;
        }
        curCmd += lc->cmdsize;
    }

    if (!linkeditCmd || !symtabCmd || !dynsymtabCmd || (!dataCmd && !dataConstCmd)) return;

    intptr_t linkedBase = slide + linkeditCmd->vmaddr - linkeditCmd->fileoff;
    struct nlist_64 *symtab = (struct nlist_64 *)(linkedBase + symtabCmd->symoff);
    uint8_t *strtab = (uint8_t *)(linkedBase + symtabCmd->stroff);
    uint32_t *indirectsym = (uint32_t *)(linkedBase + dynsymtabCmd->indirectsymoff);

    struct segment_command_64 *segments[] = { dataCmd, dataConstCmd };
    for (int s = 0; s < 2; s++) {
        struct segment_command_64 *seg = segments[s];
        if (!seg) continue;

        uint8_t *sectionBase = (uint8_t *)((uintptr_t)seg + sizeof(struct segment_command_64));
        for (uint32_t j = 0; j < seg->nsects; j++) {
            struct section_64 *sect = (struct section_64 *)(sectionBase + j * sizeof(struct section_64));
            if (sect->flags == S_LAZY_SYMBOL_POINTERS ||
                sect->flags == S_NON_LAZY_SYMBOL_POINTERS) {
                replaceSymbolPointerAtSection(sect, symtab, strtab, indirectsym,
                                              slide, symbol, newMethod, oldMethod);
            }
        }
    }
}

// MARK: - Public class

@implementation _0x2828DAB

+ (BOOL)lookSymbol:(NSString *)symbol
            atImage:(const struct mach_header *)image
         imageSlide:(intptr_t)slide
      symbolAddress:(void **)outAddr
{
    struct segment_command_64 *linkeditCmd = NULL;
    struct dyld_info_command *dyldInfoCmd = NULL;
    NSMutableArray<NSString *> *allDylds = [NSMutableArray array];

    uint8_t *curCmd = (uint8_t *)image + sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < image->ncmds; i++) {
        struct load_command *lc = (struct load_command *)curCmd;
        switch (lc->cmd) {
            case LC_SEGMENT_64: {
                struct segment_command_64 *seg = (struct segment_command_64 *)lc;
                if (strcmp(seg->segname, SEG_LINKEDIT) == 0) {
                    linkeditCmd = seg;
                }
                break;
            }
            case LC_DYLD_INFO_ONLY:
            case LC_DYLD_INFO:
                dyldInfoCmd = (struct dyld_info_command *)lc;
                break;
            case LC_LOAD_DYLIB:
            case LC_LOAD_WEAK_DYLIB:
            case LC_LOAD_UPWARD_DYLIB:
            case LC_REEXPORT_DYLIB: {
                struct dylib_command *dc = (struct dylib_command *)lc;
                const char *dylibName = (const char *)curCmd + dc->dylib.name.offset;
                [allDylds addObject:[NSString stringWithUTF8String:dylibName]];
                break;
            }
            default:
                break;
        }
        curCmd += lc->cmdsize;
    }

    if (!linkeditCmd || !dyldInfoCmd) return NO;

    intptr_t linkeditBase = slide + linkeditCmd->vmaddr - linkeditCmd->fileoff;

    // Try Lazy bind
    if (dyldInfoCmd->lazy_bind_size > 0) {
        uint8_t *lazy = (uint8_t *)(linkeditBase + dyldInfoCmd->lazy_bind_off);
        if (lookLazyBindSymbol(symbol, outAddr, lazy, dyldInfoCmd->lazy_bind_size, allDylds)) {
            return YES;
        }
    }

    // Try Non-lazy bind
    if (dyldInfoCmd->bind_size > 0) {
        uint8_t *bind = (uint8_t *)(linkeditBase + dyldInfoCmd->bind_off);
        if (lookBindSymbol(symbol, outAddr, bind, dyldInfoCmd->bind_size, allDylds)) {
            return YES;
        }
    }

    return NO;
}

+ (void)_0x2828DAA:(NSString *)symbol {
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const struct mach_header *image = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        if (image) {
            void *originalAddr = NULL;
            if ([self lookSymbol:symbol atImage:image imageSlide:slide symbolAddress:&originalAddr] &&
                originalAddr) {
                void *old = NULL;
                replaceSymbolAtImage(image, slide, symbol, originalAddr, &old);
            }
        }
    }
}

@end

#else
// Non-arm64 stub
@implementation _0x2828DAB
+ (void)_0x2828DAA:(NSString *)symbol { /* not supported on this architecture */ }
@end
#endif // __arm64__